import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'control_bar_actions.dart';
import 'control_bar_timeline.dart';
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
          child: SizedBox(height: titleHeight, child: title),
        ),
        // Keep the timeline in the production content tree so the stable
        // ViewModel listenables can drive the same ProgressBar instance.
        Flexible(
          fit: FlexFit.tight,
          child: ControlBarTimeline(
            vm: vm,
            resizing: resizing,
            onSeekStart: onSeekStart,
            onSeekEnd: onSeekEnd,
            minimal: mode.isMinimal,
          ),
        ),
        Flexible(
          fit: mode.isMinimal ? FlexFit.loose : FlexFit.tight,
          child: SizedBox(height: actionsHeight, child: actions),
        ),
      ],
    );

    return _BarArrowNavScope(
      child: Stack(
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
      ),
    );
  }
}

/// 控制栏 ←→ 组内焦点移动 — "键随焦点"导航(2026-10-10 裁决)。
///
/// 焦点在控制栏任意可聚焦后代(动作区按钮等)时,←→ 在组内移动焦点,
/// 符合桌面播放器操作直觉;移到边缘 handled 空操作(不冒泡成全局 seek,
/// 避免"最左按 ← 突然跳播")。Space/Enter 由 [GlassButton] 自身的
/// ActivateIntent 消费(激活按钮而非播放/暂停);ProgressBar 聚焦时
/// ←→ 被滑条自身消费为步进,同样到不了本层。
class _BarArrowNavScope extends StatelessWidget {
  final Widget child;

  const _BarArrowNavScope({required this.child});

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: Focus(
      // 自身不进 Tab 链 — 纯冒泡拦截点,可聚焦性全部交给后代控件.
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final dir = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowRight => TraversalDirection.right,
          LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
          _ => null,
        };
        if (dir == null) return KeyEventResult.ignored;
        final current = FocusManager.instance.primaryFocus;
        if (current == null) return KeyEventResult.ignored;
        // 子树序移动 — node 即本 scope 的 Focus 节点,traversalDescendants
        // 恰为控制栏子树内可遍历节点(后序深度优先树序),与面板开/关无关;
        // 该 getter 本身已过滤 skipTraversal + canRequestFocus。旧实现取
        // FocusScope.of(context)(路由 scope),面板打开时遍历含面板 task
        // scope 等栏外节点,栏边缘方向键会把焦点泄进面板(U2,Space 随即
        // 作用于跨面控件)。不用 findFirstFocusInDirection:其缺省搜索
        // 边界是整个 route scope,且嵌套 group 下几何搜索会回退到焦点
        // 路径祖先节点(requestFocus 到祖先 scope 后,后续方向键绕过本层
        // 直接触发全局 seek — 实测坑)。
        final nodes = node.traversalDescendants.toList();
        final idx = nodes.indexOf(current);
        if (idx < 0) return KeyEventResult.handled;
        final nextIdx = idx + (dir == TraversalDirection.right ? 1 : -1);
        // 边缘(首/尾之外)停住 — handled 空操作,不冒泡成全局 seek.
        if (nextIdx < 0 || nextIdx >= nodes.length) {
          return KeyEventResult.handled;
        }
        nodes[nextIdx].requestFocus();
        return KeyEventResult.handled;
      },
      child: child,
    ),
  );
}
