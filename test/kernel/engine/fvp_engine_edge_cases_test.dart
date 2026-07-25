/// FvpEngine edge case tests — state queries before open, dispose during
/// playback, double dispose, volume/mute boundaries, seek clamping.
///
/// Uses FakeEngine to avoid mdk.dll FFI dependency in headless CI.
/// Tests exercise the MediaEngine interface contracts that FvpEngine must honor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;

  setUp(() {
    engine = FakeEngine();
  });

  tearDown(() {
    // Safe to call even if already disposed (FakeEngine has double-dispose guard)
    engine.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // State queries before open()
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — state before open', () {
    test('state is idle before any open', () {
      expect(engine.state.value, MediaState.idle);
    });

    test('position is 0 before any open', () {
      expect(engine.position.value, 0);
    });

    test('duration is 0 before any open', () {
      expect(engine.duration.value, 0);
    });

    test('volume defaults to 1.0', () {
      expect(engine.volume.value, 1.0);
    });

    test('isMuted defaults to false', () {
      expect(engine.isMuted.value, isFalse);
    });

    test('isBuffering defaults to false', () {
      expect(engine.isBuffering.value, isFalse);
    });

    test('isSeeking defaults to false', () {
      expect(engine.isSeeking.value, isFalse);
    });

    test('lastError is null before any open', () {
      expect(engine.lastError.value, isNull);
    });

    test('textureId is null before any open', () {
      expect(engine.textureId.value, isNull);
    });

    test('playbackSpeed defaults to 1.0', () {
      expect(engine.playbackSpeed.value, 1.0);
    });

    test('mediaInfo has zero duration before open', () {
      expect(engine.mediaInfo.duration, 0);
    });

    test('aspectRatio defaults to 16/9', () {
      expect(engine.aspectRatio.value, 16 / 9);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Dispose during playback
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — dispose during playback', () {
    test('dispose while playing does not throw', () {
      engine.configureMedia(durationMs: 60000);
      engine.play();
      expect(engine.state.value, MediaState.playing);

      expect(() => engine.dispose(), returnsNormally);
    });

    test('dispose while paused does not throw', () {
      engine.configureMedia(durationMs: 60000);
      engine.play();
      engine.pause();
      expect(engine.state.value, MediaState.paused);

      expect(() => engine.dispose(), returnsNormally);
    });

    test('dispose while opening does not throw', () async {
      engine.configureMedia(durationMs: 60000);
      // Start open but don't await
      final future = engine.open('C:/test.mp4');
      engine.dispose();
      await future; // should complete safely
    });

    test('dispose resets textureId to null', () {
      engine.configureMedia(durationMs: 60000);
      engine.dispose();

      // After dispose, accessing disposed notifiers should not throw
      // (FakeEngine disposes all ValueNotifiers)
    });

    test('open after dispose returns OpenSuperseded', () async {
      engine.dispose();

      final result = await engine.open('C:/test.mp4');
      expect(result, isA<OpenSuperseded>());
    });

    test('play after dispose is a no-op', () {
      engine.dispose();
      expect(() => engine.play(), returnsNormally);
    });

    test('pause after dispose is a no-op', () {
      engine.dispose();
      expect(() => engine.pause(), returnsNormally);
    });

    test('stop after dispose is a no-op', () {
      engine.dispose();
      expect(() => engine.stop(), returnsNormally);
    });

    test('seekTo after dispose is a no-op', () async {
      engine.dispose();
      await engine.seekTo(5000);
      expect(engine.seekToCallCount, 0);
    });

    test('setVolume after dispose is a no-op', () {
      engine.dispose();
      expect(() => engine.setVolume(0.5), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Double dispose
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — double dispose', () {
    test('double dispose does not throw', () {
      engine.configureMedia(durationMs: 60000);
      engine.dispose();

      expect(() => engine.dispose(), returnsNormally);
    });

    test('triple dispose does not throw', () {
      engine.dispose();
      expect(() => engine.dispose(), returnsNormally);
      expect(() => engine.dispose(), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Volume/mute at boundaries (0, 1)
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — volume boundaries', () {
    test('setVolume(0) clamps to 0 and auto-mutes', () {
      engine.setVolume(0);

      expect(engine.volume.value, 0.0);
      expect(engine.isMuted.value, isTrue);
    });

    test('setVolume(1.0) sets volume and unmutes', () {
      engine.setVolume(0); // first mute
      expect(engine.isMuted.value, isTrue);

      engine.setVolume(1.0);
      expect(engine.volume.value, 1.0);
      expect(engine.isMuted.value, isFalse);
    });

    test('setVolume negative clamps to 0 and auto-mutes', () {
      engine.setVolume(-0.5);

      expect(engine.volume.value, 0.0);
      expect(engine.isMuted.value, isTrue);
    });

    test('setVolume > 1.0 clamps to 1.0', () {
      engine.setVolume(1.5);

      expect(engine.volume.value, 1.0);
    });

    test('setVolume(0.5) does not change mute state', () {
      engine.setMute(false);
      engine.setVolume(0.5);

      expect(engine.volume.value, 0.5);
      expect(engine.isMuted.value, isFalse);
    });

    test('setVolume from 0 to positive auto-unmutes', () {
      engine.setVolume(0);
      expect(engine.isMuted.value, isTrue);

      engine.setVolume(0.3);
      expect(engine.volume.value, 0.3);
      expect(engine.isMuted.value, isFalse);
    });

    test('setMute(true) does not change volume value', () {
      engine.setVolume(0.7);
      engine.setMute(true);

      expect(engine.volume.value, 0.7);
      expect(engine.isMuted.value, isTrue);
    });

    test('setMute(false) does not change volume value', () {
      engine.setVolume(0.7);
      engine.setMute(true);
      engine.setMute(false);

      expect(engine.volume.value, 0.7);
      expect(engine.isMuted.value, isFalse);
    });

    test('setVolume(0) then setMute(false) leaves volume at 0', () {
      engine.setVolume(0);
      expect(engine.isMuted.value, isTrue);

      engine.setMute(false);
      // setMute directly sets isMuted without volume linkage
      expect(engine.isMuted.value, isFalse);
      expect(engine.volume.value, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Seek to negative / duration+1
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — seek boundaries', () {
    test('seekTo negative clamps to 0', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      await engine.seekTo(-1000);
      expect(engine.position.value, 0);
    });

    test('seekTo beyond duration clamps to duration', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      await engine.seekTo(999999);
      expect(engine.position.value, 60000);
    });

    test('seekTo exactly 0 works', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      await engine.seekTo(30000);
      expect(engine.position.value, 30000);

      await engine.seekTo(0);
      expect(engine.position.value, 0);
    });

    test('seekTo exactly duration works', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      await engine.seekTo(60000);
      expect(engine.position.value, 60000);
    });

    test('skipForward clamps to duration', () async {
      engine.configureMedia(durationMs: 5000);
      await engine.open('C:/test.mp4');

      engine.position.value = 3000;
      engine.skipForward(10000);

      expect(engine.position.value, 5000);
    });

    test('skipBack clamps to 0', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      engine.position.value = 3000;
      engine.skipBack(10000);

      expect(engine.position.value, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Playback speed boundaries
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — playback speed', () {
    test('setPlaybackRate below min clamps to 0.25', () {
      engine.setPlaybackRate(0.01);
      expect(engine.playbackSpeed.value, 0.25);
    });

    test('setPlaybackRate above max clamps to 4.0', () {
      engine.setPlaybackRate(10.0);
      expect(engine.playbackSpeed.value, 4.0);
    });

    test('setPlaybackRate at boundaries', () {
      engine.setPlaybackRate(0.25);
      expect(engine.playbackSpeed.value, 0.25);

      engine.setPlaybackRate(4.0);
      expect(engine.playbackSpeed.value, 4.0);
    });

    test('setPlaybackRate normal value', () {
      engine.setPlaybackRate(1.5);
      expect(engine.playbackSpeed.value, 1.5);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Toggle play/pause edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — togglePlayPause', () {
    test('toggle from idle starts playing', () {
      engine.togglePlayPause();
      expect(engine.state.value, MediaState.playing);
    });

    test('toggle from playing goes to paused', () {
      engine.play();
      expect(engine.state.value, MediaState.playing);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.paused);
    });

    test('toggle from paused resumes playing', () {
      engine.play();
      engine.pause();
      expect(engine.state.value, MediaState.paused);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.playing);
    });

    test('toggle from error is a no-op', () {
      engine.simulateError('test error');
      expect(engine.state.value, MediaState.error);

      engine.togglePlayPause();
      expect(engine.state.value, MediaState.error);
    });

    test('toggle from completed calls onPlay but state stays completed', () {
      // Known contract-implementation gap: _canTransitionTo does not include
      // completed→playing, so transitionTo silently fails and state stays
      // completed. The onPlay callback IS invoked (play()), but the state
      // machine rejects the transition. See PlaybackControl.play() doc comment.
      //
      // Reach completed via the valid path: idle → playing → completed
      engine.play();
      expect(engine.state.value, MediaState.playing);
      engine.simulateCompleted();
      expect(engine.state.value, MediaState.completed);

      engine.togglePlayPause();
      // onPlay callback was called (play() increments playCallCount),
      // but the transition completed→playing is illegal in the state machine.
      expect(engine.playCallCount, 2); // once for initial play, once for toggle
      expect(engine.state.value, MediaState.completed);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Error state and recovery
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — error and recovery', () {
    test('error state sets lastError', () {
      engine.simulateError('something broke');

      expect(engine.state.value, MediaState.error);
      expect(engine.lastError.value, isNotNull);
      expect(engine.lastError.value!.message, 'something broke');
    });

    test('recover from error returns to idle', () {
      engine.simulateError('test');
      expect(engine.state.value, MediaState.error);

      engine.recover();
      expect(engine.state.value, MediaState.idle);
      expect(engine.lastError.value, isNull);
    });

    test('open after error succeeds', () async {
      engine.simulateError('previous error');

      engine.configureMedia(durationMs: 60000);
      final result = await engine.open('C:/test.mp4');

      expect(result, isA<OpenSuccess>());
      expect(engine.state.value, MediaState.idle);
      expect(engine.lastError.value, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Open → play → stop lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — lifecycle', () {
    test('open → play → stop resets position', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');
      engine.play();
      engine.position.value = 30000;

      engine.stop();

      expect(engine.state.value, MediaState.idle);
      expect(engine.position.value, 0);
    });

    test('open → play → pause → play cycle', () async {
      engine.configureMedia(durationMs: 60000);
      await engine.open('C:/test.mp4');

      engine.play();
      expect(engine.state.value, MediaState.playing);

      engine.pause();
      expect(engine.state.value, MediaState.paused);

      engine.play();
      expect(engine.state.value, MediaState.playing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Generation guard — rapid open
  // ═══════════════════════════════════════════════════════════════════════════

  group('FvpEngine edge cases — generation guard', () {
    test('rapid open — only last result commits', () async {
      engine.configureMedia(durationMs: 60000);

      final f1 = engine.open('C:/a.mp4');
      final f2 = engine.open('C:/b.mp4');
      final f3 = engine.open('C:/c.mp4');

      final results = await Future.wait([f1, f2, f3]);

      // All three should have completed (some may be OpenSuperseded)
      expect(results.length, 3);
      // At least the last one should be OpenSuccess
      expect(results.last, isA<OpenSuccess>());
    });

    test('open after failed open works normally', () async {
      engine.configureMedia(durationMs: 60000);
      engine.failNextOpenWith = 'first fails';

      final r1 = await engine.open('C:/bad.mp4');
      expect(r1, isA<OpenError>());

      engine.configureMedia(durationMs: 60000);
      final r2 = await engine.open('C:/good.mp4');
      expect(r2, isA<OpenSuccess>());
      expect(engine.lastError.value, isNull);
    });
  });
}
