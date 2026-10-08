import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 不透明次级表面 — no background sampling, glass highlights or primary changes.
class SecondarySurface extends StatelessWidget {
  const SecondarySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.spMd),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional semantic severity border; never an optical gradient/highlight.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: padding,
    decoration: BoxDecoration(
      color: Tokens.bgPanel,
      borderRadius: BorderRadius.circular(Tokens.secondarySurfaceRadius),
      border: switch (borderColor) {
        final color? => Border.all(color: color),
        null => null,
      },
    ),
    child: child,
  );
}
