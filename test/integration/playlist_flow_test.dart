import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';

import '../helpers/fake_engine.dart';
import '../helpers/integration_helpers.dart';

void main() {
  group('Playlist flow', () {
    late FakeEngine engine;
    late dynamic controller;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);
      controller = createTestController(engine);
    });

    tearDown(() {
      engine.dispose();
    });

    test('playNext advances to next track', () async {
      controller.playlist.addAll(['C:/a.mp4', 'C:/b.mp4', 'C:/c.mp4']);
      controller.playlist.currentIndex = 0;
      await controller.playNext();
      expect(controller.playlist.currentIndex, 1);
      expect(engine.openCallCount, 1);
    });

    test('playPrevious goes back', () async {
      controller.playlist.addAll(['C:/a.mp4', 'C:/b.mp4', 'C:/c.mp4']);
      controller.playlist.currentIndex = 2;
      await controller.playPrevious();
      expect(controller.playlist.currentIndex, 1);
    });

    test('loopAll wraps at end', () async {
      controller.playlist.addAll(['C:/a.mp4', 'C:/b.mp4', 'C:/c.mp4']);
      controller.playlist.mode = PlayMode.loopAll;
      controller.playlist.currentIndex = 2;
      await controller.playNext();
      expect(controller.playlist.currentIndex, 0);
    });

    test('loopSingle replays same track', () async {
      controller.playlist.addAll(['C:/a.mp4', 'C:/b.mp4']);
      controller.playlist.mode = PlayMode.loopSingle;
      controller.playlist.currentIndex = 0;
      await controller.playNext();
      expect(controller.playlist.currentIndex, 0);
    });

    test('cycle play modes', () {
      expect(controller.playlist.mode, PlayMode.loopAll);

      controller.playlist.mode = PlayMode.loopSingle;
      expect(controller.playlist.mode, PlayMode.loopSingle);

      controller.playlist.mode = PlayMode.shuffle;
      expect(controller.playlist.mode, PlayMode.shuffle);

      controller.playlist.mode = PlayMode.loopAll;
      expect(controller.playlist.mode, PlayMode.loopAll);
    });

    test('addFiles adds to playlist', () async {
      final count = await controller.addFiles(['C:/a.mp4', 'C:/b.mp4']);
      expect(count, 2);
      expect(controller.playlist.length, 2);
    });
  });
}
