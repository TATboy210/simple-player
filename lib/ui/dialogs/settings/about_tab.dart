import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/settings_card.dart';

/// 关于页面 tab — 版本、技术栈、开源许可
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 应用名称 + 版本
        SettingsCard(
          title: l10n.brandName,
          icon: Icons.info_outline,
          children: [
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
        // 版权信息
        SettingsCard(
          title: l10n.copyright,
          icon: Icons.copyright,
          children: [
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
        // 开源许可
        SettingsActionCard(
          title: l10n.licenses,
          icon: Icons.article,
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Simple Player',
            applicationVersion: '0.0.1',
          ),
        ),
      ],
    );
  }
}
