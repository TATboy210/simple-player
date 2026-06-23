import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'log.dart';

/// Periodic RSS memory logger — debug builds only.
///
/// Reads [ProcessInfo.currentRss] every [interval] seconds and logs via
/// [logBridge]. When RSS growth exceeds [_thresholdBytes] since the last
/// reading, emits a warning.
class MemoryMonitor {
  MemoryMonitor._();

  static Timer? _timer;
  static int _lastRss = 0;

  /// 50 MB growth threshold.
  static const int _thresholdBytes = 50 * 1024 * 1024;

  /// Start periodic RSS logging.
  ///
  /// No-op in release builds ([kDebugMode] guard).
  static void start({
    Duration interval = const Duration(seconds: 30),
  }) {
    if (!kDebugMode) return;

    _lastRss = ProcessInfo.currentRss;
    final currentMB = (_lastRss / (1024 * 1024)).toStringAsFixed(1);
    logBridge.i('[MemoryMonitor] RSS: $currentMB MB');

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      final current = ProcessInfo.currentRss;
      final delta = current - _lastRss;
      final mb = (current / (1024 * 1024)).toStringAsFixed(1);
      logBridge.i('[MemoryMonitor] RSS: $mb MB');

      if (delta > _thresholdBytes) {
        final deltaMB = (delta / (1024 * 1024)).toStringAsFixed(1);
        logBridge.w(
          '[MemoryMonitor] RSS growth +$deltaMB MB exceeds threshold',
        );
      }

      _lastRss = current;
    });
  }

  /// Cancel periodic timer.
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
