// panel_color_test.dart — Phase 30-04 结构色路由合约测试，Phase 31 Plan 01 re-baseline。
//
// Phase 31 D-11 分层决策后，四段色路由分裂为 chrome/content 两条路径：
// - chrome 三段（标题栏 / tab 条 / 按钮栏）：共享 ControlBarDecoration.playing
//   装饰 —— BoxDecoration(color: controlBarBg, 1px controlBarBorderWhite 边框,
//   4-shadow 末位 glowOuterRing)，corner-only 圆角分段（Pitfall 1 缓解）；
// - 内容区：保持 ColoredBox(color: Tokens.panelSectionBg) → bgGlass 薄玻璃
//   （D-11 content 单路由，VISUAL-04）。
//
// 另含单 BackdropFilter 结构闸门（SC#4 / T-31-02）：面板子树 BackdropFilter
// 计数 == 1，防止未来叠加第二层 blur 造成 GPU readback 堆叠。
//
// 与 settings_overlay_shell_test.dart 的 30-03 group 互补：
// - 30-03 group：单尺寸（800×600）确认分段结构存在
// - 本文件：跨 3 个尺寸（compact / 默认 / 全屏）确认 chrome/content 路由稳定 + 合约维度

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

  /// 断言单个 Container 的 decoration 字段等价 ControlBarDecoration.playing spec
  /// （Phase 31 D-11 chrome 路由合约）：controlBarBg 底色 + 1px
  /// controlBarBorderWhite 边框 + 4-shadow 列表末位 glowOuterRing。
  void expectChromeDecoration(Container container, String sectionName) {
    final decoration = container.decoration;
    // pattern matching 取 BoxDecoration 具体类型，避免 as 强转
    if (decoration is! BoxDecoration) {
      fail(
        '$sectionName: expected BoxDecoration, got ${decoration.runtimeType}',
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
    final shadows = decoration.boxShadow;
    expect(
      shadows?.length,
      4,
      reason: '$sectionName shadow count (tween-compat 硬约束)',
    );
    expect(
      shadows?[3].color,
      Tokens.glowOuterRing,
      reason: '$sectionName shadow[3] glowOuterRing',
    );
  }

  /// 断言 chrome 三段装饰等价 ControlBarDecoration.playing、内容区保持
  /// panelSectionBg 薄玻璃（Phase 31 D-11 chrome/content 分层合约）。
  /// 用 `find.descendant(...).first` 深度优先匹配最外层，避开内部 Container/ColoredBox 干扰。
  void expectChromeContentSplit(WidgetTester tester) {
    // 标题栏 Container（titleBarKey 子树首个 Container）
    final titleBarContainer = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(SettingsOverlayShell.titleBarKey),
        matching: find.byType(Container),
      ),
    ).first;
    expectChromeDecoration(titleBarContainer, 'title bar');

    // 按钮栏 Container（buttonBarKey 唯一定位）
    final buttonBarContainer = tester.widget<Container>(
      find.byKey(SettingsOverlayShell.buttonBarKey),
    );
    expectChromeDecoration(buttonBarContainer, 'button bar');

    // tab 条 Container（SettingsTabStrip 子树首个 Container）
    final tabStripContainer = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(SettingsTabStrip),
        matching: find.byType(Container),
      ),
    ).first;
    expectChromeDecoration(tabStripContainer, 'tab strip');

    // 内容区 ColoredBox（SettingsTabContent 子树首个 ColoredBox）—
    // D-11 content 单路由：保持 panelSectionBg（→ bgGlass 薄玻璃，VISUAL-04）
    final contentColoredBox = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(SettingsTabContent),
        matching: find.byType(ColoredBox),
      ),
    ).first;
    expect(contentColoredBox.color, Tokens.panelSectionBg);
  }

  group('panel chrome/content color route (31-01 D-11 re-baseline)', () {
    testWidgets(
      'chrome sections use ControlBarDecoration.playing, content stays '
      'panelSectionBg at compact 500×400',
      (tester) async {
        // Arrange — compact 模式（D-04 面板 400×225，色路由应与几何无关）
        final controller = await pumpShell(tester, size: const Size(500, 400));
        controller.open();
        await tester.pump();

        // Assert — chrome 三段共享装饰 + content 薄玻璃
        expectChromeContentSplit(tester);
      },
    );

    testWidgets(
      'chrome sections use ControlBarDecoration.playing, content stays '
      'panelSectionBg at default 800×600',
      (tester) async {
        // Arrange — D-04 下限命中（面板 400×225），默认 defaultTabIndex=3
        final controller = await pumpShell(tester, size: const Size(800, 600));
        controller.open();
        await tester.pump();

        // Assert — 色路由稳定，不受 default tab 选择影响
        expectChromeContentSplit(tester);
      },
    );

    testWidgets(
      'chrome sections use ControlBarDecoration.playing, content stays '
      'panelSectionBg at fullscreen 1920×1080',
      (tester) async {
        // Arrange — D-04 上限命中（面板 960×540），normal 模式
        final controller = await pumpShell(
          tester,
          size: const Size(1920, 1080),
        );
        controller.open();
        await tester.pump();

        // Assert — 几何放大不改变 chrome/content 路由合约
        expectChromeContentSplit(tester);
      },
    );

    testWidgets(
      'panelSectionBg aliases bgGlass (content single-swap-route seam)',
      (tester) async {
        // Assert — D-11 content 单路由契约：panelSectionBg 就是 bgGlass，
        // 未来 content 色变更只动 alias 单点，四个消费者测试零变更
        expect(Tokens.panelSectionBg, Tokens.bgGlass);
      },
    );

    testWidgets(
      'panel has exactly one top-level BackdropFilter (SC#4 / T-31-02 gate)',
      (tester) async {
        // Arrange — 默认尺寸打开面板
        final controller = await pumpShell(tester, size: const Size(800, 600));
        controller.open();
        await tester.pump();

        // Assert — 结构闸门：包裹面板 sizing box 的 BackdropFilter 有且仅有
        // 一个（shell 的 GlassContainer 持有）。取 panelKey 的祖先链而非整个
        // 壳子树：tab 内容卡片（General/Video/...）自身的 GlassContainer blur
        // 是 Phase 25 预存在的 per-card 层，不属本 phase 的 chrome/content
        // 路由面；chrome 三段（BoxDecoration）与 content（ColoredBox）均为
        // 该唯一 panel 级 blur 的 paint-only 子节点，任何人在面板级别叠加
        // 第二层 blur（GPU readback 堆叠）会立即红灯。
        expect(
          find.ancestor(
            of: find.byKey(SettingsOverlayShell.panelKey),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
