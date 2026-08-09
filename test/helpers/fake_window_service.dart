import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/bridge/window_bridge.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';

/// 测试替身 — 实现 WindowBridge 接口，无 window_manager 依赖。
///
/// 提供调用计数用于测试断言。
class FakeWindowService implements WindowBridge {
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
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(1280, 720));
  @override
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  @override
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  @override
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  // ─── WindowBridge implementation ───

  @override
  Future<void> init() async {}

  @override
  Future<void> setMode(WindowMode target) async {
    modeCallCount++;
    lastModeValue = target;
    mode.value = target;
  }

  // Importers: integration tests, widget tests
  // Affected API: setAspectRatio — new WindowBridge method stub
  @override
  Future<void> setAspectRatio(double ratio) async {}

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    alwaysOnTopCallCount++;
    lastAlwaysOnTopValue = value;
    isAlwaysOnTop.value = value;
  }

  @override
  Future<void> minimize() async {
    minimizeCallCount++;
  }

  @override
  Future<void> close() async {
    closeCallCount++;
  }

  @override
  Future<void> startDragging() async {
    startDraggingCallCount++;
  }

  @override
  bool get isFullscreen => mode.value == WindowMode.fullscreen;

  void showAfterFirstFrame() {}

  @override
  void dispose() {
    mode.dispose();
    windowSize.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
