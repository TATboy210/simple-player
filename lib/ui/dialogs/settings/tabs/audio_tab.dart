// AudioTab — 音频设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 音频输出设备 + 音轨自动选择 + 音量调节，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 音频设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class AudioTab extends StatelessWidget {
  final PendingSettingsState pending;
  const AudioTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AnimatedSectionList(
      children: [
        // 音频输出 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '音频输出', icon: Icons.headphones),
              SettingRow(
                title: '输出设备',
                description: '选择音频输出设备',
                control: DropdownButton<String>(
                  value: pending.current('audioDevice') as String? ?? 'default',
                  dropdownColor: Tokens.bgElevated,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                  ),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text('系统默认'),
                    ),
                    DropdownMenuItem(
                      value: 'speakers',
                      child: Text('扬声器'),
                    ),
                    DropdownMenuItem(
                      value: 'headphones',
                      child: Text('耳机'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) pending.update('audioDevice', v);
                  },
                ),
              ),
            ],
          ),
        ),
        // 音轨设置 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '音轨', icon: Icons.audiotrack),
              SettingRow(
                title: '自动选择音轨',
                description: '优先选择默认语言音轨',
                control: Switch(
                  value:
                      pending.current('autoSelectTrack') as bool? ?? true,
                  onChanged: (v) => pending.update('autoSelectTrack', v),
                  activeThumbColor: Tokens.accent,
                ),
              ),
            ],
          ),
        ),
        // 音量设置 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '音量', icon: Icons.volume_up),
              SettingRow(
                title: '默认音量',
                description: '设置播放器启动时的默认音量',
                control: SizedBox(
                  width: 120,
                  child: Slider(
                    value:
                        (pending.current('defaultVolume') as double?) ?? 0.8,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) => pending.update('defaultVolume', v),
                    activeColor: Tokens.accent,
                    inactiveColor: Tokens.bgHover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}
