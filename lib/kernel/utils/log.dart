import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Kernel-wide logger. Uses PrettyPrinter with minimal method count
/// for compact desktop output. Only logs in debug mode (default filter).
///
/// Call [initLog] during startup to add file output in release mode.
/// Logs are written to `%APPDATA%\SimplePlayer\logs\` with 2 MB rotation.
Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 4,
    lineLength: 100,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Initialize file logging for release builds.
///
/// In debug mode this is a no-op (console output only).
/// In release mode, appends a [RotatingFileOutput] that writes to
/// `%APPDATA%\SimplePlayer\logs\app_<timestamp>.log` with 2 MB rotation.
Future<void> initLog() async {
  if (kDebugMode) return;

  try {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return;

    final dir = Directory('$appData\\SimplePlayer\\logs');
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_');
    final file = File('${dir.path}\\app_$timestamp.log');

    log = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: 100,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput([
        ConsoleOutput(),
        _RotatingFileOutput(dir, file, maxBytes: 2 * 1024 * 1024),
      ]),
    );
  } on Exception catch (e) {
    debugPrint('[Log] file logging init failed: $e');
  }
}

/// File output with size-based rotation.
///
/// When [_file] exceeds [maxBytes], renames it to an archive and creates
/// a fresh file. Keeps at most 5 archives.
class _RotatingFileOutput extends LogOutput {
  _RotatingFileOutput(this._dir, this._file, {this.maxBytes = 2 * 1024 * 1024});

  final Directory _dir;
  File _file;
  final int maxBytes;
  IOSink? _sink;

  void _ensureSink() {
    _sink ??= _file.openWrite(mode: FileMode.append);
  }

  @override
  void output(OutputEvent event) {
    _ensureSink();
    for (final line in event.lines) {
      _sink!.writeln(line);
    }
    _sink!.flush();

    if (_file.existsSync() && _file.lengthSync() > maxBytes) {
      _rotate();
    }
  }

  void _rotate() {
    _sink?.flush();
    _sink?.close();
    _sink = null;

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .replaceAll('T', '_');
    final archive = File('${_dir.path}\\app_$timestamp.log');
    try {
      _file.renameSync(archive.path);
    } on Exception {
      // rename failed — continue with current file
    }
    _file = File(
      '${_dir.path}\\app_${DateTime.now().millisecondsSinceEpoch}.log',
    );
    _cleanupArchives();
  }

  void _cleanupArchives() {
    final archives =
        _dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('app_') && f.path.endsWith('.log'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final old in archives.skip(5)) {
      try {
        old.deleteSync();
      } on Exception {
        // ignore cleanup failures
      }
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
  }
}
