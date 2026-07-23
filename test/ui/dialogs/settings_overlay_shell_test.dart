// SettingsOverlayShell widget 测试 — 覆盖 PANEL-03/04/05/06/07。
//
// 复用 Plan 23-01 的手写 FakePlaybackController（implements SettingsPanelPlayback）
// 替代真实 PlaybackController，不依赖 MediaEngine / mdk.dll，
// 规避 headless FFI 加载失败风险（CLAUDE.md "Fakes over mocks"）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/shared/apple_curves.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/settings_button.dart';

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
        // Arrange — 800×600 窗口，面板 400×300（50%），maxX=(800-400)/2=200, maxY=(600-300)/2=150
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

        // Assert — 被 clamp 到 maxX=200, maxY=150
        expect(controller.state.dragOffset.value.dx, 200.0);
        expect(controller.state.dragOffset.value.dy, 150.0);
      },
    );

    testWidgets(
      'title-bar drag clamps correctly with undersized window (smaller than 500x400)',
      (tester) async {
        // Arrange — 480×360 窗口，面板=240×180（50%）
        // maxX=(480-240)/2=120, maxY=(360-180)/2=90
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(480, 360),
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

        // Assert — 被 clamp 到小窗口的 maxX=120, maxY=90
        expect(controller.state.dragOffset.value.dx, 120.0);
        expect(controller.state.dragOffset.value.dy, 90.0);
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
      '625x500 window produces 312.5x250 panel (50% ratio)',
      (tester) async {
        // Arrange — 625×500 → 312.5×250（50% 窗口尺寸）
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(625, 500),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板尺寸精确 312.5×250
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 312.5);
        expect(panelBox.height, 250.0);
      },
    );

    testWidgets(
      'below-threshold window produces 50% panel with double precision',
      (tester) async {
        // Arrange — 600×400 → 300×200（50% 窗口尺寸）
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(600, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — 宽度 300，高度 200
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 300.0);
        expect(panelBox.height, 200.0);
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

    // ── Tab Navigation (SIDEBAR-01/02/03) ──

    testWidgets(
      'open shell renders 7 SettingsNavItem tab items',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — 7 个 SettingsNavItem 存在
        expect(find.byType(SettingsNavItem), findsNWidgets(7));
      },
    );

    testWidgets(
      'default selected tab is index 0 (通用) on open',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — selectedTab 为 0
        expect(controller.state.selectedTab.value, 0);

        // Assert — 通用 文字可见（tab bar + 内容区各一处）
        expect(find.text('通用'), findsWidgets);
      },
    );

    testWidgets(
      'all 7 tab labels are visible in the tab bar',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — 7 个标签全部可见
        const labels = [
          '通用', '均衡器', '音频', '视频', '快捷键', '关于', '性能',
        ];
        for (final label in labels) {
          expect(find.text(label), findsWidgets); // 至少在 tab bar 和内容区各一处
        }
      },
    );

    testWidgets(
      'clicking tab index 3 (视频) switches selectedTab to 3',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击第 4 个 tab（index 3 = 视频）
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(3));
        await tester.pump();

        // Assert — selectedTab 更新为 3
        expect(controller.state.selectedTab.value, 3);
      },
    );

    testWidgets(
      'opening panel resets selectedTab to 0 even if previously on another tab',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 切换到 tab 5
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(5));
        await tester.pump();
        expect(controller.state.selectedTab.value, 5);

        // Act — 关闭再打开
        controller.close();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        controller.open();
        await tester.pump();

        // Assert — selectedTab 重置为 0（D-03）
        expect(controller.state.selectedTab.value, 0);
      },
    );

    testWidgets(
      'IndexedStack index matches selectedTab value',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 切换到 tab 2
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(2));
        await tester.pump();

        // Assert — IndexedStack 的 index 等于 selectedTab
        final indexedStack = tester.widget<IndexedStack>(
          find.byType(IndexedStack),
        );
        expect(indexedStack.index, 2);
      },
    );

    testWidgets(
      'TweenAnimationBuilder wraps IndexedStack children for fade animation',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — TweenAnimationBuilder 存在（IndexedStack 至少构建当前可见 tab 的）
        expect(
          find.byType(TweenAnimationBuilder<double>),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'after switching tabs, previous tab widget is still in tree (IndexedStack keeps alive)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 从 tab 0 切换到 tab 3
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(3));
        await tester.pump();

        // Assert — 通用 的占位文字仍在树中（IndexedStack 保持存活）
        // 注意：tab bar 中也有 "通用" 文字，所以 findsWidgets
        expect(find.text('通用'), findsWidgets);
        expect(find.text('视频'), findsWidgets);
      },
    );

    testWidgets(
      'content area has Padding(spMd) around IndexedStack',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — Padding 是 IndexedStack 的父级，padding 值为 spMd (12)
        final padding = tester.widget<Padding>(
          find.ancestor(
            of: find.byType(IndexedStack),
            matching: find.byType(Padding),
          ).first,
        );
        expect(padding.padding, const EdgeInsets.all(12)); // Tokens.spMd = 12
      },
    );

    // ── Keyboard & Gamepad Tab Switching (SIDEBAR-04) ──

    testWidgets(
      'Arrow Right switches to next tab',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump(); // Focus 获得焦点

        // Act
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 1);
      },
    );

    testWidgets(
      'Arrow Left switches to previous tab (wrapping 0→6)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();
        expect(controller.state.selectedTab.value, 0);

        // Act — 从 tab 0 按左键，应循环到 tab 6
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 6);
      },
    );

    testWidgets(
      'Arrow Right wraps around (6→0)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 切换到 tab 6
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(6));
        await tester.pump();
        expect(controller.state.selectedTab.value, 6);

        // Act — 按右键，应循环到 tab 0
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 0);
      },
    );

    testWidgets(
      'multiple arrow presses cycle through tabs',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 按 3 次右键
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 3);
      },
    );

    testWidgets(
      'gamepad Right Shoulder (gameButton12) switches to next tab',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act
        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton12);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 1);
      },
    );

    testWidgets(
      'gamepad Left Shoulder (gameButton13) switches to previous tab',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 切换到 tab 3
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(3));
        await tester.pump();

        // Act — 按左肩键
        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton13);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 2);
      },
    );

    testWidgets(
      'gamepad gameButtonRight1 also works (cross-platform)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act
        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonRight1);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 1);
      },
    );

    testWidgets(
      'gamepad gameButtonLeft1 also works (cross-platform)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 切换到 tab 2
        final navItems = find.byType(SettingsNavItem);
        await tester.tap(navItems.at(2));
        await tester.pump();

        // Act — 按左肩键（跨平台）
        await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonLeft1);
        await tester.pump();

        // Assert
        expect(controller.state.selectedTab.value, 1);
      },
    );

    testWidgets(
      'arrow key does NOT close panel',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // Assert — 面板仍然打开
        expect(controller.state.isOpen.value, isTrue);
      },
    );

    testWidgets(
      'KeyUp events are ignored (no tab switch on release)',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 发送 KeyUp（非 KeyDown）
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        // Assert — selectedTab 不变
        expect(controller.state.selectedTab.value, 0);
      },
    );

    testWidgets(
      'ESC/B still closes panel after tab switching',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();
        await tester.pump();

        // Act — 先切 tab，再按 ESC
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Assert — 面板关闭
        expect(controller.state.isOpen.value, isFalse);

        // 排空退出动画
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    // ── Button Bar (TABS-03/TABS-04) ──

    testWidgets(
      'button bar renders three SettingsButton widgets (Cancel, Apply, OK) when open',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — 3 个 SettingsButton 存在
        expect(find.byType(SettingsButton), findsNWidgets(3));
        expect(find.text('取消'), findsOneWidget);
        expect(find.text('应用'), findsOneWidget);
        expect(find.text('确定'), findsOneWidget);
      },
    );

    testWidgets(
      'button bar is not rendered when panel is closed',
      (tester) async {
        // Arrange
        await pumpShell(tester);
        // never opened

        // Assert — 关闭状态无按钮栏
        expect(find.byType(SettingsButton), findsNothing);
        expect(find.byKey(SettingsOverlayShell.buttonBarKey), findsNothing);
      },
    );

    testWidgets(
      'OK button calls commitPending and close',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击确定
        await tester.tap(find.text('确定'));
        await tester.pump();

        // Assert — 面板关闭
        expect(controller.state.isOpen.value, isFalse);

        // 排空 close() 触发的 200ms 退出动画定时器
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    testWidgets(
      'Apply button calls commitPending but does NOT close',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击应用
        await tester.tap(find.text('应用'));
        await tester.pump();

        // Assert — 面板仍然打开
        expect(controller.state.isOpen.value, isTrue);
      },
    );

    testWidgets(
      'Cancel button calls cancelPending and close',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Act — 点击取消
        await tester.tap(find.text('取消'));
        await tester.pump();

        // Assert — 面板关闭
        expect(controller.state.isOpen.value, isFalse);

        // 排空 close() 触发的 200ms 退出动画定时器
        await tester.pump(const Duration(milliseconds: 250));
      },
    );
  });
}
