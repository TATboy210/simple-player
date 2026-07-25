import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';
import 'package:simple_player_flutter/kernel/engine/playback_skip_mixin.dart';

/// 测试用引擎 — 混入 PlaybackSkipMixin 验证行为
class _TestEngine with PlaybackSkipMixin {
  int seekToCalled = 0;
  int lastSeekTarget = 0;

  @override
  final ValueNotifier<int> position = ValueNotifier(0);

  @override
  final ValueNotifier<int> duration = ValueNotifier(60000);

  @override
  Future<void> seekTo(int ms) async {
    seekToCalled++;
    lastSeekTarget = ms;
  }

  // PlaybackControl 其他方法 — stub 实现
  @override
  Future<OpenResult> open(String path) async => const OpenSuperseded();
  @override
  void play() {}
  @override
  void pause() {}
  @override
  void stop() {}
  @override
  void togglePlayPause() {}
  @override
  void setVolume(double volume) {}
  @override
  void setMute(bool mute) {}
  @override
  void setPlaybackRate(double rate) {}
  @override
  void setRange({required int from, int to = -1}) {}
}

void main() {
  group('PlaybackSkipMixin', () {
    late _TestEngine engine;

    setUp(() {
      engine = _TestEngine();
    });

    tearDown(() {
      engine.position.dispose();
      engine.duration.dispose();
    });

    group('skipForward', () {
      test('normal skip: 5000 + 10000 = 15000', () {
        engine.position.value = 5000;
        engine.duration.value = 60000;
        engine.skipForward();
        expect(engine.lastSeekTarget, 15000);
        expect(engine.seekToCalled, 1);
      });

      test('clamped at duration: 55000 + 10000 = 60000', () {
        engine.position.value = 55000;
        engine.duration.value = 60000;
        engine.skipForward();
        expect(engine.lastSeekTarget, 60000);
      });

      test('custom ms: 5000 + 30000 = 35000', () {
        engine.position.value = 5000;
        engine.duration.value = 60000;
        engine.skipForward(30000);
        expect(engine.lastSeekTarget, 35000);
      });

      test('at end: 60000 + 10000 = 60000 (clamped)', () {
        engine.position.value = 60000;
        engine.duration.value = 60000;
        engine.skipForward();
        expect(engine.lastSeekTarget, 60000);
      });
    });

    group('skipBack', () {
      test('normal skip: 15000 - 10000 = 5000', () {
        engine.position.value = 15000;
        engine.duration.value = 60000;
        engine.skipBack();
        expect(engine.lastSeekTarget, 5000);
        expect(engine.seekToCalled, 1);
      });

      test('clamped at 0: 5000 - 10000 = 0', () {
        engine.position.value = 5000;
        engine.duration.value = 60000;
        engine.skipBack();
        expect(engine.lastSeekTarget, 0);
      });

      test('custom ms: 30000 - 15000 = 15000', () {
        engine.position.value = 30000;
        engine.duration.value = 60000;
        engine.skipBack(15000);
        expect(engine.lastSeekTarget, 15000);
      });

      test('at start: 0 - 10000 = 0 (clamped)', () {
        engine.position.value = 0;
        engine.duration.value = 60000;
        engine.skipBack();
        expect(engine.lastSeekTarget, 0);
      });
    });
  });
}
