/// Single local fan-in and bounded presentation queue for diagnostic reports.
library;

import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/player_error.dart';
import 'clock.dart';
import 'diagnostic_redactor.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';

/// 错误报告服务的窄接口。
///
/// Narrow error-reporting contract shared by global hooks and future effects.
abstract interface class ErrorReporter {
  /// Safely reports a Flutter framework callback failure.
  void reportFlutterSafely(FlutterErrorDetails details);

  /// Safely reports a root-isolate platform failure.
  void reportPlatformSafely(Object error, StackTrace stackTrace);

  /// Safely reports a guarded bootstrap failure.
  void reportBootstrapSafely(Object error, StackTrace stackTrace);

  /// Safely reports an explicit player-engine failure.
  void reportPlayerError(PlayerError error, {String? mediaPath});

  /// Announces that a presentation host can consume the existing FIFO head.
  void flushPresentation();

  /// Removes only the FIFO head after presentation is dismissed.
  void dismissCurrent();
}

/// 统一错误报告实现；拥有本地有界 FIFO 和副作用隔离。
///
/// Single diagnostic fan-in implementation. Public intake methods contain their
/// own failures so untrusted diagnostic payloads never become app failures.
final class ErrorReporterImpl implements ErrorReporter {
  /// Maximum reports retained for future presentation; evidence storage is a
  /// later effect and deliberately is not coupled to this bounded UI backlog.
  static const int _maxQueueLength = 5;

  /// Collapses an immediate callback storm without hiding a later recurrence.
  static const Duration _dedupeWindow = Duration(seconds: 10);

  /// Bounded snapshots prevent diagnostic input from growing local memory.
  static const int _maxTextLength = 4096;
  static const int _maxStackLength = 16384;
  static const int _maxFrameLength = 512;

  /// Used only when an input supplied no original throw-site stack.
  static const String unavailableOriginalStackMarker =
      '[unavailable original stack: no original throw-site stack was supplied]';

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
      throw StateError('ErrorReporterImpl.I accessed before init().');
    }
    return instance;
  }

  /// Whether [I] can be accessed without throwing.
  static bool get isInitialized => _instance != null;

  /// Initializes the process-wide reporter once without replacing consumers.
  static void init() => _instance ??= ErrorReporterImpl();

  /// Resets the process-wide reporter for isolated tests.
  @visibleForTesting
  static void resetForTesting() => _instance = null;

  /// Read-only FIFO snapshot for deterministic policy tests.
  @visibleForTesting
  List<ErrorReport> get queuedReports => List<ErrorReport>.unmodifiable(_queue);

  /// Captures a Flutter framework error with a supplied or explicit absent stack.
  @override
  void reportFlutterSafely(FlutterErrorDetails details) {
    _reportSafely(
      source: ErrorSource.flutterFramework,
      severity: ErrorSeverity.error,
      error: details.exception,
      suppliedStack: details.stack,
    );
  }

  /// Captures a platform error into the local diagnostics pipeline.
  @override
  void reportPlatformSafely(Object error, StackTrace stackTrace) {
    _reportSafely(
      source: ErrorSource.platformDispatcher,
      severity: ErrorSeverity.error,
      error: error,
      suppliedStack: stackTrace,
    );
  }

  /// Captures an exception emitted by the guarded application bootstrap zone.
  @override
  void reportBootstrapSafely(Object error, StackTrace stackTrace) {
    _reportSafely(
      source: ErrorSource.guardedZone,
      severity: ErrorSeverity.error,
      error: error,
      suppliedStack: stackTrace,
    );
  }

  /// Captures primitive snapshots from a PlayerError without retaining it.
  @override
  void reportPlayerError(PlayerError error, {String? mediaPath}) {
    try {
      // Snapshot every mutable PlayerError value before queue insertion.
      final context = error.context;
      _reportSafely(
        source: ErrorSource.playerEngine,
        severity: error.isFatal ? ErrorSeverity.fatal : ErrorSeverity.error,
        error: error,
        suppliedStack: context?.callbackStackTrace,
        messageOverride: error.message,
        mediaPathOverride: mediaPath ?? context?.path,
      );
    } on Object catch (failure, stackTrace) {
      // PlayerError implementations are untrusted at this boundary.
      _emitLastResort(failure, stackTrace);
    }
  }

  /// Publishes the existing FIFO head without altering queue contents.
  @override
  void flushPresentation() => _publishSafely(isReady: true);

  /// Removes the acknowledged head and promotes the next surviving report.
  @override
  void dismissCurrent() {
    try {
      if (_queue.isNotEmpty) {
        _queue.removeFirst();
      }
      _publishSafely();
    } on Object catch (failure, stackTrace) {
      // Containment boundary: queue/presentation failures cannot escape UI input.
      _emitLastResort(failure, stackTrace);
    }
  }

  void _reportSafely({
    required ErrorSource source,
    required ErrorSeverity severity,
    required Object error,
    required StackTrace? suppliedStack,
    String? messageOverride,
    String? mediaPathOverride,
  }) {
    if (_isReporting) {
      _emitLastResort(
        StateError('Suppressed reentrant error report.'),
        StackTrace.current,
      );
      return;
    }

    _isReporting = true;
    try {
      final report = _createReport(
        source: source,
        severity: severity,
        error: error,
        suppliedStack: suppliedStack,
        messageOverride: messageOverride,
        mediaPathOverride: mediaPathOverride,
      );
      final acceptance = _accept(report);
      _publishSafely();
      _notifyEffects(acceptance.report, acceptance.disposition);
    } on Object catch (failure, stackTrace) {
      // This documented composition boundary prevents diagnostic-chain crashes.
      _emitLastResort(failure, stackTrace);
    } finally {
      _isReporting = false;
    }
  }

  ErrorReport _createReport({
    required ErrorSource source,
    required ErrorSeverity severity,
    required Object error,
    required StackTrace? suppliedStack,
    required String? messageOverride,
    required String? mediaPathOverride,
  }) {
    final now = _clock.now();
    // Sanitize before length bounds and every downstream queue/effect fan-out.
    final message = _bounded(
      DiagnosticRedactor.redactDiagnosticText(
        messageOverride ?? error.toString(),
      ),
      _maxTextLength,
    );
    final stack = _snapshotStack(suppliedStack);
    return ErrorReport(
      eventId: _eventIdGenerator(),
      source: source,
      severity: severity,
      firstOccurredAt: now,
      lastOccurredAt: now,
      errorType: _bounded(error.runtimeType.toString(), _maxTextLength),
      message: message,
      rawStackTrace: stack,
      mediaPath: _sanitizeMediaPath(mediaPathOverride ?? _currentMediaPath()),
      occurrenceCount: 1,
    );
  }

  _AcceptanceResult _accept(ErrorReport candidate) {
    final matchingIndex = _findMatchingIndex(candidate);
    if (matchingIndex != null) {
      final existing = _queue.elementAt(matchingIndex);
      if (candidate.lastOccurredAt.difference(existing.lastOccurredAt) <=
          _dedupeWindow) {
        final merged = existing.copyWith(
          lastOccurredAt: candidate.lastOccurredAt,
          occurrenceCount: existing.occurrenceCount + 1,
        );
        _replaceAt(matchingIndex, merged);
        return _AcceptanceResult(merged, ReportAcceptance.merged);
      }
    }
    if (_queue.length == _maxQueueLength) {
      _queue.removeFirst();
    }
    _queue.addLast(candidate);
    return _AcceptanceResult(candidate, ReportAcceptance.newReport);
  }

  int? _findMatchingIndex(ErrorReport candidate) {
    final fingerprint = _fingerprint(candidate);
    for (var index = 0; index < _queue.length; index += 1) {
      if (_fingerprint(_queue.elementAt(index)) == fingerprint) {
        return index;
      }
    }
    return null;
  }

  void _replaceAt(int index, ErrorReport replacement) {
    final reports = _queue.toList(growable: false);
    _queue
      ..clear()
      ..addAll([
        for (
          var currentIndex = 0;
          currentIndex < reports.length;
          currentIndex += 1
        )
          currentIndex == index ? replacement : reports[currentIndex],
      ]);
  }

  String _fingerprint(ErrorReport report) {
    return '${report.source.name}|${report.errorType}|${report.message}|${_topFrame(report.rawStackTrace)}';
  }

  String _topFrame(String stack) {
    final lines = stack.split('\n');
    for (final line in lines) {
      if (line.contains('package:simple_player_flutter/')) {
        return _bounded(line, _maxFrameLength);
      }
    }
    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        return 'fallback:${_bounded(line, _maxFrameLength)}';
      }
    }
    return 'fallback:empty';
  }

  String _snapshotStack(StackTrace? suppliedStack) {
    final snapshot =
        suppliedStack?.toString() ?? unavailableOriginalStackMarker;
    return _bounded(
      DiagnosticRedactor.redactDiagnosticText(snapshot),
      _maxStackLength,
    );
  }

  String? _sanitizeMediaPath(String? value) {
    if (value == null) return null;
    return _bounded(DiagnosticRedactor.redactPathValue(value), _maxTextLength);
  }

  String _bounded(String value, int maximum) {
    if (value.length <= maximum) {
      return value;
    }
    return '${value.substring(0, maximum)}…[truncated]';
  }

  String? _boundedNullable(String? value) =>
      value == null ? null : _bounded(value, _maxTextLength);

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
    } on Object catch (failure, stackTrace) {
      _emitLastResort(failure, stackTrace);
    }
  }

  void _notifyEffects(ErrorReport report, ReportAcceptance acceptance) {
    for (final effect in _effects) {
      try {
        effect(report, acceptance);
      } on Object catch (failure, stackTrace) {
        _emitLastResort(failure, stackTrace);
      }
    }
  }

  void _emitLastResort(Object error, StackTrace stackTrace) {
    try {
      _lastResortOutput(error, stackTrace);
    } on Object {
      // Terminal fallback deliberately neither retries nor re-enters diagnostics.
    }
  }

  static String? _noMediaPath() => null;

  static EventIdGenerator _createEventIdGenerator() {
    var sequence = 0;
    return () => 'error-${DateTime.now().microsecondsSinceEpoch}-${++sequence}';
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

/// Immutable internal result used to keep queue policy separate from effects.
final class _AcceptanceResult {
  const _AcceptanceResult(this.report, this.disposition);

  final ErrorReport report;
  final ReportAcceptance disposition;
}
