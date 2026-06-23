# Phase 6: Window Code Optimization - Research

**Researched:** 2026-05-29
**Domain:** Flutter desktop window management, fullscreen interaction, DragToResizeArea
**Confidence:** HIGH

## Summary

Phase 6 addresses 5 user-reported issues with the window layer, all related to fullscreen interaction and window chrome. The scope is small, targeted fixes -- not architectural changes.

After reading all relevant source files, I identified the root causes of each issue:

1. **DragToResizeArea not fullscreen-aware** (`app.dart:152-153`) -- The widget is created once with `resizeEdgeSize: 11` and never reacts to fullscreen state changes. The `enableResizeEdges` parameter exists in the window_manager API to selectively disable edges, but is not used.

2. **ESC key not wired for fullscreen exit** (`player_screen.dart:120-146`) -- `KeyboardHandler` supports `onExitFullscreen` parameter but `PlayerScreen._buildVideoContent` never passes it. The 'F' key for toggle works (via `onToggleFullscreen`), but ESC does nothing.

3. **AutoHideController hides controls permanently in fullscreen** -- When controls fade out, `IgnorePointer(ignoring: true)` blocks all pointer events. Mouse movement should reshow controls via `onMouseMove()`, but the ESC key bypass is the critical safety net.

4. **CustomTitleBar fullscreen hide works correctly** -- `windowService.isFullscreen` ValueNotifier updates via `onWindowEnterFullScreen()`/`onWindowLeaveFullScreen()` callbacks. `CustomTitleBar` already returns `SizedBox.shrink()` when fullscreen. No fix needed here.

5. **VideoSurface 16:9 rendering works correctly** -- `FittedBox(fit: BoxFit.contain)` with aspect-ratio-aware sizing produces no black bars for 16:9 content in a 16:9 window. The `safeRatio` fallback defaults to 16/9 when engine reports invalid ratio.

**Primary recommendation:** Fix the three real bugs (DragToResizeArea fullscreen disable, ESC key wiring, resizeEdgeSize value) and verify the two non-issues (title bar hide, 16:9 rendering).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 全屏按钮代码存在但需验证可见性 -- `_RightButtonGroup` 渲染条件 `onToggleFullscreen != null` 已满足
- **D-02:** 全屏后无法退出 -- `AutoHideController` 隐藏控制栏时 `IgnorePointer(ignoring: true)` 阻止点击。需确保鼠标移动时控制栏可靠显示，且全屏退出按钮始终可点击
- **D-03:** 全屏时标题栏仍可见 -- `CustomTitleBar` 通过 `windowService.isFullscreen` 控制显隐，需验证正确更新
- **D-04:** `resizeEdgeSize=11px` 判定区域太小 -- app.dart:153 需增大。建议 5-8px。全屏时需禁用拖拽调整大小
- **D-05:** 标题栏不应遮住视频 -- 当前布局可接受，只需确保全屏时正确隐藏
- **D-06:** 16:9 视频应与 16:9 窗口完美匹配 -- 需验证无黑边、无裁剪

### Claude's Discretion
- DragToResizeArea 具体数值由 Claude 根据用户体验决定
- 全屏退出的具体交互方案（单击显示控制栏 vs 始终可点击 ESC 退出）由 Claude 决定
- VideoSurface 渲染逻辑优化方案由 Claude 决定

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPT-01 | Window layer code optimization -- refactor window management code structure while preserving all existing behavior, keep MethodChannel contract unchanged, reduce complexity, improve readability | Root causes identified for all 5 issues. Fixes are 3-5 line changes in 3 files. No architectural changes needed. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fullscreen state management | Kernel/Bridge (WindowService) | -- | WindowService owns isFullscreen ValueNotifier, receives WindowListener events |
| Fullscreen UI response | UI layer (PlayerScreen, ControlsOverlay) | -- | Widgets listen to isFullscreen and conditionally render |
| DragToResizeArea configuration | App shell (app.dart) | -- | DragToResizeArea wraps the entire app, needs fullscreen-aware rebuild |
| Keyboard shortcuts | UI layer (KeyboardHandler) | -- | Focus + onKeyEvent handles all key bindings |
| Auto-hide behavior | UI layer (AutoHideController) | -- | Timer-based fade, IgnorePointer gating |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| window_manager | 0.5.1 | Window chrome, resize, fullscreen | Already in use, provides DragToResizeArea + WindowListener |

### No New Dependencies
This phase requires zero new packages. All fixes use existing Flutter SDK widgets and the already-installed window_manager package.

## Architecture Patterns

### Pattern 1: ValueNotifier + ValueListenableBuilder for fullscreen-aware widgets

The codebase uses `WindowService.isFullscreen` (ValueNotifier) to drive UI changes. Widgets that need fullscreen awareness should wrap their dynamic parts in `ValueListenableBuilder<bool>`.

**Current correct example** (custom_title_bar.dart:23-29):
```dart
ValueListenableBuilder<bool>(
  valueListenable: windowService.isFullscreen,
  builder: (context, isFullscreen, _) {
    if (isFullscreen) return const SizedBox.shrink();
    return _TitleBarContent(windowService: windowService);
  },
);
```

**Current broken example** (app.dart:152-153) -- DragToResizeArea does NOT listen to fullscreen:
```dart
home: DragToResizeArea(
  resizeEdgeSize: 11,  // static, never changes
  child: ...,
),
```

### Pattern 2: AutoHideController IgnorePointer gating

ControlsOverlay uses a two-layer visibility system:
1. `FadeTransition` for visual fade (opacity animation)
2. `IgnorePointer(ignoring: !isVisible)` for hit-test gating

When `visible` becomes false after fade-out animation completes, ALL pointer events are blocked. This is intentional for normal operation but creates a problem in fullscreen when the user needs to interact with the control area to reshow controls.

The MouseRegion `onHover` callback sits ABOVE the IgnorePointer layer in the widget tree, so mouse movement should still trigger `onMouseMove()` -> `show()`. This is the correct design -- the issue reported by the user likely stems from the mouse needing to be in the exact control bar area.

### Recommended Fix: app.dart DragToResizeArea

Wrap DragToResizeArea with ValueListenableBuilder to react to fullscreen changes:

```dart
home: ValueListenableBuilder<bool>(
  valueListenable: windowService.isFullscreen,
  builder: (context, isFullscreen, child) => DragToResizeArea(
    resizeEdgeSize: isFullscreen ? 0 : 6,
    enableResizeEdges: isFullscreen ? [] : null,
    child: child!,
  ),
  child: DeferredPlayerFeature(...),  // cached child
),
```

**Key detail:** `enableResizeEdges: []` (empty list) disables ALL resize edges. `enableResizeEdges: null` enables all edges (default). This is confirmed from the DragToResizeArea source code (line 49): `if (enableResizeEdges != null && !enableResizeEdges!.contains(resizeEdge)) return Container();`

### Recommended Fix: player_screen.dart ESC key

Add `onExitFullscreen` callback to KeyboardHandler:

```dart
onExitFullscreen: () {
  if (isFullscreen) windowService.setFullscreen(false);
},
```

This ensures ESC always exits fullscreen regardless of control bar visibility.

## Common Pitfalls

### Pitfall 1: DragToResizeArea is StatelessWidget
**What goes wrong:** DragToResizeArea is a StatelessWidget -- it does not react to state changes internally. If you set `resizeEdgeSize: 11` at construction time, it stays 11 forever.
**Why it happens:** Unlike StatefulWidget, StatelessWidget only rebuilds when its parent rebuilds.
**How to avoid:** Wrap with ValueListenableBuilder at the parent level so the widget rebuilds with new parameters when fullscreen state changes.
**Warning signs:** Resize behavior doesn't change when entering/exiting fullscreen.

### Pitfall 2: IgnorePointer blocks ALL hit testing
**What goes wrong:** When AutoHideController fades out controls, `IgnorePointer(ignoring: true)` blocks all pointer events to the subtree. Users cannot click the fullscreen exit button.
**Why it happens:** This is by design -- prevents invisible overlay from intercepting clicks on video surface.
**How to avoid:** The MouseRegion for `onHover`/`onEnter`/`onExit` must be ABOVE the IgnorePointer in the widget tree (it is, confirmed at controls_overlay.dart:149-154). ESC key provides a guaranteed exit path.
**Warning signs:** Users report "can't exit fullscreen by clicking."

### Pitfall 3: window_manager setFullScreen is async
**What goes wrong:** `windowManager.setFullScreen()` is async. The WindowListener callbacks (`onWindowEnterFullScreen`/`onWindowLeaveFullScreen`) fire asynchronously after the native window state changes.
**Why it happens:** Platform channel communication is inherently async.
**How to avoid:** Do not assume synchronous state updates. The ValueNotifier pattern handles this correctly -- the listener updates the notifier, and ValueListenableBuilder rebuilds.
**Warning signs:** UI flickers or shows wrong state during fullscreen transition.

### Pitfall 4: resizeEdgeSize 0 vs removing DragToResizeArea
**What goes wrong:** Trying to conditionally remove DragToResizeArea from the widget tree causes the entire app to rebuild and can lose state.
**Why it happens:** Widget tree diffing treats different widget types as different subtrees.
**How to avoid:** Keep DragToResizeArea in the tree at all times. Use `resizeEdgeSize: 0` + `enableResizeEdges: []` to effectively disable it without removing it.
**Warning signs:** State loss, playlist closes, playback restarts on fullscreen toggle.

## Code Examples

### DragToResizeArea source (window_manager 0.5.1)
```dart
// Source: pub-cache/window_manager-0.5.1/lib/src/widgets/drag_to_resize_area.dart
class DragToResizeArea extends StatelessWidget {
  const DragToResizeArea({
    super.key,
    required this.child,
    this.resizeEdgeColor = Colors.transparent,
    this.resizeEdgeSize = 8,        // DEFAULT is 8, not 11
    this.resizeEdgeMargin = EdgeInsets.zero,
    this.enableResizeEdges,          // null = all enabled, [] = all disabled
  });

  Widget _buildDragToResizeEdge(ResizeEdge resizeEdge, ...) {
    if (enableResizeEdges != null && !enableResizeEdges!.contains(resizeEdge)) {
      return Container();  // returns empty container, no gesture detection
    }
    // ... MouseRegion + GestureDetector for resize
  }
}
```

### WindowService fullscreen events (window_service.dart)
```dart
// Source: lib/kernel/bridge/window_service.dart
@override
void onWindowEnterFullScreen() {
  if (!_disposed) isFullscreen.value = true;  // triggers ValueListenableBuilder rebuilds
}

@override
void onWindowLeaveFullScreen() {
  if (!_disposed) isFullscreen.value = false;
}

Future<void> setFullscreen(bool value) => windowManager.setFullScreen(value);
```

### AutoHideController visibility gating (controls_overlay.dart)
```dart
// Source: lib/ui/player/controls_overlay.dart:155-158
ValueListenableBuilder<bool>(
  valueListenable: _autoHide.visible,
  builder: (_, isVisible, child) =>
      IgnorePointer(ignoring: !isVisible, child: child),
  child: RepaintBoundary(child: Stack(...)),  // cached child
),
```

### KeyboardHandler ESC binding (keyboard_handler.dart:158-161)
```dart
// Source: lib/ui/player/keyboard_handler.dart
if (_keyMatches(key, 'exitFullscreen', LogicalKeyboardKey.escape)) {
  onExitFullscreen?.call();  // currently NEVER called because PlayerScreen doesn't pass it
  return KeyEventResult.handled;
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fullscreen state tracking | Custom boolean + manual sync | WindowService.isFullscreen (ValueNotifier) | Already exists, correctly updated by WindowListener |
| Resize edge disabling | Custom GestureDetector overlay | DragToResizeArea.enableResizeEdges: [] | Built-in API, handles all 8 edges + cursors |
| Keyboard shortcuts | Raw KeyEvent handler | KeyboardHandler + onExitFullscreen callback | Existing infrastructure, just needs wiring |

## Common Pitfalls

### Pitfall 5: PlayerScreen passes onToggleFullscreen but not onExitFullscreen
**What goes wrong:** KeyboardHandler has TWO separate fullscreen callbacks: `onToggleFullscreen` (F key) and `onExitFullscreen` (ESC key). PlayerScreen only passes `onToggleFullscreen`.
**Why it happens:** The ESC binding exists in KeyboardHandler but the callback was never wired in PlayerScreen.
**How to avoid:** Add `onExitFullscreen` callback to KeyboardHandler instantiation in PlayerScreen.
**Warning signs:** ESC key does nothing in fullscreen.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none -- standard flutter test |
| Quick run command | `flutter test test/widget/player/` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPT-01 | DragToResizeArea disables in fullscreen | widget | `flutter test test/widget/player/controls_overlay_test.dart` | Yes |
| OPT-01 | ESC exits fullscreen | widget | `flutter test test/widget/player/keyboard_handler_test.dart` | No -- Wave 0 |
| OPT-01 | CustomTitleBar hides in fullscreen | widget | `flutter test test/widget/player/custom_title_bar_test.dart` | No -- Wave 0 |
| OPT-01 | AutoHideController reshow on mouse move | unit | `flutter test test/widget/player/auto_hide_controller_test.dart` | Yes |

### Sampling Rate
- **Per task commit:** `flutter test test/widget/player/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widget/player/keyboard_handler_test.dart` -- covers ESC fullscreen exit
- [ ] `test/widget/player/custom_title_bar_test.dart` -- covers fullscreen hide behavior
- [ ] `test/widget/app_drag_to_resize_test.dart` -- covers DragToResizeArea fullscreen disable

## Security Domain

Not applicable -- this phase involves no authentication, user input handling, cryptography, or data persistence changes. All changes are UI-layer window chrome fixes.

## Sources

### Primary (HIGH confidence)
- `window_manager-0.5.1/lib/src/widgets/drag_to_resize_area.dart` -- verified source code in pub cache
- `lib/kernel/bridge/window_service.dart` -- verified WindowListener callbacks
- `lib/ui/player/auto_hide_controller.dart` -- verified auto-hide logic
- `lib/ui/player/controls_overlay.dart` -- verified IgnorePointer gating
- `lib/ui/player/keyboard_handler.dart` -- verified ESC binding exists but unwired
- `lib/ui/player/player_screen.dart` -- verified onExitFullscreen not passed
- `lib/app.dart` -- verified static DragToResizeArea configuration

### Secondary (MEDIUM confidence)
- Memory: `project_fullscreen_bugs.md` -- 5 historical fullscreen bugs (2026-05-12), all fixed
- Memory: `project_fullscreen_win32_fix.md` -- Win32 FFI fullscreen rewrite (2026-05-20)
- Memory: `project_window_resize.md` -- DragToResizeArea implementation history

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, using existing window_manager 0.5.1
- Architecture: HIGH -- all source files read, root causes verified
- Pitfalls: HIGH -- based on actual source code analysis and historical bug memory

**Research date:** 2026-05-29
**Valid until:** 2026-06-28 (30 days -- stable phase, no fast-moving dependencies)
