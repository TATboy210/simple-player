# Codebase Concerns

**Analysis Date:** 2026-05-09

## Tech Debt

**Static Mutable Singletons:**
- Issue: Heavy reliance on static mutable state across multiple classes: `SettingsStore._cachedPrefs`, `PlaylistStore._debounce/_pendingJson/_writeInFlight`, `PlatformService._instance`, `MotionUtils._reducedMotion`. These create hidden coupling, make testing harder (requiring `reset()` calls), and risk state leaking between tests.
- Files: `lib/kernel/persistence/settings_store.dart`, `lib/kernel/persistence/playlist_store.dart`, `lib/kernel/services/platform_service.dart`, `lib/kernel/utils/motion_utils.dart`
- Impact: Test isolation requires explicit `reset()`/`resetPrewarm()` calls; missing these causes flaky tests. Production code has implicit ordering dependencies (e.g., `SettingsStore.prewarm()` must be called before `load()`).
- Fix approach: Consider dependency injection via constructor parameters. At minimum, document initialization order requirements and add assert guards.

**Mixin-Based PlaybackController:**
- Issue: `PlaybackController` uses 3 mixins (`FileOperations`, `PlaybackNavigator`, `StateMonitor`) that share state via abstract getters. This creates implicit coupling — each mixin depends on the host class providing specific fields and methods, but this contract is only enforced at compile time via abstract members.
- Files: `lib/kernel/services/playback_controller.dart`, `lib/kernel/services/file_operations.dart`, `lib/kernel/services/playback_navigator.dart`, `lib/kernel/services/state_monitor.dart`
- Impact: Adding new shared state requires modifying the mixin interface. Mixin method signatures must stay in sync. Hard to reason about execution order.
- Fix approach: Current approach works for 3 mixins but won't scale. If more mixins are needed, consider extracting a shared context object or switching to composition with explicit constructor injection.

**History Migration Runs on Every Load:**
- Issue: `PlaylistStore._migrateHistory()` checks for `history.json` on every `load()` call. After first successful migration, the file is deleted, so subsequent calls are cheap (file existence check), but the code path is always executed.
- Files: `lib/kernel/persistence/playlist_store.dart:107`
- Impact: Minor performance cost (one extra `File.exists()` call per load). More importantly, the migration logic adds complexity to the load path.
- Fix approach: Consider adding a `migrated` flag to `playlist.json` to skip the check entirely after first migration.

**Playlist.currentIndex Getter/Setter:**
- Issue: Dart analyzer flags `Playlist.currentIndex` as `unnecessary_getters_setters` — the getter/setter wraps `_currentIndex` with range validation, which is intentional but triggers the lint.
- Files: `lib/kernel/playlist/playlist.dart:32`
- Impact: Cosmetic lint warning. The validation logic in the setter is valuable.
- Fix approach: Suppress the lint with `// ignore: unnecessary_getters_setters` or rename to `currentIndexWithValidation` if the getter truly adds no value.

**FvpEngine Size (555 lines):**
- Issue: `FvpEngine` is the largest source file. It handles open/play/pause/stop/seek, track management delegation, video effects, subtitle management, and lifecycle.
- Files: `lib/kernel/engine/fvp_engine.dart`
- Impact: Readability concern. The file is well-organized with clear sections, but adding more features will push it past comfortable size.
- Fix approach: Already partially mitigated by extracting `FvpCallbackHandler`, `PositionPoller`, and `TrackManager`. Consider extracting video effects and subtitle management into separate helpers if more features are added.

## Known Bugs

**No-op onNeedRebuild Callback:**
- Symptoms: `App` passes `onNeedRebuild: () {}` (empty callback) to `PlaybackController`. This means `StateMonitor` calls `onNeedRebuild()` after playlist operations, but nothing happens.
- Files: `lib/app.dart:41`
- Trigger: Any playlist operation (remove, reorder, clear, play mode toggle) calls `onNeedRebuild()` which is a no-op.
- Workaround: The UI may not be wired up yet (home screen shows "Ready" placeholder). When UI is connected, this callback must trigger a widget rebuild.

**Unawaited Migration in StateMonitor.init():**
- Symptoms: `_loadPlaylistForMigration()` is called with `unawaited()` — fire-and-forget. If migration fails, the error is logged but the playlist may be incomplete.
- Files: `lib/kernel/services/state_monitor.dart:35`
- Trigger: First app launch with legacy `history.json` present.
- Workaround: Migration errors are caught and logged. Playlist still loads from `playlist.json` independently.

## Security Considerations

**PathValidator Error Messages Leak Full Paths:**
- Risk: `PathValidator.validate()` returns error messages containing the full file path (e.g., `'路径不安全: ${trimmed}'`, `'不支持的文件类型: ${trimmed}'`). These messages may be displayed in UI or logged.
- Files: `lib/kernel/utils/path_validator.dart:71-72`
- Current mitigation: Error messages are only used internally (`validationError` notifier) and via `debugPrint`/`log.d` (debug-only).
- Recommendations: Sanitize paths in user-facing error messages — show only filename, not full path. Keep full path only in debug logs.

**URL Scheme Whitelist Includes http://:**
- Risk: `PathValidator._urlSchemes` includes `http://`, allowing unencrypted media streams. For a desktop media player playing user-selected content, this is acceptable (user explicitly provides the URL), but worth noting.
- Files: `lib/kernel/utils/path_validator.dart:35`
- Current mitigation: URLs are only accepted from user input (file picker, drag-drop), not from untrusted sources.
- Recommendations: No change needed for local media player. If remote content discovery is added, restrict to `https://` and `rtmps://`.

**No Input Sanitization on Playlist JSON:**
- Risk: `Playlist.fromJson()` and `PlaylistItem.fromJson()` parse JSON from disk without schema validation. Malformed JSON could cause unexpected behavior.
- Files: `lib/kernel/playlist/playlist.dart:277`, `lib/kernel/models/playlist_item.dart:45`
- Current mitigation: Individual item parsing is wrapped in try-catch (line 289-295), corrupt items are skipped. Index values are clamped.
- Recommendations: Current defensive parsing is adequate for a local desktop app. No external JSON sources.

## Performance Bottlenecks

**PositionPoller 250ms Interval:**
- Problem: Timer fires every 250ms to poll `_player.position` via FFI. During playback, this is 4 FFI calls/second.
- Files: `lib/kernel/engine/position_poller.dart:17`
- Cause: mdk/FFmpeg doesn't provide a push-based position callback; polling is the only option.
- Improvement path: Already optimized — only updates `ValueNotifier` when value changes (avoids unnecessary widget rebuilds). URL paths additionally poll `buffered()`. Local files skip buffered polling entirely.

**VideoProcessingService Persists All Settings on Every Change:**
- Problem: Each slider change triggers `_persistAll()` which calls 7 individual `SettingsStore.save*()` methods. With 50ms debounce, rapid slider movement causes burst writes.
- Files: `lib/kernel/services/video_processing_service.dart:86-95`
- Cause: Each setting is saved individually via `SettingsStore` (sequential SharedPreferences writes).
- Improvement path: Use `SettingsStore.saveAll()` instead of 7 individual calls. Increase debounce to 200ms for slider interactions. Consider only persisting on slider release (onChangedEnd) rather than every pixel.

**SettingsStore Sequential Writes:**
- Problem: `saveAll()` performs 20+ sequential `await` calls to SharedPreferences. Each write is a platform I/O call.
- Files: `lib/kernel/persistence/settings_store.dart:279-313`
- Cause: RC-4 decision to use sequential writes for data consistency (vs `Future.wait` which could partial-fail).
- Improvement path: Batch all key-value pairs into a single `SharedPreferences.setMap()` if the API supports it. Or accept the ~4ms sequential cost (documented as acceptable in RC-4 comment).

## Fragile Areas

**MediaEngine Interface (13 ValueNotifiers):**
- Files: `lib/kernel/engine/media_engine.dart`
- Why fragile: Any new engine implementation must correctly manage 13 ValueNotifier lifecycles (create, update, dispose). Missing disposal causes memory leaks. Missing state updates cause UI desync.
- Safe modification: When adding a new notifier, update: (1) `MediaEngine` interface, (2) `FvpEngine` implementation, (3) `FakeEngine` test double, (4) all tests that check notifier values.
- Test coverage: `FakeEngine` covers all 13 notifiers. `FvpEngine` tests are limited (FFI-dependent).

**PlaybackNavigator.openGeneration Guard:**
- Files: `lib/kernel/services/playback_navigator.dart:24`
- Why fragile: The generation counter prevents stale async callbacks from applying, but the pattern is easy to get wrong. Missing `if (gen != openGeneration) return;` check after any `await` would cause race conditions.
- Safe modification: Always add generation checks after every `await` in `playIndex()`. The current code does this correctly (lines 53, 180, 254, 336).
- Test coverage: Covered by `playback_navigator_test.dart` and `playback_controller_test.dart`.

**PlaylistStore Static State Coordination:**
- Files: `lib/kernel/persistence/playlist_store.dart`
- Why fragile: 3 static fields (`_debounce`, `_pendingJson`, `_writeInFlight`) must be coordinated. The `reset()` method must clear all 3. The `_flush()` method must handle concurrent calls via `_writeInFlight`.
- Safe modification: Always update `reset()` when adding new static fields. Test isolation depends on calling `reset()` in `setUp()`.
- Test coverage: `PlaylistStore.reset()` is `@visibleForTesting`. Tests use it correctly.

**AppState initState → _init Race:**
- Files: `lib/app.dart:32-59`
- Why fragile: `initState()` calls `_init()` (async) without awaiting. The `_ready` flag gates the UI, but between `initState` and `_init` completing, the widget is in a partial state. If `dispose()` is called before `_init()` completes, `setState(() => _ready = true)` runs on unmounted widget.
- Safe modification: The `if (mounted)` guard on line 59 prevents the crash, but the pattern is subtle.
- Test coverage: Not directly tested (App is a StatefulWidget, no widget tests exist).

## Scaling Limits

**Playlist In-Memory Storage:**
- Current capacity: Entire playlist stored in `List<PlaylistItem>` in memory.
- Limit: Practical limit ~10,000 items (memory) and ~1,000 items (JSON serialization/deserialization speed).
- Scaling path: For very large playlists, switch to database storage (sqflite/drift) with pagination.

**SharedPreferences for Settings:**
- Current capacity: All settings in a single SharedPreferences instance.
- Limit: SharedPreferences loads all keys into memory on first access. With 20+ keys, this is fine. At 100+ keys, startup cost grows.
- Scaling path: Not needed for current key count. If settings grow significantly, consider grouping into JSON blobs.

## Dependencies at Risk

**fvp 0.36.2:**
- Risk: FFI binding to native MDK/FFmpeg libraries. Version pinned to `^0.36.2`. Breaking changes in MDK API would require updating all `FvpEngine` FFI calls.
- Impact: Core playback functionality. Any breakage blocks the entire app.
- Migration plan: No alternative engine currently implemented. `MediaEngine` interface exists specifically to allow swapping backends.

**shadcn_flutter 0.0.52:**
- Risk: Pre-1.0 package with frequent breaking changes. The `0.0.x` versioning suggests rapid iteration.
- Impact: UI components may break on upgrade.
- Migration plan: Pin to exact version (`0.0.52` not `^0.0.52`). Evaluate on each upgrade.

**easy_localization 3.0.8:**
- Risk: Localization package. If abandoned, switching to `flutter_localizations` + `intl` is straightforward.
- Impact: Low — localization is a thin layer.
- Migration plan: Already uses `flutter_localizations` delegates. `easy_localization` may be removable if only used for string loading.

## Missing Critical Features

**No Widget Tests:**
- Problem: Zero widget tests exist. All 238 tests are unit tests. UI behavior (player screen, control bar, playlist panel, settings dialog) is completely untested.
- Blocks: Confident UI refactoring. Visual regressions go undetected.

**No Integration Tests:**
- Problem: No `integration_test/` directory exists. End-to-end flows (open file → play → seek → pause → next track) are untested.
- Blocks: Confidence in full playback flow correctness.

**No Error Recovery UI:**
- Problem: `App` shows a static "Ready" placeholder. No actual player UI is connected. Error states from `FvpEngine` are stored in `errorMessage` ValueNotifier but no widget displays them.
- Blocks: Users cannot see error messages or recover from failures.

## Test Coverage Gaps

**FvpEngine (555 lines, 0 dedicated tests):**
- What's not tested: `open()`, `play()`, `pause()`, `stop()`, `seekTo()`, `setVolume()`, `setMute()`, `togglePlayPause()`, `setPlaybackRate()`, `setRange()`, `setVideoEffect()`, `rotate()`, `setAspectRatio()`, `setDeinterlace()`, `setExternalSubtitle()`, `setSubtitleDelay()`, `setEqualizer()`, `dispose()`.
- Files: `lib/kernel/engine/fvp_engine.dart`
- Risk: Core playback engine has no unit tests. All testing is indirect via `FakeEngine` which doesn't exercise FFI paths.
- Priority: High — but constrained by FFI dependency. Consider adding more mock-based tests for state machine logic.

**PlaylistStore (172 lines, 0 dedicated tests):**
- What's not tested: `save()`, `load()`, `clear()`, `dispose()`, `_flush()`, `_migrateHistory()`.
- Files: `lib/kernel/persistence/playlist_store.dart`
- Risk: Persistence layer is untested. File I/O, atomic rename, debounce, and migration logic all unverified.
- Priority: High — persistence bugs cause data loss.

**App Widget (116 lines, 0 tests):**
- What's not tested: `initState()`, `_init()`, `dispose()`, `build()`.
- Files: `lib/app.dart`
- Risk: App initialization (parallel `Future.wait`, prewarm, locale loading) is untested.
- Priority: Medium — initialization bugs cause startup failures.

**MotionUtils (28 lines, 0 tests):**
- What's not tested: `update()`, `duration()`, `curve()`, `isReducedMotion`.
- Files: `lib/kernel/utils/motion_utils.dart`
- Risk: Accessibility feature (reduced motion) is untested.
- Priority: Low — simple utility with minimal logic.

**MediaState/PlayMode/VideoEffectType Enums:**
- What's not tested: Enum values and their ordering (used by `SettingsStore` for index-based persistence).
- Files: `lib/kernel/models/media_state.dart`, `lib/kernel/models/play_mode.dart`, `lib/kernel/models/video_effect_type.dart`
- Risk: Adding/removing/reordering enum values breaks persisted settings (indices shift).
- Priority: Medium — already mitigated by clamp guards in `SettingsStore`, but no test verifies enum stability.

---

*Concerns audit: 2026-05-09*
