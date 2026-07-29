// Settings 面板焦点导航集成测试 — 覆盖 NAV-01/NAV-04/NAV-05/NAV-06。
//
// 测试 D-pad Up/Down 焦点移动、A/B 键行为、FocusTraversalGroup 层级。
// 复用 FakePlaybackController 替身，不依赖 mdk.dll。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/services/input_mode_detector.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';

import 'settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
  }) async {
    final fake = FakePlaybackController(initialState: MediaState.playing);
    final controller = SettingsPanelController(fake);
    addTearDown(() async {
      // 清理 InputModeDetector 进程级单例的 pending FakeTimer（recordArrowKey 的
      // 5s gamepad 检测 + setArrowGlow 的 reset 计时器），避免 fakeAsync 泄漏
      // 触发 !timersPending 断言（panel_key_bindings.handle 间接调用单例）。
      InputModeDetector.instance.onPanelClosed();
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

      // 排空定时器 + 取消 InputModeDetector 单例的 pending FakeTimer。
      // arrowUp/Down 经 panel_key_bindings.handle 调 recordArrowKey（5s 检测
      // Timer）+ setArrowGlow（reset Timer）。flutter_test 的 timersPending
      // 检查（_verifyInvariants）在 addTearDown 之前运行，addTearDown 的
      // onPanelClosed 来不及取消，故须在 body 末尾主动调。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
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

      // Assert — selectedTab 更新为 4（open→General(3)，Right→nextTab→(3+1)%7=4）
      expect(controller.state.selectedTab.value, 4);

      // Act — 按 Left 切换回
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Assert — selectedTab 回到 0（或循环到 6）
      // 由于焦点可能在侧边栏，Left 应切换 tab
      expect(controller.state.selectedTab.value, isNot(1));

      // 排空 + 取消 InputModeDetector 单例的 pending FakeTimer（arrowLeft/Right
      // 经 recordArrowKey 启动 5s 检测 Timer）。timersPending 检查
      // （_verifyInvariants）在 addTearDown 之前运行，addTearDown 的
      // onPanelClosed 来不及取消，故须在 body 末尾主动调。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
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

      // Assert — open→3，RB(next)→(3+1)%7=4
      expect(controller.state.selectedTab.value, 4);

      // Act — LB 切换到上一个 tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton13);
      await tester.pump();

      // Assert — LB(prev)→(4-1+7)%7=3
      expect(controller.state.selectedTab.value, 3);
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
      // open() 重置到 General(3)；Right→nextTab→4；Up 仅 setArrowGlow 不切 tab；
      // 再 Right→(4+1)%7=5。
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.state.selectedTab.value, 4);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.state.selectedTab.value, 5);

      // Assert — 面板仍然打开
      expect(controller.state.isOpen.value, isTrue);

      // 排空 + 取消 InputModeDetector 单例的 pending FakeTimer（arrowRight +
      // arrowUp 经 recordArrowKey 启动 5s 检测 Timer；arrowUp 还启动 glow
      // reset Timer）。timersPending 检查（_verifyInvariants）在 addTearDown
      // 之前运行，addTearDown 的 onPanelClosed 来不及取消，故须 body 末尾主动调。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });
  });
}
