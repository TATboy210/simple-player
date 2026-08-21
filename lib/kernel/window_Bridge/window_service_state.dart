import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../diagnostics/kernel_logger.dart';
import '../persistence/window_persistence.dart';
import 'window_bridge.dart';
import 'window_constants.dart';

/// WindowService 的内部可变状态容器。
final class WindowServiceState {
  /// 创建窗口状态，默认使用稳定的启动尺寸。
  WindowServiceState({Size initialSize = defaultWindowSize})
    : _windowSize = ValueNotifier(initialSize);

  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  final ValueNotifier<Size> _windowSize;
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  bool _disposed = false;
  bool get disposed => _disposed;

  /// 当前窗口尺寸的内部写入端。
  ValueNotifier<Size> get windowSize => _windowSize;

  /// 释放所有 notifier；重复调用安全。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    _windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
  }
}

/// 将原生 resize 回调收敛为防抖后的窗口状态更新。
final class WindowResizeCoordinator {
  /// 创建 resize 协调器。
  WindowResizeCoordinator({
    required WindowServiceState state,
    required Future<Size> Function() readSize,
    required Future<void> Function(Size size) persistSize,
    KernelLogger? logger,
  }) : _state = state,
       _readSize = readSize,
       _persistSize = persistSize,
       _logger = logger;

  static const _debounce = Duration(milliseconds: 500);
  static const _minimumSize = minimumWindowSize;

  final WindowServiceState _state;
  final Future<Size> Function() _readSize;
  final Future<void> Function(Size size) _persistSize;
  final KernelLogger? _logger;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// 接收 resize 事件并启动或刷新当前会话的防抖计时器。
  void onResize() {
    if (_disposed) return;
    _timer?.cancel();
    final generation = ++_generation;
    if (!_state.isResizing.value) _state.resizeSessionId.value++;
    _state.isResizing.value = true;
    _timer = Timer(_debounce, () => unawaited(_settle(generation)));
  }

  Future<void> _settle(int generation) async {
    if (!_isCurrent(generation)) return;
    Size? size;
    try {
      size = await _readSize();
    } on Exception catch (error, stackTrace) {
      (_logger ?? KernelLogger.I).error(
        '[WindowResizeCoordinator._settle] $error\n$stackTrace',
      );
    }
    if (!_isCurrent(generation)) return;
    _updateOnUIThread(() {
      if (!_isCurrent(generation)) return;
      if (size != null && size != _state.windowSize.value) {
        _state.windowSize.value = Size(
          math.max(size.width, _minimumSize.width),
          math.max(size.height, _minimumSize.height),
        );
      }
      _state.isResizing.value = false;
      unawaited(_persistSafely(_state.windowSize.value));
    });
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _persistSafely(Size size) async {
    try {
      await _persistSize(size);
    } on Object catch (error, stackTrace) {
      (_logger ?? KernelLogger.I).w(
        '[WindowResizeCoordinator._persistSize] $error\n$stackTrace',
      );
    }
  }

  void _updateOnUIThread(VoidCallback update) {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        update();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) => update());
      }
    } on Exception catch (error, stackTrace) {
      (_logger ?? KernelLogger.I).w(
        '[WindowResizeCoordinator._updateOnUIThread] $error\n$stackTrace',
      );
      update();
    }
  }

  /// 取消未完成的防抖任务并使异步回调失效。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _timer = null;
  }
}

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

/// 串行保存窗口快照，隔离平台读取和持久化异常。
final class WindowPersistenceCoordinator {
  WindowPersistenceCoordinator({
    required WindowServiceState state,
    required WindowPersistence persistence,
    required Future<Offset> Function() readPosition,
    required void Function(String message, Object error, StackTrace stackTrace)
    log,
  }) : _state = state,
       _persistence = persistence,
       _readPosition = readPosition,
       _log = log;

  final WindowServiceState _state;
  final WindowPersistence _persistence;
  final Future<Offset> Function() _readPosition;
  final void Function(String, Object, StackTrace) _log;
  Future<void> _operation = Future<void>.value();

  /// 保存当前窗口几何；全屏时跳过，避免保存 media_kit route 尺寸。
  Future<void> save({Size? size}) {
    final operation = _operation.then((_) => _saveSerialized(size: size));
    _operation = operation.catchError((Object error, StackTrace stackTrace) {
      _log('[WindowPersistenceCoordinator.save]', error, stackTrace);
    });
    return operation;
  }

  Future<void> _saveSerialized({Size? size}) async {
    if (_state.disposed || _state.mode.value.isFullscreen) return;
    try {
      final position = await _readPosition();
      if (_state.disposed) return;
      await _persistence.save(
        PersistedWindowState(
          size: size ?? _state.windowSize.value,
          position: position,
          alwaysOnTop: _state.isAlwaysOnTop.value,
          isMaximized: _state.mode.value == WindowMode.maximized,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log('[WindowPersistenceCoordinator._saveSerialized]', error, stackTrace);
    }
  }
}
