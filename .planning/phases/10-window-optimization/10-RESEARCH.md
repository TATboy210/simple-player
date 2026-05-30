# Phase 10: Window Optimization - Research

**Researched:** 2026-05-30
**Domain:** Win32 window management, multi-monitor, startup geometry restore, fullscreen transitions
**Confidence:** HIGH

## Summary

Phase 10 addresses WIN-04 — continued window management and UX improvement. The current codebase has three critical gaps:

1. **Startup geometry not restored**: `main.dart` uses static `WindowOptions(size: Size(960, 540), center: true)` and never reads persisted geometry from `SettingsStore`. Despite `SettingsStore.load()` returning `windowWidth/windowHeight/windowX/windowY/isMaximized`, these values are never applied to the window at startup.

2. **No multi-monitor bounds validation**: Only `monitorFromWindow(hwnd, monitorDefaultToNearest)` is used for fullscreen/maximize. Saved window position is never checked against visible displays. When users switch between docked/undocked laptop configurations, the window can appear off-screen.

3. **Double WindowService instantiation**: `App` creates `WindowService()..init()` and `PlayerServices.init()` creates another `WindowService()..init()`. Two instances both call `removeBorderImmediate()` and register as WindowListener — a race condition on `_baseStyle` and duplicate callbacks.

4. **Fullscreen restore on startup**: `isFullscreen` and `isMaximized` are persisted but never restored. If the app crashes while fullscreen, it starts in windowed mode.

The existing infrastructure is solid: `SettingsStore` has RC-3 sanitization (NaN/Infinity/negative protection), RC-4 sequential writes (no partial corruption), and 500ms debounce on geometry saves. Phase 9 added FFI pointer safety (try/finally, dispose fix, fullscreen timeout). The work is primarily about wiring these together.

**Primary recommendation:** Add a `WindowBootstrap` class that reads saved geometry, validates against current monitor topology, applies position/size, and restores fullscreen/maximize state — all before `windowManager.show()`. Fix the double WindowService by making it a singleton injected from App.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Startup geometry restore | Kernel/Bridge | — | WindowService owns window state, reads SettingsStore |
| Multi-monitor bounds check | Kernel/Bridge | — | Win32 EnumDisplayMonitors or screen_retriever API |
| Fullscreen state persistence | Kernel/Bridge | Kernel/Persistence | WindowService + SettingsStore coordination |
| Window animation smoothness | Kernel/Bridge | — | DWM + SetWindowPos sequencing |
| Crash-resilient geometry save | Kernel/Bridge | Kernel/Persistence | Debounce + close handler + sequential writes |
| Double WindowService fix | Features/Player | App | DI/injection pattern |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | 0.5.1 | Window lifecycle, setPosition/setSize/ensureVisible | Already in use, provides cross-platform window API |
| screen_retriever | 0.2.0 | Multi-monitor enumeration (getAllDisplays, getPrimaryDisplay) | Dependency of window_manager, already available |
| ffi | 2.2.0 | Win32 API calls (EnumDisplayMonitors, GetMonitorInfo) | Already in use for window_service.dart |
| shared_preferences | ^2.5.5 | Settings persistence | Already in use |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:ffi | SDK | Direct Win32 calls when window_manager API is insufficient | Multi-monitor enumeration fallback |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| screen_retriever | Win32 EnumDisplayMonitors FFI | screen_retriever is already a dependency and provides Dart-native API; FFI only needed if screen_retriever lacks specific capability |
| windowManager.setFullScreen() | Current FFI WS_POPUP approach | setFullScreen keeps WS_CAPTION (visible frame); current FFI approach is correct for true borderless fullscreen — keep it |

**Installation:** No new packages needed. All required libraries are already in `pubspec.yaml`.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| window_manager | npm/pub | ~4 yrs | High | github.com/leanflutter/window_manager | [OK] | Already installed |
| screen_retriever | npm/pub | ~4 yrs | High | github.com/leanflutter/screen_retriever | [OK] | Already installed (transitive) |
| ffi | npm/pub | Dart SDK | SDK | dart-lang/sdk | [OK] | Already installed |
| shared_preferences | npm/pub | ~6 yrs | Very High | flutter/packages | [OK] | Already installed |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*No new packages required for this phase.*

## Architecture Patterns

### Current Startup Flow (broken)

```
main.dart
  -> WindowOptions(size: 960x540, center: true)  // HARDCODED — ignores saved geometry
  -> WindowService.removeBorderImmediate()        // removes WS_CAPTION
  -> windowManager.show() + focus()
  -> App(coordinator)
    -> WindowService()..init()                     // FIRST instance
    -> DeferredPlayerFeature
      -> PlayerFeature
        -> PlayerServices
          -> WindowService()..init()               // SECOND instance (BUG)
          -> SettingsStore.load()                  // geometry loaded but NEVER applied to window
```

### Recommended Startup Flow (fixed)

```
main.dart
  -> windowManager.ensureInitialized()
  -> SettingsStore.load()                          // read saved geometry
  -> WindowBootstrap.restoreOrCenter(settings)     // NEW: apply geometry
    -> if saved position exists AND on visible monitor:
      -> windowManager.setPosition(savedPosition)
      -> windowManager.setSize(savedSize)
    -> else:
      -> windowManager.center()
    -> windowManager.ensureVisible()               // safety net for monitor changes
  -> WindowService.removeBorderImmediate()
  -> windowManager.show() + focus()
  -> if settings.isMaximized: windowService.maximize()
  -> App(coordinator, windowService)               // single instance, injected
```

### Pattern 1: Startup Geometry Restore with Multi-Monitor Safety

**What:** Read saved window geometry from SettingsStore, validate against current monitor topology, and apply before showing the window.

**When to use:** Every application launch.

**Example:**
```dart
// Source: window_manager API (ensureVisible, setPosition, setSize)
class WindowBootstrap {
  static Future<void> restoreOrCenter(AppSettings settings) async {
    if (settings.windowX != null && settings.windowY != null) {
      // Restore saved position
      await windowManager.setPosition(
        Offset(settings.windowX!, settings.windowY!),
      );
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
      // Ensure window is on a visible monitor (handles monitor disconnect)
      await windowManager.ensureVisible();
    } else {
      // First launch or no saved position — use WindowOptions center
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
      await windowManager.center();
    }
  }
}
```

### Pattern 2: Singleton WindowService with Injection

**What:** Create WindowService once in App, pass it down to PlayerServices/PlayerFeature via constructor.

**When to use:** When multiple consumers need the same window state.

**Example:**
```dart
// In App:
final WindowService _windowService = WindowService()..init();

// Pass to DeferredPlayerFeature → PlayerFeature → PlayerScreen
// PlayerServices receives WindowService instead of creating one
class PlayerServices {
  final WindowService windowService;
  PlayerServices({required this.windowService});
  // ... no longer creates WindowService internally
}
```

### Pattern 3: Close-Triggered Geometry Save

**What:** Save window geometry immediately on window close (not just debounced resize).

**When to use:** Window close event, to capture final geometry even if resize debounce hasn't fired.

**Example:**
```dart
// In WindowService, override onWindowClose:
@override
void onWindowClose() {
  // Save immediately — debounce may not have fired
  _saveGeometryImmediate();
}
```

### Anti-Patterns to Avoid

- **Hardcoded WindowOptions size at startup**: Always read from SettingsStore first
- **Creating WindowService in multiple places**: Single instance, injected via constructor
- **Relying solely on debounce for geometry save**: Close/crash handlers must save immediately
- **Using windowManager.setFullScreen() for frameless windows**: Keeps WS_CAPTION visible border; use FFI approach instead

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-monitor detection | Win32 EnumDisplayMonitors FFI | `screen_retriever` `getAllDisplays()` | Already a dependency, Dart-native API |
| Window visibility check | Manual monitor rect intersection math | `windowManager.ensureVisible()` | Built-in, handles edge cases |
| Window position/size | Multiple setPosition + setSize calls | `windowManager.setBounds(Rect)` | Atomic operation, single WM message |

## Common Pitfalls

### Pitfall 1: WindowOptions overriding restored geometry
**What goes wrong:** `WindowOptions(size: Size(960, 540))` runs in `waitUntilReadyToShow` callback, potentially overriding any position/size set earlier.
**Why it happens:** `waitUntilReadyToShow` applies WindowOptions when the window is ready, which may happen after manual setPosition/setSize.
**How to avoid:** Set geometry INSIDE the `waitUntilReadyToShow` callback, AFTER `removeBorderImmediate()` but BEFORE `show()`. Or use `WindowOptions` with the saved size.
**Warning signs:** Window briefly appears at 960x540 then jumps to saved position.

### Pitfall 2: ensureVisible() called too early
**What goes wrong:** `ensureVisible()` returns before the window is fully shown, causing incorrect monitor detection.
**Why it happens:** Window visibility state affects monitor detection.
**How to avoid:** Call `ensureVisible()` AFTER `windowManager.show()`, or rely on `waitUntilReadyToShow` ordering.
**Warning signs:** Window appears on wrong monitor despite saved position being correct.

### Pitfall 3: Maximize on startup conflicts with saved size
**What goes wrong:** Restoring maximized state on startup overrides the saved position/size, but the maximize implementation uses `setWindowPos` which may not animate smoothly.
**Why it happens:** Custom `maximize()` uses FFI `SetWindowPos` directly.
**How to avoid:** If `isMaximized` is saved, call `windowService.maximize()` AFTER geometry restore. The maximize function already saves `_savedMaximizeFrame` for later restore.
**Warning signs:** Window flashes at restored size then jumps to maximized.

### Pitfall 4: Fullscreen on startup with crash recovery
**What goes wrong:** Restoring fullscreen on startup when the app crashed mid-fullscreen. `_savedFrame` is null (not persisted across crashes).
**Why it happens:** `_savedFrame` is only in-memory; crash loses it.
**How to avoid:** Do NOT auto-restore fullscreen on startup. Instead, clear `isFullscreen` in SettingsStore on clean startup. Only restore if the user explicitly toggled it.
**Warning signs:** App starts fullscreen with no way to exit (no saved frame to restore to).

## Code Examples

### Startup Geometry Restore

```dart
// In main.dart, inside waitUntilReadyToShow callback:
windowManager.waitUntilReadyToShow(windowOptions, () async {
  await WindowService.removeBorderImmediate();

  // Restore saved geometry
  final settings = await SettingsStore.load();
  if (settings.windowX != null && settings.windowY != null) {
    await windowManager.setPosition(
      Offset(settings.windowX!, settings.windowY!),
    );
    await windowManager.setSize(
      Size(settings.windowWidth, settings.windowHeight),
    );
  }

  await windowManager.show();
  await windowManager.focus();

  // Post-show: ensure on visible monitor + restore state
  await windowManager.ensureVisible();
  if (settings.isMaximized) {
    // maximize after show + ensureVisible
  }
});
```

### Multi-Monitor Bounds Check

```dart
// Source: screen_retriever API
import 'package:screen_retriever/screen_retriever.dart';

Future<bool> isOnVisibleDisplay(Offset position, Size size) async {
  final displays = await screen_retriever.getAllDisplays();
  final windowRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

  for (final display in displays) {
    final displayRect = Rect.fromLTWH(
      display.visiblePosition!.dx,
      display.visiblePosition!.dy,
      display.visibleSize!.width,
      display.visibleSize!.height,
    );
    // Window is "on" this display if at least 100px is visible
    if (windowRect.overlaps(displayRect)) {
      final overlap = windowRect.intersect(displayRect);
      if (overlap.width >= 100 && overlap.height >= 100) {
        return true;
      }
    }
  }
  return false;
}
```

### WindowService Singleton Injection

```dart
// App creates WindowService once
class _AppState extends State<App> {
  final WindowService _windowService = WindowService()..init();

  @override
  Widget build(BuildContext context) {
    return DeferredPlayerFeature(
      windowService: _windowService,  // injected
      // ...
    );
  }
}

// PlayerServices receives it
class PlayerServices {
  final WindowService windowService;
  PlayerServices({required this.windowService});
  // remove: windowService = WindowService();
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| window_manager setFullScreen | FFI WS_POPUP + DWM margins | v1.0 Phase 1 | True borderless fullscreen, no visible frame |
| WindowManagerService (legacy) | WindowService (current) | v1.0 | Single source of truth |
| No geometry persistence | SettingsStore.saveWindowGeometry (500ms debounce) | v1.0 | Geometry survives restart |
| No FFI safety | try/finally + dispose + fullscreen timeout | v1.2 Phase 9 | No memory leaks, no permanent lock |

**Deprecated/outdated:**
- `WindowManagerService` (lib/kernel/window/): Legacy, not used in current startup flow
- `windowManager.setFullScreen()`: Keeps WS_CAPTION, produces visible border on frameless windows

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `windowManager.ensureVisible()` correctly handles multi-monitor scenarios where saved position is off-screen | Multi-Monitor Bounds Check | Window may appear off-screen; fallback: manual EnumDisplayMonitors FFI |
| A2 | `screen_retriever.getAllDisplays()` works on Windows and returns correct visible positions | Multi-Monitor Bounds Check | May need Win32 EnumDisplayMonitors FFI fallback |
| A3 | Setting geometry inside `waitUntilReadyToShow` callback works correctly (not overridden by WindowOptions) | Startup Geometry Restore | Window may flash at default size; need to test ordering |
| A4 | `windowManager.setBounds()` is atomic on Windows (single WM message) | Don't Hand-Roll | May need separate setPosition + setSize calls |
| A5 | DWM transitions (animate maximize/restore) work correctly when using FFI SetWindowPos | Pitfall 3 | Animation may be choppy; may need DWMWA_TRANSITIONS_DISABLED |

## Open Questions

1. **WindowOptions ordering**
   - What we know: `WindowOptions(size: Size(960, 540))` is passed to `waitUntilReadyToShow`. The callback runs when the window is ready.
   - What's unclear: Does `windowManager.setPosition/setSize` called INSIDE the callback override WindowOptions, or does WindowOptions apply AFTER the callback?
   - Recommendation: Test empirically. If overridden, change `WindowOptions` to use saved size, or remove size from WindowOptions entirely and set it manually.

2. **ensureVisible() timing**
   - What we know: `ensureVisible()` is documented to move the window onto a connected screen.
   - What's unclear: Does it work correctly when called before `show()`? Does it handle partial visibility (e.g., window 50% off-screen)?
   - Recommendation: Call after `show()` + `focus()` to be safe. Test with window partially off-screen.

3. **Fullscreen auto-restore safety**
   - What we know: `_savedFrame` is in-memory only, lost on crash.
   - What's unclear: Should we persist `_savedFrame` to SettingsStore for crash recovery?
   - Recommendation: Do NOT auto-restore fullscreen. Clear `isFullscreen` on clean startup. The user can re-enter fullscreen manually.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| window_manager | Window management | ✓ | 0.5.1 | — |
| screen_retriever | Multi-monitor | ✓ | 0.2.0 (transitive) | Win32 EnumDisplayMonitors FFI |
| ffi | Win32 API | ✓ | 2.2.0 | — |
| shared_preferences | Settings | ✓ | ^2.5.5 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none — standard flutter test |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WIN-04a | Window restores saved geometry on startup | unit | `flutter test test/kernel/bridge/window_service_test.dart` | ❌ Wave 0 |
| WIN-04b | Multi-monitor bounds check moves off-screen window | unit | `flutter test test/kernel/bridge/window_bootstrap_test.dart` | ❌ Wave 0 |
| WIN-04c | Fullscreen enter/exit no visual glitch | manual | Visual inspection on Windows | Manual only |
| WIN-04d | Geometry persists reliably after crash | unit | `flutter test test/kernel/persistence/settings_store_test.dart` | ✅ |

### Sampling Rate

- **Per task commit:** `flutter test test/kernel/bridge/ test/kernel/persistence/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + manual fullscreen animation verification

### Wave 0 Gaps

- [ ] `test/kernel/bridge/window_service_test.dart` — covers WIN-04a (startup geometry restore)
- [ ] `test/kernel/bridge/window_bootstrap_test.dart` — covers WIN-04b (multi-monitor bounds check)
- [ ] `test/helpers/fake_screen_retriever.dart` — mock for screen_retriever in tests

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | SettingsStore._sanitizeDimension/_sanitizeCoordinate (already in place) |
| V6 Cryptography | no | — |

### Known Threat Patterns for Win32 Window Management

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Corrupted geometry values in SharedPreferences | Tampering | SettingsStore RC-3 sanitization (already in place) |
| Off-screen window (social engineering) | Evasion | ensureVisible() + multi-monitor bounds check |
| Fullscreen lock (crash during fullscreen) | Denial of Service | Phase 9 fullscreen timeout + don't auto-restore fullscreen |

## Sources

### Primary (HIGH confidence)
- `lib/kernel/bridge/window_service.dart` — current implementation, 370 lines
- `lib/kernel/persistence/settings_store.dart` — geometry persistence with RC-3/RC-4 safety
- `lib/main.dart` — startup flow (geometry NOT restored)
- `lib/app.dart` — WindowService creation (double instantiation bug)
- `lib/features/player/player_services.dart` — second WindowService creation

### Secondary (MEDIUM confidence)
- window_manager 0.5.1 API (ensureVisible, setBounds, setPosition, setSize)
- screen_retriever 0.2.0 API (getAllDisplays, getPrimaryDisplay)
- Memory files: project_window_border.md, project_window_anti_patterns.md, project_fullscreen_win32_fix.md

### Tertiary (LOW confidence)
- window_manager ensureVisible() behavior on partial visibility (untested)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use, no new dependencies
- Architecture: HIGH — clear gaps identified in startup flow, double instance bug confirmed
- Pitfalls: MEDIUM — WindowOptions ordering and ensureVisible timing need empirical testing

**Research date:** 2026-05-30
**Valid until:** 2026-06-15 (window_manager API stable, but WindowOptions ordering needs testing)
