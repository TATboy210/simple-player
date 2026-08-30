/// 可信定位的不可变 formatter-facing 契约。
///
/// Immutable formatter-facing location contract. Later plans enrich this value
/// from trusted project frames and optional source-line evidence.
library;

/// 单个已格式化的项目栈帧。
///
/// One already-formatted project stack frame retained as diagnostic evidence.
final class ErrorLocationFrame {
  /// Creates an immutable project-frame snapshot.
  const ErrorLocationFrame({
    required this.file,
    required this.line,
    required this.member,
  });

  /// Project-relative or trusted absolute source-file reference.
  final String file;

  /// One-based source line number.
  final int line;

  /// Captured class or method description when the stack supplies one.
  final String member;
}

/// 报告的可选可信源码位置；null 表示尚未富化。
///
/// Optional trusted source location for a report. A null report location is a
/// deliberate D-05 fallback, not an extraction error.
final class ErrorLocation {
  /// Creates immutable primary, secondary, and optional source-line evidence.
  const ErrorLocation({
    required this.primaryFrame,
    this.secondaryFrames = const [],
    this.sourceLines = const [],
  });

  /// First trusted project frame selected for developer-facing evidence.
  final ErrorLocationFrame primaryFrame;

  /// At most two following project frames retained for context.
  final List<ErrorLocationFrame> secondaryFrames;

  /// Optional trusted source excerpts, populated only by later enrichment.
  final List<String> sourceLines;
}
