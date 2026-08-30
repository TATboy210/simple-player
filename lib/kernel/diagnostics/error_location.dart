/// 从冻结 raw stack 提取的可信项目定位。
///
/// Immutable location evidence extracted exclusively from the raw stack retained
/// by an accepted error report. Parse failures degrade to no location evidence.
library;

import 'package:flutter/foundation.dart';

/// The only package accepted as project-owned diagnostic evidence.
const String projectPackageName = 'simple_player_flutter';

/// The Flutter SDK VM-frame grammar used to reject malformed `#` lines first.
final RegExp _vmFramePattern = RegExp(
  r'^#(\d+) +(.+) \((.+?):?(\d+){0,1}:?(\d+){0,1}\)$',
);

/// 单个已格式化的项目栈帧。
///
/// Immutable project stack-frame evidence. [packageScheme], [package], and
/// [packagePath] preserve the parsed source identity for trusted readers.
final class ErrorLocationFrame {
  /// Creates an immutable project-frame snapshot.
  const ErrorLocationFrame({
    required this.file,
    required this.packageScheme,
    required this.package,
    required this.packagePath,
    required this.line,
    required this.column,
    required this.member,
  });

  /// Stable source reference such as `package:simple_player_flutter/foo.dart`.
  final String file;

  /// Parsed URI scheme, retained for later trusted source resolution.
  final String packageScheme;

  /// Parsed package name, retained for exact project ownership checks.
  final String package;

  /// Package-relative or absolute path parsed by Flutter's [StackFrame].
  final String packagePath;

  /// One-based source line number.
  final int line;

  /// One-based source column number, or -1 when absent.
  final int column;

  /// Captured class or method description when the stack supplies one.
  final String member;
}

/// 报告的可选可信源码位置；null 表示没有项目帧。
///
/// Immutable project-frame location for a report. A null value is the explicit
/// D-05 fallback: no project frame was found in the frozen raw stack.
final class ErrorLocation {
  /// Creates immutable primary, secondary, and optional source-line evidence.
  ErrorLocation({
    required this.primaryFrame,
    List<ErrorLocationFrame> secondaryFrames = const [],
    List<String> sourceLines = const [],
  }) : secondaryFrames = List<ErrorLocationFrame>.unmodifiable(secondaryFrames),
       sourceLines = List<String>.unmodifiable(sourceLines);

  /// First trusted project frame selected for developer-facing evidence.
  final ErrorLocationFrame primaryFrame;

  /// At most two following project frames retained for context.
  final List<ErrorLocationFrame> secondaryFrames;

  /// Optional trusted source excerpts, populated only after containment checks.
  final List<String> sourceLines;
}

/// 从已冻结的 raw stack 保守提取首个项目帧与最多两个后续帧。
///
/// Extracts project evidence only from [rawStackTrace], never from a live stack
/// or filesystem. Malformed and unsupported input returns the D-05 null
/// fallback rather than creating a second diagnostic failure.
ErrorLocation? extractErrorLocation(String rawStackTrace) {
  final projectFrames = _parseFrames(rawStackTrace)
      .where((frame) => frame.package == projectPackageName)
      .map(_toLocationFrame)
      .toList(growable: false);
  if (projectFrames.isEmpty) {
    return null;
  }
  return ErrorLocation(
    primaryFrame: projectFrames.first,
    secondaryFrames: projectFrames.skip(1).take(2).toList(growable: false),
  );
}

/// Parses only SDK-supported lines so malformed VM records cannot reach `match!`.
List<StackFrame> _parseFrames(String rawStackTrace) {
  try {
    final parsableLines = rawStackTrace.split('\n').where(_isSafeStackLine);
    return StackFrame.fromStackString(parsableLines.join('\n'))
        .where((frame) => frame.line >= 0)
        .toList(growable: false);
  } on Object {
    // Parsing is a diagnostic boundary: less evidence is always safer than throw.
    return const <StackFrame>[];
  }
}

/// Allows web-style lines through Flutter while filtering unsafe VM-prefixed lines.
bool _isSafeStackLine(String line) =>
    !line.startsWith('#') || _vmFramePattern.hasMatch(line);

/// Converts Flutter's parsed frame into stable immutable formatter evidence.
ErrorLocationFrame _toLocationFrame(StackFrame frame) {
  final memberParts = [
    frame.className,
    frame.method,
  ].where((part) => part.isNotEmpty).toList(growable: false);
  return ErrorLocationFrame(
    file: '${frame.packageScheme}:${frame.package}/${frame.packagePath}',
    packageScheme: frame.packageScheme,
    package: frame.package,
    packagePath: frame.packagePath,
    line: frame.line,
    column: frame.column,
    member: memberParts.join('.'),
  );
}
