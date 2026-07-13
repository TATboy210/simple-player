import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../../kernel/services/theme_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/glass_container.dart';
import '../../shared/animated_section_list.dart';
import '../../shared/section_header.dart';

/// 通用设置 tab — 语言切换 + 主题选择
///
/// 接收当前选中的 locale/themeIndex（由 SettingsPanel 管理的 pending 值），
/// 不直接修改 App 状态。用户点击时通过回调通知 SettingsPanel 更新 pending 值。
class GeneralTab extends StatelessWidget {
  final String currentLocale;
  final int currentThemeIndex;
  final ValueChanged<String>? onLocaleChanged;
  final ValueChanged<int>? onThemeChanged;
  final VoidCallback? onReset;

  const GeneralTab({
    super.key,
    required this.currentLocale,
    required this.currentThemeIndex,
    this.onLocaleChanged,
    this.onThemeChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedSectionList(
      children: [
        // 语言选择 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.language, icon: Icons.language),
              _LanguageSelector(
                currentLocale: currentLocale,
                onChanged: onLocaleChanged,
              ),
            ],
          ),
        ),
        // 主题选择 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: l10n.theme, icon: Icons.palette),
              _ThemeSelector(
                currentIndex: currentThemeIndex,
                onChanged: onThemeChanged,
              ),
            ],
          ),
        ),
        // 重置按钮 — 底部左侧
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: Tokens.spSm),
            child: TextButton(
              onPressed: onReset,
              child: Text(
                l10n.resetToDefaults,
                style: const TextStyle(
                  color: Tokens.textSecondary,
                  fontSize: Tokens.fontCaption,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String currentLocale;
  final ValueChanged<String>? onChanged;

  const _LanguageSelector({required this.currentLocale, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LangChip(
          label: '中文',
          selected: currentLocale == 'zh',
          onTap: () => onChanged?.call('zh'),
        ),
        const SizedBox(width: Tokens.spSm),
        _LangChip(
          label: 'English',
          selected: currentLocale == 'en',
          onTap: () => onChanged?.call('en'),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: selected ? Tokens.bgHover : Colors.transparent,
          border: Border.all(
            color: selected ? Tokens.accent : Tokens.borderHighlight,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Tokens.accent : Tokens.textPrimary,
            fontSize: Tokens.fontCaption,
            fontWeight: selected ? Tokens.weightMedium : Tokens.weightRegular,
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onChanged;

  const _ThemeSelector({required this.currentIndex, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.themeMidnight, l10n.themeOcean, l10n.themeForest];

    return Row(
      children: [
        for (int i = 0; i < ThemeService.accents.length; i++) ...[
          if (i > 0) const SizedBox(width: Tokens.spSm),
          _ThemeChip(
            label: labels[i],
            color: ThemeService.accents[i],
            selected: currentIndex == i,
            onTap: () => onChanged?.call(i),
          ),
        ],
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spMd,
          vertical: Tokens.spXs,
        ),
        decoration: BoxDecoration(
          color: selected ? Tokens.bgHover : Colors.transparent,
          border: Border.all(
            color: selected ? color : Tokens.borderHighlight,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Tokens.spXs),
            Text(
              label,
              style: TextStyle(
                color: selected ? Tokens.accent : Tokens.textPrimary,
                fontSize: Tokens.fontCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
