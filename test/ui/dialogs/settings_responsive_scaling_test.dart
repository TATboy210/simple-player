// SettingsOverlayShell 响应式缩放测试 — 覆盖 SCALE-01/02/03。
//
// 验证面板连续缩放（clamp 400-600）、5:4 高宽比、800px 断点 tab bar
// normal/compact 切换、RepaintBoundary 隔离。

import 'package:flutter/material.dart';
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

  group('Responsive Scaling', () {
    testWidgets(
      'panelWidth scales continuously and clamps to 600 at large window',
      (tester) async {
        // Arrange — 1920×1080 窗口 → width = 1920 * 0.8 = 1536, clamp to 600
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(1920, 1080),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板宽度 = 600（被 maxWidth 钳制）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 600.0);
      },
    );

    testWidgets(
      'panelWidth clamps to 400 at small window',
      (tester) async {
        // Arrange — 500×400 窗口 → width = 500 * 0.8 = 400, 在 [400,600] 内
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板宽度 = 400
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
      },
    );

    testWidgets(
      'panelWidth scales at mid-range window (800px)',
      (tester) async {
        // Arrange — 800×600 窗口 → width = 800 * 0.8 = 640, clamp to 600
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板宽度 = 600（640 超过 max，被钳制）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 600.0);
      },
    );

    testWidgets(
      'panelHeight follows width * 0.8 ratio (fullscreen 600×480)',
      (tester) async {
        // Arrange — 1920×1080 窗口 → width = 1920 * 0.8 = 1536, clamp to 600, height = 600 * 0.8 = 480
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(1920, 1080),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板尺寸 = 600×480（SC-2）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 600.0);
        expect(panelBox.height, 480.0);
      },
    );

    testWidgets(
      'panelHeight follows width * 0.8 ratio at min width (compact 400×320)',
      (tester) async {
        // Arrange — 500×400 窗口 → width = 400, height = 400 * 0.8 = 320
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — 面板尺寸 = 400×320（SC-3）
        final panelBox = tester.widget<SizedBox>(
          find.byKey(SettingsOverlayShell.panelKey),
        );
        expect(panelBox.width, 400.0);
        expect(panelBox.height, 320.0);
      },
    );

    testWidgets(
      'tab bar uses normal font at >= 800px window',
      (tester) async {
        // Arrange — 1000×800 窗口 → isCompact = false
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(1000, 800),
        );
        controller.open();
        await tester.pump();

        // Assert — SettingsNavItem 使用 14.0 字体（normal 模式）
        final navItems = tester.widgetList<SettingsNavItem>(
          find.byType(SettingsNavItem),
        );
        for (final item in navItems) {
          expect(item.fontSize, Tokens.tabBarFontNormal);
        }
      },
    );

    testWidgets(
      'tab bar uses compact font at < 800px window',
      (tester) async {
        // Arrange — 600×400 窗口 → isCompact = true
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(600, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — SettingsNavItem 使用 12.0 字体（compact 模式）
        final navItems = tester.widgetList<SettingsNavItem>(
          find.byType(SettingsNavItem),
        );
        for (final item in navItems) {
          expect(item.fontSize, Tokens.tabBarFontCompact);
        }
      },
    );

    testWidgets(
      'panel wrapped in RepaintBoundary',
      (tester) async {
        // Arrange — 800×600 窗口
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Assert — FocusTraversalGroup 的父级是 RepaintBoundary
        final repaintBoundary = find.ancestor(
          of: find.byType(FocusTraversalGroup),
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundary, findsWidgets);
      },
    );

    testWidgets(
      'BackdropFilter present during open animation',
      (tester) async {
        // Arrange — 800×600 窗口
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(800, 600),
        );
        controller.open();
        await tester.pump();

        // Assert — BackdropFilter 存在（GlassContainer 的模糊效果）
        expect(find.byType(BackdropFilter), findsWidgets);
      },
    );

    testWidgets(
      'tab bar uses compact spacing at < 800px window',
      (tester) async {
        // Arrange — 600×400 窗口 → isCompact = true
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(600, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — SettingsNavItem 使用 compact spacing
        final navItems = tester.widgetList<SettingsNavItem>(
          find.byType(SettingsNavItem),
        );
        for (final item in navItems) {
          expect(item.spacing, Tokens.tabBarSpacingCompact);
        }
      },
    );

    testWidgets(
      'all 7 tab labels visible at 400px compact panel width',
      (tester) async {
        // Arrange — 500×400 窗口 → panel=400×320, isCompact=true
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — D-03: 全部7个标签在 compact 模式下可见，无滚动、无隐藏
        const labels = ['通用', '均衡器', '音频', '视频', '快捷键', '关于', '性能'];
        for (final label in labels) {
          expect(find.text(label), findsWidgets, reason: '$label should be visible at compact width');
        }
      },
    );

    testWidgets(
      'tab bar height is 56px in compact mode and 64px in normal mode',
      (tester) async {
        // Arrange — compact: 500×400 窗口
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — tab bar Container 高度 = 56（compact）
        // 找到包含 SettingsNavItem 的 Container
        final compactTabBar = tester.widget<Container>(
          find.ancestor(
            of: find.byType(SettingsNavItem).first,
            matching: find.byType(Container),
          ).first,
        );
        final compactConstraints = compactTabBar.constraints;
        expect(compactConstraints?.maxHeight, 56.0);

        // Act — 切换到 normal 模式
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

        // Assert — tab bar Container 高度 = 64（normal）
        final normalTabBar = tester.widget<Container>(
          find.ancestor(
            of: find.byType(SettingsNavItem).first,
            matching: find.byType(Container),
          ).first,
        );
        final normalConstraints = normalTabBar.constraints;
        expect(normalConstraints?.maxHeight, 64.0);
      },
    );

    testWidgets(
      'animation duration constant is 200ms',
      (tester) async {
        // Assert — D-06: 动画时长不变（200ms）
        expect(
          SettingsOverlayShell.animationDuration,
          const Duration(milliseconds: 200),
        );
      },
    );

    testWidgets(
      'tab bar uses direct conditional sizing, not AnimatedContainer',
      (tester) async {
        // Arrange — 500×400 窗口（compact 模式）
        final (controller, _) = await pumpShell(
          tester,
          size: const Size(500, 400),
        );
        controller.open();
        await tester.pump();

        // Assert — D-09: tab bar 使用条件表达式切换高度，无过渡动画
        // AnimatedContainer 仅存在于 SettingsNavItem 内部（用于 hover/selected 背景），
        // tab bar 本身的高度 Container 不是 AnimatedContainer
        final navItemAncestor = find.ancestor(
          of: find.byType(SettingsNavItem).first,
          matching: find.byType(Container),
        ).first;
        // Container（tab bar 包装）不应该是 AnimatedContainer
        final container = tester.widget<Container>(navItemAncestor);
        expect(container.runtimeType, Container);
      },
    );
  });
}
