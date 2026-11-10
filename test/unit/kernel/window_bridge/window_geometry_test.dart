import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/window_bridge/service/window_geometry.dart';

void main() {
  const primary = Rect.fromLTWH(0, 0, 1920, 1040);
  const secondary = Rect.fromLTWH(1920, 0, 1920, 1040);

  group('isReachableOnAnyDisplay', () {
    test('accepts a window fully inside a work area', () {
      const bounds = Rect.fromLTWH(100, 100, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const [primary]), isTrue);
    });

    test('accepts a window on the secondary display when it is present', () {
      const bounds = Rect.fromLTWH(2200, 100, 1280, 720);
      expect(
        isReachableOnAnyDisplay(bounds, const [primary, secondary]),
        isTrue,
      );
    });

    test('rejects a window left on a display that was unplugged', () {
      const bounds = Rect.fromLTWH(2200, 100, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const [primary]), isFalse);
    });

    test('accepts a window mostly off-screen but with a grabbable strip', () {
      // 只露出右侧 120px 宽的一条 — 够抓住标题栏拖回来。
      const bounds = Rect.fromLTWH(1800, 100, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const [primary]), isTrue);
    });

    test('rejects a window with less than the reachable strip visible', () {
      const bounds = Rect.fromLTWH(1850, 100, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const [primary]), isFalse);
    });

    test('rejects a window whose title bar is above the work area', () {
      const bounds = Rect.fromLTWH(100, -700, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const [primary]), isFalse);
    });

    test('trusts the persisted value when no display info is available', () {
      const bounds = Rect.fromLTWH(99999, 99999, 1280, 720);
      expect(isReachableOnAnyDisplay(bounds, const <Rect>[]), isTrue);
    });
  });
}
