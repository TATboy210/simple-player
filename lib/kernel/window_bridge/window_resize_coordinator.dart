import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../bridge/win32/sizemove_bridge.dart'
    show SizemoveProbe, SizemoveSnapshot;
import '../diagnostics/kernel_logger.dart';
import 'window_constants.dart';
import 'window_service_state.dart';
import 'window_ui_thread.dart';

/// 将原生 resize 回调收敛为防抖后的窗口状态更新。
final class WindowResizeCoordinator {
  /// 创建 resize 协调器。
  ///
  /// [sizemoveProbe] 为 v0.0.9 P0-1 取证接线（WM_ENTERSIZEMOVE/
  /// WM_EXITSIZEMOVE 原生模态循环观测，纯记录不改行为）；null 时
  /// 行为与旧版逐字节等价，全部既有调用与测试无需适配。
  WindowResizeCoordinator({
    required this._state,
    required this._readSize,
    required this._persistSize,
    this._logger,
    this._sizemoveProbe,
  });

  static const _debounce = Duration(milliseconds: 500);

  final WindowServiceState _state;
  final Future<Size> Function() _readSize;
  final Future<void> Function(Size size) _persistSize;
  final KernelLogger? _logger;
  final SizemoveProbe? _sizemoveProbe;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// 会话首个 resize 事件时的原生模态循环状态 — 预期 true；false 说明
  /// WM_SIZE 平台转发早于 ENTERSIZEMOVE 被 Dart 感知，本身即是时序证据。
  bool? _sessionStartNativeActive;

  /// 接收 resize 事件并启动或刷新当前会话的防抖计时器。
  void onResize() {
    if (_disposed) return;
    _timer?.cancel();
    final generation = ++_generation;
    if (!_state.isResizing.value) {
      _state.resizeSessionId.value++;
      // 仅会话首个事件查询一次 — 避免 resize 风暴期跨线程消息放大。
      _sessionStartNativeActive = _querySizemove('session-start')?.isActive;
    }
    _state.isResizing.value = true;
    _timer = Timer(_debounce, () => unawaited(_settle(generation)));
  }

  /// 关键证据点 — debounce 到点时原生模态循环是否仍在进行。
  ///
  /// true = settle 误判结束（拖拽中途停手 >500ms），isResizing/降级链
  /// 提前恢复；false 且 exitLagMs 即 debounce 相对真实 session 终点的滞后。
  Future<void> _settle(int generation) async {
    if (!_isCurrent(generation)) return;
    final settleSnapshot = _querySizemove('settle');
    _logSizemoveSession(settleSnapshot);
    // 全屏进入/退出触发的 resize 是过渡而非用户意图:跳过 windowSize 更新与
    // 持久化,避免把显示器尺寸写进偏好导致下次启动恢复成巨窗。isResizing
    // 仍须清除(filterQuality 降级依赖它恢复)。
    if (_state.mode.value.isFullscreen) {
      updateOnUIThread(
        () {
          if (_isCurrent(generation)) _state.isResizing.value = false;
        },
        warn: (error, stackTrace) => _loggerOrFallback.w(
          '[WindowResizeCoordinator._settle] $error\n$stackTrace',
        ),
      );
      return;
    }
    Size? size;
    try {
      size = await _readSize();
    } on Exception catch (error, stackTrace) {
      (_logger ?? KernelLogger.I).error(
        '[WindowResizeCoordinator._settle] $error\n$stackTrace',
      );
    }
    if (!_isCurrent(generation)) return;
    updateOnUIThread(
      () {
        if (!_isCurrent(generation)) return;
        if (size != null && size != _state.windowSize.value) {
          _state.windowSize.value = Size(
            math.max(size.width, minimumWindowSize.width),
            math.max(size.height, minimumWindowSize.height),
          );
        }
        _state.isResizing.value = false;
        unawaited(_persistSafely(_state.windowSize.value));
      },
      warn: (error, stackTrace) => _loggerOrFallback.w(
        '[WindowResizeCoordinator._updateOnUIThread] $error\n$stackTrace',
      ),
    );
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  /// 查询原生 SIZEMOVE 模态循环状态 — probe 未接线或查询失败均返回 null。
  SizemoveSnapshot? _querySizemove(String point) {
    final probe = _sizemoveProbe;
    if (probe == null) return null;
    try {
      return probe.query();
    } on Exception catch (error) {
      _loggerOrFallback.w(
        '[WindowResizeCoordinator] sizemove-probe $point failed: $error',
      );
      return null;
    }
  }

  /// 输出会话级取证汇总 — 每 resize 会话一条结构化日志（probe 接线时）。
  void _logSizemoveSession(SizemoveSnapshot? settleSnapshot) {
    if (_sizemoveProbe == null || settleSnapshot == null) return;
    _loggerOrFallback.i(
      '[WindowResizeCoordinator] sizemove-probe',
      context: <String, Object?>{
        'sessionId': _state.resizeSessionId.value,
        'sessionStartNativeActive': _sessionStartNativeActive,
        'settleWhileNativeActive': settleSnapshot.isActive,
        'exitLagMs': settleSnapshot.exitLagMs,
        'enterTick': settleSnapshot.enterTick,
      },
    );
  }

  Future<void> _persistSafely(Size size) async {
    try {
      await _persistSize(size);
    } on Object catch (error, stackTrace) {
      _loggerOrFallback.w(
        '[WindowResizeCoordinator._persistSize] $error\n$stackTrace',
      );
    }
  }

  KernelLogger get _loggerOrFallback => _logger ?? KernelLogger.I;

  /// 取消未完成的防抖任务并使异步回调失效。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _timer = null;
  }
}
