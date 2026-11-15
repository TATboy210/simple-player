import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'auto_hide_controller.dart';

/// 控制栏显现判定 — 指针是否落在控制栏自身的矩形内。
///
/// v0.0.4: 自动显现响应区从「底部 150px 全宽」收窄到控制栏本体矩形：左右各
/// 缩进 [Tokens.controlBarMarginH]、距底 [Tokens.controlBarMarginBottom]、高
/// [Tokens.controlBarHeight]。紧凑模式(minimal)栏高 100，判定仍按 110 —
/// 10px 容差取保守侧：宁可多 10px 触发，也不让用户指着控制栏它却不出现。
bool pointerInsideControlBar(Size area, Offset localPosition) {
  final fromBottom = area.height - localPosition.dy;
  final withinBarHeight =
      fromBottom >= Tokens.controlBarMarginBottom &&
      fromBottom <= Tokens.controlBarMarginBottom + Tokens.controlBarHeight;
  final withinBarWidth =
      localPosition.dx >= Tokens.controlBarMarginH &&
      localPosition.dx <= area.width - Tokens.controlBarMarginH;
  return withinBarHeight && withinBarWidth;
}

/// 顶层鼠标区域 — 驱动 auto-hide 的唤醒/保活，并按 [cursorHidden] 切换光标。
///
/// 光标由派生信号单点驱动 (一个 ValueListenableBuilder)；onHover/onEnter/
/// onExit 是 State 方法，build 不再为它们每次新建闭包。
class ControlsCursorRegion extends StatefulWidget {
  const ControlsCursorRegion({
    super.key,
    required this.autoHide,
    required this.cursorHidden,
  });

  final AutoHideController autoHide;

  /// 光标是否隐藏 (全屏 + 控制栏隐藏 + 无面板)。
  final ValueListenable<bool> cursorHidden;

  @override
  State<ControlsCursorRegion> createState() => _ControlsCursorRegionState();
}

class _ControlsCursorRegionState extends State<ControlsCursorRegion> {
  /// 指针是否落在控制栏矩形内 (v0.0.4: 仅矩形内移动/进入才唤醒控制栏)。
  bool _insideBar(PointerEvent event) {
    final size = context.size;
    if (size == null) return false;
    return pointerInsideControlBar(size, event.localPosition);
  }

  /// 控制栏矩形内的移动刷新显现与保活计时；传事件时间戳(单调时钟)节流零分配。
  void _onHover(PointerHoverEvent event) {
    if (_insideBar(event)) widget.autoHide.onMouseMove(event.timeStamp);
  }

  /// 进入即显限定在控制栏矩形内 — 从窗口任意位置进入不唤醒控制栏；
  /// 进入后移入矩形由 [_onHover] 揭示。
  void _onEnter(PointerEnterEvent event) {
    if (_insideBar(event)) widget.autoHide.onMouseEnter();
  }

  void _onExit(PointerExitEvent event) => widget.autoHide.onMouseExit();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.cursorHidden,
      // child 恒定：光标翻转只重建 MouseRegion，不重建占位体。
      child: const SizedBox.expand(),
      builder: (_, hidden, child) => MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: hidden ? SystemMouseCursors.none : MouseCursor.defer,
        onHover: _onHover,
        onEnter: _onEnter,
        onExit: _onExit,
        child: child,
      ),
    );
  }
}
