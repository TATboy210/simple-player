// panel_color_test.dart — Phase 30-04 (Wave 3) 结构色路由合约测试 (D-02 / LAYOUT-05)。
//
// 验证四段（标题栏 / tab 条 / 内容区 / 按钮栏）背景在任意几何下都解析到
// `Tokens.panelSectionBg`（= bgGlass 别名），而非 ARGB 字面值——确保 Phase 31
// 改 alias 单点时测试零变更，且色路由与 D-04 几何完全解耦。
//
// 与 settings_overlay_shell_test.dart 的 30-03 group 互补：
// - 30-03 group：单尺寸（800×600）确认四段路由存在
// - 本文件：跨 3 个尺寸（compact / 默认 / 全屏）确认路由稳定性 + 合约维度

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tab_strip.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../ui/dialogs/settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳 — MediaQuery 覆盖窗口尺寸（复用 scaling/integration 模式）。
  Future<SettingsPanelController> pumpShell(
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
    return controller;
  }

  /// 断言四段背景都解析到 `Tokens.panelSectionBg`（D-02 color-route 合约）。
  /// 用 `find.descendant(...).first` 深度优先匹配最外层，避开内部 Container/ColoredBox 干扰。
  void expectFourSectionsRouteToPanelSectionBg(WidgetTester tester) {
    // 标题栏 Container（titleBarKey 子树首个 Container）
    final titleBarContainer = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(SettingsOverlayShell.titleBarKey),
        matching: find.byType(Container),
      ),
    ).first;
    expect(titleBarContainer.color, Tokens.panelSectionBg);

    // 按钮栏 Container（buttonBarKey 唯一定位）
    final buttonBarContainer = tester.widget<Container>(
      find.byKey(SettingsOverlayShell.buttonBarKey),
    );
    expect(buttonBarContainer.color, Tokens.panelSectionBg);

    // tab 条 Container（SettingsTabStrip 子树首个 Container）
    final tabStripContainer = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(SettingsTabStrip),
        matching: find.byType(Container),
      ),
    ).first;
    expect(tabStripContainer.color, Tokens.panelSectionBg);

    // 内容区 ColoredBox（SettingsTabContent 子树首个 ColoredBox；
    // 原 bgPanel distinct route 已统一到 panelSectionBg，D-02）
    final contentColoredBox = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(SettingsTabContent),
        matching: find.byType(ColoredBox),
      ),
    ).first;
    expect(contentColoredBox.color, Tokens.panelSectionBg);
  }

  group('panel structural color route (30-04 D-02)', () {
    testWidgets(
      'four sections route to Tokens.panelSectionBg at compact 500×400',
      (tester) async {
        // Arrange — compact 模式（D-04 面板 400×225，色路由应与几何无关）
        final controller = await pumpShell(tester, size: const Size(500, 400));
        controller.open();
        await tester.pump();

        // Assert — 四段全部解析到 panelSectionBg
        expectFourSectionsRouteToPanelSectionBg(tester);
      },
    );

    testWidgets(
      'four sections route to Tokens.panelSectionBg at default 800×600',
      (tester) async {
        // Arrange — D-04 下限命中（面板 400×225），默认 defaultTabIndex=3
        final controller = await pumpShell(tester, size: const Size(800, 600));
        controller.open();
        await tester.pump();

        // Assert — 色路由稳定，不受 default tab 选择影响
        expectFourSectionsRouteToPanelSectionBg(tester);
      },
    );

    testWidgets(
      'four sections route to Tokens.panelSectionBg at fullscreen 1920×1080',
      (tester) async {
        // Arrange — D-04 上限命中（面板 960×540），normal 模式
        final controller = await pumpShell(
          tester,
          size: const Size(1920, 1080),
        );
        controller.open();
        await tester.pump();

        // Assert — 几何放大不改变色路由合约
        expectFourSectionsRouteToPanelSectionBg(tester);
      },
    );

    testWidgets(
      'panelSectionBg aliases bgGlass (Phase 31 single-point mutation seam)',
      (tester) async {
        // Assert — D-02 alias 契约：panelSectionBg 就是 bgGlass，Phase 31 改 alias
        // 时此断言会同步更新，无需改动四个消费者测试
        expect(Tokens.panelSectionBg, Tokens.bgGlass);
      },
    );
  });
}
