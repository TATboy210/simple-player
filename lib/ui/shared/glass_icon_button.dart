import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 毛玻璃风格图标按钮，36x36 Material + InkWell
class GlassIconButton extends StatelessWidget {
  static final _radius = BorderRadius.circular(Tokens.radiusBtn);

  final IconData? icon;
  final Widget? child;
  final double iconSize;
  final Color? color;
  final VoidCallback? onPressed;
  final void Function(TapUpDetails details)? onSecondaryTapUp;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    this.icon,
    this.child,
    this.iconSize = Tokens.iconLg,
    this.color = Tokens.textPrimary,
    this.onPressed,
    this.onSecondaryTapUp,
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
          borderRadius: _radius,
          child: InkWell(
            onTap: onPressed,
            onSecondaryTapUp: onSecondaryTapUp,
            hoverColor: Tokens.bgHover,
            highlightColor: Colors.transparent,
            borderRadius: _radius,
            splashFactory: InkRipple.splashFactory,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
