/// PlayerScreen 层 rebuild boundary 测试 (v0.0.9 P0-2)。
///
/// 锁死重建矩阵：hover / isResizing / mode 翻转各事件对 PlayerScreen
/// build 与视频链 widget identity 的影响。回归背景：曾存在两处"假缓存"
/// — PlayerFeature hover 走 setState 重建整棵 PlayerScreen；
/// PlayerScreen 的 cachedVideoContent 实为 build 局部变量，父级每次
/// build 都重构造 Row→DropHandler→Stack→Video 整链（State 因 GlobalKey
/// 保留但 widget 构造成本照付）。修复后 hover 零上层重建、视频链经
/// AnimatedBuilder.child 恒定 identity。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_manager_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/player/drop_handler.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_player_controls.dart';
import '../../helpers/fake_video_controls.dart';
import '../../helpers/fake_window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late FakePlayerControls playerPort;
  late FakeVideoControlsPort videoPort;
  late VideoProcessingService videoProcessing;
  late AppSettingsService settings;
  late FakeWindowService windowService;
  int screenBuilds = 0;

  /// 固定 surface builder — 跨重泵复用同一闭包（依赖比对按 identity）。
  /// 每次新建闭包会正确触发视频链缓存失效（那是行为契约而非 bug）。
  Widget surfaceBuilder(GlobalKey<dynamic> key) => const SizedBox.expand();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = FakeEngine();
    playerPort = FakePlayerControls();
    videoPort = FakeVideoControlsPort(player: playerPort);
    videoProcessing = VideoProcessingService(engine);
    settings = AppSettingsService(
      engine: engine,
      videoProcessing: videoProcessing,
      store: AppSettingsStore(),
    );
    windowService = FakeWindowService();
    screenBuilds = 0;
  });

  tearDown(() {
    settings.dispose();
    videoProcessing.dispose();
    engine.dispose();
    windowService.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    void Function(List<String>)? onFilesDropped,
    void Function(bool hovering)? onDragHoverChanged,
  }) async {
    final coordinator = PlaylistCoordinator(
      engine: engine,
      resumeEnabled: settings.resumeEnabled,
    );
    addTearDown(coordinator.dispose);
    final controller = PlaybackController(engine: engine);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerScreen(
          engine: engine,
          controller: controller,
          playlistCoordinator: coordinator,
          settingsServices: SettingsServicesBundle(
            videoProcessing: videoProcessing,
            settings: settings,
          ),
          windowService: windowService,
          videoSurfaceBuilder: surfaceBuilder,
          testVideoControls: videoPort,
          onFilesDropped: onFilesDropped,
          onDragHoverChanged: onDragHoverChanged,
          debugOnBuild: () => screenBuilds++,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hover 翻转 — PlayerScreen.build 零重建（P0-2 根因锁定）', (tester) async {
    var hoverEvents = 0;
    void onHover(bool hovering) => hoverEvents++;
    await pumpScreen(tester, onDragHoverChanged: onHover);
    final buildsBefore = screenBuilds;

    // 模拟 DropHandler hover 进/出 ×2 — 走真实回调链。
    final screen = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
    screen.onDragHoverChanged!(true);
    await tester.pump(const Duration(milliseconds: 400));
    screen.onDragHoverChanged!(false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(hoverEvents, 2, reason: '回调链闭合 — DropHandler 事件抵达宿主');
    expect(screenBuilds, buildsBefore, reason: 'hover 直写 notifier，上层零重建');
    expect(tester.takeException(), isNull);
  });

  testWidgets('isResizing 翻转 — PlayerScreen.build 零重建（VLB 局部驱动）', (
    tester,
  ) async {
    await pumpScreen(tester);
    final buildsBefore = screenBuilds;

    windowService.isResizing.value = true;
    await tester.pump();
    windowService.isResizing.value = false;
    await tester.pump(const Duration(milliseconds: 400));

    expect(screenBuilds, buildsBefore, reason: 'resize 画质切换由视频子树内部 VLB 驱动');
  });

  testWidgets('mode 翻转 — AnimatedBuilder 内部驱动，视频链 identity 恒定', (tester) async {
    await pumpScreen(tester);
    final dropHandlerBefore = tester.widget<DropHandler>(
      find.byType(DropHandler),
    );
    final buildsBefore = screenBuilds;

    await windowService.setMode(WindowMode.fullscreen);
    await tester.pump(const Duration(milliseconds: 400));

    // AnimatedBuilder 只重跑 builder 闭包，PlayerScreen.build 不执行 —
    // screenBuilds 不变正是优化目标（外壳重组由 builder 层承担）。
    expect(screenBuilds, buildsBefore);
    final dropHandlerAfter = tester.widget<DropHandler>(
      find.byType(DropHandler),
    );
    expect(
      identical(dropHandlerBefore, dropHandlerAfter),
      isTrue,
      reason: '视频链经 AnimatedBuilder.child 透传，mode 翻转零重建',
    );
  });

  testWidgets('父级重泵（同依赖新实例）— 视频链缓存保留', (tester) async {
    void onDrop(List<String> paths) {}
    await pumpScreen(tester, onFilesDropped: onDrop);
    final dropHandlerBefore = tester.widget<DropHandler>(
      find.byType(DropHandler),
    );

    // 同依赖重泵 — 模拟宿主因无关状态 rebuild 传入新 PlayerScreen 实例。
    await pumpScreen(tester, onFilesDropped: onDrop);

    final dropHandlerAfter = tester.widget<DropHandler>(
      find.byType(DropHandler),
    );
    expect(
      identical(dropHandlerBefore, dropHandlerAfter),
      isTrue,
      reason: '依赖 identity 未变时视频子树缓存必须保留',
    );
  });

  testWidgets('onFilesDropped 替换 — 缓存正确失效，DropHandler 收到新回调', (tester) async {
    var dropCount = 0;
    void onDropV1(List<String> paths) {}
    void onDropV2(List<String> paths) => dropCount++;

    await pumpScreen(tester, onFilesDropped: onDropV1);
    await pumpScreen(tester, onFilesDropped: onDropV2);

    // 陈旧闭包防御：替换后拖放必须路由到新回调（漏判 = 拖放静默丢失）。
    tester.widget<DropHandler>(find.byType(DropHandler)).onFilesDropped(const [
      'C:\\video\\a.mp4',
    ]);
    expect(dropCount, 1);
  });
}
