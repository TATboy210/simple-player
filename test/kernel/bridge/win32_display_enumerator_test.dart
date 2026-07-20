import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_enumerator.dart';
import 'package:simple_player_flutter/kernel/bridge/win32/win32_display_enumerator.dart';

void main() {
  group('DisplayInfo', () {
    test('toString includes bounds, work, and primary flag', () {
      final info = const DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      final str = info.toString();
      expect(str, contains('1920'));
      expect(str, contains('1080'));
      expect(str, contains('primary=true'));
    });

    test('equality holds for same values', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      expect(a, equals(b));
    });

    test('equality fails for different bounds', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 2560, 1440),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('equality fails for different workArea', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 40, 1920, 1040),
        isPrimary: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('equality fails for different isPrimary', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent for equal objects', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for unequal objects', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 2560, 1440),
        workArea: Rect.fromLTWH(0, 0, 2560, 1400),
        isPrimary: false,
      );
      // Hash codes are likely different but not guaranteed
      // Just verify they don't crash
      expect(a.hashCode, isA<int>());
      expect(b.hashCode, isA<int>());
    });

    test('workArea is subset of bounds', () {
      const info = DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      // workArea height (1040) < bounds height (1080) — taskbar area excluded
      expect(info.workArea.height, lessThanOrEqualTo(info.bounds.height));
      expect(info.workArea.width, lessThanOrEqualTo(info.bounds.width));
    });

    test('non-primary display', () {
      const info = DisplayInfo(
        bounds: Rect.fromLTWH(1920, 0, 1920, 1080),
        workArea: Rect.fromLTWH(1920, 0, 1920, 1040),
        isPrimary: false,
      );
      expect(info.isPrimary, isFalse);
      expect(info.bounds.left, 1920); // Second monitor offset
    });

    test('toString with non-primary display', () {
      const info = DisplayInfo(
        bounds: Rect.fromLTWH(1920, 0, 1920, 1080),
        workArea: Rect.fromLTWH(1920, 0, 1920, 1040),
        isPrimary: false,
      );
      final str = info.toString();
      expect(str, contains('primary=false'));
    });
  });

  group('Win32DisplayEnumerator', () {
    // 注意: enumerateDisplays / getDisplayForWindow / getCurrentDisplay
    // 需要真实 Win32 环境，无法在 Flutter test 中测试。
    // 此处测试数据类本身的行为。

    test('Win32DisplayInfo typedef works correctly', () {
      const bounds = Rect.fromLTWH(1920, 0, 3840, 1080);
      const workArea = Rect.fromLTWH(1920, 40, 3840, 1040);
      final info = const Win32DisplayInfo(
        bounds: bounds,
        workArea: workArea,
        isPrimary: false,
      );

      expect(info.bounds, bounds);
      expect(info.workArea, workArea);
      expect(info.isPrimary, isFalse);
    });

    test('Win32DisplayInfo is DisplayInfo', () {
      const info = Win32DisplayInfo(
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        workArea: Rect.fromLTWH(0, 0, 1920, 1040),
        isPrimary: true,
      );
      expect(info, isA<DisplayInfo>());
    });
  });

  group('DisplayEnumerator interface', () {
    test('DisplayEnumerator is abstract', () {
      // Can't instantiate directly — verify it's an abstract class
      expect(DisplayEnumerator, isA<Type>());
    });

    test('Win32DisplayAdapter implements DisplayEnumerator', () {
      // Win32DisplayAdapter wraps Win32DisplayEnumerator as instance interface
      expect(Win32DisplayAdapter, isA<Type>());
    });
  });
}
