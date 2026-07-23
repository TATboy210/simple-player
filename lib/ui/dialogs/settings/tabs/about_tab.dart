// AboutTab — 关于设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
//
// 版本信息 + 链接占位，用户交互通过 pending.update() 存储，
// 不直接调用 service 方法。

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../shared/animated_section_list.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/section_header.dart';
import '../../../shared/settings_card.dart';
import '../pending_settings.dart';

/// 关于设置 tab（骨架）— Phase 25 框架占位，后续阶段填充真实功能。
///
/// 接收 [PendingSettingsState] 引用，用户交互通过 pending.update() 存储，
/// 不直接调用 service 方法。
class AboutTab extends StatelessWidget {
  final PendingSettingsState pending;
  const AboutTab({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return const AnimatedSectionList(
      children: [
        // 版本信息 — 毛玻璃卡片
        GlassContainer(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: '关于', icon: Icons.info_outline),
              SettingRow(
                title: 'Simple Player',
                description: 'Flutter 桌面媒体播放器',
                control: Text(
                  'v1.8.0',
                  style: TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
              SettingRow(
                title: '引擎',
                description: 'fvp (MDK/FFmpeg)',
                control: Text(
                  'MDK 0.1.x',
                  style: TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: Tokens.fontCaption,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 链接 — 毛玻璃卡片
        GlassContainer(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: '链接', icon: Icons.link),
              SettingRow(
                title: '项目主页',
                description: 'GitHub 仓库',
                control: Icon(
                  Icons.open_in_new,
                  size: Tokens.iconSm,
                  color: Tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
