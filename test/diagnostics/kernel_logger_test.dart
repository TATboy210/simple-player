/// Behavioral tests for Phase 17 KernelLogger: LogLevel, LogSink, all sink
/// types (DevToolsSink, DebugPrintSink, NullSink, CompositeSink),
/// KernelLoggerImpl lifecycle, and path redaction (D17).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

/// Test spy sink that records all log calls for assertion.
class SpySink implements LogSink {
  final List<(LogLevel, String, Map<String, Object?>?)> calls = [];

  @override
  void log(
    LogLevel level,
    String msg, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    calls.add((level, msg, context));
  }
}

void main() {
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
      expect(() => sink.log(LogLevel.warn, 'hello'), returnsNormally);
    });

    test('cyclic structured context stays inside the diagnostic path', () {
      final context = <String, Object?>{};
      context['self'] = context;

      expect(
        () => const DebugPrintSink().log(
          LogLevel.debug,
          'cycle',
          context: context,
        ),
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

    test('log() with structured context returns normally', () {
      const sink = DevToolsSink();
      expect(
        () => sink.log(
          LogLevel.error,
          'test error',
          context: {'sampleCount': 12, 'totalP99Us': 42000},
        ),
        returnsNormally,
      );
    });
  });

  group('serializeLogContext', () {
    test('recursively sorts map keys while preserving list order and null', () {
      final context = <String, Object?>{
        'z': 1,
        'nested': <String, Object?>{'b': 2, 'a': 1},
        'list': <Object?>[3, null, 1],
        'a': true,
      };

      expect(
        serializeLogContext(context),
        '{"a":true,"list":[3,null,1],"nested":{"a":1,"b":2},"z":1}',
      );
    });

    test(
      'normalizes DateTime Set and non-finite doubles deterministically',
      () {
        final context = <String, Object?>{
          'set': <Object?>{'b', 'a'},
          'when': DateTime.utc(2026, 8, 7, 12, 30),
          'nan': double.nan,
          'positiveInfinity': double.infinity,
          'negativeInfinity': double.negativeInfinity,
        };

        expect(
          serializeLogContext(context),
          '{"nan":"NaN","negativeInfinity":"-Infinity",'
          '"positiveInfinity":"Infinity","set":["a","b"],'
          '"when":"2026-08-07T12:30:00.000Z"}',
        );
      },
    );

    test('replaces cyclic references without throwing', () {
      final context = <String, Object?>{};
      context['self'] = context;

      expect(serializeLogContext(context), '{"self":"<cycle>"}');
    });
  });

  group('default sink strategy', () {
    test('debug fans out to debug and DevTools sinks', () {
      final debugSink = SpySink();
      final devToolsSink = SpySink();
      final sink = createDefaultLogSink(
        KernelBuildMode.debug,
        debugSink: debugSink,
        devToolsSink: devToolsSink,
      );

      sink.log(LogLevel.info, 'resize', context: {'count': 1});

      expect(debugSink.calls, hasLength(1));
      expect(devToolsSink.calls, hasLength(1));
    });

    test('profile writes only to DevTools sink', () {
      final debugSink = SpySink();
      final devToolsSink = SpySink();
      final sink = createDefaultLogSink(
        KernelBuildMode.profile,
        debugSink: debugSink,
        devToolsSink: devToolsSink,
      );

      sink.log(LogLevel.info, 'resize');

      expect(debugSink.calls, isEmpty);
      expect(devToolsSink.calls, hasLength(1));
    });

    test('release produces no output', () {
      final debugSink = SpySink();
      final devToolsSink = SpySink();
      final sink = createDefaultLogSink(
        KernelBuildMode.release,
        debugSink: debugSink,
        devToolsSink: devToolsSink,
      );

      expect(() => sink.log(LogLevel.info, 'resize'), returnsNormally);
      expect(debugSink.calls, isEmpty);
      expect(devToolsSink.calls, isEmpty);
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
      expect(() => composite.log(LogLevel.info, 'empty'), returnsNormally);
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

      logger.error(
        'err',
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );
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
