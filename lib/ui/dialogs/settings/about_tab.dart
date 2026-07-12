import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/glass_container.dart';
import '../../shared/animated_section_list.dart';
import '../../shared/section_header.dart';
import '../../shared/settings_card.dart'; // keep for SettingRow export

/// 关于页面 tab — 版本、技术栈、开源许可
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedSectionList(
      children: [
        // 应用名称 + 版本 — GlassContainer + SectionHeader 替代 SettingsCard
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.brandName, icon: Icons.info_outline),
              SettingRow(
                title: l10n.version,
                control: const Text(
                  '0.0.1',
                  style: TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
              SettingRow(
                title: l10n.techStack,
                control: const Text(
                  'Flutter + fvp',
                  style: TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 版权信息
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.copyright, icon: Icons.copyright),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.spXs),
                child: Text(
                  l10n.copyright,
                  style: const TextStyle(
                    color: Tokens.textTertiary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 开源许可 — GlassContainer + InkWell 替代 SettingsActionCard
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: InkWell(
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Simple Player',
              applicationVersion: '0.0.1',
            ),
            borderRadius: BorderRadius.circular(Tokens.radiusLarge),
            child: SettingRow(
              icon: Icons.article,
              title: l10n.licenses,
              control: const Icon(
                Icons.chevron_right,
                size: Tokens.iconMd,
                color: Tokens.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
