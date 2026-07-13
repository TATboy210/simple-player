# Phase 5: 全屏与设置面板交互规范化 - RESEARCH

**Date:** 2026-07-13
**Phase:** 5
**Domain:** Flutter dialog positioning, animation widgets, keyboard event handling
**Confidence:** HIGH

## Summary

This phase requires the SettingsPanel to dynamically reposition itself when the window transitions between windowed and fullscreen modes. The core challenge is that the current `showDialog` + `Align(alignment: Alignment.topLeft)` + `Transform.translate(offset)` pattern does not easily support switching between topLeft+offset positioning (windowed) and center positioning (fullscreen) with smooth animation.

After researching Flutter's animation widgets, showDialog behavior, and ESC key handling on desktop, the recommended approach is:
1. Replace the static `Align` + `Transform.translate` with `AnimatedAlign` for the alignment transition
2. Keep `showDialog` (it works fine for dynamic positioning when the builder reads external state)
3. Add `Focus` widget with ESC interception inside the dialog, coordinated with `PopScope`
4. Use `MediaQuery.sizeOf(context)` for fullscreen dimensions (returns window size, which equals screen size in fullscreen)

## Topic 1: AnimatedAlign vs AnimatedPositioned vs AnimatedSlide

### Findings

**Current pattern** (settings_panel.dart line 465-491):
```dart
ValueListenableBuilder<Offset>(
  valueListenable: _offset,
  builder: (context, offset, panel) =>
      Transform.translate(offset: offset, child: panel),
  child: Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 80, top: 48),
      child: GlassContainer(...),
    ),
  ),
)
```

**AnimatedAlign** [ASSUMED]:
- Animates the `alignment` property (e.g., `Alignment.topLeft` to `Alignment.center`)
- Works inside any parent that provides unbounded constraints (the dialog's barrier provides this)
- Implicit animation: just change the `alignment` value and it animates automatically
- Best fit for this use case because we're switching between `Alignment.topLeft` (windowed) and `Alignment.center` (fullscreen)

**AnimatedPositioned** [ASSUMED]:
- Requires a `Stack` parent
- Animates `top`, `left`, `right`, `bottom` values
- Would require restructuring the widget tree to use Stack
- More complex for this use case

**AnimatedSlide** [ASSUMED]:
- Animates an `Offset` that represents a fraction of the widget's own size
- Offset `(0, 0)` = normal position, `(0, -1)` = moved up by 100% of height
- Not suitable for centering because it's relative to widget size, not parent size

### Recommendation

Use `AnimatedAlign` with `alignment: isFullscreen ? Alignment.center : Alignment.topLeft`. This is the simplest approach that:
- Naturally handles the topLeft-to-center transition with animation
- Keeps the existing Padding for windowed mode offset (left: 80, top: 48)
- Works within the existing showDialog barrier (which provides unconstrained layout)
- Uses the project's standard animation duration: `Tokens.durationSlide` (300ms)

The `_offset` ValueNotifier (drag offset) should be applied via `Transform.translate` INSIDE the `AnimatedAlign`, so it works relative to the aligned position.

## Topic 2: showDialog + Dynamic Positioning

### Findings

`showDialog` creates an internal `OverlayEntry` managed by the Navigator. The dialog's builder function is called whenever the Navigator rebuilds, but it does NOT automatically rebuild when external state changes.

**Key insight:** The dialog's `builder` receives a `BuildContext` that is BELOW the Navigator in the widget tree. External `ValueNotifier` changes (like `windowService.mode`) will NOT trigger a rebuild of the dialog content unless the dialog explicitly listens to them.

**Solution:** The SettingsPanel already uses `ValueListenableBuilder` extensively. Adding a `ValueListenableBuilder<WindowMode>` around the positioning logic will work correctly because:
1. `windowService.mode` is a `ValueNotifier<WindowMode>` exposed via `WindowBridge`
2. `ValueListenableBuilder` subscribes to the notifier regardless of where it sits in the tree
3. The dialog's route stays on the Navigator stack — mode changes don't affect it

**No need to switch to OverlayEntry.** The current `showDialog` pattern works fine for dynamic positioning as long as the dialog content subscribes to the relevant state.

### Recommendation

Keep `showDialog`. Add `windowService` parameter to `SettingsPanel` and wrap the positioning logic in `ValueListenableBuilder<WindowMode>`:

```dart
// In SettingsPanel.build()
ValueListenableBuilder<WindowMode>(
  valueListenable: widget.windowService.mode,
  builder: (context, mode, _) {
    final isFullscreen = mode.isFullscreen;
    return AnimatedAlign(
      alignment: isFullscreen ? Alignment.center : Alignment.topLeft,
      duration: const Duration(milliseconds: Tokens.durationSlide),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: isFullscreen
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: 80, top: 48),
        child: ValueListenableBuilder<Offset>(
          valueListenable: _offset,
          builder: (context, offset, panel) =>
              Transform.translate(offset: offset, child: panel),
          child: GlassContainer(...), // existing panel content
        ),
      ),
    );
  },
)
```

## Topic 3: ESC Key Coordination in showDialog

### Findings

**Current behavior:** `showDialog` with `barrierDismissible: false` (as in the current code) prevents tap-outside dismissal. However, on desktop (Windows), pressing ESC still triggers `Navigator.maybePop()` which pops the dialog route. This is Flutter's default behavior — ESC is mapped to the system "back" action.

**The problem:** When the settings panel is open in fullscreen, ESC should close the panel first (D-04), not exit fullscreen. Currently, the ESC key event reaches the `KeyboardHandler` in `player_screen.dart` which calls `onExitFullscreen`. The dialog's ESC handling (via Navigator.maybePop) happens at a different layer.

**Solution approach:** Use `PopScope` (Flutter 3.16+) + `Focus` widget inside the dialog:

1. **PopScope** prevents Navigator from popping the dialog on ESC:
   ```dart
   PopScope(
     canPop: false, // blocks ESC/Navigator.maybePop
     child: ...
   )
   ```

2. **Focus** widget with `autofocus: true` intercepts key events at the dialog level:
   ```dart
   Focus(
     autofocus: true,
     onKeyEvent: (node, event) {
       if (event is KeyDownEvent &&
           event.logicalKey == LogicalKeyboardKey.escape) {
         Navigator.of(context).pop(); // close panel
         return KeyEventResult.handled; // don't propagate
       }
       return KeyEventResult.ignored;
     },
     child: ...
   )
   ```

3. Since `KeyEventResult.handled` stops propagation, the outer `KeyboardHandler` in `player_screen.dart` will NOT receive the ESC event, so fullscreen won't be toggled.

**Important:** The `Focus` widget must have `autofocus: true` to ensure it receives key events when the dialog opens. The dialog's barrier already has a `Focus` that handles ESC when `barrierDismissible` is true, but since we set `barrierDismissible: false`, we need our own Focus.

### Recommendation

Add `PopScope` + `Focus` wrapper inside `SettingsPanel.build()`:

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false, // prevent Navigator from dismissing on ESC
    child: Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // existing barrier + panel
        ],
      ),
    ),
  );
}

KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (event.logicalKey == LogicalKeyboardKey.escape) {
    Navigator.of(context).pop(); // close panel
    return KeyEventResult.handled; // don't propagate to outer KeyboardHandler
  }
  return KeyEventResult.ignored;
}
```

## Topic 4: Fullscreen-Aware Screen Dimensions

### Findings

**`MediaQuery.sizeOf(context)`** returns the size of the Flutter view (window), not the physical screen. On Windows desktop:
- In windowed mode: returns the window size (e.g., 1280x720)
- In fullscreen mode: returns the full screen size (e.g., 3840x2160 for 4K)

This is because Flutter's view IS the window — when the window is fullscreen, the view fills the entire screen. `MediaQuery.sizeOf(context)` will correctly return the fullscreen dimensions.

**No need for `screen_retriever` package** or platform-specific code. The existing `MediaQuery.sizeOf(context)` suffices because:
1. The dialog is a child of `MaterialApp`, which sets up `MediaQuery` based on the window size
2. When `WindowService.setMode(WindowMode.fullscreen)` is called, the window resizes to fill the screen
3. `MediaQuery` updates automatically when the window size changes
4. The dialog's `build` method will be called with the new size

### Recommendation

Use `MediaQuery.sizeOf(context)` for any dimension calculations inside the dialog. No additional packages or platform code needed.

```dart
final screenSize = MediaQuery.sizeOf(context);
// In fullscreen: screenSize matches the monitor resolution
// In windowed: screenSize matches the window dimensions
```

## Topic 5: Offset Reset on Mode Change

### Findings

The `_offset` ValueNotifier stores the user's drag offset. When transitioning between modes:
- **Windowed → Fullscreen:** The offset from windowed mode (relative to topLeft+80,48) makes no sense in fullscreen (centered). It should reset to `Offset.zero`.
- **Fullscreen → Windowed:** The panel returns to topLeft+80,48. Any offset from fullscreen dragging should also reset.

**Timing question:** Should the reset happen immediately or as part of the animation?

**Analysis:**
- If we reset `_offset` immediately when mode changes, the panel "jumps" to the aligned position, then `AnimatedAlign` animates the rest. This is visually acceptable because the jump is small (the offset was from dragging).
- If we animate the offset back to zero, it creates a compound animation (alignment change + offset change) which looks complex and potentially confusing.
- The CONTEXT.md D-09 says "offset needs to reset to Offset.zero" — it doesn't specify animation.

### Recommendation

Reset `_offset` to `Offset.zero` immediately when mode changes, then let `AnimatedAlign` handle the smooth position transition. This is the simplest approach:

```dart
// In SettingsPanel.initState or didChangeDependencies
widget.windowService.mode.addListener(_onModeChanged);

void _onModeChanged() {
  // Reset drag offset when mode changes
  _offset.value = Offset.zero;
}
```

The `AnimatedAlign` animation will smoothly move the panel from its current visual position to the new aligned position. Since the offset is reset simultaneously, the panel moves in a straight line rather than a compound curve.

## Topic 6: Drag Behavior in Fullscreen

### Findings

In windowed mode, the panel is draggable (D-06). In fullscreen mode, the panel should be centered (D-05) and dragging should probably be disabled to maintain the centered position.

However, the CONTEXT.md doesn't explicitly state whether dragging is allowed in fullscreen. The locked decisions only specify the initial position (centered) and the offset reset on exit.

### Recommendation

Disable dragging in fullscreen mode. The panel is centered, and dragging it would create a non-centered offset that conflicts with the centering intent. Add a `isFullscreen` check to the drag GestureDetector:

```dart
GestureDetector(
  onPanStart: isFullscreen ? null : (_) {},
  onPanUpdate: isFullscreen ? null : (d) {
    _offset.value += d.delta;
  },
  child: ... // title bar
)
```

## Validation Architecture

### Test Strategy

| Test | Type | What It Verifies |
|------|------|------------------|
| Panel centers on fullscreen enter | Widget test | AnimatedAlign alignment switches to center |
| Panel returns to topLeft on fullscreen exit | Widget test | AnimatedAlign alignment switches back |
| ESC closes panel in fullscreen | Widget test | Focus intercepts ESC, Navigator.pop called |
| ESC does not exit fullscreen when panel open | Widget test | KeyEventResult.handled stops propagation |
| Offset resets on mode change | Unit test | _offset.value == Offset.zero after mode change |
| Pending changes preserved across mode change | Widget test | _pendingLocale/_pendingThemeIndex unchanged |
| Drag disabled in fullscreen | Widget test | onPanUpdate is null when isFullscreen |

### Manual Testing Checklist
- [ ] Open settings panel in windowed mode, enter fullscreen → panel smoothly moves to center
- [ ] Open settings panel in fullscreen, exit fullscreen → panel smoothly returns to topLeft+offset
- [ ] In fullscreen with panel open, press ESC → panel closes, stay in fullscreen
- [ ] In fullscreen with panel closed, press ESC → exit fullscreen
- [ ] Drag panel in windowed mode, enter fullscreen → panel centers, offset resets
- [ ] Make pending changes (locale/theme), enter fullscreen → changes preserved
- [ ] Open panel in fullscreen directly → panel appears centered

## Summary

**Key recommendations for the planner:**

1. **Use `AnimatedAlign`** for the alignment transition (topLeft ↔ center). It's the simplest Flutter widget that handles this exact use case with implicit animation.

2. **Keep `showDialog`** — it works fine for dynamic positioning. Add `ValueListenableBuilder<WindowMode>` inside the dialog to react to mode changes.

3. **Use `PopScope` + `Focus`** for ESC key coordination. `PopScope(canPop: false)` prevents Navigator from dismissing the dialog. `Focus(autofocus: true, onKeyEvent: ...)` intercepts ESC at the dialog level and calls `Navigator.pop` manually, preventing propagation to the outer `KeyboardHandler`.

4. **`MediaQuery.sizeOf(context)`** works correctly in fullscreen on Windows — returns the full screen size when the window is fullscreen. No additional packages needed.

5. **Reset `_offset` immediately** on mode change. Let `AnimatedAlign` handle the smooth position animation.

6. **Disable dragging in fullscreen mode** to maintain centered position.

**Implementation order:**
1. Add `WindowBridge` parameter to `SettingsPanel` constructor
2. Add `ValueListenableBuilder<WindowMode>` around positioning logic
3. Replace `Align` + `Transform.translate` with `AnimatedAlign` + conditional `Transform.translate`
4. Add `PopScope` + `Focus` for ESC handling
5. Add mode change listener to reset `_offset`
6. Wire up in `App._showSettingsPanel()` to pass `windowService`
7. Update ESC handling in dialog to not propagate to outer KeyboardHandler

## RESEARCH COMPLETE
