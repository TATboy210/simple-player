// SettingsOverlayShell 集成测试 — 覆盖面板生命周期、响应式断点、拖拽、键盘、RepaintBoundary。
//
// 验证端到端路径：打开→操作→关闭，跨窗口尺寸切换，手柄/键盘导航。
// 复用 FakePlaybackController，不依赖 mdk.dll。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import 'settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳 — MediaQuery 覆盖窗口尺寸。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
  }) async {
    final fake = FakePlaybackController();
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

  group('Settings Panel Lifecycle', () {
    testWidgets('open panel -> mask + panel visible + title set', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);

      // Act
      controller.open();
      await tester.pump();

      // Assert
      expect(find.byKey(SettingsOverlayShell.shellKey), findsOneWidget);
      expect(find.byKey(SettingsOverlayShell.maskKey), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(controller.state.isOpen.value, isTrue);
    });

    testWidgets('close panel -> mask + panel removed after exit animation', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 点击遮罩关闭
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      // Assert — isOpen 立即为 false
      expect(controller.state.isOpen.value, isFalse);

      // Act — 等退出动画播完
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      // Assert — 壳从命中树移除
      expect(find.byKey(SettingsOverlayShell.shellKey), findsNothing);
      expect(find.byKey(SettingsOverlayShell.maskKey), findsNothing);
    });

    testWidgets('reopen after close re-mounts the shell', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      controller.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Act — 重新打开
      controller.open();
      await tester.pump();

      // Assert — 壳重新出现
      expect(find.byKey(SettingsOverlayShell.shellKey), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });
  });

  group('Tab Switching', () {
    testWidgets('switch tab -> content changes (IndexedStack index)', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 点击第 3 个 tab（视频）
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(3));
      await tester.pump();

      // Assert — selectedTab 更新
      expect(controller.state.selectedTab.value, 3);

      // Assert — IndexedStack 的 index 也更新
      final shellStack = tester.widgetList<IndexedStack>(find.byType(IndexedStack))
          .firstWhere((s) => s.children.length == 7);
      expect(shellStack.index, 3);
    });

    testWidgets('switch back to tab 0 (通用)', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 切到 tab 4 再切回 0
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(4));
      await tester.pump();
      await tester.tap(navItems.at(0));
      await tester.pump();

      // Assert
      expect(controller.state.selectedTab.value, 0);
    });
  });

  group('Responsive Breakpoint Crossing', () {
    testWidgets('window >= 800px renders tab items with normal font', (tester) async {
      // Arrange — 1000×800 → isCompact = false
      final (controller, _) = await pumpShell(
        tester,
        size: const Size(1000, 800),
      );
      controller.open();
      await tester.pump();

      // Assert — 所有 nav item 使用 normal 字体
      final navItems = tester.widgetList<SettingsNavItem>(
        find.byType(SettingsNavItem),
      );
      for (final item in navItems) {
        expect(item.fontSize, Tokens.tabBarFontNormal);
        expect(item.spacing, Tokens.tabBarSpacingNormal);
      }
    });

    testWidgets('window < 800px renders tab items with compact font', (tester) async {
      // Arrange — 600×400 → isCompact = true
      final (controller, _) = await pumpShell(
        tester,
        size: const Size(600, 400),
      );
      controller.open();
      await tester.pump();

      // Assert — 所有 nav item 使用 compact 字体
      final navItems = tester.widgetList<SettingsNavItem>(
        find.byType(SettingsNavItem),
      );
      for (final item in navItems) {
        expect(item.fontSize, Tokens.tabBarFontCompact);
        expect(item.spacing, Tokens.tabBarSpacingCompact);
      }
    });

    testWidgets('resize across 800px breakpoint changes tab bar mode immediately', (tester) async {
      // Arrange — 从 compact 模式开始
      final (controller, _) = await pumpShell(
        tester,
        size: const Size(600, 400),
      );
      controller.open();
      await tester.pump();

      // Assert — 初始 compact
      var navItems = tester.widgetList<SettingsNavItem>(find.byType(SettingsNavItem));
      expect(navItems.first.fontSize, Tokens.tabBarFontCompact);

      // Act — 重建 widget 树，切换到 normal 模式
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 800)),
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
      await tester.pump();

      // Assert — 立即切换到 normal 字体（无过渡动画）
      navItems = tester.widgetList<SettingsNavItem>(find.byType(SettingsNavItem));
      expect(navItems.first.fontSize, Tokens.tabBarFontNormal);
    });
  });

  group('Drag Bounds', () {
    testWidgets('drag title bar -> panel moves within bounds', (tester) async {
      // Arrange — 1200×800 窗口 → 面板 600×480, maxX=(1200-600)/2=300, maxY=(800-480)/2=160
      final (controller, _) = await pumpShell(
        tester,
        size: const Size(1200, 800),
      );
      controller.open();
      await tester.pump();

      // Act — 在标题栏拖拽
      final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
      final gesture = await tester.startGesture(tester.getCenter(titleBar));
      await gesture.moveBy(const Offset(100, 20));
      await gesture.up();
      await tester.pump();

      // Assert — dx=100（在 maxX=300 内），dy=20（在 maxY=160 内）
      expect(controller.state.dragOffset.value.dx, 100.0);
      expect(controller.state.dragOffset.value.dy, 20.0);
    });

    testWidgets('drag beyond bounds is clamped', (tester) async {
      // Arrange — 1200×800 窗口 → 面板 600×480, maxX=300, maxY=160
      final (controller, _) = await pumpShell(
        tester,
        size: const Size(1200, 800),
      );
      controller.open();
      await tester.pump();

      // Act — 拖到超出边界
      final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
      final gesture = await tester.startGesture(tester.getCenter(titleBar));
      await gesture.moveBy(const Offset(500, 200));
      await gesture.up();
      await tester.pump();

      // Assert — 被 clamp 到 maxX=300, maxY=160
      expect(controller.state.dragOffset.value.dx, 300.0);
      expect(controller.state.dragOffset.value.dy, 160.0);
    });
  });

  group('Keyboard Shortcuts', () {
    testWidgets('ESC closes panel', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump(); // Focus 获得焦点

      // Act
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Assert
      expect(controller.state.isOpen.value, isFalse);
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('B key closes panel', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.pump();

      // Assert
      expect(controller.state.isOpen.value, isFalse);
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('LB (gameButton13) cycles tabs', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 先切到 tab 3，再按左肩键
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(3));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton13);
      await tester.pump();

      // Assert — 回到 tab 2
      expect(controller.state.selectedTab.value, 2);
    });

    testWidgets('RB (gameButton12) cycles tabs', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();
      await tester.pump();

      // Act — 按右肩键
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButton12);
      await tester.pump();

      // Assert — 切到 tab 1
      expect(controller.state.selectedTab.value, 1);
    });
  });

  group('RepaintBoundary Isolation', () {
    testWidgets('panel wrapped in RepaintBoundary', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester, size: const Size(800, 600));
      controller.open();
      await tester.pump();

      // Assert — RepaintBoundary 是 FocusTraversalGroup 的祖先
      final rb = find.ancestor(
        of: find.byType(FocusTraversalGroup),
        matching: find.byType(RepaintBoundary),
      );
      expect(rb, findsWidgets);
    });

    testWidgets('BackdropFilter present during animation', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester, size: const Size(800, 600));
      controller.open();
      await tester.pump();

      // Assert — GlassContainer 的 BackdropFilter 存在
      expect(find.byType(BackdropFilter), findsWidgets);
    });
  });

  // ── SCALE Success Criteria (Phase 27 ROADMAP) ──
  //
  // 验证 ROADMAP Phase 27 的 5 条 Success Criteria 全部由自动化测试覆盖。

  group('SCALE Success Criteria', () {
    // SC-1: MediaQuery.size 检测窗口尺寸，面板按比例缩放
    testWidgets('SC-1: MediaQuery.size drives panel sizing at 3 window sizes', (tester) async {
      // 测试 3 个窗口尺寸，确认面板宽度随窗口变化

      // 1920×1080 → width=1536, clamp to 600
      final (ctrl1, _) = await pumpShell(tester, size: const Size(1920, 1080));
      ctrl1.open();
      await tester.pump();
      var panel = tester.widget<SizedBox>(find.byKey(SettingsOverlayShell.panelKey));
      expect(panel.width, 600.0);
      ctrl1.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 800×600 → width=640, clamp to 600
      final (ctrl2, _) = await pumpShell(tester, size: const Size(800, 600));
      ctrl2.open();
      await tester.pump();
      panel = tester.widget<SizedBox>(find.byKey(SettingsOverlayShell.panelKey));
      expect(panel.width, 600.0);
      ctrl2.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 500×400 → width=400
      final (ctrl3, _) = await pumpShell(tester, size: const Size(500, 400));
      ctrl3.open();
      await tester.pump();
      panel = tester.widget<SizedBox>(find.byKey(SettingsOverlayShell.panelKey));
      expect(panel.width, 400.0);
    });

    // SC-2: 全屏模式面板600×480
    testWidgets('SC-2: fullscreen mode panel is 600×480', (tester) async {
      // Arrange — 1920×1080 模拟全屏
      final (controller, _) = await pumpShell(tester, size: const Size(1920, 1080));
      controller.open();
      await tester.pump();

      // Assert — 面板精确 600×480
      final panel = tester.widget<SizedBox>(find.byKey(SettingsOverlayShell.panelKey));
      expect(panel.width, 600.0);
      expect(panel.height, 480.0);

      // Assert — tab bar 为 normal 模式（fontSize 14.0）
      final navItems = tester.widgetList<SettingsNavItem>(find.byType(SettingsNavItem));
      for (final item in navItems) {
        expect(item.fontSize, Tokens.tabBarFontNormal);
      }
    });

    // SC-3: 小窗口（<800px）面板400×320
    testWidgets('SC-3: small window <800px panel is 400×320', (tester) async {
      // Arrange — 500×400 窗口（<800px → compact 模式, 500*0.8=400 → clamp 下限命中）
      final (controller, _) = await pumpShell(tester, size: const Size(500, 400));
      controller.open();
      await tester.pump();

      // Assert — 面板精确 400×320（width=500*0.8=400, height=400*0.8=320）
      final panel = tester.widget<SizedBox>(find.byKey(SettingsOverlayShell.panelKey));
      expect(panel.width, 400.0);
      expect(panel.height, 320.0);

      // Assert — tab bar 为 compact 模式（fontSize 12.0）
      final navItems = tester.widgetList<SettingsNavItem>(find.byType(SettingsNavItem));
      for (final item in navItems) {
        expect(item.fontSize, Tokens.tabBarFontCompact);
      }
    });

    // SC-4: 打开/关闭动画 Scale + Fade 流畅（200ms 无异常）
    testWidgets('SC-4: open/close animation completes in 200ms without error', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester, size: const Size(800, 600));

      // Act — 打开面板
      controller.open();
      await tester.pump();

      // Assert — AnimatedOpacity 和 AnimatedScale 存在，duration=200ms
      final scaleWidget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleWidget.duration, const Duration(milliseconds: 200));
      expect(scaleWidget.scale, 1.0);

      // 推进 12 帧（200ms @60fps）— 无异常
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16, microseconds: 667));
      }

      // Act — 关闭面板
      controller.close();
      await tester.pump();

      // 推进关闭动画 — 无异常
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16, microseconds: 667));
      }

      // Assert — 关闭后 isOpen 为 false
      expect(controller.state.isOpen.value, isFalse);

      // 等待退出动画完成
      await tester.pump(const Duration(milliseconds: 250));
    });

    // SC-5: 关键路径 — open/close/tab switch/drag/keyboard
    testWidgets('SC-5: all key paths work (open/close/tab/drag/keyboard)', (tester) async {
      final (controller, _) = await pumpShell(tester, size: const Size(1200, 800));

      // Path 1: Open
      controller.open();
      await tester.pump();
      expect(controller.state.isOpen.value, isTrue);
      expect(find.byKey(SettingsOverlayShell.shellKey), findsOneWidget);

      // Path 2: Switch tab
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(2)); // 音频
      await tester.pump();
      expect(controller.state.selectedTab.value, 2);

      // Path 3: Drag title bar
      final titleBar = find.byKey(SettingsOverlayShell.titleBarKey);
      final gesture = await tester.startGesture(tester.getCenter(titleBar));
      await gesture.moveBy(const Offset(50, 30));
      await gesture.up();
      await tester.pump();
      expect(controller.state.dragOffset.value.dx, 50.0);

      // Path 4: Keyboard — arrow right switches tab
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.state.selectedTab.value, 3);

      // Path 5: Close via ESC
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.state.isOpen.value, isFalse);

      // 等待退出动画
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(SettingsOverlayShell.shellKey), findsNothing);
    });
  });
}
