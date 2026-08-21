/// Unit tests for [WindowMode] enum.
///
/// Covers: convenience getters (isWindowed, isMaximized, isFullscreen).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';

void main() {
  group('WindowMode', () {
    test('has all expected values', () {
      expect(WindowMode.values, hasLength(3));
      expect(WindowMode.values, contains(WindowMode.windowed));
      expect(WindowMode.values, contains(WindowMode.maximized));
      expect(WindowMode.values, contains(WindowMode.fullscreen));
    });

    group('isWindowed', () {
      test('true for windowed', () {
        expect(WindowMode.windowed.isWindowed, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.maximized.isWindowed, isFalse);
        expect(WindowMode.fullscreen.isWindowed, isFalse);
      });
    });

    group('isMaximized', () {
      test('true for maximized', () {
        expect(WindowMode.maximized.isMaximized, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.windowed.isMaximized, isFalse);
        expect(WindowMode.fullscreen.isMaximized, isFalse);
      });
    });

    group('isFullscreen', () {
      test('true for fullscreen', () {
        expect(WindowMode.fullscreen.isFullscreen, isTrue);
      });

      test('false for other modes', () {
        expect(WindowMode.windowed.isFullscreen, isFalse);
        expect(WindowMode.maximized.isFullscreen, isFalse);
      });
    });

    test('exactly one getter is true per mode', () {
      for (final mode in WindowMode.values) {
        final trueCount = [
          mode.isWindowed,
          mode.isMaximized,
          mode.isFullscreen,
        ].where((b) => b).length;
        expect(trueCount, 1, reason: '${mode.name} should have exactly 1 true');
      }
    });
  });
}
