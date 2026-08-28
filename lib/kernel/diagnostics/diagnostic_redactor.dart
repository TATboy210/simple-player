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
    final output = StringBuffer();
    var index = 0;
    while (index < value.length) {
      final pathStart = _pathStartAt(value, index);
      if (pathStart == null) {
        output.write(value[index]);
        index += 1;
        continue;
      }

      final token = _readPathToken(value, pathStart);
      output.write(value.substring(index, pathStart));
      output.write(redactPathValue(token.value));
      index = token.end;
    }
    return output.toString();
  }

  /// Recognizes local path starts after rejecting non-file URI schemes first.
  static int? _pathStartAt(String value, int index) {
    if (_hasNonFileUriSchemeBefore(value, index)) return null;
    if (_startsWithIgnoreCase(value, index, 'file://')) return index;
    if (_startsWith(value, index, r'\\')) return index;
    if (_isDrivePathStart(value, index) || _isPosixPathStart(value, index)) {
      return index;
    }
    return null;
  }

  /// Reads one local token without treating valid filename spaces as boundaries.
  ///
  /// Diagnostic paths can contain spaces, parentheses, and brackets. A scanner
  /// therefore stops only at quotes, line breaks, source locations, and trailing
  /// diagnostic punctuation instead of the former whitespace-terminated regexes.
  static _PathToken _readPathToken(String value, int start) {
    final quote = _openingQuoteBefore(value, start);
    var end = start;
    while (end < value.length) {
      if (_isTokenBoundary(value, end, quote)) break;
      end += 1;
    }
    return _PathToken(value.substring(start, end), end);
  }

  static bool _isTokenBoundary(String value, int index, String? quote) {
    final character = value[index];
    if (quote != null && character == quote) return true;
    if (character == '\n' || character == '\r' || character == '"') {
      return true;
    }
    if (_isSourceLocationAt(value, index)) return true;
    if ((character == ')' || character == ']') &&
        _closesDiagnostic(value, index)) {
      return true;
    }
    return false;
  }

  /// Keeps a closing bracket inside a filename unless it closes surrounding text.
  static bool _closesDiagnostic(String value, int index) {
    final next = index + 1;
    return next >= value.length ||
        value[next] == ':' ||
        value[next] == ',' ||
        value[next] == '\n' ||
        value[next] == '\r' ||
        value[next] == ' ';
  }

  static bool _isSourceLocationAt(String value, int index) {
    if (value[index] != ':') return false;
    final lineStart = index + 1;
    final lineEnd = _digitsEnd(value, lineStart);
    if (lineEnd == lineStart ||
        lineEnd >= value.length ||
        value[lineEnd] != ':') {
      return false;
    }
    final columnStart = lineEnd + 1;
    return _digitsEnd(value, columnStart) > columnStart;
  }

  static int _digitsEnd(String value, int index) {
    var end = index;
    while (end < value.length && _isDigit(value.codeUnitAt(end))) {
      end += 1;
    }
    return end;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  static String? _openingQuoteBefore(String value, int start) {
    if (start == 0) return null;
    final preceding = value[start - 1];
    return preceding == '"' || preceding == "'" ? preceding : null;
  }

  static bool _isDrivePathStart(String value, int index) {
    if (index + 2 >= value.length || !_isAsciiLetter(value.codeUnitAt(index))) {
      return false;
    }
    // A drive designator is a standalone letter, never the final character of
    // a URI scheme such as `http:/`.
    if (index > 0 && _isAsciiLetter(value.codeUnitAt(index - 1))) return false;
    return value[index + 1] == ':' && _isSeparator(value[index + 2]);
  }

  static bool _isPosixPathStart(String value, int index) {
    if (value[index] != '/') return false;
    if (index == 0) return true;
    // Inspect the whole token because either slash in `https://` can otherwise
    // look like a POSIX root after its preceding slash is encountered.
    var tokenStart = index;
    while (tokenStart > 0 && !_isWhitespace(value.codeUnitAt(tokenStart - 1))) {
      tokenStart -= 1;
    }
    final tokenPrefix = value.substring(tokenStart, index);
    if (RegExp(r'^[A-Za-z]+:/*$').hasMatch(tokenPrefix) &&
        !tokenPrefix.toLowerCase().startsWith('file:')) {
      return false;
    }
    return !_isUriContinuation(value.codeUnitAt(index - 1));
  }

  static bool _hasNonFileUriSchemeBefore(String value, int index) {
    // URLs may contain several slashes, so inspect the current whitespace-delimited
    // token rather than only the three preceding characters at this slash.
    var tokenStart = index;
    while (tokenStart > 0 && !_isWhitespace(value.codeUnitAt(tokenStart - 1))) {
      tokenStart -= 1;
    }
    final token = value.substring(tokenStart, index);
    final match = RegExp(r'^([A-Za-z]+):/+$').firstMatch(token);
    final scheme = match?.group(1)?.toLowerCase();
    return scheme != null && scheme != 'file';
  }

  static bool _isUriContinuation(int codeUnit) =>
      _isAsciiLetter(codeUnit) || _isDigit(codeUnit) || codeUnit == 46;

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 32 || codeUnit == 9 || codeUnit == 10 || codeUnit == 13;

  static bool _isAsciiLetter(int codeUnit) =>
      (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);

  static bool _isSeparator(String value) => value == '/' || value == r'\';

  static bool _startsWith(String value, int index, String prefix) =>
      value.startsWith(prefix, index);

  static bool _startsWithIgnoreCase(String value, int index, String prefix) {
    final end = index + prefix.length;
    return end <= value.length &&
        value.substring(index, end).toLowerCase() == prefix.toLowerCase();
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

/// Internal scanner result preserves the exclusive end index in source text.
final class _PathToken {
  const _PathToken(this.value, this.end);

  final String value;
  final int end;
}
