import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'glass_container.dart' show GlassButton;
import 'secondary_surface.dart';

/// 删除操作确认条 — opaque secondary surface, with native dialog exits.
///
/// The message scrolls independently so cancel/confirm remain visible even at
/// large text scales. This widget only returns a choice; callers own deletion.
class GlassConfirmStrip extends StatelessWidget {
  /// 确认返回 true；取消、遮罩与原生 ESC 返回 false。
  /// Opens a native dialog route without changing the caller's destructive flow.
  static Future<bool> show(
    BuildContext context, {
    required String message,
    IconData confirmIcon = Icons.delete,
    required String confirmTooltip,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Retain the existing below-center position above the player controls.
        alignment: const Alignment(0, 0.62),
        child: GlassConfirmStrip._(
          message: message,
          cancelLabel: AppLocalizations.of(dialogContext).cancel,
          confirmIcon: confirmIcon,
          confirmTooltip: confirmTooltip,
        ),
      ),
    );
    return result ?? false;
  }

  const GlassConfirmStrip._({
    required this.message,
    required this.cancelLabel,
    required this.confirmIcon,
    required this.confirmTooltip,
  });

  final String message;
  final String cancelLabel;
  final IconData confirmIcon;
  final String confirmTooltip;

  @override
  Widget build(BuildContext context) => SecondarySurface(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning_amber_outlined,
          size: Tokens.spXl,
          color: Tokens.danger,
        ),
        const SizedBox(width: Tokens.spSm),
        // Flexible inherits the dialog's bounded height. Only message content
        // scrolls: neither action can be stranded below a long filename list.
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
        const SizedBox(width: Tokens.spMd),
        GlassButton.iconOnly(
          icon: Icons.close,
          tooltip: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: Tokens.spXs),
        GlassButton.iconOnly(
          icon: confirmIcon,
          tooltip: confirmTooltip,
          color: Tokens.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}
