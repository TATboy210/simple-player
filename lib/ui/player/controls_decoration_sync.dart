import 'package:flutter/material.dart';

import '../../kernel/engine/engine_state.dart';
import '../theme/tokens.dart';
import 'controls_host.dart';

/// 控制栏装饰/全屏派生状态同步 — idle 信号、decoration 动画与 resize 联动。
///
/// 持有三个展示信号 ([isFullscreen]/[isIdle]/[decoration]) 与两个时序标记
/// (resize 中 / 全屏过渡中)，由编排 State 在监听回调里驱动。
class ControlsDecorationSync {
  ControlsDecorationSync(
    this._host, {
    required TickerProvider vsync,
    required this.onResizeSettled,
  }) : decoration = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: Tokens.durationNormal),
         value: 1.0, // 不 resize 时完全可见
       );

  final ControlsHost _host;

  /// resize 平息 (resizing=false) 后的补同步 — 空置态钉住 (v0.0.6)。
  final VoidCallback onResizeSettled;

  /// 共享 AnimationController — 驱动 resize 淡出/淡入和 decoration 状态切换。
  final AnimationController decoration;

  /// 派生 isFullscreen — 由 windowMode 驱动(单一数据源)，供全屏按钮图标。
  final ValueNotifier<bool> isFullscreen = ValueNotifier<bool>(false);

  /// 将 idle 状态变化限制在中央控制组，同时保留装饰动画独立监听。
  final ValueNotifier<bool> isIdle = ValueNotifier<bool>(false);

  /// resize 期间忽略 engine 状态变化，避免 controller 竞争。
  bool _isResizing = false;

  /// 全屏切换过渡标记 — 跳过 isResizing 触发的控制栏淡出，避免全屏切换闪烁。
  /// mode 进出全屏时置位，resize 平息后由 [onResizeChanged] 清除。
  bool _isFullscreenTransition = false;

  bool get _engineIdle => _host.engine.state.value == MediaState.idle;

  /// 以当前 windowMode / engine 状态初始化信号 (不动 AutoHide/过渡标记)。
  void init() {
    isIdle.value = _engineIdle;
    isFullscreen.value = _host.windowMode.value.isFullscreen;
  }

  /// 仅刷新 idle 信号，不驱动动画 (engine 更换 / activate 路径)。
  void refreshIdle() => isIdle.value = _engineIdle;

  /// 由 WindowMode 同步全屏派生状态(图标/auto-hide/过渡标记)。
  void syncMode() {
    final fs = _host.windowMode.value.isFullscreen;
    if (isFullscreen.value == fs) return;
    _host.menuSession?.cancel();
    isFullscreen.value = fs;
    _host.autoHide.isFullscreen = fs;
    // 标记过渡，下次 isResizing=true 跳过 reverse() — 抑制切换期控制栏闪烁，
    // 同时避免窗口恢复 resize 期间动画竞争(退出单帧异常的候选源)。
    _isFullscreenTransition = true;
  }

  /// engine.state → idle 信号 + decoration 方向 (idle 淡出 / playing 淡入)。
  void syncIdle() {
    refreshIdle();
    if (isIdle.value) {
      decoration.reverse();
    } else {
      decoration.forward();
    }
  }

  /// engine 状态变化 — resize 期间忽略；返回 true 表示已处理。
  bool onEngineStateChanged() {
    if (_isResizing) return false;
    syncIdle();
    return true;
  }

  /// resize 信号变化 — resizing=true 时 reverse() 淡出，false 时按 engine
  /// 状态恢复。全屏切换期间跳过 reverse() 防闪烁。
  void onResizeChanged() {
    final resizing = _host.resizing?.value ?? false;
    // CB-06: 同步 AutoHideController — resize 期间冻结隐藏计时器。
    _host.autoHide.resizing = resizing;
    _isResizing = resizing;
    if (resizing) {
      if (!_isFullscreenTransition) decoration.reverse(); // 1.0 → 0.0
      return;
    }
    _isFullscreenTransition = false; // 清除标记，恢复正常 resize 行为
    // resize 期间被暂缓的引擎状态变化 — 结束时补同步。
    syncIdle();
    onResizeSettled();
  }

  /// 释放动画与信号。
  void dispose() {
    decoration.dispose();
    isFullscreen.dispose();
    isIdle.dispose();
  }
}
