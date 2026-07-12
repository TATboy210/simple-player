# Codebase Concerns

**Analysis Date:** 2026-07-12

## Tech Debt

**Cross-Platform Thumbnail Providers — Stub Implementations:**
- Issue: `MacosThumbnailProvider` always returns `null` (line 12), `NoopThumbnailProvider` returns `null` on Windows (line 29 of `thumbnail_service.dart`). Only Linux has a working implementation via XDG cache.
- Files: `lib/kernel/services/macos_thumbnail_provider.dart`, `lib/kernel/services/thumbnail_service.dart`
- Impact: macOS and Windows users never see video thumbnails in the playlist panel; the `TODO` on line 7 of `macos_thumbnail_provider.dart` notes QLThumbnailGenerator FFI is needed.
- Fix approach: Implement Win32 `IThumbnailProvider` COM FFI for Windows and `QLThumbnailGenerator` Objective-C FFI for macOS, or use `file_selector` / `xdg_directories` to query system thumbnail caches.

**DisplayConfig Refresh Rate Detection — Hardcoded Fallback:**
- Issue: `_detectRefreshRate()` always returns 60Hz (line 69 of `display_config.dart`). The `TODO` on line 64 notes the need for Win32 `GetDeviceCaps(VREFRESH)`.
- Files: `lib/kernel/bridge/display_config.dart`
- Impact: D3D11 sync mode is always `'1'` (sync), even on 144Hz+ displays where async mode (`'0'`) would reduce latency by ~8ms per frame.
- Fix approach: Add Win32 FFI call `GetDeviceCaps(hdc, VREFRESH)` via `dart:ffi` in the existing `Win32FullscreenApi` pattern.

**Deprecated Static Methods Still Present:**
- Issue: `PlaylistStore` has a deprecated static `_instance` field (line 29, `playlist_store.dart`) and `ScreenUtils` has a deprecated `clampToNearestMonitor` method (line 53, `screen_utils.dart`).
- Files: `lib/kernel/persistence/playlist_store.dart`, `lib/kernel/utils/screen_utils.dart`
- Impact: Dead code that may confuse future contributors; lint warnings accumulate.
- Fix approach: Remove deprecated methods and update any remaining callers.

**Features Layer — Dual Responsibility (View + ViewModel):**
- Issue: `PlayerFeature` (283 lines) admits in its doc comment (line 13) it "simultaneously serves View and some ViewModel responsibilities (legacy, future refactoring target)." It holds `BuildContext`, manages UI state, and creates service containers.
- Files: `lib/features/player/player_feature.dart`
- Impact: Harder to test business logic independently from widget tree; violates the stated MVVM separation.
- Fix approach: Extract ViewModel logic into `PlayerViewModel` (a `ChangeNotifier`) and keep `PlayerFeature` as a pure View that delegates to it.

## Known Bugs

**WindowService Silent Catch Blocks:**
- Symptoms: `catch (_) { update(); }` on line 136 of `window_service.dart` silently swallows scheduler phase check failures and falls back to direct mutation.
- Files: `lib/kernel/bridge/window_service.dart:136`, `lib/kernel/bridge/win32/win32_display_enumerator.dart:219`
- Trigger: UI thread scheduler in unexpected phase during window resize or display enumeration.
- Workaround: Already logs in some paths, but the fallback at line 136 is silent. Should at minimum log the exception.

**Fullscreen Confirmation Timeout Path:**
- Symptoms: `_waitForConfirmation` in `window_service.dart` (lines 363-387) falls through to a 20-iteration polling loop (2 seconds total) on timeout, which may cause visible UI lag.
- Files: `lib/kernel/bridge/window_service.dart:363-387`
- Trigger: Native fullscreen callback fails to fire within 500ms (common on Wayland/Linux).
- Workaround: Already handled by polling fallback, but user experiences a 2-second delay before state settles.

## Security Considerations

**No Hardcoded Secrets Detected:**
- Risk: Low. The codebase does not contain hardcoded API keys, tokens, or credentials.
- Current mitigation: `pubspec.yaml` uses `publish_to: 'none'`; `.env` files are not committed (not present in repo).
- Recommendations: Continue monitoring; add a pre-commit hook for secret scanning if the project grows to include API integrations.

**FFI Memory Safety — Generally Sound:**
- Risk: Low. Win32 FFI code in `win32_fullscreen_ffi.dart` uses `calloc` with `finally` blocks for `free()` (e.g., line 342). Pattern is consistent across `getWindowRect`, `getWindowPlacement`, etc.
- Files: `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart`, `lib/kernel/bridge/win32/win32_display_enumerator.dart`
- Recommendations: No action needed; the existing `finally` block pattern is correct.

## Performance Bottlenecks

**Full Playlist Rebuild on Every File Scan:**
- Problem: `FolderScanner` (line 52 of `folder_scanner.dart`) returns an empty list on error, and `PlaylistStore` loads the full playlist as a single JSON blob. No incremental loading.
- Files: `lib/kernel/scanner/folder_scanner.dart`, `lib/kernel/persistence/playlist_store.dart`
- Cause: Entire playlist JSON is deserialized on every app launch; large playlists (1000+ items) may cause a noticeable startup delay.
- Improvement path: Implement streaming JSON parsing or lazy-load playlist entries by folder group.

**LRU Cache Unbounded in ThumbnailService:**
- Problem: `_evictIfNeededImpl()` in `thumbnail_service.dart` evicts by count (max 200), but each entry holds a full `ImageProvider` which may decode a large bitmap into memory.
- Files: `lib/kernel/services/thumbnail_service.dart:16`
- Cause: No size-based eviction; 200 thumbnails at ~1MB each = ~200MB peak.
- Improvement path: Add approximate byte-size tracking or reduce `_maxCacheSize` on low-memory devices.

**WindowService Resize Polling Loop:**
- Problem: `_waitForConfirmation` polls `queryFullscreen()` 20 times at 100ms intervals (2 seconds worst case) when the native callback times out.
- Files: `lib/kernel/bridge/window_service.dart:381-385`
- Improvement path: Already a known limitation; the callback-based approach is primary, polling is fallback only.

## Fragile Areas

**Win32 Fullscreen FFI Layer:**
- Files: `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` (509 lines), `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` (459 lines)
- Why fragile: Direct Win32 API calls (`SetWindowPos`, `GetWindowLong`, `SetWindowLong`) depend on undocumented Windows behavior. Style bit manipulation (`WS_THICKFRAME` removal, `WS_EX_TOPMOST`) is sensitive to Windows version changes. The WARN logs on lines 144-150 of `windows_fullscreen_driver.dart` indicate known edge cases where style stripping fails.
- Safe modification: Always test on Windows 10 + Windows 11; never change style bit flags without reviewing the D-P05/D-P06/D-P07/D-P08 decision docs referenced in the code.
- Test coverage: 765 lines in `test/platform/windows_fullscreen_driver_test.dart` — good, but integration tests are needed for actual Win32 API behavior.

**WindowService — Largest Bridge File (451 lines):**
- Files: `lib/kernel/bridge/window_service.dart`
- Why fragile: Coordinates fullscreen, resize, persistence, geometry save/restore, and confirmation chains. Multiple Timer instances (`_resizeDebounce`, `_resizeEndTimer`) with cancellation logic. The `_confirmByWindowId` map manages async confirmation state.
- Safe modification: Changes to any Timer or Completer logic require careful review of cancellation paths (dispose, error, timeout).
- Test coverage: Unit tests exist but the interaction between Timer, Completer, and Platform callbacks is hard to test in isolation.

**FvpEngine — Complex Composition (628 lines):**
- Files: `lib/kernel/engine/fvp_engine.dart`
- Why fragile: Composes 6 helper classes via mixins (`EngineState`, `TrackControl`, `VideoEffects`, `RendererConfig`) plus direct fields. The factory constructor pattern (lines 51-58) creates all helpers eagerly, but their interactions during state transitions are complex.
- Safe modification: Follow the existing factory pattern; never add `late` fields. Any new helper must be injected in the factory constructor.
- Test coverage: `test/engine/mixin_capability_test.dart` (393 lines) covers capability combinations.

## Scaling Limits

**Playlist Size:**
- Current capacity: No enforced limit; `PlaylistStore` serializes entire list to JSON.
- Limit: JSON serialization of 10,000+ items may cause 100ms+ startup delay and high memory usage.
- Scaling path: Implement streaming/lazy loading, or add a soft cap with warning UI.

**Thumbnail Cache:**
- Current capacity: 200 entries in `_cache` LinkedHashMap.
- Limit: No byte-size tracking; memory usage depends on decoded bitmap size.
- Scaling path: Add size-aware eviction or reduce cap for low-memory devices.

**Test Suite:**
- Current capacity: 94 test files, ~16,000 lines total.
- Limit: `flutter test` full suite runs in reasonable time, but adding more widget tests with golden images will slow CI.
- Scaling path: Shard tests by directory (platform/, widget/, kernel/) in CI.

## Dependencies at Risk

**`fullscreen_window` (Local Package):**
- Risk: Vendored at `packages/fullscreen_window` with only 11 Dart files. The macOS and Linux drivers depend on `FullScreenWindowPlatform` from this package, which wraps MethodChannel calls to native code.
- Impact: Any native plugin update could break fullscreen on macOS/Linux.
- Mitigation: The Win32 path uses direct FFI (no dependency on this package for Windows), but macOS/Linux still depend on it.

**`fvp: ^0.37.2`:**
- Risk: Core rendering dependency; version-pinned to `^0.37.2`. The `mdk.Player` API is the foundation of all playback.
- Impact: Breaking changes in fvp would require rewriting `FvpEngine` and all helpers.
- Mitigation: Version pinning prevents accidental upgrades; `pubspec.lock` committed.

**`window_manager: ^0.5.2`:**
- Risk: Used for window positioning, geometry, and frameless window setup. Version-pinned.
- Impact: Conflicts with Win32 FFI fullscreen code if window_manager internals change.
- Mitigation: `WindowService` wraps all window_manager calls; changes are isolated.

## Missing Critical Features

**Windows Thumbnail Extraction:**
- Problem: No working thumbnail extraction on Windows (returns `null`).
- Blocks: Visual playlist experience on the primary supported platform.

**macOS Thumbnail Extraction:**
- Problem: No working thumbnail extraction on macOS (returns `null`).
- Blocks: Visual playlist experience on macOS.

**Real Refresh Rate Detection:**
- Problem: `DisplayConfig` always reports 60Hz on Windows.
- Blocks: Optimal D3D11 sync mode selection for high-refresh-rate displays.

## Test Coverage Gaps

**Cross-Platform Fullscreen Integration:**
- What's not tested: Actual Win32 API calls in `Win32FullscreenApi` (static methods wrap FFI calls that cannot run in Dart unit tests).
- Files: `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart`
- Risk: Style bit manipulation bugs only surface on real Windows; mock-based tests verify logic but not FFI behavior.
- Priority: High (Windows is primary platform)

**WindowService Timer/Completer Interactions:**
- What's not tested: The race conditions between `_resizeDebounce`, `_resizeEndTimer`, and `_confirmByWindowId` Completer timeouts.
- Files: `lib/kernel/bridge/window_service.dart:141-387`
- Risk: Timer cancellation bugs cause stale state or leaked Completers.
- Priority: Medium (covered by unit tests for individual methods, but not interaction-level)

**FvpEngine State Transitions Under Error:**
- What's not tested: Behavior when `mdk.Player` throws during state transitions (e.g., open fails mid-transition, dispose called during seek).
- Files: `lib/kernel/engine/fvp_engine.dart`
- Risk: Engine may enter inconsistent state on playback errors.
- Priority: Medium (error handling exists via `on Exception catch`, but edge cases are untested)

**ThumbnailService Cache Eviction Under Memory Pressure:**
- What's not tested: Cache behavior when `ImageProvider` objects are large or when cache is near capacity.
- Files: `lib/kernel/services/thumbnail_service.dart`
- Risk: Memory spike when 200 large thumbnails are cached simultaneously.
- Priority: Low (cache is LRU with 200 cap; unlikely to be a real problem in practice)

---

*Concerns audit: 2026-07-12*
