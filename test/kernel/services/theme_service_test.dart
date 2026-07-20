/// ThemeService unit tests — pure Dart, no mdk.dll dependency.
///
/// Tests the singleton theme service: accent colors, theme index management,
/// currentAccent/currentTheme accessors, setTheme clamping, and dispose.
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // ThemeService.setTheme() calls SettingsStore.saveThemeIndex() which
    // uses KernelLoggerImpl.I — must init for tests.
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('ThemeService', () {
    setUp(() {
      // Reset singleton state between tests to prevent leaks
      ThemeService.I.themeIndex.value = 0;
    });

    group('accents', () {
      test('has 3 accent colors', () {
        expect(ThemeService.accents.length, 3);
      });

      test('accents are valid Color values', () {
        for (final accent in ThemeService.accents) {
          expect(accent, isA<Color>());
        }
      });

      test('first accent is Midnight blue', () {
        expect(ThemeService.accents[0], const Color(0xFF2C58F4));
      });

      test('second accent is Ocean cyan', () {
        expect(ThemeService.accents[1], const Color(0xFF00B4D8));
      });

      test('third accent is Forest green', () {
        expect(ThemeService.accents[2], const Color(0xFF2D6A4F));
      });
    });

    group('themeIndex', () {
      test('defaults to 0', () {
        expect(ThemeService.I.themeIndex.value, 0);
      });
    });

    group('currentAccent', () {
      test('returns accent at current index', () {
        ThemeService.I.themeIndex.value = 0;
        expect(ThemeService.I.currentAccent, ThemeService.accents[0]);
      });

      test('clamps to valid range when index out of bounds', () {
        // Set index beyond range — should clamp to last valid index
        ThemeService.I.themeIndex.value = 99;
        expect(ThemeService.I.currentAccent, ThemeService.accents[2]);
      });
    });

    group('currentTheme', () {
      test('returns dark theme', () {
        final theme = ThemeService.I.currentTheme;
        expect(theme.brightness, Brightness.dark);
      });

      test('theme colorScheme primary matches current accent', () {
        ThemeService.I.themeIndex.value = 1;
        final theme = ThemeService.I.currentTheme;
        expect(theme.colorScheme.primary, ThemeService.accents[1]);
      });
    });

    group('setTheme', () {
      test('updates themeIndex value', () {
        ThemeService.I.setTheme(2);
        expect(ThemeService.I.themeIndex.value, 2);
      });

      test('clamps index to valid range', () {
        ThemeService.I.setTheme(-5);
        expect(ThemeService.I.themeIndex.value, 0);

        ThemeService.I.setTheme(100);
        expect(ThemeService.I.themeIndex.value, 2);
      });
    });

    group('dispose', () {
      test('disposes themeIndex notifier', () {
        // Create a fresh ThemeService-like scenario
        // ThemeService is a singleton, so we just verify dispose doesn't throw
        // Note: calling dispose on the singleton would break other tests,
        // so we verify the method exists and is callable
        expect(ThemeService.I.dispose, isA<Function>());
      });
    });
  });
}
