import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_dialog.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/video_settings_content.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';

void main() {
  setUpAll(() {
    // v0.0.6 bundle 注入用例经 AppSettingsService → KernelLogger (项目惯例).
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  // 固定中文 locale — 文案断言（标题/导航/分区名）不随宿主环境漂移。
  Widget buildSubject() => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => SettingsDialog.show(context),
            child: const Text('打开设置'),
          ),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle(); // 弹出动画 + 内容淡入完成
  }

  testWidgets('shows a two-pane shell with nav entries', (tester) async {
    await openDialog(tester);

    // 壳：标题 + 左侧导航（关于 = 唯一真实项；通用/视频/音频为灰显占位）。
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
  });

  testWidgets('about pane lists real open-source components and licenses', (
    tester,
  ) async {
    await openDialog(tester);

    // 开源技术区 — 顶部组件（真实在用的引擎封装与框架）必在首屏。
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    // LGPL 组件（mpv/libmpv 与 FFmpeg）共用同一许可证标识。
    expect(find.text('LGPL-2.1-or-later'), findsNWidgets(2));
  });

  testWidgets('about pane shows special thanks above tech stack with donors', (
    tester,
  ) async {
    await openDialog(tester);

    // v0.0.4：鸣谢区上移至技术栈之前，进门即见（无需滚动）。
    expect(find.text('特别鸣谢'), findsOneWidget);
    // 已录入的爱发电支持者以「头像 + 姓名」条目呈现。
    expect(find.text('爱发电用户_24f3f'), findsOneWidget);
    // 空态占位文案不再出现（名单非空）。
    expect(find.text('名单正在准备中，敬请期待'), findsNothing);
    // 技术栈仍在鸣谢区之后（同一 ListView 内先后顺序）。
    expect(find.text('技术栈'), findsOneWidget);
    final thanksDy = tester.getTopLeft(find.text('特别鸣谢')).dy;
    final techDy = tester.getTopLeft(find.text('技术栈')).dy;
    expect(thanksDy, lessThan(techDy));
  });

  testWidgets('about pane brand row renders social link buttons', (
    tester,
  ) async {
    await openDialog(tester);

    // v0.0.4：品牌行右侧的社交/赞助 logo 按钮（X/爱发电/Patreon/GitHub）。
    // Material 近似图标，tooltip 提示品牌名；点击行为（openUrl）走系统
    // 浏览器，widget 测试不触真进程，只断言按钮存在与可点语义。
    expect(find.byTooltip('X (Twitter)'), findsOneWidget);
    expect(find.byTooltip('爱发电'), findsOneWidget);
    expect(find.byTooltip('Patreon'), findsOneWidget);
    expect(find.byTooltip('GitHub'), findsOneWidget);
  });

  testWidgets('closes via the built-in close button', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle(); // 关闭动画走完

    // 回到承载页 — 入口按钮仍在，弹层消失以右区标题消失为准。
    expect(find.text('打开设置'), findsOneWidget);
    expect(find.text('关于'), findsNothing);
  });

  testWidgets(
    'selecting the general tab switches content and marks it selected',
    (tester) async {
      await openDialog(tester);

      // 初始选中态为「关于」（向后兼容现状：直接打开设置看到 About）。
      expect(find.text('media_kit'), findsOneWidget);
      expect(find.byType(GeneralSettingsContent), findsNothing);

      await tester.tap(find.text('通用'));
      await tester.pumpAndSettle();

      // 内容切换为通用分区，About 的组件列表消失。
      expect(find.byType(GeneralSettingsContent), findsOneWidget);
      expect(find.text('media_kit'), findsNothing);

      // 选中高亮是持续态（区别于 hover 的瞬态）：bgHover 圆角底；
      // 未选中的「关于」条目恢复无底色。
      final general = tester.widget<Container>(
        find.byKey(const ValueKey('settings-nav-general')),
      );
      expect((general.decoration! as BoxDecoration).color, Tokens.bgHover);
      final about = tester.widget<Container>(
        find.byKey(const ValueKey('settings-nav-about')),
      );
      expect((about.decoration! as BoxDecoration).color, isNull);
    },
  );

  testWidgets('returning to the about tab restores the about content', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsOneWidget);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // About 内容回归 —— 通用/关于互切均可达。
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.byType(GeneralSettingsContent), findsNothing);
  });

  testWidgets('disabled video and audio entries never switch content', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsOneWidget);

    // 灰显占位项不可交互（Avoid captive UI）：点击无伪反馈、内容不切换。
    // IgnorePointer 拦截命中是灰显行为的直接证据 —— warnIfMissed: false 显式
    // 声明「点击落空即预期」。
    await tester.tap(find.text('视频'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('音频'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsOneWidget);
    expect(find.text('media_kit'), findsNothing);

    // 灰显语义结构锁：38% 不透明度 + IgnorePointer 保持原状。
    // .first 取最内层（导航条目自身的 Opacity/IgnorePointer）。
    final videoOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('视频'), matching: find.byType(Opacity)).first,
    );
    expect(videoOpacity.opacity, 0.38);
    final audioOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('音频'), matching: find.byType(Opacity)).first,
    );
    expect(audioOpacity.opacity, 0.38);
    final videoPointer = tester.widget<IgnorePointer>(
      find
          .ancestor(of: find.text('视频'), matching: find.byType(IgnorePointer))
          .first,
    );
    expect(videoPointer.ignoring, isTrue);
  });

  group('bundle 注入 (v0.0.6)', () {
    late FakeEngine engine;
    late VideoProcessingService videoProcessing;
    late AppSettingsService settings;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      engine = FakeEngine();
      videoProcessing = VideoProcessingService(engine);
      settings = AppSettingsService(
        engine: engine,
        videoProcessing: videoProcessing,
        store: AppSettingsStore(),
      );
    });

    tearDown(() {
      settings.dispose();
      videoProcessing.dispose();
      engine.dispose();
    });

    Widget buildInjectedSubject() => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => SettingsDialog.show(
                context,
                services: SettingsServicesBundle(
                  videoProcessing: videoProcessing,
                  settings: settings,
                ),
              ),
              child: const Text('打开设置'),
            ),
          ),
        ),
      ),
    );

    testWidgets('video/audio 分区保持关闭 (v0.0.6.1 用户裁决, bundle 注入也不例外)', (
      tester,
    ) async {
      await tester.pumpWidget(buildInjectedSubject());
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();

      // 入口灰显: 点击不切换内容.
      await tester.tap(find.text('视频'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(VideoSettingsContent), findsNothing);
      await tester.tap(find.text('音频'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final videoOpacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('视频'), matching: find.byType(Opacity))
            .first,
      );
      expect(videoOpacity.opacity, 0.38);
    });

    testWidgets('通用分区出现断点续播开关并可翻转', (tester) async {
      await tester.pumpWidget(buildInjectedSubject());
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('通用'));
      await tester.pumpAndSettle();
      expect(find.text('记住播放位置'), findsOneWidget);
      expect(settings.resumeEnabled.value, isTrue);

      // 点行翻转 → 服务状态变化.
      await tester.tap(find.text('记住播放位置'));
      await tester.pumpAndSettle();
      expect(settings.resumeEnabled.value, isFalse);
    });

    testWidgets('VideoSettingsContent 组件级 — 滑条变化写入 VideoProcessingService', (
      tester,
    ) async {
      // 分区入口已按用户裁决关闭, 组件本身的服务写入契约独立验证.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 400,
              child: VideoSettingsContent(videoProcessing: videoProcessing),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final brightnessSlider = find.byType(Slider).first;
      await tester.drag(brightnessSlider, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(videoProcessing.state.value.brightness, greaterThan(0.5));
    });
  });
}
