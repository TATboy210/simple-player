// GeneralTab — 通用设置 tab — 语言切换 + 外观设置。
//
// 语言切换使用 SpinControl（Steam 水平选择器），外观使用 Switch。
// 用户交互通过 pending.update() 存储，不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../option_list_navigation_overlay.dart';
import '../pending_settings.dart';

/// 语言选项列表 — 与 PendingSettingsState 键 'locale' 对应
const _localeOptions = ['zh', 'en'];

/// locale 值到显示文本的映射（D-09）
String _formatLocale(String value) {
  return switch (value) {
    'zh' => '中文',
    'en' => 'English',
    _ => value,
  };
}

/// locale 值到选项索引的转换 — 未知值回退到 0（中文）
int _localeToIndex(String? locale) {
  if (locale == null) return 0;
  final idx = _localeOptions.indexOf(locale);
  return idx >= 0 ? idx : 0;
}

/// 通用设置 tab — 语言 SpinControl + 深色模式 Switch。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class GeneralTab extends StatelessWidget {
  final PendingSettingsState pending;
  const GeneralTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return OptionListNavigationOverlay(
      // The overlay owns the Stack; GeneralTab supplies only its scrollable list.
      child: SingleChildScrollView(
        child: AnimatedSectionList(
          children: [
            // 语言选择 — 毛玻璃卡片 + SpinControl（D-08/D-09/D-10）
            GlassContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spLg,
                vertical: Tokens.spMd,
              ),
              margin: const EdgeInsets.only(bottom: Tokens.spMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '语言', icon: Icons.language),
                  SettingSpinRow(
                    icon: Icons.language,
                    title: '界面语言',
                    description: '选择界面显示语言',
                    options: _localeOptions,
                    currentIndex: _localeToIndex(
                      pending.current('locale') as String?,
                    ),
                    onChanged: (i) =>
                        pending.update('locale', _localeOptions[i]),
                    formatValue: _formatLocale,
                  ),
                ],
              ),
            ),
            // 外观设置 — 毛玻璃卡片
            GlassContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spLg,
                vertical: Tokens.spMd,
              ),
              margin: const EdgeInsets.only(bottom: Tokens.spMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '外观', icon: Icons.dark_mode),
                  SettingRow(
                    title: '深色模式',
                    description: '启用深色主题（当前仅深色主题可用）',
                    control: Switch(
                      value: pending.current('darkMode') as bool? ?? true,
                      onChanged: (v) => pending.update('darkMode', v),
                      activeThumbColor: Tokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
