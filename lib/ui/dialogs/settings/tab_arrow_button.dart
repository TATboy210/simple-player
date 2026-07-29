// tab_arrow_button.dart — Phase 32 Plan 02 (NAV-01) 端帽箭头按钮。
//
// 职责：设置面板 tab 条左右两端的持久箭头按钮，点击分别接
// controller.prevTab（左）/ nextTab（右）—— 与键盘方向键走同一 controller
// 路径，不引入第二个 tab 选择状态 (NAV-01 / T-32-05)。
//
// 视觉复用控制栏 glass 语言 (ControlBarDecoration.playing)，但不创建
// BackdropFilter (D-04) —— 面板 GlassContainer 已拥有单一模糊边界。

import 'package:flutter/material.dart';

import '../../shared/control_bar_decoration.dart';
import '../../theme/tokens.dart';

/// 设置面板 tab 条端帽箭头按钮 (NAV-01)。
///
/// 持久挂于 7 项 tab 行左右两端：[isLeft] 为 true 渲染左箭头并接
/// [onTap] = controller.prevTab；为 false 渲染右箭头并接 [onTap] =
/// controller.nextTab。与键盘方向键走同一 controller 路径，无第二个
/// tab 选择状态 (T-32-05)。
///
/// 装饰复用 [ControlBarDecoration.playing]（D-04：无 BackdropFilter ——
/// 面板 [GlassContainer] 已拥有单一模糊边界，端帽再造一层模糊会触发
/// 嵌套模糊回读）。内容外包 [RepaintBoundary]（Pitfall 5：隔离端帽
/// 独立的悬停/点击重绘，避免污染 tab 条其余区域的重绘）。
///
/// [isCompact] 切换端帽高度以匹配 [SettingsTabStrip] 的 compact/normal 模式。
class TabArrowButton extends StatelessWidget {
  const TabArrowButton({
    super.key,
    required this.isLeft,
    required this.onTap,
    this.isCompact = false,
  });

  /// true = 左端帽（[Icons.chevron_left]，接 prevTab）；
  /// false = 右端帽（[Icons.chevron_right]，接 nextTab）。
  final bool isLeft;

  /// 点击回调 —— 由 [SettingsTabStrip] 接 controller.prevTab（左）
  /// 或 controller.nextTab（右）。
  final VoidCallback onTap;

  /// 紧凑布局标志 —— 端帽高度匹配 tab 条 compact/normal 模式。
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    // 端帽高度随 tab 条布局模式切换 —— 与 SettingsTabStrip 的 isCompact 同步。
    final height = isCompact
        ? Tokens.tabStripHeightCompact
        : Tokens.tabStripHeightNormal;
    final radius = BorderRadius.circular(Tokens.tabArrowRadius);

    return RepaintBoundary(
      child: Container(
        width: Tokens.tabArrowWidth,
        height: height,
        // D-04: 复用 ControlBarDecoration.playing 作外壳 —— 无 BackdropFilter。
        // 面板 GlassContainer 已拥有单一模糊边界，端帽再造模糊会嵌套回读。
        decoration: ControlBarDecoration.playing(borderRadius: radius),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            // 复用 GlassButton 先例：bgHover 悬停高亮 + 无 splash 水纹。
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            child: Center(
              child: Icon(
                isLeft ? Icons.chevron_left : Icons.chevron_right,
                size: Tokens.iconMd,
                color: Tokens.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
