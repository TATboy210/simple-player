import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_enumerator.dart';
import 'package:simple_player_flutter/kernel/utils/screen_utils.dart';

void main() {
  // 模拟双显示器: 主屏 1920x1080, 副屏 2560x1440 位于右侧
  // Rect.fromLTWH(left, top, width, height)
  final primary = const DisplayInfo(
    bounds: Rect.fromLTWH(0, 0, 1920, 1080),
    workArea: Rect.fromLTWH(0, 0, 1920, 1040),
    isPrimary: true,
  );
  final secondary = const DisplayInfo(
    bounds: Rect.fromLTWH(1920, 0, 2560, 1440),
    workArea: Rect.fromLTWH(1920, 0, 2560, 1400),
    isPrimary: false,
  );
  final dualDisplays = [primary, secondary];

  group('ScreenUtils.clampToNearestMonitor', () {
    test('window on primary stays on primary', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: 100,
        y: 100,
        width: 800,
        height: 600,
      );
      expect(result.dx, 100);
      expect(result.dy, 100);
    });

    test('window on secondary stays on secondary', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: 2000,
        y: 100,
        width: 800,
        height: 600,
      );
      expect(result.dx, 2000);
      expect(result.dy, 100);
    });

    test('window fully off-screen on primary is centered', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: -5000,
        y: -5000,
        width: 800,
        height: 600,
      );
      // 应居中在主显示器（最近）
      expect(result.dx, greaterThanOrEqualTo(0));
      expect(result.dy, greaterThanOrEqualTo(0));
    });

    test('window off-screen secondary is clamped to secondary work area', () {
      // 窗口中心在副屏内，但 y > bottom-minVisible → offScreen
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: 2200,
        y: 1400,
        width: 800,
        height: 600,
      );
      // offScreen=true (1400 > 1300) → 居中到副屏 workArea
      expect(result.dx, 2800); // 1920 + (2560-800)/2
      expect(result.dy, 400); // 0 + (1400-600)/2
    });

    test('empty displays falls back to primary display behavior', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: [],
        x: 100,
        y: 100,
        width: 800,
        height: 600,
      );
      // 回退到 clampToPrimaryDisplay，窗口可见则保持原位
      expect(result.dx, 100);
      expect(result.dy, 100);
    });

    test('disconnected monitor: window moves to nearest', () {
      // 只有主屏，窗口原来在副屏位置
      final result = ScreenUtils.clampToNearestMonitor(
        displays: [primary],
        x: 2500,
        y: 100,
        width: 800,
        height: 600,
      );
      // 应被钳制到主显示器
      expect(result.dx, lessThanOrEqualTo(1920 - 100));
    });

    test('triple monitor: window on third stays on third', () {
      final third = const DisplayInfo(
        bounds: Rect.fromLTWH(-1920, 0, 1920, 1080),
        workArea: Rect.fromLTWH(-1920, 0, 1920, 1040),
        isPrimary: false,
      );
      final result = ScreenUtils.clampToNearestMonitor(
        displays: [third, primary, secondary],
        x: -1500,
        y: 100,
        width: 800,
        height: 600,
      );
      expect(result.dx, -1500);
      expect(result.dy, 100);
    });
  });

  group('ScreenUtils._clampToArea (via clampToNearestMonitor)', () {
    test('window fully visible returns original position', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: 500,
        y: 500,
        width: 400,
        height: 300,
      );
      expect(result, const Offset(500, 500));
    });

    test('window partially off right edge is kept (enough visible)', () {
      final result = ScreenUtils.clampToNearestMonitor(
        displays: dualDisplays,
        x: 1800,
        y: 100,
        width: 400,
        height: 300,
      );
      // 右边缘只露出 120px > minVisible(100)，保持原位
      expect(result, const Offset(1800, 100));
    });
  });
}
