import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 性能监控工具 — 记录 build/raster 耗时
///
/// 使用固定容量环形缓冲区（_maxFrames=300），避免无界列表内存泄漏。
/// 每 100 帧输出一次统计，不主动清空缓冲区（环形覆盖最旧数据）。
class PerfMonitor {
  static final PerfMonitor _instance = PerfMonitor._();
  static PerfMonitor get instance => _instance;

  PerfMonitor._();

  /// 环形缓冲区最大容量
  static const _maxFrames = 300;

  bool _enabled = false;
  final _buildTimes = List<Duration?>.filled(_maxFrames, null);
  final _rasterTimes = List<Duration?>.filled(_maxFrames, null);
  int _writeIndex = 0;
  int _totalFrames = 0;

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

      // 环形缓冲区写入 — 覆盖最旧数据
      final idx = _writeIndex % _maxFrames;
      _buildTimes[idx] = buildDuration;
      _rasterTimes[idx] = rasterDuration;
      _writeIndex++;
      _totalFrames++;

      // 记录超过阈值的帧
      // 16ms — 60fps 下一帧的预算时间（1000/60 ≈ 16.67ms），超过即视为慢帧
      if (totalDuration.inMilliseconds > 16) {
        developer.log(
          'Slow frame: ${totalDuration.inMilliseconds}ms '
          '(build: ${buildDuration.inMilliseconds}ms, '
          'raster: ${rasterDuration.inMilliseconds}ms)',
          name: 'Perf',
        );
      }

      // 每 100 帧输出统计，平衡日志频率和信息量
      if (_totalFrames % 100 == 0) {
        _printStats();
      }
    }
  }

  /// 输出统计信息
  void _printStats() {
    final count = _totalFrames < _maxFrames ? _totalFrames : _maxFrames;
    if (count == 0) return;

    var buildSum = 0;
    var rasterSum = 0;
    var maxBuild = 0;
    var maxRaster = 0;

    for (var i = 0; i < count; i++) {
      final bt = _buildTimes[i];
      final rt = _rasterTimes[i];
      if (bt != null) {
        final us = bt.inMicroseconds;
        buildSum += us;
        if (us > maxBuild) maxBuild = us;
      }
      if (rt != null) {
        final us = rt.inMicroseconds;
        rasterSum += us;
        if (us > maxRaster) maxRaster = us;
      }
    }

    // μs → ms 转换因子
    final avgBuild = buildSum / count / 1000;
    final avgRaster = rasterSum / count / 1000;

    developer.log(
      'Stats (last $count frames):\n'
      '  Build:  avg=${avgBuild.toStringAsFixed(2)}ms, max=${maxBuild / 1000}ms\n'
      '  Raster: avg=${avgRaster.toStringAsFixed(2)}ms, max=${maxRaster / 1000}ms',
      name: 'Perf',
    );
  }

  /// 重置全部状态（仅供测试使用）。
  @visibleForTesting
  void reset() {
    _enabled = false;
    for (var i = 0; i < _maxFrames; i++) {
      _buildTimes[i] = null;
      _rasterTimes[i] = null;
    }
    _writeIndex = 0;
    _totalFrames = 0;
  }

  /// 导出统计为 JSON
  Map<String, dynamic> exportStats() {
    final result = <String, dynamic>{};

    final count = _totalFrames < _maxFrames ? _totalFrames : _maxFrames;
    if (count > 0) {
      var buildSum = 0;
      var rasterSum = 0;
      var maxBuild = 0;
      var maxRaster = 0;

      for (var i = 0; i < count; i++) {
        final bt = _buildTimes[i];
        final rt = _rasterTimes[i];
        if (bt != null) {
          final us = bt.inMicroseconds;
          buildSum += us;
          if (us > maxBuild) maxBuild = us;
        }
        if (rt != null) {
          final us = rt.inMicroseconds;
          rasterSum += us;
          if (us > maxRaster) maxRaster = us;
        }
      }

      result['frameCount'] = count;
      result['build'] = {
        'avgMs': buildSum / count / 1000,
        'maxMs': maxBuild / 1000,
      };
      result['raster'] = {
        'avgMs': rasterSum / count / 1000,
        'maxMs': maxRaster / 1000,
      };
    }

    return result;
  }
}
