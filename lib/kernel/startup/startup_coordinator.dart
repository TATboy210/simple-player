import 'package:flutter/foundation.dart';

import '../diagnostics/kernel_logger.dart';
import 'startup_state.dart';

export 'startup_state.dart';

final log = KernelLogger.I;

/// 启动协调器 — 跟踪各阶段进度并广播状态
///
/// 各初始化组件通过 [report] 上报阶段进展，
/// UI 通过 [state] ValueNotifier 驱动 Splash 进度。
///
/// 用法：
/// ```dart
/// final coordinator = StartupCoordinator();
/// coordinator.report(StartupPhase.infrastructure, 0.5, 'Rust init...');
/// // ...完成后
/// coordinator.report(StartupPhase.infrastructure, 1.0, 'Done');
/// ```
class StartupCoordinator {
  StartupCoordinator() {
    _stopwatch.start();
  }

  final _state = ValueNotifier<StartupState>(StartupState.initial);
  final _stopwatch = Stopwatch();
  final _phaseTimestamps = <StartupPhase, int>{};

  // ── 逐阶段独立计时 ──
  final _phaseWatches = <StartupPhase, Stopwatch>{};
  final _phaseDurations = <StartupPhase, Duration>{};

  /// 当前启动状态
  ValueNotifier<StartupState> get state => _state;

  /// 上报阶段进展
  ///
  /// [phase] 当前阶段
  /// [progress] 0.0 ~ 1.0
  /// [message] 阶段描述文本
  void report(StartupPhase phase, double progress, String message) {
    if (!_phaseTimestamps.containsKey(phase)) {
      _phaseTimestamps[phase] = _stopwatch.elapsedMilliseconds;
    }
    // 阶段开始时启动独立 Stopwatch
    if (progress == 0.0 && !_phaseWatches.containsKey(phase)) {
      _phaseWatches[phase] = Stopwatch()..start();
    }
    // 阶段完成时记录耗时
    final watch = _phaseWatches[phase];
    if (progress >= 1.0 && watch != null) {
      watch.stop();
      _phaseDurations[phase] = watch.elapsed;
    }
    _state.value = StartupState(
      phase: phase,
      progress: progress.clamp(0.0, 1.0),
      message: message,
    );
  }

  /// 标记启动完成
  void markReady() {
    _stopwatch.stop();
    _phaseTimestamps[StartupPhase.ready] = _stopwatch.elapsedMilliseconds;
    _state.value = const StartupState(
      phase: StartupPhase.ready,
      progress: 1.0,
      message: 'Ready',
    );
    _logTimeline();
  }

  /// 输出逐阶段结构化耗时日志
  void _logTimeline() {
    log.i('━━━ Startup Timeline ━━━');
    for (final phase in StartupPhase.values) {
      if (phase == StartupPhase.ready) continue;
      final duration = _phaseDurations[phase];
      if (duration != null) {
        final ms = duration.inMicroseconds / 1000; // μs → ms 转换
        log.i('  ✓ ${phase.name.padRight(16)} ${ms.toStringAsFixed(1)}ms');
      } else if (_phaseTimestamps.containsKey(phase)) {
        log.i('  ○ ${phase.name.padRight(16)} (no duration)');
      } else {
        log.i('  ○ ${phase.name.padRight(16)} (skipped)');
      }
    }
    final total = _stopwatch.elapsed;
    log.i('  ────────────────────────');
    log.i('  Total: ${(total.inMicroseconds / 1000).toStringAsFixed(1)}ms'); // μs → ms 转换
    log.i('━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Releases all resources. Call during app shutdown.
  void dispose() {
    _state.dispose();
  }
}
