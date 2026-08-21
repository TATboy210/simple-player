# Codebase Concerns

**Analysis Date:** 2026-08-21

## Tech Debt

### Deferred Window Bridge Migration Left Inconsistent Naming

- Issue: The old `lib/kernel/window_manager_service/` directory was deleted and replaced by `lib/kernel/window_Bridge/` (capital B), but the directory name mixes conventions — `window_Bridge` (camelCase `B`) violates Dart's `snake_case` directory naming convention while the internal file `window_bridge.dart` (lowercase) is correct. The file `window_manager_service.dart` lives inside `window_Bridge/` and exports `window_bridge.dart` / `window_constants.dart` / `window_service_state.dart` via a barrel.
- Files: `lib/kernel/window_Bridge/` (directory), `lib/kernel/window_Bridge/window_manager_service.dart`, `lib/kernel/window_Bridge/window_bridge.dart`, `lib/kernel/window_Bridge/window_service_state.dart`
- Impact: Inconsistent casing creates import-path confusion and violates the project's own `snake_case` directory convention documented in coding-style rules. New contributors may create duplicate directories with different casing on case-insensitive filesystems.
- Fix approach: Rename `lib/kernel/window_Bridge/` to `lib/kernel/window_bridge/` (lowercase) and update the 7 import sites: `lib/app.dart:4`, `lib/features/player/deferred_player_feature.dart:18`, `lib/features/player/player_feature.dart:23`, `lib/kernel/player_services.dart:30`, `lib/main.dart:10`, `lib/ui/player/player_keyboard_actions.dart:4`, `lib/ui/player/player_screen.dart:6`, `lib/ui/window/custom_title_bar.dart:5`.

### Deprecated `WindowState` Legacy Class Still Shipped

- Issue: `WindowState` in `lib/kernel/window_Bridge/window_bridge.dart:70` is annotated `@Deprecated('WindowService owns active state; prefer WindowBridge.')` but remains in the public barrel export. No callers inside `lib/` use it, yet it is exported via `window_manager_service.dart:13` (`export 'window_bridge.dart'`).
- Files: `lib/kernel/window_Bridge/window_bridge.dart:68-103`, `lib/kernel/window_Bridge/window_manager_service.dart:13`
- Impact: Dead public API surface; external consumers (tests, plugins) may depend on the deprecated type, blocking removal.
- Fix approach: Remove `WindowState` class and the `@Deprecated` annotation. Grep `test/` and `lib/` for any `WindowState(` references (none found in production code). Delete the class and its barrel export entry.

### `PlayerFeature` Admits It Carries ViewModel Responsibilities

- Issue: The doc comment at `lib/features/player/player_feature.dart:12-13` explicitly states: "本文件同时承担 View 和部分 ViewModel 职责（历史遗留，后续重构目标）" ("This file simultaneously bears View and partial ViewModel responsibilities (historical legacy, future refactor target)"). The StatefulWidget `_PlayerFeatureState` manages UI state (`_ready`, `_error`, `_errorMessage`, `_isDragHovering`) AND directly owns `PlayerServices` lifecycle AND wires `FilePickerCoordinator` callbacks — three concerns in one class.
- Files: `lib/features/player/player_feature.dart:60-234`
- Impact: Mixed responsibilities make the widget hard to test in isolation; UI state changes and service initialization failures are entangled, so a failure in `_services.init()` drives `setState` for error display directly from the init callback.
- Fix approach: Extract a `PlayerViewModel extends ChangeNotifier` (or `ValueNotifier<PlayerUiState>`) that owns `PlayerServices` lifecycle and exposes `UiState` (loading/ready/error). `PlayerFeature` becomes a pure `View` that listens to the ViewModel and renders accordingly, matching the documented MVVM intent.

### macOS Thumbnail Provider Is a Stub

- Issue: `MacosThumbnailProvider.getThumbnail` unconditionally returns `null`. The TODO at `lib/kernel/services/macos_thumbnail_provider.dart:7` acknowledges the gap: "实现 QLThumbnailGenerator Objective-C FFI 提取真实缩略图" ("Implement QLThumbnailGenerator Objective-C FFI to extract real thumbnails").
- Files: `lib/kernel/services/macos_thumbnail_provider.dart:7-13`
- Impact: macOS users see no video thumbnails in the playlist/history tabs — only file icon fallbacks. Windows users also get `NoopThumbnailProvider` (per `lib/kernel/services/thumbnail_service.dart:36`), so thumbnails are effectively non-functional on the primary target platform.
- Fix approach: Implement a Windows thumbnail provider using `SHGetImageList` / `IExtractIcon` via `dart:ffi` (the `ffi: ^2.2.0` dependency is already present in `pubspec.yaml`). For macOS, add a `QLThumbnailGenerator` FFI bridge. Update `ThumbnailService._providerImpl` switch (`lib/kernel/services/thumbnail_service.dart:35-40`) to return the real provider instead of `NoopThumbnailProvider`.

### Keyboard Handler Missing Fullscreen Shortcut in Help Panel

- Issue: The `F` key toggles fullscreen (handled at `lib/ui/player/keyboard_handler.dart:143`), but `shortcutDefinitions` at `lib/ui/player/keyboard_handler.dart:15-26` does NOT list it. The TODO at line 142 admits: "补 shortcutDefinitions + l10n.shortcutFullscreen 以在帮助面板显示" ("Add shortcutDefinitions + l10n.shortcutFullscreen to show in help panel").
- Files: `lib/ui/player/keyboard_handler.dart:15-26`, `lib/ui/player/keyboard_handler.dart:142`
- Impact: Users cannot discover the fullscreen shortcut via the help overlay (F1 / `?`). The key works but is invisible in the documentation.
- Fix approach: Add `('F', l10n.shortcutFullscreen)` to the `shortcutDefinitions` list, add the `shortcutFullscreen` key to `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`, and regenerate localizations.

### Heavy Use of `late` Initializers (55 occurrences)

- Issue: 55 `late` / `late final` declarations across `lib/`, concentrated in State classes and the engine. While many are legitimate (constructor-body assignment, `late final VideoController` after `_player` init), several risk `LateInitializationError` if accessed before assignment — e.g., `lib/kernel/services/video_processing_service.dart:35` (`late VideoProcessingState _previousState` set in constructor body) and `lib/ui/player/player_screen.dart:103` (`late Widget _titleBar`).
- Files: `lib/ui/player/player_video_controls.dart:327-353` (7 `late final` fields), `lib/ui/player/player_screen.dart:97-103`, `lib/kernel/services/video_processing_service.dart:35-38`, `lib/kernel/services/playback_controller.dart:87`
- Impact: `LateInitializationError` crashes are hard to debug — they give no stack trace of the assignment site. Accessing a `late` field during a partially-failed `initState` or out-of-order lifecycle will crash at runtime.
- Fix approach: Audit `late` usages; convert fields that can be `final` with nullable types + `??` guards (per coding-style rules: "Avoid `late` unless initialization is guaranteed before first use"). Reserve `late final` only for fields assigned in the constructor body before any method call (like `_controller` at `lib/kernel/engine/media_kit_engine.dart:59`).

### `PlayerServices` Getters Use Bang Operator on Nullable Fields

- Issue: `PlayerServices` holds nullable backing fields (`_engine`, `_controller`, `_videoProcessing`, `_mediaKitEngine`) but exposes non-nullable getters via `!`: `lib/kernel/player_services.dart:66` (`engine => _engine!`), `:73` (`controller => _controller!`), `:81` (`videoProcessing => _videoProcessing!`), `:92` (`_mediaKitEngine!.videoController`). The coding-style rules say "Avoid `!` — reserve only where a null value is a programming error and crashing is correct."
- Files: `lib/kernel/player_services.dart:66-92`
- Impact: If any caller accesses these getters before `init()` completes or after a failed init, the app crashes with a null-dereference `!` error instead of a descriptive `StateError`. The `_initialized` flag is the only guard, but getters do not check it.
- Fix approach: Either (a) make the getters throw `StateError('PlayerServices not initialized; call init() first')` when `_initialized == false`, or (b) return nullable types and let callers handle null. The existing `_disposed` flag pattern in the same file (`lib/kernel/player_services.dart:97-98`) should be extended to cover the init-guard case.

## Known Bugs

### Clean-Build Windows Executable May Fail to Start

- Symptoms: After a clean build (deleting `build/`), the Windows `.exe` may not start.
- Files: `windows/CMakeLists.txt`, `windows/runner/main.cpp`, `windows/runner/flutter_window.cpp`, `lib/main.dart`
- Trigger: Delete `build/` directory, run `flutter build windows`, launch the resulting executable.
- Workaround: The investigation document at `.planning/debug/windows-exe-cannot-start-after-clean-build.md` (status: investigating) confirms the issue is not reproduced by the existing cached debug executable, but CMake `CMP0175` policy scope and missing `libmpv-2.dll` / ANGLE DLLs in a fresh build output are the leading hypotheses. No code fix has been applied.
- Notes: The debug doc explicitly states the root cause is NOT yet confirmed. Static analysis of the runner found no deterministic null dereference. The most actionable verification is to run a clean configure/build with `flutter build windows --verbose` and inspect the output directory for missing DLLs.

### Fullscreen White Border / Edge Gap (Windowed + Fullscreen)

- Symptoms: A white border or edge seam appears at window edges in frameless or fullscreen mode on Windows.
- Files: `lib/kernel/window_Bridge/window_manager_service.dart:154-192` (the `_initWindow` method no longer calls `setAsFrameless`), `windows/runner/win32_window.cpp`
- Trigger: Launch the Windows player, enter fullscreen; inspect all edges.
- Workaround: The investigation at `.planning/debug/fullscreen-white-border-gap.md` (status: investigating) confirms the root cause: `window_manager` intercepts `WM_NCCALCSIZE` before `FlutterWindow::MessageHandler`, and `waitUntilReadyToShow` applies `TitleBarStyle.hidden` which forcibly clears `is_frameless_`, causing the plugin to subtract 8px from right/bottom. The fix (calling `setAsFrameless` after `waitUntilReadyToShow`) was previously applied but the current `_initWindow` method at `lib/kernel/window_Bridge/window_manager_service.dart:154-192` does NOT call it — relying instead on Windows runner `WM_NCHITTEST` returning native `HT*` hit results. This regression may reintroduce the white border.

### Deferred Video Playback Failure (Historical, Unresolved)

- Symptoms: "A video appears to load but does not play."
- Files: (Historically) `lib/kernel/engine/media_kit_engine.dart` open→play path, `lib/kernel/services/playback_controller.dart:171-201`
- Trigger: Open a valid local video in the desktop player.
- Workaround: Two debug documents (`.planning/debug/fvp-playback-history-regression.md` and `.planning/debug/video-playback-cannot-load.md`, both status: deferred) investigated this under the old fvp/MDK backend. The backend was replaced by media_kit, and the current `PlaybackController.openAndPlay` (`lib/kernel/services/playback_controller.dart:180-200`) calls `engine.open(path)` then `engine.play()` on `OpenSuccess`. Whether the historical bug persists under media_kit is unverified.

## Security Considerations

### `PathUtils.openFileLocation` Passes User-Derived Path to Process.run

- Risk: `lib/kernel/utils/path_utils.dart:74-90` calls `Process.run('explorer', [dir])` (or `xdg-open` / `open`) where `dir` is derived from a user-supplied media path via `dirname(path)`. While the path originates from a file picker or drag-and-drop (already validated upstream), the `dir` substring is not independently re-validated for shell metacharacters or traversal sequences before subprocess invocation.
- Files: `lib/kernel/utils/path_utils.dart:74-90`
- Current mitigation: Upstream `PathValidator.validate()` (`lib/kernel/services/path_validator.dart:113-132`) checks for path traversal, null bytes, and control characters before the path reaches the engine. `dirname()` extracts the parent, which could theoretically differ in safety characteristics from the validated full path.
- Recommendations: Re-validate the `dir` output of `dirname()` through `PathValidator.isPathTraversal()` before passing it to `Process.run`. Use argument lists (already done — `[dir]`, not string interpolation) which avoids shell injection. Add a test that passes a path like `/safe/../../etc` to verify the directory is rejected.

### SharedPreferences Stores Window Geometry in Plaintext

- Risk: `lib/kernel/persistence/window_persistence.dart:83-109` persists window size, position, `alwaysOnTop`, and `isMaximized` to `SharedPreferences`, which is unencrypted plaintext on all platforms. While this data is not sensitive, `flutter_secure_storage: ^9.2.4` is a declared dependency in `pubspec.yaml` but is NOT used anywhere in the codebase (grep for `flutter_secure_storage` returns zero hits in `lib/`).
- Files: `lib/kernel/persistence/window_persistence.dart:83-109`, `pubspec.yaml` (dependency declared but unused)
- Current mitigation: Window geometry is not sensitive data; the risk is negligible. But the declared-but-unused `flutter_secure_storage` dependency adds bundle size for no benefit.
- Recommendations: Either remove `flutter_secure_storage` from `pubspec.yaml` (it is unused) or, if future secrets are planned, document the intended use. Do not store tokens or credentials in `SharedPreferences`.

### Debug-Only VM Service Bridge Ships in Release Builds

- Risk: `lib/main.dart:4` imports `package:marionette_flutter/marionette_flutter.dart`, and `lib/main.dart:15` calls `MarionetteBinding.ensureInitialized()` only in `kDebugMode`. However, the package is a dependency in `pubspec.yaml` (`marionette_flutter: 0.6.0`) and its Dart code is compiled into all build modes even if the `ensureInitialized` call is gated. The package is described as a "Debug-only VM service bridge for Marionette MCP UI automation."
- Files: `lib/main.dart:4-18`, `pubspec.yaml`
- Current mitigation: The `MarionetteBinding.ensureInitialized()` call is gated by `if (kDebugMode)` at `lib/main.dart:14`, so the VM service is not started in release/profile mode. Tree-shaking may eliminate unused code.
- Recommendations: Move `marionette_flutter` to `dev_dependencies` if the package supports it, or use conditional imports (`import 'package:marionette_flutter/marionette_flutter.dart' if (dart.library.html) ...`) to ensure zero code is compiled into release builds. Verify with `flutter build windows --release` that no VM service endpoints are exposed.

## Performance Bottlenecks

### `PlayerVideoControls` Is 907 Lines — Approaching Maintainability Limit

- Problem: `lib/ui/player/player_video_controls.dart` is 907 lines, nearly double the 500-line guideline in CLAUDE.md ("Files < 500 lines — extract modules when approaching limit") and exceeding the 800-line hard limit in coding-style rules.
- Files: `lib/ui/player/player_video_controls.dart`
- Cause: The `_PlayerVideoControlsState` class manages: auto-hide animation, fullscreen transition, subtitle padding sync, resize state tracking, idle state derivation, click-timer double-tap detection, and lifecycle listener attachment — all in one State class.
- Improvement path: Extract `SubtitlePaddingSyncer`, `FullscreenTransitionHandler`, and `DoubleTapDetector` into separate classes (following the pattern already used for `AutoHideController` at `lib/ui/player/auto_hide_controller.dart`). Target <400 lines per file.

### Synchronous Directory Listing in Subtitle Detection Hot Path

- Problem: `SubtitleService.detectAndLoadSync` at `lib/kernel/services/subtitle_service.dart:70-87` calls `dir.listSync()` synchronously on the UI isolate. The doc comment admits this is "用于 playIndex 热路径" (used in the hot path). While the comment claims "文件数量通常很少（< 100）" (file count is usually small), directories with hundreds of files will cause frame jank.
- Files: `lib/kernel/services/subtitle_service.dart:70-87`
- Cause: `listSync()` blocks the event loop until the directory enumeration completes. On network drives or directories with many files, this can take hundreds of milliseconds.
- Improvement path: The async variant `detectAndLoad` (`lib/kernel/services/subtitle_service.dart:47-64`) already exists and uses `Stream.list()`. Migrate the hot path to call the async version with `unawaited()` if the subtitle does not need to load synchronously before playback starts. The `PlaybackController.openAndPlay` flow (`lib/kernel/services/playback_controller.dart:184-188`) already uses `unawaited(subtitleService?.detectAndLoad(path))` — verify that `detectAndLoadSync` has no remaining callers and remove it.

### 39 `unawaited()` Fire-and-Forget Calls in Engine

- Problem: 39 `unawaited()` calls across `lib/`, concentrated in `lib/kernel/engine/media_kit_engine.dart` (18 calls). These mark fire-and-forget futures intentionally, but several control critical state: `unawaited(_player.play())` (`lib/kernel/engine/media_kit_engine.dart:228`), `unawaited(_player.pause())` (`:236`), `unawaited(_player.setVolume(...))` (`:326`).
- Files: `lib/kernel/engine/media_kit_engine.dart:228,236,326,335,338,348,355,358,372,396,404,406,413,471`
- Cause: The engine bridges synchronous project API to async media_kit API. Play/pause/seek return `void` in the `MediaEngine` interface, so the underlying `Future` cannot be awaited without changing the interface.
- Improvement path: This is a design constraint, not a bug. But it means errors from `_player.play()` (e.g., media not ready) are silently swallowed. Consider adding `.catchError((e) => _lastError.value = ...)` to the unawaited futures for play/pause/seek to surface failures to the UI via `_lastError`.

### LRU Thumbnail Cache Is Unbounded per Entry Size

- Problem: `ThumbnailService` at `lib/kernel/services/thumbnail_service.dart:21` bounds the cache to 200 entries (`_maxCacheSize = 200`) but does not track memory size. Each `ImageProvider` may hold decoded image data. On a system with large video files, 200 cached thumbnails could consume significant memory.
- Files: `lib/kernel/services/thumbnail_service.dart:21,29,120-124`
- Cause: The eviction logic (`_evictIfNeededImpl` at `:120-124`) only checks entry count, not bytes.
- Improvement path: Since Windows currently uses `NoopThumbnailProvider` (returns `null` — no caching happens), this is a latent issue. When real thumbnails are implemented, add a byte-size ceiling (e.g., 50MB) and evict by LRU until both count and size constraints are satisfied.

## Fragile Areas

### Fullscreen / Window-Mode Transition Coordination

- Files: `lib/kernel/window_Bridge/window_manager_service.dart` (`WindowService`), `lib/kernel/window_Bridge/window_service_state.dart` (`WindowModeCoordinator`, `WindowResizeCoordinator`), `lib/ui/player/player_video_controls.dart:391-399` (`_toggleFullscreen`), `lib/ui/player/player_screen.dart:152-158`
- Why fragile: The fullscreen lifecycle spans three coordinators (`WindowModeCoordinator`, `WindowResizeCoordinator`, `WindowPersistenceCoordinator`) plus media_kit's own route push/pop. The `_isFullscreenTransition` flag (`lib/ui/player/player_video_controls.dart:359`), `_isDeactivating` flag (`:364`), `_fullscreenIntent` flag (`window_service_state.dart:161`), and `_completing` flag (`media_kit_engine.dart:87`) all guard against interleaved state transitions. Multiple cross-referenced memory notes (e.g., `project_fullscreen_minimal_fix`, `bugfix_white_border_frameless`, `project_path_b_player_stream_controls`) document hard-won fixes that are easy to regress.
- Safe modification: Before touching fullscreen logic, read the memory notes in `MEMORY.md` under the `bugfix_white_border_frameless` and `project_fullscreen_minimal_fix` entries. Test the full cycle: windowed → maximized → fullscreen → exit fullscreen → windowed. Verify `_isDeactivating` guards remain in place — removing them reintroduces the "deactivated widget's ancestor" assertion (documented at `player_video_controls.dart:424-432`).
- Test coverage: `test/kernel/bridge/window_mode_test.dart` and `test/unit/kernel/bridge/window_service_test.dart` exist but have TODO markers (`test/unit/kernel/bridge/window_service_test.dart:78,81,84`) for Phase 4 rewrite of `FullscreenDriver` and `FullscreenResult` tests that were NOT ported.

### Engine Stream Subscription Lifecycle

- Files: `lib/kernel/engine/media_kit_engine.dart:52` (`_subscribeStreams`), `lib/kernel/engine/media_kit_engine.dart:440-510` (dispose + `_cancelSubscription`)
- Why fragile: The engine holds a `List<Future<void> Function()> _subscriptionCancels` (`:93`) of cancel callbacks for 9+ media_kit streams. The dispose method (`:465-510`) iterates these and calls each cancel, but the cancel itself returns a `Future` that is `unawaited` in the loop. If `dispose()` is called during app teardown, the subscriptions may not be fully cancelled before the `Player` is disposed, leading to events being delivered to a disposed notifier.
- Safe modification: Any change to stream subscription count or order must update both `_subscribeStreams` and the dispose loop. The `_disposed` guard (`:95`) must be checked in every public method (currently checked in `seekTo`, `setVolume`, `setMute`, `setPlaybackRate`, `switchAudioTrack`, `switchSubtitleTrack` — verify new methods follow suit).
- Test coverage: `test/kernel/engine/media_kit_engine_test.dart` and `test/kernel/engine/race_condition_test.dart` cover stream lifecycle, but only with `@visibleForTesting` static methods (no native libmpv).

### Player Screen Widget Caching and `didUpdateWidget` Source Migration

- Files: `lib/ui/player/player_screen.dart:76-252` (`_PlayerScreenState`), specifically `didUpdateWidget` at `:208-229` and `_buildVideoContent` caching at `:258`
- Why fragile: The screen caches `_titleBar` (`:103`) and `cachedVideoContent` (`:258`) to preserve widget identity across rebuilds. When `windowService` or `engine` or `controller` is replaced (via `didUpdateWidget`), the cached widgets and their listeners must be migrated — `:211-217` rebuilds `_titleBar`, `:222-228` detaches from old engine/controller and re-attaches. Missing any of these migrations causes stale listener notifications to corrupt the new tree.
- Safe modification: When adding a new `ValueNotifier` dependency to `PlayerScreen`, it MUST be registered for migration in `didUpdateWidget` (detach from `oldWidget`, attach to `widget`). Otherwise, the old source's notifications continue firing after replacement.
- Test coverage: No widget test exists for `PlayerScreen` directly (`test/integration/controls_flow_test.dart` and `test/integration/playback_flow_test.dart` cover integration flows but not the `didUpdateWidget` migration path specifically).

## Scaling Limits

### Static Singleton Services Block Test Parallelization

- Resource: Static mutable singletons in `KernelLoggerImpl._instance` (`lib/kernel/diagnostics/kernel_logger.dart:490`), `MemoryMonitor._instance` (`lib/kernel/diagnostics/memory_monitor.dart:44`), `PlaylistStore._instance` (`lib/kernel/persistence/playlist_store.dart:31`), `InputModeDetector._instance` (`lib/kernel/services/input_mode_detector.dart:55`), `ThumbnailService._instance` (`lib/kernel/services/thumbnail_service.dart:24`).
- Current capacity: All tests run sequentially because these singletons share global state. `resetForTesting()` / `reset()` / `resetInstance()` methods exist but must be called in `setUp`/`tearDown` of every test file.
- Limit: If two test files run in parallel (e.g., via `dart test -j N`), singleton state leaks between them, causing flaky failures.
- Scaling path: Migrate singletons to injected instances owned by `PlayerServices` or a DI container (`get_it` is declared in `pubspec.yaml` but unused in `lib/`). Pass `KernelLogger` / `PlaylistStore` / `InputModeDetector` as constructor parameters instead of static access. This also removes the `late final` and `!` patterns on `KernelLogger.I` / `_log`.

## Dependencies at Risk

### `go_router: ^16.2.0` Declared but Unused in Application Code

- Risk: `go_router` is listed in `pubspec.yaml` dependencies, but `grep -rn "go_router\|GoRouter" lib/` returns zero hits in application code. The package adds significant bundle size and a transitive dependency chain.
- Impact: Unused dependency increases build time, adds analysis surface, and may conflict with future Flutter version upgrades.
- Migration plan: Remove `go_router: ^16.2.0` from `pubspec.yaml` and run `flutter pub get`. If routing is planned for the future, add it when the feature is implemented (per YAGNI principle).

### `get: ^4.7.3` Declared but Unused

- Risk: `get` (GetX) is in `pubspec.yaml` but `grep -rn "package:get\|Get\.\|GetWidget\|GetxController" lib/` returns zero hits. The project uses `ValueNotifier` + `ValueListenableBuilder` exclusively for state management (per CLAUDE.md architecture section).
- Impact: Dead dependency; adds transitive packages and potential version conflicts.
- Migration plan: Remove `get: ^4.7.3` from `pubspec.yaml`.

### `dio: ^5.9.0` Declared but Unused

- Risk: `dio` HTTP client is in `pubspec.yaml` but `grep -rn "package:dio\|Dio(" lib/` returns zero hits. The player is a local-file media player with no HTTP client usage (URLs are passed to media_kit/libmpv directly).
- Impact: Unused dependency.
- Migration plan: Remove `dio: ^5.9.0` from `pubspec.yaml`.

### `freezed: ^3.2.5` + `build_runner: ^2.15.0` Codegen Pipeline Blocked

- Risk: The memory note `reference_analyzer_14_ecosystem_blocked.md` documents that `freezed` / `pigeon` / `source_gen` have NOT跟进 (not followed) `analyzer` 14, so `--major-versions` upgrades fail. `freezed_annotation: ^3.1.0` is a runtime dependency, `freezed: ^3.2.5` is a dev dependency, but no `.freezed.dart` files exist in the codebase (grep returns zero). The codegen pipeline is set up but unused.
- Impact: `build_runner` runs add time to CI but produce no output. If `freezed` models are added later, the analyzer version lock may cause build failures.
- Migration plan: If no frozen models are planned, remove `freezed`, `freezed_annotation`, `build_runner`, and `pigeon` from `pubspec.yaml`. If they are planned, wait for the analyzer ecosystem to catch up (per the memory note) before upgrading.

## Missing Critical Features

### No Error Recovery UI for Engine Init Failure

- Problem: If `PlayerServices.init()` fails (e.g., libmpv DLL missing, GPU init failure), `PlayerFeature._init()` at `lib/features/player/player_feature.dart:124-137` catches the error, sets `_error = true` + `_errorMessage = '$e'`, and renders a static error screen (`_buildErrorState` at `:190-210`). There is no retry button, no diagnostic export, and no "open logs" action.
- Blocks: Users experiencing init failures cannot recover without restarting the app. The error message is raw `'$e'` (exception toString), not localized or user-friendly.
- Fix approach: Add a "Retry" button to `_buildErrorState` that re-runs `_services.init()`. Add a "Copy error" button that copies the error + stack trace to clipboard. Use `DebugExporter` (`lib/kernel/utils/debug_exporter.dart`) to offer a "Export diagnostics" action.

### No Windows Thumbnail Generation

- Problem: `ThumbnailService` returns `NoopThumbnailProvider` on Windows (`lib/kernel/services/thumbnail_service.dart:36`), meaning playlist and history tabs show no thumbnails on the project's primary target platform. The thumbnail UI infrastructure (`lib/ui/playlist/thumbnail_tile.dart`, `lib/ui/playlist/folder_tab.dart`, `lib/ui/playlist/history_tab.dart`) exists but receives `null` from the provider.
- Blocks: Playlist/history visual browsing is degraded on Windows. The 314-line `thumbnail_tile.dart` and 316-line `folder_tab.dart` render fallback icons.
- Fix approach: Implement a `WindowsThumbnailProvider` using `SHGetImageList` with `IShellItemImageResult` via `dart:ffi`. The `ffi: ^2.2.0` package is already a dependency. Cache results in the existing LRU cache.

## Test Coverage Gaps

### 40+ Source Files Have No Corresponding Test File

- What's not tested: A script matching `lib/**/*.dart` to `test/**` found 40+ files with no test, including critical infrastructure:
  - `lib/app.dart` — App root widget, no test
  - `lib/main.dart` — Composition root, no test
  - `lib/features/player/player_feature.dart` — View+ViewModel, no test
  - `lib/kernel/window_Bridge/window_manager_service.dart` — Window service, no test (only `window_mode_test.dart` and `window_service_test.dart` test sub-components)
  - `lib/kernel/window_Bridge/window_service_state.dart` — State + coordinators, no test
  - `lib/kernel/services/video_processing_service.dart` — Video effects, no test
  - `lib/kernel/persistence/playlist_store.dart` — Persistence, no test
  - `lib/ui/player/player_screen.dart` — Main screen, no test
  - `lib/ui/player/progress_bar.dart` — 531-line seekbar, no test
  - `lib/ui/player/player_video_controls.dart` — 907-line controls, no test
  - All `lib/ui/playlist/*` files — No tests
  - All `lib/ui/shared/*` files — No tests (except golden tests for glass widgets)
- Files: See the full list above; key gaps are in `lib/ui/` (most widgets untested) and `lib/kernel/window_Bridge/` (coordinators untested).
- Risk: UI regressions (layout, gesture, state transitions) are caught only by manual testing or the 2 integration tests (`test/integration/controls_flow_test.dart`, `test/integration/playback_flow_test.dart`). Window coordinator logic bugs (resize debounce, mode serialization, persistence) are invisible.
- Priority: HIGH — `window_service_state.dart` coordinators and `video_processing_service.dart` are pure logic (no Flutter/native deps) and should be unit-tested. UI widget tests are MEDIUM priority.

### Window Service Test File Has Unported Phase 4 TODOs

- What's not tested: `test/unit/kernel/bridge/window_service_test.dart:78,81,84` has three TODO markers: "Phase 4 — rewrite driver creation tests without FullscreenDriver", "rewrite FullscreenResult tests", "rewrite confirmation chain tests". These tests were stubbed out during the window bridge refactor and never ported.
- Files: `test/unit/kernel/bridge/window_service_test.dart:78-84`
- Risk: Fullscreen driver creation, fullscreen result handling, and confirmation chain logic are untested after the refactor. If these paths regress, no test will catch it.
- Priority: HIGH — These are critical window-management paths.

### Headless Test Environment Has Pre-Existing mdk.dll Failures

- What's not tested: The memory note `reference_mdk_dll_headless_test_failures.md` documents that `flutter test` in headless environments has ~57 pre-existing `mdk.dll` FFI loading failures. These are NOT code regressions but environment issues — `mdk.dll` (the old MDK backend) cannot load in headless test runners. The memory note `reference_preexisting_test_failures.md` adds 18 more pre-existing failures from KernelLogger init, KeyboardHandler F-key, and deprecated UI.
- Files: Tests that instantiate `MediaKitEngine` (which loads native libmpv) fail in CI/headless. `test/kernel/engine/media_kit_engine_test.dart` uses only `@visibleForTesting` static methods to avoid this.
- Risk: Pre-existing failures mask real regressions. Developers must `git stash` their changes, run tests to establish the baseline failure count, then `git stash pop` and compare — a fragile manual process.
- Priority: MEDIUM — The root cause (MDK backend removal) has been addressed (media_kit is now the sole backend), but the test environment may still have libmpv loading issues. Consider running engine-dependent tests in a group with `@OnPlatform({'windows': Skip('libmpv unavailable in headless CI')})` and documenting the expected failure count in CI.
