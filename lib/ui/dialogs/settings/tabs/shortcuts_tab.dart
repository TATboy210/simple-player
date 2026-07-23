// ShortcutsTab — 快捷键设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 快捷键显示（仅展示当前绑定，真实按键录制属 Phase 26 NAV-03），
// 用户交互通过 pending.update() 存储，不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 快捷键设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
///
/// 注意：真实按键录制属 Phase 26 (NAV-03)，骨架仅显示标签 + 当前按键文字。
class ShortcutsTab extends StatelessWidget {
  final PendingSettingsState pending;
  const ShortcutsTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: AnimatedSectionList(
      children: [
        // 快捷键列表 — 毛玻璃卡片
        GlassContainer(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: '快捷键', icon: Icons.keyboard),
              SettingRow(
                title: '播放 / 暂停',
                description: '切换播放状态',
                control: _KeyChip(keyLabel: 'Space'),
              ),
              SettingRow(
                title: '快进 / 快退',
                description: '前进或后退 5 秒',
                control: _KeyChip(keyLabel: '← / →'),
              ),
              SettingRow(
                title: '音量调节',
                description: '增大或减小音量 5%',
                control: _KeyChip(keyLabel: '↑ / ↓'),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

/// 快捷键显示芯片 — 骨架占位，展示当前绑定的按键文字。
///
/// Phase 26 将替换为可录制的按键输入控件。
class _KeyChip extends StatelessWidget {
  final String keyLabel;
  const _KeyChip({required this.keyLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spMd,
        vertical: Tokens.spXs,
      ),
      decoration: BoxDecoration(
        color: Tokens.bgElevated,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.borderHighlight),
      ),
      child: Text(
        keyLabel,
        style: const TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
          fontFamily: Tokens.fontFamilyMono,
        ),
      ),
    );
  }
}
