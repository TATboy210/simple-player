import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart'
    show KernelLoggerImpl;
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';

import '../../helpers/fake_engine.dart';

/// 竞态条件测试 — 验证引擎 operation-generation 守卫在快速/交错操作下的正确性.
///
/// 原 [EngineStateMachine] 直接单测已随类移除 — generation 守卫内联进
/// MediaKitEngine/FakeEngine (自管 `_operationGeneration` 计数器), 故改为
/// 面向 FakeEngine 外部可观察行为的测试:
/// - stale 请求返回 `OpenSuperseded`
/// - 旧异步 continuation 不得污染新会话的 state/媒体派生状态
/// - 空置态 (无媒体) play/toggle 幂等忽略 (play guard 契约)
///
/// openGate/stopGate 提供确定性交错控制, 不依赖真实时序.
void main() {
  // 初始化 KernelLogger (引擎层日志依赖).
  KernelLoggerImpl.init();

  group('Race condition — rapid open-open', () {
    test('older open is superseded, newest open owns final session', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 1000);

      // open A 挂在 gate 上 (模拟慢速 I/O), open B 随后发起并完成.
      final gateA = Completer<void>();
      engine.openGate = gateA;
      final futureA = engine.open('a.mp4');

      engine.openGate = null;
      final resultB = await engine.open('b.mp4');
      expect(resultB, isA<OpenSuccess>());
      expect(engine.state.value, MediaState.idle);
      expect(engine.hasMedia, isTrue);

      // 释放 A — 它的 continuation 已过期, 不得覆盖 B 的会话.
      gateA.complete();
      final resultA = await futureA;
      expect(resultA, isA<OpenSuperseded>());
      expect(engine.state.value, MediaState.idle);
      expect(engine.hasMedia, isTrue);
    });
  });

  group('Race condition — open-seek-open interleaved', () {
    test('seek between two opens: final state matches last open', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 10000);

      await engine.open('a.mp4');
      engine.play();
      expect(engine.state.value, MediaState.playing);

      // 用户在 playing 中 seek — 乐观定位立即生效.
      await engine.seekTo(5000);
      expect(engine.position.value, 5000);

      // 用户发起新 open — 挂起期间 state 为 opening.
      final gateB = Completer<void>();
      engine.openGate = gateB;
      final futureB = engine.open('b.mp4');
      expect(engine.state.value, MediaState.opening);

      // gen2 完成加载 → idle + 新媒体派生状态.
      gateB.complete();
      expect(await futureB, isA<OpenSuccess>());
      expect(engine.state.value, MediaState.idle);
      expect(engine.hasMedia, isTrue);
      // open B 重置 position — 旧会话的 5000 不得残留.
      expect(engine.position.value, 0);
    });
  });

  group('Race condition — dispose during open', () {
    test('dispose during open: pending open is superseded', () async {
      final engine = FakeEngine();
      final gate = Completer<void>();
      engine.openGate = gate;
      final future = engine.open('a.mp4');

      engine.dispose();
      gate.complete();
      expect(await future, isA<OpenSuperseded>());
    });

    test('double dispose is safe no-op', () {
      final engine = FakeEngine();
      engine.dispose();
      expect(() => engine.dispose(), returnsNormally);
    });
  });

  group('Race condition — open-play-pause-open rapid fire', () {
    test('rapid sequence ends with newest session', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 10000);

      await engine.open('a.mp4'); // gen1 → idle, hasMedia
      engine.play(); // playing
      expect(engine.state.value, MediaState.playing);

      // gen1 会话的 pause 到达 — playing → paused.
      // (须在 open B 之前: open B 会把 state 写成 opening, pause 将被
      //  非 playing guard no-op.)
      engine.pause();
      expect(engine.state.value, MediaState.paused);

      // 新 open B 挂起 (gen2 在飞行中) — state → opening.
      final gateB = Completer<void>();
      engine.openGate = gateB;
      final futureB = engine.open('b.mp4'); // gen2

      // gen2 完成加载.
      gateB.complete();
      await futureB;
      expect(engine.state.value, MediaState.idle);

      // 新会话可正常播放.
      engine.play();
      expect(engine.state.value, MediaState.playing);
    });
  });

  group('Race condition — stale stop vs new open', () {
    test('older stop cannot clear newer open session', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 5000);

      await engine.open('a.mp4');
      engine.play();

      // stop A 挂起 (gen 已递增).
      final stopGate = Completer<void>();
      engine.stopGate = stopGate;
      final stopFuture = engine.stop();

      // 新 open B 抢先完成 — stop A 成为过期操作.
      engine.openGate = null;
      await engine.open('b.mp4');
      expect(engine.hasMedia, isTrue);

      // 释放 stop A — 它不得清空 B 的媒体派生状态.
      stopGate.complete();
      await stopFuture;
      expect(engine.hasMedia, isTrue);
      expect(engine.duration.value, 5000);
    });
  });

  group('Play guard — empty state (no media)', () {
    test('play() with hasMedia=false keeps state idle', () {
      final engine = FakeEngine();
      expect(engine.hasMedia, isFalse);

      engine.play();
      expect(engine.state.value, MediaState.idle);
    });

    test('togglePlayPause() with hasMedia=false keeps state idle', () {
      final engine = FakeEngine();
      engine.togglePlayPause();
      expect(engine.state.value, MediaState.idle);
      // 命令仍路由到引擎 (UI 可交互契约), 只是引擎幂等忽略.
      expect(engine.togglePlayPauseCallCount, 1);
    });

    test('play() after open succeeds — guard does not block normal flow',
        () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 1000);

      await engine.open('a.mp4');
      engine.play();
      expect(engine.state.value, MediaState.playing);

      // stop 清空媒体后, 再 play 又被幂等忽略.
      await engine.stop();
      engine.play();
      expect(engine.state.value, MediaState.idle);
    });
  });
}
