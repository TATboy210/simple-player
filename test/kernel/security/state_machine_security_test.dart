// State machine security tests — validates state corruption detection,
// callback safety, generation guard, and numeric invariants.
//
// 状态机瘦身后(向后兼容方案):
// - transitionTo 不再校验合法性矩阵 → 删除 illegal transitions 组.
// - 删除 lifecyclePhase / recover() → 删除相关用例.
// - 保留: generation 守卫、dispose 安全、FakeEngine 不变量、回调安全.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';

import '../../helpers/fake_engine.dart';

void main() {
  // Initialize KernelLoggerImpl — tests use NullSink (no output).
  KernelLoggerImpl.init();

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Post-dispose safety — double-dispose and post-dispose no-ops.
  // ─────────────────────────────────────────────────────────────────────────
  group('Post-dispose safety', () {
    test('double dispose is safe no-op', () {
      final m = EngineStateMachine();
      m.state.value = MediaState.playing;
      m.dispose();
      expect(() => m.dispose(), returnsNormally);
    });

    test('FakeEngine operations after dispose are no-ops', () {
      final engine = FakeEngine();
      engine.dispose();

      // All control methods should be no-ops (guarded by _disposed).
      expect(() => engine.play(), returnsNormally);
      expect(() => engine.pause(), returnsNormally);
      expect(() => engine.stop(), returnsNormally);
      expect(() => engine.setVolume(0.5), returnsNormally);
      expect(() => engine.setMute(true), returnsNormally);
      expect(() => engine.setPlaybackRate(2.0), returnsNormally);
      expect(() => engine.togglePlayPause(), returnsNormally);
    });

    test('FakeEngine double dispose is safe', () {
      final engine = FakeEngine();
      engine.dispose();
      expect(() => engine.dispose(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. State corruption detection — failed open + supersede do not corrupt.
  // ─────────────────────────────────────────────────────────────────────────
  group('State corruption detection', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test(
      'after failed open, state returns to error (not stuck in opening)',
      () async {
        engine.failNextOpenWith = 'corrupt file';
        final result = await engine.open('/bad/file.mp4');

        expect(result, isA<OpenError>());
        expect(engine.state.value, MediaState.error);
        // State is NOT stuck in `opening` — it correctly transitioned to `error`.
      },
    );

    test('rapid open + supersede does not corrupt state', () async {
      engine.configureMedia(durationMs: 1000);

      // Fire two opens — second supersedes first.
      final future1 = engine.open('/first.mp4');
      final future2 = engine.open('/second.mp4');

      await Future.wait([future1, future2]);

      // State should be clean (idle after successful open).
      expect(engine.state.value, MediaState.idle);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Callback ordering and safety
  // ─────────────────────────────────────────────────────────────────────────
  group('Callback ordering and safety', () {
    test('ValueNotifier listeners fire in subscription order', () {
      final notifier = ValueNotifier<int>(0);
      final log = <int>[];

      notifier.addListener(() => log.add(notifier.value));
      notifier.value = 1;
      notifier.value = 2;
      notifier.value = 3;

      expect(log, [1, 2, 3]);
      notifier.dispose();
    });

    test('no callbacks fire after ValueNotifier.dispose()', () {
      final notifier = ValueNotifier<int>(0);
      var callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.value = 1;
      expect(callCount, 1);

      notifier.dispose();
      // After dispose, existing listeners are removed — verify no crash.
      expect(callCount, 1);
    });

    test('state change listeners see consistent state values', () {
      final m = EngineStateMachine();
      final observed = <MediaState>[];

      m.state.addListener(() => observed.add(m.state.value));

      // Walk through a valid path: idle -> opening -> playing -> paused.
      m.transitionTo(MediaState.opening, 'test');
      m.transitionTo(MediaState.playing, 'test');
      m.transitionTo(MediaState.paused, 'test');

      expect(observed, [
        MediaState.opening,
        MediaState.playing,
        MediaState.paused,
      ]);

      m.dispose();
    });

    test('stale generation transition does NOT fire state listener', () {
      final m = EngineStateMachine();
      var fireCount = 0;
      m.state.addListener(() => fireCount++);

      final gen1 = m.nextGeneration(); // 1
      m.nextGeneration(); // 2 — gen1 is now stale

      m.state.value = MediaState.opening;
      fireCount = 0; // reset after direct assignment

      m.transitionTo(MediaState.playing, 'test', generation: gen1);

      expect(fireCount, 0, reason: 'Stale generation must not fire listener');
      expect(m.state.value, MediaState.opening);

      m.dispose();
    });

    test('togglePlayPause callbacks respect state boundaries', () {
      final playCalls = <String>[];
      final pauseCalls = <String>[];
      final m = EngineStateMachine(
        onPlay: () => playCalls.add('play'),
        onPause: () => pauseCalls.add('pause'),
      );

      // idle -> play callback.
      m.togglePlayPause();
      expect(playCalls.length, 1);
      expect(pauseCalls.length, 0);

      // playing -> pause callback.
      m.state.value = MediaState.playing;
      m.togglePlayPause();
      expect(playCalls.length, 1);
      expect(pauseCalls.length, 1);

      // opening -> no callback.
      m.state.value = MediaState.opening;
      m.togglePlayPause();
      expect(playCalls.length, 1);
      expect(pauseCalls.length, 1);

      // error -> no callback.
      m.state.value = MediaState.error;
      m.togglePlayPause();
      expect(playCalls.length, 1);
      expect(pauseCalls.length, 1);

      m.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Invariant checks — position, volume, mute consistency.
  //    (与状态机瘦身无关 — 验证 FakeEngine clamp 逻辑.)
  // ─────────────────────────────────────────────────────────────────────────
  group('Invariant checks', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);
    });

    tearDown(() {
      engine.dispose();
    });

    group('position invariants', () {
      test('position starts at 0', () {
        expect(engine.position.value, 0);
      });

      test('position is always >= 0 after open', () async {
        await engine.open('/test.mp4');
        expect(engine.position.value, greaterThanOrEqualTo(0));
      });

      test('position is always <= duration after seekTo', () async {
        await engine.open('/test.mp4');
        engine.duration.value = 60000;

        // Seek beyond duration — FakeEngine clamps via clamp(0, duration).
        await engine.seekTo(999999);
        expect(engine.position.value, lessThanOrEqualTo(engine.duration.value));
      });

      test('seekTo negative value clamps to 0', () async {
        await engine.open('/test.mp4');
        engine.duration.value = 60000;

        await engine.seekTo(-500);
        expect(engine.position.value, 0);
      });

      test('position resets to 0 on stop', () async {
        await engine.open('/test.mp4');
        engine.position.value = 30000;

        await engine.stop();
        expect(engine.position.value, 0);
      });
    });

    group('volume invariants', () {
      test('volume starts at 1.0', () {
        expect(engine.volume.value, 1.0);
      });

      test('volume is always >= 0 after setVolume', () {
        engine.setVolume(-0.5);
        expect(engine.volume.value, greaterThanOrEqualTo(0.0));
      });

      test('volume is always <= 1.0 after setVolume', () {
        engine.setVolume(2.0);
        expect(engine.volume.value, lessThanOrEqualTo(1.0));
      });

      test('setVolume(0) sets isMuted to true', () {
        engine.setVolume(0);
        expect(engine.volume.value, 0.0);
        expect(engine.isMuted.value, true);
      });

      test('setVolume(positive) clears isMuted', () {
        engine.setMute(true);
        expect(engine.isMuted.value, true);

        engine.setVolume(0.5);
        expect(engine.isMuted.value, false);
      });

      test('volume boundary: exactly 0.0', () {
        engine.setVolume(0.0);
        expect(engine.volume.value, 0.0);
        expect(engine.isMuted.value, true);
      });

      test('volume boundary: exactly 1.0', () {
        engine.setVolume(1.0);
        expect(engine.volume.value, 1.0);
        expect(engine.isMuted.value, false);
      });

      test('volume boundary: extreme negative clamps to 0', () {
        engine.setVolume(-999.0);
        expect(engine.volume.value, 0.0);
      });

      test('volume boundary: extreme positive clamps to 1', () {
        engine.setVolume(999.0);
        expect(engine.volume.value, 1.0);
      });
    });

    group('isMuted consistency', () {
      test('setMute(true) does not change volume value', () {
        engine.setVolume(0.7);
        engine.setMute(true);
        expect(engine.volume.value, 0.7);
        expect(engine.isMuted.value, true);
      });

      test('setMute(false) does not change volume value', () {
        engine.setVolume(0.7);
        engine.setMute(true);
        engine.setMute(false);
        expect(engine.volume.value, 0.7);
        expect(engine.isMuted.value, false);
      });

      test('mute state survives play/pause cycle', () {
        engine.setMute(true);
        engine.play();
        expect(engine.isMuted.value, true);
        engine.pause();
        expect(engine.isMuted.value, true);
      });
    });

    group('playbackSpeed invariant', () {
      test('playbackSpeed starts at 1.0', () {
        expect(engine.playbackSpeed.value, 1.0);
      });

      test('setPlaybackRate clamps to valid range', () {
        engine.setPlaybackRate(0.01);
        expect(engine.playbackSpeed.value, greaterThanOrEqualTo(0.25));

        engine.setPlaybackRate(100.0);
        expect(engine.playbackSpeed.value, lessThanOrEqualTo(4.0));
      });

      test('setPlaybackRate boundary: exactly 0.25', () {
        engine.setPlaybackRate(0.25);
        expect(engine.playbackSpeed.value, 0.25);
      });

      test('setPlaybackRate boundary: exactly 4.0', () {
        engine.setPlaybackRate(4.0);
        expect(engine.playbackSpeed.value, 4.0);
      });
    });

    group('state machine invariants after rapid operations', () {
      test('rapid play/pause does not corrupt state', () {
        engine.open('/test.mp4');

        // Rapid fire.
        for (var i = 0; i < 20; i++) {
          if (engine.state.value == MediaState.playing) {
            engine.pause();
          } else {
            engine.play();
          }
        }

        // State must be either playing or paused — never stuck in between.
        expect(
          engine.state.value,
          anyOf(MediaState.playing, MediaState.paused),
        );
      });

      test('rapid volume changes stay within bounds', () {
        for (var i = 0; i < 100; i++) {
          engine.setVolume(i * 0.02 - 1.0); // -1.0 to 1.0
        }
        expect(engine.volume.value, inInclusiveRange(0.0, 1.0));
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Generation guard — stale callback protection.
  // ─────────────────────────────────────────────────────────────────────────
  group('Generation guard — stale callback protection', () {
    test('stale generation rejects transition and preserves state', () {
      final m = EngineStateMachine();

      final gen1 = m.nextGeneration(); // 1
      m.nextGeneration(); // 2 — gen1 is now stale

      m.state.value = MediaState.opening;
      m.transitionTo(MediaState.playing, 'test', generation: gen1);

      // Stale 被拒绝,state 不变.
      expect(m.state.value, MediaState.opening);

      m.dispose();
    });

    test('current generation accepts transition', () {
      final m = EngineStateMachine();
      final gen = m.nextGeneration();

      m.state.value = MediaState.opening;
      m.transitionTo(MediaState.playing, 'test', generation: gen);

      expect(m.state.value, MediaState.playing);

      m.dispose();
    });

    test('transition without generation skips generation check', () {
      final m = EngineStateMachine();
      m.nextGeneration(); // bump generation
      m.nextGeneration(); // bump again

      m.state.value = MediaState.opening;
      // No generation param — should succeed regardless of generation mismatch.
      m.transitionTo(MediaState.playing, 'test');

      expect(m.state.value, MediaState.playing);

      m.dispose();
    });

    test('stale generation after dispose-time bump is rejected', () {
      final m = EngineStateMachine();
      final gen = m.nextGeneration();

      // Simulate engine dispose: bump generation, gen is now stale.
      m.nextGeneration();

      m.state.value = MediaState.opening;
      m.transitionTo(MediaState.playing, 'test', generation: gen);

      expect(m.state.value, MediaState.opening);

      m.dispose();
    });
  });
}
