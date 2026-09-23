import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_keyboard_actions.dart';
import 'package:simple_player_flutter/ui/shared/osd_overlay.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_window_service.dart';

void main() {
  tearDown(() {
    OsdService.I.hide();
  });

  /// 装配键盘处理器 (zh 本地化 — onToggleMute OSD 文案依赖 l10n).
  Future<void> pumpHandler(
    WidgetTester tester, {
    required FakeEngine engine,
  }) async {
    final controller = PlaybackController(engine: engine);
    final windowService = FakeWindowService();
    addTearDown(() {
      controller.dispose();
      windowService.dispose();
      engine.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildPlayerKeyboardActions(
            engine: engine,
            controller: controller,
            actions: const PlayerActions(),
            customBindings: const {},
            videoKey: GlobalKey<VideoState>(),
            isFullscreen: false,
            context: context,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'window keyboard delegates playback commands to stable PlayerActions',
    (tester) async {
      final engine = FakeEngine();
      final controller = PlaybackController(engine: engine);
      final windowService = FakeWindowService();
      var playPauseCount = 0;
      final seekBackValues = <int>[];
      final seekForwardValues = <int>[];
      final actions = PlayerActions(
        onPlayPause: () => playPauseCount++,
        onSeekBack: seekBackValues.add,
        onSeekForward: seekForwardValues.add,
      );

      addTearDown(() {
        controller.dispose();
        windowService.dispose();
        engine.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => buildPlayerKeyboardActions(
              engine: engine,
              controller: controller,
              actions: actions,
              customBindings: const {},
              videoKey: GlobalKey<VideoState>(),
              isFullscreen: false,
              context: context,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);

      expect(playPauseCount, 2);
      expect(seekBackValues, [Tokens.skipShortMs]);
      expect(seekForwardValues, [Tokens.skipLongMs]);
      // 旧窗口态路径会直接调用 engine；统一后只允许 PlayerActions 接收命令。
      expect(engine.togglePlayPauseCallCount, 0);
      expect(engine.skipBackCallCount, 0);
      expect(engine.skipForwardCallCount, 0);
    },
  );

  testWidgets('ArrowUp — setVolume +0.05 且 OSD 反馈百分比 (v0.0.8.1)', (
    tester,
  ) async {
    final engine = FakeEngine();
    engine.setVolume(0.5);
    await pumpHandler(tester, engine: engine);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

    expect(engine.lastSetVolumeValue, closeTo(0.55, 1e-9));
    expect(OsdService.I.message.value?.text, '55%', reason: '键盘调音量须有 OSD');

    // OSD hold 定时器在测试体结束时校验 — 体内显式取消 (tearDown 太晚).
    OsdService.I.hide();
  });

  testWidgets('KeyM — 静音且 OSD 静音文案 (v0.0.8.1)', (tester) async {
    final engine = FakeEngine();
    engine.setVolume(0.6);
    await pumpHandler(tester, engine: engine);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

    expect(engine.isMuted.value, isTrue);
    expect(OsdService.I.message.value?.text, '静音');
    // 原生静音: mute 不触碰音量.
    expect(engine.setVolumeCallCount, 1, reason: '仅 setUp 的 setVolume(0.6)');
    OsdService.I.hide();
  });
}
