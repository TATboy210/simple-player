// panel_key_bindings.dart — Phase 28 从 settings_overlay_shell.dart 提取的键盘/手柄路由 helper (REFAC-01)；
// Phase 32 (NAV-02/NAV-04/NAV-06/NAV-07) 扩展为四向箭头 + 方向辉光 + 删除跨平台 Left1/Right1。
//
// 职责：把面板 root Focus 收到的 KeyDown 事件映射到 SettingsPanelController 的
// close/prevTab/nextTab 三个动作，并把四个方向键的输入信号喂给 InputModeDetector。
// ESC/B 关面板；左右箭头切 tab 并记录箭头活动；上下箭头记录箭头活动并触发方向辉光；
// LB/RB 循环切 tab（仅 gameButton13/12，删除跨平台 gameButtonLeft1/Right1，NAV-04）。
// 状态归属：本 helper 无状态，所有动作委托给 controller 与 InputModeDetector；不引入第二个 notifier。
//
// 设计约束（PLAN Task 1）：root Focus 仍留在 SettingsOverlayShell（保持焦点作用域
// 与 FocusTraversalGroup 层级不变，D-08），onKeyEvent 仅委托给本 helper 的 handle 方法。
// KeyUp 事件仍返回 ignored（不消费），与原实现一致。
// NAV-07 遏制：四个方向键全部返回 handled，防止冒泡到外层 KeyboardHandler 的 seek/volume 回调。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../kernel/services/input_mode_detector.dart';
import 'settings_panel_controller.dart';

/// 设置面板键盘/手柄事件路由 — 把 root Focus 的 KeyDown 映射到 controller 动作 +
/// 喂给 [InputModeDetector]（D-04/D-05/D-06/D-07，NAV-02/NAV-04/NAV-06/NAV-07）。
///
/// 从 [SettingsOverlayShell] 提取 (REFAC-01)。Phase 32 扩展：四个方向键全部
/// 调用 [InputModeDetector.instance.recordArrowKey]（NAV-02 启发式信号），
/// 上下箭头额外调用 [InputModeDetector.instance.setArrowGlow] 触发方向辉光（NAV-06）；
/// 删除跨平台 [LogicalKeyboardKey.gameButtonLeft1]/[LogicalKeyboardKey.gameButtonRight1]
/// 比较，仅保留 Windows 直接映射的 gameButton13/12（D-05，NAV-04 grep gate）。
/// KeyUp 事件返回 [KeyEventResult.ignored]，不消费。
///
/// 无状态 helper：所有动作委托给注入的 [SettingsPanelController]，
/// 输入信号委托给进程级 [InputModeDetector.instance]，不持有副本状态，
/// 确保 controller 保持唯一状态拥有者（PLAN must_haves truths 之一）。
class SettingsPanelKeyBindings {
  const SettingsPanelKeyBindings(this.controller);

  /// 路由目标 — close/prevTab/nextTab 的实际执行者。
  final SettingsPanelController controller;

  /// 处理 root Focus 的按键事件 — 仅消费 KeyDown，KeyUp 直接忽略 (PANEL-06/D-04/D-05)。
  ///
  /// 面板打开时事件由 Focus subtree 消费（返回 handled），不冒泡到
  /// KeyboardHandler（避免触发 seek ±5s / 音量 ±5%，NAV-07 遏制）。
  /// 四个方向键（上下左右）全部调用 [InputModeDetector.instance.recordArrowKey]，
  /// 上下箭头额外调用 [InputModeDetector.instance.setArrowGlow]。
  KeyEventResult handle(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ESC/B — 关面板（PANEL-06）
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyB) {
      controller.close();
      return KeyEventResult.handled;
    }

    // Arrow Left — 记录箭头活动 + 切换到上一个 tab（D-04，NAV-02）
    if (key == LogicalKeyboardKey.arrowLeft) {
      InputModeDetector.instance.recordArrowKey();
      controller.prevTab();
      return KeyEventResult.handled;
    }

    // Arrow Right — 记录箭头活动 + 切换到下一个 tab（D-04，NAV-02）
    if (key == LogicalKeyboardKey.arrowRight) {
      InputModeDetector.instance.recordArrowKey();
      controller.nextTab();
      return KeyEventResult.handled;
    }

    // Arrow Up — 记录箭头活动 + 触发向上辉光（NAV-02/NAV-06，NAV-07 遏制）
    if (key == LogicalKeyboardKey.arrowUp) {
      InputModeDetector.instance.recordArrowKey();
      InputModeDetector.instance.setArrowGlow(ArrowDirection.up);
      return KeyEventResult.handled;
    }

    // Arrow Down — 记录箭头活动 + 触发向下辉光（NAV-02/NAV-06，NAV-07 遏制）
    if (key == LogicalKeyboardKey.arrowDown) {
      InputModeDetector.instance.recordArrowKey();
      InputModeDetector.instance.setArrowGlow(ArrowDirection.down);
      return KeyEventResult.handled;
    }

    // NOTE (32-03 诊断, 2026-07-29)：Windows 桌面 profile 实测证明 Xbox 手柄
    // LB/RB（及 A/B/X/Y 等面键）不会作为 KeyEvent 到达本 Focus 处理器——
    // 仅 D-pad 被重映射层翻译成键盘箭头才到达。即下方 gameButton12/13 比较
    // 在 Windows 桌面从不命中（死路由）。真肩键支持需经 XInput 桥接
    // （window_bridge MethodChannel + GamepadService），延后到 32-04。
    // 32-01 当初"gameButton13/12 = Windows 直接映射肩键"的前提已被实测证伪。
    // Gamepad Left Shoulder — 切换到上一个 tab（D-05，仅 gameButton13）
    if (_isLeftShoulder(key)) {
      controller.prevTab();
      return KeyEventResult.handled;
    }

    // Gamepad Right Shoulder — 切换到下一个 tab（D-05，仅 gameButton12）
    if (_isRightShoulder(key)) {
      controller.nextTab();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 左肩键检测 — 仅 Windows 直接映射的 gameButton13（NAV-04：删除跨平台 gameButtonLeft1）。
  static bool _isLeftShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton13;

  /// 右肩键检测 — 仅 Windows 直接映射的 gameButton12（NAV-04：删除跨平台 gameButtonRight1）。
  static bool _isRightShoulder(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.gameButton12;
}
