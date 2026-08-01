// Settings tab content widget 测试 — 覆盖 Phase 25 Plan 02 骨架 tab 渲染。
//
// 复用 FakePlaybackController（implements SettingsPanelPlayback）替身，
// 不依赖 MediaEngine / mdk.dll，规避 headless FFI 加载失败风险。
// 测试骨架 tab 的渲染、控件类型、交互状态持久化。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/_settings_nav_item.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_overlay_shell.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_controller.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/equalizer_tab.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/general_tab.dart';
import 'package:simple_player_flutter/ui/shared/animated_section_list.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';

import 'settings_panel_controller_test.dart' show FakePlaybackController;

void main() {
  /// 构建最小化覆盖层测试壳 — 复用 settings_overlay_shell_test.dart 的 pumpShell 模式。
  Future<(SettingsPanelController, FakePlaybackController)> pumpShell(
    WidgetTester tester, {
    Size size = const Size(800, 600),
    bool initiallyPlaying = true,
  }) async {
    final fake = FakePlaybackController(
      initialState: initiallyPlaying ? MediaState.playing : MediaState.idle,
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
    return (controller, fake);
  }

  group('Settings Tab Content', () {
    // ── Tab rendering ──

    testWidgets('GeneralTab (index 0) renders 语言 section and 界面语言 SettingRow', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — General tab is selected by default, 语言 section visible
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('界面语言'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
    });

    testWidgets('switching to EqualizerTab (index 1) renders 均衡器 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 切换到均衡器 tab（index 0）
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(0));
      await tester.pump();

      // Assert — Phase 33 EqualizerTab：均衡器预设 section + 预设标签可见
      //（33-01 重写：5 预设选择器替换旧 60Hz/1kHz/14kHz 频段骨架）
      expect(find.text('均衡器预设'), findsOneWidget);
      expect(find.text('摇滚'), findsOneWidget);
    });

    testWidgets('switching to AudioTab (index 2) renders 音频输出 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(1));
      await tester.pump();

      // Assert
      expect(find.text('音频输出'), findsOneWidget);
      expect(find.text('输出设备'), findsOneWidget);
      expect(find.text('自动选择音轨'), findsOneWidget);
      expect(find.text('默认音量'), findsOneWidget);
    });

    testWidgets('switching to VideoTab (index 3) renders 解码器 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(2));
      await tester.pump();

      // Assert
      expect(find.text('解码器'), findsOneWidget);
      expect(find.text('解码方式'), findsOneWidget);
      expect(find.text('去隔行'), findsOneWidget);
      expect(find.text('亮度'), findsOneWidget);
    });

    testWidgets('switching to ShortcutsTab (index 4) renders 快捷键 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(4));
      await tester.pump();

      // Assert
      expect(find.text('快捷键'), findsWidgets); // tab bar + section header
      expect(find.text('播放 / 暂停'), findsOneWidget);
      expect(find.text('快进 / 快退'), findsOneWidget);
      expect(find.text('音量调节'), findsOneWidget);
    });

    testWidgets('switching to AboutTab (index 5) renders 关于 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(5));
      await tester.pump();

      // Assert
      expect(find.text('关于'), findsWidgets); // tab bar + section header
      expect(find.text('Simple Player'), findsOneWidget);
      expect(find.text('v1.8.0'), findsOneWidget);
      expect(find.text('项目主页'), findsOneWidget);
    });

    testWidgets('switching to PerformanceTab (index 6) renders 性能监控 section', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(6));
      await tester.pump();

      // Assert
      expect(find.text('性能监控'), findsOneWidget);
      expect(find.text('帧率叠加层'), findsOneWidget);
      expect(find.text('日志级别'), findsOneWidget);
    });

    // ── Control types ──

    testWidgets('GeneralTab contains Switch control for 深色模式', (tester) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — Switch exists in General tab
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('GeneralTab contains SpinControl for locale selection', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — GeneralTab 用 SettingSpinRow → SpinControl 切换语言（非 DropdownButton）
      expect(find.byType(SpinControl), findsWidgets);
    });

    testWidgets('EqualizerTab contains Slider controls for balance and sync', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 切换到均衡器
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(0));
      await tester.pump();

      // Assert — Phase 33：balance + 音频延迟 两个 Slider。descendant 限定到
      // EqualizerTab，避免 AudioTab 音量 Slider 串扰（find 默认 skipOffstage，
      // 非选中 tab 的 widget 不计入，但 descendant 限定更明确意图）。
      expect(
        find.descendant(
          of: find.byType(EqualizerTab),
          matching: find.byType(Slider),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('AudioTab contains Slider for volume control', (tester) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(1));
      await tester.pump();

      // Assert — volume Slider exists
      expect(find.byType(Slider), findsOneWidget);
    });

    // ── SettingRow presence ──

    testWidgets('all tabs use SettingRow for layout', (tester) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — General tab has SettingRow items
      expect(find.byType(SettingRow), findsWidgets);
    });

    // ── Pending state interaction ──

    testWidgets(
      'Switch in GeneralTab has correct initial value from pending state',
      (tester) async {
        // Arrange
        final (controller, _) = await pumpShell(tester);
        controller.open();
        await tester.pump();

        // Assert — Switch renders with default value (true for darkMode)
        // The GeneralTab's dark mode Switch uses
        // pending.current('darkMode') as bool? ?? true
        final switchWidget = tester.widget<Switch>(find.byType(Switch).first);
        expect(switchWidget.value, isTrue);
      },
    );

    testWidgets('SpinControl onChanged callback switches locale to English', (
      tester,
    ) async {
      // Arrange — GeneralTab 默认显示（defaultTabIndex=3），locale 默认 'zh' (index 0)
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 直接调用 GeneralTab 内 SpinControl 的 onChanged(1) 验证 locale 切换链路。
      // tap hit test 在 IndexedStack 7-tab + MaterialApp Overlay 双层结构下不稳定
      // （Overlay 的 AbsorbPointer 吸收点击，tap 落不到 SpinControl 的 InkWell），
      // 改用回调级测试验证 GeneralTab→pending 链路（原 DropdownButton 测试的核心意图），
      // 不 suppress 断言、不改 sizing/breakpoint 语义（D-04 边界）。
      final spin = tester.widget<SpinControl>(
        find
            .descendant(
              of: find.byType(GeneralTab),
              matching: find.byType(SpinControl),
            )
            .first,
      );
      spin.onChanged(1);
      await tester.pump();

      // Assert — pending state 更新为 'en'
      expect(controller.pending.current('locale'), 'en');
    });

    // ── AnimatedSectionList usage ──

    testWidgets('tab content uses AnimatedSectionList for staggered fade-in', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — AnimatedSectionList exists in the tree
      expect(find.byType(AnimatedSectionList), findsWidgets);
    });

    // ── IndexedStack keeps all tabs alive ──

    testWidgets('IndexedStack keeps all 7 tab widgets alive after switching', (
      tester,
    ) async {
      // Arrange
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Act — 切换到 tab 3 (视频)
      final navItems = find.byType(SettingsNavItem);
      await tester.tap(navItems.at(2));
      await tester.pump();

      // Assert — 视频 tab content visible
      expect(find.text('解码方式'), findsOneWidget);
      // Assert — the main IndexedStack (shell content) has 7 children
      // There are multiple IndexedStack in the tree (AnimatedSectionList uses Column),
      // so find the one with exactly 7 children (the shell's tab stack)
      final allStacks = tester.widgetList<IndexedStack>(
        find.byType(IndexedStack),
      );
      final shellStack = allStacks.firstWhere((s) => s.children.length == 7);
      expect(shellStack.index, 2);
    });

    // ── No regressions with existing tests ──

    testWidgets('shell still renders 7 SettingsNavItem tabs after wiring', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — 7 nav items still present
      expect(find.byType(SettingsNavItem), findsNWidgets(7));
    });

    testWidgets('button bar still renders after wiring tab content', (
      tester,
    ) async {
      // Arrange & Act
      final (controller, _) = await pumpShell(tester);
      controller.open();
      await tester.pump();

      // Assert — button bar still present
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('应用'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
    });
  });
}
