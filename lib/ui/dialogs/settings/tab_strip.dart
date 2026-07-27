// tab_strip.dart — Phase 28 从 settings_overlay_shell.dart 提取的水平 tab 栏 (REFAC-01)。
//
// 职责：7 个 SettingsNavItem 横排 + selectedTab 驱动高亮 + 响应式 compact/normal 切换。
// 状态归属：SettingsPanelController.state.selectedTab 仍为唯一状态拥有者，本 widget
// 仅通过 ValueListenable 读取、通过 onSelect 回调写回索引，不引入第二个 notifier。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '_settings_nav_item.dart';

/// 设置面板水平 tab 栏 — 7 个 [SettingsNavItem] 横排，[selectedTab] 驱动高亮。
///
/// 从 [SettingsOverlayShell] 提取 (REFAC-01)，保持图标/标签顺序、`Tokens.*` 值、
/// 响应式 compact/normal 切换不变。状态由外部 [selectedTab] ValueListenable 拥有，
/// 本 widget 仅渲染并通过 [onSelect] 回调写回索引，确保 SettingsPanelController
/// 保持唯一状态拥有者（PLAN must_haves truths 之一）。
class SettingsTabStrip extends StatelessWidget {
  const SettingsTabStrip({
    super.key,
    required this.selectedTab,
    required this.onSelect,
    required this.isCompact,
  });

  /// 当前选中 tab 索引 — 由 SettingsPanelController.state.selectedTab 拥有。
  final ValueListenable<int> selectedTab;

  /// tab 选中回调 — 写回 controller.state.selectedTab.value = index。
  final ValueChanged<int> onSelect;

  /// 响应式 compact/normal 模式标志 — 控制 tab 高度、字体大小、间距。
  final bool isCompact;

  /// 7 个 tab 图标（D-01 顺序：EQ/Audio/Video/General/Shortcuts/About/Performance，
  /// General 位于 index 3 中间位）。
  static const _tabIcons = [
    Icons.equalizer,
    Icons.headphones,
    Icons.videocam,
    Icons.tune,
    Icons.keyboard,
    Icons.info_outline,
    Icons.speed,
  ];

  /// 7 个 tab 标签文字（D-01 顺序，General 居中；Phase 25 可升级为 l10n）。
  static const _tabLabels = [
    '均衡器',
    '音频',
    '视频',
    '通用',
    '快捷键',
    '关于',
    '性能',
  ];

  @override
  Widget build(BuildContext context) {
    final fontSize = isCompact
        ? Tokens.tabBarFontCompact
        : Tokens.tabBarFontNormal;
    final spacing = isCompact
        ? Tokens.tabBarSpacingCompact
        : Tokens.tabBarSpacingNormal;

    return ValueListenableBuilder<int>(
      valueListenable: selectedTab,
      builder: (context, selectedIndex, _) {
        return Container(
          height: isCompact ? 56 : 64,
          color: Tokens.bgGlass,
          child: Row(
            children: List.generate(_tabIcons.length, (i) {
              return Expanded(
                child: SettingsNavItem(
                  icon: _tabIcons[i],
                  label: _tabLabels[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                  fontSize: fontSize,
                  spacing: spacing,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
