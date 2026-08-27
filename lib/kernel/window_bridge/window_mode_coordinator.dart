import 'dart:async';

import 'window_bridge.dart';
import 'window_service_state.dart';

/// 串行协调普通窗口、最大化和 media_kit 全屏语义。
final class WindowModeCoordinator {
  WindowModeCoordinator({
    required WindowServiceState state,
    required Future<void> Function() maximize,
    required Future<void> Function() unmaximize,
    required Future<void> Function() waitForInitialization,
    required void Function(String message) log,
  }) : _state = state,
       _maximize = maximize,
       _unmaximize = unmaximize,
       _waitForInitialization = waitForInitialization,
       _log = log;

  final WindowServiceState _state;
  final Future<void> Function() _maximize;
  final Future<void> Function() _unmaximize;
  final Future<void> Function() _waitForInitialization;
  final void Function(String) _log;
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

  Future<void> _setSerialized(WindowMode target) async {
    if (target == WindowMode.fullscreen) {
      syncFullscreenState(true);
      return;
    }
    await _waitForInitialization();
    if (_disposed || target == _state.mode.value) return;
    final generation = ++_generation;
    final previous = _state.mode.value;
    _log('setMode($target) <- $previous');
    _fullscreenIntent = false;
    _commit(generation, target);
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
