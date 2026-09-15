/// PlayerScreen 控制层装配回归测试 (v0.0.6 清理轮).
///
/// 锁死"单一装配入口"契约: 生产 `_buildControls` 与测试 seam 必须给出
/// **完全一致**的 PlayerVideoControls 接线。回归背景: 曾存在双路径分叉,
/// 生产经顶层 helper 装配漏传 settingsServices, 导致"记住播放位置"的
/// 面板门控在实机上失效(数据层不记录但面板仍显示旧断点)。
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
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_dialog.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';
import 'package:simple_player_flutter/ui/playlist/playlist_panel.dart';

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
  });

  tearDown(() {
    settings.dispose();
    videoProcessing.dispose();
    engine.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final coordinator = PlaylistCoordinator(
      engine: engine,
      resumeEnabled: settings.resumeEnabled,
    );
    addTearDown(coordinator.dispose);
    final controller = PlaybackController(engine: engine);
    addTearDown(controller.dispose);
    final windowService = FakeWindowService();
    addTearDown(windowService.dispose);

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
          videoSurfaceBuilder: (_) => const SizedBox.expand(),
          testVideoControls: videoPort,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('装配单一入口 — settingsServices 贯通到 PlaylistPanel', (tester) async {
    await pumpScreen(tester);

    // 空置态: 面板挂载 (playlistCoordinator 非空), 其 resumeEnabled 必须来自
    // settingsServices.settings.resumeEnabled — null 即生产接线断裂.
    final panel = tester.widget<PlaylistPanel>(find.byType(PlaylistPanel));
    expect(panel.resumeEnabled, same(settings.resumeEnabled));
  });
}
