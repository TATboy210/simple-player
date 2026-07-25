// panel_key_bindings.dart — Phase 28 从 settings_overlay_shell.dart 提取的键盘/手柄路由 helper (REFAC-01)。
//
// 职责：把面板 root Focus 收到的 KeyDown 事件映射到 SettingsPanelController 的
// close/prevTab/nextTab 三个动作。ESC/B 关面板，左右箭头切 tab，LB/RB 循环切 tab。
// 状态归属：本 helper 无状态，所有动作委托给 controller；不引入第二个 notifier。
//
// 设计约束（PLAN Task 2）：root Focus 仍留在 SettingsOverlayShell（保持焦点作用域
// 与 FocusTraversalGroup 层级不变），onKeyEvent 仅委托给本 helper 的 handle 方法。
// KeyUp 事件仍返回 ignored（不消费），与原实现一致。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_panel_controller.dart';

/// 设置面板键盘/手柄事件路由 — 把 root Focus 的 KeyDown 映射到 controller 动作 (D-04/D-05/D-06)。
///
/// 从 [SettingsOverlayShell] 提取 (REFAC-01)，保持 ESC/B 关闭、左右箭头切 tab、
/// gameButton13/12（含跨平台 gameButtonLeft1/Right1）循环切 tab 的全部行为不变。
/// KeyUp 事件返回 [KeyEventResult.ignored]，不消费。
///
/// 无状态 helper：所有动作委托给注入的 [SettingsPanelController]，不持有副本状态，
/// 确保 controller 保持唯一状态拥有者（PLAN must_haves truths 之一）。
class SettingsPanelKeyBindings {
  const SettingsPanelKeyBindings(this.controller);

  /// 路由目标 — close/prevTab/nextTab 的实际执行者。
  final SettingsPanelController controller;

  /// 处理 root Focus 的按键事件 — 仅消费 KeyDown，KeyUp 直接忽略 (PANEL-06/D-04/D-05)。
  ///
  /// 面板打开时事件由 Focus subtree 消费（返回 handled），不冒泡到
  /// KeyboardHandler（避免触发 seek ±5s）。
  KeyEventResult handle(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ESC/B — 关面板（PANEL-06）
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyB) {
      controller.close();
      return KeyEventResult.handled;
    }

    // Arrow Left — 切换到上一个 tab（D-04）
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.prevTab();
      return KeyEventResult.handled;
    }

    // Arrow Right — 切换到下一个 tab（D-04）
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.nextTab();
      return KeyEventResult.handled;
    }

    // Gamepad Left Shoulder — 切换到上一个 tab（D-05）
    if (_isLeftShoulder(key)) {
      controller.prevTab();
      return KeyEventResult.handled;
    }

    // Gamepad Right Shoulder — 切换到下一个 tab（D-05）
    if (_isRightShoulder(key)) {
      controller.nextTab();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 左肩键检测 — Windows 映射 gameButton13，跨平台也检查 gameButtonLeft1。
  static bool _isLeftShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton13 ||
      key == LogicalKeyboardKey.gameButtonLeft1;

  /// 右肩键检测 — Windows 映射 gameButton12，跨平台也检查 gameButtonRight1。
  static bool _isRightShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton12 ||
      key == LogicalKeyboardKey.gameButtonRight1;
}
