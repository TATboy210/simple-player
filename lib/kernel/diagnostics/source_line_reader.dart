/// 可信源码根内的小窗口源码读取。
///
/// Reads source evidence only when a project-owned root is established and the
/// build mode permits it. Every rejected input degrades without throwing.
library;

import 'dart:convert';
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

/// Reads runtime package metadata through an owned, injectable boundary.
abstract interface class SourcePackageConfigAccess {
  /// Returns the runtime package-config URI string, or null when unavailable.
  String? get packageConfigPath;

  /// Reads package-config JSON text, or null when it cannot be obtained.
  String? readConfig(String packageConfigPath);

  /// Confirms the resolved project root contains the expected source directory.
  bool hasSourceDirectory(String root);
}

/// Production `dart:io` implementation that contains filesystem failures.
final class DartIoSourceFileAccess
    implements SourceFileAccess, SourcePackageConfigAccess {
  /// Creates the production source-file access seam.
  const DartIoSourceFileAccess();

  @override
  String? get packageConfigPath => Platform.packageConfig;

  @override
  String? readConfig(String packageConfigPath) {
    try {
      final configUri = Uri.tryParse(packageConfigPath);
      if (configUri == null || configUri.scheme != 'file') {
        return null;
      }
      return File.fromUri(configUri).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  bool hasSourceDirectory(String root) => Directory('$root/lib').existsSync();

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
/// executable directory when application-owned package resolution is unavailable.
final class SourceLineReader {
  /// Production construction resolves the owned diagnostics package through pub's config.
  factory SourceLineReader() {
    const fileAccess = DartIoSourceFileAccess();
    return SourceLineReader._(
      _resolveTrustedRoot(fileAccess, fileAccess),
      _runtimeBuildMode(),
      fileAccess,
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

  /// Resolves the production root with an injectable runtime-config path for tests.
  @visibleForTesting
  factory SourceLineReader.fromPackageConfigForTesting({
    required SourceReadBuildMode buildMode,
    required SourceFileAccess fileAccess,
    required SourcePackageConfigAccess packageConfigAccess,
  }) {
    return SourceLineReader._(
      _resolveTrustedRoot(fileAccess, packageConfigAccess),
      buildMode,
      fileAccess,
    );
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

/// Resolves this application's package root from the active pub package configuration.
///
/// The config location comes from the Dart runtime, not cwd or the executable path.
/// Only the exact project package and an existing `lib/` directory establish trust.
String? _resolveTrustedRoot(
  SourceFileAccess fileAccess,
  SourcePackageConfigAccess packageConfigAccess,
) {
  final configPath = packageConfigAccess.packageConfigPath;
  if (configPath == null) {
    return null;
  }
  try {
    final configUri = _packageConfigUri(configPath);
    final configText = packageConfigAccess.readConfig(configPath);
    if (configUri == null || configText == null) {
      return null;
    }
    final config = jsonDecode(configText);
    if (config is! Map<String, Object?>) {
      return null;
    }
    final packages = config['packages'];
    if (packages is! List<Object?>) {
      return null;
    }
    for (final package in packages) {
      final root = _projectRootFromPackageEntry(
        package,
        configUri.resolve('.').toFilePath(),
      );
      if (root == null) {
        continue;
      }
      final canonicalRoot = fileAccess.canonicalize(root);
      if (canonicalRoot == null ||
          !packageConfigAccess.hasSourceDirectory(canonicalRoot)) {
        return null;
      }
      return canonicalRoot;
    }
  } on FormatException {
    // Invalid package metadata must not establish a filesystem root.
  }
  return null;
}

/// Accepts only an absolute file URI or absolute filesystem path supplied by Dart.
Uri? _packageConfigUri(String configPath) {
  final parsed = Uri.tryParse(configPath);
  if (parsed != null && parsed.scheme == 'file') {
    return parsed;
  }
  if (!Platform.isWindows && configPath.startsWith('/')) {
    return Uri.file(configPath);
  }
  if (Platform.isWindows && RegExp(r'^[A-Za-z]:[\\/]').hasMatch(configPath)) {
    return Uri.file(configPath, windows: true);
  }
  return null;
}

/// Extracts the application root only from the exact owned package entry.
String? _projectRootFromPackageEntry(Object? entry, String configDirectory) {
  if (entry is! Map<String, Object?> || entry['name'] != projectPackageName) {
    return null;
  }
  final rootUri = entry['rootUri'];
  if (rootUri is! String || rootUri.isEmpty) {
    return null;
  }
  final parsedRoot = Uri.tryParse(rootUri);
  if (parsedRoot == null) {
    return null;
  }
  final absoluteRoot = parsedRoot.scheme.isEmpty
      ? Uri.directory(configDirectory).resolveUri(parsedRoot)
      : parsedRoot;
  final packageUri = entry['packageUri'];
  if (packageUri is! String || packageUri != 'lib/') {
    return null;
  }
  if (absoluteRoot.scheme != 'file') {
    return null;
  }
  return _normalizePath(absoluteRoot.toFilePath());
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
