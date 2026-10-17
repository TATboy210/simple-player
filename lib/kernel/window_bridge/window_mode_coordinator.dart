// ignore_for_file: prefer-async-await, avoid-passing-async-when-sync-expected
import 'dart:async';

import 'window_bridge.dart';
import 'window_service_state.dart';

/// 串行协调普通窗口、最大化和原生全屏语义。
///
/// 全屏由本协调器经注入的 [_enterFullscreen]/[_exitFullscreen] 执行
/// (Windows: Win32FullscreenBridge; 其余平台: window_frame_kit 的 windowManager)。
final class WindowModeCoordinator {
  WindowModeCoordinator({
    required this._state,
    required this._maximize,
    required this._unmaximize,
    required this._waitForInitialization,
    required this._log,
    Future<void> Function()? enterFullscreen,
    Future<void> Function()? exitFullscreen,
  }) : _enterFullscreen = enterFullscreen ?? _noop,
       _exitFullscreen = exitFullscreen ?? _noop;

  static Future<void> _noop() async {}

  final WindowServiceState _state;
  final Future<void> Function() _maximize;
  final Future<void> Function() _unmaximize;
  final Future<void> Function() _waitForInitialization;
  final void Function(String) _log;
  final Future<void> Function() _enterFullscreen;
  final Future<void> Function() _exitFullscreen;
  Future<void> _operation = Future<void>.value();
  int _generation = 0;
  bool _fullscreenIntent = false;
  bool _disposed = false;

  bool get fullscreenIntent => _fullscreenIntent;

  Future<void> waitForOperations() => _operation;

  /// 将其他窗口命令加入同一串行队列，避免模式与置顶操作交错。
  Future<void> enqueue(Future<void> Function() operation) {
    final queued = _operation.then((_) => operation());
    _operation = queued.catchError((Object error, StackTrace stackTrace) {
      _log('[WindowModeCoordinator.enqueue] $error\n$stackTrace');
    });
    return queued;
  }

  Future<void> setMode(WindowMode target) {
    final operation = _operation.then((_) => _setSerialized(target));
    _operation = operation.catchError((Object error, StackTrace stackTrace) {
      _log('[WindowModeCoordinator.setMode] $error\n$stackTrace');
    });
    return operation;
  }

  /// 原生全屏调用隔离 — 平台不支持 (MissingPluginException) 或窗口管理器
  /// 拒绝 (PlatformException) 时只记录, 模式状态保持已提交的意图: 全屏
  /// 失败不得让 setMode 抛出、更不得卡住后续串行模式切换.
  Future<void> _runNativeFullscreen(
    Future<void> Function() call,
    String phase,
  ) async {
    try {
      await call();
    } on Exception catch (error, stackTrace) {
      _log(
        '[WindowModeCoordinator] native fullscreen $phase failed: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _setSerialized(WindowMode target) async {
    if (target == WindowMode.fullscreen) {
      // 先提交意图+模式 (onNativeMaximize 依赖意图把原生铺满映射回全屏),
      // 再执行原生全屏.
      if (_state.mode.value == WindowMode.fullscreen) return;
      syncFullscreenState(true);
      await _runNativeFullscreen(_enterFullscreen, 'enter');
      return;
    }
    await _waitForInitialization();
    if (_disposed || target == _state.mode.value) return;
    final generation = ++_generation;
    final previous = _state.mode.value;
    _log('setMode($target) <- $previous');
    _fullscreenIntent = false;
    _commit(generation, target);
    if (previous == WindowMode.fullscreen) {
      await _runNativeFullscreen(_exitFullscreen, 'exit');
    }
    if (target == WindowMode.maximized) {
      await _maximize();
    } else if (previous == WindowMode.maximized) {
      await _unmaximize();
    }
  }

  void syncFullscreenState(bool isFullscreen) {
    if (_disposed) return;
    final target = isFullscreen
        ? WindowMode.fullscreen
        : (_state.mode.value == WindowMode.fullscreen
              ? WindowMode.windowed
              : _state.mode.value);
    if (target == _state.mode.value) return;
    _fullscreenIntent = isFullscreen;
    _commit(++_generation, target);
  }

  void onNativeMaximize() {
    if (_disposed) return;
    if (_fullscreenIntent || _state.mode.value == WindowMode.fullscreen) {
      _commit(++_generation, WindowMode.fullscreen);
    } else {
      _commit(++_generation, WindowMode.maximized);
    }
  }

  void onNativeUnmaximize() {
    if (_disposed || _fullscreenIntent) return;
    if (_state.mode.value == WindowMode.maximized) {
      _commit(++_generation, WindowMode.windowed);
    }
  }

  void _commit(int generation, WindowMode mode) {
    if (_disposed || generation != _generation) return;
    _state.mode.value = mode;
  }

  void dispose() {
    _disposed = true;
    ++_generation;
  }
}
