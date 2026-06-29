<!-- refreshed: 2026-06-25 -->

# Codebase Concerns

## HIGH Severity

### 1. Bang Operator (`!.`) Proliferation (~20 usages)
Multiple files force-unwrap nullable fields without guards. Each is a potential crash site.

| File | Line(s) | Risk |
|------|---------|------|
| `fullscreen_controller.dart` | 166-168 | `_savedSnapshot!` -- crash if exitFullscreen called before save |
| `media_info_dialog.dart` | 55-65 | `info.video!.width` etc. -- crash if video stream missing |
| `control_bar.dart` | 163, 190 | `resizing!.value`, `child!` |
| `glass_container.dart` | 94, 121 | `resizing!.value`, `child!` |
| `keyboard_handler.dart` | 108 | `focused.context!.widget` |
| `playlist_panel.dart` | 189 | `widget.resizing!.value` |
| `aurora_background.dart` | 293 | `blobImages!.length` after null check (redundant pattern) |
| `edge_glow.dart` | 161 | `_pulseController!.value` |
| `log.dart` | 230, 232 | `_sink!.writeln/flush` -- crash if init failed |
| `startup_coordinator.dart` | 52-53 | `_phaseWatches[phase]!` |

**Fix:** Replace with `?.` + null-aware operators or guard with `if (x != null)`.

### 2. Hardcoded Colors Violate Design System
Many UI files contain `Color(0x...)` instead of `Tokens.*` constants.

- `app.dart:92,95,103,122,185,193,194` -- 7 hardcoded colors in quick menu
- `aurora_background.dart:31-33,161,210` -- 5 hardcoded colors
- `thumbnail_tile.dart:297` -- hardcoded overlay color
- `osd_overlay.dart:135` -- track color
- Theme accent colors duplicated in 4 places: `theme_service.dart`, `general_tab.dart`, `settings_panel.dart`, `app.dart`

**Impact:** Theme changes require hunting 10+ files. Single source of truth needed in `ThemeService.accents`.

### 3. Large Files Needing Split (>400 lines, non-generated)

| File | Lines | Suggestion |
|------|-------|------------|
| `fvp_engine.dart` | 724 | God object with 15+ ValueNotifiers. Verify existing extractions (FvpCallbackHandler, PositionPoller, TrackManager) are complete |
| `progress_bar.dart` | 437 | Extract thumbnail tooltip widget |
| `settings_store.dart` | 436 | Extract validation/sanitation into `settings_validator.dart`; 26+ static methods |
| `control_bar.dart` | 429 | Extract volume/seek/speed sub-widgets |
| `settings_panel.dart` | 402 | Complex deferred-apply logic; tabs partially extracted |

### 4. Git History: Fullscreen Instability Pattern
Repeated reverts and fixes signal fragile fullscreen/window management:
- `91dcc00` -- Revert WM_SIZING aspect ratio lock
- `901e10a` -- Revert "remove fullscreen mode"
- `7ba6ccf`, `2b902df` -- Multiple fullscreen gap/exit fixes
- `a13e2d7`, `54348b0` -- Frameless border and mode switching fixes

Needs focused integration tests and a state machine for window mode transitions.

### 5. Race Condition in Fullscreen Controller
`FullscreenController` uses Completer-based mutex that is not reentrant-safe. Rapid F-key presses during transition can corrupt saved window state, leaving the window stuck in partial fullscreen.

**Fix:** Queue pending transitions or add a cooldown period after each transition.

## MEDIUM Severity

### 6. Silent Catch Blocks
`linux_platform_fullscreen.dart:53,56` -- Two `catch (_)` blocks swallow errors without logging. Platform fullscreen failures leave window in inconsistent state with no diagnostics.

`folder_scanner.dart:63-65` -- `on Exception { return []; }` silently swallows permission errors and disk failures.

**Fix:** At minimum `debugPrint` the error. Consider returning a result type with error info.

### 7. Static Mutable State in Persistence Layer
`PlaylistStore` and `SettingsStore` use static fields for caching, making test isolation fragile.

- `playlist_store.dart:28-35` -- `static Timer? _debounce`, `static String? _pendingJson`
- `settings_store.dart:23` -- `static SharedPreferences? _cachedPrefs`

Tests must call `reset()` methods. Concurrent test runs may interfere.

### 8. Windows-Only Log Path
`log.dart:148-151` -- Uses `%APPDATA%` which is Windows-only. Logging silently fails on macOS/Linux.

**Fix:** Use `path_provider`'s `getApplicationSupportDirectory()`.

### 9. Magic Numbers in Settings Store
`settings_store.dart` hardcodes window dimension bounds (`1280`, `1024`, `8192`, `4608`) without named constants. Other scattered magic numbers: `playback_navigator.dart:46` (1000ms), `linux_platform_fullscreen.dart:90` (1280x720), `aspect_ratio_mode.dart:7,9` (epsilon values without explanation).

### 10. Unsafe Cast + Bang Double Risk
`app.dart:86` -- `findRenderObject()! as RenderBox` chains force-unwrap with unsafe downcast. If RenderObject is not a RenderBox, throws `TypeError` at runtime with no useful message.

### 11. FFI Memory Safety (Mostly Good)
- **Linux fullscreen** -- `calloc`/`free` in try/finally. Correct, but errors are silently discarded (see item 6).
- **Win32 fullscreen** -- `Pointer<Utf16>` for window class/name lookups. Verify all allocations are freed.
- **Window HWND lookup** (`win32_platform_fullscreen.dart:127-133`) finds Flutter window by class name `FLUTTER_RUNNER_WIN32_WINDOW`. Fragile if Flutter changes the name or multiple windows are open. Cache HWND on first lookup.

### 12. Inconsistent Engine Error Reporting
`fvp_engine.dart` error handling varies by operation: `open()`/`play()` set user-visible `errorMessage`, but `pause()`/`stop()`/`setVolume()` only log. User has no visibility into non-critical failures.

### 13. No Crash Recovery
If the app crashes mid-playback, saved state may be inconsistent (playlist saved but position not, or vice versa). Use single atomic write or write-ahead log.

## LOW Severity

### 14. Stub Platform Implementations
- `macos_thumbnail_provider.dart` -- TODO for QLThumbnailGenerator FFI
- `linux_thumbnail_provider.dart` -- Stub alongside `noop_thumbnail_provider.dart`
- `display_config.dart:49` -- TODO for Win32 FFI refresh rate detection

### 15. Test Coverage Gaps
No tests found for:
- **UI layer**: `player_screen`, `playlist_panel`, `glass_container`, `aurora_background`, `settings_panel`, `control_bar`, `progress_bar`
- **Services**: `locale_service`, `theme_service`, `folder_scanner`
- **Utils**: `screen_utils`, `memory_monitor`

Golden tests exist but widget interaction tests are thin. No integration tests for engine lifecycle (open/play/pause/stop/seek state transitions).

### 16. Log File Rotation
`log.dart:169` -- `_RotatingFileOutput` with `maxBytes: 2 * 1024 * 1024` (2MB). Verify rotation doesn't lose log entries during rotation boundary.

### 17. Aurora Background Ticker During Paused Video
`aurora_background.dart:66-68` -- Ticker pauses only when state is not `idle`, but doesn't account for `paused` state where video surface is still visible. Unnecessary GPU usage.

---

*Concerns audit: 2026/06/25*
