import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

/// 播放模式按钮（图标 + 文字标签）
class PlayModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isIdle;
  final VoidCallback? onPressed;

  const PlayModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.isIdle = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      hoverColor: Tokens.bgHover,
      borderRadius: BorderRadius.circular(Tokens.radiusBtn),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spSm,
          vertical: Tokens.spXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Tokens.iconMd, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: Tokens.fontOverline,
                fontWeight: Tokens.weightMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
