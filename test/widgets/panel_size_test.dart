// 设置面板尺寸几何测试 — Phase 30 Plan 30-01 Task 1 (D-04 严格 16:9)。
//
// 验证 SettingsOverlayShell._panelWidth/_panelHeight 在不同窗口尺寸下
// 产出严格 16:9 几何：
//   width  = min(0.5×W, H×16/9).clamp(400, 960)
//   height = width × 9/16
// 无断点分支（breakpointResponsive 仅驱动 tab-compact 呈现）。
//
// 复用 FakePlaybackController（implements SettingsPanelPlayback）替身，
// 不依赖 MediaEngine / mdk.dll，规避 headless FFI 加载失败风险。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

import '../ui/dialogs/settings_panel_controller_test.dart'
    show FakePlaybackController;

void main() {
  /// 构建指定窗口尺寸的最小化覆盖层测试壳。
  Future<SettingsPanelController> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
  }) async {
    final fake = FakePlaybackController(
      initialState: MediaState.playing,
    );
    final controller = SettingsPanelController(fake);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [SettingsOverlayShell(controller: controller)],
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  group('panel size geometry (D-04: strict 16:9)', () {
    testWidgets(
      '1920x1080 produces 960x540 panel (width=min(960,1920)=960, height=960×9/16)',
      (tester) async {
        // Arrange — 1920×1080：width=min(0.5×1920=960, 1080×16/9=1920)=960，
        // clamp(400,960)=960；height=960×9/16=540
        final controller = await pumpShell(
          tester,
          size: const Size(1920, 1080),
        );
        controller.open();
        await tester.pump();

        // Assert — 16:9 几何上限 960×540
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 960.0);
        expect(panelBox.height, closeTo(540.0, 0.01));
      },
    );

    testWidgets(
      '1366x768 produces 683x384.19 panel (width=min(683,1365.33)=683)',
      (tester) async {
        // Arrange — 1366×768：width=min(0.5×1366=683, 768×16/9≈1365.33)=683，
        // clamp(400,960)=683；height=683×9/16=384.1875
        final controller = await pumpShell(
          tester,
          size: const Size(1366, 768),
        );
        controller.open();
        await tester.pump();

        // Assert — 16:9 几何（width 受 0.5×W 限制，height 非整数）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 683.0);
        expect(panelBox.height, closeTo(384.1875, 0.01));
      },
    );

    testWidgets(
      '800x600 produces 400x225 panel (width=min(400,1066.67)=400)',
      (tester) async {
        // Arrange — 800×600：width=min(0.5×800=400, 600×16/9≈1066.67)=400，
        // clamp(400,960)=400；height=400×9/16=225
        final controller = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Assert — 16:9 几何下限 400×225
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
        expect(panelBox.height, closeTo(225.0, 0.01));
      },
    );

    testWidgets(
      '500x400 produces 400x225 panel (width=250 clamped up to minWidth 400)',
      (tester) async {
        // Arrange — 500×400：width=min(0.5×500=250, 400×16/9≈711.11)=250，
        // clamp(400,960)=400（下限）；height=400×9/16=225
        final controller = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — width clamp 到下限 400，保持 16:9
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
        expect(panelBox.height, closeTo(225.0, 0.01));
      },
    );
  });
}
