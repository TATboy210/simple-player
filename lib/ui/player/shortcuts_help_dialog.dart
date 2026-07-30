import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'keyboard_handler.dart';

/// 快捷键帮助对话框 — 表格展示所有快捷键定义.
///
/// 数据源 [shortcutDefinitions] 与 [KeyboardHandler] 共享单一数据源,
/// 保证帮助面板与实际绑定始终一致.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: Tokens.bgPanel,
      title: Text(
        l10n.shortcutsHelpTitle,
        style: const TextStyle(color: Tokens.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        child: Table(
          columnWidths: const {0: FixedColumnWidth(100), 1: FlexColumnWidth()},
          children: shortcutDefinitions(l10n)
              .map(
                (s) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        s.$1,
                        style: const TextStyle(
                          color: Tokens.accent,
                          fontSize: Tokens.fontCaption,
                          fontWeight: Tokens.weightMedium,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        s.$2,
                        style: const TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: Tokens.fontCaption,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close, style: const TextStyle(color: Tokens.accent)),
        ),
      ],
    );
  }
}
