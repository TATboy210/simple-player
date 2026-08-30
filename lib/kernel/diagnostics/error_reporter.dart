/// Single local fan-in and bounded presentation queue for diagnostic reports.
library;

import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/player_error.dart';
import 'clock.dart';
import 'diagnostic_redactor.dart';
import 'error_location.dart';
import 'error_report.dart';
import 'error_reporting_dependencies.dart';
import 'source_line_reader.dart';

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
  // Developer-only evidence needs the same bounded-memory guarantee as text.
  static const int _maxDeveloperPathLength = 4096;
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
    ErrorLocationEnricher locationEnricher = _defaultLocationEnricher,
    List<ErrorReportEffect> effects = const [],
    LastResortOutput lastResortOutput = _defaultLastResortOutput,
  }) : _clock = clock,
       _eventIdGenerator = eventIdGenerator ?? _createEventIdGenerator(),
       _currentMediaPath = currentMediaPath,
       _locationEnricher = locationEnricher,
       _effects = List<ErrorReportEffect>.unmodifiable(effects),
       _lastResortOutput = lastResortOutput;

  /// Creates a reporter with deterministic seams for tests.
  ErrorReporterImpl.forTesting({
    required Clock clock,
    required EventIdGenerator eventIdGenerator,
    required CurrentMediaPathProvider currentMediaPath,
    ErrorLocationEnricher locationEnricher = _defaultLocationEnricher,
    List<ErrorReportEffect> effects = const [],
    LastResortOutput lastResortOutput = _defaultLastResortOutput,
  }) : _clock = clock,
       _eventIdGenerator = eventIdGenerator,
       _currentMediaPath = currentMediaPath,
       _locationEnricher = locationEnricher,
       _effects = List<ErrorReportEffect>.unmodifiable(effects),
       _lastResortOutput = lastResortOutput;

  static ErrorReporterImpl? _instance;

  final Clock _clock;
  final EventIdGenerator _eventIdGenerator;
  final CurrentMediaPathProvider _currentMediaPath;
  final ErrorLocationEnricher _locationEnricher;
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
        // Context path names the failed open target, never the successfully
        // current media. The provider preserves the current-media snapshot.
        mediaPathOverride: mediaPath,
        failedOpenPathOverride: context?.path,
        playerErrorCode: _playerErrorCode(error),
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
    String? failedOpenPathOverride,
    String? playerErrorCode,
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
        failedOpenPathOverride: failedOpenPathOverride,
        playerErrorCode: playerErrorCode,
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
    required String? failedOpenPathOverride,
    required String? playerErrorCode,
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
    // Read the live provider once before any redaction so accepted reports cannot
    // drift when playback changes while effects later consume the snapshot.
    final fullMediaPath = _boundedDeveloperPath(
      mediaPathOverride ?? _currentMediaPath(),
    );
    final failedOpenPath = _boundedDeveloperPath(failedOpenPathOverride);
    final location = _enrichLocation(stack);
    return ErrorReport(
      eventId: _eventIdGenerator(),
      source: source,
      severity: severity,
      firstOccurredAt: now,
      lastOccurredAt: now,
      errorType: _bounded(error.runtimeType.toString(), _maxTextLength),
      playerErrorCode: playerErrorCode,
      message: message,
      rawStackTrace: stack,
      mediaPath: _sanitizeMediaPath(fullMediaPath),
      fullMediaPath: fullMediaPath,
      failedOpenPath: failedOpenPath,
      location: location,
      occurrenceCount: 1,
    );
  }

  /// Produces final location evidence before any queue or effect can observe it.
  ///
  /// Failure is intentionally an evidence downgrade: public capture still accepts
  /// the report and formatter emits the stable no-project-frame fallback.
  ErrorLocation? _enrichLocation(String rawStackTrace) {
    try {
      return _locationEnricher(rawStackTrace);
    } on Object {
      return null;
    }
  }

  _AcceptanceResult _accept(ErrorReport candidate) {
    final matchingIndex = _newestInWindowIndex(candidate);
    if (matchingIndex != null) {
      final existing = _queue.elementAt(matchingIndex);
      final merged = existing.copyWith(
        lastOccurredAt: candidate.lastOccurredAt,
        occurrenceCount: existing.occurrenceCount + 1,
      );
      _replaceAt(matchingIndex, merged);
      return _AcceptanceResult(merged, ReportAcceptance.merged);
    }
    if (_queue.length == _maxQueueLength) {
      _queue.removeFirst();
    }
    _queue.addLast(candidate);
    return _AcceptanceResult(candidate, ReportAcceptance.newReport);
  }

  /// 从最新端向最旧端扫描，返回首个"等语义身份且落在 0–10 秒窗内"的项下标。
  ///
  /// 时间窗检查必须与选择同趟完成：若先取最旧等指纹项再看时间，t=0、t=11、
  /// t=15 的复现序列会只与 t=0 比较（elapsed=15s 超窗）而被错误追加为第三条
  /// （01-VERIFICATION gap 1）。从最新端扫描保证最近一次窗内出现优先获得合并。
  int? _newestInWindowIndex(ErrorReport candidate) {
    final identity = _identity(candidate);
    for (var index = _queue.length - 1; index >= 0; index -= 1) {
      final existing = _queue.elementAt(index);
      if (_identity(existing) != identity) {
        continue;
      }
      final elapsed = candidate.lastOccurredAt.difference(
        existing.lastOccurredAt,
      );
      // Wall-clock rollback must preserve new evidence instead of merging stale.
      if (elapsed >= Duration.zero && elapsed <= _dedupeWindow) {
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

  /// 报告的语义身份：仅用于短窗合并判定的固定字段顺序元组。
  ///
  /// record 的 `==` 是逐字段结构相等，直接比较值本身而非序列化串——
  /// message/mediaPath 等可变长字段携带 `|` 也不会产生分隔符碰撞
  /// （01-VERIFICATION gap 2）。
  _ReportIdentity _identity(ErrorReport report) {
    return (
      report.source,
      report.severity,
      report.errorType,
      report.playerErrorCode,
      report.message,
      report.mediaPath,
      // A safely redacted attempt target distinguishes independent failed opens
      // without exposing developer-only full paths to presentation consumers.
      _sanitizeMediaPath(report.failedOpenPath),
      _topFrame(report.rawStackTrace),
    );
  }

  /// Converts the sealed player hierarchy into an immutable, stable primitive.
  String _playerErrorCode(PlayerError error) {
    return switch (error) {
      FileError(:final code) => 'file:${code.name}',
      CodecError(:final code) => 'codec:${code.name}',
      PlaybackError(:final code) => 'playback:${code.name}',
      NetworkError(:final code) => 'network:${code.name}',
      UnknownError() => 'unknown',
    };
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

  /// Bounds opaque developer-only paths without applying UI-safe redaction.
  String? _boundedDeveloperPath(String? value) {
    if (value == null) return null;
    return _bounded(value, _maxDeveloperPathLength);
  }

  String _bounded(String value, int maximum) {
    if (value.length <= maximum) {
      return value;
    }
    const truncationMarker = '…[truncated]';
    if (maximum <= truncationMarker.length) {
      return truncationMarker.substring(0, maximum);
    }
    return '${value.substring(0, maximum - truncationMarker.length)}'
        '$truncationMarker';
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

  /// Extracts source frames from frozen evidence and reads optional trusted lines.
  static ErrorLocation? _defaultLocationEnricher(String rawStackTrace) {
    final location = extractErrorLocation(rawStackTrace);
    if (location == null) return null;
    final excerpt = SourceLineReader().read(location.primaryFrame);
    if (excerpt == null) return location;
    return ErrorLocation(
      primaryFrame: location.primaryFrame,
      secondaryFrames: location.secondaryFrames,
      sourceLines: [
        for (final line in excerpt.lines) '${line.lineNumber}: ${line.text}',
      ],
    );
  }

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

/// Narrow synchronous enrichment seam used before report acceptance/effects.
typedef ErrorLocationEnricher = ErrorLocation? Function(String rawStackTrace);

/// Immutable internal result used to keep queue policy separate from effects.
final class _AcceptanceResult {
  const _AcceptanceResult(this.report, this.disposition);

  final ErrorReport report;
  final ReportAcceptance disposition;
}

/// 语义身份元组类型：source/severity/errorType/playerErrorCode/message/
/// mediaPath/safeFailedOpenPath/topFrame 八字段 record，结构相等即语义等价。
typedef _ReportIdentity = (
  ErrorSource,
  ErrorSeverity,
  String,
  String?,
  String,
  String?,
  String?,
  String,
);
