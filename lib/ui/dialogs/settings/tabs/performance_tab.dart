// PerformanceTab — 性能设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 性能监控开关 + 日志级别选择，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 性能设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class PerformanceTab extends StatelessWidget {
  final PendingSettingsState pending;
  const PerformanceTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return AnimatedSectionList(
      children: [
        // 性能监控 — 毛玻璃卡片
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
                title: '性能监控',
                icon: Icons.speed,
              ),
              SettingRow(
                title: '帧率叠加层',
                description: '在画面上显示实时帧率信息',
                control: Switch(
                  value:
                      pending.current('showFrameStats') as bool? ?? false,
                  onChanged: (v) => pending.update('showFrameStats', v),
                  activeThumbColor: Tokens.accent,
                ),
              ),
            ],
          ),
        ),
        // 日志设置 — 毛玻璃卡片
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '日志', icon: Icons.bug_report),
              SettingRow(
                title: '日志级别',
                description: '控制日志输出详细程度',
                control: DropdownButton<String>(
                  value: pending.current('logLevel') as String? ?? 'info',
                  dropdownColor: Tokens.bgElevated,
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontSize: Tokens.fontBody,
                  ),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'debug', child: Text('Debug')),
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warn', child: Text('Warn')),
                    DropdownMenuItem(value: 'error', child: Text('Error')),
                  ],
                  onChanged: (v) {
                    if (v != null) pending.update('logLevel', v);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
