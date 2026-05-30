# Codebase Concerns

**Analysis Date:** 2026-05-30

## Platform Lock-in (HIGH)

### Windows-Only Architecture

- Issue: Entire window management layer is tightly coupled to Win32 FFI via `dart:ffi`. No macOS or Linux window bridge exists. Zero `Platform.isWindows` guards — the code assumes Windows unconditionally.
- Files: `lib/kernel/bridge/window_service.dart` (328 lines), `lib/kernel/bridge/win32_bindings.dart` (118 lines), `windows/runner/win32_window.cpp` (322 lines)
- Impact: Porting to macOS/Linux requires rewriting the entire bridge layer. The `window_manager` package provides cross-platform abstractions, but custom maximize/fullscreen/fullscreen-restore logic bypasses it entirely with raw Win32 API calls (`SetWindowLongPtr`, `SetWindowPos`, `DwmExtendFrameIntoClientArea`).
- Fix approach: Extract window operations behind an abstract `WindowBridge` interface. Keep Win32 implementation as one concrete class. Add platform stubs for macOS/Linux.

### ThumbnailService Windows No-Op

- Issue: `ThumbnailService` maps `TargetPlatform.windows` to `NoopThumbnailProvider()` — no real thumbnails on the primary platform. macOS provider is also a stub with a TODO comment.
- Files: `lib/kernel/services/thumbnail_service.dart` (line 27), `lib/kernel/services/macos_thumbnail_provider.dart` (line 7)
- Impact: Playlist panel shows empty thumbnail placeholders on all desktop platforms. Only Linux has a real provider.
- Fix approach: Implement Windows thumbnail extraction via `IThumbnailProvider` COM interface or `ShellItemImageFactory`.

## FFI Memory Safety (HIGH)

### Manual calloc/free in WindowService

- Issue: Raw FFI pointers (`Pointer<Rect>`, `Pointer<MonitorInfo>`, `Pointer<Margins>`) are manually allocated with `calloc` and freed with `calloc.free`. Saved frame pointers (`_savedFrame`, `_savedMaximizeFrame`) are heap-allocated and must be explicitly freed.
- Files: `lib/kernel/bridge/window_service.dart` (lines 165-173, 179-185, 217-228, 258-266, 296-306, 319-321)
- Impact: If `_enterFullscreen()` allocates `_savedFrame` but a subsequent call throws before `calloc.free`, the pointer leaks. The `dispose()` method frees `_savedMaximizeFrame` but NOT `_savedFrame` (line 319-321 only checks `_savedMaximizeFrame`). An early exception in `_exitFullscreen` before line 227 would leak `_savedFrame`.
- Fix approach: Add `_savedFrame` cleanup to `dispose()`. Use try/finally blocks around all calloc/free pairs. Consider wrapping FFI structs in a Dart-managed holder with `Finalizer`.

### Fullscreen Transition Deadlock Risk

- Issue: `_fullscreenTransitioning` boolean guard prevents concurrent fullscreen toggles but has no timeout. If a Win32 API call hangs, the guard stays true forever, locking the user out of fullscreen.
- Files: `lib/kernel/bridge/window_service.dart` (lines 144-156)
- Impact: Rapid F-key presses during fullscreen animation are guarded, but a stuck API call permanently blocks fullscreen.
- Fix approach: Add a timeout (e.g., 2 seconds) that resets `_fullscreenTransitioning` if the transition doesn't complete.

## Static Mutable Singletons (MEDIUM)

### Global State Anti-Pattern

- Issue: Multiple services use static mutable singletons with `static final X I = X._()` pattern. These create hidden global state that's difficult to test and prevents dependency injection.
- Files:
  - `lib/kernel/services/locale_service.dart` (line 18) — `LocaleService.I`
  - `lib/kernel/services/theme_service.dart` (line 15) — `ThemeService.I`
  - `lib/ui/widgets/osd_overlay.dart` (line 27) — `OsdService.I`
  - `lib/kernel/utils/perf_monitor.dart` (line 11) — `PerfMonitor.instance`
  - `lib/kernel/engine/engine_prewarm.dart` (line 20-23) — static `_prewarmed` flags
  - `lib/kernel/services/thumbnail_service.dart` (line 21-22) — static `_cache` and `_order`
- Impact: Tests must call `reset()` on each singleton before/after each test. Any test that forgets to reset leaks state into subsequent tests. Prevents parallel test execution.
- Fix approach: Migrate to constructor injection with a lightweight service locator. At minimum, ensure every singleton has a `@visibleForTesting reset()` method. (Partially done in Phase 5.)

## Large Files (MEDIUM)

### Files Exceeding 300 Lines

- Issue: 13 files exceed 300 lines. `fvp_engine.dart` at 690 lines mixes playback control, network configuration, track management delegation, video effects, and D3D11 settings.
- Files (by size):
  - `lib/kernel/engine/fvp_engine.dart` — 690 lines
  - `lib/kernel/persistence/settings_store.dart` — 439 lines
  - `lib/ui/dialogs/settings_panel.dart` — 402 lines
  - `lib/ui/shared/aurora_background.dart` — 358 lines
  - `lib/ui/playlist/playlist_panel.dart` — 333 lines
  - `lib/kernel/bridge/window_service.dart` — 328 lines
  - `lib/ui/dialogs/settings/video_tab.dart` — 317 lines
  - `lib/ui/playlist/thumbnail_tile.dart` — 309 lines
  - `lib/ui/player/player_screen.dart` — 309 lines
  - `lib/ui/playlist/folder_tab.dart` — 306 lines
- Impact: Hard to test individual concerns in isolation. `fvp_engine.dart` has 12 ValueNotifiers and 6+ distinct responsibilities.
- Fix approach: Extract `NetworkConfigurator` from `fvp_engine.dart`. Extract `VideoEffectController`. Use generic `_saveField<T>()` for `SettingsStore`.

### SettingsStore Monolithic Persistence

- Issue: 439-line static class with 25+ individual save methods, each wrapping `SharedPreferences` with try-catch. The `load()` method returns hardcoded defaults duplicating `AppSettings` defaults.
- Files: `lib/kernel/persistence/settings_store.dart`
- Impact: Adding a new setting requires 6 touch points: key constant, `AppSettings` field, save method, `load()`, `saveAll()`, default fallback.
- Fix approach: Serialize/deserialize the entire `AppSettings` object in one pass. Or switch to structured storage with schema migration.

## Deferred Import Complexity (MEDIUM)

### DeferredPlayerFeature

- Issue: `deferred as` import adds async loading complexity, error handling for load failures, and a blank screen during load. On desktop, code splitting is less critical than on web/mobile.
- Files: `lib/features/player/deferred_player_feature.dart`
- Impact: Adds a code path that can fail silently (shows error text). The `EnginePrewarm` already runs fire-and-forget in `main()`, so engine init happens in parallel anyway.
- Fix approach: Measure actual startup time difference. If <500ms savings, remove deferred import and simplify to direct import.

## Security Considerations (MEDIUM)

### FFI Pointer Safety

- Risk: Raw FFI pointers used without bounds checking. Passing an invalid HWND to Win32 APIs could cause access violations.
- Files: `lib/kernel/bridge/window_service.dart`, `lib/kernel/bridge/win32_bindings.dart`
- Current mitigation: All HWND values come from `windowManager.getId()` — always valid during the window's lifetime.
- Recommendations: Add null/zero checks on HWND before FFI calls.

### URL Input Validation

- Risk: Network URLs (http/https/rtsp/rtmp/srt/udp/tcp) are passed directly to FFmpeg without structural validation. Malformed URLs could trigger FFmpeg parsing issues.
- Files: `lib/kernel/engine/fvp_engine.dart` (lines 165-211), `lib/kernel/services/path_validator.dart`
- Current mitigation: `PathValidator.isUrl()` checks URL prefix only.
- Recommendations: Use `Uri.tryParse()` to validate URL structure. Reject URLs with unexpected schemes or excessively long components.

### File Path Handling

- Risk: User-provided file paths passed directly to `mdk.Player.media` and `File()`. No length validation.
- Files: `lib/features/player/services/file_operations.dart`, `lib/kernel/engine/fvp_engine.dart`
- Current mitigation: `PathValidator` checks extensions. `fvp_engine.dart` checks `File.exists()`.
- Recommendations: Add path length validation (Windows MAX_PATH = 260). Sanitize paths to prevent null bytes.

## Performance Bottlenecks (LOW)

### PositionPoller 250ms Timer

- Problem: Polls playback position every 250ms via `Timer`. Necessary because fvp/MDK doesn't provide a position-changed callback.
- Files: `lib/kernel/engine/position_poller.dart`
- Improvement path: fvp upstream could expose a position callback to eliminate polling.

### LRU Cache Linear Scan

- Problem: `ThumbnailService._touch()` calls `_order.remove(filePath)` which is O(n) on a List. With `_maxCacheSize = 200`, worst case is 200 comparisons per access.
- Files: `lib/kernel/services/thumbnail_service.dart` (lines 72-75)
- Improvement path: Replace `_cache` + `_order` with `LinkedHashMap` for O(1) access-order operations.

### D3D11 Sync CPU Default

- Problem: Default `d3d11.sync.cpu = 1` (synchronous) adds 1-2 frames of input lag on high-refresh-rate displays.
- Files: `lib/kernel/engine/fvp_engine.dart` (line 49)
- Improvement path: Detect display refresh rate at startup. Use async mode on 120Hz+ displays.

## Dependencies at Risk (MEDIUM)

### `desktop_drop` (v0.7.1)

- Risk: Community-maintained, infrequent updates. Could break on new Flutter/Windows versions.
- Impact: Drag-and-drop file support breaks.
- Migration plan: Implement native drag-and-drop via Win32 `DragAcceptFiles` + `WM_DROPFILES` in C++ runner (~50 lines).

### `fvp` (v0.36.2)

- Risk: Core dependency — single maintainer (WangBin). Provides entire media playback engine (MDK + FFmpeg + D3D11).
- Impact: No drop-in alternative for Flutter desktop texture-based playback.
- Migration plan: Long-term, consider wrapping mpv or FFmpeg directly via FFI + custom texture plugin.

### `window_manager` (v0.5.1)

- Risk: Custom fullscreen/maximize logic bypasses most of its API. Future versions may change `WindowListener` callback behavior.
- Impact: Breaking changes would require updating `WindowService` and C++ runner.
- Current mitigation: Only stable API surface is used (`getId()`, `addListener()`, `setSize()`, `minimize()`, `close()`, `center()`, `startDragging()`, `setAlwaysOnTop()`).

## Test Coverage Gaps (MEDIUM)

### 48 Test Files, 596 Tests, ~7,578 Lines

- Coverage: Below 80% target. Key untested areas:
  - `WindowService` FFI calls — all mocked, real Win32 behavior untested
  - `SettingsPanel` deferred apply — OK/Cancel/Apply race conditions
  - `FvpEngine` network streams — 6 protocol branches in `_configureNetworkOptions()` untested
  - `AuroraBackground` — 358-line custom painter, no performance benchmarks
- Risk: Win32 API behavior changes across Windows versions (10 vs 11). Multi-monitor edge cases. DPI scaling.
- Priority: SettingsPanel deferred apply (HIGH), WindowService FFI (MEDIUM), Network streams (MEDIUM), Aurora (LOW).

## Dart Analyzer Status

- 6 issues found (2 warnings, 4 infos):
  - `test/perf/control_bar_perf_test.dart` — unused import
  - `test/widget/player/progress_bar_test.dart` — unused local variable
  - `test/golden/glass_widgets_golden_test.dart` — 3x `prefer_const_constructors`
  - `test/perf/control_bar_perf_test.dart` — dangling library doc comment

## Resolved Since 2026-05-28

- ~~Single `catch (_)` silently swallows errors~~ — all changed to `on Exception catch (e)` + logging
- ~~`on Object catch` catches Error subtypes~~ — all changed to `on Exception catch (e)`
- ~~Duplicate `formatMs()` utility~~ — deleted duplicate
- ~~`app.dart` unsafe casts~~ — typed callbacks replace `Object?` casts
- ~~ControlsOverlay fragile cache invalidation~~ — cache pattern removed
- ~~PerfMonitor unbounded list growth~~ — fixed-capacity ring buffer
- ~~PerfMonitor.mark()/markEnd() dead code~~ — removed
- ~~AppSettings not immutable~~ — added `copyWith()`, `operator ==`, `hashCode`

---

*Concerns audit: 2026-05-30*
