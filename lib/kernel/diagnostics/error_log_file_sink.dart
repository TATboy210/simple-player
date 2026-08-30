/// ErrorReporter effect that durably appends diagnostic evidence to one file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'diagnostic_pack_formatter.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';

/// Error/fatal-only durable diagnostic-file effect.
///
/// The Future chain orders independent append-and-flush operations without
/// batching. It never awaits or throws into ErrorReporter effect dispatch.
final class ErrorLogFileSink {
  /// Creates an effect that writes diagnostic packs to [file].
  ErrorLogFileSink({required File file}) : _file = file;

  final File _file;
  Future<void> _pending = Future<void>.value();

  /// Stable availability state for a future non-modal presentation.
  final ValueNotifier<bool> logsAvailable = ValueNotifier<bool>(true);

  /// Accepts an ErrorReporter effect call and queues eligible durable evidence.
  void record(ErrorReport report, ReportAcceptance acceptance) {
    if (!_isPersistentSeverity(report.severity)) {
      return;
    }

    final pack = formatDiagnosticPack(report, logPath: _file.path);
    // This continuation remains non-throwing so one filesystem failure cannot
    // poison later evidence or re-enter ErrorReporter.
    _pending = _pending
        .then((_) => _append(pack))
        .then(
          (_) => logsAvailable.value = true,
          onError: (Object _, StackTrace __) => logsAvailable.value = false,
        );
  }

  /// Waits for all writes observed before this call without closing the effect.
  Future<void> drain() => _pending;

  /// Appends one complete UTF-8 pack and asks the OS to flush it immediately.
  Future<void> _append(String pack) => _file.writeAsString(
    '$pack\n\n',
    mode: FileMode.append,
    encoding: utf8,
    flush: true,
  );

  /// Ensures warning-only reports never reach the filesystem boundary.
  bool _isPersistentSeverity(ErrorSeverity severity) =>
      severity == ErrorSeverity.error || severity == ErrorSeverity.fatal;
}
