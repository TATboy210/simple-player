import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/fullscreen_capability.dart';
import '../models/fullscreen_error.dart';
import '../models/fullscreen_event.dart';
import '../models/fullscreen_request.dart';
import '../models/fullscreen_snapshot.dart';
import 'fullscreen_adapter.dart';
import 'fullscreen_command_queue.dart';
import 'fullscreen_driver.dart';
import 'platform/windows_fullscreen_driver.dart';
import 'window_mode.dart';

/// Desktop 平台全屏适配器 — Phase B 核心实现。
///
/// 串联命令队列、状态回读、恢复策略和事件广播。
///
/// 设计约束:
/// - 实现 FullscreenAdapter 抽象接口
/// - ⛔ P0-3: 禁止直调 windowManager/fullScreenWindow，所有原生操作通过 _driver 转发
/// - P0-4: 不持有 WindowBridge 引用，状态查询全由 driver 直接调原生 API
/// - per-window 状态容器 (D-04)
/// - 内部持有 FullscreenCommandQueue (D-15)
/// - 事件流使用 broadcast StreamController (D-06/D-07)
class DesktopFullscreenAdapter implements FullscreenAdapter {
  /// 创建 DesktopFullscreenAdapter。
  ///
  /// [driver] 平台全屏驱动，负责原生调用。
  /// 构造时自动将 driver 的原生回调转发到 Adapter 确认信号 (D-P11)。
  DesktopFullscreenAdapter(this._driver) {
    // D-P11: 将 driver 的原生回调转发到 Adapter 的确认信号
    // macOS: NSWindow delegate → onFullScreenChanged → _confirmByWindowId
    // Linux: GdkWindow state-changed → onFullScreenChanged → _confirmByWindowId
    // Windows: 无需此机制 (FFI 同步操作)
    _driver.onNativeStateChanged = onNativeFullScreenChanged;
  }

  /// 平台驱动 — 所有原生操作通过此接口转发 (P0-3)。
  final FullscreenDriver _driver;

  /// 命令队列 — per-windowId 串行化 (D-15)。
  final FullscreenCommandQueue _queue = FullscreenCommandQueue();

  /// per-window 状态容器 (D-04)。
  final Map<int, ValueNotifier<FullscreenSnapshot>> _snapshots = {};

  /// 事件广播流 (D-06/D-07)。
  final StreamController<FullscreenEvent> _events =
      StreamController<FullscreenEvent>.broadcast();

  /// 退出全屏前的窗口几何快照 — 用于恢复 (D-22)。
  final Map<int, _RestoreSnapshot> _restoreSnapshots = {};

  /// per-windowId 回调确认信号 (P0-1)。
  ///
  /// key = windowId，value = 等待该窗口原生回调确认的 Completer。
  /// 防止多窗口并发时互相覆盖确认信号。
  final Map<int, Completer<bool>> _confirmByWindowId = {};

  /// 已 dispose 标志。
  bool _disposed = false;

  // ─── FullscreenAdapter: 状态查询 ───

  @override
  ValueNotifier<FullscreenSnapshot> snapshot([int windowId = 0]) {
    return _snapshotFor(windowId);
  }

  @override
  Stream<FullscreenEvent> get events => _events.stream;

  // ─── FullscreenAdapter: 能力查询 ───

  @override
  Future<FullscreenCapability> capabilities() async {
    // Phase C: 委托给 driver，每平台返回真实能力
    return _driver.capabilities();
  }

  // ─── FullscreenAdapter: 命令 ───

  @override
  Future<void> setFullscreen(
    bool fullscreen, {
    int windowId = 0,
    FullscreenMode mode = FullscreenMode.borderless,
  }) async {
    if (_disposed) return;

    final notifier = _snapshotFor(windowId);
    final current = notifier.value;

    // D-09: error 状态自动清理为 stable
    if (current.hasError) {
      notifier.value = current.copyWith(
        phase: FullscreenPhase.stable,
        clearError: true,
      );
    }

    // D-12: 正在过渡中 → BusyTransition
    if (notifier.value.isTransitioning) {
      _events.add(FullscreenEvent.error(
        error: FullscreenError.busyTransition(notifier.value.phase),
      ));
      return;
    }

    // 构造请求
    final request = fullscreen
        ? FullscreenRequest.enter(mode: mode, windowId: windowId)
        : FullscreenRequest.leave(windowId: windowId);

    // 入队，executor 回调在队列调度时执行
    await _queue.enqueue(
      request,
      _executeCommand,
      currentFullscreen: notifier.value.isFullscreen,
    );
  }

  @override
  Future<void> toggle({
    int windowId = 0,
    FullscreenMode? preferredMode,
  }) async {
    if (_disposed) return;
    final notifier = _snapshotFor(windowId);
    final request = FullscreenRequest.toggle(
      preferredMode: preferredMode,
      windowId: windowId,
    );
    await _queue.enqueue(
      request,
      _executeCommand,
      currentFullscreen: notifier.value.isFullscreen,
    );
  }

  // ─── FullscreenAdapter: Lifecycle ───

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queue.dispose();
    _events.close();
    for (final notifier in _snapshots.values) {
      notifier.dispose();
    }
    _snapshots.clear();
    _restoreSnapshots.clear();
    _confirmByWindowId.clear();
  }

  // ─── 原生回调入口 ───

  /// WindowListener 回调入口 — 由 WindowService 转发。
  ///
  /// P0-1: 按 windowId 隔离确认信号，只完成对应窗口的 Completer。
  void onNativeFullScreenChanged(int windowId, bool isFullscreen) {
    final completer = _confirmByWindowId.remove(windowId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
  }

  // ─── 内部实现 ───

  /// 获取/创建指定 windowId 的 snapshot notifier (D-04)。
  ValueNotifier<FullscreenSnapshot> _snapshotFor(int windowId) {
    return _snapshots.putIfAbsent(
      windowId,
      () => ValueNotifier(const FullscreenSnapshot()),
    );
  }

  /// 命令队列 executor — 由 FullscreenCommandQueue 调度执行。
  Future<bool> _executeCommand(FullscreenRequest request) async {
    final notifier = _snapshotFor(request.windowId);
    final current = notifier.value;

    if (request is EnterFullscreen) {
      return _handleEnter(request, notifier, current);
    }

    if (request is LeaveFullscreen) {
      return _handleLeave(request, notifier, current);
    }

    // ToggleFullscreen 应在队列中被解析为 Enter/Leave
    return false;
  }

  /// 处理进入全屏命令。
  Future<bool> _handleEnter(
    EnterFullscreen request,
    ValueNotifier<FullscreenSnapshot> notifier,
    FullscreenSnapshot current,
  ) async {
    // D-22: 调用原生前快照（仅非全屏→全屏时采集）
    if (!current.isFullscreen) {
      await _captureRestoreSnapshot(request.windowId);
    }

    // D-16: 命令开始执行时更新 phase
    notifier.value = current.copyWith(phase: FullscreenPhase.entering);
    _events.add(FullscreenEvent.enterRequested(targetMode: request.mode));

    try {
      // D-25: minimized 状态下先 restore 再全屏
      if (await _driver.isMinimized()) {
        await _driver.restore();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // PERF-01/02: Windows 快速路径 — 跳过确认链
      // Windows FFI 同步操作，无需等待原生回调或轮询
      if (_driver is WindowsFullscreenDriver) {
        await _driver.enterFullscreenFast(displayId: 0);
        notifier.value = notifier.value.copyWith(
          phase: FullscreenPhase.stable,
          effectiveMode: request.mode,
        );
        _events.add(FullscreenEvent.entered(finalMode: request.mode));
        return true;
      }

      // macOS/Linux: 标准路径 + 三级确认链
      await _driver.enterFullscreen(displayId: 0);

      // D-19: 三级状态回读
      final confirmed = await _waitForConfirmation(request.windowId, true);

      if (confirmed) {
        notifier.value = notifier.value.copyWith(
          phase: FullscreenPhase.stable,
          effectiveMode: request.mode,
        );
        _events.add(FullscreenEvent.entered(finalMode: request.mode));
        return true;
      } else {
        // D-20: StateDesync — 报错 + 不自动重试 + 更新真实状态
        await _applyDesync(
          notifier,
          expected: request.mode,
          windowId: request.windowId,
        );
        return false;
      }
    } on Exception catch (e) {
      // 平台调用失败
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.error,
        lastError: FullscreenError.platformFailure('$e', e),
      );
      _events.add(FullscreenEvent.error(
        error: FullscreenError.platformFailure('$e', e),
      ));
      return false;
    }
  }

  /// 处理退出全屏命令。
  Future<bool> _handleLeave(
    LeaveFullscreen request,
    ValueNotifier<FullscreenSnapshot> notifier,
    FullscreenSnapshot current,
  ) async {
    notifier.value = current.copyWith(phase: FullscreenPhase.leaving);
    _events.add(FullscreenEvent.leaveRequested());

    try {
      // PERF-01/02: Windows 快速路径 — 跳过确认链
      if (_driver is WindowsFullscreenDriver) {
        await _driver.leaveFullscreenFast();
        // D-22~D-25: 恢复策略仍需执行
        await _restoreFromSnapshot(request.windowId);
        notifier.value = notifier.value.copyWith(
          phase: FullscreenPhase.stable,
          effectiveMode: FullscreenMode.windowed,
          clearError: true,
        );
        _events.add(FullscreenEvent.left());
        return true;
      }

      // macOS/Linux: 标准路径 + 三级确认链
      await _driver.leaveFullscreen();

      // D-19: 三级状态回读
      final confirmed = await _waitForConfirmation(request.windowId, false);

      if (confirmed) {
        // D-22~D-25: 恢复策略
        await _restoreFromSnapshot(request.windowId);
        notifier.value = notifier.value.copyWith(
          phase: FullscreenPhase.stable,
          effectiveMode: FullscreenMode.windowed,
          clearError: true,
        );
        _events.add(FullscreenEvent.left());
        return true;
      } else {
        // D-20: StateDesync
        await _applyDesync(
          notifier,
          expected: FullscreenMode.windowed,
          windowId: request.windowId,
        );
        return false;
      }
    } on Exception catch (e) {
      notifier.value = notifier.value.copyWith(
        phase: FullscreenPhase.error,
        lastError: FullscreenError.platformFailure('$e', e),
      );
      _events.add(FullscreenEvent.error(
        error: FullscreenError.platformFailure('$e', e),
      ));
      return false;
    }
  }

  /// 应用 StateDesync — snapshot 更新为真实状态 + 发出错误事件 (D-20)。
  Future<void> _applyDesync(
    ValueNotifier<FullscreenSnapshot> notifier, {
    required FullscreenMode expected,
    required int windowId,
  }) async {
    final actualFullscreen = await _driver.queryFullscreen();
    final actualMode = actualFullscreen
        ? FullscreenMode.borderless
        : FullscreenMode.windowed;
    notifier.value = notifier.value.copyWith(
      phase: FullscreenPhase.error,
      effectiveMode: actualMode,
      lastError: FullscreenError.stateDesync(
        expected: expected,
        actual: actualMode,
      ),
    );
    _events.add(FullscreenEvent.error(
      error: FullscreenError.stateDesync(
        expected: expected,
        actual: actualMode,
      ),
    ));
  }

  /// 捕获恢复快照 (D-22, P0-4 修正版)。
  ///
  /// 读取 isMaximized/position/size 通过 _driver 直接查询原生 API。
  Future<void> _captureRestoreSnapshot(int windowId) async {
    final maximized = await _driver.isMaximized();
    final position = await _driver.getPosition();
    final size = await _driver.getSize();
    _restoreSnapshots[windowId] = _RestoreSnapshot(
      mode: WindowMode.windowed, // 退出全屏后恢复到 windowed
      position: position,
      size: size,
      isMaximized: maximized,
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
    // Level 1: 等待原生回调确认
    // P0-1: 使用 per-windowId 的 Completer<bool>
    // P0-2: Completer<bool> 可判定成功/超时
    final completer = Completer<bool>();
    _confirmByWindowId[windowId] = completer;

    try {
      final confirmed = await completer.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (confirmed) return true;
    } finally {
      // 防止泄漏：无论成功/超时/异常，都清理
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
}

/// 退出全屏前的窗口快照 — 用于恢复策略 (D-22)。
///
/// 使用 WindowMode + bool isMaximized 而非 FullscreenMode (P1-7)。
final class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.mode,
    required this.position,
    required this.size,
    this.isMaximized = false,
  });

  /// 窗口模式（恢复到 windowed）。
  final WindowMode mode;

  /// 全屏前的窗口位置。
  final Offset position;

  /// 全屏前的窗口尺寸。
  final Size size;

  /// 全屏前是否最大化 (D-23)。
  final bool isMaximized;
}
