import 'package:flutter/material.dart';

import '../shared/secondary_surface_visibility.dart';
import '../theme/tokens.dart';
import 'auto_hide_controller.dart';

/// 控制栏显隐外壳 — 按 [AutoHideController.visible] 定位并淡入淡出 [child]。
///
/// [child] (ControlBar 子树) 由调用方构建一次并传入，显隐翻转只重建这层
/// Positioned/Visibility 壳。Visibility 保留 state/animation，故隐藏时按钮树
/// 与动画控制器仍挂载；SecondarySurfaceOwner 把可见性传给二级浮层。
class ControlsBarVisibility extends StatelessWidget {
  const ControlsBarVisibility({
    super.key,
    required this.autoHide,
    required this.child,
  });

  final AutoHideController autoHide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: autoHide.visible,
      builder: (_, isVisible, _) => Positioned(
        left: Tokens.controlBarMarginH,
        right: Tokens.controlBarMarginH,
        bottom: Tokens.controlBarMarginBottom,
        child: Visibility(
          key: const Key('player-controls-visibility'),
          visible: isVisible,
          maintainState: true,
          maintainAnimation: true,
          child: SecondarySurfaceOwner(
            visible: isVisible,
            eligibility: autoHide.visible,
            child: FadeTransition(opacity: autoHide.opacity, child: child),
          ),
        ),
      ),
    );
  }
}
