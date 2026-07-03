# Codebase Concerns

**Analysis Date:** 2026-07-03

## Tech Debt

**Windows Thumbnail Provider Missing:**
- Issue: `ThumbnailService` maps `TargetPlatform.windows` to `NoopThumbnailProvider` (returns null always). No real Windows thumbnail implementation exists.
- Files: `lib/kernel/services/thumbnail_service.dart:29`, `lib/kernel/services/noop_thumbnail_provider.dart`
- Impact: Windows users see no video thumbnails in playlist panel — only file icons. This is the primary platform.
- Fix approach: Implement `WindowsThumbnailProvider` using `IThumbnailCache` COM API or `IShellItemImageFactory` via FFI. Reference: `lib/kernel/bridge/win32/win32_display_enumerator.dart` for Win32 FFI patterns.

**macOS Thumbnail Provider Stub:**
- Issue: `MacosThumbnailProvider` returns null always with a TODO comment for QLThumbnailGenerator FFI.
- Files: `lib/kernel/services/macos_thumbnail_provider.dart`
- Impact: macOS users see no video thumbnails. Low priority since macOS build is not primary target.
- Fix approach: Use `QLThumbnailGenerator` via Objective-C FFI or `process.run` with `qlmanage -t`.

**DisplayConfig Refresh Rate Detection Stub:**
- Issue: `_detectRefreshRate()` always returns 60Hz. The `PlatformDispatcher.instance.views.first` path exists but cannot actually detect refresh rate — Flutter doesn't expose it.
- Files: `lib/kernel/bridge/display_config.dart:52-63`
- Impact: 120Hz+ displays always get `d3d11.sync.cpu='1'` (sync mode), which adds ~1 frame latency. The async mode (value `'0'`) is never selected automatically.
- Fix approach: Use Win32 FFI `GetDeviceCaps(hdc, VREFRESH)` to detect actual refresh rate. The TODO at line 56 documents this.

**Deprecated APIs Still in Codebase:**
- Issue: `ScreenUtils.clampToPrimaryDisplay` and `PlaylistStore(storagePath:)` constructor are marked `@Deprecated` but still callable.
- Files: `lib/kernel/utils/screen_utils.dart:53`, `lib/kernel/persistence/playlist_store.dart:48`
- Impact: Callers may use deprecated paths that lack multi-monitor support.
- Fix approach: Remove deprecated methods after verifying no callers exist outside tests.

**Duplicate Extension Lists:**
- Issue: `PlayerViewModel.allowedExtensions` and `PathValidator.supportedExtensions` maintain separate extension lists that can drift out of sync.
- Files: `lib/features/player/player_view_model.dart:52-55`, `lib/kernel/services/path_validator.dart:11-36`
- Impact: FilePicker may show extensions that PathValidator rejects, or vice versa. `PlayerViewModel` list is smaller (17 items vs 25 in PathValidator).
- Fix approach: `PlayerViewModel` should reference `PathValidator.supportedExtensions` instead of maintaining its own list.

**GlobalHotkeyService Uses debugPrint Instead of Logger:**
- Issue: `GlobalHotkeyService` uses `debugPrint()` directly instead of the project's `log` / `logBridge` logger instances.
- Files: `lib/kernel/services/global_hotkey_service.dart:27,68,72,84,90`
- Impact: Hotkey log output doesn't go through the file logger in release builds, making debugging harder.
- Fix approach: Replace `debugPrint` with `logBridge.d()` / `logBridge.w()`.

## Known Bugs

**Bang Operator on Nullable `_services`:**
- Symptoms: `_services!` throws if `init()` fails partway or if methods called before initialization completes.
- Files: `lib/features/player/player_view_model.dart:90,98,103,105,106`
- Trigger: Race condition — if user triggers file open or play mode toggle before `init()` finishes, or if `init()` throws after partial setup.
- Workaround: `_error` flag is set on init failure, but UI methods don't check it before accessing `_services!`.

**MemoryMonitor History Unbounded Growth on RemoveAt(0):**
- Symptoms: O(n) removal from front of `List` on every sample when at capacity.
- Files: `lib/kernel/utils/memory_monitor.dart:184`
- Trigger: Monitor runs for extended periods (200+ samples at 30s interval = 100+ minutes).
- Workaround: `_maxHistory` cap at 200 limits the damage, but the `removeAt(0)` pattern is O(n) per call.
- Fix approach: Use `Queue` from `dart:collection` or a ring buffer implementation.

**SubtitleService.detectAndLoad Loads Only First Match Without Priority:**
- Symptoms: If multiple subtitle files match (e.g., `movie.srt` and `movie.en.srt`), only the first filesystem-ordered match is loaded.
- Files: `lib/features/player/services/subtitle_service.dart:30-36`
- Trigger: Directory with multiple subtitle variants for the same media file.
- Workaround: None — user must manually select preferred subtitle.

## Security Considerations

**Path Traversal Protection:**
- Risk: `PathValidator.isPathTraversal` detects `../`, `..\\`, null bytes, UNC paths, and `~` expansion.
- Files: `lib/kernel/services/path_validator.dart:68-74`
- Current mitigation: Validation is enforced at `PlaybackNavigator.playIndex` before opening any file.
- Recommendations: RTSP/RTMP/SRT/UDP/TCP URLs skip validation entirely (`isUrl` returns true). Consider validating URL authority to prevent `file://` scheme injection.

**URL Scheme Trust:**
- Risk: `PathValidator.validate` trusts all non-HTTP URLs (RTSP, RTMP, SRT, UDP, TCP) without structure validation.
- Files: `lib/kernel/services/path_validator.dart:93-101`
- Current mitigation: HTTP/HTTPS URLs get `Uri.tryParse` + authority check.
- Recommendations: Validate that RTSP/RTMP/SRT URLs at least have a valid host component.

**Shared Preferences for Sensitive Data:**
- Risk: Window position, last opened file path, and playback settings stored in plaintext via `shared_preferences`.
- Files: `lib/kernel/persistence/settings_store.dart`
- Current mitigation: No credentials or tokens stored. Desktop-only app with user-level access.
- Recommendations: Acceptable for current scope. If cloud sync is added, encrypt sensitive paths.

## Performance Bottlenecks

**Aurora Background Ticker:**
- Problem: `AuroraBackground` runs a continuous `Ticker` for Lissajous curve animation even when the window is partially visible. The blob pre-rendering optimization helps, but the ticker still runs at vsync rate.
- Files: `lib/ui/shared/aurora_background.dart`
- Cause: Ticker pauses only when `engineState` is non-idle OR window loses focus. During idle state with focus, it runs continuously.
- Improvement path: Add frame budget check — skip frames when no visual change detected (blob positions delta below threshold).

**PlaylistStore Isolate Fallback:**
- Problem: `PlaylistStore.loadInBackground` spawns an Isolate for JSON parsing but falls back to main-thread `load()` on failure.
- Files: `lib/kernel/persistence/playlist_store.dart:151-175`
- Cause: Isolate creation can fail on resource-constrained systems or during startup contention.
- Improvement path: Pre-validate Isolate availability; use `compute()` which has built-in fallback.

**SettingsStore Static Singleton:**
- Problem: `SettingsStore._instance` is a mutable static field. Multiple `load()` calls create new instances if `_instance` is null (after `resetPrewarm`).
- Files: `lib/kernel/persistence/settings_store.dart:36-43,85`
- Cause: Thread safety concern — `load()` is async, so concurrent calls could race on `_instance`.
- Improvement path: Use a `Completer`-based initialization pattern or make `load()` always go through a single cached future.

## Fragile Areas

**WindowService Resize Callback Chain:**
- Files: `lib/kernel/bridge/window_service.dart:129-213`
- Why fragile: Three boolean flags (`_disposed`, `_isProgrammaticResize`, `_skipNextResize`) interact with async `Timer` callbacks and OS-level `WindowListener` events. The `_updateOnUIThread` method has a bare `catch (_) { update(); }` fallback that silently swallows binding errors.
- Safe modification: Never add new boolean flags. Use a state machine enum for resize lifecycle.
- Test coverage: `test/unit/kernel/bridge/window_service_test.dart` exists but may not cover all OS callback timing edge cases.

**FvpEngine late Field Initialization:**
- Files: `lib/kernel/engine/fvp_engine.dart:53-60`
- Why fragile: 8 `late` fields (`_callbackHandler`, `_positionPoller`, `_trackManager`, `_mediaOpener`, `_videoEffectController`, `_volumeController`, `_subtitleConfigurator`, `_d3d11Configurator`) are initialized in `_createPlayer()`. Accessing any before `_createPlayer()` throws `LateInitializationError`.
- Safe modification: All helpers are created together in `_createPlayer()`. Never access them from constructors or before `open()`.
- Test coverage: `test/kernel/engine/` has individual helper tests but integration test coverage for the full init chain is limited.

**PlayerViewModel _services! Pattern:**
- Files: `lib/features/player/player_view_model.dart:34,90,98,103,105,106`
- Why fragile: Public methods (`openFile`, `onFilesDropped`, `onTogglePlayMode`) use `_services!` without null check. If called before `init()` completes or after `dispose()`, they crash.
- Safe modification: Guard all public methods with `if (_services == null) return;` or expose a `bool get isReady`.
- Test coverage: `PlayerViewModel` has limited direct test coverage.

**ProgressBar AnimationController Lifecycle:**
- Files: `lib/ui/player/progress_bar.dart:75-87`
- Why fragile: Two `AnimationController`s (`_expandController`, `_tooltipFadeController`) plus a `Timer? _seekThrottle` must be disposed in correct order. The `_barListenable` is rebuilt in `didUpdateWidget`.
- Safe modification: Always call `dispose()` on old listenable before building new one. Test `didUpdateWidget` code paths.

## Scaling Limits

**LRU Cache Fixed Size:**
- Current capacity: 200 entries in `ThumbnailService._cache`
- Limit: Memory pressure if thumbnails are large (high-res video frames). No memory-based eviction.
- Scaling path: Track approximate byte size per entry; evict by memory budget instead of count.

**PlaylistStore JSON Serialization:**
- Current capacity: Entire playlist serialized as single JSON array.
- Limit: Playlists with 10,000+ entries may cause UI jank during save (main thread JSON encoding).
- Scaling path: Use Isolate for JSON encoding (matching the decode path which already uses Isolate).

## Dependencies at Risk

**window_manager:**
- Risk: Core dependency for window control. Package maintenance status should be monitored.
- Impact: `WindowService`, `WindowPersistence`, all window geometry operations depend on it.
- Migration plan: The `WindowBridge` abstraction in `lib/kernel/bridge/window_bridge.dart` isolates the dependency — swapping requires only a new `WindowBridge` implementation.

**fvp:**
- Risk: Tightly coupled native dependency (MDK/FFmpeg). Version pinned to `^0.37.2`.
- Impact: Entire playback pipeline depends on fvp. No abstraction layer for swapping engines.
- Migration plan: `EngineState` mixin provides the interface contract. A new engine implementation would need to satisfy all 30+ methods.

**fullscreen_window:**
- Risk: Local package at `packages/fullscreen_window/`. No external version tracking.
- Impact: Fullscreen toggle depends on this package.
- Migration plan: The package is small (single platform channel call). Can be inlined or replaced.

## Missing Critical Features

**Cross-Platform Parity:**
- Problem: Windows is the only fully functional platform. macOS and Linux have stub thumbnail providers and rely on `window_manager` which may have platform-specific quirks.
- Blocks: Linux/macOS builds are functional but feature-incomplete.

**HLS/ABR Streaming:**
- Problem: No adaptive bitrate streaming support. Network URLs use fixed buffer configuration.
- Blocks: Streaming from HTTP sources with variable quality.

## Test Coverage Gaps

**UI Layer (lib/ui/):**
- What's not tested: `player_screen.dart` (376 lines), `settings_panel.dart` (402 lines), `playlist_panel.dart` (368 lines), `folder_tab.dart` (306 lines), `thumbnail_tile.dart` (309 lines) — the largest UI files have no dedicated unit/widget tests.
- Files: `lib/ui/player/player_screen.dart`, `lib/ui/dialogs/settings_panel.dart`, `lib/ui/playlist/playlist_panel.dart`
- Risk: Regressions in the main player screen layout, settings dialog behavior, and playlist panel go undetected.
- Priority: High

**PlayerFeature/PlayerViewModel:**
- What's not tested: `player_feature.dart` (225 lines) and `player_view_model.dart` (122 lines) — the main feature entry points with init, file open, drag-drop, and play mode logic.
- Files: `lib/features/player/player_feature.dart`, `lib/features/player/player_view_model.dart`
- Risk: Init failures, file picker integration, and drag-drop regressions undetected.
- Priority: High

**Settings Dialog Tabs:**
- What's not tested: Individual settings tabs (`video_tab.dart` 317 lines, `audio_tab.dart`, `general_tab.dart`, `shortcuts_tab.dart` 243 lines) have no unit tests.
- Files: `lib/ui/dialogs/settings/video_tab.dart`, `lib/ui/dialogs/settings/shortcuts_tab.dart`
- Risk: Setting persistence regressions, UI state management bugs in deferred apply pattern.
- Priority: Medium

**Keyboard Handler:**
- What's not tested: `keyboard_handler.dart` (228 lines) — 20+ keyboard shortcuts with custom binding support.
- Files: `lib/ui/player/keyboard_handler.dart`
- Risk: Shortcut conflicts, binding override failures, media key handling regressions.
- Priority: Medium

**Aurora Background:**
- What's not tested: `aurora_background.dart` (363 lines) — complex custom painter with Ticker, blob pre-rendering, noise caching.
- Files: `lib/ui/shared/aurora_background.dart`
- Risk: Visual regressions, memory leaks from undisposed Ticker/Images, performance degradation.
- Priority: Low

---

*Concerns audit: 2026-07-03*
