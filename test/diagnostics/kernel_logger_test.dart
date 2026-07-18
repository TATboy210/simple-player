/// Signature-acceptance tests for `KernelLogger` (D6 census) — asserts
/// `NullKernelLogger` accepts all 3 live call shapes found across the
/// 84-call-site census for `error()`/`fatal()`, plus the single-positional
/// shape for `trace`/`debug`/`info`/`warn`.
///
/// This is a compile+execute test, not a behavioral one: `NullKernelLogger`
/// is a deliberate no-op (D2/D3, Phase 17 supplies the real sink-backed
/// implementation). What matters here is that the interface's optional
/// named parameters (`error:`, `stackTrace:`) are wide enough to express
/// every shape the existing 84 call sites need after their Phase 17
/// migration (D8 level-mapping table) — a signature that were narrower
/// would fail to compile against real call sites, not just this test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';

void main() {
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
  });
}
