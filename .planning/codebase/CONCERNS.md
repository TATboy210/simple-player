# Codebase Concerns

**Analysis Date:** 2026/06/23

## Tech Debt

### 1. Hardcoded Colors Violate Design System

**Issue:** Many UI files contain hardcoded `Color(0x...)` values instead of using `Tokens.*` constants, violating the project's design system contract.

**Files:**
- `lib/app.dart:92,95,103,122,185,193,194` — 7 hardcoded colors in quick menu
- `lib/ui/shared/aurora_background.dart:31-33,161,210` — 5 hardcoded colors
- `lib/ui/playlist/thumbnail_tile.dart:297` — hardcoded overlay color
- `lib/ui/shared/osd_overlay.dart:135` — track color
- `lib/kernel/services/theme_service.dart:18-20` — accent colors defined here AND in `general_tab.dart:131-133` AND `settings_panel.dart:66`

**Impact:** Theme changes require hunting through 10+ files. Inconsistent colors if one file is missed.

**Fix approach:** Extract all hardcoded colors to `Tokens.*` constants. For theme-specific accents, centralize in `ThemeService.accents` and reference from there.

### 2. Duplicated Theme Accent Colors

**Issue:** The same 3 accent colors (`0xFF2C58F4`, `0xFF00B4D8`, `0xFF2D6A4F`) are defined in 4 separate locations:

| File | Line(s) |
|------|---------|
| `lib/kernel/services/theme_service.dart` | 18-20 |
| `lib/ui/dialogs/settings/general_tab.dart` | 131-133 |
| `lib/ui/dialogs/settings_panel.dart` | 66 |
| `lib/app.dart` | 185, 193 |

**Impact:** Adding a new theme requires editing 4 files. Risk of color mismatch if one is updated but not others.

**Fix approach:** Single source of truth in `ThemeService.accents`. All other locations should reference `ThemeService.accents[i]`.

### 3. Large Files Approaching Limit

**Issue:** Several files exceed the 500-line guideline or are close to it.

| File | Lines | Concern |
|------|-------|---------|
| `lib/kernel/engine/fvp_engine.dart` | 724 | **Exceeds 500** — God object with 15+ ValueNotifiers |
| `lib/l10n/app_localizations.dart` | 1022 | Generated — acceptable |
| `lib/kernel/persistence/settings_store.dart` | 439 | 26+ save/load methods, all static |
| `lib/ui/dialogs/settings_panel.dart` | 402 | Complex state management for deferred apply |
| `lib/ui/shared/aurora_background.dart` | 362 | Custom painting + ticker logic |
| `lib/ui/playlist/playlist_panel.dart` | 358 | Dual-tab layout |
| `lib/ui/player/control_bar.dart` | 350 | Responsive layout logic |

**Impact:** Hard to navigate, test, and modify. `fvp_engine.dart` is the most concerning — it handles open/play/pause/stop/seek/volume/mute/subtitle/tracks/error in one class.

**Fix approach:** Extract `FvpEngine` into smaller mixins or delegates (already has `FvpCallbackHandler`, `PositionPoller`, `TrackManager` — consider further decomposition).

### 4. Static Mutable State in Persistence Layer

**Issue:** `PlaylistStore` and `SettingsStore` use static fields for caching, making test isolation fragile.

**Files:**
- `lib/kernel/persistence/playlist_store.dart:28-35` — `static Timer? _debounce`, `static String? _pendingJson`, `static Future<void>? _writeInFlight`
- `lib/kernel/persistence/settings_store.dart:23` — `static SharedPreferences? _cachedPrefs`

**Impact:** Tests must call `reset()` methods to avoid state leakage. Concurrent test runs may interfere.

**Fix approach:** Consider instance-based stores with dependency injection, or ensure all static state is properly reset in `@visibleForTesting` reset methods (already partially done with `SettingsStore.resetPrewarm()`).

## Platform-Specific Risks

### 5. Windows-Only Platform Code

**Issue:** Core window management features are Windows-only with no macOS/Linux fallback.

**Files:**
- `lib/kernel/bridge/win32/win32_platform_fullscreen.dart` — Entire file is Win32 FFI (140 lines)
- `lib/kernel/bridge/window_service.dart:245-247` — Factory throws `UnsupportedError` for non-Windows
- `lib/kernel/bridge/display_config.dart:49` — TODO for Win32 FFI refresh rate detection

**Impact:** App crashes on macOS/Linux launch due to `UnsupportedError` in `WindowService._createPlatformFullscreen()`.

**Fix approach:** Implement `PlatformFullscreen` for macOS (NSWindow style mask) and Linux (GTK window state). The TODO at `window_service.dart:246` tracks this.

### 6. Stub Platform Implementations

**Issue:** macOS and Linux thumbnail providers are stubs that return empty results.

**Files:**
- `lib/kernel/services/macos_thumbnail_provider.dart:7` — `/// TODO: 实现 QLThumbnailGenerator Objective-C FFI 提取真实缩略图。`
- `lib/kernel/services/linux_thumbnail_provider.dart` — Likely stub (not read but exists alongside noop provider)
- `lib/kernel/services/noop_thumbnail_provider.dart` — Explicit noop fallback

**Impact:** No thumbnail previews on macOS/Linux. Users see empty playlist tiles.

**Fix approach:** Implement `QLThumbnailGenerator` FFI for macOS, `ThumbnailFactory` for Linux (GNOME/KDE).

### 7. Windows-Only Log Path

**Issue:** Log file path uses `%APPDATA%` environment variable, which is Windows-specific.

**File:** `lib/kernel/utils/log.dart:148-151`

```dart
final appData = Platform.environment['APPDATA'];
if (appData == null) return;
final dir = Directory('$appData\\SimplePlayer\\logs');
```

**Impact:** Logging silently fails on macOS/Linux (returns early when `APPDATA` is null).

**Fix approach:** Use `path_provider`'s `getApplicationSupportDirectory()` for cross-platform log path.

## Error Handling Gaps

### 8. Silent Error Swallowing in Scanner

**Issue:** `FolderScanner.scan()` catches all exceptions and returns empty list without logging.

**File:** `lib/kernel/scanner/folder_scanner.dart:63-65`

```dart
} on Exception {
  return [];
}
```

**Impact:** Permission errors, disk failures, or invalid paths are silently ignored. User sees empty folder with no explanation.

**Fix approach:** Log the error and consider returning a result type that includes error information.

### 9. Inconsistent Error Reporting in Engine

**Issue:** Some engine operations set `errorMessage` (user-visible), others only log (developer-visible), with no clear pattern.

**File:** `lib/kernel/engine/fvp_engine.dart`

| Operation | Error handling |
|-----------|---------------|
| `open()` (line 399) | Sets `errorMessage` + `_errorType` |
| `play()` (line 419) | Sets `errorMessage` + `_errorType` |
| `pause()` (line 434) | Only `log.e()` |
| `stop()` (line 447) | Only `log.e()` |
| `seekTo()` (line 464) | Sets `errorMessage` |
| `setVolume()` (line 482) | Via `_guardedAction` — only `log.e()` |

**Impact:** User has no visibility into pause/stop/volume failures. Inconsistent UX.

**Fix approach:** Define error severity levels — critical (open/play) shows UI banner, non-critical (pause/stop) logs only. Document the convention.

## Performance Concerns

### 10. No Debouncing on Playlist Save Triggers

**Issue:** `PlaybackController` calls `savePlaylist()` on every state change (reorder, remove, clear, mode toggle), each triggering the 300ms debounce timer.

**Files:**
- `lib/features/player/services/playback_controller.dart:81,88,98,105` — 4 call sites
- `lib/kernel/persistence/playlist_store.dart:49-52` — debounce implementation

**Impact:** Rapid operations (batch remove, quick reorder) still trigger multiple serializations within the debounce window. The debounce only coalesces the I/O, not the JSON encoding.

**Fix approach:** Move `jsonEncode` into the debounced callback, or debounce at the `PlaybackController` level before calling `PlaylistStore.save()`.

### 11. Aurora Background Ticker Runs During Video Playback

**Issue:** `AuroraBackground` starts a `Ticker` that runs every frame, even when the background is fully obscured by video.

**File:** `lib/ui/shared/aurora_background.dart:66-68`

The `engineState` listener pauses the ticker only when state is not `idle`, but the check is incomplete — it doesn't account for `paused` state where the video surface may still be visible.

**Impact:** Unnecessary GPU usage during paused video (background is still hidden behind the video texture).

**Fix approach:** Pause ticker when `engineState` is `playing` OR `paused` (video surface is visible in both states). Only resume on `idle` or `stopped`.

## Fragile Areas

### 12. Window HWND Lookup by Class Name

**Issue:** `Win32PlatformFullscreen._getHwnd()` finds the Flutter window by searching for class name `FLUTTER_RUNNER_WIN32_WINDOW`.

**File:** `lib/kernel/bridge/win32/win32_platform_fullscreen.dart:127-133`

```dart
static int _getHwnd() {
  final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  try {
    return _findWindow(className, nullptr);
  } finally {
    calloc.free(className);
  }
}
```

**Impact:** If Flutter changes the window class name in a future version, or if multiple Flutter windows are open, this returns the wrong HWND or 0.

**Fix approach:** Cache the HWND on first successful lookup. Consider using `GetActiveWindow()` or the Flutter engine's view ID as fallback.

### 13. Race Condition in Fullscreen Controller

**Issue:** `FullscreenController` uses a `Completer`-based mutex to prevent concurrent fullscreen transitions, but the mutex is not reentrant-safe.

**File:** `lib/kernel/bridge/fullscreen_controller.dart`

If `enter()` is called while `exit()` is in progress (e.g., rapid F key presses), the second call may fail silently or corrupt the saved window state.

**Impact:** Window stuck in partial fullscreen state with wrong dimensions.

**Fix approach:** Queue pending transitions instead of dropping them, or add a cooldown period after each transition.

## Security Considerations

### 14. No Input Validation on File Paths

**Issue:** `FolderScanner.scan()` and `FileOperations.openAndPlay()` accept arbitrary file paths without sanitization.

**Files:**
- `lib/kernel/scanner/folder_scanner.dart:42-66`
- `lib/features/player/services/file_operations.dart`

**Impact:** Low risk for desktop app — user controls their own filesystem. But path traversal could access files outside intended directories if paths come from drag-and-drop or CLI args.

**Fix approach:** Validate that paths are within expected directories. Already partially addressed by `PathValidator.isUrl()` check in engine.

### 15. Hardcoded Win32 Constants

**Issue:** Win32 API constants are defined as module-level `const` values without documentation of their Windows SDK origin.

**File:** `lib/kernel/bridge/win32/win32_platform_fullscreen.dart:14-20`

```dart
const int _gwlStyle = -16;
const int _wsCaption = 0x00C00000;
const int _wsThickframe = 0x00040000;
```

**Impact:** If these values change in a future Windows SDK (unlikely but possible), or if the constants are wrong, the fullscreen behavior breaks silently.

**Fix approach:** Add comments referencing the Windows SDK header (`winuser.h`) or use the `win32` package's named constants.

## Test Coverage Gaps

### 16. No Integration Tests for Engine Lifecycle

**Issue:** The engine open/play/pause/stop/seek lifecycle has complex state transitions and error paths, but no integration tests exercise the full flow.

**Files:**
- `lib/kernel/engine/fvp_engine.dart` — 724 lines, 15+ state transitions
- `lib/features/player/services/playback_controller.dart` — orchestrates engine + playlist

**Impact:** Regressions in state machine transitions (e.g., seeking while buffering, opening while playing) are only caught by manual testing.

**Priority:** High — engine state bugs cause user-visible playback failures.

### 17. No Widget Tests for Settings Panel

**Issue:** `SettingsPanel` has complex deferred-apply logic for locale and theme changes, with cancel/OK/Apply paths.

**File:** `lib/ui/dialogs/settings_panel.dart` — 402 lines

**Impact:** The deferred-apply pattern (changes visible during editing, reverted on cancel) is error-prone and untested.

**Priority:** Medium — settings UI correctness affects user experience.

## Missing Critical Features

### 18. No Crash Recovery

**Issue:** If the app crashes mid-playback, the saved state may be inconsistent (playlist saved but position not, or vice versa).

**Files:**
- `lib/kernel/persistence/playlist_store.dart` — atomic write with retry
- `lib/kernel/persistence/settings_store.dart` — individual key saves

**Impact:** On restart, the app may resume at wrong position or lose recent playlist changes.

**Fix approach:** Use a single atomic write for all state (playlist + position + settings) or implement a write-ahead log.

---

*Concerns audit: 2026/06/23*
