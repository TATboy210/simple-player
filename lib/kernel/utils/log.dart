import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' hide PrefixPrinter;

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

/// Module-scoped loggers. Initialized with debug defaults,
/// overwritten by [initLog] in release mode.
Logger logEngine = Logger(
  printer: PrefixPrinter(
    'engine',
    PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
);

Logger logBridge = Logger(
  printer: PrefixPrinter(
    'bridge',
    PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
);

Logger logServices = Logger(
  printer: PrefixPrinter(
    'services',
    PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
);

Logger logUi = Logger(
  printer: PrefixPrinter(
    'ui',
    PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
);

/// Optional JSON printer for log aggregation tools.
/// Not used by default output — PrettyPrinter is the default.
final jsonPrinter = JsonPrinter();

/// Wraps a [LogPrinter] to prepend a module name prefix to each output line.
///
/// Example: `PrefixPrinter('engine', PrettyPrinter())` produces lines like
/// `[engine] 12:34:56 message here`.
class PrefixPrinter extends LogPrinter {
  PrefixPrinter(this._prefix, this._inner);

  final String _prefix;
  final LogPrinter _inner;

  @override
  List<String> log(LogEvent event) {
    final innerLines = _inner.log(event);
    return innerLines
        .map((line) => line.isEmpty ? line : '[$_prefix] $line')
        .toList();
  }
}

/// Simple JSON printer for structured log output.
///
/// Produces one JSON object per log line with level, message, and time fields.
/// Used optionally by log aggregation tools — not the default output format.
class JsonPrinter extends LogPrinter {
  JsonPrinter();

  @override
  List<String> log(LogEvent event) {
    final buffer = StringBuffer()
      ..write('{"level":"${event.level.name}",')
      ..write('"message":"${_escapeJson(event.message.toString())}",')
      ..write('"time":"${event.time.toIso8601String()}"');
    if (event.error != null) {
      buffer.write(',"error":"${_escapeJson(event.error.toString())}"');
    }
    if (event.stackTrace != null) {
      buffer.write(
        ',"stackTrace":"${_escapeJson(event.stackTrace.toString())}"',
      );
    }
    buffer.write('}');
    return [buffer.toString()];
  }

  String _escapeJson(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }
}

/// Initialize file logging for release builds.
///
/// In debug mode this is a no-op (console output only).
/// In release mode, configures all 5 loggers (global + 4 module) with
/// shared [PrettyPrinter] (no colors), [ProductionFilter] (warning+),
/// and [MultiOutput] (console + rotating file).
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

    final printer = PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 100,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    );
    final filter = ProductionFilter();
    final output = MultiOutput([
      ConsoleOutput(),
      _RotatingFileOutput(dir, file, maxBytes: 2 * 1024 * 1024),
    ]);

    // Global logger — no prefix (backward compat)
    log = Logger(
      filter: filter,
      printer: printer,
      level: Level.warning,
      output: output,
    );

    // Module loggers — PrefixPrinter wraps the shared printer
    logEngine = Logger(
      filter: filter,
      printer: PrefixPrinter('engine', printer),
      level: Level.warning,
      output: output,
    );
    logBridge = Logger(
      filter: filter,
      printer: PrefixPrinter('bridge', printer),
      level: Level.warning,
      output: output,
    );
    logServices = Logger(
      filter: filter,
      printer: PrefixPrinter('services', printer),
      level: Level.warning,
      output: output,
    );
    logUi = Logger(
      filter: filter,
      printer: PrefixPrinter('ui', printer),
      level: Level.warning,
      output: output,
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
    final sink = _sink;
    if (sink == null) return;
    for (final line in event.lines) {
      sink.writeln(line);
    }
    sink.flush();

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
