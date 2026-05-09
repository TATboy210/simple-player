# Codebase Concerns

**Analysis Date:** 2026-05-09

## Tech Debt

**FvpEngine exceeds 400-line target:**
- Issue: `lib/kernel/engine/fvp_engine.dart` is 555 lines. Largest file in codebase. Contains playback control, media info parsing, track delegation, video effects, subtitle handling, and lifecycle management in one class.
- Files: `lib/kernel/engine/fvp_engine.dart`
- Impact: Hard to navigate, test, and modify. The `open()` method alone is 136 lines (lines 137-273) with deeply nested media info parsing.
- Fix approach: Extract media info parsing into a dedicated `MediaInfoParser` helper. Extract video effect/equalizer/rotation methods into a `VideoEffectMixin` or delegate class. Target: reduce to ~350 lines.

**SettingsStore all-static design:**
- Issue: `lib/kernel/persistence/settings_store.dart` (314 lines) is entirely static methods with a static `_cachedPrefs` field. No dependency injection, no interface. Each `save*` method repeats the same `_save` boilerplate pattern.
- Files: `lib/kernel/persistence/settings_store.dart`
- Impact: Hard to test in isolation (requires `resetPrewarm()` dance). Static state leaks between tests if `reset()` not called. Cannot swap storage backend.
- Fix approach: Extract `SettingsStore` interface, make implementation injectable. Consider code generation for the 15+ near-identical save methods.

**PlaylistStore all-static design:**
- Issue: `lib/kernel/persistence/playlist_store.dart` (172 lines) uses static fields (`_debounce`, `_pendingJson`, `_writeInFlight`) for debounced write-back. Same testability problem as SettingsStore.
- Files: `lib/kernel/persistence/playlist_store.dart`
- Impact: Static state leaks between tests. `PlaylistStore.reset()` exists but must be manually called in every test teardown.
- Fix approach: Make injectable with interface. Keep static convenience methods for backward compatibility but delegate to instance.

**13 separate ValueNotifiers in FvpEngine:**
- Issue: `FvpEngine` exposes 13 individual `ValueNotifier` fields (`textureId`, `state`, `position`, `duration`, `volume`, `isMuted`, `isBuffering`, `subtitleText`, `buffered`, `aspectRatio`, `errorMessage`, `playbackSpeed`, `activeDecoder`). Each requires separate `addListener`/`dispose` calls.
- Files: `lib/kernel/engine/fvp_engine.dart` (lines 48-88), `lib/kernel/engine/media_engine.dart` (lines 20-57)
- Impact: Widget code needs multiple `ValueListenableBuilder` wrappers. Easy to forget disposing one. Composing state requires listening to multiple notifiers.
- Fix approach: Consider grouping related notifiers into state objects (e.g., `PlaybackState`, `AudioState`, `VideoState`). Or adopt a single `ChangeNotifier` with grouped getters.

**Deleted .planning directory in working tree:**
- Issue: Git status shows 25+ `.planning/` files deleted in working tree but not committed. Previous planning artifacts (phases 1-3, ROADMAP, STATE, etc.) are gone.
- Files: `.planning/` directory tree
- Impact: Lost project context. Previous phase plans and research docs unavailable for reference.
- Fix approach: Either commit the deletions intentionally or restore from git. Document the decision.

**PlaybackController uses mixin chain for orchestration:**
- Issue: `PlaybackController` (`lib/kernel/services/playback_controller.dart`, 49 lines) mixes in `FileOperations`, `PlaybackNavigator`, and `StateMonitor`. Each mixin declares abstract getters for shared state (`engine`, `playlist`, `currentFileName`, `onNeedRebuild`, `onError`, `savePlaylist`). The mixin chain pattern is non-standard and makes dependency relationships implicit.
- Files: `lib/kernel/services/playback_controller.dart`, `lib/kernel/services/file_operations.dart`, `lib/kernel/services/playback_navigator.dart`, `lib/kernel/services/state_monitor.dart`
- Impact: IDE navigation across mixin boundaries is poor. Refactoring shared state requires updating all 4 files. Debugging call stacks through mixin dispatch is harder than direct delegation.
- Fix approach: Acceptable for now (each mixin is focused). If complexity grows, convert to composition with explicit delegate objects.

## Known Bugs

**Empty onNeedRebuild callback:**
- Symptoms: `PlaybackController` receives `onNeedRebuild: () {}` (empty no-op) from `app.dart` line 40. Any UI that depends on playlist rebuild notifications will not update.
- Files: `lib/app.dart:40`, `lib/kernel/services/playback_controller.dart:27`
- Trigger: Adding/removing/reordering playlist items, toggling play mode.
- Workaround: Currently no UI exists to observe this (app shows "Ready" placeholder). When UI is added, this must be wired to `setState` or equivalent.

**VideoProcessingService not instantiated:**
- Symptoms: `VideoProcessingService` exists in `lib/kernel/services/video_processing_service.dart` (121 lines) but is never created or used in `app.dart` or `PlaybackController`. Video effects, rotation, aspect ratio, and deinterlace settings cannot be applied from UI.
- Files: `lib/kernel/services/video_processing_service.dart`, `lib/app.dart`
- Trigger: Always -- service is dead code in current state.
- Workaround: None. Must be instantiated in `_AppState.initState()` and wired to `_engine`.

**PlatformService stubs do nothing:**
- Symptoms: Both `WindowsPlatformService` (`lib/kernel/platform/windows_platform_service.dart`) and `LinuxPlatformService` (`lib/kernel/platform/linux_platform_service.dart`) have empty `initService()` and `dispose()` methods.
- Files: `lib/kernel/platform/windows_platform_service.dart`, `lib/kernel/platform/linux_platform_service.dart`
- Trigger: Always -- platform-specific initialization is no-op.
- Workaround: None needed currently (fvp handles rendering). But window management (fullscreen, always-on-top, size persistence) requires real platform service.

## Security Considerations

**PathValidator URL validation is weak:**
- Risk: `PathValidator.validate()` allows any URL with `http://`, `https://`, `rtmp://`, `rtsp://` scheme to pass without further validation. Only checks extension whitelist. An attacker could craft a URL with a valid media extension pointing to a malicious server.
- Files: `lib/kernel/utils/path_validator.dart:67-69`
- Current mitigation: Extension whitelist enforced for local files. URL scheme whitelist exists.
- Recommendations: Add hostname allowlist or at minimum log/deny private IP ranges (10.x, 192.168.x, 127.x) for non-development builds. Consider SSRF protection.

**No input sanitization on subtitle delay:**
- Risk: `FvpEngine.setSubtitleDelay()` passes raw integer to `setProperty()` without bounds checking. Extreme values could cause unexpected behavior in mdk.
- Files: `lib/kernel/engine/fvp_engine.dart:460-462`
- Current mitigation: None.
- Recommendations: Clamp to reasonable range (e.g., -30000ms to 30000ms).

**No input sanitization on equalizer filter string:**
- Risk: `FvpEngine.setEqualizer()` passes raw string to `setProperty('af', ...)` without validation. Malformed FFmpeg filter syntax could crash the engine.
- Files: `lib/kernel/engine/fvp_engine.dart:478-480`
- Current mitigation: None.
- Recommendations: Validate filter string format or use structured parameters.

## Performance Bottlenecks

**PositionPoller 250ms timer runs continuously during playback:**
- Problem: `PositionPoller` (`lib/kernel/engine/position_poller.dart`) polls `_player.position` every 250ms via `Timer.periodic`. Each poll calls into mdk FFI.
- Files: `lib/kernel/engine/position_poller.dart:41-44`
- Cause: No event-driven position updates from mdk; polling is the only option.
- Improvement path: Consider increasing interval to 500ms for non-seek-bar updates. Use mdk's `onPosition` callback if available in future fvp versions.

**PlaylistStore serializes entire playlist on every pause:**
- Problem: `StateMonitor._onStateChanged()` calls `savePlaylist()` on every pause event (line 69). This triggers JSON serialization of the full playlist even if nothing changed.
- Files: `lib/kernel/services/state_monitor.dart:60-70`
- Cause: No dirty flag to track whether playlist actually changed.
- Improvement path: Add a `_dirty` flag. Only serialize and debounce-write when playlist data actually changed.

**SettingsStore.saveAll() makes 18 sequential SharedPreferences writes:**
- Problem: `saveAll()` in `lib/kernel/persistence/settings_store.dart:279-313` performs 18 sequential `await` calls to SharedPreferences. Each is a platform channel round-trip.
- Files: `lib/kernel/persistence/settings_store.dart:279-313`
- Cause: Sequential writes for data consistency (RC-4 comment). But SharedPreferences is a single JSON file internally -- all writes are buffered until commit.
- Improvement path: Use `SharedPreferences.setString` with a single JSON blob instead of 18 individual keys. Reduces platform calls from 18 to 1.

**VideoProcessingService double-listener pattern:**
- Problem: `VideoProcessingService` (`lib/kernel/services/video_processing_service.dart`) adds two listeners per ValueNotifier -- one for engine delegation and one for persistence debounce. Each change fires both. The persist listener triggers 7 sequential `SettingsStore.save*()` calls on every slider drag.
- Files: `lib/kernel/services/video_processing_service.dart:56-83`
- Cause: Separate listener functions for engine and persistence.
- Improvement path: Merge into single listener. Batch all persistence writes into one `saveAll()` call.

## Fragile Areas

**PlaybackNavigator openGeneration guard:**
- Files: `lib/kernel/services/playback_navigator.dart:23-27, 53`
- Why fragile: The `openGeneration` counter prevents stale async callbacks from applying, but the pattern is subtle. If any code path forgets to check `gen != openGeneration`, stale state leaks through. The guard is implicit, not enforced by type system.
- Safe modification: When adding new async operations in PlaybackNavigator, always capture `openGeneration` before `await` and check after.
- Test coverage: `test/kernel/services/playback_navigator_test.dart` covers basic cases but not rapid-fire race conditions.

**Playlist index tracking during mutations:**
- Files: `lib/kernel/playlist/playlist.dart:107-119, 124-140`
- Why fragile: `removeAt()` and `reorder()` manually adjust `_currentIndex` with branching logic. Off-by-one errors are easy to introduce. The `clamp` on line 116 silently snaps to valid range rather than signaling error.
- Safe modification: Always run `test/kernel/playlist/playlist_test.dart` after changes. Add property-based tests for index tracking.
- Test coverage: 217 lines of tests exist but do not cover all edge cases (e.g., remove at boundary while in shuffle mode).

**FvpEngine._isOpening reentrancy guard:**
- Files: `lib/kernel/engine/fvp_engine.dart:95, 139-142, 169, 271`
- Why fragile: Boolean `_isOpening` flag prevents concurrent `open()` calls. But if `open()` throws before reaching `finally` block (e.g., in `_player.prepare()` timeout handling), `_isOpening` could remain `true` permanently, blocking all future opens.
- Safe modification: The `finally` block on line 269-272 handles this. Verify with test that timeout + exception paths always clear `_isOpening`.
- Test coverage: No direct test for `_isOpening` guard behavior.

**PlaylistStore static debounce timer leaks across tests:**
- Files: `lib/kernel/persistence/playlist_store.dart:25-27`
- Why fragile: `_debounce`, `_pendingJson`, `_writeInFlight` are static. Any test that calls `PlaylistStore.save()` without calling `PlaylistStore.reset()` in tearDown leaks a timer that fires after the test completes.
- Safe modification: Always call `PlaylistStore.reset()` in tearDown. Consider making PlaylistStore instantiable.
- Test coverage: No dedicated PlaylistStore tests exist.

## Scaling Limits

**Playlist grows without bounds:**
- Current capacity: No limit on playlist size.
- Limit: Large playlists (10,000+ items) will slow JSON serialization, debounce writes, and UI rebuilds.
- Scaling path: Add playlist size cap (e.g., 5,000 items). Implement virtual scrolling for playlist UI. Consider database-backed storage for large collections.

**SharedPreferences as primary storage:**
- Current capacity: All settings in single SharedPreferences JSON file.
- Limit: SharedPreferences loads entire file into memory. With large `lastFile` paths or many keys, startup cost grows.
- Scaling path: Migrate to structured storage (sqflite, hive) if settings complexity grows beyond current ~25 keys.

## Dependencies at Risk

**11 unused dependencies in pubspec.yaml:**
- Risk: `pubspec.yaml` declares 16 non-SDK dependencies. Only 5 are actually imported in lib/: `fvp`, `path_provider`, `shared_preferences`, `dynamic_color`, `logger`. The following 11 are unused: `file_picker`, `window_manager`, `desktop_drop`, `easy_localization`, `shadcn_flutter`, `velocity_x`, `smooth_page_indicator`, `glass_kit`, `flutter_zoom_drawer`, `flutter_animate`, `just_audio`.
- Impact: Increases build time, app size, and dependency surface area. `window_manager: 0.5.1` is pinned to exact version (not range), blocking security updates.
- Migration plan: Remove unused deps from `pubspec.yaml`. Keep only `fvp`, `path_provider`, `shared_preferences`, `dynamic_color`, `logger`. Re-add when UI is implemented.

**fvp pinned to ^0.36.2:**
- Risk: fvp is a pre-1.0 package wrapping native MDK/FFmpeg. Breaking changes possible on minor version bumps.
- Impact: Engine layer tightly coupled to fvp's mdk.Player API.
- Migration plan: `MediaEngine` interface abstracts fvp. If fvp breaks, only `fvp_engine.dart` and helpers need updating. Keep interface stable.

**window_manager pinned to exact version 0.5.1:**
- Risk: Not using caret range (`^0.5.1`). Blocks automatic patch/minor updates. Package is declared but never imported -- dead dependency.
- Files: `pubspec.yaml:17`
- Impact: If re-enabled for window management, will be locked to stale version.
- Migration plan: Remove from pubspec.yaml. Re-add with `^0.5.1` or latest when needed.

## Missing Critical Features

**No actual UI:**
- Problem: `app.dart` renders a black screen with "Ready" text placeholder. No player screen, control bar, progress bar, playlist panel, or any user-facing UI exists in the current codebase.
- Blocks: All user-facing functionality. The kernel layer is complete but unexercised.

**No macOS platform service:**
- Problem: `main.dart:20-21` only handles Linux and Windows (`Platform.isLinux ? LinuxPlatformService() : WindowsPlatformService()`). macOS falls through to WindowsPlatformService.
- Blocks: macOS support.

**analysis_options.yaml has empty linter rules:**
- Problem: `analysis_options.yaml:3` includes `package:flutter_lints/flutter.yaml` but the `linter: rules:` section is empty. No custom lint rules enabled.
- Files: `analysis_options.yaml`
- Blocks: Enforcement of project-specific conventions (e.g., `avoid_print`, `prefer_const_constructors`).

## Test Coverage Gaps

**FvpEngine has no direct tests:**
- What's not tested: The entire 555-line engine class -- `open()`, `play()`, `pause()`, `stop()`, `seekTo()`, `setVolume()`, `setMute()`, `togglePlayPause()`, `skipForward/Back()`, `setPlaybackRate()`, `setRange()`, `setVideoEffect()`, `rotate()`, `setAspectRatio()`, `setDeinterlace()`, `setExternalSubtitle()`, `setSubtitleDelay()`, `setEqualizer()`, `dispose()`.
- Files: `lib/kernel/engine/fvp_engine.dart`
- Risk: Engine is the core of the app. Bugs in state transitions, error handling, or dispose ordering go undetected.
- Priority: HIGH -- requires FakeEngine or mdk mock to test. Current `test/helpers/fake_engine.dart` (357 lines) exists but tests only use it indirectly through PlaybackController.

**PlaylistStore has no tests:**
- What's not tested: Debounce behavior, atomic write (tmp+rename), load/save round-trip, history migration, clear(), dispose(), concurrent write guard.
- Files: `lib/kernel/persistence/playlist_store.dart`
- Risk: Data loss if debounce or atomic write logic is broken.
- Priority: MEDIUM -- file I/O requires temp directory fixtures.

**App shell has no tests:**
- What's not tested: `_init()` parallel initialization, locale loading, error recovery, dispose ordering, "Ready" loading state.
- Files: `lib/app.dart`, `lib/main.dart`
- Risk: Startup failures go undetected.
- Priority: LOW -- app shell is thin wrapper.

**UI theme layer has no tests:**
- What's not tested: `lib/kernel/ui/theme/tokens.dart`, `lib/kernel/ui/theme/app_theme.dart`.
- Files: `lib/kernel/ui/theme/tokens.dart`, `lib/kernel/ui/theme/app_theme.dart`
- Risk: Theme regressions undetected.
- Priority: LOW -- compile-time const tokens are inherently safe.

---

*Concerns audit: 2026-05-09*
