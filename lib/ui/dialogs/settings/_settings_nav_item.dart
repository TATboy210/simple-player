import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 侧边栏导航项 — 图标 + 标签，选中高亮
class SettingsNavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: Tokens.spSm),
        decoration: BoxDecoration(
          color: selected ? Tokens.bgHover : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? Tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: Tokens.iconLg,
              color: selected ? Tokens.accent : Tokens.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Tokens.accent : Tokens.textSecondary,
                fontWeight:
                    selected ? Tokens.weightMedium : Tokens.weightRegular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
