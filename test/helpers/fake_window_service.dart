import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/window_manager_service/window_manager_service.dart';

/// 测试替身 — 实现 WindowBridge 接口，无 window_manager 依赖。
///
/// 提供调用计数用于测试断言。
class FakeWindowService implements WindowBridge {
  bool _disposed = false;

  // ─── Call tracking ───

  int modeCallCount = 0;
  WindowMode? lastModeValue;
  int alwaysOnTopCallCount = 0;
  bool? lastAlwaysOnTopValue;
  int minimizeCallCount = 0;
  int closeCallCount = 0;
  int startDraggingCallCount = 0;

  // ─── ValueNotifiers ───

  @override
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  @override
  /// 与生产实现一致的默认外部窗口尺寸。
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(1280, 752));
  @override
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  @override
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  @override
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  // ─── WindowBridge implementation ───

  @override
  Future<void> init() async {
    if (_disposed) return;
  }

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed) return;
    modeCallCount++;
    lastModeValue = target;
    mode.value = target;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (_disposed) return;
    alwaysOnTopCallCount++;
    lastAlwaysOnTopValue = value;
    isAlwaysOnTop.value = value;
  }

  @override
  Future<void> minimize() async {
    if (_disposed) return;
    minimizeCallCount++;
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    closeCallCount++;
  }

  @override
  Future<void> startDragging() async {
    if (_disposed) return;
    startDraggingCallCount++;
  }

  @override
  bool get isFullscreen => mode.value == WindowMode.fullscreen;

  void showAfterFirstFrame() {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    windowSize.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
