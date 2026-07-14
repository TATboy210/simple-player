/// EngineStateMachine 单元测试
///
/// 覆盖 SVC-02 需求: 独立状态机的转换守卫、togglePlayPause、标志位管理。
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';

void main() {
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
    });

    group('transitionTo — legal transitions', () {
      test('idle → opening returns true', () {
        expect(machine.transitionTo(MediaState.opening, 'test'), true);
        expect(machine.state.value, MediaState.opening);
      });

      test('idle → error returns true', () {
        expect(machine.transitionTo(MediaState.error, 'test'), true);
        expect(machine.state.value, MediaState.error);
      });

      test('opening → playing returns true', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.playing, 'test'), true);
        expect(machine.state.value, MediaState.playing);
      });

      test('opening → idle returns true', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.idle, 'test'), true);
        expect(machine.state.value, MediaState.idle);
      });

      test('opening → error returns true', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.error, 'test'), true);
        expect(machine.state.value, MediaState.error);
      });

      test('playing → paused returns true', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.paused, 'test'), true);
        expect(machine.state.value, MediaState.paused);
      });

      test('playing → completed returns true', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.completed, 'test'), true);
        expect(machine.state.value, MediaState.completed);
      });

      test('playing → error returns true', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.error, 'test'), true);
        expect(machine.state.value, MediaState.error);
      });

      test('playing → idle returns true', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.idle, 'test'), true);
        expect(machine.state.value, MediaState.idle);
      });

      test('paused → playing returns true', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.playing, 'test'), true);
        expect(machine.state.value, MediaState.playing);
      });

      test('paused → error returns true', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.error, 'test'), true);
        expect(machine.state.value, MediaState.error);
      });

      test('paused → idle returns true', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.idle, 'test'), true);
        expect(machine.state.value, MediaState.idle);
      });

      test('completed → opening returns true', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.opening, 'test'), true);
        expect(machine.state.value, MediaState.opening);
      });

      test('completed → error returns true', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.error, 'test'), true);
        expect(machine.state.value, MediaState.error);
      });

      test('completed → idle returns true', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.idle, 'test'), true);
        expect(machine.state.value, MediaState.idle);
      });

      test('error → opening returns true', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.opening, 'test'), true);
        expect(machine.state.value, MediaState.opening);
      });

      test('error → idle returns true', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.idle, 'test'), true);
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('transitionTo — illegal transitions', () {
      test('idle → playing returns false and state unchanged', () {
        expect(machine.transitionTo(MediaState.playing, 'test'), false);
        expect(machine.state.value, MediaState.idle);
      });

      test('idle → paused returns false', () {
        expect(machine.transitionTo(MediaState.paused, 'test'), false);
        expect(machine.state.value, MediaState.idle);
      });

      test('idle → completed returns false', () {
        expect(machine.transitionTo(MediaState.completed, 'test'), false);
        expect(machine.state.value, MediaState.idle);
      });

      test('opening → paused returns false', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.paused, 'test'), false);
        expect(machine.state.value, MediaState.opening);
      });

      test('opening → completed returns false', () {
        machine.state.value = MediaState.opening;
        expect(machine.transitionTo(MediaState.completed, 'test'), false);
        expect(machine.state.value, MediaState.opening);
      });

      test('playing → opening returns false', () {
        machine.state.value = MediaState.playing;
        expect(machine.transitionTo(MediaState.opening, 'test'), false);
        expect(machine.state.value, MediaState.playing);
      });

      test('paused → opening returns false', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.opening, 'test'), false);
        expect(machine.state.value, MediaState.paused);
      });

      test('paused → completed returns false', () {
        machine.state.value = MediaState.paused;
        expect(machine.transitionTo(MediaState.completed, 'test'), false);
        expect(machine.state.value, MediaState.paused);
      });

      test('completed → playing returns false', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.playing, 'test'), false);
        expect(machine.state.value, MediaState.completed);
      });

      test('completed → paused returns false', () {
        machine.state.value = MediaState.completed;
        expect(machine.transitionTo(MediaState.paused, 'test'), false);
        expect(machine.state.value, MediaState.completed);
      });

      test('error → playing returns false', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.playing, 'test'), false);
        expect(machine.state.value, MediaState.error);
      });

      test('error → paused returns false', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.paused, 'test'), false);
        expect(machine.state.value, MediaState.error);
      });

      test('error → completed returns false', () {
        machine.state.value = MediaState.error;
        expect(machine.transitionTo(MediaState.completed, 'test'), false);
        expect(machine.state.value, MediaState.error);
      });

      test('same-state transition returns false', () {
        expect(machine.transitionTo(MediaState.idle, 'test'), false);
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
        expect(machine.transitionTo(MediaState.opening, 'test'), true);
        expect(machine.state.value, MediaState.opening);
        // flags still set
        expect(machine.isSeeking.value, true);
        expect(machine.isBuffering.value, true);
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
