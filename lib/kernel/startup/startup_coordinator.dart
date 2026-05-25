import 'package:flutter/foundation.dart';

import 'startup_state.dart';

export 'startup_state.dart';

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

  /// 输出各阶段耗时日志
  void _logTimeline() {
    final total = _stopwatch.elapsedMilliseconds;
    debugPrint('[Startup] completed in ${total}ms');
    var prev = 0;
    for (final phase in StartupPhase.values) {
      final ts = _phaseTimestamps[phase];
      if (ts != null) {
        final delta = ts - prev;
        debugPrint('  ${phase.name}: +${delta}ms (at ${ts}ms)');
        prev = ts;
      }
    }
  }

  void dispose() {
    _state.dispose();
  }
}
