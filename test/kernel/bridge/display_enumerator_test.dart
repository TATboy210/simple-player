import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_enumerator.dart';

/// Mock DisplayEnumerator — 验证抽象接口契约。
///
/// Win32 实现依赖 FFI (user32.dll)，无法在测试环境直接调用。
/// 用 mock 验证接口行为和 DisplayInfo 数据类。
class MockDisplayEnumerator implements DisplayEnumerator {
  MockDisplayEnumerator(this._displays);

  final List<DisplayInfo> _displays;

  @override
  List<DisplayInfo> enumerateDisplays() => List.unmodifiable(_displays);

  @override
  DisplayInfo? getDisplayForWindow(int hwnd) {
    // 简化: 返回主显示器
    try {
      return _displays.firstWhere((d) => d.isPrimary);
    } on StateError {
      return _displays.isNotEmpty ? _displays.first : null;
    }
  }

  @override
  DisplayInfo? getCurrentDisplay() => getDisplayForWindow(0);
}

void main() {
  group('DisplayInfo', () {
    test('equality — same values are equal', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTRB(0, 0, 1920, 1080),
        workArea: Rect.fromLTRB(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTRB(0, 0, 1920, 1080),
        workArea: Rect.fromLTRB(0, 0, 1920, 1040),
        isPrimary: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality — different values are not equal', () {
      const a = DisplayInfo(
        bounds: Rect.fromLTRB(0, 0, 1920, 1080),
        workArea: Rect.fromLTRB(0, 0, 1920, 1040),
        isPrimary: true,
      );
      const b = DisplayInfo(
        bounds: Rect.fromLTRB(1920, 0, 3840, 1080),
        workArea: Rect.fromLTRB(1920, 0, 3840, 1040),
        isPrimary: false,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes bounds, workArea, and primary', () {
      const info = DisplayInfo(
        bounds: Rect.fromLTRB(0, 0, 1920, 1080),
        workArea: Rect.fromLTRB(0, 0, 1920, 1040),
        isPrimary: true,
      );
      final str = info.toString();
      expect(str, contains('bounds'));
      expect(str, contains('work'));
      expect(str, contains('primary'));
    });
  });

  // ─── TEST-04: DisplayEnumerator — 接口契约验证 ───

  group('TEST-04: DisplayEnumerator contract', () {
    test('enumerateDisplays returns at least one display', () {
      final enumerator = MockDisplayEnumerator([
        const DisplayInfo(
          bounds: Rect.fromLTRB(0, 0, 1920, 1080),
          workArea: Rect.fromLTRB(0, 0, 1920, 1040),
          isPrimary: true,
        ),
      ]);

      final displays = enumerator.enumerateDisplays();
      expect(displays, isNotEmpty);
    });

    test('identifies exactly one primary display', () {
      final enumerator = MockDisplayEnumerator([
        const DisplayInfo(
          bounds: Rect.fromLTRB(0, 0, 1920, 1080),
          workArea: Rect.fromLTRB(0, 0, 1920, 1040),
          isPrimary: true,
        ),
        const DisplayInfo(
          bounds: Rect.fromLTRB(1920, 0, 3840, 1080),
          workArea: Rect.fromLTRB(1920, 0, 3840, 1040),
          isPrimary: false,
        ),
      ]);

      final displays = enumerator.enumerateDisplays();
      final primary = displays.where((d) => d.isPrimary);
      expect(primary, hasLength(1));
    });

    test('getDisplayForWindow returns primary display', () {
      const primary = DisplayInfo(
        bounds: Rect.fromLTRB(0, 0, 1920, 1080),
        workArea: Rect.fromLTRB(0, 0, 1920, 1040),
        isPrimary: true,
      );
      final enumerator = MockDisplayEnumerator([
        primary,
        const DisplayInfo(
          bounds: Rect.fromLTRB(1920, 0, 3840, 1080),
          workArea: Rect.fromLTRB(1920, 0, 3840, 1040),
          isPrimary: false,
        ),
      ]);

      final display = enumerator.getDisplayForWindow(12345);
      expect(display, equals(primary));
    });

    test('getCurrentDisplay delegates to getDisplayForWindow', () {
      final enumerator = MockDisplayEnumerator([
        const DisplayInfo(
          bounds: Rect.fromLTRB(0, 0, 2560, 1440),
          workArea: Rect.fromLTRB(0, 0, 2560, 1400),
          isPrimary: true,
        ),
      ]);

      final current = enumerator.getCurrentDisplay();
      expect(current, isNotNull);
      expect(current!.isPrimary, isTrue);
    });

    test('empty display list returns null for window lookup', () {
      final enumerator = MockDisplayEnumerator([]);
      expect(enumerator.getDisplayForWindow(0), isNull);
      expect(enumerator.getCurrentDisplay(), isNull);
    });

    test('multi-monitor: bounds do not overlap', () {
      final enumerator = MockDisplayEnumerator([
        const DisplayInfo(
          bounds: Rect.fromLTRB(0, 0, 1920, 1080),
          workArea: Rect.fromLTRB(0, 0, 1920, 1040),
          isPrimary: true,
        ),
        const DisplayInfo(
          bounds: Rect.fromLTRB(1920, 0, 3840, 1080),
          workArea: Rect.fromLTRB(1920, 0, 3840, 1040),
          isPrimary: false,
        ),
      ]);

      final displays = enumerator.enumerateDisplays();
      expect(displays, hasLength(2));

      // 副屏 bounds.left 应等于主屏 bounds.right (并排布局)
      expect(displays[1].bounds.left, equals(displays[0].bounds.right));
    });
  });
}
