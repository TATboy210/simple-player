import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/ui/player/player_actions.dart';
import 'package:simple_player_flutter/ui/player/player_keyboard_actions.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_window_service.dart';

void main() {
  testWidgets(
    'window keyboard delegates playback commands to stable PlayerActions',
    (tester) async {
      final engine = FakeEngine();
      final playlist = Playlist();
      final controller = PlaybackController(
        engine: engine,
        playlist: playlist,
        onNeedRebuild: () {},
      );
      final windowService = FakeWindowService();
      var playPauseCount = 0;
      var previousCount = 0;
      var nextCount = 0;
      final seekBackValues = <int>[];
      final seekForwardValues = <int>[];
      final actions = PlayerActions(
        onPlayPause: () => playPauseCount++,
        onSeekBack: seekBackValues.add,
        onSeekForward: seekForwardValues.add,
        onPrevious: () => previousCount++,
        onNext: () => nextCount++,
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
              windowService: windowService,
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
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);

      expect(playPauseCount, 2);
      expect(seekBackValues, [Tokens.skipShortMs]);
      expect(seekForwardValues, [Tokens.skipLongMs]);
      expect(previousCount, 1);
      expect(nextCount, 1);
      // 旧窗口态路径会直接调用 engine；统一后只允许 PlayerActions 接收命令。
      expect(engine.togglePlayPauseCallCount, 0);
      expect(engine.skipBackCallCount, 0);
      expect(engine.skipForwardCallCount, 0);
    },
  );
}
