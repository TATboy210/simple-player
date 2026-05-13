# Phase 05: Fullscreen Reliability - Research

**Researched:** 2026-05-14
**Domain:** Window management, fullscreen toggle, state persistence
**Confidence:** HIGH

## Summary

The current `WindowService` has a critical state synchronization bug: `_enterFullscreenInternal()` performs the visual fullscreen operation (setSize + setPosition to cover the screen) but **never sets `mode.value = WindowMode.fullscreen`**. The `_exitFullscreenInternal()` similarly never sets `mode.value = WindowMode.windowed`. This means:

- F key enters fullscreen visually, but `mode.value` stays `windowed`, so pressing F again does nothing (re-enters enter branch instead of toggling back)
- ESC handler checks `isFullscreen` (derived from `mode.value`), which is always `false`, so ESC never exits fullscreen
- Fullscreen button icon stays as `Icons.fullscreen` (never changes to `Icons.fullscreen_exit`)
- Double-click enters fullscreen but cannot exit via double-click

The old `WindowManagerService` (dead code, 515 lines) DID set `mode.value` optimistically at line 278. The current `WindowService` relies on `_WindowListener.onWindowEnterFullScreen()` callback, but this callback only fires from `windowManager.setFullScreen(true)` -- NOT from the manual `setSize`+`setPosition` approach used here.

Fullscreen state persistence has the same gap: `SettingsStore.saveIsFullscreen()` is never called during toggle. The `_persistWindowState()` method explicitly skips saving when fullscreen is detected.

**Primary recommendation:** Add `mode.value` optimistic update + `SettingsStore.saveIsFullscreen()` to both `_enterFullscreenInternal()` and `_exitFullscreenInternal()`. This is a 4-line fix with high impact.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen toggle logic | WindowService (Dart) | -- | Single source of truth for window state |
| Window size/position | window_manager (Dart) | C++ Win32 | Manual borderless fullscreen via setSize+setPosition |
| Aspect ratio unlock/restore | AspectRatioService (Dart) | C++ WM_SIZING | Dart controls ratio, C++ enforces during resize |
| Fullscreen state persistence | WindowGeometryStore (Dart) | SharedPreferences | Save/restore on toggle + app restart |
| ESC key exit | KeyboardHandler (Dart) | -- | Only active when mode == fullscreen |
| Double-click toggle | ControlsOverlay (Dart) | -- | GestureDetector.onDoubleTap |
| Fullscreen button | ControlBar (Dart) | -- | Icon depends on isFullscreen |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | 0.5.1 | Window lifecycle, setSize/setPosition | Already in use, handles frameless + resize |
| shared_preferences | (in pubspec) | Persistent key-value storage | Already in use for all settings |

### No new dependencies needed

This phase is pure bug-fix and wiring. No new packages required.

## Architecture Patterns

### Fullscreen Toggle Flow (Current -- Broken)

```
F key / button / double-click
  -> WindowBridge.toggleFullscreen()
    -> WindowService.toggleFullscreen()
      -> mode.value == windowed (always true!)
        -> _enterFullscreenInternal()
          -> AspectRatioService.unlock()
          -> Cache _windowedSize, _windowedPosition
          -> setHasShadow(false)
          -> setPosition(0,0), setSize(screenW, screenH)
          // BUG: mode.value never set
          // BUG: SettingsStore.saveIsFullscreen() never called
```

### Fullscreen Toggle Flow (Fixed)

```
F key / button / double-click
  -> WindowBridge.toggleFullscreen()
    -> WindowService.toggleFullscreen()
      -> mode.value == fullscreen? (now works)
        YES -> _exitFullscreenInternal()
          -> mode.value = WindowMode.windowed  // OPTIMISTIC
          -> setSize(_windowedSize), setPosition(_windowedPosition)
          -> setHasShadow(true)
          -> AspectRatioService.setAspectRatio(_savedRatio)
          -> SettingsStore.saveIsFullscreen(false)  // PERSIST
        NO -> _enterFullscreenInternal()
          -> mode.value = WindowMode.fullscreen  // OPTIMISTIC
          -> AspectRatioService.unlock()
          -> Cache geometry
          -> setHasShadow(false), setPosition(0,0), setSize(screen)
          -> SettingsStore.saveIsFullscreen(true)  // PERSIST
```

### Key Pattern: Optimistic State Update

The old `WindowManagerService` used optimistic updates with rollback on failure:

```dart
// From WindowManagerService.toggleFullscreen() line 278:
mode.value = WindowMode.fullscreen; // optimistic
try {
  await windowManager.setHasShadow(false);
  // ... setSize, setPosition
  await SettingsStore.saveIsFullscreen(true);
} on Exception catch (e) {
  mode.value = WindowMode.windowed; // rollback
}
```

The current `WindowService` should follow the same pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fullscreen detection | Custom WM_SIZE monitoring | window_manager callbacks + manual state | Manual fullscreen doesn't fire native FS events |
| Screen dimensions | Win32 GetSystemMetrics | ui.PlatformDispatcher.instance.views | Already used, cross-platform |

## Common Pitfalls

### Pitfall 1: Missing mode.value Update
**What goes wrong:** `_enterFullscreenInternal()` does visual fullscreen but never updates `mode.value`. All downstream consumers (ESC handler, button icon, double-click toggle) read stale state.
**Why it happens:** Regression from WindowManagerService -> WindowService migration. Old service set mode.value; new service forgot.
**How to fix:** Add `mode.value = WindowMode.fullscreen` at start of `_enterFullscreenInternal()`, `mode.value = WindowMode.windowed` at start of `_exitFullscreenInternal()`.
**Warning signs:** F key only works once, ESC does nothing, button icon wrong.

### Pitfall 2: Missing Persistence on Toggle
**What goes wrong:** Fullscreen state not saved when toggling. On restart, app always starts windowed.
**Why it happens:** `_persistWindowState()` skips fullscreen mode (line 379). `SettingsStore.saveIsFullscreen()` is never called in toggle path.
**How to fix:** Call `SettingsStore.saveIsFullscreen(true/false)` in enter/exit methods.
**Warning signs:** Fullscreen doesn't persist across restarts.

### Pitfall 3: _WindowListener Callbacks Are Dead Code for Manual Fullscreen
**What goes wrong:** `_WindowListener.onWindowEnterFullScreen()` sets `mode.value` but only fires from `windowManager.setFullScreen(true)`. Since WindowService uses manual `setSize`+`setPosition`, this callback never fires.
**Why it happens:** window_manager's native Windows implementation fires `onWindowEnterFullScreen` only for actual fullscreen API calls, not manual resize.
**How to fix:** Don't rely on these callbacks for mode state. Set mode.value explicitly in enter/exit methods. Keep callbacks as idempotent safety net.
**Warning signs:** mode.value stays windowed even after visual fullscreen.

### Pitfall 4: Double-Invocation in Close Handler
**What goes wrong:** `_WindowListener.onWindowClose()` calls `_service.close()` which calls `windowManager.close()`. If `setPreventClose(false)` triggers another `onWindowClose`, double-invocation occurs.
**Why it happens:** Fragile coupling between WindowListener callback and close() method.
**How to avoid:** Current code has `_closing` guard (line 225). Verify this is sufficient. The WindowManagerService had the same pattern and it worked.
**Warning signs:** Crash on close, or close hangs.

## Code Examples

### Fix 1: Optimistic mode.value + Persistence in _enterFullscreenInternal

```dart
Future<void> _enterFullscreenInternal() async {
  // Unlock aspect ratio so WM_SIZING won't constrain the resize
  _savedRatio = AspectRatioService.I.current;
  if (_savedRatio > 0) await AspectRatioService.I.unlock();

  // Cache windowed geometry for restore
  _windowedSize = await windowManager.getSize();
  _windowedPosition = await windowManager.getPosition();

  // Optimistic update -- UI reacts immediately
  mode.value = WindowMode.fullscreen;

  try {
    // Manual borderless fullscreen (setFullScreen doesn't work on frameless)
    await windowManager.setHasShadow(false);
    final screen = ui.PlatformDispatcher.instance.views.first;
    final screenW = screen.physicalSize.width / screen.devicePixelRatio;
    final screenH = screen.physicalSize.height / screen.devicePixelRatio;
    await windowManager.setPosition(Offset.zero);
    await windowManager.setSize(Size(screenW, screenH));
    await SettingsStore.saveIsFullscreen(true);
  } on Exception catch (e) {
    // Rollback on failure
    mode.value = WindowMode.windowed;
    if (_savedRatio > 0) {
      await AspectRatioService.I.setAspectRatio(_savedRatio);
      _savedRatio = 0.0;
    }
    debugPrint('[WindowService] enterFullscreen failed: $e');
  }
}
```

### Fix 2: mode.value + Persistence in _exitFullscreenInternal

```dart
Future<void> _exitFullscreenInternal() async {
  // Optimistic update
  mode.value = WindowMode.windowed;

  try {
    // Restore windowed geometry
    if (_windowedSize != null) {
      await windowManager.setSize(_windowedSize!);
    }
    if (_windowedPosition != null) {
      await windowManager.setPosition(_windowedPosition!);
    }
    await windowManager.setHasShadow(true);

    // Restore aspect ratio
    if (_savedRatio > 0) {
      await AspectRatioService.I.setAspectRatio(_savedRatio);
      _savedRatio = 0.0;
    }
    await SettingsStore.saveIsFullscreen(false);
  } on Exception catch (e) {
    // Rollback on failure
    mode.value = WindowMode.fullscreen;
    debugPrint('[WindowService] exitFullscreen failed: $e');
  }
}
```

### Fix 3: Remove dead _onNativeEvent handler (optional cleanup)

The `com.simple_player/window` MethodChannel has no C++ handler registered. `_onNativeEvent` only handles `onMaximizeChanged` which is never sent. This is dead code from the migration. Safe to remove, or leave as-is (no functional impact).

## State of the Art

| Old Approach | Current Approach | Issue |
|--------------|------------------|-------|
| WindowManagerService sets mode.value optimistically | WindowService relies on _WindowListener callback | Callback never fires for manual fullscreen |
| WindowManagerService calls SettingsStore.saveIsFullscreen | WindowService skips persistence in _persistWindowState | Fullscreen state lost on restart |
| WindowManagerService has onWindowEnterFullScreen handler | WindowService has same handler | Dead code -- never triggered |

**Root cause:** The WindowService was written to use manual fullscreen (setSize+setPosition) but inherited the callback-based state management pattern from WindowManagerService. These two approaches are incompatible.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | window_manager's onWindowEnterFullScreen does NOT fire for manual setSize+setPosition fullscreen | Pitfall 3 | If it DOES fire, mode.value would be set correctly via callback, and the bug is elsewhere |
| A2 | The _closing guard in close() prevents double-invocation from onWindowClose | Pitfall 4 | If insufficient, app could crash on close |
| A3 | C++ com.simple_player/window channel has no handler | Fix 3 | If handler exists elsewhere, removing _onNativeEvent would break it |

## Open Questions

1. **Should we also set mode.value in the _WindowListener callbacks?**
   - What we know: The callbacks exist but are dead code for manual fullscreen
   - Recommendation: Keep them as idempotent safety net. If window_manager ever fires them (e.g., OS-level fullscreen trigger), they provide correct state. Setting mode.value in both enter/exit AND callbacks is safe (idempotent assignment).

2. **Should _persistWindowState() also save fullscreen state?**
   - What we know: Currently skips saving when fullscreen. SettingsStore.saveIsFullscreen is the dedicated method.
   - Recommendation: Use explicit `SettingsStore.saveIsFullscreen()` in enter/exit methods. Don't change `_persistWindowState()` -- it correctly avoids saving fullscreen geometry.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none -- standard flutter test |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FS-01 | F key toggles fullscreen | unit | `flutter test test/window/window_service_test.dart` | Wave 0 |
| FS-02 | Fullscreen button toggles | widget | `flutter test test/ui/player/control_bar_test.dart` | Wave 0 |
| FS-03 | Double-click toggles | widget | `flutter test test/ui/player/controls_overlay_test.dart` | Wave 0 |
| FS-04 | ESC exits fullscreen | unit | `flutter test test/ui/player/keyboard_handler_test.dart` | Wave 0 |
| FS-05 | mode.value updates optimistically | unit | `flutter test test/window/window_service_test.dart` | Wave 0 |
| FS-06 | State persists across sessions | unit | `flutter test test/window/window_service_test.dart` | Wave 0 |
| FS-07 | Aspect ratio unlocks/restores | unit | `flutter test test/window/window_service_test.dart` | Wave 0 |

### Wave 0 Gaps

- [ ] `test/window/window_service_test.dart` -- covers FS-01, FS-05, FS-06, FS-07
- [ ] `test/ui/player/keyboard_handler_test.dart` -- covers FS-01, FS-04
- [ ] `test/ui/player/controls_overlay_test.dart` -- covers FS-03
- [ ] `test/ui/player/control_bar_test.dart` -- covers FS-02

## Sources

### Primary (HIGH confidence)
- `lib/window/window_service.dart` -- current fullscreen implementation, verified missing mode.value
- `lib/kernel/window/window_manager_service.dart` -- old implementation with correct optimistic update pattern
- `lib/kernel/bridge/window_bridge.dart` -- WindowBridge interface, mode ValueNotifier
- `lib/window/geometry_store.dart` -- persistence layer, saveFullscreen method exists
- `lib/kernel/persistence/settings_store.dart` -- saveIsFullscreen method exists but never called

### Secondary (MEDIUM confidence)
- window_manager package -- onWindowEnterFullScreen callback behavior (ASSUMED: only fires for setFullScreen API)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, existing code only
- Architecture: HIGH -- bug is clearly identified in source code
- Pitfalls: HIGH -- root cause verified by comparing old vs new implementation

**Research date:** 2026-05-14
**Valid until:** 2026-06-14 (stable -- window management patterns don't change frequently)
