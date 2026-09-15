/// ShufflePolicy 纯函数 + FakeEngine shuffle 语义测试 (v0.0.6 Phase 3).
library;

import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/shuffle_policy.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';

import '../../helpers/fake_engine.dart';

void main() {
  group('ShufflePolicy.pickShuffleNext', () {
    test('排除当前曲', () {
      final picked = ShufflePolicy.pickShuffleNext(
        queue: ['a', 'b', 'c'],
        current: 'b',
        recent: const [],
        random: Random(1),
      );
      expect(picked, isNot('b'));
      expect(picked, isIn(['a', 'c']));
    });

    test('避开最近播放集 (栈顶在前)', () {
      // 种子固定 — 枚举多轮确保避开语义: recent 覆盖除一个候选外的全部.
      final picked = ShufflePolicy.pickShuffleNext(
        queue: ['a', 'b', 'c', 'd'],
        current: 'a',
        recent: const ['b', 'c'],
        random: Random(7),
      );
      expect(picked, 'd'); // 新鲜候选唯一
    });

    test('鸽笼保证 — 2 元素队列不死锁', () {
      final rng = Random(3);
      for (var i = 0; i < 20; i++) {
        final picked = ShufflePolicy.pickShuffleNext(
          queue: ['a', 'b'],
          current: 'a',
          recent: const ['b', 'a', 'b'],
          random: rng,
        );
        expect(picked, 'b'); // 新鲜候选恒存在
      }
    });

    test('单文件队列 — 返回 null (调用方裁定回退)', () {
      expect(
        ShufflePolicy.pickShuffleNext(
          queue: ['a'],
          current: 'a',
          recent: const [],
          random: Random(1),
        ),
        isNull,
      );
    });

    test('可注入 Random — 确定性可测', () {
      final picks = <String?>[];
      for (var i = 0; i < 10; i++) {
        picks.add(
          ShufflePolicy.pickShuffleNext(
            queue: ['a', 'b', 'c'],
            current: 'a',
            recent: const [],
            random: Random(42),
          ),
        );
      }
      expect(picks.toSet().length, 1); // 同种子同序列 → 恒定
    });

    test('recent 中的已移除条目自然失效 (交集裁剪)', () {
      final picked = ShufflePolicy.pickShuffleNext(
        queue: ['a', 'b'],
        current: 'a',
        recent: const ['x', 'y', 'z'], // 均不在队列
        random: Random(5),
      );
      expect(picked, 'b');
    });
  });

  group('ShufflePolicy.pushHistory', () {
    test('入栈 + 容量溢出丢栈底', () {
      final history = ListQueue<String>();
      for (var i = 0; i < ShufflePolicy.historyCapacity + 5; i++) {
        ShufflePolicy.pushHistory(history, 'p$i');
      }
      expect(history.length, ShufflePolicy.historyCapacity);
      expect(history.first, 'p5'); // 最早的 5 条被挤出
      expect(history.last, 'p${ShufflePolicy.historyCapacity + 4}');
    });
  });

  group('FakeEngine shuffle 语义 (与 MediaKitEngine 同构)', () {
    late FakeEngine engine;

    setUp(() => engine = FakeEngine());
    tearDown(() => engine.dispose());

    test('shuffle 手动 next — 队列顺序恒定, 跳转发生 (解耦直接断言)',
        () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await engine.setPlayMode(PlayMode.shuffle);

      engine.nextInQueue();
      engine.nextInQueue();
      engine.nextInQueue();

      // v0.0.6 核心断言: 随机播放不再物理乱序列表.
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(engine.jumpedToIndices, hasLength(3));
    });

    test('shuffle previous — 沿历史栈精确回溯', () async {
      // 注入确定 picker: 恒选队列末尾元素.
      engine.shufflePicker =
          ({required queue, required current, required recent}) =>
              queue.reversed.firstWhere((p) => p != current);
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await engine.setPlayMode(PlayMode.shuffle);

      engine.nextInQueue(); // a → c (picker 注入)
      engine.nextInQueue(); // c → b
      expect(engine.queueIndex.value, 1);

      engine.previousInQueue(); // 弹栈 → c
      expect(engine.queueIndex.value, 2);
      engine.previousInQueue(); // 弹栈 → a
      expect(engine.queueIndex.value, 0);
    });

    test('shuffle previous 栈空 — 线性回绕兜底 (永远有响应)', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await engine.setPlayMode(PlayMode.shuffle);

      engine.previousInQueue(); // 无历史 → index-1: 0 → 2 (回绕)

      expect(engine.queueIndex.value, 2);
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']);
    });

    test('shuffle EOF 自动续播 — simulateCompleted 触发随机跳转', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await engine.setPlayMode(PlayMode.shuffle);

      engine.simulateCompleted();

      expect(engine.jumpedToIndices, hasLength(1));
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']); // 顺序不变
    });

    test('loopAll 下 EOF — 无 Dart 层钩子 (mpv 原生循环)', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await engine.setPlayMode(PlayMode.loopAll);

      engine.simulateCompleted();

      expect(engine.jumpedToIndices, isEmpty);
    });

    test('切换出 shuffle 再切回 — 历史栈清空', () async {
      engine.shufflePicker =
          ({required queue, required current, required recent}) =>
              queue.reversed.firstWhere((p) => p != current);
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      await engine.setPlayMode(PlayMode.shuffle);
      engine.nextInQueue(); // 历史: [a]
      expect(engine.shuffleHistory, isNotEmpty);

      await engine.setPlayMode(PlayMode.loopAll);
      await engine.setPlayMode(PlayMode.shuffle);

      expect(engine.shuffleHistory, isEmpty);
    });
  });
}
