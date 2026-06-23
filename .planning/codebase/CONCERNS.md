# Codebase Concerns

**Analysis Date:** 2026-06-23

## Compilation Errors (CRITICAL)

### audio_tab.dart Type Errors

- Issue: `_AudioTrackRow.track` is typed as `dynamic` instead of `AudioTrackInfo`. Lines 67 and 73 fail because `dynamic` properties can't be used in `bool` conditions or assigned to `String?`.
- Files: `lib/ui/dialogs/settings/audio_tab.dart` (lines 51, 67, 73)
- Impact: Build fails with 3 analyzer errors: `non_bool_condition`, `argument_type_not_assignable`.
- Fix approach: Change `final dynamic track;` to `final AudioTrackInfo track;` on line 51.

### v2 Archived Code Errors

- Issue: `v2/` directory contains archived mpv+ANGLE prototype with broken imports (`package:flutter_fullscreen/flutter_fullscreen.dart` doesn't exist)
- Files: `v2/lib/infra/window/window_service.dart` (lines 5, 46, 48, 118)
- Impact: 4 errors from v2/ pollute analyzer output, confuse CI
- Fix approach: Add `v2/` to `.gitignore` or move to separate branch

### showDialog Type Inference Warnings

- Issue: `showDialog` calls lack explicit type arguments, causing inference warnings
- Files: `lib/app.dart:66`, `lib/ui/player/player_screen.dart:278`
- Impact: Warning-only. May cause issues with strict analysis.
- Fix approach: Add explicit `<void>` type argument to `showDialog<void>()` calls.

### Unused Variables

- Issue: `videoContent` in `player_screen.dart:120` is assigned but never read
- Files: `lib/ui/player/player_screen.dart:120`
- Impact: Warning-only.
- Fix approach: Remove or prefix with `_` if intentionally unused.

### Unused Import

- Issue: `window_persistence.dart` imports `log.dart` but doesn't use it
- Files: `lib/kernel/bridge/window_persistence.dart:4`
- Impact: Warning-only.
- Fix approach: Remove the import.

## FvpEngine God Object (HIGH)

### 724 Lines, 12+ Responsibilities

- Issue: `FvpEngine` is the largest non-generated file at 724 lines. It handles: playback control, network stream configuration (6 protocol branches), track management delegation, video effects, D3D11 settings, subtitle delay, equalizer, rotation, aspect ratio, deinterlace, and lifecycle management.
- Files: `lib/kernel/engine/fvp_engine.dart` (724 lines)
- Impact: Difficult to test individual concerns in isolation. Adding a new feature requires modifying this file. 12 `ValueNotifier` fields and 15+ public methods.
- Fix approach: Extract `NetworkConfigurator` (already done at `lib/kernel/engine/network_configurator.dart`), `VideoEffectController` (already done at `lib/kernel/engine/video_effect_controller.dart`), and `D3d11Configurator` (already done at `lib/kernel/engine/d3d11_configurator.dart`). However, `FvpEngine` still holds 12 ValueNotifiers and 724 lines. Further decomposition needed: extract `MediaOpener` (already done at `lib/kernel/engine/media_opener.dart`) and consider splitting playback control from configuration.

## SettingsStore Monolithic Persistence (HIGH)

### 439 Lines, 26+ Save Methods

- Issue: Each setting has its own `saveX()` method wrapping `SharedPreferences` with try-catch. The `load()` method duplicates all defaults from `AppSettings`. Adding a new setting requires 6 touch points: key constant, `AppSettings` field, save method, `load()`, `saveAll()`, default fallback.
- Files: `lib/kernel/persistence/settings_store.dart` (439 lines), `lib/kernel/models/app_settings.dart`
- Impact: High maintenance cost. Defaults are defined in two places (`AppSettings` constructor and `SettingsStore.load()` catch block).
- Fix approach: Serialize/deserialize the entire `AppSettings` object in one pass using JSON. Or switch to structured storage with schema migration. The `_save()` helper already centralizes try-catch, but individual methods still proliferate.

## Static Mutable Singletons (MEDIUM)

### Global State Anti-Pattern

- Issue: Multiple services use `static final X I = X._()` singleton pattern. These create hidden global state that's difficult to test and prevents dependency injection.
- Files:
  - `lib/kernel/services/locale_service.dart:18` — `LocaleService.I`
  - `lib/kernel/services/theme_service.dart:15` — `ThemeService.I`
  - `lib/ui/shared/osd_overlay.dart:27` — `OsdService.I`
  - `lib/kernel/utils/perf_monitor.dart:11` — `PerfMonitor._instance`
  - `lib/kernel/services/thumbnail_service.dart` — static `_impl` and `_cache`
  - `lib/kernel/persistence/playlist_store.dart` — static `_debounce`, `_pendingJson`, `_writeInFlight`
  - `lib/kernel/bridge/display_config.dart` — static `_cachedHz`, `_initialized`
- Impact: Tests must call `reset()` on each singleton before/after each test. Any test that forgets to reset leaks state into subsequent tests. Prevents parallel test execution.
- Fix approach: Migrate to constructor injection. `LocaleService` and `ThemeService` are used in `app.dart` — inject them as constructor parameters. `OsdService` is used via `OsdService.I.show()` — convert to a provider pattern. `PlaylistStore` and `ThumbnailService` should become instance-based with injection.

## Large Files (MEDIUM)

### Files Exceeding 300 Lines

- Issue: 10 files exceed 300 lines (excluding generated l10n files). The top 5 are architectural concerns.
- Files (by size):
  - `lib/kernel/engine/fvp_engine.dart` — 724 lines (god object)
  - `lib/kernel/persistence/settings_store.dart` — 439 lines (monolithic)
  - `lib/ui/dialogs/settings_panel.dart` — 402 lines (complex dialog)
  - `lib/ui/shared/aurora_background.dart` — 362 lines (custom painter)
  - `lib/ui/playlist/playlist_panel.dart` — 358 lines (floating panel)
  - `lib/ui/player/control_bar.dart` — 350 lines (control bar)
  - `lib/ui/player/player_screen.dart` — 338 lines (main screen)
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
  - `lib/kernel/engine/fvp_engine.dart:56-58` — 3 `late final` fields (callbackHandler, positionPoller, trackManager)
  - `lib/features/player/services/video_processing_service.dart:27,30` — 2 `late` fields
- Impact: If `PlayerServices.init()` throws halfway through, `controller` and `videoProcessing` are uninitialized. Accessing them crashes with `LateInitializationError`.
- Fix approach: Use nullable types or factory constructors. For `FvpEngine`, the `late` fields are initialized in `_createPlayer()` which is called lazily — this is intentional but fragile.

## Platform Lock-in (MEDIUM)

### Windows-Only Implementation

- Issue: Core window management uses Win32 FFI directly (`win32_platform_fullscreen.dart`). `WindowService._createPlatformFullscreen()` returns `Win32PlatformFullscreen()` on Windows, but macOS/Linux paths are TODO stubs.
- Files: `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`, `lib/kernel/bridge/window_service.dart:245-246`
- Impact: Porting to macOS/Linux requires implementing `PlatformFullscreen` for each platform, plus `WindowService` platform branching.
- Fix approach: The `PlatformFullscreen` interface is already defined. Implement `MacosPlatformFullscreen` (NSWindow style mask) and `LinuxPlatformFullscreen` (GTK window state).

### ThumbnailService Platform Gaps

- Issue: `ThumbnailService` maps `TargetPlatform.windows` to `NoopThumbnailProvider()` — no real thumbnails on the primary platform. macOS provider returns `null` with a TODO for QLThumbnailGenerator.
- Files: `lib/kernel/services/thumbnail_service.dart:26`, `lib/kernel/services/macos_thumbnail_provider.dart:7`
- Impact: Playlist panel shows empty thumbnail placeholders on Windows and macOS. Only Linux has a real provider (XDG thumbnail cache).
- Fix approach: Implement Windows thumbnail extraction via `IThumbnailProvider` COM interface or `ShellItemImageFactory`. For macOS, use `QLThumbnailGenerator` via Objective-C FFI.

### DisplayConfig Refresh Rate Detection

- Issue: `_detectRefreshRate()` always returns 60Hz. TODO to use Win32 FFI `GetDeviceCaps(VREFRESH)`.
- Files: `lib/kernel/bridge/display_config.dart:49`
- Impact: 120Hz+ displays always get sync mode (`d3d11.sync.cpu=1`), adding 1-2 frames of input lag.
- Fix approach: Use Win32 FFI `GetDeviceCaps(hdc, VREFRESH)` or `display_size` package.

## Deferred Import Complexity (MEDIUM)

### DeferredPlayerFeature

- Issue: `deferred as` import adds async loading complexity, error handling for load failures, and an empty screen during load. On desktop, code splitting is less critical than on web/mobile.
- Files: `lib/features/player/deferred_player_feature.dart` (97 lines)
- Impact: Adds a code path that can fail silently (shows error text). The `EnginePrewarm` already runs fire-and-forget in `main()`, so engine init happens in parallel anyway.
- Fix approach: Measure actual startup time difference. If <500ms savings, remove deferred import and simplify to direct import.

## Bare Catch Clauses (MEDIUM)

### Exception Type Erosion

- Issue: Some catch blocks use bare `catch (e, st)` instead of `on Exception catch (e)`, catching Error subtypes (programming bugs) that should propagate.
- Files:
  - `lib/kernel/bridge/display_config.dart:52` — `catch (e, st)`
  - `lib/features/player/deferred_player_feature.dart:67` — `catch (e, stackTrace)`
  - `lib/kernel/services/linux_thumbnail_provider.dart:35` — `on Exception {}` (silent swallow)
- Impact: Programming bugs (AssertionError, TypeError) get logged and swallowed instead of crashing with stack trace.
- Fix approach: Use `on Exception catch (e)` consistently. For `linux_thumbnail_provider.dart`, at minimum log the exception.

## Security Considerations (MEDIUM)

### URL Input Validation

- Risk: Network URLs (http/https/rtsp/rtmp/srt/udp/tcp) are passed directly to FFmpeg. Only HTTP/HTTPS get structural validation via `Uri.tryParse()`. Other protocols skip validation entirely.
- Files: `lib/kernel/services/path_validator.dart:93-101`, `lib/kernel/engine/fvp_engine.dart:190-231`
- Current mitigation: `PathValidator.isUrl()` checks URL prefix. `_configureNetworkOptions()` sets timeouts.
- Recommendations: Use `Uri.tryParse()` to validate URL structure for all protocols. Reject URLs with unexpected schemes or excessively long components.

### File Path Handling

- Risk: User-provided file paths passed directly to `mdk.Player.media` and `File()`. No length validation.
- Files: `lib/features/player/services/file_operations.dart`, `lib/kernel/engine/fvp_engine.dart:248-280`
- Current mitigation: `PathValidator` checks extensions and path traversal. `fvp_engine.dart` checks `File.exists()`.
- Recommendations: Add path length validation (Windows MAX_PATH = 260). Consider symlink resolution check.

### Win32 FFI Raw Calls

- Risk: Direct FFI calls to user32.dll without sandboxing. HWND lookup by class name string.
- Files: `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`
- Current mitigation: Class name `FLUTTER_RUNNER_WIN32_WINDOW` is Flutter-specific. FFI functions are static final (DLL handle shared).
- Recommendations: Validate HWND is not null/zero before operations. Add error handling for DLL load failures.

## Performance Bottlenecks (LOW)

### PositionPoller Timer

- Problem: Polls playback position every 100-250ms via `Timer.periodic`. Necessary because fvp/MDK doesn't provide a position-changed callback.
- Files: `lib/kernel/engine/position_poller.dart`
- Current mitigation: Adaptive intervals (100ms after seek, 250ms steady, auto-revert after 1s). Already optimized.
- Improvement path: fvp upstream could expose a position callback to eliminate polling.

### Thumbnail LRU Cache Unbounded

- Problem: `ThumbnailService._cache` holds 200 `ImageProvider` objects in memory with no byte-size limit.
- Files: `lib/kernel/services/thumbnail_service.dart:16-21`
- Cause: LRU cache tracks entry count, not byte size. 200 entries at 1080p = ~90MB.
- Improvement path: Track approximate byte size (width * height * 4), evict when exceeding memory budget.

### PlaylistStore Static Timers

- Problem: `_debounce` Timer and `_writeInFlight` Future are static, persist across test runs.
- Files: `lib/kernel/persistence/playlist_store.dart:28-35`
- Cause: Static mutable state for debounce logic.
- Improvement path: Move to instance-based PlaylistStore, inject via constructor.

## Fragile Areas

**FvpEngine Open Method:**
- Files: `lib/kernel/engine/fvp_engine.dart:248-410`
- Why fragile: 162 lines, 15+ early returns, multiple timeout paths, texture creation race conditions
- Safe modification: Always test with: local file, HTTP URL, RTSP stream, invalid file, timeout scenario
- Test coverage: Unit tests exist for callback handler, but open() integration requires real MDK

**FullscreenController Mutex:**
- Files: `lib/kernel/bridge/fullscreen_controller.dart:105-142`
- Why fragile: Boolean mutex (`_isAnimating`) with try/finally, rollback on failure, OS callback interference
- Safe modification: Test enter/exit/rapid-toggle/failure-rollback scenarios
- Test coverage: Good — has FakeWindowOps and FakePlatformFullscreen test doubles

**PlayerScreen Callback Drilling:**
- Files: `lib/ui/player/player_screen.dart`
- Why fragile: 15+ callback parameters passed through constructor, any change cascades
- Safe modification: Group related callbacks into action objects or use InheritedWidget
- Test coverage: Integration tests exist but don't cover all callback paths

**SettingsPanel Deferred Apply:**
- Files: `lib/ui/dialogs/settings_panel.dart`
- Why fragile: Pending/original state tracking for locale and theme, cancel must restore both
- Safe modification: Test OK/Cancel/Apply with locale change, theme change, and both together
- Test coverage: No dedicated settings panel tests found

## Scaling Limits

**Playlist JSON Serialization:**
- Current capacity: ~1000 items typical, no hard limit
- Limit: JSON encode/decode becomes slow at 10K+ items, SharedPreferences has size limits
- Scaling path: Migrate to SQLite for large playlists, use streaming JSON parser

**Thumbnail Cache Memory:**
- Current capacity: 200 entries, ~90MB at 1080p (1920*1080*4*200)
- Limit: 4K thumbnails would be ~6GB for 200 entries
- Scaling path: Store thumbnails on disk, use memory-mapped files, limit cache to available RAM

## Dependencies at Risk

**player_engine (Local Path):**
- Risk: `path: ../widget_tree_flutter/player_engine` — local dependency, not published
- Impact: Build breaks if sibling repo is missing, no version pinning
- Migration plan: Publish to private pub.dev, or use git dependency with version tag

**fvp (v0.37.2):**
- Risk: Core dependency — single maintainer (WangBin). Provides entire media playback engine (MDK + FFmpeg + D3D11 texture).
- Impact: No drop-in alternative for Flutter desktop texture-based playback.
- Migration plan: Long-term, consider wrapping mpv or FFmpeg directly via FFI + custom texture plugin (v2 prototype was archived).

**window_manager (v0.5.1):**
- Risk: Community-maintained. Custom fullscreen logic bypasses `window_manager.setFullScreen()` with raw Win32 FFI.
- Impact: Breaking changes in `WindowListener` callback behavior would require updating `WindowService`.
- Current mitigation: Only stable API surface is used. `WindowBridge` interface abstracts the dependency.

**desktop_drop (v0.7.1):**
- Risk: Community-maintained, infrequent updates. Could break on new Flutter/Windows versions.
- Impact: Drag-and-drop file support breaks.
- Migration plan: Implement native drag-and-drop via Win32 `DragAcceptFiles` + `WM_DROPFILES` in C++ runner.

## Test Coverage Gaps

**Settings Panel:**
- What's not tested: OK/Cancel/Apply flows, locale/theme deferred apply, drag behavior
- Files: `lib/ui/dialogs/settings_panel.dart`
- Risk: Locale/theme changes could corrupt state on cancel
- Priority: Medium

**Window Service Integration:**
- What's not tested: WindowListener callbacks, resize debounce, fullscreen toggle with OS interference
- Files: `lib/kernel/bridge/window_service.dart`
- Risk: Race conditions between Dart and OS window management
- Priority: High

**Network Stream Handling:**
- What's not tested: RTSP/RTMP/SRT connection, timeout, reconnection, low-latency config
- Files: `lib/kernel/engine/fvp_engine.dart:190-231`
- Risk: Network stream failures silently set error state
- Priority: Medium

**PlayerScreen Callback Integration:**
- What's not tested: All 15+ callback parameters, callback chains, error propagation
- Files: `lib/ui/player/player_screen.dart`
- Risk: Callback drilling makes it easy to miss wiring
- Priority: Medium

## Resolved Since 2026-05-30

- ~~Win32 FFI from Dart~~ — Removed. `window_service.dart` now uses `window_manager` + `flutter_fullscreen` packages only.
- ~~`_savedFrame` memory leak~~ — Fixed in Phase 13 Wave 2 (H-2).
- ~~`onWindowClose` async race~~ — Fixed in Phase 13 Wave 2 (H-1). Now uses `whenComplete()`.
- ~~Triple async border removal~~ — Fixed in Phase 13 Wave 2 (CR-1). C++ WM_NCCALCSIZE handles frameless.
- ~~`catch (_)` silent errors~~ — All changed to `on Exception catch (e)` + logging.
- ~~LRU cache O(n) scan~~ — Fixed. `ThumbnailService._touch()` uses `LinkedHashMap` O(1) remove+reinsert.
- ~~PerfMonitor unbounded list~~ — Fixed with ring buffer.
- ~~AppSettings not immutable~~ — Has `copyWith()`, `operator ==`, `hashCode`.
- ~~NetworkConfigurator extraction~~ — Done. `lib/kernel/engine/network_configurator.dart`.
- ~~VideoEffectController extraction~~ — Done. `lib/kernel/engine/video_effect_controller.dart`.
- ~~D3d11Configurator extraction~~ — Done. `lib/kernel/engine/d3d11_configurator.dart`.
- ~~MediaOpener extraction~~ — Done. `lib/kernel/engine/media_opener.dart`.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v1.3+ | WIN-07: Fullscreen smooth transition | Blocked by engine (fvp doesn't expose transition callbacks) | v1.2.1 |
| v1.3+ | PLATFORM-02: macOS/Linux platform stubs | Interface only, implementations are TODO | v1.0 |
| v1.3+ | ARCH-01: FvpEngine further decomposition | Partially done (4 extractors), still 724 lines | v1.2 |
| v1.3+ | Steam/SteamOS distribution | Deferred | v1.0 |
| v1.3+ | Windows thumbnail extraction | NoopThumbnailProvider on Windows | v1.0 |
| v1.3+ | DisplayConfig real refresh rate detection | Always returns 60Hz | v1.2 |

---

*Concerns audit: 2026-06-23*
