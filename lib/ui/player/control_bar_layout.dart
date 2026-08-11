import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'control_bar_actions.dart';
import 'control_bar_timeline.dart';
import 'control_bar_title.dart';
import 'control_bar_view_model.dart';
import 'player_actions.dart';

/// 控制栏的三行内容布局。
///
/// 将标题、时间导航和动作区的布局从视觉外壳中分离，使装饰或模糊效果变化时
/// 不会混入业务控件的组合职责。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [ControlBarViewModel]。
class ControlBarLayout extends StatelessWidget {
  final ControlBarViewModel vm;
  final PlayerActions actions;
  final bool isIdle;
  final ValueListenable<bool>? isIdleListenable;
  final String? title;
  final ValueListenable<String>? titleListenable;
  final ValueListenable<bool>? resizing;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  /// 全屏切换回调 — 透传给 ControlBarActions → RightButtonGroup.
  final VoidCallback? onToggleFullscreen;

  const ControlBarLayout({
    super.key,
    required this.vm,
    required this.actions,
    required this.isIdle,
    this.isIdleListenable,
    this.title,
    this.titleListenable,
    this.resizing,
    this.onSeekStart,
    this.onSeekEnd,
    this.onToggleFullscreen,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // CSS .player-controls::before — 顶部渐变光线。
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: Tokens.controlBarGradientHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Tokens.glowTransparent,
                  Tokens.glowAccent,
                  Tokens.glowTransparent,
                ],
              ),
            ),
          ),
        ),
        // 3 行等分布局：标题 / 时间导航 / 按钮行。
        Column(
          children: [
            Expanded(
              child: ControlBarTitle(
                title: title,
                titleListenable: titleListenable,
              ),
            ),
            Expanded(
              child: ControlBarTimeline(
                vm: vm,
                resizing: resizing,
                onSeekStart: onSeekStart,
                onSeekEnd: onSeekEnd,
              ),
            ),
            Expanded(
              child: ControlBarActions(
                vm: vm,
                actions: actions,
                isIdle: isIdle,
                isIdleListenable: isIdleListenable,
                onToggleFullscreen: onToggleFullscreen,
                onInteractionStart: onInteractionStart,
                onInteractionEnd: onInteractionEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
