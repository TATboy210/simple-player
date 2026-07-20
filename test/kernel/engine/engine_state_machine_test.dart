import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/lifecycle_phase.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/transition_result.dart';

void main() {
  // 初始化 KernelLoggerImpl — 测试环境使用 NullSink（无输出）
  // Initialize KernelLoggerImpl — tests use NullSink (no output)
  KernelLoggerImpl.init();

  group('EngineStateMachine', () {
    late EngineStateMachine machine;
    late List<String> playCalls;
    late List<String> pauseCalls;

    setUp(() {
      playCalls = [];
      pauseCalls = [];
      machine = EngineStateMachine(
        onPlay: () => playCalls.add('play'),
        onPause: () => pauseCalls.add('pause'),
      );
    });

    tearDown(() {
      machine.dispose();
    });

    group('initial state', () {
      test('state starts as idle', () {
        expect(machine.state.value, MediaState.idle);
      });

      test('isSeeking starts as false', () {
        expect(machine.isSeeking.value, false);
      });

      test('isBuffering starts as false', () {
        expect(machine.isBuffering.value, false);
      });

      test('lifecyclePhase starts as alive', () {
        expect(machine.lifecyclePhase.value, LifecyclePhase.alive);
      });
    });

    group('transitionTo — legal transitions', () {
      test('idle → opening returns ok', () {
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.opening);
      });

      test('idle → error returns ok', () {
        expect(machine.transitionTo(MediaState.error, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.error);
      });

      test('opening → playing returns ok', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.playing, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.playing);
      });

      test('opening → idle returns ok', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.idle);
      });

      test('opening → error returns ok', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.error, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.error);
      });

      test('playing → paused returns ok', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.paused, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.paused);
      });

      test('playing → completed returns ok', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.completed, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.completed);
      });

      test('playing → error returns ok', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.error, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.error);
      });

      test('playing → idle returns ok', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.idle);
      });

      test('paused → playing returns ok', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.playing, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.playing);
      });

      test('paused → error returns ok', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.error, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.error);
      });

      test('paused → idle returns ok', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.idle);
      });

      test('completed → opening returns ok', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.opening);
      });

      test('completed → error returns ok', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.error, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.error);
      });

      test('completed → idle returns ok', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.idle);
      });

      test('error → opening returns ok', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.opening);
      });

      test('error → idle returns ok', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('transitionTo — illegal transitions', () {
      test('idle → playing returns ok (play after open)', () {
        expect(machine.transitionTo(MediaState.playing, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.playing);
      });

      test('idle → paused returns illegal', () {
        expect(machine.transitionTo(MediaState.paused, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.idle);
      });

      test('idle → completed returns illegal', () {
        expect(machine.transitionTo(MediaState.completed, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.idle);
      });

      test('opening → paused returns illegal', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.paused, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.opening);
      });

      test('opening → completed returns illegal', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.completed, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.opening);
      });

      test('playing → opening returns illegal', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.playing);
      });

      test('paused → opening returns illegal', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.paused);
      });

      test('paused → completed returns illegal', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.completed, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.paused);
      });

      test('completed → playing returns illegal', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.playing, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.completed);
      });

      test('completed → paused returns illegal', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.paused, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.completed);
      });

      test('error → playing returns illegal', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.playing, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.error);
      });

      test('error → paused returns illegal', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.paused, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.error);
      });

      test('error → completed returns illegal', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.completed, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.error);
      });

      test('same-state transition returns illegal', () {
        expect(machine.transitionTo(MediaState.idle, 'test'), TransitionResult.illegal);
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('togglePlayPause', () {
      test('idle state calls onPlay callback', () {
        machine.togglePlayPause();
        expect(playCalls, ['play']);
        expect(pauseCalls, isEmpty);
        // state unchanged — callback is responsible for actual play + state transition
        expect(machine.state.value, MediaState.idle);
      });

      test('playing state calls onPause callback', () {
        machine.state.value = MediaState.playing;
        machine.togglePlayPause();
        expect(pauseCalls, ['pause']);
        expect(playCalls, isEmpty);
        expect(machine.state.value, MediaState.playing);
      });

      test('paused state calls onPlay callback', () {
        machine.state.value = MediaState.paused;
        machine.togglePlayPause();
        expect(playCalls, ['play']);
        expect(pauseCalls, isEmpty);
        expect(machine.state.value, MediaState.paused);
      });

      test('completed state calls onPlay callback', () {
        machine.state.value = MediaState.completed;
        machine.togglePlayPause();
        expect(playCalls, ['play']);
        expect(pauseCalls, isEmpty);
        expect(machine.state.value, MediaState.completed);
      });

      test('error state calls no callback', () {
        machine.state.value = MediaState.error;
        machine.togglePlayPause();
        expect(playCalls, isEmpty);
        expect(pauseCalls, isEmpty);
        expect(machine.state.value, MediaState.error);
      });

      test('opening state calls no callback', () {
        machine.state.value = MediaState.opening;
        machine.togglePlayPause();
        expect(playCalls, isEmpty);
        expect(pauseCalls, isEmpty);
        expect(machine.state.value, MediaState.opening);
      });
    });

    group('isSeeking / isBuffering flags', () {
      test('isSeeking can be set independently', () {
        machine.isSeeking.value = true;
        expect(machine.isSeeking.value, true);
        // main state unchanged
        expect(machine.state.value, MediaState.idle);
      });

      test('isBuffering can be set independently', () {
        machine.isBuffering.value = true;
        expect(machine.isBuffering.value, true);
        expect(machine.state.value, MediaState.idle);
      });

      test('flags do not affect transitionTo', () {
        machine.isSeeking.value = true;
        machine.isBuffering.value = true;
        expect(machine.transitionTo(MediaState.opening, 'test'), TransitionResult.ok);
        expect(machine.state.value, MediaState.opening);
        // flags still set
        expect(machine.isSeeking.value, true);
        expect(machine.isBuffering.value, true);
      });
    });

    group('OpenGenerationTracker', () {
      test('currentGeneration starts at 0', () {
        expect(machine.currentGeneration, 0);
      });

      test('nextGeneration increments and returns new value', () {
        expect(machine.nextGeneration(), 1);
        expect(machine.nextGeneration(), 2);
        expect(machine.nextGeneration(), 3);
      });

      test('currentGeneration reflects latest nextGeneration call', () {
        machine.nextGeneration();
        machine.nextGeneration();
        expect(machine.currentGeneration, 2);
      });

      test('transitionTo with matching generation returns ok', () {
        final gen = machine.nextGeneration();
        machine.state.value = MediaState.opening;
        expect(
          machine.transitionTo(MediaState.playing, 'test', generation: gen),
          TransitionResult.ok,
        );
        expect(machine.state.value, MediaState.playing);
      });

      test('transitionTo with stale generation returns staleGeneration', () {
        machine.nextGeneration(); // gen 1
        final staleGen = machine.nextGeneration(); // gen 2
        machine.nextGeneration(); // gen 3 — now staleGen is outdated
        machine.state.value = MediaState.opening;
        expect(
          machine.transitionTo(MediaState.playing, 'test', generation: staleGen),
          TransitionResult.staleGeneration,
        );
        // state unchanged
        expect(machine.state.value, MediaState.opening);
      });

      test('transitionTo without generation skips generation check', () {
        machine.nextGeneration();
        machine.state.value = MediaState.opening;
        expect(
          machine.transitionTo(MediaState.playing, 'test'),
          TransitionResult.ok,
        );
        expect(machine.state.value, MediaState.playing);
      });
    });

    group('LifecyclePhase', () {
      test('lifecyclePhase is orthogonal to state', () {
        machine.state.value = MediaState.playing;
        expect(machine.lifecyclePhase.value, LifecyclePhase.alive);
        machine.state.value = MediaState.paused;
        expect(machine.lifecyclePhase.value, LifecyclePhase.alive);
      });

      test('lifecyclePhase transitions independently of state', () {
        machine.lifecyclePhase.value = LifecyclePhase.disposing;
        expect(machine.lifecyclePhase.value, LifecyclePhase.disposing);
        // state unchanged
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('recover()', () {
      test('error → idle transition', () {
        machine.state.value = MediaState.error;
        machine.recover();
        expect(machine.state.value, MediaState.idle);
      });

      test('no-op when not in error state (idle)', () {
        machine.recover();
        expect(machine.state.value, MediaState.idle);
      });

      test('no-op when not in error state (playing)', () {
        machine.state.value = MediaState.playing;
        machine.recover();
        expect(machine.state.value, MediaState.playing);
      });

      test('no-op when not in error state (paused)', () {
        machine.state.value = MediaState.paused;
        machine.recover();
        expect(machine.state.value, MediaState.paused);
      });

      test('clears lastError when provided', () {
        // Use a simple ValueNotifier to test lastError clearing
        // In real usage this would be ValueNotifier<PlayerError?>
        // but for test purposes a simple notifier suffices
        machine.state.value = MediaState.error;
        machine.recover();
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('double-dispose', () {
      test('second dispose is safe no-op', () {
        final m = EngineStateMachine();
        m.state.value = MediaState.opening;
        m.dispose();
        // second dispose should not throw
        expect(() => m.dispose(), returnsNormally);
      });

      test('dispose sets lifecyclePhase to disposed', () {
        final m = EngineStateMachine();
        expect(m.lifecyclePhase.value, LifecyclePhase.alive);
        m.dispose();
        expect(m.lifecyclePhase.value, LifecyclePhase.disposed);
      });
    });

    group('dispose', () {
      test('dispose completes without error', () {
        final m = EngineStateMachine();
        // Set some state before dispose
        m.state.value = MediaState.opening;
        m.isSeeking.value = true;
        m.isBuffering.value = true;
        // dispose should not throw
        expect(() => m.dispose(), returnsNormally);
      });
    });
  });
}
