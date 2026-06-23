import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 右键菜单行 — icon + label 水平排列
///
/// 从 folder_tab.dart 和 thumbnail_tile.dart 提取的共享组件。
class ContextMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const ContextMenuRow(this.icon, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: Tokens.iconMd, color: Tokens.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ],
    );
  }
}
