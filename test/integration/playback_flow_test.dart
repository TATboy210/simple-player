import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/media_state.dart';

import '../helpers/fake_engine.dart';
import '../helpers/integration_helpers.dart';

void main() {
  group('Playback flow', () {
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

    test('open file starts playback', () async {
      await controller.openAndPlay('C:/test.mp4');
      expect(engine.state.value, MediaState.playing);
      expect(engine.openCallCount, 1);
      expect(engine.openPaths, ['C:/test.mp4']);
    });

    test('seek updates position', () async {
      await engine.open('C:/test.mp4');
      engine.play();
      await engine.seekTo(30000);
      expect(engine.position.value, 30000);
      expect(engine.seekToCallCount, 1);
    });

    test('pause stops playback', () async {
      await controller.openAndPlay('C:/test.mp4');
      engine.pause();
      expect(engine.state.value, MediaState.paused);
      expect(engine.pauseCallCount, 1);
    });

    test('togglePlayPause cycles states', () async {
      await controller.openAndPlay('C:/test.mp4');
      expect(engine.state.value, MediaState.playing);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.paused);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.playing);
    });

    test('skipForward advances position', () async {
      await engine.open('C:/test.mp4');
      engine.play();
      engine.position.value = 10000;
      engine.skipForward(10);
      expect(engine.position.value, 20000);
    });

    test('skipBack decreases position', () async {
      await engine.open('C:/test.mp4');
      engine.play();
      engine.position.value = 30000;
      engine.skipBack(10);
      expect(engine.position.value, 20000);
    });
  });
}
