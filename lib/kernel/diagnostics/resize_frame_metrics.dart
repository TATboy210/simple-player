/// resize 期间帧时序诊断 — 轻量会话切片器 (方向4).
///
/// 监听 [WindowService.state.isResizing]:
/// - 上升沿 (false→true) 注册 [SchedulerBinding.addTimingsCallback],
///   累积 resize 期间每帧的 build/raster 时序;
/// - 下降沿 (true→false) 移除回调并输出摘要
///   (build/raster/totalSpan 的 avg/max + 60fps/30fps 丢帧计数).
///
/// totalSpan = build + raster + 流水线等待. avg/max 揭示是否存在流水线
/// 气泡: build/raster 健康但 totalSpan 大 → 帧在等资源 (如视频纹理上传),
/// 卡顿在 FrameTiming 测不到的管线外.
///
/// 仅 debug 模式生效: [kDebugMode] 门控 — release 构造不注册 listener,
/// 零开销. 生命周期跟随 [WindowService], 由其构造/dispose.
///
/// 限制 (如实记录): resize 卡顿根因在 Flutter engine Windows 纹理合成层
/// (media_kit setSize 触发 D3D11 纹理重建), 本诊断器只能量化卡顿程度,
/// 不能消除 — 用于定位与回归对比.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'kernel_logger.dart';

/// 轻量 resize 帧时序诊断器 — 会话式切片.
///
/// Lightweight resize frame-timing diagnostics — session-sliced.
/// Binds to an [isResizing] [ValueListenable]; collects per-frame
/// [FrameTiming] during resize sessions, logs a summary on completion.
final class ResizeFrameMetrics {
  /// 构造 — 绑定到 [isResizing] 监听器.
  ///
  /// [isResizing] resize 状态信号 (通常 WindowService.state.isResizing).
  /// [logger] 可选日志门面; 省略时摘要输出走 [KernelLogger.I]
  /// (仅在 debug 模式 _logSummary 内访问, 构造零依赖).
  ResizeFrameMetrics({
    required ValueListenable<bool> isResizing,
    KernelLogger? logger,
  }) : _isResizing = isResizing,
       _logger = logger,
       _enabled = kDebugMode {
    // release 构造不注册 listener — 零稳态开销, listener 也被 tree-shake.
    if (_enabled) {
      _isResizing.addListener(_onResizingChanged);
    }
  }

  final ValueListenable<bool> _isResizing;
  final KernelLogger? _logger;
  final bool _enabled;

  bool _sessionActive = false;
  bool _disposed = false;
  final List<FrameTiming> _samples = [];

  /// 60fps 帧预算 (~16.67ms) — totalSpan 超过即记一次 60fps 丢帧.
  static const Duration _frameBudget60 = Duration(
    milliseconds: 16,
    microseconds: 670,
  );

  /// 30fps 帧预算 (~33.33ms) — totalSpan 超过即记一次 30fps 丢帧.
  static const Duration _frameBudget30 = Duration(
    milliseconds: 33,
    microseconds: 333,
  );

  /// isResizing 变化 — 边沿触发会话开/关.
  void _onResizingChanged() {
    if (_disposed || !_enabled) return;
    final resizing = _isResizing.value;
    if (resizing) {
      if (!_sessionActive) _startSession();
    } else {
      if (_sessionActive) _endSession();
    }
  }

  /// 开启 resize 会话 — 注册 timings 回调, 清空样本.
  void _startSession() {
    _sessionActive = true;
    _samples.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// timings 回调 — 累积本会话帧时序样本 (引擎在每帧绘制后调用).
  void _onTimings(List<FrameTiming> timings) {
    if (_disposed || !_sessionActive) return;
    _samples.addAll(timings);
  }

  /// 结束 resize 会话 — 移除回调, 输出摘要, 清空样本.
  void _endSession() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _sessionActive = false;
    _logSummary();
    _samples.clear();
  }

  /// 输出会话摘要 — build/raster avg/max + 60fps/30fps 丢帧计数.
  ///
  /// 无帧数据时 (resize 太快, 引擎未上报 timings) 输出 debug 提示.
  void _logSummary() {
    final logger = _logger ?? KernelLogger.I;
    if (_samples.isEmpty) {
      logger.debug(
        '[ResizeFrameMetrics] resize session ended — no frames captured',
      );
      return;
    }

    final builds = _samples.map((t) => t.buildDuration.inMicroseconds).toList()
      ..sort();
    final rasters =
        _samples.map((t) => t.rasterDuration.inMicroseconds).toList()..sort();
    // totalSpan 含流水线等待 — avg/max 与 build/raster 对比可揭示管线外延迟.
    final spans =
        _samples.map((t) => t.totalSpan.inMicroseconds).toList()..sort();

    final buildAvgUs = _avg(builds);
    final buildMaxUs = builds.last;
    final rasterAvgUs = _avg(rasters);
    final rasterMaxUs = rasters.last;
    final spanAvgUs = _avg(spans);
    final spanMaxUs = spans.last;

    final jank60 = _samples.where((t) => t.totalSpan > _frameBudget60).length;
    final jank30 = _samples.where((t) => t.totalSpan > _frameBudget30).length;

    logger.info(
      '[ResizeFrameMetrics] session: ${_samples.length} frames | '
      'build ${_ms(buildAvgUs)}/${_ms(buildMaxUs)}ms (avg/max) | '
      'raster ${_ms(rasterAvgUs)}/${_ms(rasterMaxUs)}ms (avg/max) | '
      'total ${_ms(spanAvgUs)}/${_ms(spanMaxUs)}ms (avg/max) | '
      'jank $jank60@60fps $jank30@30fps',
    );
  }

  /// 微秒列表求平均 — 空列表返回 0.
  static int _avg(List<int> sortedUs) {
    if (sortedUs.isEmpty) return 0;
    var sum = 0;
    for (final us in sortedUs) {
      sum += us;
    }
    return sum ~/ sortedUs.length;
  }

  /// 微秒 → 毫秒字符串 (1 位小数).
  static String _ms(int us) => (us / 1000).toStringAsFixed(1);

  /// 释放 — 移除 timings 回调与 isResizing listener. 幂等.
  ///
  /// 必须在所监听的 ValueListenable dispose 之前调用,
  /// 否则 removeListener 会触发 "used after being disposed".
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_enabled) {
      // removeTimingsCallback 非幂等: debug 断言 _timingsCallbacks.contains,
      // session 从未 start 时 _onTimings 未注册, 移除会抛. 仅会话进行中才移除.
      if (_sessionActive) {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      }
      _isResizing.removeListener(_onResizingChanged);
    }
    _sessionActive = false;
    _samples.clear();
  }
}
