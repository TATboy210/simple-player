import 'package:flutter/material.dart';

import '../../../kernel/ui/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

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
        const SizedBox(height: Tokens.spSm),
        Text(
          l10n.brandName,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontBody,
            fontWeight: Tokens.weightMedium,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: Tokens.spXs),
        Text(
          '${l10n.version} 0.0.1',
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        const SizedBox(height: Tokens.spLg),
        // 技术栈
        _InfoRow(
          label: l10n.techStack,
          value: 'Flutter + fvp (MDK/FFmpeg)',
        ),
        const SizedBox(height: Tokens.spSm),
        // 描述
        Text(
          l10n.copyright,
          style: const TextStyle(
            color: Tokens.textTertiary,
            fontSize: Tokens.fontCaption,
          ),
        ),
        const SizedBox(height: Tokens.spLg),
        // 开源许可按钮
        _LicensesButton(label: l10n.licenses),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Tokens.textSecondary,
            fontSize: Tokens.fontCaption,
            fontWeight: Tokens.weightMedium,
          ),
        ),
        const SizedBox(width: Tokens.spSm),
        Text(
          value,
          style: const TextStyle(
            color: Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
          ),
        ),
      ],
    );
  }
}

class _LicensesButton extends StatelessWidget {
  final String label;

  const _LicensesButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showLicensePage(
        context: context,
        applicationName: 'Simple Player',
        applicationVersion: '0.0.1',
      ),
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Tokens.borderHighlight,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Tokens.accent,
            fontSize: Tokens.fontCaption,
            fontWeight: Tokens.weightMedium,
          ),
        ),
      ),
    );
  }
}
