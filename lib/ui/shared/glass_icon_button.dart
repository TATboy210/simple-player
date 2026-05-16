import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

/// 毛玻璃风格图标按钮，36x36 Material + InkWell
class GlassIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    this.icon,
    this.child,
    this.iconSize = Tokens.iconLg,
    this.color = Tokens.textPrimary,
    this.onPressed,
    this.tooltip,
  }) : assert(
         icon != null || child != null,
         'Either icon or child must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final content = child ?? Icon(icon!, size: iconSize, color: color);

    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Tokens.radiusBtn),
          child: InkWell(
            onTap: onPressed,
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(Tokens.radiusBtn),
            splashFactory: InkRipple.splashFactory,
            child: Center(
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
