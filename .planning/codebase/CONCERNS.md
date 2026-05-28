# Codebase Concerns

**Analysis Date:** 2026-05-28

## HIGH Severity

### 1. Platform-specific files deleted mid-branch
**Files:** `lib/window/window_service.dart`, `lib/ui/shared/resize_notifier.dart`
**Impact:** Git status shows 12 files modified — large refactor in progress. Any code referencing WindowService or ResizeNotifier will fail at compile time.
**Fix:** Verify all references updated before merge. Ensure functionality absorbed into new architecture.

### 2. fvp D3D11 sync CPU/GPU bottleneck [MITIGATED Phase 3]
**File:** `lib/kernel/engine/fvp_engine.dart:141-153`
**Impact:** `updateTexture()` does D3D11 CopyResource + sync flush per frame. On 4K content, causes frame drops.
**Mitigation:** Phase 3 Plan 01 added `_applyD3d11Defaults()` with `d3d11.sync.cpu=1` (safe default) + `video.decoders=D3D11,NVDEC,FFmpeg` (hardware-first). Runtime-tunable via Performance settings tab. See PERFORMANCE.md for details.
**Remaining:** Monitor fvp upstream for async texture APIs. Consider D3D11 MAP_WRITE_DISCARD pattern.

### 3. ~~Single `catch (_)` silently swallows errors~~ [RESOLVED Phase 1]
**File:** `lib/kernel/persistence/playlist_store.dart:168`
**Resolution:** Changed to `on Exception catch (e)` + `log.d()` (Phase 1, commit f4f50bf). Verified 2026-05-29: zero `catch (_)` patterns remain in lib/.

### 4. ~~`on Object catch` catches Error subtypes (3 places)~~ [RESOLVED Phase 1]
**Files:**
- `lib/kernel/engine/engine_prewarm.dart:56`
- `lib/features/player/services/subtitle_service.dart:37`
- `lib/features/player/services/subtitle_service.dart:59`
**Resolution:** All 3 changed to `on Exception catch (e)` with `log.d()` (Phase 1, commit f4f50bf). Verified 2026-05-29: zero `on Object catch` patterns remain in lib/.

## MEDIUM Severity

### 5. Static singletons — untestable global state
**Files:** ThumbnailService, SettingsStore, EnginePrewarm, PerfMonitor
**Impact:** Makes unit testing difficult, creates hidden coupling, prevents parallel test execution.
**Fix:** Use constructor injection. Apply `@visibleForTesting` reset pattern.

### 6. Duplicate `formatMs()` utility
**Files:** `lib/utils/time_utils.dart` AND `lib/kernel/utils/time_utils.dart`
**Impact:** Maintenance drift — if one is updated, the other may be forgotten.
**Fix:** Delete `lib/utils/time_utils.dart`, update imports.

### 7. macOS thumbnail provider is a stub
**File:** `lib/kernel/services/macos_thumbnail_provider.dart:7`
**Impact:** macOS users see no thumbnails. TODO: QLThumbnailGenerator Objective-C FFI.
**Fix:** Implement or use `file_icon` package.

### 8. Windows thumbnail provider disabled
**File:** `lib/kernel/services/thumbnail_service.dart:27`
```dart
TargetPlatform.windows => const NoopThumbnailProvider(),
```
**Impact:** Despite CLAUDE.md mentioning "Win32 COM thumbnail extraction," returns null.
**Fix:** Implement COM provider or update documentation.

### 9. `app.dart` unsafe casts
**File:** `lib/app.dart:58-67`
```dart
engine: engine as MediaEngine,  // unsafe cast from Object?
videoProcessing: videoProcessing as VideoProcessingService?,
```
**Impact:** `DeferredPlayerFeature` uses `Object?` to avoid eager imports. Runtime TypeError if wrong type.
**Fix:** Use typed callback interface or sealed class.

### 10. Large files approaching 800-line threshold

| File | Lines | Concern |
|------|-------|---------|
| `app_localizations.dart` | 974 | Auto-generated — acceptable |
| `fvp_engine.dart` | 633 | Single class, 12 ValueNotifiers |
| `settings_store.dart` | 446 | 24 nearly identical save methods |
| `settings_panel.dart` | 386 | Complex UI |

**Fix:** Extract sub-widgets from settings_card. Use generic `_saveField<T>()` for SettingsStore.

### 11. ControlsOverlay fragile cache invalidation
**File:** `lib/ui/player/controls_overlay.dart:71-138`
**Impact:** 8 nullable cache fields for ControlBar caching. Adding a new property requires updating both cache fields and `needsRebuild`.
**Fix:** Use single immutable state object with `==` override.

### 12. URL scheme whitelist trusts upstream
**File:** `lib/kernel/services/path_validator.dart:57`
**Impact:** URLs bypass path traversal checks. Low practical risk (FFmpeg handles URL parsing).
**Fix:** Add basic URL validation (no null bytes, max length).

## LOW Severity

### 13. Test coverage ~64% — below 80% target
**Coverage:** 1,161 / 1,822 lines = 63.7%
**Untested:** settings_panel, aurora_background, startup_coordinator, localization

### 14. ~~PerfMonitor unbounded list growth~~ [RESOLVED Phase 3 Plan 01]
**File:** `lib/kernel/utils/perf_monitor.dart`
**Resolution:** Replaced unbounded lists with fixed-capacity ring buffer (`_maxFrames = 300`). Uses `_writeIndex % _maxFrames` for overwrite semantics. No periodic memory spikes.

### 15. ~~PerfMonitor.mark()/markEnd() dead code~~ [RESOLVED Phase 3 Plan 01]
**File:** `lib/kernel/utils/perf_monitor.dart`
**Resolution:** `mark()`/`markEnd()` wrapper methods removed. `window_service.dart` updated to use `developer.Timeline.startSync/finishSync` directly.

### 16. EnginePrewarm fire-and-forget
**File:** `lib/main.dart:17-22`
**Impact:** If prewarm fails, error swallowed, subsequent player pays cold-start cost.

### 17. AppSettings not immutable
**File:** `lib/kernel/persistence/settings_store.dart:11-57`
**Impact:** No `copyWith()`, no `==`/`hashCode`. VideoProcessingState uses freezed — AppSettings should follow.

### 18. ~~FvpEngine.subtitleDelay catches silently~~ [RESOLVED Phase 1]
**File:** `lib/kernel/engine/fvp_engine.dart:567`
**Resolution:** Changed to `on Exception catch (e)` with `log.d()` (Phase 1). Verified 2026-05-29: uses typed exception catch with logging.
