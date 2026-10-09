import 'package:flutter/foundation.dart';
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
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // 构建期: 同步记账真值仍未推进发布面, 监听器零通知。
        expect(duringBuild.generation, 0);
        expect(duringBuild.current, isNull);
        expect(duringBuild.pending, isNull);
        expect(notifications, isEmpty);
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
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(duringBuild.generation, 0);
      expect(duringBuild.current, isNull);
      expect(duringBuild.pending, isNull);
      expect(notifications, isEmpty);
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
}
