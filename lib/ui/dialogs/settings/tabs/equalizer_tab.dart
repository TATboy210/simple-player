// EqualizerTab — 均衡器设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 均衡器开关 + 3 频段滑块，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 均衡器设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class EqualizerTab extends StatelessWidget {
  final PendingSettingsState pending;
  const EqualizerTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return AnimatedSectionList(
      children: [
        // 均衡器开关 + 频段滑块 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '均衡器', icon: Icons.equalizer),
              // 均衡器开关
              SettingRow(
                title: '启用均衡器',
                description: '开启音频均衡器调节',
                control: Switch(
                  value: pending.current('eqEnabled') as bool? ?? false,
                  onChanged: (v) => pending.update('eqEnabled', v),
                  activeThumbColor: Tokens.accent,
                ),
              ),
              // 60Hz 低频 — 骨架用 dummy ValueNotifier
              SettingSliderRow(
                label: '60Hz',
                notifier: ValueNotifier(0.0),
                min: -1.0,
                max: 1.0,
                displaySuffix: '%',
              ),
              // 1kHz 中频
              SettingSliderRow(
                label: '1kHz',
                notifier: ValueNotifier(0.0),
                min: -1.0,
                max: 1.0,
                displaySuffix: '%',
              ),
              // 14kHz 高频
              SettingSliderRow(
                label: '14kHz',
                notifier: ValueNotifier(0.0),
                min: -1.0,
                max: 1.0,
                displaySuffix: '%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
