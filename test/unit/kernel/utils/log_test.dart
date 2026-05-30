import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' as log_lib;
import 'package:simple_player_flutter/kernel/utils/log.dart';

/// Captures log output lines for test assertions.
class _TestOutput extends log_lib.LogOutput {
  final List<String> lines = [];

  @override
  void output(log_lib.OutputEvent event) {
    lines.addAll(event.lines);
  }

  @override
  Future<void> destroy() async {
    lines.clear();
  }
}

void main() {
  group('PrefixPrinter', () {
    test('prepends module name to each output line', () {
      final inner = log_lib.PrettyPrinter(methodCount: 0, colors: false);
      final printer = PrefixPrinter('engine', inner);

      final event = log_lib.LogEvent(log_lib.Level.info, 'test message');
      final lines = printer.log(event);

      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line, startsWith('[engine] '));
      }
    });

    test('different module names produce different prefixes', () {
      final inner = log_lib.PrettyPrinter(methodCount: 0, colors: false);
      final enginePrinter = PrefixPrinter('engine', inner);
      final bridgePrinter = PrefixPrinter('bridge', inner);

      final event = log_lib.LogEvent(log_lib.Level.info, 'test message');
      final engineLines = enginePrinter.log(event);
      final bridgeLines = bridgePrinter.log(event);

      expect(engineLines.first, startsWith('[engine] '));
      expect(bridgeLines.first, startsWith('[bridge] '));
    });

    test('preserves inner printer output content', () {
      final inner = log_lib.PrettyPrinter(methodCount: 0, colors: false);
      final printer = PrefixPrinter('services', inner);

      final event = log_lib.LogEvent(log_lib.Level.warning, 'warning msg');
      final lines = printer.log(event);

      expect(lines, isNotEmpty);
      // PrettyPrinter adds box borders; message is in one of the lines
      expect(lines.any((l) => l.contains('warning msg')), isTrue);
      for (final line in lines) {
        expect(line, startsWith('[services] '));
      }
    });
  });

  group('module loggers', () {
    test('logEngine is non-null Logger instance', () {
      expect(logEngine, isA<log_lib.Logger>());
    });

    test('logBridge is non-null Logger instance', () {
      expect(logBridge, isA<log_lib.Logger>());
    });

    test('logServices is non-null Logger instance', () {
      expect(logServices, isA<log_lib.Logger>());
    });

    test('logUi is non-null Logger instance', () {
      expect(logUi, isA<log_lib.Logger>());
    });
  });

  group('jsonPrinter', () {
    test('is LogPrinter instance', () {
      expect(jsonPrinter, isA<log_lib.LogPrinter>());
    });
  });

  group('initLog release mode config', () {
    test('PrefixPrinter with Logger prefixes output correctly', () {
      final inner = log_lib.PrettyPrinter(methodCount: 0, colors: false);
      final output = _TestOutput();
      final logger = log_lib.Logger(
        printer: PrefixPrinter('test', inner),
        filter: log_lib.ProductionFilter(),
        level: log_lib.Level.warning,
        output: output,
      );

      logger.w('warning message');
      expect(output.lines, isNotEmpty);
      expect(output.lines.any((l) => l.contains('[test] ')), isTrue);
      expect(output.lines.any((l) => l.contains('warning message')), isTrue);
    });

    test('ProductionFilter with Level.warning blocks debug messages', () {
      final output = _TestOutput();
      final logger = log_lib.Logger(
        printer: log_lib.PrettyPrinter(methodCount: 0, colors: false),
        filter: log_lib.ProductionFilter(),
        level: log_lib.Level.warning,
        output: output,
      );

      logger.d('debug message');
      expect(output.lines, isEmpty);
    });

    test('ProductionFilter with Level.warning passes warning messages', () {
      final output = _TestOutput();
      final logger = log_lib.Logger(
        printer: log_lib.PrettyPrinter(methodCount: 0, colors: false),
        filter: log_lib.ProductionFilter(),
        level: log_lib.Level.warning,
        output: output,
      );

      logger.w('warning message');
      expect(output.lines, isNotEmpty);
    });
  });
}
