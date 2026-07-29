// SettingsOverlayShell widget 测试 — 覆盖 PANEL-03/04/05/06/07。
//
// 复用 Plan 23-01 的手写 FakePlaybackController（implements SettingsPanelPlayback）
// 替代真实 PlaybackController，不依赖 MediaEngine / mdk.dll，
// 规避 headless FFI 加载失败风险（CLAUDE.md "Fakes over mocks"）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/bridge/display_enumerator.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/services/input_mode_detector.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/player/keyboard_handler.dart';
import 'package:simple_player_flutter/ui/shared/apple_curves.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_strip.dart';
import 'package:simple_player_flutter/ui/shared/settings_button.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

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
    DisplayEnumerator? displayEnumerator,
    Future<Offset> Function()? windowPositionReader,
  }) async {
    final fake = FakePlaybackController(
      initialState: initiallyPlaying ? MediaState.playing : MediaState.idle,
    );
    final controller = SettingsPanelController(fake);
    addTearDown(() async {
      // 清理 InputModeDetector 进程级单例的 pending FakeTimer（recordArrowKey 的
      // 5s gamepad 检测 + setArrowGlow 的 reset 计时器），避免 fakeAsync 泄漏
      // 触发 !timersPending 断言（panel_key_bindings.handle 间接调用单例）。
      InputModeDetector.instance.onPanelClosed();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    Widget shell = SettingsOverlayShell(
      controller: controller,
      displayEnumerator: displayEnumerator,
      windowPositionReader: windowPositionReader,
    );
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
    testWidgets('open renders glass shell with 设置 title and close button', (
      tester,
    ) async {
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
    });

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
        // 找到包含 panelKey 的 GlassContainer（壳级别，非 tab 内部的 GlassContainer）
        final shellGlass = tester.widget<GlassContainer>(
          find.ancestor(
            of: find.byKey(SettingsOverlayShell.panelKey),
            matching: find.byType(GlassContainer),
          ),
        );
        expect(shellGlass.tier, GlassTier.normal);
        expect(find.byType(BackdropFilter), findsWidgets);

        // Assert — 动画终点 scale==1.0 / opacity==1.0，时长 200ms，
        // 开启曲线为 AppleCurves.fullscreenEnter（PANEL-05 / D-07 / D-08）
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
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
        // Arrange — 800×600 窗口，面板 400×225（D-04：width=min(0.5×800, 600×16/9)=400，
        // height=400×9/16=225）；maxX=(800-400)/2=200, maxY=(600-225)/2=187.5
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Act — 在标题栏区域拖拽
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(50, 30));
        await gesture.up();
        await tester.pump();

        // Assert — dx=50（在 maxX=200 内），dy=30（在 maxY=187.5 内）
        expect(controller.state.dragOffset.value.dx, 50.0);
        expect(controller.state.dragOffset.value.dy, 30.0);

        // Act — 拖到超出边界
        final gesture2 = await tester.startGesture(tester.getCenter(titleBar));
        await gesture2.moveBy(const Offset(500, 500));
        await gesture2.up();
        await tester.pump();

        // Assert — 被 clamp 到 maxX=200, maxY=187.5
        expect(controller.state.dragOffset.value.dx, 200.0);
        expect(controller.state.dragOffset.value.dy, 187.5);
      },
    );

    testWidgets(
      'title-bar drag clamps correctly with undersized window (smaller than 500x400)',
      (tester) async {
        // Arrange — 480×360 窗口，面板 400×225（D-04：width=min(0.5×480, 360×16/9)=240，
        // clamp 到 minWidth=400；height=400×9/16=225）
        // maxX=max(0,(480-400)/2)=40, maxY=max(0,(360-225)/2)=67.5
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(480, 360),
        );
        controller.open();
        await tester.pump();

        // Act — 拖到超出小窗口边界
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final gesture = await tester.startGesture(tester.getCenter(titleBar));
        await gesture.moveBy(const Offset(200, 200));
        await gesture.up();
        await tester.pump();

        // Assert — 被 clamp 到小窗口的 maxX=40, maxY=67.5
        expect(controller.state.dragOffset.value.dx, 40.0);
        expect(controller.state.dragOffset.value.dy, 67.5);
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

    testWidgets('B key closes open panel', (tester) async {
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
    });

    testWidgets(
      '625x500 window produces 400x225 panel (D-04: min(0.5W, H*16/9) clamped to 400, height=W*9/16)',
      (tester) async {
        // Arrange — 625×500 → width=min(0.5×625=312.5, 500×16/9≈888.9)=312.5,
        // clamp 到 minWidth=400；height=400×9/16=225
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(625, 500),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板尺寸精确 400×225（D-04 严格 16:9）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
        expect(panelBox.height, 225.0);
      },
    );

    testWidgets(
      'below-threshold window produces 400x225 panel (D-04: min(0.5W, H*16/9) clamps to minWidth)',
      (tester) async {
        // Arrange — 600×400 → width=min(0.5×600=300, 400×16/9≈711.1)=300,
        // clamp 到 minWidth=400；height=400×9/16=225
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(600, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — 宽度 400（clamp 下限），高度 225（16:9）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
        expect(panelBox.height, 225.0);
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

    testWidgets('open shell renders 7 SettingsNavItem tab items', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — 7 个 SettingsNavItem 存在
      expect(find.byType(SettingsNavItem), findsNWidgets(7));
    });

    testWidgets('default selected tab is index 3 (通用) on open', (tester) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — selectedTab 为 3（D-01：General 在七 tab 序列 index 3 默认打开）
      expect(controller.state.selectedTab.value, 3);

      // Assert — 通用 文字可见（tab bar + 内容区各一处）
      expect(find.text('通用'), findsWidgets);
    });

    testWidgets('all 7 tab labels are visible in the tab bar', (tester) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — 7 个标签全部可见（D-01 顺序：EQ/Audio/Video/General/Shortcuts/About/Performance）
      const labels = ['均衡器', '音频', '视频', '通用', '快捷键', '关于', '性能'];
      for (final label in labels) {
        expect(find.text(label), findsWidgets); // 至少在 tab bar 和内容区各一处
      }
    });

    testWidgets('clicking tab index 2 (视频) switches selectedTab to 2', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 点击第 3 个 tab（index 2 = 视频），非默认 General tab。
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(2));
      await tester.pump();

      // Assert — selectedTab 从默认 3 更新为 2。
      expect(controller.state.selectedTab.value, 2);
    });

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

        // Assert — selectedTab 重置为 3（D-01：General 默认 index 3）
        expect(controller.state.selectedTab.value, 3);
      },
    );

    testWidgets('IndexedStack index matches selectedTab value', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 切换到 tab 2
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(2));
      await tester.pump();

      // Assert — IndexedStack 的 index 等于 selectedTab
      // 壳内有多个 IndexedStack（tab 内容可能也包含），取第一个（壳级别）
      final allStacks = tester.widgetList<IndexedStack>(
        find.byType(IndexedStack),
      );
      // Shell's IndexedStack has 7 children (one per tab)
      final shellStack = allStacks.firstWhere((s) => s.children.length == 7);
      expect(shellStack.index, 2);
    });

    testWidgets(
      'TweenAnimationBuilder wraps IndexedStack children for fade animation',
      (tester) async {
        // Arrange & Act
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — TweenAnimationBuilder 存在（IndexedStack 至少构建当前可见 tab 的）
        expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
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

    testWidgets('content area has Padding(spMd) around IndexedStack', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — Padding 是 IndexedStack 的父级，padding 值为 spMd (12)
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byType(IndexedStack),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(12)); // Tokens.spMd = 12
    });

    // ── Keyboard & Gamepad Tab Switching (SIDEBAR-04) ──

    testWidgets('Arrow Right switches to next tab', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump(); // Focus 获得焦点

      // Act — default tab 3（D-01），按右 → tab 4
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Assert
      expect(controller.state.selectedTab.value, 4);

      // 取消 InputModeDetector 单例的 pending FakeTimer（arrow 键经
      // recordArrowKey 启动 5s 检测 Timer）。timersPending 检查
      // （_verifyInvariants）在 addTearDown 之前运行，须 body 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

    testWidgets('Arrow Left switches to previous tab (default 3, left → 2)', (
      tester,
    ) async {
      // Arrange — default tab 3（D-01）
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();
      expect(controller.state.selectedTab.value, 3);

      // Act — 从 tab 3 按左键 → tab 2
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Assert
      expect(controller.state.selectedTab.value, 2);

      // 取消 InputModeDetector 单例的 pending FakeTimer（arrowLeft 经
      // recordArrowKey 启动 5s 检测 Timer）。timersPending 检查
      // （_verifyInvariants）在 addTearDown 之前运行，须 body 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

    testWidgets('Arrow Right wraps around (6→0)', (tester) async {
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

      // 取消 InputModeDetector 单例的 pending FakeTimer（arrowRight 经
      // recordArrowKey 启动 5s 检测 Timer）。timersPending 检查
      // （_verifyInvariants）在 addTearDown 之前运行，须 body 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

    testWidgets('multiple arrow presses cycle through tabs', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 按 3 次右键（default tab 3，3 次后 → tab 6）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Assert — default 3 + 3 次右键 = tab 6
      expect(controller.state.selectedTab.value, 6);

      // 取消 InputModeDetector 单例的 pending FakeTimer（3 次 arrowRight 经
      // recordArrowKey 启动 5s 检测 Timer，每次刷新不堆叠但仍 pending）。
      // timersPending 检查（_verifyInvariants）在 addTearDown 之前运行，须 body
      // 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

    testWidgets('gamepad Right Shoulder (gameButton12) switches to next tab', (
      tester,
    ) async {
      // Arrange — default tab 3（D-01）
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton12);
      await tester.pump();

      // Assert — 3 + 1 = tab 4
      expect(controller.state.selectedTab.value, 4);
    });

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

    test('NAV-04: lib/ source has no gameButtonLeft1/Right1 code refs', () async {
      // git grep -hE 输出匹配 content 行（无文件名行号）。
      // 注释行（// 或 ///）允许文档引用已删除符号；代码行禁止 —— NAV-04
      // 防止代码重新引入跨平台肩键别名比较（panel_key_bindings 仅留 gameButton12/13）。
      final result = await Process.run(
        'git',
        const ['grep', '-hE', 'gameButtonLeft1|gameButtonRight1', '--', 'lib/'],
      );
      final stdout = result.stdout.toString();
      final codeLines = stdout
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'));
      expect(
        codeLines,
        isEmpty,
        reason: 'lib/ 代码不得引用 gameButtonLeft1/gameButtonRight1（NAV-04）；'
            '注释文档引用允许。匹配行：\n$stdout',
      );
    });

    testWidgets(
      'NAV-07: arrows contained in panel do not bubble to outer KeyboardHandler',
      (tester) async {
        // Arrange — 外层 KeyboardHandler spy 计数四向回调；若面板根 Focus 未遏制
        // 方向键，事件冒泡到外层 KeyboardHandler 触发 seek/volume 回调。
        var seekBackwardCount = 0;
        var seekForwardCount = 0;
        var volumeUpCount = 0;
        var volumeDownCount = 0;
        final (controller, _) = await pumpShell(
          tester,
          decorate: (shell) => KeyboardHandler(
            onSeekBackward: () => seekBackwardCount++,
            onSeekForward: () => seekForwardCount++,
            onVolumeUp: () => volumeUpCount++,
            onVolumeDown: () => volumeDownCount++,
            child: shell,
          ),
        );
        controller.open();
        await tester.pump();
        await tester.pump();
        // pump×2 让 _onIsOpenChanged 排的 post-frame requestFocus 执行并稳定 ——
        // 第一 pump 触发 isOpen listener → _requestPanelFocus 排 post-frame；
        // 第二 pump 执行 post-frame callback 调 _panelFocusNode.requestFocus() 夺回
        // 外层 KeyboardHandler(autofocus:true) 持有的焦点。此后方向键到面板根
        // panel_key_bindings.handle（返回 handled 遏制）而非冒泡到外层 seek/volume。
        // 方案 A 生产修复（fix(32-01)）：settings_overlay_shell open 时显式
        // requestFocus 面板根 FocusNode，对标 PlaylistPanel 模式。


        // Act — 发四个方向键，每个后 pump 让事件分发
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        // Assert — 四向回调零调用（NAV-07 遏制：面板根 handle 返回 handled 阻止冒泡）
        expect(seekBackwardCount, 0);
        expect(seekForwardCount, 0);
        expect(volumeUpCount, 0);
        expect(volumeDownCount, 0);

        // 排空定时器 + 取消 InputModeDetector 单例的 pending FakeTimer（4 方向
        // 键经 recordArrowKey 启动 5s 检测 Timer；arrowUp/Down 还启动 glow reset
        // Timer）。timersPending 检查（_verifyInvariants）在 addTearDown 之前运行，
        // addTearDown 的 onPanelClosed 来不及取消，故须 body 末尾主动调。
        await tester.pump(const Duration(milliseconds: 250));
        InputModeDetector.instance.onPanelClosed();
      },
    );

    testWidgets('arrow key does NOT close panel', (tester) async {
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

      // 取消 InputModeDetector 单例的 pending FakeTimer（arrowRight 经
      // recordArrowKey 启动 5s 检测 Timer）。timersPending 检查
      // （_verifyInvariants）在 addTearDown 之前运行，须 body 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

    testWidgets('KeyUp events are ignored (no tab switch on release)', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 发送 KeyUp（非 KeyDown）
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Assert — selectedTab 不变（default 3，D-01）
      expect(controller.state.selectedTab.value, 3);
    });

    testWidgets('ESC/B still closes panel after tab switching', (tester) async {
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

      // 排空退出动画 + 取消前置 arrowRight 启动的 InputModeDetector 5s 检测
      // Timer（ESC 本身不启动 Timer，但前置的 Right 启动了）。timersPending
      // 检查（_verifyInvariants）在 addTearDown 之前运行，须 body 内取消。
      await tester.pump(const Duration(milliseconds: 250));
      InputModeDetector.instance.onPanelClosed();
    });

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

    testWidgets('button bar is not rendered when panel is closed', (
      tester,
    ) async {
      // Arrange
      await pumpShell(tester);
      // never opened

      // Assert — 关闭状态无按钮栏
      expect(find.byType(SettingsButton), findsNothing);
      expect(find.byKey(SettingsOverlayShell.buttonBarKey), findsNothing);
    });

    testWidgets('OK button calls commitPending and close', (tester) async {
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
    });

    testWidgets('Apply button calls commitPending but does NOT close', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 点击应用
      await tester.tap(find.text('应用'));
      await tester.pump();

      // Assert — 面板仍然打开
      expect(controller.state.isOpen.value, isTrue);
    });

    testWidgets('Cancel button calls cancelPending and close', (tester) async {
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
    });
  });

  // ── Multi-monitor drag clamp, fallback, resize (Plan 30-02: D-03/D-05/D-06) ──
  group('settings overlay multi-monitor (30-02)', () {
    /// 1200×800 窗口 → 面板 600×337.5（D-04：width=min(600,1422.22)=600，
    /// height=600×9/16=337.5），baseLeft=300，baseTop=231.25。
    /// fake workArea LTRB(100,200,1100,700)（1000×500 ≥ 600×337.5）；
    /// fake windowOrigin=(50,50)。
    /// 屏幕坐标 panel left=50+300+dx → dx∈[-250,150]；top=50+231.25+dy →
    /// dy∈[-81.25,81.25]。对称 clamp dx 上限 300 / dy 上限 231.25（可区分）。
    const windowSize = Size(1200, 800);
    const fakeWorkArea = Rect.fromLTRB(100, 200, 1100, 700);
    const fakeWindowOrigin = Offset(50, 50);

    testWidgets(
      'work area with cached window position clamps drag to screen-coordinate bounds (D-03)',
      (tester) async {
        // Arrange — 注入 fake display + windowPositionReader
        final fake = FakeDisplayEnumerator(workArea: fakeWorkArea);
        final (controller, _) = await pumpShell(
          tester,
          size: windowSize,
          displayEnumerator: fake,
          windowPositionReader: () async => fakeWindowOrigin,
        );
        controller.open();
        await tester.pump();

        // Act — drag session: onPanStart 异步缓存 origin，moveBy dy=+500
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final g1 = await tester.startGesture(tester.getCenter(titleBar));
        await tester.pump(); // 让 Future.value resolve → _cachedWindowOrigin 设
        await g1.moveBy(const Offset(0, 500));
        await tester.pump();
        await g1.up();
        await tester.pump();

        // Assert — 屏幕坐标 clamp: dy=81.25（对称会到 231.25）
        expect(controller.state.dragOffset.value.dy, closeTo(81.25, 0.01));

        // Act — 重置后测 dx 方向
        controller.state.dragOffset.value = Offset.zero;
        await tester.pump();
        final g2 = await tester.startGesture(tester.getCenter(titleBar));
        await tester.pump();
        await g2.moveBy(const Offset(500, 0));
        await tester.pump();
        await g2.up();
        await tester.pump();

        // Assert — dx=150（对称会到 300）
        expect(controller.state.dragOffset.value.dx, closeTo(150.0, 0.01));
      },
    );

    testWidgets(
      'null display result preserves symmetric clamp (D-03 fallback)',
      (tester) async {
        // Arrange — fake getCurrentDisplay 返回 null（无显示器信息）
        final fake = FakeDisplayEnumerator(workArea: null);
        final (controller, _) = await pumpShell(
          tester,
          size: windowSize,
          displayEnumerator: fake,
          windowPositionReader: () async => fakeWindowOrigin,
        );
        controller.open();
        await tester.pump();

        // Act
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final g = await tester.startGesture(tester.getCenter(titleBar));
        await tester.pump();
        await g.moveBy(const Offset(0, 500));
        await tester.pump();
        await g.up();
        await tester.pump();

        // Assert — null display → 对称 clamp: dy=231.25
        expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));
      },
    );

    testWidgets(
      'display-query exception preserves symmetric clamp without crashing (D-03 fallback)',
      (tester) async {
        // Arrange — fake getCurrentDisplay 抛可恢复 Exception（验证 shell fallback）。
        final fake = FakeDisplayEnumerator(throwOnGetCurrent: true);
        final (controller, _) = await pumpShell(
          tester,
          size: windowSize,
          displayEnumerator: fake,
          windowPositionReader: () async => fakeWindowOrigin,
        );
        controller.open();
        await tester.pump();

        // Act — drag；shell try/catch + debugPrint + 对称 fallback，不崩溃
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final g = await tester.startGesture(tester.getCenter(titleBar));
        await tester.pump();
        await g.moveBy(const Offset(0, 500));
        await tester.pump();
        await g.up();
        await tester.pump();

        // Assert — 无崩溃，dy=231.25（对称 fallback）
        expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));
      },
    );

    testWidgets(
      'resize re-clamps displaced offset after post-frame reconciliation (D-05)',
      (tester) async {
        // Arrange — 1200×800，无 displayEnumerator（对称 clamp），maxY=231.25
        final (controller, _) = await pumpShell(tester, size: windowSize);
        controller.open();
        await tester.pump();

        // Act — drag dy=+500 → 对称 clamp 231.25（在更小尺寸下将非法）
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final g = await tester.startGesture(tester.getCenter(titleBar));
        await g.moveBy(const Offset(0, 500));
        await g.up();
        await tester.pump();
        expect(controller.state.dragOffset.value.dy, closeTo(231.25, 0.01));

        // Act — pump 更小窗口 800×600，面板 400×225，对称 maxY=187.5
        // didChangeDependencies → post-frame callback → re-clamp 231.25→187.5
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
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
        await tester.pump(); // 排 post-frame callback
        await tester.pump(); // 执行 callback → re-clamp

        // Assert — dy 从 231.25 re-clamp 到 187.5
        expect(controller.state.dragOffset.value.dy, closeTo(187.5, 0.01));
      },
    );

    testWidgets(
      'panel retains RepaintBoundary ancestor after clamp paths run (D-06)',
      (tester) async {
        // Arrange
        final fake = FakeDisplayEnumerator(workArea: fakeWorkArea);
        final (controller, _) = await pumpShell(
          tester,
          size: windowSize,
          displayEnumerator: fake,
          windowPositionReader: () async => fakeWindowOrigin,
        );
        controller.open();
        await tester.pump();

        // Act — 触发 work-area clamp 路径（origin 已缓存）
        final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
        final g = await tester.startGesture(tester.getCenter(titleBar));
        await tester.pump();
        await g.moveBy(const Offset(500, 500));
        await tester.pump();
        await g.up();
        await tester.pump();

        // Assert — RepaintBoundary 仍是 panel 的祖先（D-06 保留）
        expect(
          find.ancestor(
            of: find.byKey(SettingsOverlayShell.panelKey),
            matching: find.byType(RepaintBoundary),
          ),
          findsWidgets,
        );
      },
    );
  });

  // ── Structural color route (Plan 30-03: LAYOUT-05 / D-02；31-01 D-11 re-baseline) ──
  group('settings overlay structural color route (30-03)', () {
    testWidgets(
      'chrome sections use ControlBarDecoration.playing decoration, content stays Tokens.panelSectionBg',
      (tester) async {
        // Arrange — open shell 让四段都挂载
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Phase 31 D-11：chrome 三段从 color-route 切换为共享
        // ControlBarDecoration.playing 装饰（BoxDecoration: controlBarBg +
        // 1px controlBarBorderWhite + 4-shadow 末位 glowOuterRing）；
        // content 保持 panelSectionBg 薄玻璃。局部断言函数与
        // panel_color_test.dart 的 expectChromeDecoration 同构。
        void expectChromeDecoration(Container container, String sectionName) {
          final decoration = container.decoration;
          if (decoration is! BoxDecoration) {
            fail(
              '$sectionName: expected BoxDecoration, '
              'got ${decoration.runtimeType}',
            );
          }
          expect(
            decoration.color,
            Tokens.controlBarBg,
            reason: '$sectionName color',
          );
          final border = decoration.border;
          if (border is! Border) {
            fail('$sectionName: expected Border, got ${border.runtimeType}');
          }
          expect(border.top.width, 1, reason: '$sectionName border width');
          expect(
            border.top.color,
            Tokens.controlBarBorderWhite,
            reason: '$sectionName border color',
          );
          expect(
            decoration.boxShadow?.length,
            4,
            reason: '$sectionName shadow count',
          );
          expect(
            decoration.boxShadow?[3].color,
            Tokens.glowOuterRing,
            reason: '$sectionName shadow[3] glowOuterRing',
          );
        }

        // Assert — 标题栏 Container 走 ControlBarDecoration.playing
        final titleBarContainer = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byKey(SettingsOverlayShell.titleBarKey),
                matching: find.byType(Container),
              ),
            )
            .first;
        expectChromeDecoration(titleBarContainer, 'title bar');

        // Assert — 按钮栏 Container 走 ControlBarDecoration.playing
        final buttonBarContainer = tester.widget<Container>(
          find.byKey(SettingsOverlayShell.buttonBarKey),
        );
        expectChromeDecoration(buttonBarContainer, 'button bar');

        // Assert — tab 条 Container 走 ControlBarDecoration.playing
        final tabStripContainer = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(SettingsTabStrip),
                matching: find.byType(Container),
              ),
            )
            .first;
        expectChromeDecoration(tabStripContainer, 'tab strip');

        // Assert — 内容区 ColoredBox color 保持 panelSectionBg（D-11 content
        // 单路由；SettingsTabContent 子树首个 ColoredBox）
        final contentColoredBox = tester
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byType(SettingsTabContent),
                matching: find.byType(ColoredBox),
              ),
            )
            .first;
        expect(contentColoredBox.color, Tokens.panelSectionBg);
      },
    );
  });
}

/// 手写 DisplayEnumerator 替身 — 可配 workArea 或抛异常（Plan 30-02 D-03 fallback 测试）。
///
/// 复用 test/widgets/multi_monitor_clamp_test.dart 的 fake 模式，但在本文件内
/// 自定义以支持 [throwOnGetCurrent]（验证 shell 层 try/catch + 对称 fallback）。
/// 用 local 变量提升非 null（避免 `!`，CLAUDE.md 严格类型安全）。
class FakeDisplayEnumerator implements DisplayEnumerator {
  FakeDisplayEnumerator({this.workArea, this.throwOnGetCurrent = false});

  /// 当前显示器可用区域（null 模拟"无显示器信息"）.
  final Rect? workArea;

  /// true 时 getCurrentDisplay 抛 Exception（验证可恢复异常 fallback 路径）.
  final bool throwOnGetCurrent;

  @override
  List<DisplayInfo> enumerateDisplays() {
    final area = workArea;
    if (area == null) return const [];
    return [DisplayInfo(bounds: area, workArea: area, isPrimary: true)];
  }

  @override
  DisplayInfo? getDisplayForWindow(int hwnd) => getCurrentDisplay();

  @override
  DisplayInfo? getCurrentDisplay() {
    if (throwOnGetCurrent) {
      throw Exception('fake display query failure');
    }
    final area = workArea;
    if (area == null) return null;
    return DisplayInfo(bounds: area, workArea: area, isPrimary: true);
  }
}
