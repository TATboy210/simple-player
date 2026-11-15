import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/service/close_sequence.dart';

// 本文件大量使用无操作占位闭包充当序列步进器（hide/persist/dispose 的
// “本用例不关心此步”变体），DCM 的 no-empty-block 会逐个误报 — 文件级豁免。
// ignore_for_file: no-empty-block, avoid_redundant_async

/// 关窗 hide-first 序列（契约 7）的行为锁定。
///
/// 序列：hide → persist → closing listeners → dispose + exit(0)；
/// 每步超时兜底、任何失败不阻断退出、多路触发单飞。
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('CloseSequence', () {
    test('按契约顺序执行：hide → persist → listeners → dispose → exit(0)',
        () async {
      final calls = <String>[];
      final seq = CloseSequence(
        hide: () => calls.add('hide'),
        persist: () async => calls.add('persist'),
        closingListeners: () => [
          () async => calls.add('listener-1'),
          () async => calls.add('listener-2'),
        ],
        disposeService: () => calls.add('dispose'),
        exit: (code) => calls.add('exit=$code'),
      );
      await seq.begin();
      expect(calls, [
        'hide',
        'persist',
        'listener-1',
        'listener-2',
        'dispose',
        'exit=0',
      ]);
    });

    test('重复触发单飞 — 共享同一次执行，hide/persist 各只跑一次', () async {
      var hideCount = 0;
      var persistCount = 0;
      final exitCodes = <int>[];
      // persist 挂起，直到测试放行 — 验证第二个触发不会重开序列。
      final releasePersist = Completer<void>();
      final seq = CloseSequence(
        hide: () => hideCount++,
        // ignore: prefer_async_await
        persist: () => releasePersist.future.then((_) => persistCount++),
        closingListeners: () => const [],
        disposeService: () {},
        exit: exitCodes.add,
      );

      final first = seq.begin();
      final second = seq.begin();
      final third = seq.begin();
      // 未放行 persist：第二个/第三个触发拿到的是同一个未完成 operation。
      expect(identical(first, second), isTrue);
      expect(identical(second, third), isTrue);
      expect(hideCount, 1);

      releasePersist.complete();
      await first;
      expect(hideCount, 1);
      expect(persistCount, 1);
      expect(exitCodes, [0]);
      // 序列完成后再次触发：_operation 从不重置 — 单飞语义的极端表现
      // （close 后进程即退，重开场景不存在；调用方由 _disposed 门控）。
      final again = seq.begin();
      expect(identical(again, first), isTrue);
      expect(hideCount, 1);
    });

    test('步骤抛错不阻断退出 — hide 失败仍走 persist/exit(0)', () async {
      final calls = <String>[];
      final seq = CloseSequence(
        hide: () => throw StateError('hide failed'),
        persist: () async => calls.add('persist'),
        closingListeners: () => [
          () => throw Exception('listener failed'),
          () async => calls.add('listener-2'),
        ],
        disposeService: () => calls.add('dispose'),
        exit: (code) => calls.add('exit=$code'),
      );
      await seq.begin();
      expect(calls, ['persist', 'listener-2', 'dispose', 'exit=0']);
    });

    test('异步 listener 执行中注册的新 listener 不在本次快照内', () async {
      final calls = <String>[];
      late List<Future<void> Function()> Function() listeners;
      final seq = CloseSequence(
        hide: () {},
        persist: () async {},
        closingListeners: () => listeners(),
        disposeService: () {},
        exit: (_) => calls.add('exit'),
      );
      listeners = () => [
        // ignore: avoid_redundant_async
        () async {
          calls.add('listener-1');
          // listener 执行期间注册 — 契约允许，但本次序列不遍历到它。
          listeners = () => [
            () async => calls.add('late-listener'),
          ];
        },
      ];
      await seq.begin();
      expect(calls, ['listener-1', 'exit']);
    });

    test('步骤超时兜底 — persist 挂起超过 stepTimeout 仍继续 dispose+exit',
        () async {
      final exitCodes = <int>[];
      var disposeCount = 0;
      late CloseSequence seq;
      seq = CloseSequence(
        hide: () {},
        persist: () => Completer<void>().future, // 永不完成
        closingListeners: () => const [],
        disposeService: () => disposeCount++,
        exit: exitCodes.add,
        stepTimeout: const Duration(milliseconds: 20),
      );
      final done = seq.begin();
      // stepTimeout 到期后序列继续走（不取消底层，只是不再等待）。
      await done.timeout(const Duration(seconds: 2),
          onTimeout: () => fail('sequence hung past stepTimeout'));
      expect(disposeCount, 1);
      expect(exitCodes, [0]);
      // 超时发生在 fake time 里也成立 — 用 fakeAsync 复核计时不依赖真实等待。
      fakeAsync((async) {
        var exits = 0;
        final seq2 = CloseSequence(
          hide: () {},
          persist: () => Completer<void>().future,
          closingListeners: () => const [],
          disposeService: () {},
          exit: (_) => exits++,
          stepTimeout: const Duration(milliseconds: 800),
        );
        // ignore: prefer_async_await
        unawaited(seq2.begin().then((_) => exits++));
        async.elapse(const Duration(milliseconds: 1600));
        expect(exits, 2); // exit(0) + operation 完成计数
      });
    });

    test('dispose+exit 在任何路径下都执行（finally 语义）', () async {
      final exitCodes = <int>[];
      var disposeCount = 0;
      final seq = CloseSequence(
        hide: () => throw StateError('boom'),
        persist: () async {},
        closingListeners: () => const [],
        disposeService: () => disposeCount++,
        exit: exitCodes.add,
        stepTimeout: const Duration(milliseconds: 10),
      );
      await seq.begin();
      expect(disposeCount, 1);
      expect(exitCodes, [0]);
      expect(seq.operation, isNotNull);
    });
  });
}
