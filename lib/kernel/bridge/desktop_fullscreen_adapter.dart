import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/fullscreen_capability.dart';
import 'fullscreen_driver.dart';

/// Desktop 平台全屏适配器 — v3 简化版。
///
/// 直接调用 driver，不经过命令队列。
/// 状态用 ValueNotifier&lt;bool&gt; 表示，替代复杂的 FullscreenSnapshot。
///
/// 设计约束:
/// - ⛔ P0-3: 禁止直调 windowManager/fullScreenWindow，所有原生操作通过 _driver 转发
/// - P0-4: 不持有 WindowBridge 引用，状态查询全由 driver 直接调原生 API
/// - 保留三级确认链、恢复策略、快速路径
class DesktopFullscreenAdapter {
  /// 创建 DesktopFullscreenAdapter。
  ///
  /// [driver] 平台全屏驱动，负责原生调用。
  /// 构造时自动将 driver 的原生回调转发到确认信号 (D-P11)。
  DesktopFullscreenAdapter(this._driver) {
    // D-P11: 将 driver 的原生回调转发到 Adapter 的确认信号
    _driver.onNativeStateChanged = onNativeFullScreenChanged;
  }

  /// 平台驱动 — 所有原生操作通过此接口转发 (P0-3)。
  final FullscreenDriver _driver;

  /// 全屏状态 — 替代旧的 Map&lt;int, ValueNotifier&lt;FullscreenSnapshot&gt;&gt;。
  final ValueNotifier<bool> _isFullscreen = ValueNotifier(false);

  /// 全屏状态 getter — WindowService 监听此 notifier。
  ValueNotifier<bool> get isFullscreen => _isFullscreen;

  /// 当前全屏状态的便捷访问。
  bool get _currentFullscreen => _isFullscreen.value;

  /// 退出全屏前的窗口几何快照 — 用于恢复 (D-22)。
  final Map<int, _RestoreSnapshot> _restoreSnapshots = {};

  /// per-windowId 回调确认信号 (P0-1)。
  final Map<int, _PendingConfirmation> _confirmByWindowId = {};

  /// 单调递增的请求 ID — 防止迟到回调错误确认后续操作。
  int _nextRequestId = 0;

  /// 已 dispose 标志。
  bool _disposed = false;

  // ─── 能力查询 ───

  /// 查询当前平台的全屏能力。
  Future<FullscreenCapability> capabilities() async {
    return _driver.capabilities();
  }

  // ─── 命令 ───

  /// 设置全屏状态。
  ///
  /// [fullscreen] true 进入全屏，false 退出全屏。
  /// 直接调用 _handleEnter/_handleLeave，不经过命令队列。
  Future<void> setFullscreen(bool fullscreen, {int windowId = 0}) async {
    if (_disposed) return;
    if (fullscreen) {
      await _handleEnter(windowId);
    } else {
      await _handleLeave(windowId);
    }
  }

  /// 切换全屏状态。
  Future<void> toggle({int windowId = 0}) async {
    if (_disposed) return;
    if (_currentFullscreen) {
      await _handleLeave(windowId);
    } else {
      await _handleEnter(windowId);
    }
  }

  // ─── Lifecycle ───

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _driver.onNativeStateChanged = null;
    _driver.dispose();
    _isFullscreen.dispose();
    _restoreSnapshots.clear();
    for (final pending in _confirmByWindowId.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(false);
      }
    }
    _confirmByWindowId.clear();
  }

  // ─── 原生回调入口 ───

  /// WindowListener 回调入口 — 由 WindowService 转发。
  ///
  /// P0-1: 按 windowId 隔离确认信号，只完成对应窗口的 Completer。
  void onNativeFullScreenChanged(int windowId, bool isFullscreen) {
    if (_disposed) return;
    final pending = _confirmByWindowId[windowId];
    if (pending != null) {
      // requestId 匹配才确认 — 拒绝迟到的旧回调 (P1-1)
      if (pending.expectedFullscreen == isFullscreen &&
          pending.requestId == _nextRequestId - 1) {
        _confirmByWindowId.remove(windowId);
        if (!pending.completer.isCompleted) {
          pending.completer.complete(true);
        }
      }
      return;
    }

    // 无 pending 确认 — 外部强制变更，直接更新状态
    _isFullscreen.value = isFullscreen;
  }

  // ─── 内部实现 ───

  /// 处理进入全屏命令。
  Future<bool> _handleEnter(int windowId) async {
    // D-22: 调用原生前快照（仅非全屏→全屏时采集）
    if (!_currentFullscreen) {
      await _captureRestoreSnapshot(windowId);
    }

    try {
      // D-25: minimized 状态下先 restore 再全屏
      if (await _driver.isMinimized()) {
        await _driver.restore();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // PERF-01/02: 快速路径 — 跳过确认链
      if (_driver.supportsFastPath) {
        await _driver.enterFullscreenFast(displayId: 0);
        _isFullscreen.value = true;
        return true;
      }

      // 先注册 waiter，避免原生调用同步发出回调时丢失确认。
      _registerConfirmation(windowId, true);
      await _driver.enterFullscreen(displayId: 0);

      // D-19: 三级状态回读
      final confirmed = await _waitForConfirmation(windowId, true);

      if (confirmed) {
        _isFullscreen.value = true;
        return true;
      } else {
        // D-20: StateDesync — 查询真实状态
        await _applyDesync(windowId);
        return false;
      }
    } on Exception catch (e) {
      debugPrint('[DesktopFullscreenAdapter] enter failed: $e');
      _isFullscreen.value = false;
      return false;
    }
  }

  /// 处理退出全屏命令。
  Future<bool> _handleLeave(int windowId) async {
    try {
      // PERF-01/02: 快速路径 — 跳过确认链
      if (_driver.supportsFastPath) {
        await _driver.leaveFullscreenFast();
        // D-22~D-25: 恢复策略仍需执行
        await _restoreFromSnapshot(windowId);
        _isFullscreen.value = false;
        return true;
      }

      // 先注册 waiter，避免原生调用同步发出回调时丢失确认。
      _registerConfirmation(windowId, false);
      await _driver.leaveFullscreen();

      // D-19: 三级状态回读
      final confirmed = await _waitForConfirmation(windowId, false);

      if (confirmed) {
        // D-22~D-25: 恢复策略
        await _restoreFromSnapshot(windowId);
        _isFullscreen.value = false;
        return true;
      } else {
        // D-20: StateDesync
        await _applyDesync(windowId);
        return false;
      }
    } on Exception catch (e) {
      debugPrint('[DesktopFullscreenAdapter] leave failed: $e');
      return false;
    }
  }

  /// 应用 StateDesync — 查询真实状态并更新 (D-20)。
  Future<void> _applyDesync(int windowId) async {
    final actualFullscreen = await _driver.queryFullscreen();
    debugPrint('[DesktopFullscreenAdapter] desync detected, correcting to $actualFullscreen');
    _isFullscreen.value = actualFullscreen;
  }

  /// 捕获恢复快照 (D-22, P0-4 修正版)。
  Future<void> _captureRestoreSnapshot(int windowId) async {
    final snapshot = await _driver.captureSnapshot();
    _restoreSnapshots[windowId] = _RestoreSnapshot(
      position: snapshot.position,
      size: snapshot.size,
      isMaximized: snapshot.isMaximized,
    );
  }

  /// 从快照恢复窗口 (D-22~D-25)。
  Future<void> _restoreFromSnapshot(int windowId) async {
    final snapshot = _restoreSnapshots.remove(windowId);
    if (snapshot == null) return;

    // D-23: maximized 恢复采用调用 maximize()
    if (snapshot.isMaximized) {
      await _driver.maximize();
      return;
    }

    // D-24: 副屏恢复采用 setBounds 恢复
    if (snapshot.position != Offset.zero || snapshot.size != Size.zero) {
      try {
        await _driver.setBounds(snapshot.position, snapshot.size);
      } on Exception catch (_) {
        // 降级: 副屏不可用时 center
        await _driver.setBounds(null, snapshot.size);
      }
    }
  }

  /// 三级状态确认 (D-19, P0-1/P0-2 修正版)。
  ///
  /// Level 1: 等待原生回调确认（主路径，500ms 超时）
  /// Level 2: 短轮询（100ms 间隔，最多 20 次 = 2s）
  /// Level 3: 超时，返回 false
  Future<bool> _waitForConfirmation(
    int windowId,
    bool expectedFullscreen,
  ) async {
    final pending = _confirmByWindowId[windowId];
    if (pending == null ||
        pending.expectedFullscreen != expectedFullscreen) {
      _registerConfirmation(windowId, expectedFullscreen);
    }

    try {
      final waiter = _confirmByWindowId[windowId];
      if (waiter == null) {
        return false;
      }
      final confirmed = await waiter.completer.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (confirmed) return true;
    } finally {
      _confirmByWindowId.remove(windowId);
    }

    // Level 2: 短轮询（100ms 间隔，最多 20 次 = 2s）
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final actual = await _driver.queryFullscreen();
      if (actual == expectedFullscreen) return true;
    }

    // Level 3: 超时
    return false;
  }

  void _registerConfirmation(int windowId, bool expectedFullscreen) {
    _confirmByWindowId[windowId] = _PendingConfirmation(
      expectedFullscreen: expectedFullscreen,
      completer: Completer<bool>(),
      requestId: _nextRequestId++,
    );
  }
}

final class _PendingConfirmation {
  const _PendingConfirmation({
    required this.expectedFullscreen,
    required this.completer,
    required this.requestId,
  });

  final bool expectedFullscreen;
  final Completer<bool> completer;
  final int requestId;
}

/// 退出全屏前的窗口快照 — 用于恢复策略 (D-22)。
final class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.position,
    required this.size,
    this.isMaximized = false,
  });

  /// 全屏前的窗口位置。
  final Offset position;

  /// 全屏前的窗口尺寸。
  final Size size;

  /// 全屏前是否最大化 (D-23)。
  final bool isMaximized;
}
