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

  const SettingsNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(vertical: Tokens.spSm),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: Tokens.durationFast),
                style: TextStyle(
                  fontSize: Tokens.fontOverline,
                  color: fgColor,
                  fontWeight: widget.selected
                      ? Tokens.weightMedium
                      : Tokens.weightRegular,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
