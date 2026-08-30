/// Injectable dependencies for deterministic, failure-isolated error reporting.
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'error_report.dart';
import 'kernel_logger.dart';

/// 生成进程内报告 ID 的纯函数。
///
/// Generates a process-local identifier for each distinct accepted report.
typedef EventIdGenerator = String Function();

/// 在捕获瞬间读取当前媒体路径的纯函数。
///
/// Reads the current media path at intake so the report stores a primitive
/// snapshot rather than retaining a playback-service dependency.
typedef CurrentMediaPathProvider = String? Function();

/// 每次已接纳的报告触发的独立副作用。
///
/// Isolated effect invoked for every accepted new or merged report.
typedef ErrorReportEffect = void Function(
  ErrorReport report,
  ReportAcceptance acceptance,
);

/// 报告链本身故障时的非递归最后输出边界。
///
/// Last-resort output for reporter-chain failures. Implementations must not
/// invoke the reporter, logger, or UI because this boundary contains recursion.
typedef LastResortOutput = void Function(Object error, StackTrace stackTrace);

/// 捕获进入有界队列后的处置结果。
///
/// Disposition returned to effects. Only [newReport] and [merged] are emitted
/// because eviction and reentrancy suppression are not accepted captures.
enum ReportAcceptance {
  /// A distinct report was appended to the bounded FIFO.
  newReport,

  /// A matching in-window report was replaced in its original FIFO slot.
  merged,

  /// A prior FIFO head was evicted to make capacity for a new report.
  dropped,

  /// Intake was suppressed because a reporter call was already active.
  reentrantSuppressed,
}

/// References [Clock] so the reporter reuses the project-wide injectable clock.
typedef DiagnosticClock = Clock;

/// Write endpoint owned by the stable startup diagnostic-file delegate.
///
/// The concrete file sink remains replaceable at the composition boundary while
/// reporter consumers retain the delegate and its status listenables forever.
abstract interface class DiagnosticLogSink {
  /// Queues a report for durable evidence when the writer is active.
  void record(ErrorReport report, ReportAcceptance acceptance);

  /// Stable write availability published by the concrete sink.
  ValueListenable<bool> get logsAvailable;

  /// Drains any accepted writes before the active writer is released.
  Future<void> dispose();
}

/// Read-only diagnostic-log state exposed to future presentation consumers.
abstract interface class DiagnosticLogStatus {
  /// Stable availability notifier; false until a writer activates or after I/O loss.
  ValueListenable<bool> get logsAvailable;

  /// Stable nullable path notifier; null whenever no active writer exists.
  ValueListenable<String?> get logPath;
}

/// Startup-stable reporter effect that buffers durable evidence until activation.
///
/// Pending path resolution retains a bounded FIFO so hooks-first startup cannot lose
/// accepted error evidence. Activation drains that FIFO before accepting direct writes,
/// while notifier identities remain stable for reporter and UI consumers.
final class DelegatingDiagnosticLogEffect implements DiagnosticLogStatus {
  DelegatingDiagnosticLogEffect();

  /// Retains only a bounded startup burst while path-provider resolution is pending.
  static const int _pendingCapacity = 32;

  final ValueNotifier<bool> _logsAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _logPath = ValueNotifier<String?>(null);
  final ListQueue<_PendingDiagnosticRecord> _pending =
      ListQueue<_PendingDiagnosticRecord>();
  DiagnosticLogSink? _sink;
  bool _isActivated = false;
  bool _isFlushingPending = false;

  @override
  ValueListenable<bool> get logsAvailable => _logsAvailable;

  @override
  ValueListenable<String?> get logPath => _logPath;

  /// Accepts an ErrorReporter effect call without exposing a concrete writer.
  void record(ErrorReport report, ReportAcceptance acceptance) {
    final sink = _sink;
    if (sink != null && !_isFlushingPending) {
      sink.record(report, acceptance);
      return;
    }
    _enqueuePending(report, acceptance);
  }

  /// Retains a bounded record while initial activation serializes the sink handoff.
  void _enqueuePending(ErrorReport report, ReportAcceptance acceptance) {
    // Drop the oldest record to preserve the most recent bounded startup evidence.
    if (_pending.length == _pendingCapacity) {
      _pending.removeFirst();
    }
    _pending.addLast(_PendingDiagnosticRecord(report, acceptance));
  }

  /// Activates [sink] once and flushes unresolved reports in their original order.
  void activate({
    required DiagnosticLogSink sink,
    required String resolvedPath,
  }) {
    if (_isActivated) {
      _warnRepeatedActivation();
      return;
    }
    _isActivated = true;
    // Keep arrivals queued until every original record reaches the sink, including
    // reentrant effect calls made during a synchronous record implementation.
    _sink = sink;
    _isFlushingPending = true;
    sink.logsAvailable.addListener(_syncAvailability);
    _logPath.value = resolvedPath;
    _logsAvailable.value = sink.logsAvailable.value;
    while (_pending.isNotEmpty) {
      final pending = _pending.removeFirst();
      sink.record(pending.report, pending.acceptance);
    }
    _isFlushingPending = false;
  }

  /// Contains repeated activation diagnostics because this effect is a hook target.
  void _warnRepeatedActivation() {
    try {
      KernelLogger.I.warn('Diagnostic log effect ignored repeated activation.');
    } on Object {
      // Logger initialization cannot be assumed by direct unit-test construction.
    }
  }

  void _syncAvailability() {
    final sink = _sink;
    if (sink != null) {
      _logsAvailable.value = sink.logsAvailable.value;
    }
  }

  /// Drains and releases the active writer for test reset or process shutdown.
  Future<void> dispose() async {
    final sink = _sink;
    sink?.logsAvailable.removeListener(_syncAvailability);
    _sink = null;
    _isActivated = false;
    _isFlushingPending = false;
    _pending.clear();
    _logPath.value = null;
    _logsAvailable.value = false;
    if (sink != null) {
      await sink.dispose();
    }
  }
}

/// Immutable startup record that preserves the reporter effect call contract.
final class _PendingDiagnosticRecord {
  const _PendingDiagnosticRecord(this.report, this.acceptance);

  final ErrorReport report;
  final ReportAcceptance acceptance;
}
