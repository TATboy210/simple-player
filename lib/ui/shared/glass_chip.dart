import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 毛玻璃风格选项芯片 — 用于倍速选择器、音质切换等横向选项
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 48.0,
    this.height = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        hoverColor: Tokens.bgHover,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: Tokens.bgGlass,
                  borderRadius: BorderRadius.circular(Tokens.radiusBtn),
                  border: Border.all(color: Tokens.borderHighlight, width: 0.5),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Tokens.accent : Tokens.textPrimary,
              fontSize: Tokens.fontCaption,
              fontWeight: selected
                  ? Tokens.weightSemiBold
                  : Tokens.weightRegular,
            ),
          ),
        ),
      ),
    );
  }
}
