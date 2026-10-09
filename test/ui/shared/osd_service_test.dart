import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/shared/osd_message.dart';
import 'package:simple_player_flutter/ui/shared/osd_service.dart';

/// Deterministic scheduler deliberately permits firing canceled callbacks.
class _Clock {
  Duration now = Duration.zero;
  final jobs = <_Job>[];
  int maxOutstanding = 0;

  VoidCallback schedule(Duration delay, VoidCallback fire) {
    final job = _Job(now + delay, fire);
    jobs.add(job);
    final active = jobs.where((j) => !j.canceled && !j.fired).length;
    if (active > maxOutstanding) maxOutstanding = active;
    return () => job.canceled = true;
  }

  void advance(int ms) {
    now = Duration(milliseconds: ms);
    for (final job in List<_Job>.of(jobs)) {
      if (!job.canceled && !job.fired && job.at <= now) job.run();
    }
  }
}

class _Job {
  _Job(this.at, this.fire);
  final Duration at;
  final VoidCallback fire;
  bool canceled = false;
  bool fired = false;
  void run() {
    fired = true;
    fire();
  }
}

void main() {
  for (final priority in OsdPriority.values) {
    test('${priority.name} expires at its exact fixed deadline', () {
      final clock = _Clock();
      final service = OsdService(
        now: () => clock.now,
        schedule: clock.schedule,
      );
      service.show('event', priority: priority);
      clock.advance(priority.lifetime.inMilliseconds - 1);
      expect(service.snapshot.value.current?.message.text, 'event');
      clock.advance(priority.lifetime.inMilliseconds);
      expect(service.snapshot.value.current, isNull);
      expect(clock.maxOutstanding, 1);
      service.dispose();
    });
  }

  test(
    'higher interrupts without requeue; same level immediately refreshes',
    () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('status');
      clock.advance(100);
      s.show('success', priority: OsdPriority.success);
      expect(s.snapshot.value.pending, isNull);
      clock.advance(200);
      s.show('warning', priority: OsdPriority.warning, coalescingKey: 'disk');
      clock.advance(300);
      s.show(
        'warning latest',
        priority: OsdPriority.failure,
        coalescingKey: 'disk',
      );
      expect(s.snapshot.value.current?.message.text, 'warning latest');
      expect(s.snapshot.value.current?.expiresAt.inMilliseconds, 4300);
      expect(s.snapshot.value.pending, isNull);
      clock.advance(4300);
      expect(s.visible.value, isFalse);
      expect(clock.maxOutstanding, 1);
      s.dispose();
    },
  );

  test('pending highest priority survives; equal priority latest wins', () {
    final clock = _Clock();
    final s = OsdService(now: () => clock.now, schedule: clock.schedule);
    s.show('warning', priority: OsdPriority.warning);
    clock.advance(3000);
    s.show('success old', priority: OsdPriority.success);
    clock.advance(3100);
    s.show('success latest', priority: OsdPriority.success);
    clock.advance(3500);
    s.show('status');
    expect(s.snapshot.value.pending?.message.text, 'success latest');
    clock.advance(4000);
    expect(s.message.value?.text, 'success latest');
    expect(s.snapshot.value.current?.expiresAt.inMilliseconds, 4700);
    clock.advance(4700);
    expect(s.message.value, isNull);
    expect(clock.maxOutstanding, 1);
    s.dispose();
  });

  for (final example in [
    (OsdPriority.success, 500, 1600, 1700),
    (OsdPriority.warning, 3500, 4000, 4700),
  ]) {
    test('promotion keeps only ${example.$4 - example.$3}ms remaining', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('current', priority: example.$1);
      clock.advance(example.$2);
      s.show('pending');
      expect(s.message.value?.text, 'current');
      clock.advance(example.$3);
      expect(s.message.value?.text, 'pending');
      expect(s.snapshot.value.current?.expiresAt.inMilliseconds, example.$4);
      clock.advance(example.$4);
      expect(s.message.value, isNull);
      expect(clock.maxOutstanding, 1);
      s.dispose();
    });
  }

  test('expired pending discarded, including the 2800 versus 4000 trap', () {
    final clock = _Clock();
    final s = OsdService(now: () => clock.now, schedule: clock.schedule);
    s.show('warning', priority: OsdPriority.warning);
    clock.advance(1600);
    s.show('expired pending');
    clock.advance(4000);
    expect(s.snapshot.value.current, isNull);
    expect(s.snapshot.value.pending, isNull);
    s.dispose();
  });

  test('expired higher pending cannot prevent a valid lower replacement', () {
    final clock = _Clock();
    final s = OsdService(now: () => clock.now, schedule: clock.schedule);
    s.show('warning', priority: OsdPriority.warning);
    s.show('old success', priority: OsdPriority.success);
    clock.advance(3500);
    s.show('valid status');
    expect(s.snapshot.value.pending?.message.text, 'valid status');
    clock.advance(4000);
    expect(s.message.value?.text, 'valid status');
    s.dispose();
  });

  for (final timerFirst in [true, false]) {
    test('exact expiry admission, timerFirst=$timerFirst, stale safe', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('old');
      final old = clock.jobs.single;
      clock.now = const Duration(milliseconds: 1200);
      if (timerFirst) old.run();
      s.show('new');
      if (!timerFirst) old.run();
      expect(s.message.value?.text, 'new');
      expect(s.snapshot.value.current?.expiresAt.inMilliseconds, 2400);
      clock.advance(2400);
      expect(s.message.value, isNull);
      expect(clock.maxOutstanding, 1);
      s.dispose();
    });
  }

  test(
    'out-of-order canceled callbacks cannot hide current or promote stale',
    () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('a');
      s.show('b');
      s.show('c', priority: OsdPriority.warning);
      s.show('pending');
      final generation = s.snapshot.value.generation;
      for (final job in clock.jobs.reversed.toList()) {
        if (job.canceled) job.run();
      }
      expect(s.message.value?.text, 'c');
      expect(s.snapshot.value.generation, generation);
      s.hide();
      for (final job in clock.jobs) {
        job.run();
      }
      expect(s.message.value, isNull);
      expect(clock.maxOutstanding, 1);
      s.dispose();
    },
  );

  // ── Build-phase publication guard ──
  // 构建期相位守卫: persistentCallbacks 期间 show/hide 只把 ValueNotifier 发布
  // 推迟到本帧末, 准入记账同步推进, 消息不丢、不重、非 build 期时序不变。
  group('build-phase publication guard', () {
    testWidgets(
      'build-phase shows defer publication to frame end without loss',
      (tester) async {
        // 与 osd_overlay_test.dart 相同的注入时钟: 生产 Stopwatch 不跟随假时钟。
        final binding = tester.binding;
        final start = binding.clock.now();
        final service = OsdService(
          now: () => binding.clock.now().difference(start),
        );
        addTearDown(service.dispose);
        final notifications = <int>[];
        late final OsdSnapshot duringBuild;
        // 帧末冲刷在 pumpWidget 返回前就已执行 (post-frame 即本帧末),
        // 因此"构建期零通知"必须在 builder 内部捕获计数快照。
        late final int duringBuildNotifications;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                service.snapshot.addListener(
                  () => notifications.add(service.snapshot.value.generation),
                );
                service.show('warn', priority: OsdPriority.warning);
                // rank 0 低于 rank 2: 准入对等要求 current=warn + pending=info。
                service.show('info');
                duringBuild = service.snapshot.value;
                duringBuildNotifications = notifications.length;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // 构建期: 同步记账真值仍未推进发布面, 监听器零通知。
        expect(duringBuild.generation, 0);
        expect(duringBuild.current, isNull);
        expect(duringBuild.pending, isNull);
        expect(duringBuildNotifications, 0);
        // 帧末一次合并冲刷: 携带两次 show 后的最终一致快照, 不丢消息、不重复通知。
        expect(service.snapshot.value.generation, 2);
        expect(service.snapshot.value.current?.message.text, 'warn');
        expect(service.snapshot.value.pending?.message.text, 'info');
        expect(notifications, [2]);
        // t=3000: pending 'info' 已过 1200ms 生命期被 prune, warning 仍在场。
        await tester.pump(const Duration(milliseconds: 3000));
        service.show('late status'); // 4200ms 到期, 能活过 warning 的 4000ms。
        expect(service.snapshot.value.generation, 3);
        expect(service.snapshot.value.pending?.message.text, 'late status');
        // t=4000: warning 精确到期, 正常过期路径晋升仍有效的 pending。
        await tester.pump(const Duration(milliseconds: 1000));
        expect(service.snapshot.value.current?.message.text, 'late status');
        expect(service.snapshot.value.pending, isNull);
        expect(notifications, [2, 3, 4]);
        await tester.pump(const Duration(milliseconds: 200));
        expect(service.snapshot.value.current, isNull);
        expect(notifications, [2, 3, 4, 5]);
        service.dispose();
      },
    );

    testWidgets('build-phase hide defers and clears with a single flush', (
      tester,
    ) async {
      final binding = tester.binding;
      final start = binding.clock.now();
      final service = OsdService(
        now: () => binding.clock.now().difference(start),
      );
      addTearDown(service.dispose);
      final notifications = <int>[];
      late final OsdSnapshot duringBuild;
      // 同上: 冲刷发生在 pumpWidget 帧末, 构建期计数须在 builder 内捕获。
      late final int duringBuildNotifications;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              service.snapshot.addListener(
                () => notifications.add(service.snapshot.value.generation),
              );
              service.show('transient', priority: OsdPriority.warning);
              service.hide();
              duringBuild = service.snapshot.value;
              duringBuildNotifications = notifications.length;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(duringBuild.generation, 0);
      expect(duringBuild.current, isNull);
      expect(duringBuild.pending, isNull);
      expect(duringBuildNotifications, 0);
      // show+hide 合并为一次帧末冲刷, 终态清空且只通知一次。
      expect(service.snapshot.value.generation, 2);
      expect(service.snapshot.value.current, isNull);
      expect(service.snapshot.value.pending, isNull);
      expect(notifications, [2]);
      // show 同步记下的 warning 计时器已由 hide 取消, dispose 兜底释放。
      service.dispose();
    });

    testWidgets('dispose during pending deferral does not throw', (
      tester,
    ) async {
      final binding = tester.binding;
      final start = binding.clock.now();
      final service = OsdService(
        now: () => binding.clock.now().difference(start),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              service.show('doomed', priority: OsdPriority.warning);
              // 冲刷仍在队列中时同步 dispose: 延迟闭包绝不能触碰已释放的 notifier。
              service.dispose();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ── coalescingKey contract ──
  // key 身份门契约: 同 key 同 rank 顶替合并刷新; 异 key 同 rank 各自排队不互吃
  // (双槽占满时第三条按容量裁决丢弃); 无 key incoming 走纯 rank 行为逐字段一致。
  group('coalescingKey contract', () {
    test('distinct keys at same rank coexist and neither is dropped', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('warn a', priority: OsdPriority.warning, coalescingKey: 'a');
      expect(s.snapshot.value.current?.message.text, 'warn a');
      clock.advance(1000);
      s.show('warn b', priority: OsdPriority.warning, coalescingKey: 'b');
      // 异 key 同 rank 不互吃: 'b' 入 pending 等位, 不得顶替在场的 'a'。
      expect(s.snapshot.value.current?.message.text, 'warn a');
      expect(s.snapshot.value.pending?.message.text, 'warn b');
      clock.advance(4000); // 越过 'a' 的绝对到期 (warning lifetime 4000ms)
      expect(s.snapshot.value.current?.message.text, 'warn b');
      clock.advance(5000); // 越过 'b' 的绝对到期 (1000+4000, 晋升不续期)
      expect(s.snapshot.value.current, isNull);
      expect(clock.maxOutstanding, 1);
      s.dispose();
    });

    test('same key at same rank merges and refreshes in place', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('disk warn', priority: OsdPriority.warning, coalescingKey: 'k');
      clock.advance(1000);
      s.show(
        'disk warn latest',
        priority: OsdPriority.warning,
        coalescingKey: 'k',
      );
      // 同 key 合并刷新: 新文本 + 新入场绝对到期 (1000+4000), 非续期旧到期。
      expect(s.snapshot.value.current?.message.text, 'disk warn latest');
      expect(s.snapshot.value.current?.expiresAt.inMilliseconds, 5000);
      expect(s.snapshot.value.pending, isNull);
      s.dispose();
    });

    test(
      'unkeyed same-rank incoming still replaces immediately (legacy path)',
      () {
        final clock = _Clock();
        final s = OsdService(now: () => clock.now, schedule: clock.schedule);
        s.show('keyed warn', priority: OsdPriority.warning, coalescingKey: 'a');
        s.show('unkeyed warn', priority: OsdPriority.warning);
        // 无 key incoming 走纯 rank 行为: 仍顶替同 rank current, 无论其带不带 key。
        expect(s.snapshot.value.current?.message.text, 'unkeyed warn');
        expect(s.snapshot.value.pending, isNull);
        s.dispose();
      },
    );

    test('keyed same-rank incoming stages instead of displacing unkeyed '
        'or different-key current', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('unkeyed warn', priority: OsdPriority.warning);
      clock.advance(1000);
      s.show('keyed a warn', priority: OsdPriority.warning, coalescingKey: 'a');
      // keyed 进不可顶替无 key current (同 rank): 'a' 入 pending 等位接续。
      expect(s.snapshot.value.current?.message.text, 'unkeyed warn');
      expect(s.snapshot.value.pending?.message.text, 'keyed a warn');
      clock.advance(4000); // 越过无 key current 的到期
      expect(s.snapshot.value.current?.message.text, 'keyed a warn');
      s.dispose();
    });

    test('third distinct-key same-rank warning is dropped '
        'when both slots hold distinct keys', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('warn a', priority: OsdPriority.warning, coalescingKey: 'a');
      clock.advance(1000);
      s.show('warn b', priority: OsdPriority.warning, coalescingKey: 'b');
      s.show('warn c', priority: OsdPriority.warning, coalescingKey: 'c');
      // 双槽容量裁决: 'a'(current)+'b'(pending) 占满后, 'c' 被丢弃不顶替任何在位者。
      expect(s.snapshot.value.current?.message.text, 'warn a');
      expect(s.snapshot.value.pending?.message.text, 'warn b');
      s.dispose();
    });

    test('same key never demotes a higher-rank current; '
        'lower ranks stage regardless of key', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('failure now', priority: OsdPriority.failure, coalescingKey: 'k');
      // 同 key 'k' 但 rank 更低 (success 1 < failure 2): 身份匹配不豁免 rank 准入。
      // 注: warning 与 failure 同为 rank 2 (既有准入结构), 计划原场景 (warning
      // 带 key 但 rank 更低) 无法构造, 故用 success 钉死同一契约。
      s.show(
        'keyed success',
        priority: OsdPriority.success,
        coalescingKey: 'k',
      );
      expect(s.snapshot.value.current?.message.text, 'failure now');
      expect(s.snapshot.value.pending?.message.text, 'keyed success');
      // 无 key 低 rank 同样只进 pending 位 (既有 equal-rank-latest 规则顶掉同位者)。
      s.show('unkeyed success', priority: OsdPriority.success);
      expect(s.snapshot.value.current?.message.text, 'failure now');
      expect(s.snapshot.value.pending?.message.text, 'unkeyed success');
      s.dispose();
    });
  });

  // ── status pending-slot admission (261009-oab) ──
  // 方案 b 最小修: status (rank 0) 恒占 pending 位顶掉任何旧 pending (latest
  // wins) — 双槽被高 rank 占满时不再整条蒸发, 最坏从"蒸发"收敛为"等 current
  // 到期"; fj3 既有 coalescingKey 契约组保持原语义不动。
  group('status always occupies pending slot', () {
    test('status is never dropped when higher ranks fill both slots', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('failure now', priority: OsdPriority.failure, coalescingKey: 'f');
      s.show('warning held', priority: OsdPriority.warning, coalescingKey: 'w');
      // 异 key 同 rank 2 占满双槽: failure 占 current, warning 等 pending。
      expect(s.snapshot.value.current?.message.text, 'failure now');
      expect(s.snapshot.value.pending?.message.text, 'warning held');
      // 新语义: status 恒入 pending 位, 不再整条蒸发。
      s.show('volume 50%');
      expect(s.snapshot.value.current?.message.text, 'failure now');
      expect(s.snapshot.value.pending?.message.text, 'volume 50%');
      expect(clock.maxOutstanding, 1);
      s.dispose();
    });

    test(
      'status displaces a higher-rank pending and promotes after current',
      () {
        final clock = _Clock();
        final s = OsdService(now: () => clock.now, schedule: clock.schedule);
        s.show('success now', priority: OsdPriority.success);
        s.show(
          'success held',
          priority: OsdPriority.success,
          coalescingKey: 'x',
        );
        clock.advance(500);
        s.show('mute on'); // rank 0, 到期 1700 > current 1600, 晋升时仍有效。
        // 新语义: status 顶掉更高 rank 的 pending (latest wins)。
        expect(s.snapshot.value.current?.message.text, 'success now');
        expect(s.snapshot.value.pending?.message.text, 'mute on');
        clock.advance(1600);
        // current 到期后晋升的是 status, 而非被顶掉的 'success held'。
        expect(s.message.value?.text, 'mute on');
        clock.advance(1700);
        expect(s.message.value, isNull);
        expect(clock.maxOutstanding, 1);
        s.dispose();
      },
    );

    test('consecutive statuses keep only the latest in pending', () {
      final clock = _Clock();
      final s = OsdService(now: () => clock.now, schedule: clock.schedule);
      s.show('failure now', priority: OsdPriority.failure, coalescingKey: 'f');
      s.show('warning held', priority: OsdPriority.warning, coalescingKey: 'w');
      s.show('volume 50%');
      s.show('volume 80%');
      expect(s.snapshot.value.current?.message.text, 'failure now');
      // 连发两条 status 只留最新 (latest wins), 被顶掉的旧 pending 不复活。
      expect(s.snapshot.value.pending?.message.text, 'volume 80%');
      expect(clock.maxOutstanding, 1);
      s.dispose();
    });
  });
}
