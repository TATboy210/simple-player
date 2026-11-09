/// ThumbnailConcurrencyGate 单测 — 有界并发 / FIFO 公平 / 异常归还 / reset.
///
/// 纯 Completer 驱动, 无真实延时 (pumpEventQueue 泵微任务).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_concurrency_gate.dart';

void main() {
  group('ThumbnailConcurrencyGate', () {
    test('容量内任务立即并行, 超出者排队', () async {
      final gate = ThumbnailConcurrencyGate(2);
      final holds = List.generate(3, (_) => Completer<void>());
      final started = <int>[];

      final futures = [
        for (var i = 0; i < 3; i++)
          gate.run(() async {
            started.add(i);
            await holds[i].future;
          }),
      ];
      await pumpEventQueue();

      expect(started, [0, 1], reason: '第 3 个任务须等 slot');
      expect(gate.active, 2);
      expect(gate.queued, 1);

      holds[0].complete();
      await pumpEventQueue();
      expect(started, [0, 1, 2], reason: 'slot 释放后队首立即接手');

      holds[1].complete();
      holds[2].complete();
      await Future.wait(futures);
      expect(gate.active, 0);
      expect(gate.queued, 0);
    });

    test('FIFO — 等待者按入队顺序获得 slot', () async {
      final gate = ThumbnailConcurrencyGate(1);
      final order = <String>[];
      final hold = Completer<void>();

      final first = gate.run(() => hold.future);
      final futures = [
        for (final name in ['a', 'b', 'c'])
          gate.run(() async => order.add(name)),
      ];
      await pumpEventQueue();
      expect(order, isEmpty, reason: '首个任务占满, 其余排队');

      hold.complete();
      await first;
      await Future.wait(futures);
      expect(order, ['a', 'b', 'c']);
    });

    test('任务抛异常照样归还 slot, 异常原样传出', () async {
      final gate = ThumbnailConcurrencyGate(1);

      await expectLater(
        gate.run<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(gate.active, 0, reason: 'slot 不泄漏');

      expect(await gate.run(() async => 42), 42, reason: '后续任务不被卡死');
    });

    test('active 峰值恒不超过 maxConcurrent', () async {
      final gate = ThumbnailConcurrencyGate(2);
      var peak = 0;
      final holds = List.generate(6, (_) => Completer<void>());

      final futures = [
        for (final hold in holds)
          gate.run(() async {
            if (gate.active > peak) peak = gate.active;
            await hold.future;
          }),
      ];
      for (final hold in holds) {
        await pumpEventQueue();
        hold.complete();
      }
      await Future.wait(futures);

      expect(peak, 2);
    });

    test('reset — 清零占用并唤醒全部排队者重新分配', () async {
      final gate = ThumbnailConcurrencyGate(1);
      final hold = Completer<void>(); // 先不完成 — 模拟泄漏的 slot
      final leaked = gate.run(() => hold.future);
      final ran = <String>[];
      final waiter = gate.run(() async => ran.add('waiter'));
      await pumpEventQueue();
      expect(gate.queued, 1);

      gate.reset();
      await waiter;

      expect(ran, ['waiter'], reason: '被重置唤醒的等待者照常执行');
      hold.complete(); // 收尾: 让悬挂任务退出
      await leaked;
    });
  });
}
