/// resize 期间帧时序诊断与纯统计归约。
///
/// Debug/Profile 模式监听 resize 会话并采集 [FrameTiming]；Release 默认禁用，
/// 不注册 listener 或 timings callback。统计层与 Flutter 帧对象解耦，便于用整数
/// 微秒稳定比较 build/raster/totalSpan 的尾部延迟。
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'kernel_logger.dart';

/// 单帧 resize 时序样本，单位统一为微秒。
@immutable
final class ResizeFrameSample {
  /// 创建不可变的帧时序快照。
  const ResizeFrameSample({
    required this.buildUs,
    required this.rasterUs,
    required this.totalSpanUs,
  });

  /// Flutter build 阶段耗时。
  final int buildUs;

  /// Flutter raster 阶段耗时。
  final int rasterUs;

  /// 从帧开始到结束的总跨度，包含流水线等待。
  final int totalSpanUs;
}

/// 某一时序维度的聚合统计，单位为微秒。
@immutable
final class ResizeTimingSummary {
  /// 创建聚合结果。
  const ResizeTimingSummary({
    required this.avgUs,
    required this.p50Us,
    required this.p95Us,
    required this.p99Us,
    required this.maxUs,
  });

  /// 空样本使用的零值结果。
  const ResizeTimingSummary.zero()
    : avgUs = 0,
      p50Us = 0,
      p95Us = 0,
      p99Us = 0,
      maxUs = 0;

  final int avgUs;
  final int p50Us;
  final int p95Us;
  final int p99Us;
  final int maxUs;

  @override
  bool operator ==(Object other) =>
      other is ResizeTimingSummary &&
      avgUs == other.avgUs &&
      p50Us == other.p50Us &&
      p95Us == other.p95Us &&
      p99Us == other.p99Us &&
      maxUs == other.maxUs;

  @override
  int get hashCode => Object.hash(avgUs, p50Us, p95Us, p99Us, maxUs);
}

/// 一次 resize `drag+settle` 会话的完整摘要。
@immutable
final class ResizeFrameSummary {
  /// 创建不可变的会话摘要。
  const ResizeFrameSummary({
    required this.sampleCount,
    required this.build,
    required this.raster,
    required this.totalSpan,
    required this.jank60Count,
    required this.jank30Count,
  });

  /// 结构化日志固定字段；修改字段时测试会显式提示 schema 变化。
  static const Set<String> contextKeys = {
    'schemaVersion',
    'sessionId',
    'sessionKind',
    'sampleCount',
    'buildAvgUs',
    'buildP50Us',
    'buildP95Us',
    'buildP99Us',
    'buildMaxUs',
    'rasterAvgUs',
    'rasterP50Us',
    'rasterP95Us',
    'rasterP99Us',
    'rasterMaxUs',
    'totalAvgUs',
    'totalP50Us',
    'totalP95Us',
    'totalP99Us',
    'totalMaxUs',
    'jank60Count',
    'jank60Ratio',
    'jank30Count',
    'jank30Ratio',
  };

  final int sampleCount;
  final ResizeTimingSummary build;
  final ResizeTimingSummary raster;
  final ResizeTimingSummary totalSpan;
  final int jank60Count;
  final int jank30Count;

  double get jank60Ratio => sampleCount == 0 ? 0 : jank60Count / sampleCount;

  double get jank30Ratio => sampleCount == 0 ? 0 : jank30Count / sampleCount;

  /// 转为稳定的 machine-readable 日志字段。
  Map<String, Object?> toContext({required int sessionId}) => {
    'schemaVersion': 1,
    'sessionId': sessionId,
    'sessionKind': 'drag+settle',
    'sampleCount': sampleCount,
    'buildAvgUs': build.avgUs,
    'buildP50Us': build.p50Us,
    'buildP95Us': build.p95Us,
    'buildP99Us': build.p99Us,
    'buildMaxUs': build.maxUs,
    'rasterAvgUs': raster.avgUs,
    'rasterP50Us': raster.p50Us,
    'rasterP95Us': raster.p95Us,
    'rasterP99Us': raster.p99Us,
    'rasterMaxUs': raster.maxUs,
    'totalAvgUs': totalSpan.avgUs,
    'totalP50Us': totalSpan.p50Us,
    'totalP95Us': totalSpan.p95Us,
    'totalP99Us': totalSpan.p99Us,
    'totalMaxUs': totalSpan.maxUs,
    'jank60Count': jank60Count,
    'jank60Ratio': jank60Ratio,
    'jank30Count': jank30Count,
    'jank30Ratio': jank30Ratio,
  };
}

/// 将无序帧样本归约为可比较的 resize 指标摘要。
abstract final class ResizeFrameMetricsReducer {
  /// 60fps 的整数微秒预算；恰好等于预算不记为 jank。
  static const int frameBudget60Us = 16667;

  /// 30fps 的整数微秒预算；恰好等于预算不记为 jank。
  static const int frameBudget30Us = 33333;

  /// 使用 nearest-rank 计算 P50/P95/P99，并统计严格超预算的帧。
  static ResizeFrameSummary reduce(Iterable<ResizeFrameSample> samples) {
    final snapshot = List<ResizeFrameSample>.unmodifiable(samples);
    if (snapshot.isEmpty) {
      return const ResizeFrameSummary(
        sampleCount: 0,
        build: ResizeTimingSummary.zero(),
        raster: ResizeTimingSummary.zero(),
        totalSpan: ResizeTimingSummary.zero(),
        jank60Count: 0,
        jank30Count: 0,
      );
    }

    final builds = snapshot.map((sample) => sample.buildUs).toList()..sort();
    final rasters = snapshot.map((sample) => sample.rasterUs).toList()..sort();
    final totals = snapshot.map((sample) => sample.totalSpanUs).toList()
      ..sort();

    return ResizeFrameSummary(
      sampleCount: snapshot.length,
      build: _summarize(builds),
      raster: _summarize(rasters),
      totalSpan: _summarize(totals),
      jank60Count: totals.where((us) => us > frameBudget60Us).length,
      jank30Count: totals.where((us) => us > frameBudget30Us).length,
    );
  }

  static ResizeTimingSummary _summarize(List<int> sortedUs) =>
      ResizeTimingSummary(
        avgUs: _average(sortedUs),
        p50Us: _nearestRank(sortedUs, 50),
        p95Us: _nearestRank(sortedUs, 95),
        p99Us: _nearestRank(sortedUs, 99),
        maxUs: sortedUs.last,
      );

  static int _average(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum += value;
    }
    return sum ~/ values.length;
  }

  static int _nearestRank(List<int> sortedUs, int percentile) {
    // nearest-rank 是 1-based；减一后限制在合法下标，兼容单样本。
    final rank = (percentile * sortedUs.length / 100).ceil();
    final index = math.max(0, rank - 1);
    return sortedUs[index];
  }
}

/// 会话式 resize 帧时序诊断器。
///
/// 默认在 Debug/Profile 启用、Release 禁用；[enabled] 可注入以验证生命周期。
final class ResizeFrameMetrics {
  /// 绑定 resize 状态，并在构造时同步当前值以避免漏掉已开始的会话。
  ResizeFrameMetrics({
    required ValueListenable<bool> isResizing,
    required ValueListenable<int> resizeSessionId,
    KernelLogger? logger,
    bool enabled = !kReleaseMode,
  }) : _isResizing = isResizing,
       _resizeSessionId = resizeSessionId,
       _logger = logger,
       _enabled = enabled {
    if (_enabled) {
      _isResizing.addListener(_onResizingChanged);
      _onResizingChanged();
    }
  }

  final ValueListenable<bool> _isResizing;
  final ValueListenable<int> _resizeSessionId;
  final KernelLogger? _logger;
  final bool _enabled;
  final List<ResizeFrameSample> _samples = [];

  bool _sessionActive = false;
  bool _disposed = false;
  int _sessionId = 0;

  void _onResizingChanged() {
    if (_disposed || !_enabled) return;
    if (_isResizing.value) {
      if (!_sessionActive) _startSession();
      return;
    }
    if (_sessionActive) _endSession();
  }

  void _startSession() {
    // 在收到上升沿时冻结 ID，避免下一会话开始后污染本次摘要归属。
    _sessionId = _resizeSessionId.value;
    _sessionActive = true;
    _samples.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_disposed || !_sessionActive) return;
    _samples.addAll(
      timings.map(
        (timing) => ResizeFrameSample(
          buildUs: timing.buildDuration.inMicroseconds,
          rasterUs: timing.rasterDuration.inMicroseconds,
          totalSpanUs: timing.totalSpan.inMicroseconds,
        ),
      ),
    );
  }

  /// 向活跃会话注入确定性样本，仅供回归测试避免依赖 Flutter 帧调度时序。
  ///
  /// 生产采集始终经由 [_onTimings] 转换 [FrameTiming]；此 seam 保留相同的
  /// disposed/active 会话边界，因此测试不会绕过实际生命周期语义。
  @visibleForTesting
  void recordSamplesForTesting(Iterable<ResizeFrameSample> samples) {
    if (_disposed || !_sessionActive) return;
    _samples.addAll(samples);
  }

  void _endSession() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _sessionActive = false;
    final summary = ResizeFrameMetricsReducer.reduce(_samples);
    // 先清除旧会话样本，再调用可重入的外部 logger；若日志 sink 同步开启下一次
    // resize，旧收尾不能在返回后清掉新会话已采集的帧。
    _samples.clear();
    (_logger ?? KernelLogger.I).info(
      'resize_frame_metrics',
      context: summary.toContext(sessionId: _sessionId),
    );
  }

  /// 移除 timings callback 与 resize listener；重复调用安全。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_enabled) {
      if (_sessionActive) {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      }
      _isResizing.removeListener(_onResizingChanged);
    }
    _sessionActive = false;
    _samples.clear();
  }
}
