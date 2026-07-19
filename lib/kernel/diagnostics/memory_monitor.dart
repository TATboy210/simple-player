/// 实例化内存监控器 — 可注入、可关闭、不干扰播放业务的诊断组件。
///
/// Instance-based memory monitor implementing [MemoryMonitorSlot].
/// Replaces the legacy static singleton with dependency injection:
/// - [RssProvider] for RSS reads (testable without ProcessInfo)
/// - [Clock] for timestamps (testable without DateTime.now())
/// - [KernelLogger] for structured logging (replaces debugPrint)
///
/// Constructor auto-starts the periodic timer (D5).
/// [start()] is idempotent (Pitfall 1), [dispose()] is idempotent (Pitfall 3).
/// Zero interaction with PlaybackController or MediaState.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'kernel_logger.dart';
import 'memory_monitor_slot.dart';
import 'memory_snapshot.dart';
import 'rss_provider.dart';

/// 周期性内存监控 — 可注入依赖, 实现 [MemoryMonitorSlot]。
///
/// Periodic RSS memory monitor. Constructor auto-starts the sampling timer.
///
/// 用法:
/// ```dart
/// final monitor = MemoryMonitor(
///   rssProvider: ProcessInfoRssProvider(),
///   clock: SystemClock(),
///   logger: KernelLoggerImpl.I,
/// );
/// monitor.snapshotNotifier.addListener(myListener);
/// // ...
/// monitor.dispose();
/// ```
final class MemoryMonitor implements MemoryMonitorSlot {
  // ─── 静态单例 (KernelLoggerImpl.I 模式, Phase 17 风格) ───

  /// 静态实例 — 由 [init] 在 PlayerServices.init() 中设置。
  static MemoryMonitor? _instance;

  /// 全局访问器 — 调用前必须先调用 [init]。
  ///
  /// Throws [StateError] if [init] has not been called.
  static MemoryMonitor get I {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'MemoryMonitor.I accessed before init(). '
        'Call MemoryMonitor.init() in PlayerServices.init().',
      );
    }
    return inst;
  }

  /// 组合根 — 在 PlayerServices.init() 中调用, 设置静态 [I] 访问器。
  static void init(MemoryMonitor monitor) {
    _instance = monitor;
  }

  /// 测试重置 — 清除静态实例, 隔离测试间状态。
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  // ─── 实例构造 ───

  /// 构造 — 必填 [rssProvider] + [clock], 可选配置参数和回调。
  ///
  /// 自动启动定时器 (D5): 构造函数体内调用 [_startImpl]。
  ///
  /// [thresholdBytes] RSS 增长阈值 (默认 50 MB, D9).
  /// [maxHistory] 环形缓冲上限 (默认 200, D9).
  /// [interval] 采样间隔 (默认 30s, D9).
  /// [logger] 可选日志门面 (MEM-05 prep).
  /// [onTick] 每次 tick 回调.
  MemoryMonitor({
    required this.rssProvider,
    required this.clock,
    this.thresholdBytes = 50 * 1024 * 1024,
    this.maxHistory = 200,
    this.interval = const Duration(seconds: 30),
    KernelLogger? logger,
    this.onTick,
  }) : _logger = logger {
    _startImpl();
  }

  /// RSS 读取抽象 (可注入)。
  final RssProvider rssProvider;

  /// 时钟抽象 (可注入)。
  final Clock clock;

  /// RSS 增长阈值 (字节) — 超过此值触发 warn 日志。
  final int thresholdBytes;

  /// 环形缓冲历史上限。
  final int maxHistory;

  /// 采样间隔。
  final Duration interval;

  /// 日志门面 (可选)。
  final KernelLogger? _logger;

  /// 每次 tick 回调 (可选)。
  void Function(MemorySnapshot snapshot)? onTick;

  /// 当前快照 — 外部可通过 ValueListenableBuilder 监听。
  final ValueNotifier<MemorySnapshot?> snapshotNotifier =
      ValueNotifier<MemorySnapshot?>(null);

  Timer? _timer;
  int _lastRss = 0;
  int _peakRss = 0;
  final List<MetricSample> _history = [];
  bool _disposed = false;

  // ─── 公开 API (MemoryMonitorSlot) ───

  /// 启动周期性采样 — 幂等: 已运行或已释放时为 no-op (Pitfall 1)。
  ///
  /// Idempotent start. No-op if timer already running or already disposed.
  @override
  void start({Duration? interval}) {
    if (_timer != null || _disposed) return;
    _startImpl(interval: interval);
  }

  /// 停止采样并重置状态。
  ///
  /// Stops timer, resets all state, clears snapshotNotifier.
  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastRss = 0;
    _peakRss = 0;
    _history.clear();
    snapshotNotifier.value = null;
    onTick = null;
  }

  /// 获取当前快照 — 无数据时返回 null。
  ///
  /// Returns current [MemorySnapshot] or null if no samples recorded yet.
  @override
  MemorySnapshot? snapshot() {
    if (_lastRss == 0 && _history.isEmpty) return null;
    return MemorySnapshot(
      rssBytes: _lastRss,
      maxRssBytes: _peakRss,
      deltaBytes: 0,
      history: List.unmodifiable(_history),
      timestamp: clock.now(),
    );
  }

  /// 导出 JSON 字符串 — 无数据时返回 '{}'。
  ///
  /// Exports current snapshot as JSON string. Returns '{}' if no data.
  String exportJson() {
    final snap = snapshot();
    if (snap == null) return '{}';
    return jsonEncode(snap.toJson());
  }

  /// 释放资源 — 幂等: 重复调用安全 (Pitfall 3)。
  ///
  /// Idempotent dispose. Guarded by [_disposed] flag.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    snapshotNotifier.dispose();
  }

  // ─── 内部实现 ───

  /// 实际启动逻辑 — 读初始 RSS, 创建周期定时器。
  ///
  /// Reads initial RSS, records first sample, creates periodic timer.
  /// Called from constructor and [start].
  void _startImpl({Duration? interval}) {
    final effectiveInterval = interval ?? this.interval;

    _lastRss = rssProvider.currentRss;
    _peakRss = _lastRss;
    _recordSample(_lastRss);
    _logCurrent(_lastRss);

    _timer?.cancel();
    _timer = Timer.periodic(effectiveInterval, (_) {
      final current = rssProvider.currentRss;
      final delta = current - _lastRss;

      if (current > _peakRss) _peakRss = current;

      _recordSample(current);
      _logCurrent(current);

      // 阈值警告 — 使用 KernelLogger (MEM-05 prep)
      if (delta > thresholdBytes) {
        final deltaMB = (delta / (1024 * 1024)).toStringAsFixed(1);
        _logger?.warn(
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
        timestamp: clock.now(),
      );
      snapshotNotifier.value = snap;
      onTick?.call(snap);
    });
  }

  /// 记录采样到环形缓冲 — 使用 [Clock.now] 时间戳。
  ///
  /// Adds sample to ring buffer, trims to [maxHistory].
  void _recordSample(int rssBytes) {
    _history.add(MetricSample(
      rssBytes: rssBytes,
      timestamp: clock.now(),
    ));
    // 环形缓冲: 超过上限移除最旧
    while (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  /// 日志当前 RSS — 使用 [KernelLogger.info] (MEM-05 prep)。
  void _logCurrent(int rssBytes) {
    final mb = (rssBytes / (1024 * 1024)).toStringAsFixed(1);
    _logger?.info('[MemoryMonitor] RSS: $mb MB');
  }
}
