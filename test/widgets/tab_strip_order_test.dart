// Tab 顺序与默认选中测试 — Phase 30 Plan 30-01 Task 1 (D-01)。
//
// 验证 SettingsTabStrip 渲染 7 个 SettingsNavItem，顺序为
// [均衡器, 音频, 视频, 通用, 快捷键, 关于, 性能]（D-01），
// General（通用）位于 index 3 且为默认打开项（defaultTabIndex=3）。
//
// 复用 FakePlaybackController（implements SettingsPanelPlayback）替身，
// 不依赖 MediaEngine / mdk.dll，规避 headless FFI 加载失败风险。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

import '../ui/dialogs/settings_panel_controller_test.dart'
    show FakePlaybackController;

void main() {
  /// D-01 七 tab 顺序标签（General 居中 index 3）。
  const expectedLabels = [
    '均衡器', // 0 EQ
    '音频', // 1 Audio
    '视频', // 2 Video
    '通用', // 3 General ← defaultTabIndex
    '快捷键', // 4 Shortcuts
    '关于', // 5 About
    '性能', // 6 Performance
  ];

  /// 构建最小化覆盖层测试壳。
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

  group('tab strip order (D-01)', () {
    testWidgets(
      'renders 7 SettingsNavItem in order [均衡器,音频,视频,通用,快捷键,关于,性能]',
      (tester) async {
        // Arrange & Act
        final controller = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — 7 个 nav item，顺序与 D-01 一致
        final navItems = find.byType(SettingsNavItem);
        expect(navItems, findsNWidgets(7));
        for (var i = 0; i < expectedLabels.length; i++) {
          final item = tester.widget<SettingsNavItem>(navItems.at(i));
          expect(
            item.label,
            expectedLabels[i],
            reason: 'tab index $i label mismatch',
          );
        }
      },
    );

    testWidgets(
      'General tab (通用) is at index 3',
      (tester) async {
        // Arrange & Act
        final controller = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — index 3 的 label 是 通用
        final navItems = find.byType(SettingsNavItem);
        final generalItem = tester.widget<SettingsNavItem>(navItems.at(3));
        expect(generalItem.label, '通用');
      },
    );

    test(
      'SettingsPanelController.defaultTabIndex is 3 (General, D-01)',
      () {
        // Assert — defaultTabIndex 常量为 3
        expect(SettingsPanelController.defaultTabIndex, 3);
      },
    );

    testWidgets(
      'opening panel selects General tab (index 3) by default',
      (tester) async {
        // Arrange & Act
        final controller = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — selectedTab 为 3，且 index 3 的 nav item selected=true
        expect(controller.state.selectedTab.value, 3);
        final navItems = find.byType(SettingsNavItem);
        final generalItem = tester.widget<SettingsNavItem>(navItems.at(3));
        expect(generalItem.selected, isTrue);

        // Assert — 其余 6 个 nav item selected=false
        for (var i = 0; i < 7; i++) {
          if (i == 3) continue;
          final item = tester.widget<SettingsNavItem>(navItems.at(i));
          expect(
            item.selected,
            isFalse,
            reason: 'tab $i should not be selected',
          );
        }
      },
    );
  });
}
