import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/platform/window_handle_locator.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('WindowHandleLocator', () {
    test('returns the first non-null non-zero handle', () {
      final locator = WindowHandleLocator(<HandleStrategy>[
        () => null,
        () => 0,
        () => 42,
        () => 7,
      ]);

      expect(locator.locate(), 42);
    });

    test('a throwing strategy is logged and skipped', () {
      final locator = WindowHandleLocator(<HandleStrategy>[
        () => throw StateError('boom'),
        () => 5,
      ]);

      expect(locator.locate(), 5);
    });

    test('all strategies failing yields null', () {
      final locator = WindowHandleLocator(<HandleStrategy>[
        () => null,
        () => throw StateError('boom'),
      ]);

      expect(locator.locate(), isNull);
    });
  });

  group('defaultHandleStrategies', () {
    test('symbol lookup is always the primary strategy', () {
      final strategies = defaultHandleStrategies(
        managerFallback: () => null,
        operatingSystem: () => 'windows',
      );

      expect(strategies.first, lookupRunnerHandleSymbol);
    });

    test('windows falls back to the runner window enumeration', () {
      final strategies = defaultHandleStrategies(
        managerFallback: () => null,
        operatingSystem: () => 'windows',
      );

      // 符号 + FindWindowExW（不执行，只验证链构成）。
      expect(strategies, hasLength(2));
    });

    test('macos and linux fall back to the window manager', () {
      for (final os in <String>['macos', 'linux']) {
        final strategies = defaultHandleStrategies(
          managerFallback: () => 99,
          operatingSystem: () => os,
        );

        expect(strategies, hasLength(2), reason: os);
        expect(strategies.last(), 99, reason: os);
      }
    });

    test('unknown platform keeps only the symbol strategy', () {
      final strategies = defaultHandleStrategies(
        managerFallback: () => 99,
        operatingSystem: () => 'fuchsia',
      );

      expect(strategies, hasLength(1));
    });
  });

  test('lookupRunnerHandleSymbol returns null when the runner lacks it', () {
    // 测试宿主进程没有该导出符号 — 静默 null，由 fallback 链接管。
    expect(lookupRunnerHandleSymbol(), isNull);
  });
}
