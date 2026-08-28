/// Injectable dependencies for deterministic, failure-isolated error reporting.
library;

import 'error_report.dart';
import 'clock.dart';

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
typedef ErrorReportEffect =
    void Function(ErrorReport report, ReportAcceptance acceptance);

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
