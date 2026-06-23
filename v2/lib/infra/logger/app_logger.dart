import 'dart:io';

import 'package:flutter/foundation.dart';

/// 日志级别
enum _LogLevel { debug, info, warn, error }

/// 转轮文件输出器 — 2MB 上限，保留 5 个归档
class _RotatingFileOutput {
  _RotatingFileOutput(this._directory, {int maxBytes = 2 * 1024 * 1024, int maxArchives = 5})
      : _maxBytes = maxBytes,
        _maxArchives = maxArchives;

  final Directory _directory;
  final int _maxBytes;
  final int _maxArchives;
  IOSink? _sink;

  /// 初始化：创建目录 + 打开当前日志文件
  void init() {
    _directory.createSync(recursive: true);
    _openSink();
  }

  void write(String line) {
    final sink = _sink;
    if (sink == null) return;
    sink.writeln(line);
    // 非精确大小检查（无锁环境足够）
    if (_currentSize > _maxBytes) {
      _rotate();
    }
  }

  void close() {
    _sink?.flush();
    _sink?.close();
    _sink = null;
  }

  // ── private ──────────────────────────────────────────────

  String get _currentPath =>
      '${_directory.path}${Platform.pathSeparator}app_${_timestampForFile()}.log';

  int _currentSize = 0;

  void _openSink() {
    final file = File(_currentPath);
    _sink = file.openWrite(mode: FileMode.append);
    _currentSize = file.existsSync() ? file.lengthSync() : 0;
  }

  void _rotate() {
    _sink?.flush();
    _sink?.close();
    _cleanupOldArchives();
    _openSink();
  }

  void _cleanupOldArchives() {
    final files = _directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    // 保留最新的 maxArchives 个文件
    while (files.length >= _maxArchives) {
      files.first.deleteSync();
      files.removeAt(0);
    }
  }

  static String _timestampForFile() {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)}_'
        '${pad(now.hour)}-${pad(now.minute)}-${pad(now.second)}';
  }
}

/// 应用日志器
///
/// - debug 模式：仅 debugPrint（开发控制台）
/// - release 模式：同时写入文件（旋转归档）
/// - 使用前调用 [initLog] 初始化文件日志（debug 模式下为空操作）
class AppLogger {
  static _RotatingFileOutput? _fileOutput;
  static bool _initialized = false;

  /// 初始化文件日志，仅在 release 模式生效
  static Future<void> initLog() async {
    if (_initialized) return;
    _initialized = true;
    if (kDebugMode) return; // debug 模式：无文件日志

    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    final logDir = Directory('$appData\\SimplePlayer\\logs');
    _fileOutput = _RotatingFileOutput(logDir)..init();
  }

  // ── 4-level static API ───────────────────────────────────

  static void debug(String tag, String msg) {
    assert(() {
      debugPrint('[$tag] $msg');
      return true;
    }());
    _writeFile(_LogLevel.debug, tag, msg);
  }

  static void info(String tag, String msg) {
    debugPrint('[$tag] INFO: $msg');
    _writeFile(_LogLevel.info, tag, msg);
  }

  static void warn(String tag, String msg) {
    debugPrint('[$tag] WARN: $msg');
    _writeFile(_LogLevel.warn, tag, msg);
  }

  static void error(String tag, String msg, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$tag] ERROR: $msg${error != null ? ' ($error)' : ''}');
    final buffer = StringBuffer(msg);
    if (error != null) buffer.write(' ($error)');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    _writeFile(_LogLevel.error, tag, buffer.toString());
  }

  // ── private ──────────────────────────────────────────────

  static void _writeFile(_LogLevel level, String tag, String msg) {
    if (kDebugMode) return;
    final output = _fileOutput;
    if (output == null) return;

    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final time = '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}';
    final levelStr = level.name.toUpperCase();
    output.write('[$levelStr] $time [$tag] $msg');
  }
}
