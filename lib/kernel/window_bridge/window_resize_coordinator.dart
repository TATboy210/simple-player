import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';

import '../diagnostics/kernel_logger.dart';
import 'window_constants.dart';
import 'window_service_state.dart';

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
          math.max(size.width, minimumWindowSize.width),
          math.max(size.height, minimumWindowSize.height),
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
