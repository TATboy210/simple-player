// GeneralTab — 通用设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 语言切换 + 外观设置，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 通用设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class GeneralTab extends StatelessWidget {
  final PendingSettingsState pending;
  const GeneralTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
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
              const SectionHeader(title: '语言', icon: Icons.language),
              SettingRow(
                title: '界面语言',
                description: '选择界面显示语言',
                control: DropdownButton<String>(
                  value: pending.current('locale') as String? ?? 'zh',
                  dropdownColor: Tokens.bgElevated,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                  ),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v != null) pending.update('locale', v);
                  },
                ),
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
    );
  }
}
