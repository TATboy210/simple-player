// Settings 面板焦点导航集成测试 — 覆盖 NAV-01/NAV-04/NAV-05/NAV-06。
//
// 测试 D-pad Up/Down 焦点移动、A/B 键行为、FocusTraversalGroup 层级。
// 复用 FakePlaybackController 替身，不依赖 mdk.dll。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

import 'settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
  }) async {
    final fake = FakePlaybackController(initiallyPlaying: true);
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
    return (controller, fake);
  }

  group('Settings Focus Navigation', () {
    testWidgets('panel opens with autofocus', (tester) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump(); // Focus 获得焦点

      // Assert — 面板可见且 autofocus Focus 存在
      expect(find.byKey(SettingsOverlayShell.shellKey), findsOneWidget);
      expect(controller.state.isOpen.value, isTrue);
    });

    testWidgets('ArrowUp/ArrowDown do not close panel', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 按 Up/Down
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Assert — 面板仍然打开
      expect(controller.state.isOpen.value, isTrue);

      // 排空定时器
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('ArrowLeft/ArrowRight still switch tabs when no control focused',
        (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 按 Right 切换 tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Assert — selectedTab 更新为 1
      expect(controller.state.selectedTab.value, 1);

      // Act — 按 Left 切换回
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Assert — selectedTab 回到 0（或循环到 6）
      // 由于焦点可能在侧边栏，Left 应切换 tab
      expect(controller.state.selectedTab.value, isNot(1));
    });

    testWidgets('B key closes panel when focus is on sidebar', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — B 键关闭（默认焦点在面板根部，视为侧边栏/按钮栏区域）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.pump();

      // Assert — 面板关闭
      expect(controller.state.isOpen.value, isFalse);

      // 排空退出动画
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('Escape key closes panel', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Assert — 面板关闭
      expect(controller.state.isOpen.value, isFalse);

      // 排空退出动画
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('Enter key does not close panel', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — Enter 键
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Assert — 面板仍然打开（Enter 触发控件，不关闭面板）
      expect(controller.state.isOpen.value, isTrue);
    });

    testWidgets('LB/RB always switch tabs regardless of focus position',
        (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — RB 切换到下一个 tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton12);
      await tester.pump();

      // Assert
      expect(controller.state.selectedTab.value, 1);

      // Act — LB 切换到上一个 tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton13);
      await tester.pump();

      // Assert
      expect(controller.state.selectedTab.value, 0);
    });

    testWidgets('FocusTraversalGroup hierarchy exists in panel',
        (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — 有多个 FocusTraversalGroup（外层 + 侧边栏 + 内容区 + 按钮栏）
      final groups = tester.widgetList<FocusTraversalGroup>(
        find.byType(FocusTraversalGroup),
      );
      // 至少 4 个：外层、侧边栏、内容区、按钮栏
      expect(groups.length, greaterThanOrEqualTo(4));
    });

    testWidgets('panel key and button bar key are present', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert
      expect(find.byKey(SettingsOverlayShell.panelKey), findsOneWidget);
      expect(find.byKey(SettingsOverlayShell.buttonBarKey), findsOneWidget);
    });

    testWidgets('KeyUp events are still ignored', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 发送 KeyUp（非 KeyDown）
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Assert — 面板仍然打开，无异常
      expect(controller.state.isOpen.value, isTrue);
    });

    testWidgets('D-pad navigation does not break existing tab switching',
        (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 先切 tab，再按 Up/Down，再切 tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.state.selectedTab.value, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.state.selectedTab.value, 2);

      // Assert — 面板仍然打开
      expect(controller.state.isOpen.value, isTrue);
    });
  });
}
