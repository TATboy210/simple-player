// tab_content.dart — Phase 28 从 settings_overlay_shell.dart 提取的 tab 内容区 (REFAC-01)。
//
// 职责：7 个 tab 的 IndexedStack + 每个 tab 的 200ms opacity 淡入淡出 + bgPanel 背板 + spMd padding。
// 状态归属：selectedTab ValueListenable 仍由 SettingsPanelController.state.selectedTab 拥有，
// pending (PendingSettingsState) 仍由 controller 持有；本 widget 仅读取两者用于渲染，
// 不引入第二个 notifier 或状态副本（PLAN must_haves truths 之一）。
//
// 测试约束：settings_tab_content_test.dart 与 settings_responsive_integration_test.dart
// 通过 `firstWhere((s) => s.children.length == 7)` 定位本 IndexedStack，故必须保持
// 7-child 显式结构（不能用 List.generate 折叠），且不额外包裹 FocusTraversalGroup
// （focus_navigation_test 断言外层 FocusTraversalGroup 数量 >= 4 不变）。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'pending_settings.dart';
import 'tabs/about_tab.dart';
import 'tabs/audio_tab.dart';
import 'tabs/equalizer_tab.dart';
import 'tabs/general_tab.dart';
import 'tabs/performance_tab.dart';
import 'tabs/shortcuts_tab.dart';
import 'tabs/video_tab.dart';

/// 设置面板内容区 — 7-child [IndexedStack] + 每 tab 200ms opacity 过渡 (D-01/D-02)。
///
/// 从 [SettingsOverlayShell] 提取 (REFAC-01)，保持 7 个 tab 显式列出、
/// [PendingSettingsState] 注入、`Tokens.bgPanel` 背板、`Tokens.spMd` 内边距、
/// [TweenAnimationBuilder] opacity wrapper 全部不变。状态由外部 [selectedTab]
/// ValueListenable 拥有，本 widget 仅渲染，确保 [SettingsPanelController]
/// 保持唯一状态拥有者（PLAN must_haves truths 之一）。
class SettingsTabContent extends StatelessWidget {
  const SettingsTabContent({
    super.key,
    required this.selectedTab,
    required this.pending,
  });

  /// 当前选中 tab 索引 — 由 SettingsPanelController.state.selectedTab 拥有。
  final ValueListenable<int> selectedTab;

  /// 延迟应用状态容器 — 7 个 tab 通过它读写用户修改（TABS-04）。
  final PendingSettingsState pending;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTab,
      builder: (context, selectedIndex, _) {
        return ColoredBox(
          color: Tokens.bgPanel,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.spMd),
            child: IndexedStack(
              index: selectedIndex,
              children: [
                // Tab 0: 通用
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 0 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: GeneralTab(pending: pending),
                ),
                // Tab 1: 均衡器
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 1 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: EqualizerTab(pending: pending),
                ),
                // Tab 2: 音频
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 2 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: AudioTab(pending: pending),
                ),
                // Tab 3: 视频
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 3 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: VideoTab(pending: pending),
                ),
                // Tab 4: 快捷键
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 4 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: ShortcutsTab(pending: pending),
                ),
                // Tab 5: 关于
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 5 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: AboutTab(pending: pending),
                ),
                // Tab 6: 性能
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: 6 == selectedIndex ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: PerformanceTab(pending: pending),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
