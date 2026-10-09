import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'glass_container.dart' show GlassButton;
import 'secondary_surface.dart';

/// 删除确认内容 — owner supplies choice callbacks, no Navigator or root barrier.
/// Only the message scrolls; both actions stay reachable in short panels.
class GlassConfirmStrip extends StatelessWidget {
  const GlassConfirmStrip({
    super.key,
    required this.message,
    required this.cancelLabel,
    required this.confirmTooltip,
    required this.onCancel,
    required this.onConfirm,
    this.cancelFocus,
    this.confirmIcon = Icons.delete,
  });

  final String message;
  final String cancelLabel;
  final String confirmTooltip;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final FocusNode? cancelFocus;
  final IconData confirmIcon;

  @override
  Widget build(BuildContext context) => SecondarySurface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ),
        ),
        const SizedBox(height: Tokens.spSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              size: Tokens.spXl,
              color: Tokens.danger,
            ),
            const Spacer(),
            GlassButton.iconOnly(
              icon: Icons.close,
              tooltip: cancelLabel,
              autofocus: true,
              focusNode: cancelFocus,
              onPressed: onCancel,
            ),
            const SizedBox(width: Tokens.spXs),
            GlassButton.iconOnly(
              icon: confirmIcon,
              tooltip: confirmTooltip,
              color: Tokens.danger,
              onPressed: onConfirm,
            ),
          ],
        ),
      ],
    ),
  );
}
