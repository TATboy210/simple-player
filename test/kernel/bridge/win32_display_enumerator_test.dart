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
      expect(a.bounds, b.bounds);
      expect(a.workArea, b.workArea);
      expect(a.isPrimary, b.isPrimary);
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
  });
}
