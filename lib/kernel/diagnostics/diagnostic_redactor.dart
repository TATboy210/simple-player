/// 诊断文本脱敏策略 — 在错误报告进入队列前移除本机路径前缀。
///
/// Sanitizes local filesystem paths while retaining the filename and source
/// location useful for developer diagnostics. Network URLs stay untouched.
library;

/// 用于诊断快照的确定性本地路径脱敏器。
///
/// One policy is shared by path-valued fields and embedded diagnostic text so
/// queue, effects, and presentation can only observe the same safe snapshot.
final class DiagnosticRedactor {
  /// Redacts a standalone media-path value when it denotes a local path.
  static String redactPathValue(String value) {
    final fileUri = Uri.tryParse(value);
    if (fileUri != null && fileUri.scheme == 'file') {
      return _basename(Uri.decodeComponent(fileUri.path));
    }
    if (_isLocalPath(value)) return _basename(value);
    return value;
  }

  /// Redacts local path fragments embedded in untrusted diagnostic text.
  static String redactDiagnosticText(String value) {
    final withoutFileUris = value.replaceAllMapped(
      RegExp(r'file://[^\s\]\)]+', caseSensitive: false),
      (match) => redactPathValue(match[0] ?? ''),
    );
    final withoutUncPaths = withoutFileUris.replaceAllMapped(
      RegExp(r'\\\\[^\s\]\)]+'),
      (match) => _basename(match[0] ?? ''),
    );
    final withoutWindowsPaths = withoutUncPaths.replaceAllMapped(
      RegExp(r'(?<![A-Za-z])[A-Za-z]:[\\/][^\s\]\)]+'),
      (match) => _basename(match[0] ?? ''),
    );
    return withoutWindowsPaths.replaceAllMapped(
      RegExp(r'(?<![:/\w])/(?:[^\s/]+/)+[^\s\]\)]+'),
      (match) => _basename(match[0] ?? ''),
    );
  }

  /// Determines whether [value] is a local filesystem representation.
  static bool _isLocalPath(String value) {
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value) ||
        value.startsWith(r'\\') ||
        value.startsWith('/');
  }

  /// Keeps the final useful path component and optional source location suffix.
  static String _basename(String value) {
    final normalized = value.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }
}
