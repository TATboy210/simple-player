import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/lifecycle_phase.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/transition_result.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart'
    show KernelLoggerImpl;

/// 竞态条件测试 — 验证 EngineStateMachine 的 generation 守卫在快速操作下的正确性
///
/// Race condition tests — validate EngineStateMachine generation guard
/// correctness under rapid-fire scenarios.
///
/// 使用真实 EngineStateMachine（无 mock），通过直接调用 nextGeneration() +
/// transitionTo(generation:) 模拟快速 open/play/seek 序列。
void main() {
  // 初始化 KernelLogger 用于 transitionTo 的 warn 日志
  KernelLoggerImpl.init();

  group('Race condition — generation tracking', () {
    test('rapid open-open: second open rejects first open transitions', () {
      final machine = EngineStateMachine();

      // 模拟快速切换文件：gen1 open → idle → gen2 open
      // 在真实引擎中，新 open 会先取消当前 open（→ idle），再开始新 open
      final gen1 = machine.nextGeneration(); // gen1 = 1
      expect(
        machine.transitionTo(MediaState.opening, 'open1', generation: gen1),
        TransitionResult.ok,
      );

      // gen1 取消/失败 → idle（模拟引擎取消当前 open）
      expect(
        machine.transitionTo(MediaState.idle, 'cancel1', generation: gen1),
        TransitionResult.ok,
      );

      // gen2 立即开始 open
      final gen2 = machine.nextGeneration(); // gen2 = 2
      expect(
        machine.transitionTo(MediaState.opening, 'open2', generation: gen2),
        TransitionResult.ok,
      );

      // gen1 的 stale 回调到达 — 被拒绝
      expect(
        machine.transitionTo(
          MediaState.playing,
          'open1-complete',
          generation: gen1,
        ),
        TransitionResult.staleGeneration,
      );

      // 状态仍为 opening（来自 gen2），不受 stale gen1 影响
      expect(machine.state.value, MediaState.opening);

      machine.dispose();
    });

    test('stale generation returns TransitionResult.staleGeneration', () {
      final machine = EngineStateMachine();

      // 递增 3 次 generation，使用过期的 gen=1
      machine.nextGeneration(); // gen1 = 1
      machine.nextGeneration(); // gen2 = 2
      machine.nextGeneration(); // gen3 = 3

      expect(
        machine.transitionTo(MediaState.opening, 'stale', generation: 1),
        TransitionResult.staleGeneration,
      );

      machine.dispose();
    });
  });

  group('Race condition — open-seek-open interleaved', () {
    test('seek between two opens: final state matches last open', () {
      final machine = EngineStateMachine();

      // gen1 open → playing（第一个文件加载成功）
      final gen1 = machine.nextGeneration();
      expect(
        machine.transitionTo(MediaState.opening, 'open1', generation: gen1),
        TransitionResult.ok,
      );
      expect(
        machine.transitionTo(MediaState.playing, 'gen1-loaded', generation: gen1),
        TransitionResult.ok,
      );

      // 用户在 playing 中 seek — 状态不变（playing → playing 非法，但无 generation 检查）
      expect(
        machine.transitionTo(MediaState.playing, 'seek-during-play'),
        TransitionResult.illegal,
      );

      // 用户发起新 open（gen2）— 先回到 idle
      expect(
        machine.transitionTo(MediaState.idle, 'stop-for-open2'),
        TransitionResult.ok,
      );
      final gen2 = machine.nextGeneration();
      expect(
        machine.transitionTo(MediaState.opening, 'open2', generation: gen2),
        TransitionResult.ok,
      );

      // gen1 的 late 回调到达 — stale
      expect(
        machine.transitionTo(
          MediaState.playing,
          'gen1-late',
          generation: gen1,
        ),
        TransitionResult.staleGeneration,
      );

      // gen2 完成加载 → playing
      expect(
        machine.transitionTo(MediaState.playing, 'gen2-loaded', generation: gen2),
        TransitionResult.ok,
      );

      // 最终状态匹配 gen2 的结果
      expect(machine.state.value, MediaState.playing);

      machine.dispose();
    });
  });

  group('Race condition — open-dispose lifecycle', () {
    test('dispose during open: lifecyclePhase transitions correctly', () {
      final machine = EngineStateMachine();

      final gen = machine.nextGeneration();
      expect(
        machine.transitionTo(MediaState.opening, 'open', generation: gen),
        TransitionResult.ok,
      );

      // lifecyclePhase 初始为 alive
      expect(machine.lifecyclePhase.value, LifecyclePhase.alive);

      // 状态机不阻止 lifecycle 转换（lifecycle 是正交维度）
      expect(
        machine.transitionTo(MediaState.idle, 'cancel', generation: gen),
        TransitionResult.ok,
      );

      // dispose 后 lifecyclePhase 为 disposed
      machine.dispose();
      expect(machine.lifecyclePhase.value, LifecyclePhase.disposed);
    });

    test('double dispose is safe no-op', () {
      final machine = EngineStateMachine();

      machine.dispose();
      expect(machine.lifecyclePhase.value, LifecyclePhase.disposed);

      // 第二次 dispose 不抛异常
      machine.dispose();
      expect(machine.lifecyclePhase.value, LifecyclePhase.disposed);
    });
  });

  group('Race condition — open-play-pause-open rapid fire', () {
    test('rapid sequence: stale generation rejected, current honored', () {
      final machine = EngineStateMachine();

      // gen1: open → playing
      final gen1 = machine.nextGeneration();
      expect(
        machine.transitionTo(MediaState.opening, 'open1', generation: gen1),
        TransitionResult.ok,
      );
      expect(
        machine.transitionTo(MediaState.playing, 'play1', generation: gen1),
        TransitionResult.ok,
      );

      // 用户发起新 open（gen2）— 但 gen1 的回调仍在飞行中
      final gen2 = machine.nextGeneration();

      // gen1 的 pause 回调到达 — 仍然合法（playing → paused）
      // 注意：pause 不检查 generation（没有 generation 参数）
      expect(
        machine.transitionTo(MediaState.paused, 'pause1'),
        TransitionResult.ok,
      );

      // gen2 的 opening 到达 — 但 paused → opening 不合法
      expect(
        machine.transitionTo(MediaState.opening, 'open2', generation: gen2),
        TransitionResult.illegal,
      );

      // 需要先回到 idle 再 opening
      expect(
        machine.transitionTo(MediaState.idle, 'reset'),
        TransitionResult.ok,
      );

      // gen2 的 opening 现在合法
      expect(
        machine.transitionTo(MediaState.opening, 'open2-retry', generation: gen2),
        TransitionResult.ok,
      );

      // gen2 完成
      expect(
        machine.transitionTo(MediaState.playing, 'play2', generation: gen2),
        TransitionResult.ok,
      );

      // gen1 的 late 回调被拒绝
      expect(
        machine.transitionTo(
          MediaState.playing,
          'play1-late',
          generation: gen1,
        ),
        TransitionResult.staleGeneration,
      );

      // 最终状态来自 gen2
      expect(machine.state.value, MediaState.playing);

      machine.dispose();
    });
  });

  group('Race condition — recover during rapid operations', () {
    test('recover after error from stale generation', () {
      final machine = EngineStateMachine();

      // gen1: open → error
      final gen1 = machine.nextGeneration();
      expect(
        machine.transitionTo(MediaState.opening, 'open1', generation: gen1),
        TransitionResult.ok,
      );
      expect(
        machine.transitionTo(MediaState.error, 'error1', generation: gen1),
        TransitionResult.ok,
      );
      expect(machine.state.value, MediaState.error);

      // 用户发起新 open（gen2）但先 recover
      final gen2 = machine.nextGeneration();

      // recover 从 error → idle
      machine.recover();
      expect(machine.state.value, MediaState.idle);

      // gen2 的 open 现在可以进行
      expect(
        machine.transitionTo(MediaState.opening, 'open2', generation: gen2),
        TransitionResult.ok,
      );
      expect(machine.state.value, MediaState.opening);

      machine.dispose();
    });

    test('recover is no-op in non-error states', () {
      final machine = EngineStateMachine();

      machine.nextGeneration();
      machine.transitionTo(MediaState.opening, 'open', generation: 1);
      expect(machine.state.value, MediaState.opening);

      // recover 在 opening 状态下是 no-op
      machine.recover();
      expect(machine.state.value, MediaState.opening);

      machine.dispose();
    });
  });
}
