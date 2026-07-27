import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 侧边栏导航项 — 图标 + 标签，hover 渐变背景 + 选中指示器动画
///
/// 交互反馈：
/// - hover → 背景渐变到 Tokens.bgHover（durationFast 80ms）
/// - selected → 左侧 2px 指示器从透明滑入 Tokens.accent（durationNormal 150ms）
/// - 图标/文字颜色在 textSecondary ↔ accent 之间平滑过渡
class SettingsNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  /// 响应式字体大小 — normal 模式 14px, compact 模式 12px
  final double fontSize;
  /// 响应式水平间距 — normal 模式 16px, compact 模式 8px
  final double spacing;

  const SettingsNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = Tokens.fontOverline,
    this.spacing = Tokens.spSm,
  });

  @override
  State<SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<SettingsNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    // 背景色：hover 时高亮，selected 时也高亮
    final bgColor = _hovering || widget.selected
        ? Tokens.bgHover
        : Colors.transparent;

    // 左侧选中指示器颜色和宽度
    final indicatorColor =
        widget.selected ? Tokens.accent : Colors.transparent;
    const indicatorWidth = 2.0;

    // 图标和文字颜色
    final fgColor =
        widget.selected ? Tokens.accent : Tokens.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: Tokens.durationFast),
          width: 80,
          padding: EdgeInsets.symmetric(
            horizontal: widget.spacing,
            vertical: Tokens.spSm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left: BorderSide(
                color: indicatorColor,
                width: indicatorWidth,
              ),
            ),
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          // D-04 fallback：窄面板（400px 面板下每 tab 内容宽 ~23px）时，
          // "均衡器"等 3 字 label 自然宽度 ~42px 会触发 RenderFlex overflow。
          // 用 stretch + FittedBox(scaleDown) 让 label 自适应缩放到可用宽度，
          // 宽面板下 Text 自然宽 < 约束，scaleDown 不触发，保持原 fontSize 不变。
          // 不改 sizing 公式 / breakpointResponsive 语义 / compact 逻辑（D-04 边界）。
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: Tokens.durationFast),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.selected),
                  size: Tokens.iconLg,
                  color: fgColor,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: Tokens.durationFast),
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    color: fgColor,
                    fontWeight: widget.selected
                        ? Tokens.weightMedium
                        : Tokens.weightRegular,
                  ),
                  child: Text(widget.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
