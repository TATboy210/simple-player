import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/general_settings_content.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
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
  // 非 route 停靠面板：直接 pump SettingsPanel（生产挂载于控制层 Stack
  // 中列，显隐由宿主 notifier 经 visible 驱动），关闭按钮经 onClose 收口。
  // SizedBox 复现真实槽位几何（生产中三等分 ~273-415 × 槽高）。
  Widget buildSubject({
    VoidCallback? onClose,
    ValueListenable<bool>? scrubbing,
  }) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 330,
          child: SettingsPanel(
            visible: true,
            onClose: onClose ?? () {},
            scrubbing: scrubbing,
          ),
        ),
      ),
    ),
  );

  Future<void> openDialog(
    WidgetTester tester, {
    VoidCallback? onClose,
    ValueListenable<bool>? scrubbing,
  }) async {
    await tester.pumpWidget(
      buildSubject(onClose: onClose, scrubbing: scrubbing),
    );
    await tester.pumpAndSettle(); // 内容淡入完成
  }

  testWidgets('shows the tag layer with nav entries at L0', (tester) async {
    await openDialog(tester);

    // L0 tag 层：标题 + 竖排分区入口（关于 = 默认选中；通用/视频/音频）。
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
    // 两级覆盖导航：L0 时分区内容不可见（内容层 Offstage，默认 find 即排除）。
    expect(find.text('media_kit'), findsNothing);
    expect(find.byType(GeneralSettingsContent), findsNothing);
  });

  testWidgets('about pane lists real open-source components and licenses', (
    tester,
  ) async {
    await openDialog(tester);
    // 进入关于分区内容层（L1）。
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // 开源技术区 — 顶部组件（真实在用的引擎封装与框架）必在首屏。
    expect(find.text('media_kit', skipOffstage: false), findsOneWidget);
    expect(find.text('Flutter', skipOffstage: false), findsOneWidget);
    // LGPL 组件（mpv/libmpv 与 FFmpeg）共用同一许可证标识；窄面板下
    // ListView 按视口裁剪构建，断言视口内至少出现一个。
    expect(find.text('LGPL-2.1-or-later'), findsWidgets);
  });

  testWidgets('about pane shows special thanks above tech stack with donors', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // v0.0.4：鸣谢区上移至技术栈之前，进门即见（无需滚动）。
    expect(find.text('特别鸣谢', skipOffstage: false), findsOneWidget);
    // 已录入的爱发电支持者以「头像 + 姓名」条目呈现。
    expect(find.text('爱发电用户_24f3f', skipOffstage: false), findsOneWidget);
    // 空态占位文案不再出现（名单非空）。
    expect(find.text('名单正在准备中，敬请期待', skipOffstage: false), findsNothing);
    // 技术栈仍在鸣谢区之后（同一 ListView 内先后顺序）。
    expect(find.text('技术栈', skipOffstage: false), findsOneWidget);
    final thanksDy = tester
        .getTopLeft(find.text('特别鸣谢', skipOffstage: false))
        .dy;
    final techDy = tester.getTopLeft(find.text('技术栈', skipOffstage: false)).dy;
    expect(thanksDy, lessThan(techDy));
  });

  testWidgets('about pane brand row renders social link buttons', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // v0.0.4：品牌行右侧的社交/赞助 logo 按钮（X/爱发电/Patreon/GitHub）。
    // Material 近似图标，tooltip 提示品牌名；点击行为（openUrl）走系统
    // 浏览器，widget 测试不触真进程，只断言按钮存在与可点语义。
    expect(find.byTooltip('X (Twitter)'), findsOneWidget);
    expect(find.byTooltip('爱发电'), findsOneWidget);
    expect(find.byTooltip('Patreon'), findsOneWidget);
    expect(find.byTooltip('GitHub'), findsOneWidget);
  });

  testWidgets('closes via the built-in close button', (tester) async {
    var closed = false;
    await openDialog(tester, onClose: () => closed = true);

    // 标题行关闭按钮为 GlassButton.iconOnly — 经 tooltip 定位（播放列表
    // 同款交互）。
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    // 非 route 面板：关闭按钮经 onClose 回调收口到宿主 notifier（生产中
    // settingsVisible.value = false），面板移除由宿主 Stack 显隐控制。
    expect(closed, isTrue);
  });

  testWidgets(
    'selecting the general tab switches content and marks it selected',
    (tester) async {
      await openDialog(tester);

      // L0：tag 层可见、内容层 Offstage（两级覆盖导航）。
      expect(find.byType(GeneralSettingsContent), findsNothing);

      // 一步直达：点击 tag = 选中并进入其内容层（L1）。
      await tester.tap(find.text('通用'));
      await tester.pumpAndSettle();

      expect(find.byType(GeneralSettingsContent), findsOneWidget);
      expect(find.text('media_kit', skipOffstage: false), findsNothing);

      // 选中高亮是持续态（区别于 hover 的瞬态）：bgHover 底；
      // 未选中的「关于」chip 无底色。
      final general = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-general')),
      );
      expect((general.decoration! as BoxDecoration).color, Tokens.bgHover);
      final about = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-about')),
      );
      expect((about.decoration! as BoxDecoration).color, Colors.transparent);
    },
  );

  testWidgets('returning to the about tab restores the about content', (
    tester,
  ) async {
    await openDialog(tester);

    // 进入通用分区（L1）→ 经标题行返回按钮回 L0 → 再进关于分区。
    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsNothing);
    expect(find.text('media_kit', skipOffstage: false), findsNothing);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    // About 内容回归 —— 通用/关于互切均可达。
    expect(find.text('media_kit', skipOffstage: false), findsOneWidget);
    expect(find.byType(GeneralSettingsContent), findsNothing);
  });

  testWidgets('video 分区保持灰显，audio 已解灰 (v0.0.8.1)', (tester) async {
    await openDialog(tester);

    // video 灰显占位项不可交互（Avoid captive UI）：点击无伪反馈、内容层
    // 不进入。IgnorePointer 拦截命中是灰显行为的直接证据 ——
    // warnIfMissed: false 显式声明「点击落空即预期」。
    await tester.tap(find.text('视频'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(GeneralSettingsContent), findsNothing);
    expect(find.text('media_kit'), findsNothing);

    // 灰显语义结构锁：38% 不透明度 + IgnorePointer 保持原状。
    // .first 取最内层（chip 自身的 Opacity/IgnorePointer）。
    final videoOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('视频'), matching: find.byType(Opacity)).first,
    );
    expect(videoOpacity.opacity, 0.38);
    final videoPointer = tester.widget<IgnorePointer>(
      find
          .ancestor(of: find.text('视频'), matching: find.byType(IgnorePointer))
          .first,
    );
    expect(videoPointer.ignoring, isTrue);

    // audio 已解灰（v0.0.8.1）：不透明度恢复 1.0（无灰显 Opacity 修饰）。
    final audioOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('音频'), matching: find.byType(Opacity)).first,
    );
    expect(audioOpacity.opacity, 1.0);
  });

  testWidgets('seek 拖动挂起 — suspend 翻转停用/恢复玻璃 (v0.0.8.2)', (tester) async {
    final scrubbing = ValueNotifier<bool>(false);
    addTearDown(scrubbing.dispose);
    await openDialog(tester, scrubbing: scrubbing);

    final finder = find.descendant(
      of: find.byType(SettingsPanel),
      matching: find.byType(BackdropFilter),
    );
    expect(tester.widget<BackdropFilter>(finder).enabled, isTrue);

    scrubbing.value = true;
    await tester.pump();
    expect(
      tester.widget<BackdropFilter>(finder).enabled,
      isFalse,
      reason: '拖动进度条期间挂起面板玻璃',
    );

    scrubbing.value = false;
    await tester.pump();
    expect(tester.widget<BackdropFilter>(finder).enabled, isTrue);
  });

  group('层子树缓存 identity (v0.0.8.2 渲染优化)', () {
    Finder l0Boundary() =>
        find.byKey(const ValueKey('settings-l0-boundary-about'));

    testWidgets('L0→L1 层级翻转 — _selected 不变, tag 层缓存命中实例不变', (tester) async {
      await openDialog(tester);
      final before = tester.widget<RepaintBoundary>(l0Boundary());

      // → 进 L1 — 只改 _level, 不改 _selected → 缓存必须命中.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final after = tester.widget<RepaintBoundary>(l0Boundary());
      expect(
        identical(before, after),
        isTrue,
        reason: '层级翻转不得重建 tag 层 — 这是打开/进出 L1 零重建的核心',
      );
    });

    testWidgets('↑ 切换选中 — 缓存失效, 新实例 (高亮/内容必须更新)', (tester) async {
      await openDialog(tester);
      final before = tester.widget<RepaintBoundary>(l0Boundary());

      // 默认选中关于 → ↑ 切到音频 → _selected 变化必须失效缓存.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      final after = tester.widget<RepaintBoundary>(
        find.byKey(const ValueKey('settings-l0-boundary-audio')),
      );
      expect(
        identical(before, after),
        isFalse,
        reason: '_selected 变化必须失效缓存, 否则高亮/内容陈旧',
      );
    });
  });

  group('键盘交叉导航 (v0.0.8 XMB 化)', () {
    testWidgets('L0 上下键切换分区高亮且灰显分区不可达', (tester) async {
      await openDialog(tester);
      // 默认选中「关于」（enabled 序列 [通用, 音频, 关于] 的末位）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      // 到头即停：仍在「关于」。
      final about = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-about')),
      );
      expect((about.decoration! as BoxDecoration).color, Tokens.bgHover);

      // ↑ 回到「音频」（enabled 序列中位，v0.0.8.1 解灰后可达）。注意：
      // ArrowUp 后须重取 widget — 旧实例的 decoration 是陈旧快照。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final audio = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-audio')),
      );
      expect((audio.decoration! as BoxDecoration).color, Tokens.bgHover);
      final aboutAfterUp = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-about')),
      );
      expect(
        (aboutAfterUp.decoration! as BoxDecoration).color,
        Colors.transparent,
        reason: '↑↓ 移动后旧分区失去选中底色',
      );

      // 再 ↑ 回到「通用」（enabled 首位）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final general = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('settings-tab-general')),
      );
      expect((general.decoration! as BoxDecoration).color, Tokens.bgHover);
    });

    testWidgets('→ 键进入内容层；L1 内 ← 返回 tag 层；Esc 恒冒泡关面板', (tester) async {
      var closeCount = 0;
      await openDialog(tester, onClose: () => closeCount++);

      // → 直接进入「通用」内容层（默认选中关于 → ↑↑ 切到通用）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsOneWidget);

      // L1 内 ← = 返回 tag 层（新语义，面板仍打开，onClose 不触发）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsNothing);
      expect(closeCount, 0);

      // Esc 在任何层级都 ignored 冒泡宿主关整个面板（本测试装配无宿主
      // KeyboardHandler 链，无效果）— 锁定「面板不自行关闭、不吞键」.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closeCount, 0);
    });

    testWidgets('L1 内 → 无反应（2026-10-09 裁决）；← 返回 tag 层', (tester) async {
      await openDialog(tester);
      // 进入「通用」内容层（默认选中关于 → ↑↑ 到通用 → →）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsOneWidget);

      // L1 内 → 空操作（handled 防泄漏）— 分区保持「通用」，内容不消失。
      // 旧行为（→ 切下一分区）系 v0.0.8 XMB 交叉导航，经用户裁决移除：
      // 分区切换仅发生在 L0（↑↓ 选 tag、→/Enter 进详情）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsOneWidget);

      // ← 返回 tag 层（内容消失 — Offstage）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsNothing);
    });

    testWidgets('General 行导航 — ↓ 高亮首行、Enter 翻转错误卡片开关', (tester) async {
      await openDialog(tester);
      // 进入「通用」内容层（默认选中关于 → ↑↑ 到通用；进入即聚焦第 0 行
      // — 细节终裁）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // 第 0 行（语言行）键盘激活 no-op — 不崩即锁定 no-op 语义。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // ↓ 到第 1 行（错误卡片），Enter 翻转开关。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // 断点行（第 2 行）仅在服务注入时存在 — 无注入时 ↓ 回绕回第 0 行，
      // 再 Enter 仍 no-op。锁定回绕不越界。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsOneWidget);
    });
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
        body: Center(
          child: SizedBox(
            width: 400,
            height: 330,
            child: SettingsPanel(
              visible: true,
              onClose: () {},
              services: SettingsServicesBundle(
                videoProcessing: videoProcessing,
                settings: settings,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('video 分区保持关闭 (bundle 注入也不例外)', (tester) async {
      await tester.pumpWidget(buildInjectedSubject());
      await tester.pumpAndSettle();

      // 入口灰显: 点击不切换内容层.
      await tester.tap(find.text('视频'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(VideoSettingsContent), findsNothing);

      final videoOpacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('视频'), matching: find.byType(Opacity))
            .first,
      );
      expect(videoOpacity.opacity, 0.38);
    });

    testWidgets('audio 分区可进入 — SpinControl 写入 AppSettingsService', (
      tester,
    ) async {
      await tester.pumpWidget(buildInjectedSubject());
      await tester.pumpAndSettle();

      // 解灰后音频分区可点进（v0.0.8.1），AudioSettingsContent 两行
      // 延迟 SpinControl 渲染。
      await tester.tap(find.text('音频'));
      await tester.pumpAndSettle();
      expect(find.byType(AudioSettingsContent), findsOneWidget);
      expect(settings.audioDelayMs, 0);

      // 点第一个 SpinControl 的右箭头（音频延迟行）— 0ms + 50ms 步进。
      final increaseButtons = find.byIcon(Icons.chevron_right);
      await tester.tap(increaseButtons.first);
      await tester.pumpAndSettle();

      expect(settings.audioDelayMs, 50, reason: 'SpinControl 写入服务并落盘通道');
      expect(settings.subtitleDelayMs, 0, reason: '字幕延迟行不受影响');
    });

    testWidgets('通用分区出现断点续播开关并可翻转', (tester) async {
      await tester.pumpWidget(buildInjectedSubject());
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

    testWidgets('services 同实例重建 — 内容层缓存命中 (审查 MEDIUM-1 契约)', (tester) async {
      // 宿主（PlayerFeature）已按审查建议缓存 bundle 实例 — 本用例锁定
      // 面板侧语义：同实例重建不得失效内容层缓存。
      final bundle = SettingsServicesBundle(
        videoProcessing: videoProcessing,
        settings: settings,
      );
      Future<void> pump() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 330,
                  child: SettingsPanel(
                    visible: true,
                    onClose: () {},
                    services: bundle,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump();
      Finder l1Boundary() => find.byKey(
        const ValueKey('settings-l1-boundary-about'),
        skipOffstage: false,
      );
      final before = tester.widget<RepaintBoundary>(l1Boundary());

      await pump(); // 宿主式同实例重建

      expect(
        identical(before, tester.widget<RepaintBoundary>(l1Boundary())),
        isTrue,
        reason: '同实例 services 重建不得失效内容层缓存',
      );
    });

    testWidgets('services 换新实例 — 内容层缓存失效 (保守语义文档化)', (tester) async {
      Future<void> pumpWith(SettingsServicesBundle bundle) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  height: 330,
                  child: SettingsPanel(
                    visible: true,
                    onClose: () {},
                    services: bundle,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWith(
        SettingsServicesBundle(
          videoProcessing: videoProcessing,
          settings: settings,
        ),
      );
      Finder l1Boundary() => find.byKey(
        const ValueKey('settings-l1-boundary-about'),
        skipOffstage: false,
      );
      final before = tester.widget<RepaintBoundary>(l1Boundary());

      await pumpWith(
        SettingsServicesBundle(
          videoProcessing: videoProcessing,
          settings: settings,
        ),
      );

      expect(
        identical(before, tester.widget<RepaintBoundary>(l1Boundary())),
        isFalse,
        reason: '新实例按 identity 比较保守失效 — 语义文档化于此',
      );
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

  /// 261009-rp5 证伪组 — audio 分区键盘行响应是否存在（零生产改动验证轮）。
  ///
  /// 假设: `_enabledTabs` 自称 audio 已解灰（v0.0.8.1），但纯键盘旅程
  /// （L0 ↑ 切到音频 → → 进 L1 → 发 ↑↓/Enter）下 `_handleContentLevelKey`
  /// 对非 General 分区把 ↑↓/Enter 全部 handled 空操作，行无任何响应。
  ///
  /// 「行响应」断言取焦点拓扑: primaryFocus 是否下沉进分区内容子树 —
  /// 修复形状无关（rowsFocusNode 注入或 SpinControl 聚焦均满足）。
  group('audio 分区键盘行响应证伪 (261009-rp5)', () {
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

    Widget buildSubject() => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 330,
            child: SettingsPanel(
              visible: true,
              onClose: () {},
              services: SettingsServicesBundle(
                videoProcessing: videoProcessing,
                settings: settings,
              ),
            ),
          ),
        ),
      ),
    );

    /// primaryFocus 是否位于 [contentType] 分区内容子树内 — 行级焦点的
    /// 拓扑判定（面板级 Focus 节点的 context 祖先链不含分区内容组件）。
    bool isPrimaryFocusInside(Type contentType) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      var found = false;
      context.visitAncestorElements((element) {
        if (element.widget.runtimeType == contentType) found = true;
        return !found;
      });
      return found;
    }

    testWidgets('对照 — General 同旅程焦点下沉行级（harness 可探测行响应）', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 默认选中关于 → ↑↑ 到通用 → → 进 L1（General 进入即聚焦首行）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsContent), findsOneWidget);

      // 行焦点已下沉 General 内容子树；↓ 行导航后仍在行级。
      expect(isPrimaryFocusInside(GeneralSettingsContent), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isPrimaryFocusInside(GeneralSettingsContent), isTrue);
    });

    /// 缺陷锁（2026-10-09 RED 证实）——键盘旅程进 audio L1 后 ↑↓/Enter
    /// 全部 handled 空操作，焦点滞留面板级节点：
    /// - `_handleContentLevelKey`（settings_panel.dart:391-412）对非 General
    ///   分区的 ↑↓/Enter 一律 `return handled`，不做任何行聚焦；
    /// - `_buildTabContent`（settings_panel.dart:693-699）构建
    ///   AudioSettingsContent 时**不注入 rowsFocusNode**（General 有注入），
    ///   AudioSettingsContent 本体亦无 Focus/键盘处理——SpinControl 虽有
    ///   Focus（仅 ←→），纯键盘无路径可达（面板 Focus skipTraversal +
    ///   无程序化聚焦）。
    ///
    /// 与 `_enabledTabs` 注释自称「audio 已解灰（v0.0.8.1）」矛盾：解灰
    /// 只解了指针路径，键盘用户进了 audio 分区后无法操作任何行。
    ///
    /// 契约翻转：修复（AudioSettingsContent 注入 rowsFocusNode 复用
    /// General 模式，~30 行）落地后，把下方 isFalse 全部翻转为 isTrue，
    /// 并对照上方 General 用例补 ↑↓ 行移动断言。
    testWidgets('audio L1 发 ↑↓/Enter — 吞键无行响应（缺陷锁 · 修复待裁决）', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // 默认选中关于 → ↑ 到音频 → → 进 L1（导航本身可达）。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(AudioSettingsContent), findsOneWidget);

      // ↓ handled 但空操作 — 焦点从未下沉进 audio 行。
      final downHandled = await tester.sendKeyEvent(
        LogicalKeyboardKey.arrowDown,
      );
      await tester.pumpAndSettle();
      expect(downHandled, isTrue, reason: '↓ 被面板吞掉（handled 返回）');
      expect(
        isPrimaryFocusInside(AudioSettingsContent),
        isFalse,
        reason: '缺陷锁: ↓ 后焦点仍在面板级 — 修复落地后翻转为 isTrue',
      );

      // ↑ 同样吞键。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isPrimaryFocusInside(AudioSettingsContent), isFalse);

      // Enter 同样吞键 — 未激活任何行，两个延迟值不动。
      final enterHandled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(enterHandled, isTrue, reason: 'Enter 被面板吞掉（handled 返回）');
      expect(isPrimaryFocusInside(AudioSettingsContent), isFalse);
      expect(settings.audioDelayMs, 0, reason: 'Enter 未激活音频延迟行');
      expect(settings.subtitleDelayMs, 0, reason: 'Enter 未激活字幕延迟行');
    });
  });
}
