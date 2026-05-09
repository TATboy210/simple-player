# Domain Pitfalls: Flutter Desktop Media Player

**Domain:** Frameless window media player (Windows, Flutter + fvp + window_manager)
**Researched:** 2026-05-09
**Overall confidence:** HIGH (codebase analysis + reference project + known ecosystem issues)

---

## Critical Pitfalls

Mistakes that cause crashes, data loss, or require rewrites.

### 1. Fullscreen Race Condition with Frameless Window

**What goes wrong:** `window_manager`'s `setFullScreen()` is unreliable on frameless windows. Calling `setFullScreen(true)` after `setAsFrameless()` can cause: taskbar remains visible, window position not restored on exit, rapid toggle crashes the app.

**Why it happens:** `setFullScreen()` was designed for framed windows. On frameless, it fights with the OS's own fullscreen API. The native side may reference a destroyed window handle if `dispose()` races with an in-flight `setFullScreen` platform channel call.

**Consequences:** App hangs on fullscreen toggle. Window stuck in borderless state. Position/size not restored after exiting fullscreen.

**Prevention:**
- Manual fullscreen: `setSize(screenSize)` + `setPosition(Offset.zero)` instead of `setFullScreen(true)`
- Fullscreen reentry guard: boolean `_isFullscreenToggling` prevents concurrent toggles
- Restore previous geometry from saved state, not from `WindowManager.getSize()` during toggle
- Reference pattern from D:\player_flutter: manual setSize/setPosition for frameless fullscreen

**Detection:** Rapidly pressing F11 causes app freeze or position drift.

**Phase:** Window chrome phase (Phase 1). Must be solved before any UI work.

---

### 2. FvpEngine Dispose Ordering

**What goes wrong:** Calling `_player.dispose()` before stopping the position poller or before pending callbacks complete causes crashes in mdk native code. The `_player.textureId.removeListener()` must happen before `_player.dispose()`.

**Why it happens:** mdk's native player has internal threads. Disposing while callbacks are in-flight creates use-after-free in native memory. The current code (fvp_engine.dart:533-554) has correct ordering but it's fragile — any refactor could break it.

**Consequences:** EXC_BAD_ACCESS / segfault on Windows. Hard crash with no stack trace.

**Prevention:**
- Dispose order must be: `_disposed = true` → poller → callbacks → remove listeners → player → ValueNotifiers
- Never reorder without verifying native thread safety
- Add a test that verifies dispose order (FakeEngine can verify sequence)

**Detection:** Crash on app close or hot restart during playback.

**Phase:** Engine layer — already handled, but must be preserved during all refactors.

---

### 3. Static State Leaks Between Tests

**What goes wrong:** `PlaylistStore` and `SettingsStore` use static mutable fields (`_debounce`, `_pendingJson`, `_writeInFlight`, `_cachedPrefs`). Tests that forget `reset()` in tearDown leak timers and stale state into subsequent tests.

**Why it happens:** Dart test runner runs tests in the same process. Static fields persist across test cases. A `PlaylistStore.save()` call creates a 300ms debounce timer that fires after the test completes.

**Consequences:** Flaky tests. False positives/negatives. Timer fires in unrelated test, modifying shared state.

**Prevention:**
- Always call `PlaylistStore.reset()` and `SettingsStore.resetPrewarm()` in tearDown
- Consider making stores instantiable with constructor injection (long-term fix)
- Use `fake_async` package for deterministic timer control

**Detection:** Tests pass individually but fail in suite. Random test failures.

**Phase:** All phases — test infrastructure must be solid before adding features.

---

### 4. _isOpening Reentrancy Guard Stuck

**What goes wrong:** `FvpEngine._isOpening` boolean flag prevents concurrent `open()` calls. If `open()` throws before reaching the `finally` block (e.g., in `_player.prepare()` timeout), `_isOpening` remains `true` permanently, blocking all future opens.

**Why it happens:** The `finally` block (fvp_engine.dart:269-272) resets `_isOpening = false`, but if an exception occurs between `_isOpening = true` (line 169) and the try block (line 173), or if the isolate is killed, the flag stays set.

**Consequences:** App becomes unresponsive — no files can be opened. Only fix is restart.

**Prevention:**
- Current code handles this correctly with `finally` block
- Add timeout guard: if `_isOpening` is true for >15 seconds, force reset
- Add test: simulate timeout + exception, verify `_isOpening` resets

**Detection:** After a failed open, subsequent opens silently fail (no error shown).

**Phase:** Engine layer — verify during Phase 1 with integration tests.

---

## Moderate Pitfalls

Issues that cause poor UX, performance degradation, or maintenance burden.

### 5. Frameless Window White Flash on Startup

**What goes wrong:** Frameless windows show a white/blank flash before Flutter renders the first frame. The window is visible but empty.

**Why it happens:** `window_manager`'s `setAsFrameless()` + `show()` makes the window visible before the first Flutter frame is painted. The OS renders the default window background (white) briefly.

**Prevention:**
- Call `show()` after the first frame: `WidgetsBinding.instance.addPostFrameCallback((_) => windowManager.show())`
- Or use `setBackgroundColor(Colors.transparent)` before `show()` and handle in C++ runner
- Reference: D:\player_flutter uses C++ runner `DwmFlush` hack for first-frame prep

**Phase:** Window chrome phase (Phase 1).

---

### 6. DPI Scaling Mismatch on Windows

**What goes wrong:** Window size calculations are wrong when Windows display scaling is >100%. Mouse coordinates don't match click targets. Window appears blurry.

**Why it happens:** Flutter uses logical pixels, but `window_manager` platform channels may return physical pixels. Without `SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)`, Windows applies bitmap scaling.

**Prevention:**
- Set DPI awareness in C++ runner before Flutter engine init
- Always use logical pixels for window geometry (window_manager returns logical on Windows 10+)
- Test at 100%, 125%, 150%, 200% scaling

**Phase:** Window chrome phase (Phase 1).

---

### 7. PlaylistStore Serializes on Every Pause (No Dirty Flag)

**What goes wrong:** `StateMonitor._onStateChanged()` calls `savePlaylist()` on every pause event (state_monitor.dart:60-69). This triggers `jsonEncode(playlist.toJson())` even if nothing changed since last save.

**Why it happens:** No dirty flag to track whether playlist data actually changed. Every pause → serialize → debounce → write.

**Consequences:** Unnecessary CPU and I/O. On slow disks, causes micro-stutters during pause.

**Prevention:**
- Add `_playlistDirty` flag, set on add/remove/reorder/updatePosition
- Only serialize and save when `_playlistDirty == true`
- Reset flag after successful save

**Phase:** Performance optimization phase.

---

### 8. 13 Separate ValueNotifiers Cause Cascading Rebuilds

**What goes wrong:** `FvpEngine` exposes 13 individual `ValueNotifier` fields. Each `ValueListenableBuilder` wrapper rebuilds independently. During playback, `position` changes every 250ms, `state` changes on play/pause, `buffered` changes during streaming — each triggers separate widget rebuilds.

**Why it happens:** ValueNotifier design — each notifier is independent. No batching mechanism.

**Consequences:** Unnecessary rebuilds. Widget tree rebuilds 3-5 times per second during normal playback.

**Prevention:**
- Group related notifiers: `PlaybackState` (state + position + duration + buffered), `AudioState` (volume + isMuted + playbackSpeed), `VideoState` (aspectRatio + textureId + activeDecoder)
- Or use single `ChangeNotifier` with grouped getters that only notify when group changes
- For now: accept the cost (250ms poll is coarse enough), optimize later if jank appears

**Phase:** Performance optimization phase — not blocking for MVP.

---

### 9. SettingsStore.saveAll() Makes 18 Sequential Writes

**What goes wrong:** `saveAll()` performs 18 sequential `await SharedPreferences.setX()` calls. Each is a platform channel round-trip.

**Why it happens:** SharedPreferences API — each `set*` method is independent. No batch API in the package.

**Prevention:**
- Serialize all settings as single JSON blob: `prefs.setString('app_settings', jsonEncode(allSettings))`
- Reduces platform calls from 18 to 1
- Or use `SharedPreferencesWithCache` (shared_preferences 2.3+) with manual commit

**Phase:** Performance optimization phase.

---

### 10. mdk Callbacks from Native Thread

**What goes wrong:** mdk fires `onStateChanged` and `onMediaStatus` from native threads. Directly updating ValueNotifiers from non-main thread causes "setState() called during build" errors.

**Why it happens:** Native FFI callbacks run on mdk's internal thread pool, not Dart's event loop.

**Consequences:** Random framework assertion errors. State corruption.

**Prevention:**
- Current code handles this: `FvpCallbackHandler._scheduleOnMain()` uses `SchedulerBinding.instance.addPostFrameCallback` to dispatch to main thread
- Never update ValueNotifiers directly from mdk callbacks
- Guard with `_disposed` check before and after dispatch

**Phase:** Already handled — preserve during all engine refactors.

---

### 11. PositionPoller Runs During Non-Playback States

**What goes wrong:** PositionPoller's 250ms timer continues running even when player is paused or stopped (though `_poll()` checks `_seeking`, it doesn't check state).

**Why it happens:** `start()` is called in `play()`, `stop()` in `pause()`/`stop()`. But if state transitions are missed (e.g., error state), the timer may keep running.

**Prevention:**
- Add state check in `_poll()`: if state is not `playing`, skip
- Or stop poller on all non-playing state transitions in FvpCallbackHandler
- Current code stops poller in pause/stop — verify error states also stop it

**Phase:** Performance optimization phase.

---

### 12. Window Geometry Persistence Without Debounce

**What goes wrong:** If window move/resize events trigger immediate `SettingsStore.saveWindowWidth/Height/X/Y()` calls, rapid resizing causes many disk writes.

**Why it happens:** Window geometry changes fire at 60Hz during resize. Without debounce, each frame triggers a save.

**Prevention:**
- 500ms debounce on window geometry persistence (reference: D:\player_flutter pattern)
- Batch all geometry values into single save call
- Only persist on `onWindowResize` end, not during

**Phase:** Window persistence phase (Phase 2).

---

## Minor Pitfalls

Issues that cause minor annoyances or code smell.

### 13. PathValidator URL Validation Weak

**What goes wrong:** `PathValidator.validate()` allows any URL with `http://`, `https://`, `rtmp://`, `rtsp://` scheme to pass. No hostname validation, no private IP blocking.

**Why it happens:** Extension whitelist check on URLs is meaningless (URLs don't have file extensions in the path). No SSRF protection.

**Prevention:**
- Block private IP ranges: `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`
- Block `localhost` hostname
- Log/deny non-standard ports
- Note: local file playback is primary use case, URL support is secondary

**Phase:** Security hardening phase.

---

### 14. No Input Sanitization on Equalizer Filter String

**What goes wrong:** `FvpEngine.setEqualizer()` passes raw string to `setProperty('af', ...)` without validation. Malformed FFmpeg filter syntax could crash the engine.

**Why it happens:** No validation layer between UI and mdk property API.

**Prevention:**
- Validate filter string format: must match `af=` syntax or be empty
- Or use structured parameters (gain values per band) and construct filter string internally
- Current equalizer UI not built yet — design with structured input from start

**Phase:** Security hardening phase (deferred to v2 equalizer work).

---

### 15. PlaybackNavigator openGeneration Guard is Implicit

**What goes wrong:** The `openGeneration` counter prevents stale async callbacks from applying, but the pattern is implicit. If any code path forgets to check `gen != openGeneration`, stale state leaks through.

**Why it happens:** No type-system enforcement. The guard is a convention, not a contract.

**Prevention:**
- Always capture `openGeneration` before `await` and check after
- Consider wrapping in a helper: `Future<T> guarded(Future<T> fn)` that checks generation automatically
- Add test: rapid-fire open calls, verify only last one applies

**Phase:** All phases — pattern must be preserved.

---

### 16. Playlist Index Tracking During Mutations

**What goes wrong:** `Playlist.removeAt()` and `reorder()` manually adjust `_currentIndex` with branching logic. Off-by-one errors are easy to introduce.

**Why it happens:** Index adjustment is inherently tricky — remove before current, remove current, remove after current all have different logic.

**Prevention:**
- Use `clamp(0, length - 1)` after mutations (already done)
- Add property-based tests for index tracking
- Consider: always play by item reference, not index (but indices are simpler for persistence)

**Phase:** Already handled — verify with expanded test coverage.

---

### 17. Hot Reload Leaves Orphaned mdk Player

**What goes wrong:** Flutter hot reload doesn't call `dispose()`. The mdk native player continues running with stale state. Hot restart may or may not clean up.

**Why it happens:** Hot reload preserves Dart isolate state. `FvpEngine._player` persists, but Flutter widget tree is rebuilt.

**Prevention:**
- Add `WidgetsBindingObserver.didChangeAppLifecycleState` to pause on background
- For development: document that hot restart (not reload) is required after engine changes
- Consider: detect hot reload and reset engine state

**Phase:** Development workflow — document in CLAUDE.md.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Window chrome (frameless, title bar) | White flash on startup, DPI mismatch | Set DPI awareness in C++ runner, show after first frame |
| Fullscreen toggle | Race condition with frameless, position not restored | Manual setSize/setPosition, reentry guard, save geometry before toggle |
| Window persistence | No debounce → disk thrashing | 500ms debounce on geometry writes, batch all values |
| Aspect ratio lock | WM_SIZING conflicts with Flutter constraints | Use native MethodChannel (not Flutter-level), reference D:\player_flutter |
| Video surface rendering | Texture ID null during open(), dispose crash | Guard textureId.value != null before rendering, preserve dispose order |
| Controls overlay | 13 ValueNotifiers → cascading rebuilds | Group notifiers or accept cost for MVP |
| Drag-and-drop | PathValidator rejects valid paths | Test with CJK paths, UNC paths, long paths |
| Security hardening | URL SSRF, no input bounds | Block private IPs, clamp subtitle delay, validate equalizer input |
| Performance optimization | Playlist serializes on every pause, 18 SharedPreferences writes | Dirty flag, single JSON blob |

---

## Sources

- `.planning/codebase/CONCERNS.md` — Codebase analysis (HIGH confidence)
- `.planning/codebase/ARCHITECTURE.md` — Architecture patterns (HIGH confidence)
- `.planning/PROJECT.md` — Requirements and constraints (HIGH confidence)
- `C:\Users\35490\.claude\projects\D--simple-player-flutter\memory\project_window_anti_patterns.md` — Reference project lessons (HIGH confidence)
- GitHub: `leanflutter/window_manager` issues — fullscreen + frameless known problems (MEDIUM confidence)
- GitHub: `wang-bin/fvp` — texture dispose lifecycle (MEDIUM confidence)
- Web search: Flutter desktop DPI, frameless artifacts (MEDIUM confidence)

---

*Pitfalls audit: 2026-05-09*
