import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart'
    show KernelLoggerImpl;
import 'package:simple_player_flutter/kernel/engine/engine_state_machine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';

/// 竞态条件测试 — 验证 EngineStateMachine 的 generation 守卫在快速操作下的正确性.
///
/// 状态机瘦身后: transitionTo 返回 void,合法性不再由状态机校验.
/// generation 守卫仍是核心 — stale 回调被拒绝写入,state 不变.
/// 已删除: lifecyclePhase 组、recover 组(对应抽象已删).
void main() {
  // 初始化 KernelLogger 用于 transitionTo 的 warn 日志.
  KernelLoggerImpl.init();

  group('Race condition — generation tracking', () {
    test('rapid open-open: second open rejects first open transitions', () {
      final machine = EngineStateMachine();

      // 模拟快速切换文件: gen1 open → idle → gen2 open.
      final gen1 = machine.nextGeneration(); // gen1 = 1
      machine.transitionTo(MediaState.opening, 'open1', generation: gen1);
      expect(machine.state.value, MediaState.opening);

      // gen1 取消/失败 → idle(模拟引擎取消当前 open).
      machine.transitionTo(MediaState.idle, 'cancel1', generation: gen1);
      expect(machine.state.value, MediaState.idle);

      // gen2 立即开始 open.
      final gen2 = machine.nextGeneration(); // gen2 = 2
      machine.transitionTo(MediaState.opening, 'open2', generation: gen2);
      expect(machine.state.value, MediaState.opening);

      // gen1 的 stale 回调到达 — 被拒绝,state 不变.
      machine.transitionTo(
        MediaState.playing,
        'open1-complete',
        generation: gen1,
      );
      expect(machine.state.value, MediaState.opening);

      machine.dispose();
    });

    test('stale generation rejected — state unchanged', () {
      final machine = EngineStateMachine();

      // 递增 3 次 generation,使用过期的 gen=1.
      machine.nextGeneration(); // gen1 = 1
      machine.nextGeneration(); // gen2 = 2
      machine.nextGeneration(); // gen3 = 3

      machine.state.value = MediaState.opening;
      machine.transitionTo(MediaState.playing, 'stale', generation: 1);
      // gen 1 过期,state 不变.
      expect(machine.state.value, MediaState.opening);

      machine.dispose();
    });
  });

  group('Race condition — open-seek-open interleaved', () {
    test('seek between two opens: final state matches last open', () {
      final machine = EngineStateMachine();

      // gen1 open → playing(第一个文件加载成功).
      final gen1 = machine.nextGeneration();
      machine.transitionTo(MediaState.opening, 'open1', generation: gen1);
      machine.transitionTo(
        MediaState.playing,
        'gen1-loaded',
        generation: gen1,
      );
      expect(machine.state.value, MediaState.playing);

      // 用户在 playing 中 seek — playing→playing 同值,setter 无条件写入
      // (ValueNotifier 同值不触发通知,语义上等于 no-op).
      machine.transitionTo(MediaState.playing, 'seek-during-play');
      expect(machine.state.value, MediaState.playing);

      // 用户发起新 open(gen2)— 先回 idle.
      machine.transitionTo(MediaState.idle, 'stop-for-open2');
      final gen2 = machine.nextGeneration();
      machine.transitionTo(MediaState.opening, 'open2', generation: gen2);

      // gen1 的 late 回调到达 — stale,拒绝.
      machine.transitionTo(
        MediaState.playing,
        'gen1-late',
        generation: gen1,
      );
      expect(machine.state.value, MediaState.opening);

      // gen2 完成加载 → playing.
      machine.transitionTo(
        MediaState.playing,
        'gen2-loaded',
        generation: gen2,
      );
      expect(machine.state.value, MediaState.playing);

      machine.dispose();
    });
  });

  group('Race condition — dispose during open', () {
    test('dispose during open: state machine disposes safely', () {
      final machine = EngineStateMachine();

      final gen = machine.nextGeneration();
      machine.transitionTo(MediaState.opening, 'open', generation: gen);

      // 取消 open.
      machine.transitionTo(MediaState.idle, 'cancel', generation: gen);

      // dispose 不抛异常(lifecyclePhase 已删,仅验证 dispose 安全).
      expect(() => machine.dispose(), returnsNormally);
    });

    test('double dispose is safe no-op', () {
      final machine = EngineStateMachine();
      machine.dispose();
      expect(() => machine.dispose(), returnsNormally);
    });
  });

  group('Race condition — open-play-pause-open rapid fire', () {
    test('rapid sequence: stale generation rejected, current honored', () {
      final machine = EngineStateMachine();

      // gen1: open → playing.
      final gen1 = machine.nextGeneration();
      machine.transitionTo(MediaState.opening, 'open1', generation: gen1);
      machine.transitionTo(MediaState.playing, 'play1', generation: gen1);

      // 用户发起新 open(gen2)— 但 gen1 的回调仍在飞行中.
      final gen2 = machine.nextGeneration();

      // gen1 的 pause 回调到达(无 generation 参数)— 写入 paused.
      // 注意: pause 不带 generation,直接写入.
      machine.transitionTo(MediaState.paused, 'pause1');
      expect(machine.state.value, MediaState.paused);

      // gen2 的 opening 到达(带 generation)— setter 无条件写入 opening.
      // 旧设计会因 paused→opening 非法而拒绝;新设计由调用方 guard 负责.
      machine.transitionTo(
        MediaState.opening,
        'open2',
        generation: gen2,
      );
      expect(machine.state.value, MediaState.opening);

      // gen2 完成.
      machine.transitionTo(
        MediaState.playing,
        'play2',
        generation: gen2,
      );
      expect(machine.state.value, MediaState.playing);

      // gen1 的 late 回调被拒绝.
      machine.transitionTo(
        MediaState.playing,
        'play1-late',
        generation: gen1,
      );
      // 最终状态来自 gen2,stale gen1 不影响.
      expect(machine.state.value, MediaState.playing);

      machine.dispose();
    });
  });
}
