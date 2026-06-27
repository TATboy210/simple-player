import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Periodic RSS memory logger — debug builds only.
///
/// Reads [ProcessInfo.currentRss] every [interval] seconds and logs via
/// [logBridge]. When RSS growth exceeds [_thresholdBytes] since the last
/// reading, emits a warning.
class MemoryMonitor {
  MemoryMonitor._();

  /// 内部实例 — 持有定时器状态，消除 static mutable state
  static final MemoryMonitor _instance = MemoryMonitor._();

  Timer? _timer;
  int _lastRss = 0;

  /// 50 MB growth threshold.
  static const int _thresholdBytes = 50 * 1024 * 1024;

  /// Start periodic RSS logging.
  ///
  /// No-op in release builds ([kDebugMode] guard).
  static void start({
    Duration interval = const Duration(seconds: 30),
  }) => _instance._startImpl(interval: interval);

  void _startImpl({
    Duration interval = const Duration(seconds: 30),
  }) {
    _lastRss = ProcessInfo.currentRss;
    final currentMB = (_lastRss / (1024 * 1024)).toStringAsFixed(1);
    debugPrint('[MemoryMonitor] RSS: $currentMB MB');

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final current = ProcessInfo.currentRss;
      final delta = current - _lastRss;
      final mb = (current / (1024 * 1024)).toStringAsFixed(1);
      debugPrint('[MemoryMonitor] RSS: $mb MB');

      if (delta > _thresholdBytes) {
        final deltaMB = (delta / (1024 * 1024)).toStringAsFixed(1);
        debugPrint(
          '[MemoryMonitor] RSS growth +$deltaMB MB exceeds threshold',
        );
      }

      _lastRss = current;
    });
  }

  /// Cancel periodic timer.
  static void stop() {
    _instance._timer?.cancel();
    _instance._timer = null;
  }
}
