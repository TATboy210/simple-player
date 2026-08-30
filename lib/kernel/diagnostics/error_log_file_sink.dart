/// ErrorReporter effect that durably appends diagnostic evidence to one file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'diagnostic_pack_formatter.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';
import 'kernel_logger.dart';

/// Async boundary for one fully formed durable diagnostic-pack write.
///
/// Injectable writer seam that lets tests prove ordering and failure containment
/// without relying on filesystem permissions or platform-specific paths.
typedef ErrorLogWriter = Future<void> Function(String pack);

/// Error/fatal-only durable diagnostic-file effect.
///
/// The Future chain orders independent append-and-flush operations without
/// batching. It never awaits or throws into ErrorReporter effect dispatch.
final class ErrorLogFileSink {
  /// Reports the first and every fiftieth consecutive failure to avoid turning
  /// an unavailable disk into a diagnostic-output flood.
  static const int _failureReportInterval = 50;

  /// Creates an effect that writes diagnostic packs to [file].
  ErrorLogFileSink({
    required File file,
    ErrorLogWriter? writer,
    void Function(Object error, StackTrace stackTrace)? degradedOutput,
  }) : _file = file,
       _writer =
           writer ??
           ((pack) => file.writeAsString(
             pack,
             mode: FileMode.append,
             encoding: utf8,
             flush: true,
           )),
       _degradedOutput = degradedOutput ?? _defaultDegradedOutput;

  final File _file;
  final ErrorLogWriter _writer;
  final void Function(Object error, StackTrace stackTrace) _degradedOutput;
  Future<void> _pending = Future<void>.value();
  int _consecutiveFailures = 0;

  /// Stable availability state for a future non-modal presentation.
  final ValueNotifier<bool> logsAvailable = ValueNotifier<bool>(true);

  /// Accepts an ErrorReporter effect call and queues eligible durable evidence.
  void record(ErrorReport report, ReportAcceptance acceptance) {
    if (!_isPersistentSeverity(report.severity)) {
      return;
    }

    final pack = '${formatDiagnosticPack(report, logPath: _file.path)}\n\n';
    // This continuation stays non-throwing so failure cannot poison future
    // writes or cause ErrorReporter effect dispatch to re-enter itself.
    _pending = _pending
        .then((_) => _write(pack))
        .onError(
          (Object error, StackTrace stackTrace) =>
              _containFailure(error, stackTrace),
        );
  }

  /// Waits for all writes observed before this call without closing the effect.
  ///
  /// Repeated calls are safe because contained failures resolve the same chain.
  Future<void> drain() => _pending;

  /// Drains queued writes for lifecycle shutdown; the effect remains reusable.
  ///
  /// No OS handle is retained, so repeated close calls only await the chain.
  Future<void> dispose() => drain();

  /// Executes the injected write, restoring availability only after full success.
  Future<void> _write(String pack) async {
    await _writer(pack);
    _consecutiveFailures = 0;
    logsAvailable.value = true;
  }

  /// Records a contained failure while keeping subsequent write nodes usable.
  void _containFailure(Object error, StackTrace stackTrace) {
    _consecutiveFailures += 1;
    logsAvailable.value = false;
    if (_shouldReportFailure(_consecutiveFailures)) {
      try {
        _degradedOutput(error, stackTrace);
      } on Object {
        // Degraded output is terminal containment and must not reach reporter.
      }
    }
  }

  /// Keeps failure reporting observable without recursively producing an outage.
  bool _shouldReportFailure(int count) =>
      count == 1 || count % _failureReportInterval == 0;

  /// Reuses the kernel logger facade and contains uninitialized-logger failures.
  static void _defaultDegradedOutput(Object error, StackTrace stackTrace) {
    try {
      KernelLogger.I.warn(
        'Diagnostic file evidence is unavailable.',
        context: <String, Object?>{'errorType': error.runtimeType.toString()},
      );
    } on Object {
      // Startup may report before KernelLogger initialization; never recurse.
    }
  }

  /// Ensures warning-only reports never reach the filesystem boundary.
  bool _isPersistentSeverity(ErrorSeverity severity) =>
      severity == ErrorSeverity.error || severity == ErrorSeverity.fatal;
}
