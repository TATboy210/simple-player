import 'dart:async';
import 'package:flutter/foundation.dart';
import '../persistence/settings_store.dart';

/// Window persistence service with debounce and write lock.
///
/// Wraps [SettingsStore] window writes with two optimizations:
///
/// 1. **Debounce** (default 150ms): Coalesces rapid `WM_SIZE`/`WM_MOVE`
///    events during drag/resize (~60fps = ~16ms per event) into a single
///    write, avoiding excessive SharedPreferences I/O.
///
/// 2. **Write lock**: When a save is in-flight and new data arrives, only
///    the latest values are kept (not queued). This "latest wins" strategy
///    is correct because window geometry is a last-write-wins scenario —
///    intermediate positions during drag are never worth persisting.
///
/// Fullscreen state changes bypass debounce since they are discrete events.
class WindowPersistence {
  // 150ms 防抖 — 略大于 16ms 帧间隔，确保拖拽/resize 期间只触发一次保存
  WindowPersistence({this.debounceMs = 150});

  final int debounceMs;

  Timer? _debounce;
  Future<void>? _inFlight;
  Future<void> Function()? _pendingAction;

  /// 保存窗口几何（防抖 + 写入锁）。
  void saveWindowGeometry({
    required double x,
    required double y,
    required double width,
    required double height,
    required bool isMaximized,
  }) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: debounceMs), () {
      _enqueue(
        () => SettingsStore.saveWindowGeometry(
          x: x,
          y: y,
          width: width,
          height: height,
          isMaximized: isMaximized,
        ),
      );
    });
  }

  /// 保存全屏状态（立即，无防抖）。
  // 全屏切换是离散事件，不需要防抖
  Future<void> saveIsFullscreen(bool value) {
    return _enqueue(() => SettingsStore.saveIsFullscreen(value));
  }

  /// 写入锁：排队执行，上一个未完成时暂存最新闭包。
  // "latest wins" 策略 — 窗口几何是 last-write-wins 场景，
  // 拖拽期间的中间位置不值得持久化，只保存最终位置。
  Future<void> _enqueue(Future<void> Function() action) async {
    if (_inFlight != null) {
      // 覆盖旧的 pending，只保留最新值
      _pendingAction = action;
      return;
    }

    _inFlight = action();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
      if (_pendingAction != null) {
        final next = _pendingAction!;
        _pendingAction = null;
        await _enqueue(next); // 递归执行最新 pending
      }
    }
  }

  /// 取消防抖定时器（测试用）。
  @visibleForTesting
  void cancelDebounce() {
    _debounce?.cancel();
    _debounce = null;
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }
}
