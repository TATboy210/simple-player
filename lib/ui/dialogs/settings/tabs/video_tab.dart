// VideoTab — 视频设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 解码器选择 + 去隔行 + 色彩校正，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 视频设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class VideoTab extends StatelessWidget {
  final PendingSettingsState pending;
  const VideoTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AnimatedSectionList(
      children: [
        // 解码器选择 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '解码器', icon: Icons.memory),
              SettingRow(
                title: '解码方式',
                description: '硬件解码性能更好，软件解码兼容性更高',
                control: DropdownButton<String>(
                  value: pending.current('decoder') as String? ?? 'auto',
                  dropdownColor: Tokens.bgElevated,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                  ),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('自动')),
                    DropdownMenuItem(
                      value: 'hardware',
                      child: Text('硬件解码'),
                    ),
                    DropdownMenuItem(
                      value: 'software',
                      child: Text('软件解码'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) pending.update('decoder', v);
                  },
                ),
              ),
            ],
          ),
        ),
        // 画面设置 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '画面', icon: Icons.tv),
              SettingRow(
                title: '去隔行',
                description: '仅软件解码器生效',
                control: Switch(
                  value: pending.current('deinterlace') as bool? ?? false,
                  onChanged: (v) => pending.update('deinterlace', v),
                  activeThumbColor: Tokens.accent,
                ),
              ),
            ],
          ),
        ),
        // 色彩校正 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: '色彩校正',
                icon: Icons.color_lens,
              ),
              SettingRow(
                title: '亮度',
                description: '调整视频画面亮度',
                control: SizedBox(
                  width: 120,
                  child: Slider(
                    value:
                        (pending.current('brightness') as double?) ?? 0.0,
                    min: -1.0,
                    max: 1.0,
                    onChanged: (v) => pending.update('brightness', v),
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
