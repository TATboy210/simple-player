// SettingsPanelState — Phase 23 PANEL-01 状态模型。
//
// 纯 Dart 状态容器，持有恰好 3 个 ValueNotifier，无业务逻辑。
// D-04 边界：locale/theme 延迟应用/快捷键原始值等状态暂留 widget 本地，
// Phase 25（TABS-04）再迁移，本类不持有。

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 设置面板的最小可测试状态模型 — 恰好 3 个 [ValueNotifier]（PANEL-01）。
///
/// - [isOpen]：面板显隐（驱动覆盖层挂载与动画）。
/// - [selectedTab]：当前选中的 tab 索引（Phase 25 复用既有 7 个 tab）。
/// - [dragOffset]：标题栏拖拽产生的位移，clamp 到窗口边界（PANEL-04/D-09）。
///
/// 不持有 locale/theme/快捷键的延迟应用状态（D-04），这些暂留 widget 本地。
class SettingsPanelState {
  SettingsPanelState();

  /// 面板是否打开.
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  /// 当前选中的 tab 索引.
  final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  /// 面板拖拽偏移量 — 关闭时重置为 [Offset.zero]（见 [SettingsPanelController.close]）.
  final ValueNotifier<Offset> dragOffset = ValueNotifier<Offset>(Offset.zero);

  /// 释放全部三个 notifier.
  void dispose() {
    isOpen.dispose();
    selectedTab.dispose();
    dragOffset.dispose();
  }
}
