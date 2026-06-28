import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// ─── 数据类 ───

/// 单次内存采样。
class MetricSample {
  const MetricSample({
    required this.rssBytes,
    required this.timestamp,
  });

  final int rssBytes;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
        'rssBytes': rssBytes,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 内存快照 — 包含当前值、历史、峰值、增长率。
class MemorySnapshot {
  const MemorySnapshot({
    required this.rssBytes,
    required this.maxRssBytes,
    required this.deltaBytes,
    required this.history,
    required this.timestamp,
  });

  final int rssBytes;
  final int maxRssBytes;
  final int deltaBytes;
  final List<MetricSample> history;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
        'rssBytes': rssBytes,
        'maxRssBytes': maxRssBytes,
        'deltaBytes': deltaBytes,
        'rssMB': (rssBytes / (1024 * 1024)).toStringAsFixed(1),
        'maxRssMB': (maxRssBytes / (1024 * 1024)).toStringAsFixed(1),
        'historyCount': history.length,
        'history': history.map((s) => s.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─── 监控器 ───

/// 周期性内存监控 — 仅 debug 构建生效。
///
/// 读取 [ProcessInfo.currentRss]，维护采样历史，提供快照和 JSON 导出。
///
/// 用法：
/// ```dart
/// MemoryMonitor.start(interval: Duration(seconds: 10));
/// // 获取快照
/// final snap = MemoryMonitor.snapshot();
/// // 导出 JSON
/// final json = MemoryMonitor.exportJson();
/// // 监听变化
/// MemoryMonitor.snapshotNotifier.addListener(myListener);
/// ```
class MemoryMonitor {
  MemoryMonitor._();

  static final MemoryMonitor _instance = MemoryMonitor._();

  Timer? _timer;
  int _lastRss = 0;
  int _peakRss = 0;
  final List<MetricSample> _history = [];

  /// 50 MB 增长阈值。
  static const int _thresholdBytes = 50 * 1024 * 1024;

  /// 历史上限。
  static const int _maxHistory = 200;

  /// 当前快照 — 外部可通过 ValueListenableBuilder 监听。
  final ValueNotifier<MemorySnapshot?> snapshotNotifier =
      ValueNotifier<MemorySnapshot?>(null);

  /// 可选回调 — 每次 tick 触发。
  void Function(MemorySnapshot snapshot)? onTick;

  // ─── 公开 API ───

  /// 启动周期性 RSS 日志。
  ///
  /// debug 构建中 no-op（依赖 [debugPrint] 在 release 中被消除）。
  static void start({
    Duration interval = const Duration(seconds: 30),
    void Function(MemorySnapshot snapshot)? onTick,
  }) {
    _instance.onTick = onTick;
    _instance._startImpl(interval: interval);
  }

  /// 停止定时器并重置状态。
  static void stop() {
    _instance._timer?.cancel();
    _instance._timer = null;
    _instance._lastRss = 0;
    _instance._peakRss = 0;
    _instance._history.clear();
    _instance.snapshotNotifier.value = null;
    _instance.onTick = null;
  }

  /// 获取当前快照（无历史数据时返回 null）。
  static MemorySnapshot? snapshot() {
    final instance = _instance;
    if (instance._lastRss == 0 && instance._history.isEmpty) return null;
    return MemorySnapshot(
      rssBytes: instance._lastRss,
      maxRssBytes: instance._peakRss,
      deltaBytes: 0,
      history: List.unmodifiable(instance._history),
      timestamp: DateTime.now(),
    );
  }

  /// 导出 JSON 字符串。
  static String exportJson() {
    final snap = snapshot();
    if (snap == null) return '{}';
    return jsonEncode(snap.toJson());
  }

  // ─── 内部实现 ───

  void _startImpl({
    Duration interval = const Duration(seconds: 30),
  }) {
    _lastRss = ProcessInfo.currentRss;
    _peakRss = _lastRss;
    _recordSample(_lastRss);
    _logCurrent(_lastRss);

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final current = ProcessInfo.currentRss;
      final delta = current - _lastRss;

      if (current > _peakRss) _peakRss = current;

      _recordSample(current);
      _logCurrent(current);

      if (delta > _thresholdBytes) {
        final deltaMB = (delta / (1024 * 1024)).toStringAsFixed(1);
        debugPrint(
          '[MemoryMonitor] RSS growth +$deltaMB MB exceeds threshold',
        );
      }

      _lastRss = current;

      // 构建快照并通知
      final snap = MemorySnapshot(
        rssBytes: current,
        maxRssBytes: _peakRss,
        deltaBytes: delta,
        history: List.unmodifiable(_history),
        timestamp: DateTime.now(),
      );
      snapshotNotifier.value = snap;
      onTick?.call(snap);
    });
  }

  void _recordSample(int rssBytes) {
    _history.add(MetricSample(
      rssBytes: rssBytes,
      timestamp: DateTime.now(),
    ));
    // 环形缓冲：超过上限移除最旧
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  void _logCurrent(int rssBytes) {
    final mb = (rssBytes / (1024 * 1024)).toStringAsFixed(1);
    debugPrint('[MemoryMonitor] RSS: $mb MB');
  }
}
