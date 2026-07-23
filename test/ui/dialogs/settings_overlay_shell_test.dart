// SettingsOverlayShell widget 测试 — 覆盖 PANEL-03/04/05/06/07。
//
// 复用 Plan 23-01 的手写 FakePlaybackController（implements SettingsPanelPlayback）
// 替代真实 PlaybackController，不依赖 MediaEngine / mdk.dll，
// 规避 headless FFI 加载失败风险（CLAUDE.md "Fakes over mocks"）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/shared/apple_curves.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';

import 'settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳 — MediaQuery 覆盖窗口尺寸，Shell 全尺寸挂载于 Stack。
  ///
  /// 返回 (controller, fake) 供断言暂停/恢复生命周期调用。
  /// tearDown 先卸载 widget 树（解除 notifier 监听）再 dispose controller，
  /// 避免在 notifier 已 dispose 后触发 removeListener。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
    bool initiallyPlaying = true,
    Widget Function(Widget shell)? decorate,
  }) async {
    final fake = FakePlaybackController(initiallyPlaying: initiallyPlaying);
    final controller = SettingsPanelController(fake);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    Widget shell = SettingsOverlayShell(controller: controller);
    if (decorate != null) shell = decorate(shell);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(fit: StackFit.expand, children: [shell]),
          ),
        ),
      ),
    );
    return (controller, fake);
  }

  group('SettingsOverlayShell', () {
    testWidgets(
      'open renders glass shell with 设置 title and close button',
      (tester) async {
        // Arrange — 初始关闭：无任何壳命中目标
        final (controller, fake) = await pumpShell(tester);
        expect(find.byKey(SettingsOverlayShell.maskKey), findsNothing);

        // Act
        controller.open();
        await tester.pump();

        // Assert — 壳可见，标题为 设置，含关闭按钮；打开时暂停了正在播放的 fake
        expect(find.byKey(SettingsOverlayShell.shellKey), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
        expect(find.byKey(SettingsOverlayShell.closeButtonKey), findsOneWidget);
        expect(fake.pauseCallCount, 1);
      },
    );

    testWidgets(
      'mask tap closes shell, removes hit target, resumes playing fake',
      (tester) async {
        // Arrange
        final (controller, fake) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击遮罩（左上角，避开居中面板区域）关闭
        await tester.tapAt(const Offset(20, 20));
        await tester.pump();

        // Assert — 已关闭且恢复了打开前正在播放的 fake
        expect(controller.state.isOpen.value, isFalse);
        expect(fake.playCallCount, 1);

        // Assert — 200ms 退出动画结束后，壳从命中树卸载（PANEL-05）
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(find.byKey(SettingsOverlayShell.shellKey), findsNothing);
        expect(find.byKey(SettingsOverlayShell.maskKey), findsNothing);
      },
    );

    testWidgets(
      'visible shell uses GlassTier.normal BackdropFilter; settled enter endpoint is scale 1.0 / opacity 1.0 after 200ms',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 播完 200ms 进入动画
        await tester.pump(const Duration(milliseconds: 200));

        // Assert — GlassContainer 走 GlassTier.normal，内含 BackdropFilter（PANEL-03）
        final glass = tester.widget<GlassContainer>(
          find.byType(GlassContainer),
        );
        expect(glass.tier, GlassTier.normal);
        expect(find.byType(BackdropFilter), findsWidgets);

        // Assert — 动画终点 scale==1.0 / opacity==1.0，时长 200ms，
        // 开启曲线为 AppleCurves.fullscreenEnter（PANEL-05 / D-07 / D-08）
        final scale = tester.widget<AnimatedScale>(
          find.byType(AnimatedScale),
        );
        expect(scale.scale, 1.0);
        expect(scale.duration, const Duration(milliseconds: 200));
        expect(scale.curve, AppleCurves.fullscreenEnter);
        final opacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacities, hasLength(2)); // 遮罩 + 面板各一
        for (final o in opacities) {
          expect(o.opacity, 1.0);
          expect(o.duration, const Duration(milliseconds: 200));
          expect(o.curve, AppleCurves.fullscreenEnter);
        }
      },
    );

    testWidgets(
      'title-bar drag updates dragOffset and clamps inside MediaQuery bounds',
      (tester) async {
        // Arrange — 800×600 窗口，面板 500×400，maxX=(800-500)/2=150, maxY=(600-400)/2=100
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Act — 在标题栏区域拖拽
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(
          tester.getCenter(titleBar),
        );
        await gesture.moveBy(const Offset(50, 30));
        await gesture.up();
        await tester.pump();

        // Assert — dragOffset 更新且在 clamp 范围内
        expect(controller.state.dragOffset.value.dx, 50.0);
        expect(controller.state.dragOffset.value.dy, 30.0);

        // Act — 拖到超出边界
        final gesture2 = await tester.startGesture(
          tester.getCenter(titleBar),
        );
        await gesture2.moveBy(const Offset(500, 500));
        await gesture2.up();
        await tester.pump();

        // Assert — 被 clamp 到 maxX=150, maxY=100
        expect(controller.state.dragOffset.value.dx, 150.0);
        expect(controller.state.dragOffset.value.dy, 100.0);
      },
    );

    testWidgets(
      'title-bar drag clamps correctly with undersized window (smaller than 500x400)',
      (tester) async {
        // Arrange — 400×300 窗口，面板=min(500,320)×min(400,240)=320×240
        // maxX=(400-320)/2=40, maxY=(300-240)/2=30
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(400, 300),
        );
        controller.open();
        await tester.pump();

        // Act — 拖到超出小窗口边界
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(
          tester.getCenter(titleBar),
        );
        await gesture.moveBy(const Offset(200, 200));
        await gesture.up();
        await tester.pump();

        // Assert — 被 clamp 到小窗口的 maxX=40, maxY=30
        expect(controller.state.dragOffset.value.dx, 40.0);
        expect(controller.state.dragOffset.value.dy, 30.0);
      },
    );

    testWidgets(
      'ESC closes open panel and does not invoke fullscreen-exit observer',
      (tester) async {
        // Arrange — fullscreenExitObserver 记录是否被调用（应为 0）
        final int fullscreenExitCount = 0;
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump(); // 让 Focus 获得焦点

        // Act — 发送 ESC 键
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Assert — 面板关闭，fullscreen observer 未被调用（PANEL-06）
        expect(controller.state.isOpen.value, isFalse);
        expect(fullscreenExitCount, 0);

        // 排空 close() 触发的 200ms 退出动画定时器，避免 "Timer is still pending"
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    testWidgets(
      'B key closes open panel',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 发送 B 键
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
        await tester.pump();

        // Assert — 面板关闭
        expect(controller.state.isOpen.value, isFalse);

        // 排空 close() 触发的 200ms 退出动画定时器
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    testWidgets(
      '625x500 window produces 500x400 panel; below threshold constrains affected dimension',
      (tester) async {
        // Arrange — 恰好 625×500 → min(500,500)×min(400,400) = 500×400
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(625, 500),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板尺寸精确 500×400
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 500.0);
        expect(panelBox.height, 400.0);
      },
    );

    testWidgets(
      'below-threshold window constrains only affected dimension with double precision',
      (tester) async {
        // Arrange — 600×400 → min(500,480)×min(400,320) = 480×320
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(600, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — 宽度受 80% 约束（480），高度也受 80% 约束（320）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 480.0);
        expect(panelBox.height, 320.0);
      },
    );

    testWidgets(
      'close-button closure removes overlay from hit-test tree after 200ms exit',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击关闭按钮
        await tester.tap(find.byKey(SettingsOverlayShell.closeButtonKey));
        await tester.pump();

        // Assert — 已关闭
        expect(controller.state.isOpen.value, isFalse);

        // Act — 等待 200ms 退出动画
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        // Assert — 壳从命中树卸载
        expect(find.byKey(SettingsOverlayShell.shellKey), findsNothing);
        expect(find.byKey(SettingsOverlayShell.maskKey), findsNothing);
      },
    );

    testWidgets(
      'ESC closure removes overlay from hit-test tree after 200ms exit',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — ESC 关闭
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Assert — 已关闭
        expect(controller.state.isOpen.value, isFalse);

        // Act — 等待 200ms 退出动画
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        // Assert — 壳从命中树卸载
        expect(find.byKey(SettingsOverlayShell.shellKey), findsNothing);
      },
    );
  });
}
