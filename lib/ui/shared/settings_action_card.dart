import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'settings_card.dart';

/// 操作卡片 — 可点击导航行（用于许可、外部链接等）
///
/// ```dart
/// SettingsActionCard(
///   title: '开源许可',
///   icon: Icons.article,
///   onTap: () => showLicensePage(context: context),
/// )
/// ```
class SettingsActionCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final IconData trailingIcon;
  final VoidCallback onTap;

  const SettingsActionCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.trailingIcon = Icons.chevron_right,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spMd),
      decoration: SettingsCard.cardDecoration,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Tokens.iconSm, color: Tokens.textSecondary),
                const SizedBox(width: Tokens.spSm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Tokens.textPrimary,
                        fontSize: Tokens.fontBody,
                        fontWeight: Tokens.weightRegular,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: const TextStyle(
                          color: Tokens.textTertiary,
                          fontSize: Tokens.fontOverline,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                trailingIcon,
                size: Tokens.iconMd,
                color: Tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
