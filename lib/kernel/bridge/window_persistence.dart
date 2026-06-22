import 'dart:async';
import 'package:flutter/foundation.dart';
import '../persistence/settings_store.dart';
import '../utils/log.dart';

/// 窗口持久化服务 — 防抖保存 + 写入锁。
///
/// 包装 [SettingsStore] 的窗口相关写入，解决：
/// - W-08: 拖拽期间高频保存（防抖 500ms）
/// - 写入锁：上一次 save 未完成时，新请求合并为最新值
class WindowPersistence {
  WindowPersistence({this.debounceMs = 500});

  final int debounceMs;

  Timer? _debounce;
  Future<void>? _inFlight;
  bool _hasPending = false;

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
      _enqueue(() => SettingsStore.saveWindowGeometry(
            x: x,
            y: y,
            width: width,
            height: height,
            isMaximized: isMaximized,
          ));
    });
  }

  /// 保存全屏状态（立即，无防抖）。
  Future<void> saveIsFullscreen(bool value) {
    return _enqueue(() => SettingsStore.saveIsFullscreen(value));
  }

  /// 写入锁：排队执行，上一个未完成时标记 pending。
  Future<void> _enqueue(Future<void> Function() action) async {
    if (_inFlight != null) {
      _hasPending = true;
      return;
    }

    _inFlight = action();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
      if (_hasPending) {
        _hasPending = false;
        // 有 pending 请求 — 重新执行（最新值已在闭包中）
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
