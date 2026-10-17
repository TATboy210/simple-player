import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';

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

  /// 最近一次上报的逻辑拖动区 (null = 已清除) 与调用次数。
  Rect? dragRegion;
  int dragRegionCallCount = 0;

  /// 模拟平台是否原生接管拖动区 (默认 true, 同 Windows 生产路径;
  /// 手势兜底在 Flutter 侧始终在位, 不受此值影响)。
  bool supportsDragRegion = true;

  @override
  bool setTitleBarDragRegion(Rect? logicalRect, double devicePixelRatio) {
    if (_disposed) return false;
    dragRegionCallCount++;
    dragRegion = logicalRect;
    return supportsDragRegion;
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

  @override
  bool get isFullscreen => mode.value == WindowMode.fullscreen;

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
