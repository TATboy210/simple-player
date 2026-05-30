# Domain Pitfalls: v1.2.1 Window Smoothness, HLS ABR, Architecture Simplification

**Domain:** Flutter desktop media player -- Win32 frameless window, HLS adaptive bitrate, platform abstraction
**Researched:** 2026-05-31
**Overall confidence:** HIGH (Win32/HLS based on prior project experience + domain knowledge; Platform abstraction MEDIUM -- fewer battle-tested patterns for Flutter desktop)

---

## 1. Win32 Frameless Window Smoothness (WIN-05)

### Pitfall 1a: Flutter Engine Message Interception Kills Custom WM_NCCALCSIZE

**What goes wrong:** Adding `WM_NCCALCSIZE` handling in `flutter_window.cpp` `MessageHandler` does nothing because Flutter's `HandleTopLevelWindowProc` (line 46-53) runs FIRST and may consume the message. The current code at `flutter_window.cpp:46` shows:

```cpp
if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
        return *result;  // <-- custom handler never reached
    }
}
```

If Flutter returns a value for `WM_NCCALCSIZE`, your custom handler below it is dead code.

**Why it happens:** Flutter's embedder registers its own window proc that intercepts certain messages. `WM_NCCALCSIZE` and `WM_NCHITTEST` are among the messages Flutter may handle.

**Consequences:** The C++ `WM_NCCALCSIZE` handler compiles and runs but has zero effect. The title bar remains visible or the border flash persists. Developer wastes hours debugging a handler that never executes.

**Prevention:**
- Option A: Move custom handling BEFORE `HandleTopLevelWindowProc` -- but this risks breaking Flutter's own DPI/layout logic.
- Option B: Use `DwmExtendFrameIntoClientArea` with `margins = {-1, -1, -1, -1}` in `OnCreate()` BEFORE the Flutter controller is created. This operates at the DWM level, not the message level.
- Option C: Register a separate `WNDPROC` via `SetWindowLongPtr(GWLP_WNDPROC, ...)` that runs BEFORE Flutter's handler. This is what `bitsdojo_window` does.
- Option D (recommended): Keep `WS_CAPTION` style, use `WM_NCCALCSIZE` to zero the non-client area, but call `DwmExtendFrameIntoClientArea` for shadow. Test that `HandleTopLevelWindowProc` does NOT consume `WM_NCCALCSIZE` first -- it may not.

**Detection:** Add `OutputDebugStringW(L"WM_NCCALCSIZE hit\n")` in your handler. If it doesn't appear in debug output when resizing, Flutter consumed it.

**Phase:** WIN-05 (C++ WM_NCCALCSIZE)

---

### Pitfall 1b: WS_CAPTION Removal Kills DWM Animation (Already Proven)

**What goes wrong:** The current `SetFrameless` in `window_channel.cpp` removes `WS_CAPTION`:

```cpp
style &= ~WS_CAPTION;      // removes title bar
style |= WS_THICKFRAME;    // keeps resize border
```

This destroys DWM maximize/restore animation, Win11 rounded corners, and window shadow. This is the EXISTING behavior and has been documented as an anti-pattern in `anti_pattern_window_frameless.md`.

**Why it happens:** `WS_CAPTION` is not just the title bar text -- it is the DWM animation pipeline's required style flag. Without it, DWM skips smooth transitions.

**Consequences:** Maximize/restore becomes a jarring snap. Win11 corners become square. Shadow disappears. The "Apple-level smoothness" goal is impossible with this approach.

**Prevention:**
- DO NOT remove `WS_CAPTION`. Instead, keep it and use `WM_NCCALCSIZE` to collapse the non-client area to zero pixels. This preserves DWM's animation pipeline while hiding the visual title bar.
- If `WM_NCCALCSIZE` is intercepted by Flutter (Pitfall 1a), use `DwmExtendFrameIntoClientArea` with `{-1,-1,-1,-1}` margins as the fallback.
- The fullscreen transition (`WS_POPUP` switch) is separate and should use `SetWindowPos` atomically (already proven in `project_fullscreen_win32_fix.md`).

**Detection:** After implementing, press Win+Left/Right to snap, then Win+Up to maximize. If the animation is not smooth (snaps instead of gliding), `WS_CAPTION` was removed.

**Phase:** WIN-05 (unified border removal)

---

### Pitfall 1c: Startup Border Flash (First Frame Problem)

**What goes wrong:** `CreateWindow` in `win32_window.cpp` creates the window with `WS_OVERLAPPEDWINDOW` (full native title bar + borders). Then Dart calls `setFrameless(true)` which removes `WS_CAPTION`. Between creation and the Dart call, ONE frame with the native title bar is visible -- the "startup flash."

**Why it happens:** The init sequence is:
```
CreateWindow (WS_OVERLAPPEDWINDOW) → show window → Flutter engine starts →
Dart main() → WindowService.init() → setFrameless(true)
```

The window is visible for several frames before `setFrameless` runs.

**Consequences:** User sees a brief flash of the native Windows title bar before it disappears. On slow machines or high-DPI displays, this can last 100-200ms.

**Prevention:**
- Option A: Create the window with `WS_POPUP` style initially (no borders at all), then add `WS_THICKFRAME` after Flutter is ready. This avoids the flash but may lose DWM shadow.
- Option B: Create the window off-screen at `(-32000, -32000)`, apply `WM_NCCALCSIZE` handling, then move to correct position after first frame.
- Option C (recommended): Apply `WM_NCCALCSIZE` handling in `Win32Window::OnCreate()` BEFORE `ShowWindow()`. The message handler runs during `CreateWindow`, so `WM_NCCALCSIZE` is processed before the window is visible.
- Option D: Use `SetWindowPos` with `SWP_HIDEWINDOW` to create hidden, apply frameless, then `ShowWindow`.

**Detection:** Use screen recording at 60fps. Play back frame by frame. If any frame shows the native title bar, the flash exists.

**Phase:** WIN-05 (unified border removal)

---

### Pitfall 1d: WM_NCHITTEST Conflict with DragToResizeArea

**What goes wrong:** The current codebase uses `DragToResizeArea` (from `window_manager` package) for resize edges. Adding C++ `WM_NCHITTEST` handling creates TWO resize systems that conflict: the C++ handler returns `HTLEFT`/`HTRIGHT` etc. for edge detection, while `DragToResizeArea` also detects edges via `MouseRegion` + `GestureDetector`.

**Why it happens:** `DragToResizeArea` works at the Flutter widget level (hit testing on transparent edge regions). `WM_NCHITTEST` works at the Win32 level (returning hit test constants to Windows). Both try to handle the same 8px edge areas.

**Consequences:** Double resize triggers, jittery edge behavior, or one system overriding the other depending on message processing order.

**Prevention:**
- If implementing native `WM_NCHITTEST` in C++, REMOVE `DragToResizeArea` from the widget tree. The native handler replaces it.
- If keeping `DragToResizeArea`, do NOT add `WM_NCHITTEST` handling. Pick one system.
- The recommended path: native `WM_NCHITTEST` is superior (zero-latency, no Flutter widget overhead), but requires Pitfall 1a to be resolved first.

**Detection:** Drag a window edge. If resize starts then stops, or starts twice, both systems are active.

**Phase:** WIN-05 (C++ WM_NCCALCSIZE)

---

### Pitfall 1e: DWM Corner Preference Reset on Snap/Maximize

**What goes wrong:** Windows 11 DWM resets `DWMWA_WINDOW_CORNER_PREFERENCE` during snap/maximize/restore transitions. The current `ApplyRoundedCorners` in `win32_window.cpp` is called once during creation, but not after state changes.

**Why it happens:** DWM re-applies default corner style (square) during certain transitions. The attribute must be re-applied after every `WM_SIZE` or `WM_NCCALCSIZE` cycle.

**Consequences:** After snapping or maximizing, the window corners become square instead of round. The fix in `project_window_corner_fix.md` addressed this partially, but a full WM_NCCALCSIZE implementation may re-trigger it.

**Prevention:**
- Call `ApplyRoundedCorners(hwnd)` in the `WM_SIZE` handler, not just in `OnCreate()`.
- The existing `ApplyRoundedCorners` function is correct; it just needs to be called more often.

**Detection:** On Win11: snap window left, snap right, maximize, restore. If corners are square at any point, the reset happened.

**Phase:** WIN-05

---

## 2. HLS ABR with BBA Algorithm (HLS-01)

### Pitfall 2a: Low-Latency Config Conflicts with ABR Buffer Requirements

**What goes wrong:** The current `FvpEngine` applies low-latency settings for ALL network streams:
- `fflags +nobuffer` (minimize buffering)
- `setBufferRange(drop:true)` (drop frames to maintain latency)
- Small `demux.buffer.ranges`

ABR requires the OPPOSITE: large buffers to measure bandwidth, preload segments, and absorb network jitter. Applying ABR without removing low-latency settings causes constant rebuffering and quality oscillation.

**Why it happens:** The network configuration in `fvp_engine.dart` applies uniformly based on URL detection (`isUrl()`). There is no stream-type routing.

**Consequences:** HLS streams rebuffer constantly. BBA algorithm sees empty buffer, selects lowest quality. User gets 360p on a 50Mbps connection.

**Prevention:**
- Route configuration by stream type BEFORE applying:
```dart
if (isHlsUrl(url)) {
  // ABR config: larger buffers, no frame drop
  _player.setProperty('demux.buffer.ranges', '3');
  // Do NOT set fflags +nobuffer
  // Do NOT set drop:true
} else {
  // Low-latency config: minimal buffer, drop frames
  _player.setProperty('fflags', '+nobuffer');
  _player.setProperty('demux.buffer.ranges', '1');
  _player.setProperty('demux.buffer.ranges', '1:drop:true');
}
```
- The `PathValidator.isUrl()` check is insufficient. Need `isHlsUrl()` that checks for `.m3u8` extension or HLS-specific query params.

**Detection:** Play an HLS stream. Monitor buffer level (via `MediaEngine` position polling). If buffer stays below 2 seconds, low-latency config is still active.

**Phase:** HLS-01

---

### Pitfall 2b: BBA Reservoir/Cushion Tuning Sensitivity

**What goes wrong:** BBA maps buffer occupancy to quality levels using a piecewise function with two thresholds: `reservoir` (minimum buffer, always select lowest quality) and `cushion` (buffer range for quality ramping). Poor tuning causes:

- **Reservoir too high:** Startup takes forever to ramp quality. User watches 360p for 30 seconds.
- **Reservoir too low:** Rebuffering on first network hiccup. Buffer has no safety margin.
- **Cushion too narrow:** Quality oscillates between two levels as buffer hovers near threshold.
- **Cushion too wide:** Quality ramp is too slow. User never reaches highest quality even with good bandwidth.

**Why it happens:** BBA's original paper uses `reservoir = 1 segment duration`, `cushion = max buffer - reservoir`. But optimal values depend on content segment duration (2s vs 6s vs 10s), available quality ladder, and typical network conditions.

**Consequences:** Either constant quality oscillation (user-visible stutter in quality) or unnecessarily low quality on good connections.

**Prevention:**
- Start with `reservoir = 2 * segmentDuration` (safety margin for 2 segments).
- Set `cushion = targetBufferLevel - reservoir` where `targetBufferLevel` is 30 seconds (common default).
- Add hysteresis: only switch quality when buffer crosses threshold by >1 segment duration, not just touches it.
- Log quality switches. If switches/minute > 3, increase hysteresis margin.

**Detection:** Play a 10-minute HLS stream with stable network. Count quality switches. More than 5 total = tuning problem.

**Phase:** HLS-01

---

### Pitfall 2c: MDK/FFmpeg HLS Demuxer Does Not Expose Segment-Level Metrics

**What goes wrong:** BBA needs per-segment download time and buffer level. MDK's `mdk::Player` API exposes `buffered()` (total buffered duration) but may NOT expose per-segment download metrics (segment URL, download time, bytes received). Without per-segment metrics, bandwidth estimation is impossible.

**Why it happens:** MDK wraps FFmpeg's HLS demuxer internally. FFmpeg's `hls.c` handles segment downloading, but this information is not surfaced through MDK's public API.

**Consequences:** Cannot implement accurate bandwidth estimation. Must fall back to FFmpeg's built-in ABR (which is less configurable) or estimate bandwidth from overall buffer fill rate (less accurate).

**Prevention:**
- First, verify what MDK exposes: check `mdk::Player` properties for `avformat.hls_*` and `demux.*` options.
- If per-segment metrics are unavailable, use the "buffer delta" approach: measure `buffered()` change over time to estimate effective download rate. This is less accurate but workable.
- Alternative: use FFmpeg's `hls_prefer_list` for coarse quality selection, and implement fine-grained control at the application level only if metrics are available.

**Detection:** Attempt to read `avformat.hls_current_stream` or similar property after segment switch. If null/empty, metrics are not exposed.

**Phase:** HLS-01 (research spike)

---

### Pitfall 2d: Quality Switch Causes Audio Glitch

**What goes wrong:** When BBA switches quality (e.g., 720p to 1080p), the decoder must flush and re-initialize with the new stream parameters. If the switch happens mid-segment, there is a brief audio/video glitch.

**Why it happens:** HLS quality switches should happen at segment boundaries (keyframe-aligned). If the implementation switches immediately on buffer threshold crossing (not waiting for segment boundary), the decoder gets a discontinuous stream.

**Consequences:** Brief audio pop or video freeze at each quality switch. With frequent oscillation (Pitfall 2b), this becomes very noticeable.

**Prevention:**
- Only switch quality at segment boundaries. Track current segment index and apply the new quality for the NEXT segment, not the current one.
- MDK/FFmpeg may handle this automatically if `hls_prefer_list` is used. Verify by testing with a multi-bitrate HLS stream and checking for audio continuity.
- Pre-buffer 1-2 seconds of the new quality before switching (overlap approach).

**Detection:** Play HLS stream with artificial bandwidth throttling. Listen for audio pops during quality transitions.

**Phase:** HLS-01

---

### Pitfall 2e: HLS URL Detection Ambiguity

**What goes wrong:** Not all HTTP URLs ending in `.m3u8` are HLS. Some CDN URLs use query parameters for format selection (`?format=hls`), and some HLS URLs don't have `.m3u8` in the URL (CDN rewrites). The `PathValidator.isUrl()` check is too coarse.

**Why it happens:** HLS is identified by the master playlist URL, which may or may not have a recognizable extension. CDN-specific URL patterns vary.

**Consequences:** Non-HLS HTTP streams get ABR treatment (wrong buffer config). HLS streams get low-latency treatment (constant rebuffering).

**Prevention:**
- Use a two-stage detection:
  1. URL pattern: contains `.m3u8` or `m3u8` query param -- likely HLS
  2. Content inspection: first response contains `#EXTM3U` -- confirmed HLS
- Apply ABR config only after confirmation. Default to low-latency for unknown URLs.
- MDK may handle this internally -- check if `setProperty('avformat.hls_prefer_list', ...)` has no effect on non-HLS URLs.

**Detection:** Open a non-HLS HTTP video URL. If ABR config is applied (large buffer, no frame drop), detection is wrong.

**Phase:** HLS-01

---

## 3. Platform Abstraction Layer (PLATFORM-03)

### Pitfall 3a: Interface-First Design Without Implementation Validation

**What goes wrong:** Defining platform interfaces (`PlatformWindowService`, `PlatformEngine`) without any macOS/Linux implementation means the interface is untested. Methods that work on Windows may have no equivalent on macOS (e.g., `WS_THICKFRAME` has no macOS analog) or may need completely different parameters.

**Why it happens:** Windows-specific concepts (HWND, WS_* styles, MonitorFromWindow) leak into the interface. When macOS implementation starts, the interface must be redesigned, breaking all consumers.

**Consequences:** Interface redesign at macOS implementation time. All Windows code that depends on the interface must be updated. The "platform abstraction" becomes a Windows abstraction that pretends to be cross-platform.

**Prevention:**
- Define interfaces in terms of USER INTENTS, not platform APIs:
  - BAD: `setWindowStyle(int style)` -- Windows-specific
  - GOOD: `setDecorated(bool decorated)` -- cross-platform intent
  - BAD: `setWindowPos(IntPtr hwnd, int x, int y, int w, int h)` -- Win32 specific
  - GOOD: `setWindowGeometry(Rect rect)` -- platform-independent
- For each interface method, write a one-line comment explaining what macOS/Linux would do:
  ```dart
  /// Enter fullscreen mode.
  /// Windows: WS_POPUP + monitor cover
  /// macOS: NSWindow.toggleFullScreen
  /// Linux: _NET_WM_STATE_FULLSCREEN
  Future<void> setFullscreen(bool value);
  ```
- If a method has NO macOS/Linux equivalent, it should NOT be in the interface. Keep it as a Windows-specific extension.

**Detection:** For each interface method, can you describe the macOS implementation in one sentence? If not, the method is too Windows-specific.

**Phase:** PLATFORM-03

---

### Pitfall 3b: NoopWindowBridge Becomes a Silent Failure Trap

**What goes wrong:** `NoopWindowBridge` returns silently for all operations (no-op). Code that depends on window state (e.g., `isFullscreen.value`) gets `false` from `NoopWindowBridge` even when the actual window is fullscreen. This creates subtle bugs where UI logic thinks the window is windowed when it's actually fullscreen.

**Why it happens:** `NoopWindowBridge` is designed for safe degradation, but callers assume the state is accurate. If the platform implementation is missing (macOS/Linux), the UI shows wrong state without any error.

**Consequences:** On macOS (future), the player UI shows windowed controls when the window is actually fullscreen. Keyboard shortcuts that check `isFullscreen.value` behave incorrectly.

**Prevention:**
- `NoopWindowBridge` should log a warning on first use: `debugPrint('WARNING: NoopWindowBridge active -- window operations are no-ops')`.
- Consider making `NoopWindowBridge` throw `UnsupportedError` for state queries (not just commands). This makes missing implementations fail loudly.
- Alternative: `NoopWindowBridge` could use platform channel fallbacks where available (e.g., `MethodChannel` to macOS runner for basic fullscreen).

**Detection:** On Windows, inject `NoopWindowBridge` manually and run the app. If any UI behavior is wrong, the consumer is relying on state accuracy.

**Phase:** PLATFORM-03

---

### Pitfall 3c: Singleton Migration Breaks Init Order

**What goes wrong:** The current init sequence in `main()` is:
```
1. WidgetsFlutterBinding.ensureInitialized()
2. fvp.registerWith()
3. SharedPreferences.getInstance()
4. SettingsStore.prewarm(prefs)
5. WindowBootstrap.init(prefs)
6. runApp(App(prefs))
```

Migrating singletons to DI (constructor injection) changes this to:
```
1. WidgetsFlutterBinding.ensureInitialized()
2. fvp.registerWith()
3. Create DI container
4. Register SharedPreferences
5. Register SettingsStore
6. Register WindowService
7. Register all other services
8. runApp(App(di: container))
```

If any service's constructor depends on another service that hasn't been registered yet, the DI container throws at startup.

**Why it happens:** Static singletons hide ordering dependencies. `LocaleService.I` works because `SettingsStore.prewarm()` was called earlier. With DI, the registration order must match the dependency graph.

**Consequences:** App crashes on startup with `StateError: Service not registered`. The error message may not indicate WHICH dependency is missing.

**Prevention:**
- Draw the dependency graph BEFORE migration (already documented in `PITFALLS.md` section 3b).
- Register in topological order: leaves first (`OsdService`, `PerfMonitor`), then dependents (`LocaleService`, `ThemeService`), then root (`WindowService`).
- Use lazy registration where possible: `GetIt.I.registerLazySingleton(() => LocaleService(GetIt.I<SettingsStore>()))`.
- Test init order by running `flutter test` after EACH singleton migration.

**Detection:** App fails to start after DI migration. Check registration order against dependency graph.

**Phase:** ARCH-03

---

### Pitfall 3d: SettingsStore Simplification Breaks Per-Field Error Isolation

**What goes wrong:** The current `SettingsStore` has 25+ `saveXxx()` methods and per-field `load()` with try-catch isolation. Simplifying to bulk serialization (JSON encode/decode of `AppSettings` object) means one corrupted field prevents loading ALL fields.

**Why it happens:** The per-field approach was designed so that if `volume` is corrupted in SharedPreferences, `brightness` still loads correctly. Bulk serialization loses this isolation.

**Consequences:** A single corrupted preference key (e.g., from a crash during write) causes the entire settings to reset to defaults. User loses all custom settings.

**Prevention:**
- Keep per-field validation in the deserializer, even with bulk serialization:
```dart
AppSettings load() {
  return AppSettings(
    volume: _sanitizeDouble(prefs.getDouble('volume'), 0.5, 0.0, 1.0),
    brightness: _sanitizeDouble(prefs.getDouble('brightness'), 1.0, 0.0, 2.0),
    // ... each field independently validated
  );
}
```
- The `_sanitizeDimension`, `_sanitizeCoordinate`, `_sanitizeRotation` helpers must survive the refactor.
- Write a test that corrupts ONE key and verifies all others still load.

**Detection:** Set `prefs.setDouble('volume', double.nan)` manually, then call `load()`. If other fields also return defaults, isolation is broken.

**Phase:** ARCH-02

---

## 4. Cross-Cutting Pitfalls

### Pitfall 4a: Triple Border Removal Becomes Quadruple

**What goes wrong:** The project already has THREE border removal mechanisms: (1) `window_manager`'s `setAsFrameless()`, (2) main.dart FFI `_restoreThickFrame()`, (3) app.dart init. Adding a C++ `WM_NCCALCSIZE` handler creates a fourth mechanism. If any two overlap, they fight each other.

**Why it happens:** Each layer was added to fix a specific symptom without removing the previous layer. The result is a fragile stack of patches.

**Consequences:** Border removal works on most machines but fails on specific DPI configurations, Win10 vs Win11, or after certain window state transitions. Debugging requires understanding all four layers.

**Prevention:**
- When implementing the C++ `WM_NCCALCSIZE` approach, REMOVE the other three mechanisms:
  - Remove `setAsFrameless()` call from `WindowService.init()`
  - Remove `_restoreThickFrame()` FFI call from main.dart
  - Remove any border-related code from app.dart init
- The C++ handler should be the SOLE owner of border removal.
- If `WM_NCCALCSIZE` doesn't work (Pitfall 1a), fall back to ONE mechanism, not four.

**Detection:** Comment out the C++ handler. If borders still disappear, another mechanism is active.

**Phase:** WIN-05

---

### Pitfall 4b: fvp HLS Config Overrides Persist Across File Opens

**What goes wrong:** `mdk::Player` properties set via `setProperty()` may persist across `open()` calls. If ABR config is set for an HLS stream, then the user opens a local file, the ABR config (large buffer, no frame drop) is still active.

**Why it happens:** MDK properties are player-instance level, not per-media. `setProperty` modifies the player state, not the media state.

**Consequences:** Local file playback uses ABR buffer settings (unnecessary memory usage, different latency characteristics).

**Prevention:**
- Reset network config before each `open()` call:
```dart
void open(String url) {
  _resetNetworkConfig();  // reset to defaults
  if (isHlsUrl(url)) {
    _applyAbrConfig();
  } else if (isLowLatencyUrl(url)) {
    _applyLowLatencyConfig();
  }
  _player.open(url);
}
```
- Document which properties are per-player vs per-media.

**Detection:** Open HLS stream, then open local file. Check `demux.buffer.ranges` value. If it's still the ABR value, config persisted.

**Phase:** HLS-01

---

### Pitfall 4c: ValueNotifier Incompatibility with Platform Abstraction

**What goes wrong:** The `WindowBridge` interface exposes `ValueNotifier<bool> isFullscreen`, `ValueNotifier<bool> isMaximized`, etc. These are Dart `ValueNotifier` objects. A macOS implementation using `NSWindow` notifications would need to update these notifiers from native callbacks, which requires platform channel threading awareness.

**Why it happens:** `ValueNotifier` is single-threaded (main isolate). Native callbacks from macOS (`NSWindowDelegate`) arrive on the platform thread. Updating a `ValueNotifier` from the platform thread without `SchedulerBinding.instance.scheduleTask` causes "setState called during build" errors.

**Consequences:** macOS implementation (future) has threading bugs. `isFullscreen.value` is updated from wrong thread, causing UI glitches or assertion failures.

**Prevention:**
- The `WindowService` already handles this for C++ events (via `MethodChannel.setMethodCallHandler` which runs on main isolate). Ensure the same pattern is documented for future platform implementations.
- Add a comment on each `ValueNotifier` in the interface: "Must be updated from main isolate only."
- Consider wrapping the notifier update in `WidgetsBinding.instance.addPostFrameCallback` for safety.

**Detection:** On macOS (future), rapid fullscreen toggle causes "setState during build" assertion.

**Phase:** PLATFORM-03 (interface design)

---

## Phase-Specific Warnings

| Phase | Pitfall | Severity | Mitigation |
|-------|---------|----------|------------|
| WIN-05: C++ WM_NCCALCSIZE | Flutter engine intercepts message (1a) | CRITICAL | Test with OutputDebugString first. If intercepted, use DwmExtendFrameIntoClientArea |
| WIN-05: Unified border removal | WS_CAPTION removal kills DWM animation (1b) | HIGH | Keep WS_CAPTION, use WM_NCCALCSIZE to hide non-client area |
| WIN-05: Startup flash | First frame shows native title bar (1c) | MEDIUM | Apply WM_NCCALCSIZE in OnCreate before ShowWindow |
| WIN-05: Hit test conflict | DragToResizeArea + WM_NCHITTEST double-handling (1d) | HIGH | Pick one system, remove the other |
| WIN-05: Corner reset | DWMWA_WINDOW_CORNER_PREFERENCE reset on snap (1e) | MEDIUM | Call ApplyRoundedCorners in WM_SIZE handler |
| HLS-01: Buffer config | Low-latency config conflicts with ABR (2a) | CRITICAL | Route config by stream type, not URL presence |
| HLS-01: BBA tuning | Reservoir/cushion sensitivity (2b) | HIGH | Start conservative, add hysteresis, log switches |
| HLS-01: MDK metrics | Per-segment download metrics unavailable (2c) | HIGH | Research spike first. Fallback to buffer-delta estimation |
| HLS-01: Quality switch | Audio glitch at segment boundary (2d) | MEDIUM | Only switch at segment boundaries, pre-buffer new quality |
| HLS-01: URL detection | HLS vs non-HLS HTTP ambiguity (2e) | MEDIUM | Two-stage detection: URL pattern + content inspection |
| PLATFORM-03: Interface design | Windows-specific methods in interface (3a) | HIGH | Define by user intent, not platform API |
| PLATFORM-03: Noop fallback | Silent failure on missing platform (3b) | MEDIUM | Log warning, consider throwing for state queries |
| ARCH-03: DI migration | Init order breakage (3c) | HIGH | Topological registration order, lazy singletons |
| ARCH-02: SettingsStore | Per-field error isolation loss (3d) | HIGH | Keep per-field validation in bulk serializer |
| Cross-cutting | Quadruple border removal (4a) | HIGH | Remove old mechanisms when adding C++ handler |
| Cross-cutting | fvp config persistence across opens (4b) | MEDIUM | Reset network config before each open() |

---

## Sources

- Anti-pattern memory: `anti_pattern_window_frameless.md` (3 failed C++ approaches, DWM animation dependency on WS_CAPTION)
- Window anti-patterns: `project_window_anti_patterns.md` (kernel coupling, god objects, over-abstraction)
- Fullscreen fix: `project_fullscreen_win32_fix.md` (WS_THICKFRAME invisible border root cause, SetWindowPos atomic)
- Window resize: `project_window_resize.md` (DragToResizeArea, WM_NCHITTEST Flutter interception)
- Native interfaces: `project_native_layer_interfaces.md` (MethodChannel design, WM_NCCALCSIZE/NCHITTEST/SIZING)
- Bridge design: `project_bridge_layer_design.md` (WindowBridge vs PlatformService, unified MethodChannel)
- Layer 8 analysis: `project_layer8_window_analysis.md` (5 files 337 lines, isOperating signal value)
- HLS ABR plan: `project_hls_abr_plan.md` (BBA algorithm, low-latency conflict, 4-phase implementation)
- Current code: `flutter_window.cpp` (HandleTopLevelWindowProc priority), `win32_window.cpp` (ApplyRoundedCorners)
- Prior pitfalls: `.planning/research/PITFALLS.md` (FFI pointer ownership, singleton migration, SettingsStore)

---

*Pitfall analysis: 2026-05-31 -- v1.2.1 milestone scope*
