import 'package:flutter/material.dart';

import '../../../kernel/ui/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// 通用设置 tab — 语言切换 + 主题选择
///
/// 接收当前选中的 locale/themeIndex（由 SettingsPanel 管理的 pending 值），
/// 不直接修改 App 状态。用户点击时通过回调通知 SettingsPanel 更新 pending 值。
class GeneralTab extends StatelessWidget {
  final String currentLocale;
  final int currentThemeIndex;
  final ValueChanged<String>? onLocaleChanged;
  final ValueChanged<int>? onThemeChanged;

  const GeneralTab({
    super.key,
    required this.currentLocale,
    required this.currentThemeIndex,
    this.onLocaleChanged,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionHeader(l10n.language),
        _LanguageSelector(
          currentLocale: currentLocale,
          onChanged: onLocaleChanged,
        ),
        const SizedBox(height: Tokens.spMd),
        _SectionHeader(l10n.theme),
        _ThemeSelector(
          currentIndex: currentThemeIndex,
          onChanged: onThemeChanged,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Tokens.spSm,
        bottom: Tokens.spXs,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontOverline,
          fontWeight: Tokens.weightMedium,
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String currentLocale;
  final ValueChanged<String>? onChanged;

  const _LanguageSelector({
    required this.currentLocale,
    this.onChanged,
  });

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
            fontWeight:
                selected ? Tokens.weightMedium : Tokens.weightRegular,
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onChanged;

  const _ThemeSelector({
    required this.currentIndex,
    this.onChanged,
  });

  static const _themes = [
    _ThemeData(0, 'Midnight', Color(0xFF2C58F4)),
    _ThemeData(1, 'Ocean', Color(0xFF00B4D8)),
    _ThemeData(2, 'Forest', Color(0xFF2D6A4F)),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.themeMidnight, l10n.themeOcean, l10n.themeForest];

    return Row(
      children: [
        for (int i = 0; i < _themes.length; i++) ...[
          if (i > 0) const SizedBox(width: Tokens.spSm),
          _ThemeChip(
            label: labels[i],
            color: _themes[i].color,
            selected: currentIndex == i,
            onTap: () => onChanged?.call(i),
          ),
        ],
      ],
    );
  }
}

class _ThemeData {
  final int index;
  final String name;
  final Color color;
  const _ThemeData(this.index, this.name, this.color);
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
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
