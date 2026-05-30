import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_engine.dart';
import '../helpers/integration_helpers.dart';

void main() {
  group('Controls flow', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);
    });

    tearDown(() {
      engine.dispose();
    });

    test('setVolume changes volume', () {
      engine.setVolume(0.5);
      expect(engine.volume.value, 0.5);
    });

    test('setVolume clamps to 0-1', () {
      engine.setVolume(1.5);
      expect(engine.volume.value, 1.0);

      engine.setVolume(-0.5);
      expect(engine.volume.value, 0.0);
    });

    test('setMute toggles mute state', () {
      engine.setMute(true);
      expect(engine.isMuted.value, true);

      engine.setMute(false);
      expect(engine.isMuted.value, false);
    });

    test('volume 0 sets muted', () {
      engine.setVolume(0);
      expect(engine.isMuted.value, true);
    });

    test('fullscreen toggle updates state', () async {
      final windowService = createFakeWindowService();

      await windowService.setFullscreen(true);
      expect(windowService.isFullscreen.value, true);
      expect(windowService.fullscreenCallCount, 1);
      expect(windowService.lastFullscreenValue, true);

      await windowService.setFullscreen(false);
      expect(windowService.isFullscreen.value, false);
      expect(windowService.fullscreenCallCount, 2);
      expect(windowService.lastFullscreenValue, false);

      windowService.dispose();
    });

    test('playback speed changes', () {
      engine.setPlaybackRate(2.0);
      expect(engine.playbackSpeed.value, 2.0);

      engine.setPlaybackRate(0.5);
      expect(engine.playbackSpeed.value, 0.5);
    });
  });
}
