/// PlayerScreen 整页 golden — 界面不变重构的像素兜底。
///
/// Whole-page golden for the pixel-parity safety net: refactors of lib/ui must
/// keep these baselines byte-tolerant (see [enableTolerantGoldens]). Existing
/// per-widget goldens cannot see composition changes such as title bar + video
/// + control bar stacking, so this pins the assembled screen.
///
/// 视频面用纯色占位（真实纹理走 mpv_kit，headless 不可用）。
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/services/app_settings_service.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';
import 'package:simple_player_flutter/kernel/services/video_processing_service.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel.dart';
import 'package:simple_player_flutter/ui/player/player_screen.dart';

import '../helpers/fake_engine.dart';
import '../helpers/fake_player_controls.dart';
import '../helpers/fake_video_controls.dart';
import '../helpers/fake_window_service.dart';
import 'golden_comparator.dart';
import '../helpers/l10n_delegates.dart' show l10nDelegates;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() {
    enableTolerantGoldens();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late FakeEngine engine;
  late FakePlayerControls playerPort;
  late FakeVideoControlsPort videoPort;
  late VideoProcessingService videoProcessing;
  late AppSettingsService settings;

  setUp(() {
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
    // 固定逻辑尺寸与 DPR，保证基准图跨机器一致。
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
      RepaintBoundary(
        key: const ValueKey<String>('golden-root'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: l10nDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: PlayerScreen(
            engine: engine,
            controller: controller,
            playlistCoordinator: coordinator,
            settingsServices: SettingsServicesBundle(
              videoProcessing: videoProcessing,
              settings: settings,
            ),
            windowService: windowService,
            // 纯色占位代替 mpv 纹理 — 只锁定外壳合成。
            videoSurfaceBuilder: () => const ColoredBox(color: Colors.black),
            testVideoControls: videoPort,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('PlayerScreen golden', () {
    testWidgets('idle (empty state)', (tester) async {
      await pumpScreen(tester);
      await expectLater(
        find.byKey(const ValueKey<String>('golden-root')),
        matchesGoldenFile('goldens/player_screen_idle.png'),
      );
    });

    testWidgets('playing (control bar visible)', (tester) async {
      engine.configureMedia(durationMs: 120000);
      engine.position.value = 30000;
      engine.state.value = MediaState.playing;
      await pumpScreen(tester);
      await expectLater(
        find.byKey(const ValueKey<String>('golden-root')),
        matchesGoldenFile('goldens/player_screen_playing.png'),
      );
    });
  });
}
