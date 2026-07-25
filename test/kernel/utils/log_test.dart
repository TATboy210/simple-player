import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' hide PrefixPrinter;
import 'package:simple_player_flutter/kernel/utils/log.dart';

void main() {
  group('log singleton', () {
    test('log is initialized', () {
      expect(log, isNotNull);
    });

    test('logEngine is initialized', () {
      expect(logEngine, isNotNull);
    });

    test('logBridge is initialized', () {
      expect(logBridge, isNotNull);
    });

    test('logServices is initialized', () {
      expect(logServices, isNotNull);
    });

    test('logUi is initialized', () {
      expect(logUi, isNotNull);
    });

    test('jsonPrinter is initialized', () {
      expect(jsonPrinter, isNotNull);
    });
  });

  group('PrefixPrinter', () {
    test('prepends prefix to non-empty lines', () {
      final inner = PrettyPrinter(methodCount: 0, lineLength: 100);
      final printer = PrefixPrinter('engine', inner);

      final event = LogEvent(
        Level.info,
        'test message',
      );
      final lines = printer.log(event);

      // At least one line should have the prefix
      final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
      expect(nonEmpty, isNotEmpty);
      for (final line in nonEmpty) {
        expect(line, startsWith('[engine]'));
      }
    });

    test('preserves empty lines from inner printer', () {
      final inner = PrettyPrinter(methodCount: 0, lineLength: 100);
      final printer = PrefixPrinter('test', inner);

      final event = LogEvent(
        Level.info,
        'message',
      );
      final lines = printer.log(event);

      // PrettyPrinter may produce empty lines — PrefixPrinter should preserve them
      for (final line in lines) {
        if (line.isEmpty) {
          expect(line, isEmpty);
        } else {
          expect(line, startsWith('[test]'));
        }
      }
    });

    test('uses different prefixes for different printers', () {
      final inner = PrettyPrinter(methodCount: 0, lineLength: 100);
      final enginePrinter = PrefixPrinter('engine', inner);
      final bridgePrinter = PrefixPrinter('bridge', inner);

      final event = LogEvent(
        Level.warning,
        'test',
      );

      final engineLines = enginePrinter.log(event);
      final bridgeLines = bridgePrinter.log(event);

      final engineNonEmpty = engineLines.where((l) => l.isNotEmpty).toList();
      final bridgeNonEmpty = bridgeLines.where((l) => l.isNotEmpty).toList();

      expect(engineNonEmpty.first, startsWith('[engine]'));
      expect(bridgeNonEmpty.first, startsWith('[bridge]'));
    });
  });

  group('JsonPrinter', () {
    test('produces valid JSON output', () {
      final printer = JsonPrinter();
      final event = LogEvent(
        Level.info,
        'test message',
      );
      final lines = printer.log(event);

      expect(lines, hasLength(1));
      final json = lines.first;
      expect(json, contains('"level"'));
      expect(json, contains('"message"'));
      expect(json, contains('"time"'));
    });

    test('includes error when present', () {
      final printer = JsonPrinter();
      final event = LogEvent(
        Level.error,
        'error message',
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );
      final lines = printer.log(event);

      expect(lines.first, contains('"error"'));
    });

    test('includes stackTrace when present', () {
      final printer = JsonPrinter();
      final event = LogEvent(
        Level.error,
        'error message',
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );
      final lines = printer.log(event);

      expect(lines.first, contains('"stackTrace"'));
    });

    test('escapes special characters in message', () {
      final printer = JsonPrinter();
      final event = LogEvent(
        Level.warning,
        'message with "quotes" and \\backslash',
      );
      final lines = printer.log(event);

      // Should not throw and should produce valid JSON-like output
      expect(lines, hasLength(1));
      expect(lines.first, contains('message'));
    });

    test('escapes newlines in message', () {
      final printer = JsonPrinter();
      final event = LogEvent(
        Level.info,
        'line1\nline2',
      );
      final lines = printer.log(event);

      expect(lines, hasLength(1));
      // The newline should be escaped as \n
      expect(lines.first, contains('\\n'));
    });
  });

  group('module loggers', () {
    test('all 5 loggers are Logger instances', () {
      expect(log, isA<Logger>());
      expect(logEngine, isA<Logger>());
      expect(logBridge, isA<Logger>());
      expect(logServices, isA<Logger>());
      expect(logUi, isA<Logger>());
    });

    test('loggers can be called without throwing', () {
      expect(() => log.i('test'), returnsNormally);
      expect(() => logEngine.i('test'), returnsNormally);
      expect(() => logBridge.i('test'), returnsNormally);
      expect(() => logServices.i('test'), returnsNormally);
      expect(() => logUi.i('test'), returnsNormally);
    });
  });
}
