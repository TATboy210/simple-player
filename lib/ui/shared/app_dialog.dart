import 'package:flutter/material.dart';

import '../../kernel/ui/theme/tokens.dart';

/// 共享对话框包装器 — 统一视觉风格和关闭按钮
///
/// 所有对话框使用相同的 bgElevated 背景 + radiusLarge 圆角 + 关闭按钮。
/// 支持 LayoutBuilder 响应式：宽屏用指定尺寸，窄屏自适应。
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double width;
  final double height;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.width = 400,
    this.height = 350,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth * 0.9;
        final maxH = constraints.maxHeight * 0.85;
        final w = width.clamp(200.0, maxW).toDouble();
        final h = height.clamp(150.0, maxH).toDouble();

        return AlertDialog(
          backgroundColor: Tokens.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusLarge),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Tokens.textPrimary,
              fontSize: Tokens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(width: w, height: h, child: content),
          actions: [
            ...?actions,
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '关闭',
                style: TextStyle(color: Tokens.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}
