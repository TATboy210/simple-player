import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'control_bar_actions.dart';
import 'control_bar_title.dart';
import 'control_bar_view_model.dart';
import 'control_bar_layout_mode.dart';
import 'player_actions.dart';

/// 控制栏的响应式内容布局。
///
/// 将标题、时间导航和动作区的布局从视觉外壳中分离，使装饰或模糊效果变化时
/// 不会混入业务控件的组合职责。
///
/// 路径B Commit1:数据源从 [MediaEngine] 解耦为 [ControlBarViewModel]。
class ControlBarLayout extends StatelessWidget {
  final ControlBarViewModel vm;
  final PlayerActions actions;

  /// Shared responsive mode selected from the post-padding content width.
  final ControlBarLayoutMode mode;
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
    required this.mode,
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
  Widget build(BuildContext context) => _buildLayout(mode);

  Widget _buildLayout(ControlBarLayoutMode mode) {
    final title = ControlBarTitle(
      title: this.title,
      titleListenable: titleListenable,
      minimal: mode.isMinimal,
    );
    final actions = ControlBarActions(
      vm: vm,
      actions: this.actions,
      isIdle: isIdle,
      mode: mode,
      isIdleListenable: isIdleListenable,
      onToggleFullscreen: onToggleFullscreen,
      onInteractionStart: onInteractionStart,
      onInteractionEnd: onInteractionEnd,
    );

    // 两档模式都保留 Expanded → SizedBox 的父级类型，避免切换宽度时替换
    // 标题、时间轴和动作区的 Element；最小模式只改变稳定 SizedBox 的高度。
    final titleHeight = mode.isMinimal
        ? Tokens.controlBarTitleHeightMinimal
        : null;
    final actionsHeight = mode.isMinimal
        ? Tokens.controlBarActionsHeightMinimal
        : null;
    final content = Column(
      children: [
        Flexible(
          fit: mode.isMinimal ? FlexFit.loose : FlexFit.tight,
          child: SizedBox(
            height: titleHeight,
            child: title,
          ),
        ),
        const Flexible(fit: FlexFit.tight, child: SizedBox()),
        Flexible(
          fit: mode.isMinimal ? FlexFit.loose : FlexFit.tight,
          child: SizedBox(
            height: actionsHeight,
            child: actions,
          ),
        ),
      ],
    );

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
        content,
      ],
    );
  }
}
