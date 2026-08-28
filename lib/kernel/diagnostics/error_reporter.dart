/// Single local fan-in and bounded presentation queue for diagnostic reports.
library;

import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/player_error.dart';
import 'clock.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';

/// 错误报告服务的窄接口。
///
/// Narrow error-reporting contract shared by global hooks and future effects.
abstract interface class ErrorReporter {
  /// Safely reports a root-isolate platform failure.
  void reportPlatformSafely(Object error, StackTrace stackTrace);

  /// Announces that a presentation host can consume the existing FIFO head.
  void flushPresentation();
}

/// 统一错误报告实现；拥有本地有界 FIFO 和副作用隔离。
///
/// Single diagnostic fan-in implementation. Its public intake methods contain
/// their own failures so error feedback never becomes a second app failure.
final class ErrorReporterImpl implements ErrorReporter {
  /// Production construction with default injectable collaborators.
  ErrorReporterImpl({
    Clock clock = const SystemClock(),
    EventIdGenerator? eventIdGenerator,
    CurrentMediaPathProvider currentMediaPath = _noMediaPath,
    List<ErrorReportEffect> effects = const [],
    LastResortOutput lastResortOutput = _defaultLastResortOutput,
  }) : _clock = clock,
       _eventIdGenerator = eventIdGenerator ?? _createEventIdGenerator(),
       _currentMediaPath = currentMediaPath,
       _effects = List<ErrorReportEffect>.unmodifiable(effects),
       _lastResortOutput = lastResortOutput;

  /// Creates a reporter with deterministic seams for tests.
  ErrorReporterImpl.forTesting({
    required Clock clock,
    required EventIdGenerator eventIdGenerator,
    required CurrentMediaPathProvider currentMediaPath,
    List<ErrorReportEffect> effects = const [],
    LastResortOutput lastResortOutput = _defaultLastResortOutput,
  }) : _clock = clock,
       _eventIdGenerator = eventIdGenerator,
       _currentMediaPath = currentMediaPath,
       _effects = List<ErrorReportEffect>.unmodifiable(effects),
       _lastResortOutput = lastResortOutput;

  static ErrorReporterImpl? _instance;

  final Clock _clock;
  final EventIdGenerator _eventIdGenerator;
  final CurrentMediaPathProvider _currentMediaPath;
  final List<ErrorReportEffect> _effects;
  final LastResortOutput _lastResortOutput;
  final ListQueue<ErrorReport> _queue = ListQueue<ErrorReport>();

  /// Stable notifier instance for future presentation hosts.
  final ValueNotifier<ErrorPresentationState> presentation =
      ValueNotifier<ErrorPresentationState>(
        const ErrorPresentationState(
          current: null,
          pendingCount: 0,
          isReady: false,
        ),
      );

  bool _isReporting = false;

  /// Global reporter instance. [init] must run before access.
  static ErrorReporterImpl get I {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'ErrorReporterImpl.I accessed before init(). '
        'Call ErrorReporterImpl.init() at app startup.',
      );
    }
    return instance;
  }

  /// Whether [I] can be accessed without throwing.
  static bool get isInitialized => _instance != null;

  /// Initializes the process-wide reporter once without replacing consumers.
  static void init() {
    _instance ??= ErrorReporterImpl();
  }

  /// Resets the process-wide reporter for isolated tests.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Read-only FIFO snapshot for deterministic policy tests.
  @visibleForTesting
  List<ErrorReport> get queuedReports => List<ErrorReport>.unmodifiable(_queue);

  /// Captures a platform error into the local diagnostics pipeline.
  @override
  void reportPlatformSafely(Object error, StackTrace stackTrace) {
    _reportSafely(
      source: ErrorSource.platformDispatcher,
      severity: ErrorSeverity.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Publishes the existing FIFO head without altering queue contents.
  @override
  void flushPresentation() {
    _publishSafely(isReady: true);
  }

  void _reportSafely({
    required ErrorSource source,
    required ErrorSeverity severity,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (_isReporting) {
      _emitLastResort(
        StateError('Suppressed reentrant error report.'),
        stackTrace,
      );
      return;
    }

    _isReporting = true;
    try {
      final report = _createReport(source, severity, error, stackTrace);
      _queue.addLast(report);
      _publishSafely();
      _notifyEffects(report, ReportAcceptance.newReport);
    } on Object catch (failure, failureStackTrace) {
      // This outer boundary is intentionally broad: diagnostics must not crash.
      _emitLastResort(failure, failureStackTrace);
    } finally {
      _isReporting = false;
    }
  }

  ErrorReport _createReport(
    ErrorSource source,
    ErrorSeverity severity,
    Object error,
    StackTrace stackTrace,
  ) {
    final now = _clock.now();
    return ErrorReport(
      eventId: _eventIdGenerator(),
      source: source,
      severity: severity,
      firstOccurredAt: now,
      lastOccurredAt: now,
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      rawStackTrace: stackTrace.toString(),
      mediaPath: _currentMediaPath(),
      occurrenceCount: 1,
    );
  }

  void _publishSafely({bool? isReady}) {
    try {
      final prior = presentation.value;
      final ready = isReady ?? prior.isReady;
      final current = ready && _queue.isNotEmpty ? _queue.first : null;
      final pendingCount = ready
          ? _queue.length - (current == null ? 0 : 1)
          : _queue.length;
      presentation.value = ErrorPresentationState(
        current: current,
        pendingCount: pendingCount,
        isReady: ready,
      );
    } on Object catch (failure, failureStackTrace) {
      _emitLastResort(failure, failureStackTrace);
    }
  }

  void _notifyEffects(ErrorReport report, ReportAcceptance acceptance) {
    for (final effect in _effects) {
      try {
        effect(report, acceptance);
      } on Object catch (failure, failureStackTrace) {
        _emitLastResort(failure, failureStackTrace);
      }
    }
  }

  void _emitLastResort(Object error, StackTrace stackTrace) {
    try {
      _lastResortOutput(error, stackTrace);
    } on Object {
      // Last-resort output is intentionally terminal and non-recursive.
    }
  }

  static String? _noMediaPath() => null;

  static EventIdGenerator _createEventIdGenerator() {
    var sequence = 0;
    return () {
      sequence += 1;
      return 'error-${DateTime.now().microsecondsSinceEpoch}-$sequence';
    };
  }

  static void _defaultLastResortOutput(Object error, StackTrace stackTrace) {
    try {
      developer.log(
        'Error reporter containment failure: $error',
        stackTrace: stackTrace,
      );
    } on Object {
      // The terminal fallback cannot safely recover further.
    }
  }
}
