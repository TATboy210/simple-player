/// Behavioral tests for Phase 17 KernelLogger: LogLevel, LogSink, all sink
/// types (DevToolsSink, DebugPrintSink, NullSink, CompositeSink),
/// KernelLoggerImpl lifecycle, and path redaction (D17).
///
/// Extends the Phase 16 signature-acceptance tests (NullKernelLogger) with
/// behavioral coverage for the concrete implementation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

/// Test spy sink that records all log calls for assertion.
class SpySink implements LogSink {
  final List<(LogLevel, String, Map<String, Object?>?)> calls = [];

  @override
  void log(LogLevel level, String msg, {Map<String, Object?>? context}) {
    calls.add((level, msg, context));
  }
}

void main() {
  // =========================================================================
  // Group 0: NullKernelLogger signature tests (from Phase 16, preserved)
  // =========================================================================
  group('NullKernelLogger', () {
    const logger = NullKernelLogger();

    test('trace/debug/info/warn each accept a single positional String', () {
      expect(() => logger.trace('trace message'), returnsNormally);
      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warn('warn message'), returnsNormally);
    });

    test('error() accepts shape (a): both error: and stackTrace: named', () {
      // Live shape: 2 of 84 call sites pass both named params together.
      expect(
        () => logger.error(
          'error message',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('error() accepts shape (b): stackTrace: only', () {
      // Live shape: 2 of 84 call sites pass stackTrace: with no error:.
      expect(
        () => logger.error('error message', stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('error() accepts shape (c): neither named param', () {
      // Live shape: the remaining call sites pass only the message.
      expect(() => logger.error('error message'), returnsNormally);
    });

    test('fatal() accepts shape (a): both error: and stackTrace: named', () {
      expect(
        () => logger.fatal(
          'fatal message',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('fatal() accepts shape (b): stackTrace: only', () {
      expect(
        () => logger.fatal('fatal message', stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('fatal() accepts shape (c): neither named param', () {
      expect(() => logger.fatal('fatal message'), returnsNormally);
    });

    test('all 6 methods accept optional context param', () {
      expect(() => logger.trace('t', context: {'k': 'v'}), returnsNormally);
      expect(() => logger.debug('d', context: {'k': 'v'}), returnsNormally);
      expect(() => logger.info('i', context: {'k': 'v'}), returnsNormally);
      expect(() => logger.warn('w', context: {'k': 'v'}), returnsNormally);
      expect(
        () => logger.error('e', context: {'k': 'v'}, error: Exception('x')),
        returnsNormally,
      );
      expect(
        () => logger.fatal('f', context: {'k': 'v'}, error: Exception('x')),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  // Group 1: LogLevel enum
  // =========================================================================
  group('LogLevel', () {
    test('has exactly 6 values in severity order', () {
      expect(LogLevel.values, hasLength(6));
      expect(LogLevel.values, [
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
        LogLevel.fatal,
      ]);
    });
  });

  // =========================================================================
  // Group 2: NullSink
  // =========================================================================
  group('NullSink', () {
    test('is const-constructible', () {
      const NullSink();
      expect(true, isTrue);
    });

    test('log() is a no-op for all LogLevel values', () {
      const sink = NullSink();
      for (final level in LogLevel.values) {
        expect(() => sink.log(level, 'test'), returnsNormally);
      }
    });
  });

  // =========================================================================
  // Group 3: DebugPrintSink
  // =========================================================================
  group('DebugPrintSink', () {
    test('is const-constructible', () {
      const DebugPrintSink();
      expect(true, isTrue);
    });

    test('log() returns normally', () {
      const sink = DebugPrintSink();
      expect(
        () => sink.log(LogLevel.warn, 'hello'),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  // Group 4: DevToolsSink
  // =========================================================================
  group('DevToolsSink', () {
    test('is const-constructible', () {
      const DevToolsSink();
      expect(true, isTrue);
    });

    test('log() returns normally', () {
      const sink = DevToolsSink();
      expect(
        () => sink.log(LogLevel.error, 'test error'),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  // Group 5: CompositeSink
  // =========================================================================
  group('CompositeSink', () {
    test('delegates log() to all contained sinks', () {
      final spy1 = SpySink();
      final spy2 = SpySink();
      final composite = CompositeSink([spy1, spy2]);

      composite.log(LogLevel.warn, 'test', context: {'k': 'v'});

      expect(spy1.calls, hasLength(1));
      expect(spy1.calls[0].$1, LogLevel.warn);
      expect(spy1.calls[0].$2, 'test');
      expect(spy1.calls[0].$3, {'k': 'v'});

      expect(spy2.calls, hasLength(1));
      expect(spy2.calls[0].$1, LogLevel.warn);
    });

    test('with empty list returns normally', () {
      final composite = CompositeSink([]);
      expect(
        () => composite.log(LogLevel.info, 'empty'),
        returnsNormally,
      );
    });
  });

  // =========================================================================
  // Group 6: KernelLoggerImpl lifecycle
  // =========================================================================
  group('KernelLoggerImpl lifecycle', () {
    test('I throws StateError before init() is called', () {
      KernelLoggerImpl.resetForTesting();
      expect(() => KernelLoggerImpl.I, throwsA(isA<StateError>()));
    });

    test('I returns same instance after init() (identity)', () {
      KernelLoggerImpl.resetForTesting();
      KernelLoggerImpl.init();
      final a = KernelLoggerImpl.I;
      final b = KernelLoggerImpl.I;
      expect(identical(a, b), isTrue);
    });
  });

  // =========================================================================
  // Group 7: KernelLoggerImpl method delegation
  // =========================================================================
  group('KernelLoggerImpl method delegation', () {
    test('all 6 methods + 6 shortcuts work without exceptions', () {
      final spy = SpySink();
      final logger = KernelLoggerImpl(spy);

      logger.trace('t');
      logger.debug('d');
      logger.info('i');
      logger.warn('w');
      logger.error('e', error: Exception('x'), stackTrace: StackTrace.current);
      logger.fatal('f', error: Exception('y'));

      logger.t('t2');
      logger.d('d2');
      logger.i('i2');
      logger.w('w2');
      logger.e('e2');
      logger.f('f2');

      expect(spy.calls, hasLength(12));
      expect(spy.calls[0].$1, LogLevel.trace);
      expect(spy.calls[6].$1, LogLevel.trace);
    });

    test('error()/fatal() with error+stackTrace params work', () {
      final spy = SpySink();
      final logger = KernelLoggerImpl(spy);

      logger.error('err', error: Exception('boom'), stackTrace: StackTrace.current);
      logger.fatal('fat', error: Exception('die'));

      expect(spy.calls, hasLength(2));
      expect(spy.calls[0].$1, LogLevel.error);
      expect(spy.calls[1].$1, LogLevel.fatal);
    });
  });

  // =========================================================================
  // Group 8: LogSink interface
  // =========================================================================
  group('LogSink interface', () {
    test('is an abstract interface class (compile-time contract)', () {
      // SpySink implements LogSink, proving it requires log() implementation.
      final spy = SpySink();
      expect(spy, isA<LogSink>());
    });
  });

  // =========================================================================
  // Group 9: Path redaction (D17) — direct redactPath() tests
  // =========================================================================
  group('redactPath (D17)', () {
    test('strips Unix directory prefix to filename:line', () {
      expect(
        redactPath('lib/kernel/engine/fvp_engine.dart:259 error'),
        equals('fvp_engine.dart:259 error'),
      );
    });

    test('strips Windows directory prefix to filename:line', () {
      expect(
        redactPath(r'lib\kernel\engine\fvp_engine.dart:259 error'),
        equals('fvp_engine.dart:259 error'),
      );
    });

    test('does not alter messages without file paths', () {
      const msg = 'simple error message with no path';
      expect(redactPath(msg), equals(msg));
    });

    test('handles multiple paths in one message', () {
      expect(
        redactPath('lib/a/foo.dart:10 and lib/b/bar.dart:20'),
        equals('foo.dart:10 and bar.dart:20'),
      );
    });
  });
}
