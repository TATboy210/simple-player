// 多显示器拖拽 clamp 测试 — Phase 30 Plan 30-01 Task 2 (D-03)。
//
// 验证 SettingsOverlayShell 的 DisplayEnumerator 注入接缝：
// - 有注入且 workArea >= panelSize → dragOffset clamp 到 workArea 边界
// - 无注入 / getCurrentDisplay() 返回 null / workArea < panelSize → 退回对称 clamp
//
// 用手写 FakeDisplayEnumerator（implements DisplayEnumerator）替身，
// 不依赖 Win32 FFI / Win32DisplayAdapter，规避 headless FFI 加载失败风险
// （CLAUDE.md "Fakes over mocks"）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_enumerator.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

import '../ui/dialogs/settings_panel_controller_test.dart'
    show FakePlaybackController;

void main() {
  /// 1200×800 窗口下的面板几何（D-04 严格 16:9 公式）：
  /// - panelWidth  = min(0.5×1200=600, 800×16/9≈1422.22) = 600，clamp(400,960)=600
  /// - panelHeight = 600×9/16 = 337.5
  /// - baseLeft = (1200-600)/2 = 300，baseTop = (800-337.5)/2 = 231.25
  /// 对称 clamp：dx∈[-300,300]，dy∈[-231.25,231.25]
  /// workArea clamp（fake LTRB(100,200,1100,700)，1000×500 ≥ 600×337.5）：
  ///   minX=100-300=-200，maxX=1100-300-600=200
  ///   minY=200-231.25=-31.25，maxY=700-231.25-337.5=131.25
  /// → dx∈[-200,200]，dy∈[-31.25,131.25]（与对称区间可区分）
  const windowSize = Size(1200, 800);
  const fakeWorkArea = Rect.fromLTRB(100, 200, 1100, 700);

  /// 构建带可选 DisplayEnumerator 注入的最小化覆盖层测试壳。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    DisplayEnumerator? displayEnumerator,
  }) async {
    final fake = FakePlaybackController(initialState: MediaState.playing);
    final controller = SettingsPanelController(fake);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: windowSize),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                SettingsOverlayShell(
                  controller: controller,
                  displayEnumerator: displayEnumerator,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return (controller, fake);
  }

  group('multi-monitor drag clamp (D-03)', () {
    testWidgets(
      'workArea injection clamps drag below at dy=131.25 (not symmetric 231.25)',
      (tester) async {
        // Arrange — fake workArea 1000×500，底部边界限制 dy≤131.25
        final fake = FakeDisplayEnumerator(workArea: fakeWorkArea);
        final (controller, _) = await pumpShell(
          tester,
          displayEnumerator: fake,
        );
        controller.open();
        await tester.pump();

        // Act — 从标题栏向下拖 500px（超 workArea 底部）
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(0, 500));
        await gesture.up();
        await tester.pump();

        // Assert — workArea clamp：dy 停在 131.25（对称会到 231.25）
        expect(controller.state.dragOffset.value.dy, closeTo(131.25, 0.01));
        expect(controller.state.dragOffset.value.dx, 0.0);
      },
    );

    testWidgets('no injection falls back to symmetric clamp at dy=231.25', (
      tester,
    ) async {
      // Arrange — 无 DisplayEnumerator 注入（生产默认 null，30-02 才注入 Win32）
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
      final gesture = await tester.startGesture(tester.getCenter(titleBar));
      await gesture.moveBy(const Offset(0, 500));
      await gesture.up();
      await tester.pump();

      // Assert — 对称 clamp：dy 停在 (800-337.5)/2=231.25
      expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));
    });

    testWidgets(
      'workArea injection clamps drag right at dx=200 (not symmetric 300)',
      (tester) async {
        // Arrange
        final fake = FakeDisplayEnumerator(workArea: fakeWorkArea);
        final (controller, _) = await pumpShell(
          tester,
          displayEnumerator: fake,
        );
        controller.open();
        await tester.pump();

        // Act — 向右拖 500px（超 workArea 右边界）
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(500, 0));
        await gesture.up();
        await tester.pump();

        // Assert — workArea clamp：dx 停在 200（对称会到 300）
        expect(controller.state.dragOffset.value.dx, closeTo(200.0, 0.01));
        expect(controller.state.dragOffset.value.dy, 0.0);
      },
    );

    testWidgets('no injection falls back to symmetric clamp at dx=300', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
      final gesture = await tester.startGesture(tester.getCenter(titleBar));
      await gesture.moveBy(const Offset(500, 0));
      await gesture.up();
      await tester.pump();

      // Assert — 对称 clamp：dx 停在 (1200-600)/2=300
      expect(controller.state.dragOffset.value.dx, closeTo(300.0, 0.01));
    });

    testWidgets(
      'falls back to symmetric clamp when workArea smaller than panel',
      (tester) async {
        // Arrange — workArea 500×300 < panelSize 600×337.5 → 触发 fallback
        final smallWorkArea = const Rect.fromLTRB(0, 0, 500, 300);
        final fake = FakeDisplayEnumerator(workArea: smallWorkArea);
        final (controller, _) = await pumpShell(
          tester,
          displayEnumerator: fake,
        );
        controller.open();
        await tester.pump();

        // Act
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(0, 500));
        await gesture.up();
        await tester.pump();

        // Assert — fallback 到对称 clamp：dy=231.25（非 workArea 路径）
        expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));
      },
    );

    testWidgets(
      'falls back to symmetric clamp when getCurrentDisplay returns null',
      (tester) async {
        // Arrange — fake 返回 null display（无显示器信息）
        final fake = FakeDisplayEnumerator(workArea: null);
        final (controller, _) = await pumpShell(
          tester,
          displayEnumerator: fake,
        );
        controller.open();
        await tester.pump();

        // Act
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(0, 500));
        await gesture.up();
        await tester.pump();

        // Assert — fallback 到对称 clamp：dy=231.25
        expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));
      },
    );
  });
}

/// 手写 DisplayEnumerator 替身 — 返回固定 DisplayInfo（workArea 可配）。
///
/// 用于验证 SettingsOverlayShell._clampDragOffset 的 workArea 路径：
/// getCurrentDisplay() 返回 [DisplayInfo] 时用其 workArea clamp，
/// 返回 null 时触发对称 fallback。不调用真实 Win32 FFI。
class FakeDisplayEnumerator implements DisplayEnumerator {
  FakeDisplayEnumerator({this.workArea});

  /// 当前显示器的可用区域（null 模拟"无显示器信息"）。
  final Rect? workArea;

  @override
  List<DisplayInfo> enumerateDisplays() {
    if (workArea == null) return const [];
    return [
      DisplayInfo(bounds: workArea!, workArea: workArea!, isPrimary: true),
    ];
  }

  @override
  DisplayInfo? getDisplayForWindow(int hwnd) => getCurrentDisplay();

  @override
  DisplayInfo? getCurrentDisplay() {
    if (workArea == null) return null;
    return DisplayInfo(bounds: workArea!, workArea: workArea!, isPrimary: true);
  }
}
