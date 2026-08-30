/// 可信源码根内的小窗口源码读取。
///
/// Reads source evidence only when a project-owned root is established and the
/// build mode permits it. Every rejected input degrades without throwing.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'error_location.dart';

/// Controls whether diagnostic source I/O is permitted for a build.
enum SourceReadBuildMode {
  /// Development build may read trusted local source evidence.
  debug,

  /// Profile build may read trusted local source evidence.
  profile,

  /// Release build never touches the filesystem for source excerpts.
  release,
}

/// Immutable one-based source line retained as diagnostic evidence.
final class SourceLine {
  /// Creates a numbered source line snapshot.
  const SourceLine({required this.lineNumber, required this.text});

  /// Original one-based line number in the source file.
  final int lineNumber;

  /// Source text without its newline delimiter.
  final String text;
}

/// Immutable source window centered on a trusted location frame.
final class SourceExcerpt {
  /// Creates an immutable excerpt of at most five numbered source lines.
  SourceExcerpt({required List<SourceLine> lines})
    : lines = List<SourceLine>.unmodifiable(lines);

  /// Numbered source lines ordered as they occurred in the file.
  final List<SourceLine> lines;
}

/// Filesystem seam for deterministic containment and no-I/O release tests.
abstract interface class SourceFileAccess {
  /// Returns a canonical path when it can be resolved, otherwise null.
  String? canonicalize(String path);

  /// Reads source lines or returns null when the file cannot be read.
  List<String>? readLines(String path);
}

/// Production `dart:io` implementation that contains filesystem failures.
final class DartIoSourceFileAccess implements SourceFileAccess {
  /// Creates the production source-file access seam.
  const DartIoSourceFileAccess();

  @override
  String? canonicalize(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  List<String>? readLines(String path) {
    try {
      return File(path).readAsLinesSync();
    } on FileSystemException {
      return null;
    }
  }
}

/// 仅从受信项目根读取源码片段的 reader。
///
/// Maps application package frames to `<root>/lib/` and accepts file frames
/// only after component-aware containment. It never falls back to cwd or an
/// executable directory when self-anchored root capture is unavailable.
final class SourceLineReader {
  /// Production construction captures a root only from locator-owned frames.
  factory SourceLineReader() {
    return SourceLineReader._(
      _captureTrustedRoot(StackTrace.current),
      _runtimeBuildMode(),
      const DartIoSourceFileAccess(),
    );
  }

  /// Test-only construction exposes the root, mode, and filesystem seams.
  factory SourceLineReader.forTesting({
    required String? trustedRoot,
    required SourceReadBuildMode buildMode,
    SourceFileAccess fileAccess = const DartIoSourceFileAccess(),
  }) {
    return SourceLineReader._(trustedRoot, buildMode, fileAccess);
  }

  SourceLineReader._(String? trustedRoot, this._buildMode, this._fileAccess)
    : _trustedRoot = _normalizePath(trustedRoot);

  static const int _contextRadius = 2;

  final String? _trustedRoot;
  final SourceReadBuildMode _buildMode;
  final SourceFileAccess _fileAccess;

  /// Reads a target line plus up to two surrounding lines when fully trusted.
  SourceExcerpt? read(ErrorLocationFrame frame) {
    // Release must return before even canonicalizing a candidate filesystem path.
    if (_buildMode == SourceReadBuildMode.release) {
      return null;
    }
    final root = _trustedRoot;
    if (root == null || !_isValidRequestedLine(frame.line)) {
      return null;
    }
    final candidate = _candidatePath(root, frame);
    if (candidate == null || _hasTraversalSegment(candidate)) {
      return null;
    }
    final canonicalRoot = _fileAccess.canonicalize(root);
    final canonicalFile = _fileAccess.canonicalize(candidate);
    if (canonicalRoot == null || canonicalFile == null) {
      return null;
    }
    if (!_isContainedByRoot(canonicalRoot, canonicalFile)) {
      return null;
    }
    final sourceLines = _fileAccess.readLines(canonicalFile);
    if (sourceLines == null || frame.line > sourceLines.length) {
      return null;
    }
    return _excerptAround(sourceLines, frame.line);
  }

  /// Maps only exact project package or file frames into a prospective path.
  String? _candidatePath(String root, ErrorLocationFrame frame) {
    if (frame.packageScheme == 'package' &&
        frame.package == projectPackageName &&
        !_hasTraversalSegment(frame.packagePath)) {
      return '$root/lib/${frame.packagePath}';
    }
    if (frame.packageScheme == 'file' &&
        !_hasTraversalSegment(frame.packagePath)) {
      return _normalizePath(frame.packagePath);
    }
    return null;
  }

  /// Creates the bounded, one-based diagnostic window after all trust checks pass.
  SourceExcerpt _excerptAround(List<String> lines, int targetLine) {
    final firstIndex = (targetLine - 1 - _contextRadius).clamp(0, lines.length);
    final lastExclusive = (targetLine + _contextRadius).clamp(0, lines.length);
    return SourceExcerpt(
      lines: [
        for (var index = firstIndex; index < lastExclusive; index += 1)
          SourceLine(lineNumber: index + 1, text: lines[index]),
      ],
    );
  }
}

/// Determines the runtime mode without allowing source I/O in release builds.
SourceReadBuildMode _runtimeBuildMode() => kReleaseMode
    ? SourceReadBuildMode.release
    : kProfileMode
    ? SourceReadBuildMode.profile
    : SourceReadBuildMode.debug;

/// Captures a root only from an owned diagnostic file frame, never cwd/executable.
String? _captureTrustedRoot(StackTrace stackTrace) {
  final location = extractErrorLocation(stackTrace.toString());
  final primary = location?.primaryFrame;
  if (primary == null || primary.packageScheme != 'file') {
    return null;
  }
  final path = _normalizePath(primary.packagePath);
  const marker = '/lib/kernel/diagnostics/';
  final markerIndex = path?.toLowerCase().indexOf(marker);
  return markerIndex == null || markerIndex < 0
      ? null
      : path!.substring(0, markerIndex);
}

/// Normalizes separators and removes the URI-only Windows leading slash.
String? _normalizePath(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final slashed = value.replaceAll('\\', '/');
  final withoutWindowsUriSlash = RegExp(r'^/[A-Za-z]:/').hasMatch(slashed)
      ? slashed.substring(1)
      : slashed;
  return withoutWindowsUriSlash.replaceAll(RegExp(r'/+'), '/');
}

/// Rejects path traversal before canonicalization so no path escape is resolved.
bool _hasTraversalSegment(String path) =>
    path.replaceAll('\\', '/').split('/').any((segment) => segment == '..');

/// Validates the one-based target before any filesystem access.
bool _isValidRequestedLine(int line) => line > 0;

/// Checks canonical containment by complete components, never a string prefix.
bool _isContainedByRoot(String root, String file) {
  final normalizedRoot = _normalizePath(root);
  final normalizedFile = _normalizePath(file);
  if (normalizedRoot == null || normalizedFile == null) {
    return false;
  }
  final caseInsensitive =
      RegExp(r'^[A-Za-z]:/').hasMatch(normalizedRoot) ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalizedFile);
  final comparableRoot = caseInsensitive
      ? normalizedRoot.toLowerCase()
      : normalizedRoot;
  final comparableFile = caseInsensitive
      ? normalizedFile.toLowerCase()
      : normalizedFile;
  final rootWithSeparator = comparableRoot.endsWith('/')
      ? comparableRoot
      : '$comparableRoot/';
  return comparableFile.startsWith(rootWithSeparator);
}
