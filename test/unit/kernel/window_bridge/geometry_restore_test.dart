import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/window_persistence.dart';
import 'package:simple_player_flutter/kernel/window_bridge/service/geometry_restore.dart';

import '../../../helpers/fake_native_window.dart';

/// 隐藏态几何恢复（契约 5/10）的行为锁定：
/// 正常恢复、副屏拔线退化、工作区查询失败信任原值、Wayland 只应用尺寸。
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  const workArea = Rect.fromLTWH(0, 0, 1920, 1040);

  group('GeometryRestore.restore', () {
    test('正常恢复 — 位置在主屏工作区内，矩形精确应用', () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(120, 80),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(seed, const Rect.fromLTWH(120, 80, 1280, 720));
      expect(window.calls.length, 1);
      expect(window.calls.single, startsWith('bounds='));
    });

    test('副屏拔线 — 位置不在任何工作区内：只应用尺寸并居中', () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          // (-5000, -5000) 在 1920x1040 工作区外 — 上次的副屏已拔掉。
          position: Offset(-5000, -5000),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      // 居中于工作区：x = (1920-1280)/2 = 320, y = (1040-720)/2 = 160。
      expect(seed, const Rect.fromLTWH(320, 160, 1280, 720));
      expect(window.calls, contains('setSize=Size(1280.0, 720.0)'));
      expect(window.calls, contains('center'));
      expect(window.calls.where((c) => c.startsWith('bounds=')), isEmpty,
          reason: '不可达位置不得直接应用原矩形');
    });

    test('边缘可达 — 只露出 minimumReachableArea 的角落也算可达', () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      // 窗口绝大部分在屏幕外，但左上角留有 192x64 可抓取（> 100x32）。
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(1800, 980),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(seed, const Rect.fromLTWH(1800, 980, 1280, 720));
      expect(window.calls, isNot(contains('center')));
    });

    test('边缘不可达 — 可见区域小于 100x32 时按拔线退化', () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      // 只露出 50x32 宽（< 100px 可抓宽）→ 找不回标题栏，居中。
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(1900, 0),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(seed, const Rect.fromLTWH(320, 160, 1280, 720));
      expect(window.calls, contains('center'));
    });

    test('位置缺失 — 只应用尺寸并居中（不应用任意位置）', () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          size: Size(1280, 720),
          position: null,
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(seed, const Rect.fromLTWH(320, 160, 1280, 720));
      expect(window.calls, ['setSize=Size(1280.0, 720.0)', 'center']);
    });

    test('workAreas 查询失败 — 空列表信任持久化原值（「不搬家」退化）', () {
      final window = FakeNativeWindow()
        ..workAreasValue = const <Rect>[]
        ..workAreasError = StateError('display query failed');
      const restore = GeometryRestore(supportsPositioning: true);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(120, 80),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      // isReachableOnAnyDisplay([]) == true → 原矩形照用，不居中。
      expect(seed, const Rect.fromLTWH(120, 80, 1280, 720));
      expect(window.calls.length, 1);
      expect(window.calls.single, startsWith('bounds='));
      expect(window.calls, isNot(contains('center')));
    });

    test('Wayland（supportsPositioning=false）— 只应用尺寸，位置交 compositor',
        () {
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: false);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(120, 80),
          size: Size(1280, 720),
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(window.calls, ['setSize=Size(1280.0, 720.0)']);
      expect(window.calls, isNot(contains('center')));
      // 种子取恢复后的实际 bounds（compositor 决定的位置）。
      expect(seed, const Rect.fromLTWH(100, 100, 1280, 720),
          reason: 'FakeNativeWindow 初始 bounds 的 topLeft & size');
    });

    test('恢复几何遵守最小外框尺寸语义（与 minimumWindowSize 共用校验）', () {
      // 持久化尺寸小于最小外框 — restore 不做 clamp（契约：落盘侧已 clamp），
      // 此处仅断言透传，防止恢复层静默改写用户几何。
      final window = FakeNativeWindow()..workAreasValue = [workArea];
      const restore = GeometryRestore(supportsPositioning: true);
      const small = Size(10, 10);
      final seed = restore.restore(
        window,
        const PersistedWindowState(
          position: Offset(0, 0),
          size: small,
          alwaysOnTop: false,
          isMaximized: false,
        ),
      );
      expect(seed.size, small);
      expect(window.calls, contains('setSize=$small'));
    });
  });
}
