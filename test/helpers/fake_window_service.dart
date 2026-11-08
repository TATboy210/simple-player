import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/window_bridge/window_service.dart';

/// 测试替身 — 实现 WindowBridge 接口，无 nativeapi 依赖。
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

  /// 关窗持久化监听注册表 (v0.0.6.2) — 记录注册的监听器, 供测试侧
  /// 手动触发以验证 PlayerServices 的退出落盘接线.
  final List<Future<void> Function()> closingListeners = [];
  int removeClosingListenerCallCount = 0;

  // ─── ValueNotifiers ───

  @override
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  @override
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  @override
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  @override
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  // ─── WindowBridge implementation ───

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

  int titleBarDoubleClickCallCount = 0;

  @override
  void titleBarDoubleClick() {
    if (_disposed) return;
    titleBarDoubleClickCallCount++;
  }

  @override
  void Function() addClosingListener(Future<void> Function() listener) {
    closingListeners.add(listener);
    return () {
      if (closingListeners.remove(listener)) {
        removeClosingListenerCallCount++;
      }
    };
  }

  /// 释放通知器 — 接口不含 dispose（生命周期归组合根），测试自行收尾。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    isResizing.dispose();
    resizeSessionId.dispose();
    isAlwaysOnTop.dispose();
  }
}
