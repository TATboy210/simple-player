/// PlayerServices unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the DI container construction and dispose lifecycle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/player_services.dart';

import '../helpers/fake_engine.dart';
import '../helpers/fake_window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('PlayerServices', () {
    group('construction', () {
      test('windowService is assigned from constructor', () {
        // Arrange
        final windowService = FakeWindowService();
        final services = PlayerServices(windowService: windowService);

        // Assert
        expect(services.windowService, same(windowService));
        windowService.dispose();
      });
    });

    group('dispose', () {
      test(
        'dispose before init is safe and does not dispose borrowed window',
        () {
          // Arrange
          final windowService = FakeWindowService();
          final services = PlayerServices(windowService: windowService);

          // Act and assert
          expect(() => services.dispose(), returnsNormally);
          expect(() => windowService.mode.value, returnsNormally);
          windowService.dispose();
        },
      );

      test(
        'owns one bridge and detaches it before fake engine disposal',
        () async {
          // Arrange
          final windowService = FakeWindowService();
          final engine = FakeEngine();
          final reporter = _reporter();
          final services = PlayerServices(
            windowService: windowService,
            testingDependencies: PlayerServicesDependencies(
              engineFactory: () => engine,
              reporter: reporter,
            ),
          );
          await services.init();

          // Act
          final opened = await services.controller.openAndPlay('');
          services.dispose();

          // Assert
          expect(opened, isFalse);
          expect(reporter.queuedReports, hasLength(1));
          expect(() => engine.lastError.value = null, returnsNormally);
          expect(() => services.dispose(), returnsNormally);
          windowService.dispose();
        },
      );
    });

    group('closing listener wiring (v0.0.6.2)', () {
      test('init 注册 flushForExit 到关窗链; 触发即落盘不抛', () async {
        final windowService = FakeWindowService();
        final services = PlayerServices(
          windowService: windowService,
          testingDependencies: PlayerServicesDependencies(
            engineFactory: () => FakeEngine(),
            reporter: _reporter(),
          ),
        );
        await services.init();

        // init 后关窗链上恰好一个监听 (flushForExit).
        expect(windowService.closingListeners, hasLength(1));

        // 触发监听 = 关窗链第 2.5 步 — 完成即落盘, 不抛.
        await expectLater(windowService.closingListeners.single(), completes);

        services.dispose();
        windowService.dispose();
      });

      test('dispose 先摘除关窗监听再销毁 coordinator', () async {
        final windowService = FakeWindowService();
        final services = PlayerServices(
          windowService: windowService,
          testingDependencies: PlayerServicesDependencies(
            engineFactory: () => FakeEngine(),
            reporter: _reporter(),
          ),
        );
        await services.init();
        final listener = windowService.closingListeners.single;

        services.dispose();

        // 摘除被调用; 再次手动触发监听 → coordinator 已销毁 → no-op 不抛.
        expect(windowService.removeClosingListenerCallCount, 1);
        expect(windowService.closingListeners, isEmpty);
        await expectLater(listener(), completes);
        windowService.dispose();
      });
    });
  });
}

/// Builds a reporter suitable for service lifecycle tests.
ErrorReporterImpl _reporter() {
  var sequence = 0;
  return ErrorReporterImpl.forTesting(
    clock: FakeClock(DateTime.utc(2026, 8, 28)),
    eventIdGenerator: () => 'service-${++sequence}',
    currentMediaPath: () => null,
  );
}
