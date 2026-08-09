import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/models/aspect_ratio_mode.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/video_tab.dart';

import '../../helpers/fake_engine.dart';

/// 带 AppLocalizations 的 MaterialApp 包装器 — 与 audio_performance_tab_test 风格一致。
MaterialApp _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// 在更高视口泵入 VideoTab。
///
/// VideoTab 使用 AnimatedSectionList（Column），生产环境位于可滚动设置面板内；
/// 默认 800x600 测试视口会因 4 个毛玻璃区段溢出 12px。设置 900px 高度避免布局
/// 溢出噪声干扰断言（不修改生产代码）。
Future<void> _pumpVideoTab(WidgetTester tester, VideoTab tab) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrapWithL10n(tab));
}

void main() {
  group('VideoTab', () {
    // ── null 路径: videoProcessing 未提供时显示空状态 ──

    testWidgets('shows unavailable message and no settings areas when null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapWithL10n(const VideoTab()));

      // 英文 locale (默认): 空状态文本可见
      expect(find.text('Video processing unavailable'), findsOneWidget);
      // 空状态不应渲染任何可交互的视频设置控件。
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    // ── 服务提供路径: 渲染具体设置区段 ──
    //
    // 复用 FakeEngine + 真实 VideoProcessingService（非 mock）— service 是有行为的
    // 依赖，且其状态写回可被直接断言。SharedPreferences mock 避免 50ms 防抖持久化
    // 触碰真实 plugin 通道（与 PerformanceTab 测试同款 setUp）。

    late FakeEngine engine;
    late VideoProcessingService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = FakeEngine();
      service = VideoProcessingService(engine);
    });

    tearDown(() {
      service.dispose();
      engine.dispose();
    });

    testWidgets(
      'color correction section has 4 sliders labeled for each axis',
      (tester) async {
        await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

        // 4 个 Slider — 色彩校正 4 维度（亮度/对比度/饱和度/色调）
        expect(find.byType(Slider), findsNWidgets(4));
        // 滑块标签文本可见（Contrast/Saturation/Hue 各 1 处；
        // Brightness 同时出现在 section header 与首条滑块标签，故不在此断言）
        expect(find.text('Contrast'), findsOneWidget);
        expect(find.text('Saturation'), findsOneWidget);
        expect(find.text('Hue'), findsOneWidget);
      },
    );

    testWidgets('rotation picker shows every supported rotation angle', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      expect(find.text('0°'), findsOneWidget);
      expect(find.text('90°'), findsOneWidget);
      expect(find.text('180°'), findsOneWidget);
      expect(find.text('270°'), findsOneWidget);
    });

    testWidgets('aspect ratio dropdown shows current mode label', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      // 默认 keepOriginal → 显示 "Original" (l10n.aspectRatioOriginal)
      expect(find.byType(DropdownButton<AspectRatioMode>), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
    });

    testWidgets('selecting an aspect ratio writes the mode to service state', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      await tester.tap(find.byType(DropdownButton<AspectRatioMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('16:9').last);
      // Allow the service's persistence debounce to complete.
      await tester.pump(const Duration(milliseconds: 60));

      expect(service.state.value.aspectRatioMode, AspectRatioMode.ratio16_9);
    });

    testWidgets('deinterlace switch reflects service default state', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      // 默认 deinterlaceEnabled=false — 断言 outcome（开关值）而非 mock 调用
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('reset button text is visible and triggers onReset', (
      tester,
    ) async {
      var resetCalled = 0;
      await _pumpVideoTab(
        tester,
        VideoTab(videoProcessing: service, onReset: () => resetCalled++),
      );

      // l10n.resetToDefaults = "Restore Defaults" — 文本可见证明按钮渲染
      expect(find.text('Restore Defaults'), findsOneWidget);

      await tester.tap(find.text('Restore Defaults'));
      await tester.pump();

      // 交互 outcome: 回调被调用一次
      expect(resetCalled, 1);
    });

    // ── 交互行为: 控件改动写回 service 状态 ──

    testWidgets('tapping 90° rotation chip updates service rotation state', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      await tester.tap(find.text('90°'));
      // pump 60ms: 状态同步写回 + 清除 service 50ms 持久化防抖 Timer
      await tester.pump(const Duration(milliseconds: 60));

      // outcome: service 状态写回（非 verify mock.called）
      expect(service.state.value.rotation, 90);
    });

    testWidgets('toggling deinterlace switch updates service state', (
      tester,
    ) async {
      await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

      await tester.tap(find.byType(Switch));
      // pump 60ms: 状态同步写回 + 清除 service 50ms 持久化防抖 Timer
      await tester.pump(const Duration(milliseconds: 60));

      expect(service.state.value.deinterlaceEnabled, isTrue);
    });

    testWidgets(
      'invoking brightness slider callbacks updates service state after debounce',
      (tester) async {
        await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

        // 直接调 Slider.onChanged — 与 volume_slider_throttle_test 同款回调级测试,
        // 避免 IndexedStack/Overlay 双层结构下 hit-test 不稳定。
        // _VideoSlider 内有 50ms 防抖 Timer, 需 pump 过 50ms 才写回 service。
        final slider = tester.widget<Slider>(find.byType(Slider).first);
        slider.onChanged!(0.5);
        slider.onChangeEnd!(0.5);
        await tester.pump(const Duration(milliseconds: 60));

        expect(service.state.value.brightness, 0.5);
        // 清除 service 50ms 持久化防抖 Timer, 避免 test invariant 'Timer pending' 失败
        await tester.pump(const Duration(milliseconds: 60));
      },
    );

    testWidgets(
      'dragging brightness slider writes a changed value to service state',
      (tester) async {
        await _pumpVideoTab(tester, VideoTab(videoProcessing: service));

        await tester.drag(find.byType(Slider).first, const Offset(50, 0));
        // The slider debounces the update for 50ms before it invokes the service.
        await tester.pump(const Duration(milliseconds: 60));

        expect(service.state.value.brightness, greaterThan(0));
        // Allow the service's own persistence debounce to complete.
        await tester.pump(const Duration(milliseconds: 60));
      },
    );
  });
}
