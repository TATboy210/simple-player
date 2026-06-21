# Codebase Concerns

**Analysis Date:** 2026-06-21

## Compilation Errors (CRITICAL)

### audio_tab.dart Type Errors

- Issue: `_AudioTrackRow.track` is typed as `dynamic` instead of `AudioTrackInfo`. Lines 67 and 73 fail because `dynamic` properties can't be used in `bool` conditions or assigned to `String?`.
- Files: `lib/ui/dialogs/settings/audio_tab.dart` (lines 51, 67, 73)
- Impact: Build fails with 3 analyzer errors: `non_bool_condition`, `argument_type_not_assignable`.
- Fix approach: Change `final dynamic track;` to `final AudioTrackInfo track;` on line 51.

### integration_test Missing Argument

- Issue: `simple_test.dart` calls a constructor without the required `windowService` parameter.
- Files: `integration_test/simple_test.dart` (line 10)
- Impact: Integration test compilation fails.
- Fix approach: Pass `WindowService()` or a mock to the constructor.

### showDialog Type Inference Warnings

- Issue: `showDialog` calls in `app.dart` (line 66) and `player_screen.dart` (line 268) lack explicit type arguments, causing inference warnings.
- Files: `lib/app.dart:66`, `lib/ui/player/player_screen.dart:268`
- Impact: Warning-only. May cause issues with strict analysis.
- Fix approach: Add explicit `<void>` or `<T>` type argument to `showDialog<>()` calls.

### Unused Variables

- Issue: `videoContent` in `player_screen.dart:118` and `hasTooltip` in `test/widget/player/progress_bar_test.dart:449` are assigned but never read.
- Files: `lib/ui/player/player_screen.dart:118`, `test/widget/player/progress_bar_test.dart:449`
- Impact: Warning-only.
- Fix approach: Remove or prefix with `_` if intentionally unused.

## FvpEngine God Object (HIGH)

### 692 Lines, 12+ Responsibilities

- Issue: `FvpEngine` is the largest non-generated file at 692 lines. It handles: playback control, network stream configuration (6 protocol branches), track management delegation, video effects, D3D11 settings, subtitle delay, equalizer, rotation, aspect ratio, deinterlace, and lifecycle management.
- Files: `lib/kernel/engine/fvp_engine.dart` (692 lines)
- Impact: Difficult to test individual concerns in isolation. Adding a new feature requires modifying this file. 12 `ValueNotifier` fields and 15+ public methods.
- Fix approach: Extract `NetworkConfigurator` (lines 159-209), `VideoEffectController` (lines 592-637), and `D3d11Configurator` (lines 137-153, 639-664) into separate classes. `TrackManager` delegation is already extracted but the engine still holds 12 ValueNotifiers. Per STATE.md, this is deferred as ARCH-01.

## SettingsStore Monolithic Persistence (HIGH)

### 439 Lines, 25+ Save Methods

- Issue: Each setting has its own `saveX()` method wrapping `SharedPreferences` with try-catch. The `load()` method duplicates all defaults from `AppSettings`. Adding a new setting requires 6 touch points: key constant, `AppSettings` field, save method, `load()`, `saveAll()`, default fallback.
- Files: `lib/kernel/persistence/settings_store.dart` (439 lines), `lib/kernel/models/app_settings.dart` (167 lines)
- Impact: High maintenance cost. Defaults are defined in two places (`AppSettings` constructor and `SettingsStore.load()` catch block).
- Fix approach: Serialize/deserialize the entire `AppSettings` object in one pass using JSON. Or switch to structured storage with schema migration. The `_save()` helper already centralizes try-catch, but individual methods still proliferate.

## Static Mutable Singletons (MEDIUM)

### Global State Anti-Pattern

- Issue: Three services use `static final X I = X._()` singleton pattern. These create hidden global state that's difficult to test and prevents dependency injection.
- Files:
  - `lib/kernel/services/locale_service.dart:18` — `LocaleService.I`
  - `lib/kernel/services/theme_service.dart:15` — `ThemeService.I`
  - `lib/ui/widgets/osd_overlay.dart:27` — `OsdService.I`
  - `lib/kernel/utils/perf_monitor.dart:11` — `PerfMonitor._instance`
- Impact: Tests must call `reset()` on each singleton before/after each test. Any test that forgets to reset leaks state into subsequent tests. Prevents parallel test execution.
- Fix approach: Migrate to constructor injection. `LocaleService` and `ThemeService` are used in `app.dart` — inject them as constructor parameters. `OsdService` is used via `OsdService.I.show()` — convert to a provider pattern.

## Large Files (MEDIUM)

### Files Exceeding 300 Lines

- Issue: 10 files exceed 300 lines (excluding generated l10n files). The top 5 are architectural concerns.
- Files (by size):
  - `lib/kernel/engine/fvp_engine.dart` — 692 lines (god object)
  - `lib/kernel/persistence/settings_store.dart` — 439 lines (monolithic)
  - `lib/ui/dialogs/settings_panel.dart` — 402 lines (complex dialog)
  - `lib/ui/shared/aurora_background.dart` — 358 lines (custom painter)
  - `lib/ui/playlist/playlist_panel.dart` — 333 lines (floating panel)
  - `lib/ui/player/player_screen.dart` — 328 lines (main screen)
  - `lib/ui/dialogs/settings/video_tab.dart` — 317 lines (settings tab)
  - `lib/ui/playlist/thumbnail_tile.dart` — 309 lines (thumbnail card)
  - `lib/ui/playlist/folder_tab.dart` — 306 lines (folder grouping)
- Impact: Hard to navigate and test. `settings_panel.dart` has complex deferred-apply logic with OK/Cancel/Apply buttons.
- Fix approach: Extract sub-components from `settings_panel.dart`. Extract `AuroraPainter` from `aurora_background.dart`. The `player_screen.dart` Stack compositing is inherently complex but could extract the overlay logic.

## Late Keyword Overuse (MEDIUM)

### Deferred Initialization Pattern

- Issue: Multiple classes use `late final` for fields that are initialized in `init()` methods rather than constructors. This creates a runtime crash risk if `init()` isn't called before access.
- Files:
  - `lib/features/player/player_services.dart:17-20` — 4 `late final` fields (engine, playlist, controller, videoProcessing)
  - `lib/features/player/services/playback_controller.dart:38-40` — 3 `late final` fields (navigator, fileOps, monitor)
  - `lib/kernel/engine/fvp_engine.dart:50-52` — 3 `late final` fields (callbackHandler, positionPoller, trackManager)
  - `lib/features/player/services/video_processing_service.dart:27,30` — 2 `late` fields
  - `lib/ui/dialogs/settings/settings_tab_performance.dart:22` — 1 `late final`
- Impact: If `PlayerServices.init()` throws halfway through, `controller` and `videoProcessing` are uninitialized. Accessing them crashes with `LateInitializationError`.
- Fix approach: Use nullable types or factory constructors. For `FvpEngine`, the `late` fields are initialized in `_createPlayer()` which is called lazily — this is intentional but fragile.

## Platform Lock-in (MEDIUM)

### Windows-Only, No Platform Guards

- Issue: Zero `Platform.isWindows` guards in the codebase. The app assumes Windows unconditionally. `window_manager` and `flutter_fullscreen` handle platform abstraction at the package level, but custom logic (fullscreen animation, geometry persistence, resize debounce) has no platform branching.
- Files: `lib/kernel/bridge/window_service.dart` (229 lines), `lib/main.dart`
- Impact: Porting to macOS/Linux requires: (1) verifying `window_manager` API parity, (2) testing `flutter_fullscreen` behavior, (3) adding platform-specific geometry clamping for multi-monitor. No `dart:ffi` or `MethodChannel` is used directly — this is cleaner than the old architecture.
- Fix approach: Add platform stubs as described in STATE.md PLATFORM-02. The `WindowService` is already package-based (no raw Win32 FFI), so the migration surface is smaller than it appears.

### ThumbnailService Windows No-Op

- Issue: `ThumbnailService` maps `TargetPlatform.windows` to `NoopThumbnailProvider()` — no real thumbnails on the primary platform. macOS provider returns `null` with a TODO for QLThumbnailGenerator.
- Files: `lib/kernel/services/thumbnail_service.dart:26`, `lib/kernel/services/macos_thumbnail_provider.dart:7`
- Impact: Playlist panel shows empty thumbnail placeholders on Windows and macOS. Only Linux has a real provider.
- Fix approach: Implement Windows thumbnail extraction via `IThumbnailProvider` COM interface or `ShellItemImageFactory`. For macOS, use `QLThumbnailGenerator` via Objective-C FFI.

## Deferred Import Complexity (MEDIUM)

### DeferredPlayerFeature

- Issue: `deferred as` import adds async loading complexity, error handling for load failures, and an empty screen during load. On desktop, code splitting is less critical than on web/mobile.
- Files: `lib/features/player/deferred_player_feature.dart` (97 lines)
- Impact: Adds a code path that can fail silently (shows error text). The `EnginePrewarm` already runs fire-and-forget in `main()`, so engine init happens in parallel anyway.
- Fix approach: Measure actual startup time difference. If <500ms savings, remove deferred import and simplify to direct import. The `StartupCoordinator` progress reporting adds value even without deferred loading.

## Security Considerations (MEDIUM)

### URL Input Validation

- Risk: Network URLs (http/https/rtsp/rtmp/srt/udp/tcp) are passed directly to FFmpeg without structural validation. `PathValidator.isUrl()` checks prefix only.
- Files: `lib/kernel/engine/fvp_engine.dart:159-209`, `lib/kernel/services/path_validator.dart`
- Current mitigation: `PathValidator.isUrl()` checks URL prefix. `_configureNetworkOptions()` sets timeouts.
- Recommendations: Use `Uri.tryParse()` to validate URL structure. Reject URLs with unexpected schemes or excessively long components.

### File Path Handling

- Risk: User-provided file paths passed directly to `mdk.Player.media` and `File()`. No length validation.
- Files: `lib/features/player/services/file_operations.dart`, `lib/kernel/engine/fvp_engine.dart:242-257`
- Current mitigation: `PathValidator` checks extensions. `fvp_engine.dart` checks `File.exists()`.
- Recommendations: Add path length validation (Windows MAX_PATH = 260). Sanitize paths to prevent null bytes.

## Performance Bottlenecks (LOW)

### PositionPoller Timer

- Problem: Polls playback position every 250ms (steady state) via `Timer`. Necessary because fvp/MDK doesn't provide a position-changed callback. Adaptive: 100ms during seek, 1s auto-revert.
- Files: `lib/kernel/engine/position_poller.dart`
- Improvement path: fvp upstream could expose a position callback to eliminate polling.

### D3D11 Sync CPU

- Problem: Default `d3d11.sync.cpu = 1` (synchronous) adds 1-2 frames of input lag on high-refresh-rate displays. Decision in STATE.md: async (0) for 120Hz+, sync (1) for 60Hz.
- Files: `lib/kernel/engine/fvp_engine.dart:141`, `lib/kernel/bridge/display_config.dart`
- Current mitigation: `DisplayConfig.d3d11SyncMode()` detects refresh rate and selects mode. This is already implemented.

## Dependencies at Risk (MEDIUM)

### `player_engine` (local path)

- Risk: External package at `../widget_tree_flutter/player_engine` — path dependency, not published. If the sibling repo is moved or deleted, the build breaks.
- Impact: Core dependency — provides `PlayerEngine` abstract class, `MediaState`, `MediaInfo`, `AudioTrackInfo`, `SubtitleTrackInfo`, `VideoEffectType`.
- Current mitigation: Path dependency is explicit in `pubspec.yaml`.
- Migration plan: Publish to local pub server or convert to a monorepo package.

### `fvp` (v0.36.2)

- Risk: Core dependency — single maintainer (WangBin). Provides entire media playback engine (MDK + FFmpeg + D3D11 texture).
- Impact: No drop-in alternative for Flutter desktop texture-based playback.
- Migration plan: Long-term, consider wrapping mpv or FFmpeg directly via FFI + custom texture plugin (v2 prototype was archived).

### `desktop_drop` (v0.7.1)

- Risk: Community-maintained, infrequent updates. Could break on new Flutter/Windows versions.
- Impact: Drag-and-drop file support breaks.
- Migration plan: Implement native drag-and-drop via Win32 `DragAcceptFiles` + `WM_DROPFILES` in C++ runner (~50 lines).

### `window_manager` (v0.5.1)

- Risk: Custom fullscreen logic uses `flutter_fullscreen` alongside `window_manager`. Future versions may change `WindowListener` callback behavior.
- Impact: Breaking changes would require updating `WindowService`.
- Current mitigation: Only stable API surface is used (`getId()`, `addListener()`, `setSize()`, `minimize()`, `close()`, `center()`, `startDragging()`, `setAlwaysOnTop()`).

## Test Coverage Gaps (MEDIUM)

### 57 Test Files, 767 Tests, ~8,631 Lines

- Coverage: Below 80% target. Key untested areas:
  - `WindowService` — all window operations mocked, real behavior untested
  - `SettingsPanel` deferred apply — OK/Cancel/Apply race conditions
  - `FvpEngine` network streams — 6 protocol branches in `_configureNetworkOptions()` untested
  - `AuroraBackground` — 358-line custom painter, no performance benchmarks
  - `DeferredPlayerFeature` — load failure path untested
- Risk: Window behavior differs across Windows 10 vs 11. Multi-monitor edge cases. DPI scaling.
- Priority: SettingsPanel deferred apply (HIGH), WindowService (MEDIUM), Network streams (MEDIUM), Aurora (LOW).

## v2 Archived Code (LOW)

### 29 Files, 2,707 Lines in v2/

- Issue: The `v2/` directory contains an archived mpv+ANGLE prototype (commit 25dcc29). It has its own `.planning/`, `.dart_tool/`, and 29 Dart files. It generates analyzer warnings (`unused_element`, `unintended_html_in_doc_comment`, `curly_braces_in_flow_control_structures`).
- Files: `v2/` directory (entire tree)
- Impact: Adds 6 info-level analyzer warnings to the project. Confuses code search results. Not included in production builds.
- Fix approach: Add `v2/` to `.gitignore` or move to a separate branch/archive. The v2 prototype is documented in `.planning/project_v2_archive.md`.

## Resolved Since 2026-05-30

- ~~Win32 FFI from Dart~~ — Removed. `window_service.dart` now uses `window_manager` + `flutter_fullscreen` packages only.
- ~~`_savedFrame` memory leak~~ — Fixed in Phase 13 Wave 2 (H-2).
- ~~`onWindowClose` async race~~ — Fixed in Phase 13 Wave 2 (H-1). Now uses `whenComplete()`.
- ~~Triple async border removal~~ — Fixed in Phase 13 Wave 2 (CR-1). C++ WM_NCCALCSIZE handles frameless.
- ~~`catch (_)` silent errors~~ — All changed to `on Exception catch (e)` + logging.
- ~~LRU cache O(n) scan~~ — Fixed. `ThumbnailService._touch()` uses `LinkedHashMap` O(1) remove+reinsert.
- ~~PerfMonitor unbounded list~~ — Fixed with ring buffer.
- ~~AppSettings not immutable~~ — Has `copyWith()`, `operator ==`, `hashCode`.

## Deferred Items (from STATE.md)

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v1.3+ | WIN-07: Fullscreen smooth transition | Blocked by engine (fvp doesn't expose transition callbacks) | v1.2.1 |
| v1.3+ | PLATFORM-02: macOS/Linux platform stubs | Interface only in v1.2.1 | v1.0 |
| v1.3+ | ARCH-01: FvpEngine decomposition | Needs report | v1.2 |
| v1.3+ | Steam/SteamOS distribution | Deferred | v1.0 |

---

*Concerns audit: 2026-06-21*
