/// 统一错误来源；每个值只描述捕获边界，不描述展示或存储策略。
///
/// Unified error sources. Each value identifies a capture boundary only.
enum ErrorSource {
  /// Flutter framework callback failure.
  flutterFramework,

  /// Root-isolate platform dispatcher failure.
  platformDispatcher,

  /// Guarded application bootstrap failure.
  guardedZone,

  /// Explicit player-engine error intake.
  playerEngine,
}

/// 面向开发者的错误严重级别。
///
/// Developer-facing diagnostic severity.
enum ErrorSeverity {
  /// A recoverable degraded condition.
  warning,

  /// An operation failure while the process can continue.
  error,

  /// An unrecoverable player error.
  fatal,
}

/// 已冻结的本地诊断事件；构造后没有可变状态。
///
/// Immutable local diagnostic event. Values are primitive snapshots so a later
/// mutation of an originating error object cannot alter the accepted event.
final class ErrorReport {
  /// Creates an immutable diagnostic report from already-snapshotted values.
  const ErrorReport({
    required this.eventId,
    required this.source,
    required this.severity,
    required this.firstOccurredAt,
    required this.lastOccurredAt,
    required this.errorType,
    required this.playerErrorCode,
    required this.message,
    required this.rawStackTrace,
    required this.mediaPath,
    required this.occurrenceCount,
  });

  /// Process-local identifier assigned to a distinct report.
  final String eventId;

  /// Boundary that captured the error.
  final ErrorSource source;

  /// Severity determined at the capture boundary.
  final ErrorSeverity severity;

  /// Timestamp of the first accepted occurrence.
  final DateTime firstOccurredAt;

  /// Timestamp of the most recently merged occurrence.
  final DateTime lastOccurredAt;

  /// Snapshot of the incoming error runtime type.
  final String errorType;

  /// Stable structured PlayerError discriminator captured at player intake.
  ///
  /// Non-player capture boundaries store null so semantic dedupe cannot confuse
  /// two typed player failures that happen to share text and a stack frame.
  final String? playerErrorCode;

  /// Bounded opaque diagnostic message snapshot.
  final String message;

  /// Bounded stack snapshot or an explicit unavailable marker.
  final String rawStackTrace;

  /// Media-path snapshot captured at intake, when available.
  final String? mediaPath;

  /// Number of occurrences represented by this FIFO item.
  final int occurrenceCount;

  /// Creates a replacement for deduplication without changing report identity.
  ///
  /// Only occurrence metadata changes so the original queue position, source,
  /// primitive snapshots, and event identifier remain stable.
  ErrorReport copyWith({DateTime? lastOccurredAt, int? occurrenceCount}) {
    return ErrorReport(
      eventId: eventId,
      source: source,
      severity: severity,
      firstOccurredAt: firstOccurredAt,
      lastOccurredAt: lastOccurredAt ?? this.lastOccurredAt,
      errorType: errorType,
      playerErrorCode: playerErrorCode,
      message: message,
      rawStackTrace: rawStackTrace,
      mediaPath: mediaPath,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
    );
  }
}

/// 面向未来卡片宿主的不可变呈现快照。
///
/// Immutable state consumed by a future ValueListenableBuilder presentation
/// host. The reporter owns the backing queue and replaces this value on change.
final class ErrorPresentationState {
  /// Creates the current presentation snapshot.
  const ErrorPresentationState({
    required this.current,
    required this.pendingCount,
    required this.isReady,
  });

  /// The FIFO head available for presentation, if readiness was announced.
  final ErrorReport? current;

  /// Number of reports behind [current], or all queued reports before ready.
  final int pendingCount;

  /// Whether the future presentation host has announced readiness.
  final bool isReady;
}
