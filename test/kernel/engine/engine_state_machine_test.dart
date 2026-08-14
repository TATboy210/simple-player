import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';

/// EngineStateMachine 精简后的测试 — 验证 setter 语义 + generation 守卫.
///
/// 状态机瘦身(向后兼容方案)后的契约:
/// - [transitionTo] 是带 generation 检查的 setter,不校验合法性矩阵.
///   合法性由调用方本地 guard 负责(见 MediaKitEngine.play/pause 等).
/// - generation 过期 → 拒绝写入 + KernelLogger.warn,state 不变.
/// - 已删除: TransitionResult 返回值、合法性矩阵、lifecyclePhase、recover().
void main() {
  // 初始化 KernelLoggerImpl — 测试环境使用 NullSink(无输出).
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
    });

    // transitionTo 是无条件 setter — 不再校验合法性矩阵.
    // 合法性由调用方本地 guard 负责,状态机只管写入 + generation 守卫.
    group('transitionTo — setter writes target state', () {
      test('idle → opening writes state', () {
        machine.transitionTo(MediaState.opening, 'test');
        expect(machine.state.value, MediaState.opening);
      });

      test('idle → error writes state', () {
        machine.transitionTo(MediaState.error, 'test');
        expect(machine.state.value, MediaState.error);
      });

      test('opening → playing writes state', () {
        machine.state.value = MediaState.opening;
        machine.transitionTo(MediaState.playing, 'test');
        expect(machine.state.value, MediaState.playing);
      });

      test('playing → paused writes state', () {
        machine.state.value = MediaState.playing;
        machine.transitionTo(MediaState.paused, 'test');
        expect(machine.state.value, MediaState.paused);
      });

      test('playing → completed writes state', () {
        machine.state.value = MediaState.playing;
        machine.transitionTo(MediaState.completed, 'test');
        expect(machine.state.value, MediaState.completed);
      });

      test('completed → playing writes state (replay from end)', () {
        machine.state.value = MediaState.completed;
        machine.transitionTo(MediaState.playing, 'test');
        expect(machine.state.value, MediaState.playing);
      });

      test('error → idle writes state', () {
        machine.state.value = MediaState.error;
        machine.transitionTo(MediaState.idle, 'test');
        expect(machine.state.value, MediaState.idle);
      });

      // 旧设计会拒绝 same-state 转换;新设计作为 setter 无条件写入
      // (ValueNotifier 对同值不触发通知,但语义上允许).
      test('same-state transition is allowed (setter semantics)', () {
        machine.transitionTo(MediaState.idle, 'test');
        expect(machine.state.value, MediaState.idle);
      });
    });

    group('togglePlayPause', () {
      test('idle state calls onPlay callback', () {
        machine.togglePlayPause();
        expect(playCalls, ['play']);
        expect(pauseCalls, isEmpty);
        // state unchanged — callback 负责实际 play + 状态转换.
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
        machine.transitionTo(MediaState.opening, 'test');
        expect(machine.state.value, MediaState.opening);
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

      test('isCurrent returns true for matching generation', () {
        final gen = machine.nextGeneration();
        expect(machine.isCurrent(gen), true);
      });

      test('isCurrent returns false for stale generation', () {
        machine.nextGeneration(); // gen 1
        final staleGen = machine.nextGeneration(); // gen 2
        machine.nextGeneration(); // gen 3 — staleGen outdated
        expect(machine.isCurrent(staleGen), false);
      });

      test('transitionTo with matching generation writes state', () {
        final gen = machine.nextGeneration();
        machine.state.value = MediaState.opening;
        machine.transitionTo(MediaState.playing, 'test', generation: gen);
        expect(machine.state.value, MediaState.playing);
      });

      test('transitionTo with stale generation rejects write', () {
        machine.nextGeneration(); // gen 1
        final staleGen = machine.nextGeneration(); // gen 2
        machine.nextGeneration(); // gen 3 — staleGen outdated
        machine.state.value = MediaState.opening;
        machine.transitionTo(MediaState.playing, 'test', generation: staleGen);
        // stale 被拒绝,state 不变.
        expect(machine.state.value, MediaState.opening);
      });

      test('transitionTo without generation skips generation check', () {
        machine.nextGeneration();
        machine.nextGeneration();
        machine.state.value = MediaState.opening;
        machine.transitionTo(MediaState.playing, 'test');
        expect(machine.state.value, MediaState.playing);
      });
    });

    group('double-dispose', () {
      test('second dispose is safe no-op', () {
        final m = EngineStateMachine();
        m.state.value = MediaState.opening;
        m.dispose();
        expect(() => m.dispose(), returnsNormally);
      });
    });

    group('dispose', () {
      test('dispose completes without error', () {
        final m = EngineStateMachine();
        m.state.value = MediaState.opening;
        m.isSeeking.value = true;
        m.isBuffering.value = true;
        expect(() => m.dispose(), returnsNormally);
      });
    });
  });
}
