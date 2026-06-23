# Domain Pitfalls: Flutter Desktop Cross-Platform Window Management

**Domain:** Flutter desktop media player expanding from Windows-only to Windows/Linux/macOS
**Researched:** 2026-06-23
**Overall confidence:** MEDIUM (Windows pitfalls HIGH from direct project experience; Linux/macOS pitfalls MEDIUM from ecosystem research and known Flutter issues)

---

## 1. Linux Pitfalls (X11 vs Wayland)

### Pitfall L1: Wayland Forbids Client-Side Window Positioning

**What goes wrong:** `window_manager`'s `setPosition()`, `setAlignment()`, and `Bounds` persistence all become no-ops on Wayland. The `xdg_shell` protocol intentionally forbids clients from controlling their own window placement -- this is a security feature, not a bug. Your `WindowPersistence` center-on-startup logic will silently fail.

**Why it happens:** Wayland's design philosophy is compositor-controlled placement. Unlike X11 where apps can position themselves freely, Wayland compositors (GNOME/Mutter, KDE/KWin, wlroots-based) own window placement decisions.

**Consequences:**
- Window always opens at compositor-chosen position (usually top-left or center)
- `WindowPersistence.saveBounds()` saves coordinates but `restoreBounds()` cannot apply them
- "Open centered on screen" feature breaks silently
- Multi-window positioning (if ever added) is impossible

**Prevention:**
- Detect Wayland at runtime: check `GDK_BACKEND` environment variable or `Platform.environment['XDG_SESSION_TYPE'] == 'wayland'`
- On Wayland, skip position persistence entirely -- only save/restore size
- Use `window_manager`'s size-only methods (`setSize`, `setMinimumSize`) which DO work on Wayland
- Document that position persistence is X11/macOS/Windows only

**Warning signs:** Window always opens at (0,0) or compositor default regardless of saved position. No error thrown.

**Detection:** Run on GNOME Wayland. Save window position, close, reopen. If position differs from saved, Wayland positioning block is active.

**Phase:** LINUX-01 (initial port)

---

### Pitfall L2: Wayland Has No Global Coordinate System

**What goes wrong:** Code that uses `windowManager.getPosition()` to compute relative placement (e.g., OSD positioning, popup menus relative to window) returns meaningless values on Wayland. Wayland windows don't have global screen coordinates -- each window exists in its own coordinate space.

**Why it happens:** Wayland's security model prevents apps from knowing where they are on screen or where other windows are. This prevents keyloggers/screen-scrapers but breaks position-dependent UI.

**Consequences:**
- `windowManager.getPosition()` returns (0,0) or last-known X11 position on Wayland
- Any logic that computes "screen center - window offset" breaks
- Popup positioning relative to screen coordinates fails

**Prevention:**
- Never use absolute screen coordinates for in-app positioning
- Use Flutter's `Overlay` and `CompositedTransform` for popup positioning (widget-relative, not screen-relative)
- For fullscreen detection, use `window_manager`'s `isFullScreen()` which queries the compositor state, not coordinates

**Warning signs:** OSD or popup appears at wrong position on Wayland but correct on X11.

**Detection:** Open the speed button popup or OSD overlay on GNOME Wayland. If it appears at screen origin instead of near the triggering widget, absolute coordinates are being used.

**Phase:** LINUX-01

---

### Pitfall L3: X11/Wayland Session Detection Is Fragile

**What goes wrong:** The app needs to behave differently on X11 vs Wayland, but detecting which session is active is unreliable. `XDG_SESSION_TYPE` may be missing, `WAYLAND_DISPLAY` may be set even under XWayland, and users can run X11 apps under Wayland via XWayland.

**Why it happens:** There is no single canonical way to detect the display server. Environment variables are set by the session manager, not the app. XWayland adds a layer where X11 APIs work but Wayland behavior applies to the compositor.

**Consequences:**
- App applies X11 window positioning logic under Wayland (fails silently)
- App skips Wayland-specific workarounds when running under XWayland
- Feature flags based on session type produce wrong behavior

**Prevention:**
- Use a multi-signal detection approach:
```dart
bool get isWayland {
  if (Platform.environment['XDG_SESSION_TYPE'] == 'wayland') return true;
  if (Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty == true) return true;
  return false;
}
```
- Prefer capability detection over session detection: try `setPosition()` and check if it worked, rather than guessing based on session type
- Accept that XWayland is a hybrid: some X11 APIs work, some don't. Test on both pure X11 and XWayland.

**Warning signs:** Features work on X11 but break on XWayland, or vice versa.

**Phase:** LINUX-01

---

### Pitfall L4: GTK3 vs GTK4 Embedder Differences

**What goes wrong:** Flutter's Linux embedder uses GTK3 (as of Flutter 3.x). `window_manager` and other plugins interact with GTK3 APIs. If the target system uses GTK4 or if Flutter migrates to GTK4, window management APIs change significantly. GTK4 removed `gtk_window_set_decorated()`, changed resize behavior, and altered CSD (Client-Side Decoration) handling.

**Why it happens:** GTK3 and GTK4 have different window management APIs. Flutter's Linux embedder is pinned to GTK3, but the ecosystem is migrating to GTK4. Plugin authors may target different GTK versions.

**Consequences:**
- `window_manager` may not compile if GTK headers don't match system version
- CSD vs SSD (Server-Side Decorations) conflicts: GNOME forces CSD, KDE uses SSD
- Custom title bar rendering may conflict with GTK's own decoration rendering

**Prevention:**
- Pin `window_manager` to a tested version and verify GTK3 headers are available at build time
- On GNOME (CSD): Flutter's custom title bar may coexist with GTK's header bar -- test for double-rendering
- On KDE (SSD): Custom title bar works as expected since the compositor doesn't draw decorations
- Document the GTK3 dependency and monitor Flutter's GTK4 migration (tracked in flutter/flutter#126955)

**Warning signs:** Double title bar on GNOME. Build failures on systems with only GTK4 dev headers.

**Phase:** LINUX-01

---

### Pitfall L5: X11 Window Manager Quirks (Tiling WMs, Compositors)

**What goes wrong:** X11 window managers like i3, Sway (Wayland), and bspwm intercept window geometry requests. `windowManager.setSize()` may be overridden by the tiling layout. `setAlwaysOnTop()` may be ignored or cause focus-stealing alerts.

**Why it happens:** Tiling WMs enforce their own layout algorithm. Floating window requests can be denied or overridden. Some compositors (like picom) add their own shadows and transparency that conflict with Flutter's rendering.

**Consequences:**
- Window size/position changes are ignored by tiling WM
- `setAlwaysOnTop()` has no effect or causes compositor warnings
- Frameless window borders reappear because the WM adds its own decorations

**Prevention:**
- Accept that tiling WMs will control window geometry. Don't fight it.
- For `setAlwaysOnTop()`, use `_NET_WM_STATE_ABOVE` X11 hint (which most WMs respect) rather than `window_manager`'s generic method
- Test on at least: GNOME (floating), KDE (floating), i3 (tiling), Sway (Wayland tiling)
- Document that tiling WM behavior is unsupported but should degrade gracefully

**Warning signs:** User reports on i3/Sway that window size can't be changed or decorations appear.

**Phase:** LINUX-02 (polish)

---

### Pitfall L6: Fractional Scaling Blurs Flutter Content on Linux

**What goes wrong:** Linux fractional scaling (125%, 150%, 175%) causes Flutter content to render at 1x and then get scaled up by the compositor, resulting in blurry text and UI. This is a known Flutter/Linux issue.

**Why it happens:** Flutter's Linux embedder renders at the logical DPI, but the compositor scales the buffer. Unlike Windows (which has per-monitor DPI awareness) and macOS (which has Retina backing), Linux fractional scaling is compositor-dependent and often blurry.

**Consequences:**
- Text and UI elements appear blurry at 125%/150% scaling
- User reports "app looks fuzzy" on HiDPI Linux displays
- No app-side fix exists -- it's an embedder limitation

**Prevention:**
- Set `GDK_SCALE=2` environment variable to force integer scaling (crisp but larger)
- Monitor Flutter engine issues for fractional scaling fixes
- Accept this as a known limitation and document it
- On GNOME, users can switch to 100% or 200% scaling for crisp rendering

**Warning signs:** User reports blurry text on Linux with fractional DPI. Looks fine at 100% or 200%.

**Phase:** LINUX-02 (document, no code fix)

---

## 2. macOS Pitfalls

### Pitfall M1: NSWindow Thread Safety Crashes

**What goes wrong:** macOS Cocoa APIs require ALL `NSWindow` operations on the main thread. Flutter's platform channel callbacks may arrive on the platform thread (not the main thread). Calling `NSWindow.setFrame()`, `NSWindow.toggleFullScreen()`, or invalidating drag regions from a background thread causes `NSInternalInconsistencyException` crashes.

**Why it happens:** Flutter's macOS embedder uses a separate platform thread for channel communication. `window_manager`'s macOS implementation must dispatch all `NSWindow` calls to the main thread via `dispatch_async(dispatch_get_main_queue(), ...)`. If any code path skips this dispatch, the app crashes.

**Consequences:**
- Random crashes during fullscreen toggle, window resize, or drag operations
- Crash message: `"NSWindow drag regions should only be invalidated from the Main Thread"`
- Crashes are non-deterministic (depend on timing), making them hard to reproduce

**Prevention:**
- Verify `window_manager`'s macOS implementation dispatches to main thread (check source: `macos/Classes/WindowManager.swift`)
- If writing custom macOS code (Swift/ObjC), ALWAYS wrap NSWindow calls:
```swift
DispatchQueue.main.async {
    self.window?.setFrame(newFrame, display: true)
}
```
- For frameless windows: `mouseDownCanMoveWindow` must be overridden on the `contentView`, and drag region invalidation must happen on main thread
- Test with thread sanitizer enabled: `flutter run --enable-experiment=impeller -d macos`

**Warning signs:** Random crash during fullscreen toggle. Crash log mentions `NSWindow` + thread assertion.

**Detection:** Rapidly toggle fullscreen 20+ times. If crash occurs, thread safety issue exists.

**Phase:** MACOS-01 (initial port)

---

### Pitfall M2: NSWindowStyleMask Manipulation Breaks Window Dragging

**What goes wrong:** Removing `NSWindowStyleMask.titled` (the macOS equivalent of `WS_CAPTION`) to create a frameless window also removes the title bar drag region. The window becomes immovable unless custom drag handling is implemented.

**Why it happens:** On macOS, the title bar is the drag handle. Without `NSWindowStyleMask.titled`, there's no native drag region. `window_manager`'s `setAsFrameless()` removes the titled style, relying on Flutter's `DragToResizeArea` or custom `mouseDownCanMoveWindow` for drag.

**Consequences:**
- Window cannot be dragged by the title bar area
- If Flutter's `startDragging()` is not wired up correctly, the window is stuck
- On macOS, `startDragging()` calls `NSWindow.performWindowDrag()` which requires the titled style to be present (or custom `contentView` override)

**Prevention:**
- Keep `NSWindowStyleMask.titled` and hide the title bar text using `titleVisibility = .hidden` instead of removing the style mask
- This preserves the drag region while hiding the visual title bar
- Alternatively, override `mouseDownCanMoveWindow` on the Flutter view's `NSView` to return `true`
- Test that `startDragging()` from `window_manager` works after frameless setup

**Warning signs:** Window can't be dragged on macOS after setting frameless. Works on Windows.

**Phase:** MACOS-01

---

### Pitfall M3: macOS Fullscreen Uses Different Paradigm Than Windows

**What goes wrong:** macOS fullscreen (`NSWindow.toggleFullScreen()`) creates a new "Space" (virtual desktop) with a transition animation. Windows fullscreen (`WS_POPUP` + monitor cover) is instant and in-place. Code that assumes fullscreen is instant (like the Windows `SetWindowPos` atomic approach) breaks on macOS.

**Why it happens:** macOS fullscreen is a system-level feature with:
- 1-second animation to new Space
- Menu bar auto-hide
- Different `NSWindowStyleMask` during fullscreen
- `windowWillEnterFullScreen` / `windowDidEnterFullScreen` delegate callbacks with timing gaps

**Consequences:**
- If code reads `isFullscreen` immediately after calling `setFullScreen(true)`, it returns `false` (animation not complete)
- Window geometry queries during the transition return intermediate values
- Exiting fullscreen has a different animation and timing

**Prevention:**
- Use delegate callbacks, not polling, to detect fullscreen state:
```dart
// Wait for delegate callback, not immediate check
await windowManager.setFullScreen(true);
// State is updated via WindowListener callbacks, not return value
```
- The `WindowBridge.mode` ValueNotifier should be updated by the `windowDidEnterFullScreen` callback, not by the `setFullScreen` return
- Add a "transitioning" state to `WindowMode` if fullscreen toggle UI needs to show intermediate feedback
- Test that keyboard shortcuts (F key) work during the fullscreen animation

**Warning signs:** UI shows wrong fullscreen state during animation. F key does nothing during 1-second transition.

**Phase:** MACOS-01

---

### Pitfall M4: macOS Retina/HiDPI Texture Rendering

**What goes wrong:** Flutter's texture rendering on macOS uses `FlutterTextureRegistry`. The `fvp` plugin's texture may render at 1x resolution on Retina displays, appearing blurry. The backing store scale factor must match `NSScreen.backingScaleFactor` (typically 2.0).

**Why it happens:** macOS Retina displays have a 2x pixel ratio. If the texture buffer is created at logical resolution (e.g., 1920x1080) instead of pixel resolution (3840x2160), the compositor upscales it, causing blur.

**Consequences:**
- Video appears blurry on Retina MacBooks and iMacs
- UI elements (Flutter widgets) are crisp, but video texture is soft
- User reports "video quality looks worse on Mac than Windows"

**Prevention:**
- Verify `fvp` creates textures at the correct scale factor
- Check `fvp` source for `NSScreen.main?.backingScaleFactor` usage
- If `fvp` doesn't handle this, it's an upstream issue -- file against `fvp` repo
- Workaround: force texture resolution to 2x logical size

**Warning signs:** Crisp Flutter UI but blurry video on Retina displays. Looks fine on non-Retina external monitor.

**Phase:** MACOS-02 (polish)

---

### Pitfall M5: macOS App Nap Kills Background Playback

**What goes wrong:** macOS "App Nap" suspends or throttles apps that are not visible or are occluded. If the user minimizes the player or covers it with another window, macOS may pause the playback timer, causing audio stutter or position polling to freeze.

**Why it happens:** macOS aggressively manages power. Apps that are fully occluded or minimized are candidates for App Nap. Flutter's Dart isolate may be throttled, causing `Timer.periodic` (used by `PositionPoller`) to fire irregularly.

**Consequences:**
- Audio continues (native decoder runs independently) but position updates freeze
- When the window is restored, position jumps forward (timer catches up)
- `PositionPoller` reports stale position during App Nap

**Prevention:**
- Disable App Nap for the process: `NSProcessInfo.processInfo.processInfo.disableAutomaticTermination("Media playback")`
- Or use `NSProcessInfo.processInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled], reason: "Playback")`
- This can be done via platform channel from Dart
- Alternative: use `NSBackgroundActivityScheduler` for position polling that survives App Nap

**Warning signs:** Position bar freezes while minimized. Audio keeps playing. Position jumps when window is restored.

**Phase:** MACOS-01 (critical for media player)

---

### Pitfall M6: macOS Sandbox Restrictions Block File Access

**What goes wrong:** If the app is sandboxed (required for Mac App Store), file access is restricted to user-selected files via `NSOpenPanel`. Direct path access to arbitrary directories (like the current `FolderScanner` does) fails with permission errors.

**Why it happens:** macOS sandbox enforces `com.apple.security.files.user-selected.read-only` entitlement. Opening a file via drag-and-drop or `NSOpenPanel` grants temporary access, but the path cannot be reused after app restart without a security-scoped bookmark.

**Consequences:**
- `FolderScanner` can't scan arbitrary directories
- Playlist persistence saves paths that become inaccessible after restart
- Drag-and-drop works once but saved paths fail on next launch

**Prevention:**
- Use security-scoped bookmarks to persist file access across launches
- For non-App-Store distribution: disable sandbox in entitlements
- For App Store: implement `NSSecurityScopedBookmark` creation on file open, and resolve bookmarks on restore
- This is a significant architecture change for `PlaylistStore` and `FolderScanner`

**Warning signs:** Files opened previously can't be reopened after app restart. "Operation not permitted" errors in console.

**Phase:** MACOS-03 (App Store prep, if applicable)

---

## 3. ARM Architecture Pitfalls

### Pitfall A1: macOS Apple Silicon (ARM64) Native Plugin Compilation

**What goes wrong:** Native plugins with C/C++ code (like `fvp` which wraps MDK/FFmpeg) must provide ARM64 binaries for macOS. If `fvp` ships only x86_64 binaries, the app runs under Rosetta 2 emulation with performance penalty.

**Why it happens:** MDK/FFmpeg native libraries must be compiled for `arm64-apple-darwin`. If `fvp` bundles pre-built x86_64 `.dylib` files, they work via Rosetta but lose native performance.

**Consequences:**
- Video decoding runs at 50-70% of native ARM64 performance
- Battery drain is higher than native
- User reports "app is slow on M1/M2/M3 Macs"

**Prevention:**
- Check `fvp` pubspec for macOS binary architecture: `file libfvp.dylib` should show `arm64`
- If `fvp` doesn't provide ARM64, request it or build MDK/FFmpeg from source for arm64
- Universal binary (x86_64 + arm64) is the ideal solution
- Test on actual Apple Silicon hardware, not just Rosetta

**Warning signs:** Activity Monitor shows "Intel" next to the process name on Apple Silicon Mac.

**Phase:** MACOS-01

---

### Pitfall A2: Windows ARM64 Flutter Plugin Availability

**What goes wrong:** Flutter's Windows ARM64 support is newer and less mature. Many plugins assume x86_64 and may not compile or run on Windows ARM64 devices (Surface Pro X, Snapdragon laptops).

**Why it happens:** Windows ARM64 has a smaller market share. Plugin authors may not test on ARM64. Native dependencies (DLLs) must be compiled for ARM64.

**Consequences:**
- `window_manager` may work (pure Dart + Win32 API which has ARM64 support)
- `fvp` may not have ARM64 Windows binaries
- Build failures or runtime crashes on ARM64 Windows

**Prevention:**
- Check each native plugin for ARM64 Windows support before committing to the platform
- For `fvp`: verify MDK provides `arm64-windows` binaries
- If ARM64 Windows is a target, test early and often -- don't treat it as an afterthought
- Consider ARM64 Windows as a "best effort" tier rather than fully supported

**Warning signs:** Build errors on ARM64 Windows about missing `.dll` or architecture mismatch.

**Phase:** ARM-01 (if Windows ARM64 is a target)

---

### Pitfall A3: Linux ARM64 (Raspberry Pi) Build Toolchain

**What goes wrong:** Building Flutter for Linux ARM64 requires cross-compilation or native ARM64 build environment. The toolchain setup is significantly more complex than x86_64 Linux.

**Why it happens:** Flutter's Linux build uses the host toolchain. Building on x86_64 for ARM64 requires cross-compilation flags and ARM64 sysroot. Building natively on ARM64 (e.g., Raspberry Pi) is slow.

**Consequences:**
- Build times are 5-10x longer on ARM64 Linux
- Some plugins may not compile for ARM64 Linux at all
- CI/CD pipeline needs ARM64 runners or cross-compilation setup

**Prevention:**
- Use Docker with ARM64 image for cross-compilation: `docker run --platform linux/arm64`
- Or build natively on ARM64 hardware (slow but reliable)
- Check `fvp` for Linux ARM64 binary availability
- Consider Linux ARM64 as unsupported unless there's specific user demand

**Warning signs:** Build errors about missing `aarch64-linux-gnu` toolchain. Linker errors about architecture mismatch.

**Phase:** ARM-02 (if Linux ARM64 is a target)

---

## 4. Cross-Platform Abstraction Pitfalls

### Pitfall C1: Platform Interface Leaks Windows Concepts

**What goes wrong:** The current `WindowBridge` interface is clean (6 commands, 4 states), but extending it for cross-platform risks leaking Windows-specific concepts. Methods like `setFrameless(bool)` map cleanly to macOS (`NSWindowStyleMask`), but methods like `setWindowStyle(int)` or `setThickFrame(bool)` have no macOS/Linux equivalent.

**Why it happens:** The developer knows Windows deeply and naturally models the interface around Win32 concepts. macOS and Linux have fundamentally different window management models.

**Consequences:**
- Interface redesign when macOS implementation starts (already predicted in existing PITFALLS.md)
- Windows-specific methods become dead code on other platforms
- Consumers of the interface must handle platform-specific behavior

**Prevention:**
- Current `WindowBridge` is already well-designed (intent-based, not API-based). Protect this property.
- Every new method must have a one-line macOS and Linux equivalent documented before adding it
- If a method only works on one platform, it should be a platform-specific extension, not in the interface
- Use `Platform.isWindows` guards in consumers, not `if (bridge is NoopWindowBridge)` checks

**Warning signs:** Interface methods that say "Windows only" in their docs. `UnsupportedError` thrown on macOS/Linux for basic operations.

**Phase:** LINUX-01, MACOS-01 (interface evolution)

---

### Pitfall C2: NoopWindowBridge Masks Platform Gaps

**What goes wrong:** The existing `NoopWindowBridge` returns safe defaults for all operations. On macOS/Linux, if the real implementation isn't ready, `NoopWindowBridge` makes the app appear to work while silently failing to control the window. The UI shows "windowed" state when the window is actually fullscreen.

**Why it happens:** `NoopWindowBridge` was designed for testing, not for production platform gaps. But during cross-platform rollout, it may be used as a placeholder.

**Consequences:**
- User presses F for fullscreen -- nothing visual happens but `mode.value` stays `windowed`
- User closes fullscreen via OS shortcut -- `mode.value` still says `windowed`
- Keyboard shortcuts that check `isFullscreen` behave incorrectly

**Prevention:**
- Log a warning on first `NoopWindowBridge` use in debug mode
- Make state queries (`mode`, `windowSize`) throw `UnsupportedError` in `NoopWindowBridge` to fail fast
- Never ship `NoopWindowBridge` to production -- either implement the platform or disable the feature
- The existing warning in PITFALLS.md (3b) applies here too

**Warning signs:** App "works" on macOS but fullscreen button does nothing. No error in console.

**Phase:** LINUX-01, MACOS-01

---

### Pitfall C3: window_manager Plugin Version Fragmentation

**What goes wrong:** `window_manager` is a community plugin with varying platform support quality. Its Linux implementation has known Wayland gaps. Its macOS implementation has threading edge cases. Pinning to one version means missing fixes; upgrading may introduce regressions on a platform you just fixed.

**Why it happens:** The plugin maintainer balances 3 platforms with different maturity levels. A fix for macOS may break Linux. A Wayland fix may require GTK API changes.

**Consequences:**
- Upgrading `window_manager` to fix macOS issues breaks Linux behavior
- Each platform requires a different tested version
- Plugin issues become your issues with no workaround

**Prevention:**
- Test `window_manager` upgrades on ALL supported platforms before merging
- Maintain a compatibility matrix: `window_manager` version x platform x behavior
- If `window_manager` becomes a blocker, consider forking or writing platform-specific implementations
- The existing `Win32PlatformFullscreen` bypass pattern (bypassing `window_manager` for Windows fullscreen) may need to be replicated for macOS/Linux

**Warning signs:** `window_manager` upgrade fixes one platform but breaks another. Open issues on GitHub with no response.

**Phase:** LINUX-01, MACOS-01

---

### Pitfall C4: DragToResizeArea Widget Is Platform-Agnostic But Behavior Isn't

**What goes wrong:** `DragToResizeArea` (from `window_manager`) provides resize handles at window edges using Flutter widget hit-testing. This works on all platforms visually, but the underlying resize mechanism differs: Windows uses `WM_NCHITTEST`, macOS uses `NSWindow` resize edges, Linux uses GTK window resize.

**Why it happens:** The widget provides a unified interface, but the platform channel calls differ. On Windows, native `WM_NCHITTEST` is superior (Pitfall 1d from existing PITFALLS.md). On macOS, the native resize behavior may conflict with `DragToResizeArea`.

**Consequences:**
- On Windows: `DragToResizeArea` + native `WM_NCHITTEST` = double-handling (already documented)
- On macOS: `DragToResizeArea` may fight with `NSWindow`'s built-in resize behavior
- On Linux: Resize behavior depends on compositor and may not respect `DragToResizeArea` at all

**Prevention:**
- On Windows: Remove `DragToResizeArea` when using native `WM_NCHITTEST` (existing plan)
- On macOS: Test if `DragToResizeArea` works alongside `NSWindow` resize. If conflicts, remove it and rely on native resize.
- On Linux: `DragToResizeArea` may be the ONLY resize mechanism if GTK doesn't provide resize handles for frameless windows
- Document per-platform resize strategy

**Warning signs:** Resize jitter on macOS. Double-resize on Windows. No resize on Linux.

**Phase:** LINUX-01, MACOS-01

---

### Pitfall C5: Platform Channel Threading Model Differs Per OS

**What goes wrong:** `MethodChannel` callbacks run on the platform thread, but the platform thread differs per OS:
- **Windows:** Main thread (UI thread)
- **macOS:** Platform thread (separate from main thread)
- **Linux:** Main thread (GTK main loop)

Updating `ValueNotifier` objects (used by `WindowBridge`) from a non-main thread causes "setState during build" assertions on macOS.

**Why it happens:** Flutter's threading model is documented but not uniform across platforms. macOS's separation of main thread and platform thread is the primary source of issues.

**Consequences:**
- macOS: Crashes or assertion failures when `WindowListener` callbacks update `ValueNotifier`
- Windows/Linux: Works fine (same thread)
- Code that works on Windows may crash on macOS

**Prevention:**
- Always update `ValueNotifier` via `WidgetsBinding.instance.addPostFrameCallback` when coming from platform channels
- Or use `SchedulerBinding.instance.scheduleTask` to ensure main thread execution
- The existing `WindowService` already uses `WindowListener` which runs on the platform thread -- verify this is safe on macOS
- Add a comment: "macOS: WindowListener callbacks arrive on platform thread, not main thread"

**Warning signs:** Random "setState during build" on macOS. Works perfectly on Windows.

**Phase:** MACOS-01

---

## 5. Cross-Cutting Pitfalls

### Pitfall X1: Testing Matrix Explosion

**What goes wrong:** Three platforms x two display servers (X11/Wayland) x two architectures (x86_64/ARM64) = 12+ test configurations. Manual testing on all of them is impractical.

**Why it happens:** Each combination has unique quirks. A bug on GNOME Wayland ARM64 may not reproduce on GNOME X11 x86_64.

**Consequences:**
- Bugs ship to users on untested configurations
- CI/CD matrix becomes expensive
- Developer only tests on their own machine (Windows x86_64)

**Prevention:**
- Define tier system:
  - **Tier 1 (always test):** Windows x86_64, macOS ARM64, Ubuntu GNOME X11 x86_64
  - **Tier 2 (test before release):** Ubuntu GNOME Wayland x86_64, macOS x86_64
  - **Tier 3 (best effort):** Linux ARM64, Windows ARM64, KDE, Sway, i3
- Use GitHub Actions matrix builds for Tier 1
- Manual test on Tier 2 before releases
- Accept community reports for Tier 3

**Warning signs:** Bug reports from Tier 3 users. "Works on my machine" syndrome.

**Phase:** LINUX-01, MACOS-01

---

### Pitfall X2: Build System Complexity Multiplies Per Platform

**What goes wrong:** Each platform requires different build tooling:
- **Windows:** Visual Studio, MSVC, Windows SDK
- **macOS:** Xcode, macOS SDK, code signing
- **Linux:** GCC/Clang, GTK3 dev headers, pkg-config

CI/CD must support all three. Local development on one platform can't verify the others.

**Consequences:**
- Linux-specific build failures only discovered in CI
- macOS code signing issues block releases
- GTK3 header version mismatches cause cryptic linker errors

**Prevention:**
- Use Flutter's built-in build system (`flutter build`) which handles platform specifics
- For native code: document required SDK versions in CONTRIBUTING.md
- CI matrix: use `macos-latest`, `ubuntu-latest`, `windows-latest` runners
- Test release builds, not just debug (different optimization levels may expose different bugs)

**Warning signs:** CI passes but release build fails. Linux build works on Ubuntu but not Fedora.

**Phase:** LINUX-01, MACOS-01

---

## Phase-Specific Warnings

| Phase | Pitfall | Severity | Mitigation |
|-------|---------|----------|------------|
| LINUX-01: Initial port | L1: Wayland no positioning | HIGH | Skip position save on Wayland, size-only |
| LINUX-01: Initial port | L2: No global coordinates | HIGH | Use widget-relative positioning, not screen coords |
| LINUX-01: Initial port | L3: Session detection fragile | MEDIUM | Multi-signal detection + capability probing |
| LINUX-01: Initial port | L4: GTK3 vs GTK4 | MEDIUM | Pin GTK3, test CSD vs SSD on GNOME/KDE |
| LINUX-02: Polish | L5: Tiling WM quirks | LOW | Accept degradation, don't fight tiling WMs |
| LINUX-02: Polish | L6: Fractional scaling blur | MEDIUM | Document as known limitation, no code fix |
| MACOS-01: Initial port | M1: NSWindow thread safety | CRITICAL | Dispatch all NSWindow calls to main thread |
| MACOS-01: Initial port | M2: Frameless breaks dragging | HIGH | Keep titled style, hide titleVisibility |
| MACOS-01: Initial port | M3: Fullscreen paradigm difference | HIGH | Use delegate callbacks, not polling |
| MACOS-02: Polish | M4: Retina texture blur | MEDIUM | Verify fvp scale factor handling |
| MACOS-01: Initial port | M5: App Nap kills playback | HIGH | Disable App Nap via NSProcessInfo |
| MACOS-03: App Store | M6: Sandbox blocks file access | HIGH | Security-scoped bookmarks |
| ARM-01: macOS ARM64 | A1: Plugin ARM64 binaries | HIGH | Verify fvp ships arm64 macOS binaries |
| ARM-02: Windows ARM64 | A2: Plugin ARM64 availability | MEDIUM | Check each plugin, consider unsupported |
| ARM-03: Linux ARM64 | A3: Build toolchain complexity | LOW | Docker cross-compile or native build |
| Cross-platform | C1: Interface leaks Windows concepts | HIGH | Intent-based methods, document per-platform |
| Cross-platform | C2: NoopWindowBridge masks gaps | MEDIUM | Throw on state queries, never ship to prod |
| Cross-platform | C3: window_manager version fragmentation | HIGH | Test all platforms before upgrading |
| Cross-platform | C4: DragToResize platform differences | MEDIUM | Per-platform resize strategy |
| Cross-platform | C5: Channel threading differs per OS | HIGH | Always update ValueNotifier on main thread |
| Cross-cutting | X1: Test matrix explosion | MEDIUM | Tier system: T1 always, T2 pre-release |
| Cross-cutting | X2: Build system complexity | MEDIUM | CI matrix + documented SDK requirements |

---

## Sources

- Existing anti-patterns: `anti_pattern_window_frameless.md` (WS_CAPTION removal, DWM animation dependency)
- Existing pitfalls: `.planning/research/PITFALLS.md` (Win32 frameless, HLS ABR, platform abstraction)
- Window bridge design: `project_bridge_layer_design.md` (WindowBridge interface, 3 bridge domains)
- Window cross-platform strategy: `project_window_cross_platform.md` (window_manager as cross-platform, Win32 FFI as platform-specific)
- Fullscreen fix: `project_fullscreen_win32_fix.md` (WS_THICKFRAME 7px gap, SetWindowPos atomic)
- Native interfaces: `project_native_layer_interfaces.md` (MethodChannel unified, WM_NCCALCSIZE/NCHITTEST)
- Flutter desktop docs: docs.flutter.dev/platform-integration/desktop
- Flutter macOS embedder: `flutter/engine/shell/platform/darwin/macos/` (NSWindow thread model)
- Flutter Linux embedder: `flutter/engine/shell/platform/linux/` (GTK3, fl_view, xdg_shell)
- Wayland protocol: `xdg_shell` spec (no client-side positioning by design)
- window_manager GitHub: leanflutter/window_manager (Linux/macOS issues, Wayland gaps)

---

*Pitfall analysis: 2026-06-23 -- Cross-platform window management expansion scope*
