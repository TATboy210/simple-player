import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import '../helpers/fake_engine.dart';

void main() {
  group('Mixin capability checks', () {
    test('FakeEngine is TrackControl', () {
      final engine = FakeEngine();
      expect(engine, isA<TrackControl>());
      engine.dispose();
    });

    test('FakeEngine is VideoEffectControl', () {
      final engine = FakeEngine();
      expect(engine, isA<VideoEffectControl>());
      engine.dispose();
    });

    test('FakeEngine is RendererControl', () {
      final engine = FakeEngine();
      expect(engine, isA<RendererControl>());
      engine.dispose();
    });

    test('FakeEngine is MediaEngine', () {
      final engine = FakeEngine();
      expect(engine, isA<MediaEngine>());
      engine.dispose();
    });

    test('Dart 3 pattern matching: case TrackControl', () {
      final MediaEngine engine = FakeEngine();
      if (engine case final TrackControl tc) {
        expect(tc.getAudioTracks(), isEmpty);
      } else {
        fail('engine should match TrackControl');
      }
      engine.dispose();
    });

    test('Dart 3 pattern matching: case VideoEffectControl', () {
      final MediaEngine engine = FakeEngine();
      if (engine case final VideoEffectControl ve) {
        ve.setVideoEffect(VideoEffectType.brightness, 0.5);
      } else {
        fail('engine should match VideoEffectControl');
      }
      engine.dispose();
    });

    test('Dart 3 pattern matching: case RendererControl', () {
      final MediaEngine engine = FakeEngine();
      if (engine case final RendererControl rc) {
        rc.setD3d11SyncEnabled(true);
        rc.setHardwareDecoding(false);
      } else {
        fail('engine should match RendererControl');
      }
      engine.dispose();
    });
  });

  group('EngineState base still works', () {
    test('open() succeeds', () async {
      final engine = FakeEngine();
      await engine.open('test.mp4');
      expect(engine.openCallCount, 1);
      engine.dispose();
    });

    test('play() sets state to playing', () async {
      final engine = FakeEngine();
      await engine.open('test.mp4'); // idle → opening → idle (open completes)
      engine.play(); // idle → playing
      expect(engine.state.value, MediaState.playing);
      engine.dispose();
    });

    test('dispose() works', () {
      final engine = FakeEngine();
      engine.dispose();
    });

    test('all 12 ValueNotifiers are accessible', () {
      final engine = FakeEngine();
      expect(engine.textureId, isA<ValueNotifier<int?>>());
      expect(engine.state, isA<ValueNotifier<MediaState>>());
      expect(engine.position, isA<ValueNotifier<int>>());
      expect(engine.duration, isA<ValueNotifier<int>>());
      expect(engine.volume, isA<ValueNotifier<double>>());
      expect(engine.isMuted, isA<ValueNotifier<bool>>());
      expect(engine.isBuffering, isA<ValueNotifier<bool>>());
      expect(engine.subtitleText, isA<ValueNotifier<String>>());
      expect(engine.buffered, isA<ValueNotifier<int>>());
      expect(engine.aspectRatio, isA<ValueNotifier<double>>());
      expect(engine.lastError, isA<ValueNotifier<PlayerError?>>());
      expect(engine.playbackSpeed, isA<ValueNotifier<double>>());
      engine.dispose();
    });
  });

  group('EngineState playback behavior', () {
    test('seekTo updates position and tracks call', () async {
      final engine = FakeEngine();
      engine.duration.value = 60000;
      await engine.seekTo(30000);
      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, 30000);
      expect(engine.position.value, 30000);
      engine.dispose();
    });

    test('seekTo clamps to duration', () async {
      final engine = FakeEngine();
      engine.duration.value = 60000;
      await engine.seekTo(99999);
      expect(engine.position.value, 60000);
      engine.dispose();
    });

    test('seekTo clamps to zero', () async {
      final engine = FakeEngine();
      engine.duration.value = 60000;
      await engine.seekTo(-5000);
      expect(engine.position.value, 0);
      engine.dispose();
    });

    test('setVolume clamps and updates notifier', () {
      final engine = FakeEngine();
      engine.setVolume(0.5);
      expect(engine.volume.value, 0.5);
      expect(engine.isMuted.value, isFalse);
      engine.dispose();
    });

    test('setVolume to 0 auto-mutes', () {
      final engine = FakeEngine();
      engine.setVolume(0);
      expect(engine.volume.value, 0);
      expect(engine.isMuted.value, isTrue);
      engine.dispose();
    });

    test('setVolume clamps to 1.0 max', () {
      final engine = FakeEngine();
      engine.setVolume(2.0);
      expect(engine.volume.value, 1.0);
      engine.dispose();
    });

    test('setMute toggles notifier', () {
      final engine = FakeEngine();
      engine.setMute(true);
      expect(engine.isMuted.value, isTrue);
      engine.setMute(false);
      expect(engine.isMuted.value, isFalse);
      engine.dispose();
    });

    test('togglePlayPause cycles between playing and paused', () async {
      final engine = FakeEngine();
      await engine.open('test.mp4');
      engine.play();
      expect(engine.state.value, MediaState.playing);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.paused);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.playing);
      engine.dispose();
    });

    test('setPlaybackRate clamps to valid range', () {
      final engine = FakeEngine();
      engine.setPlaybackRate(2.0);
      expect(engine.playbackSpeed.value, 2.0);

      engine.setPlaybackRate(0.1); // below 0.25
      expect(engine.playbackSpeed.value, 0.25);

      engine.setPlaybackRate(8.0); // above 4.0
      expect(engine.playbackSpeed.value, 4.0);
      engine.dispose();
    });

    test('pause sets state and tracks call', () async {
      final engine = FakeEngine();
      await engine.open('test.mp4');
      engine.play();
      engine.pause();
      expect(engine.state.value, MediaState.paused);
      expect(engine.pauseCallCount, 1);
      engine.dispose();
    });

    test('stop resets position and tracks call', () {
      final engine = FakeEngine();
      engine.position.value = 30000;
      engine.stop();
      expect(engine.state.value, MediaState.idle);
      expect(engine.position.value, 0);
      expect(engine.stopCallCount, 1);
      engine.dispose();
    });
  });

  group('TrackControl behavior', () {
    test('getAudioTracks returns configured tracks', () {
      final engine = FakeEngine();
      engine.configureMedia(
        audioTracks: [const AudioTrackInfo(index: 0, language: 'en')],
      );
      final tracks = engine.getAudioTracks();
      expect(tracks, hasLength(1));
      expect(tracks.first.language, 'en');
      engine.dispose();
    });

    test('getSubtitleTracks returns configured tracks', () {
      final engine = FakeEngine();
      engine.configureMedia(
        subtitleTracks: [
          const SubtitleTrackInfo(index: 0, language: 'zh', title: 'Chinese'),
        ],
      );
      final tracks = engine.getSubtitleTracks();
      expect(tracks, hasLength(1));
      expect(tracks.first.title, 'Chinese');
      engine.dispose();
    });

    test('setExternalSubtitle tracks call and path', () {
      final engine = FakeEngine();
      engine.setExternalSubtitle('/path/to/sub.srt');
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, '/path/to/sub.srt');
      engine.dispose();
    });

    test('setSubtitleDelay tracks call and value', () {
      final engine = FakeEngine();
      engine.setSubtitleDelay(1500);
      expect(engine.setSubtitleDelayCallCount, 1);
      expect(engine.subtitleDelay, 1500);
      engine.dispose();
    });

    test('activeAudioTracks returns empty list', () {
      final engine = FakeEngine();
      expect(engine.activeAudioTracks, isEmpty);
      engine.dispose();
    });
  });

  group('VideoEffects behavior', () {
    test('setVideoEffect tracks type and value', () {
      final engine = FakeEngine();
      engine.setVideoEffect(VideoEffectType.brightness, 0.7);
      expect(engine.setVideoEffectCallCount, 1);
      expect(engine.lastVideoEffectType, VideoEffectType.brightness);
      expect(engine.lastVideoEffectValue, 0.7);
      engine.dispose();
    });

    test('rotate tracks degree', () {
      final engine = FakeEngine();
      engine.rotate(90);
      expect(engine.rotateCallCount, 1);
      expect(engine.lastRotateDegree, 90);
      engine.dispose();
    });

    test('setAspectRatio tracks ratio', () {
      final engine = FakeEngine();
      engine.setAspectRatio(4 / 3);
      expect(engine.setAspectRatioCallCount, 1);
      expect(engine.lastAspectRatioValue, 4 / 3);
      engine.dispose();
    });

    test('setDeinterlace tracks enable state', () {
      final engine = FakeEngine();
      engine.setDeinterlace(true);
      expect(engine.setDeinterlaceCallCount, 1);
      expect(engine.lastDeinterlaceValue, isTrue);
      engine.dispose();
    });

    test('multiple calls increment counters correctly', () {
      final engine = FakeEngine();
      engine.setVideoEffect(VideoEffectType.brightness, 0.5);
      engine.setVideoEffect(VideoEffectType.contrast, 0.8);
      expect(engine.setVideoEffectCallCount, 2);
      expect(engine.lastVideoEffectType, VideoEffectType.contrast);
      engine.dispose();
    });
  });

  group('RendererConfig behavior', () {
    test('setD3d11SyncEnabled tracks call and value', () {
      final engine = FakeEngine();
      engine.setD3d11SyncEnabled(true);
      expect(engine.setD3d11SyncEnabledCallCount, 1);
      expect(engine.lastD3d11SyncEnabled, isTrue);
      engine.dispose();
    });

    test('setHardwareDecoding tracks call and value', () {
      final engine = FakeEngine();
      engine.setHardwareDecoding(false);
      expect(engine.setHardwareDecodingCallCount, 1);
      expect(engine.lastHardwareDecodingEnabled, isFalse);
      engine.dispose();
    });

    test('multiple calls increment counters', () {
      final engine = FakeEngine();
      engine.setD3d11SyncEnabled(true);
      engine.setD3d11SyncEnabled(false);
      engine.setD3d11SyncEnabled(true);
      expect(engine.setD3d11SyncEnabledCallCount, 3);
      expect(engine.lastD3d11SyncEnabled, isTrue);
      engine.dispose();
    });
  });

  group('FakeEngine test helpers', () {
    test('simulateError sets error state', () {
      final engine = FakeEngine();
      engine.simulateError('test error');
      expect(engine.state.value, MediaState.error);
      expect(engine.lastError.value?.message, 'test error');
      engine.dispose();
    });

    test('simulateCompleted sets completed state', () async {
      final engine = FakeEngine();
      await engine.open('test.mp4');
      engine.play(); // opening → playing
      engine.simulateCompleted(); // playing → completed
      expect(engine.state.value, MediaState.completed);
      engine.dispose();
    });

    test('simulateBuffering sets buffering flag', () {
      final engine = FakeEngine();
      engine.simulateBuffering(true);
      expect(engine.isBuffering.value, isTrue);

      engine.simulateBuffering(false);
      expect(engine.isBuffering.value, isFalse);
      engine.dispose();
    });

    test('configureMedia sets duration', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 120000);
      await engine.open('test.mp4');
      expect(engine.duration.value, 120000);
      engine.dispose();
    });

    test('failNextOpenWith triggers error on next open', () async {
      final engine = FakeEngine();
      engine.failNextOpenWith = 'simulated failure';
      await engine.open('bad.mp4');
      expect(engine.state.value, MediaState.error);
      expect(engine.lastError.value?.message, 'simulated failure');
      engine.dispose();
    });

    test('methods are no-op after dispose', () {
      final engine = FakeEngine();
      engine.dispose();
      // Should not throw
      engine.play();
      engine.pause();
      engine.stop();
      engine.setVolume(0.5);
      engine.setMute(true);
      engine.togglePlayPause();
      engine.setPlaybackRate(2.0);
      engine.setVideoEffect(VideoEffectType.brightness, 0.5);
      engine.rotate(90);
      engine.setAspectRatio(16 / 9);
      engine.setDeinterlace(true);
      engine.setD3d11SyncEnabled(true);
      engine.setHardwareDecoding(false);
      engine.setExternalSubtitle('test.srt');
      engine.setSubtitleDelay(500);
    });
  });
}
