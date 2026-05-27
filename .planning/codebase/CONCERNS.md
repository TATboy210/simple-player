# Codebase Concerns

**Analysis Date:** 2026-05-23

## Tech Debt

**Window Service Triplication:**
- Issue: `WindowService`, `MacosWindowService`, `LinuxWindowService` share 90%+ identical code (init, minimize, toggleMaximize, close, startDragging, toggleFullscreen, exitFullscreen, toggleAlwaysOnTop). Each is ~280-300 lines with the same try-catch pattern, same Completer init guard, same `_togglingFullscreen`/`_closing` mutex flags.
- Files: `lib/window/window_service.dart` (302 lines), `lib/window/macos_window_service.dart` (286 lines), `lib/window/linux_window_service.dart` (279 lines)
- Impact: Every bug fix or feature addition to window management must be replicated 3 times. The recent extraction of `WindowStateService` and `WindowPersistenceService` helped, but the platform services still duplicate the control flow and error handling.
- Fix approach: Extract a base mixin or abstract class with the shared lifecycle/state/error-handling logic. Platform services override only the native-specific methods (fullscreen toggle, style manipulation). The `_fullscreen` field in `WindowService` is Windows-only; other platforms can have a no-op.

**settings_card.dart Oversized:**
- Issue: `lib/ui/shared/settings_card.dart` is 754 lines -- the largest non-generated Dart file in the project. It contains `SettingsCard`, `SettingRow`, `SettingSection`, and multiple helper widgets all in one file.
- Files: `lib/ui/shared/settings_card.dart`
- Impact: Hard to navigate, hard to test individual components, violates the 400-line guideline.
- Fix approach: Split into `settings_card.dart` (container), `setting_row.dart` (row widget), `setting_section.dart` (section grouping). Move shared layout constants to a settings tokens file or keep them in `Tokens`.

**Silent Exception Swallowing:**
- Issue: Two `catch (_)` blocks silently swallow exceptions with no logging. Elsewhere, ~50+ `catch (e)` blocks log via `debugPrint` but never rethrow or surface errors to the user -- errors are silently continued.
- Files: `lib/kernel/engine/fvp_engine.dart:538` (`on Exception catch (_) { return 0; }`), `lib/kernel/persistence/playlist_store.dart:136` (`catch (_) { // 跳过损坏项 }`)
- Impact: Silent failures make debugging production issues extremely difficult. The fvp_engine case silently returns 0 for subtitle delay on any parse error, masking real problems.
- Fix approach: At minimum, log all caught exceptions with `debugPrint`. For user-facing operations, surface errors via the OSD or error banner. Reserve `catch (_)` only for truly ignorable cases (e.g., corrupted playlist items during migration) and add a comment explaining why.

**TODO/Stub Implementations:**
- Issue: Multiple TODO markers indicate incomplete features that ship in the codebase.
- Files:
  - `lib/kernel/services/macos_thumbnail_provider.dart` -- entire class returns `null`, TODO for QLThumbnailGenerator FFI
  - `lib/kernel/services/subtitle_service.dart:60` -- `TODO: implement online subtitle search`
  - `lib/kernel/services/subtitle_service.dart:65` -- `TODO: implement subtitle style adjustment`
- Impact: macOS users get no thumbnails. Subtitle search/style features are advertised but non-functional.
- Fix approach: Either implement or remove from the public API. For macOS thumbnails, the stub should at minimum log a warning so users know it's expected behavior.

**ThumbnailService Static Singleton:**
- Issue: `ThumbnailService` uses static mutable state (`_impl`, `_cache`, `_order`) with no thread safety and no way to reset or test.
- Files: `lib/kernel/services/thumbnail_service.dart`
- Impact: Cannot write proper unit tests. Cache grows unbounded in theory (capped at 200 but `_order` list is never compacted efficiently). State leaks between test runs.
- Fix approach: Convert to instance-based with constructor injection. Pass `ThumbnailProvider` via DI. Use `LinkedHashMap` for O(1) LRU instead of separate `Map` + `List`.

## Known Bugs

**Logo Egg Random Bug (Fixed):**
- Status: Fixed in commit history -- `Random().nextInt(1000) == true` was always false, changed to `== 0`.
- Note: No regression test exists for this fix.

**Playlist Corruption on Crash:**
- Symptoms: If the app crashes during `_flush` in `PlaylistStore`, the JSON file can be partially written.
- Files: `lib/kernel/persistence/playlist_store.dart`
- Trigger: App crash or power loss during the 3-attempt flush loop.
- Workaround: The retry logic (up to 3 attempts) mitigates but does not eliminate the risk. No atomic write pattern (write-to-temp + rename) is used.

## Security Considerations

**File Path Validation:**
- Risk: User-supplied file paths from drag-and-drop or file picker are passed through `PathValidator` but the validation is basic (checks existence and extension). Symlink traversal, UNC paths, and very long paths are not explicitly blocked.
- Files: `lib/kernel/services/path_validator.dart`, `lib/kernel/services/file_operations.dart`
- Current mitigation: `PathValidator.validate()` checks file existence and allowed extensions.
- Recommendations: Add canonicalization via `File.resolveSymbolicLinks()` before use. Block UNC paths (`\\server\share`) on Windows. Add a max path length check.

**Native FFI Safety:**
- Risk: `FullscreenController` and `WindowService` use `dart:ffi` to call Win32 APIs directly. Incorrect pointer handling or wrong struct sizes could cause crashes.
- Files: `lib/window/fullscreen_controller.dart`, `lib/window/window_service.dart`
- Current mitigation: FFI bindings use `package:ffi` with `calloc`/`free`. The `FullscreenController` is isolated in its own class.
- Recommendations: Add bounds checking on HWND values. Consider using `package:win32` for type-safe bindings instead of raw FFI.

## Performance Bottlenecks

**fvp Rendering Pipeline (9 Known Bottlenecks):**
- Problem: The fvp plugin's D3D11 rendering path has 9 documented performance bottlenecks ranked by severity.
- Files: fvp plugin (external), `lib/kernel/engine/fvp_engine.dart`
- Known bottlenecks (from prior analysis):
  1. `d3d11.sync.cpu` -- GPU-CPU sync stall
  2. `Flush` -- D3D11 pipeline flush
  3. Mutex contention in frame handoff
  4. `CopyResource` for texture copy
  5-9. Various pipeline stalls
- Improvement path: Application-layer mitigations (reduce texture copies, use snapshot debounce), C++ plugin layer optimizations, MDK configuration tuning. See `reference_fvp_optimization_plan.md` for the 3-layer optimization plan.

**Thumbnail LRU Cache Inefficiency:**
- Problem: `ThumbnailService._cache` uses a `Map<String, ImageProvider>` + `List<String>` for LRU ordering. The `_touch` method likely does a linear scan to move items.
- Files: `lib/kernel/services/thumbnail_service.dart`
- Cause: `_order.remove(filePath)` is O(n) on every cache hit.
- Improvement path: Replace with `LinkedHashMap` for O(1) access-order tracking, or implement a proper LRU cache class.

## Fragile Areas

**Window Layer Race Conditions:**
- Files: `lib/window/window_service.dart`, `lib/window/macos_window_service.dart`, `lib/window/linux_window_service.dart`
- Why fragile: Multiple boolean guards (`_initialized`, `_disposed`, `_togglingFullscreen`, `_closing`) and a `Completer<void>? _initCompleter` manage async lifecycle. If any guard is checked in the wrong order or a `Future` completes after disposal, the app can hang or crash.
- Safe modification: Always check `_disposed` before any async operation. Always complete the `_initCompleter` in a `finally` block. Never `await` after checking `_initialized` without re-checking.
- Test coverage: `test/window/window_service_test.dart` exists but only covers the Windows implementation. No tests for Mac/Linux services.

**FullscreenController Native Calls:**
- Files: `lib/window/fullscreen_controller.dart`
- Why fragile: Direct Win32 FFI calls to `SetWindowLongW`, `SetWindowPos`, `MonitorFromWindow`, `GetMonitorInfoW`. Any incorrect parameter (wrong HWND, wrong style flags) causes silent failure or crash.
- Safe modification: Always test fullscreen toggle on actual Windows hardware. The `_windowedRect` cache must be populated before entering fullscreen and cleared on disposal.
- Test coverage: No unit tests (requires Win32 environment).

**PlaybackController Mixin Chain:**
- Files: `lib/kernel/services/playback_controller.dart`
- Why fragile: The controller uses mixin composition for playback logic. Changes to one mixin can affect state assumptions in another. The `openGeneration` guard prevents stale completions but adds complexity.
- Safe modification: When modifying any mixin, verify all `ValueNotifier` listeners are still consistent. Test the full open-play-next-pause cycle.

**Aspect Ratio + Fullscreen Interaction:**
- Files: `lib/kernel/window/aspect_ratio_service.dart`, `lib/window/fullscreen_controller.dart`
- Why fragile: Aspect ratio changes during fullscreen can block the fullscreen toggle (ratio lock). The `setAspectRatio` call can fail silently.
- Safe modification: Always test aspect ratio changes in both windowed and fullscreen modes. The ratio should be temporarily disabled during fullscreen transitions.

## Scaling Limits

**Static Singletons:**
- Current: `ThumbnailService`, `OsdService`, and several providers use static singleton patterns.
- Limit: Cannot run multiple instances, cannot inject test doubles cleanly, state leaks between tests.
- Scaling path: Convert to instance-based services registered via a simple service locator or constructor injection.

**ValueNotifier Fan-Out:**
- Current: Each `ValueNotifier` in `MediaEngine` triggers individual widget rebuilds via `ValueListenableBuilder`.
- Limit: With many notifiers (position, volume, mute, state, speed, etc.), widget tree can rebuild excessively if listeners are not carefully scoped.
- Scaling path: Consider grouping related state into a single `ChangeNotifier` or using `Selector` to minimize rebuilds.

## Dependencies at Risk

**fvp (MDK/FFmpeg wrapper):**
- Risk: Single external dependency for all media playback. If fvp has breaking changes or bugs, the entire player is affected. The plugin has known D3D11 performance bottlenecks.
- Impact: Playback, seeking, subtitle rendering, audio track switching all depend on fvp.
- Migration plan: No direct alternative. mpv-based Flutter plugins exist but have different API surfaces. Abstracting behind `MediaEngine` interface provides some insulation.

**window_manager:**
- Risk: Used for all window operations (minimize, maximize, fullscreen, always-on-top). Platform-specific behavior varies.
- Impact: Window management is core UX. Breakage affects all platforms.
- Migration plan: The `WindowBridge` abstraction provides insulation. Platform services can be rewritten to use direct FFI (as partially done for Windows fullscreen).

## Missing Critical Features

**No Integration Tests:**
- Problem: Zero integration tests exist. No `integration_test/` directory.
- Blocks: Cannot verify end-to-end flows (open file -> play -> seek -> pause -> next track) on real devices. CI/CD cannot catch platform-specific regressions.
- Priority: HIGH

**No Golden Tests:**
- Problem: Zero golden tests exist. No `test/golden/` directory.
- Blocks: Cannot detect visual regressions in UI components (control bar, progress bar, playlist panel, settings dialog).
- Priority: MEDIUM

**macOS/Linux Thumbnail Extraction:**
- Problem: `MacosThumbnailProvider` returns `null` for all files. `LinuxThumbnailProvider` likely has similar limitations.
- Blocks: macOS/Linux users see no file thumbnails in the playlist.
- Priority: LOW (desktop-only feature, not blocking playback)

## Test Coverage Gaps

**Untested Window Layer:**
- What's not tested: `FullscreenController`, `WindowStateService`, `WindowPersistenceService`, `MacosWindowService`, `LinuxWindowService`, `GeometryStore` (partially tested).
- Files: `lib/window/fullscreen_controller.dart`, `lib/window/window_state_service.dart`, `lib/window/window_persistence_service.dart`, `lib/window/macos_window_service.dart`, `lib/window/linux_window_service.dart`
- Risk: Window management is the most platform-sensitive code. Bugs cause UX issues (stuck fullscreen, lost geometry, resize glitches) that are hard to reproduce and debug.
- Priority: HIGH

**Untested Settings Panel:**
- What's not tested: `SettingsCard` (754 lines), `SettingsPanel`, `ShortcutsTab`, `VideoTab` -- the entire settings dialog system.
- Files: `lib/ui/shared/settings_card.dart`, `lib/ui/dialogs/settings_panel.dart`, `lib/ui/dialogs/settings/shortcuts_tab.dart`, `lib/ui/dialogs/settings/video_tab.dart`
- Risk: Settings changes can break locale switching, theme application, and keyboard shortcut binding. The deferred-apply pattern adds complexity.
- Priority: MEDIUM

**Untested Playlist UI:**
- What's not tested: `PlaylistPanel`, `FolderTab`, `HistoryTab`, `ThumbnailTile` -- the entire playlist UI.
- Files: `lib/ui/playlist/playlist_panel.dart`, `lib/ui/playlist/folder_tab.dart`, `lib/ui/playlist/history_tab.dart`, `lib/ui/playlist/thumbnail_tile.dart`
- Risk: Playlist is the primary navigation surface. Drag-and-drop, folder scanning, and history sorting are complex interactions.
- Priority: MEDIUM

**Untested Aurora Background:**
- What's not tested: `AuroraBackground` shader (296 lines) -- custom fragment shader rendering.
- Files: `lib/ui/shared/aurora_background.dart`
- Risk: Shader compilation failures on different GPUs/drivers. No visual regression test.
- Priority: LOW

---

*Concerns audit: 2026-05-23*
