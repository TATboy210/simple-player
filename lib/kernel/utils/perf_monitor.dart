import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';

/// 性能监控工具 — 记录 build/raster 耗时
class PerfMonitor {
  static final PerfMonitor _instance = PerfMonitor._();
  static PerfMonitor get instance => _instance;

  PerfMonitor._();

  bool _enabled = false;
  final _buildTimes = <Duration>[];
  final _rasterTimes = <Duration>[];

  /// 启用性能监控
  void enable() {
    if (_enabled) return;
    _enabled = true;

    // 监听帧回调
    SchedulerBinding.instance.addTimingsCallback(_onTimingsCallback);
    developer.log('PerfMonitor enabled', name: 'Perf');
  }

  /// 禁用性能监控
  void disable() {
    _enabled = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimingsCallback);
    developer.log('PerfMonitor disabled', name: 'Perf');
  }

  /// 处理帧计时数据
  void _onTimingsCallback(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildDuration = timing.buildDuration;
      final rasterDuration = timing.rasterDuration;
      final totalDuration = timing.totalSpan;

      _buildTimes.add(buildDuration);
      _rasterTimes.add(rasterDuration);

      // 记录超过阈值的帧
      if (totalDuration.inMilliseconds > 16) {
        developer.log(
          'Slow frame: ${totalDuration.inMilliseconds}ms '
          '(build: ${buildDuration.inMilliseconds}ms, '
          'raster: ${rasterDuration.inMilliseconds}ms)',
          name: 'Perf',
        );
      }

      // 每 100 帧输出统计
      if (_buildTimes.length % 100 == 0) {
        _printStats();
      }
    }
  }

  /// 输出统计信息
  void _printStats() {
    if (_buildTimes.isEmpty) return;

    final avgBuild =
        _buildTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds) /
        _buildTimes.length /
        1000;

    final avgRaster =
        _rasterTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds) /
        _rasterTimes.length /
        1000;

    final maxBuild = _buildTimes
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a > b ? a : b);
    final maxRaster = _rasterTimes
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a > b ? a : b);

    developer.log(
      'Stats (last ${_buildTimes.length} frames):\n'
      '  Build:  avg=${avgBuild.toStringAsFixed(2)}ms, max=${maxBuild / 1000}ms\n'
      '  Raster: avg=${avgRaster.toStringAsFixed(2)}ms, max=${maxRaster / 1000}ms',
      name: 'Perf',
    );

    // 清空历史
    if (_buildTimes.length > 1000) {
      _buildTimes.clear();
      _rasterTimes.clear();
    }
  }

  /// 手动记录标记
  void mark(String label) {
    developer.Timeline.startSync(label);
  }

  /// 结束标记
  void markEnd(String label) {
    developer.Timeline.finishSync();
  }

  /// 导出统计为 JSON
  Map<String, dynamic> exportStats() {
    final result = <String, dynamic>{};

    if (_buildTimes.isNotEmpty) {
      result['frameCount'] = _buildTimes.length;
      result['build'] = {
        'avgMs':
            _buildTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds) /
            _buildTimes.length /
            1000,
        'maxMs':
            _buildTimes
                .map((d) => d.inMicroseconds)
                .reduce((a, b) => a > b ? a : b) /
            1000,
      };
      result['raster'] = {
        'avgMs':
            _rasterTimes.fold<int>(0, (sum, d) => sum + d.inMicroseconds) /
            _rasterTimes.length /
            1000,
        'maxMs':
            _rasterTimes
                .map((d) => d.inMicroseconds)
                .reduce((a, b) => a > b ? a : b) /
            1000,
      };
    }

    return result;
  }
}
