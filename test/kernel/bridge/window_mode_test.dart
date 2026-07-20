/// Unit tests for [WindowMode] enum.
///
/// Covers: convenience getters (isWindowed, isMaximized, isFullscreen, isMinimized).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/window_mode.dart';

void main() {
  group('WindowMode', () {
    test('has all expected values', () {
      expect(WindowMode.values, hasLength(4));
      expect(WindowMode.values, contains(WindowMode.windowed));
      expect(WindowMode.values, contains(WindowMode.maximized));
      expect(WindowMode.values, contains(WindowMode.fullscreen));
      expect(WindowMode.values, contains(WindowMode.minimized));
    });

    group('isWindowed', () {
      test('true for windowed', () {
        expect(WindowMode.windowed.isWindowed, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.maximized.isWindowed, isFalse);
        expect(WindowMode.fullscreen.isWindowed, isFalse);
        expect(WindowMode.minimized.isWindowed, isFalse);
      });
    });

    group('isMaximized', () {
      test('true for maximized', () {
        expect(WindowMode.maximized.isMaximized, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.windowed.isMaximized, isFalse);
        expect(WindowMode.fullscreen.isMaximized, isFalse);
        expect(WindowMode.minimized.isMaximized, isFalse);
      });
    });

    group('isFullscreen', () {
      test('true for fullscreen', () {
        expect(WindowMode.fullscreen.isFullscreen, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.windowed.isFullscreen, isFalse);
        expect(WindowMode.maximized.isFullscreen, isFalse);
        expect(WindowMode.minimized.isFullscreen, isFalse);
      });
    });

    group('isMinimized', () {
      test('true for minimized', () {
        expect(WindowMode.minimized.isMinimized, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.windowed.isMinimized, isFalse);
        expect(WindowMode.maximized.isMinimized, isFalse);
        expect(WindowMode.fullscreen.isMinimized, isFalse);
      });
    });

    test('exactly one getter is true per mode', () {
      for (final mode in WindowMode.values) {
        final trueCount = [
          mode.isWindowed,
          mode.isMaximized,
          mode.isFullscreen,
          mode.isMinimized,
        ].where((b) => b).length;
        expect(trueCount, 1, reason: '${mode.name} should have exactly 1 true');
      }
    });
  });
}
