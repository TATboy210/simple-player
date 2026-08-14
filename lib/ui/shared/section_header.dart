import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Section Header — 卡片内的标题行（从 settings_card.dart 提取）
///
/// 用于 GlassContainer 等卡片组件的标题区域。
/// 支持可选的图标和描述文本。
///
/// ```dart
/// SectionHeader(title: '语言', icon: Icons.language)
/// SectionHeader(title: '均衡器', description: '10 段参数均衡', icon: Icons.equalizer)
/// ```
class SectionHeader extends StatelessWidget {
  /// 标题文本
  final String title;

  /// 可选的描述文本（显示在标题右侧）
  final String? description;

  /// 可选的图标（显示在标题左侧）
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spSm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
            const SizedBox(width: Tokens.spXs),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Tokens.textSecondary,
              fontSize: Tokens.fontCaption,
              fontWeight: Tokens.weightMedium,
            ),
          ),
          if (description != null) ...[
            const SizedBox(width: Tokens.spSm),
            Text(
              // ?? '' 防御消除 `!` (description 已 null 检查, 字段不提升)
              description ?? '',
              style: const TextStyle(
                color: Tokens.textTertiary,
                fontSize: Tokens.fontOverline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
