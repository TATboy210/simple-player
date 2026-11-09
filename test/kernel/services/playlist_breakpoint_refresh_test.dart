/// 断点刷新单条替换 + 协作类单测 (v0.0.13 coordinator 拆分).
///
/// 覆盖: 5s 断点刷新只替换变化的一条 (其余条目实例 identical, 单次通知)、
/// 缩略图 evict 注入、BreakpointSampler / BreakpointRecorder /
/// PlaylistResumeSeeker / PlaylistMetaCache / QueueObserver 纯逻辑.
/// 全部 FakeEngine + 假时钟, 无 libmpv FFI, 无真实延时.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/services/playlist_breakpoint.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';
import 'package:simple_player_flutter/kernel/services/playlist_meta_cache.dart';
import 'package:simple_player_flutter/kernel/services/playlist_queue_observer.dart';
import 'package:simple_player_flutter/kernel/services/playlist_resume_seeker.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('断点刷新 — 单条替换', () {
    late FakeEngine engine;
    late PlaylistCoordinator coordinator;
    late DateTime now;

    setUp(() {
      engine = FakeEngine();
      coordinator = PlaylistCoordinator(engine: engine);
      now = DateTime(2026, 1, 1);
      coordinator.clock = () => now;
    });

    tearDown(() {
      coordinator.dispose();
      engine.dispose();
    });

    test('5s 节流刷新: 只有当前条目被替换, 其余实例 identical, 单次通知', () async {
      final paths = [for (var i = 0; i < 500; i++) 'v$i.mp4'];
      await engine.openPlaylist(paths, startIndex: 250);
      engine.duration.value = 100000;

      final before = coordinator.entries.value;
      var notifications = 0;
      coordinator.entries.addListener(() => notifications++);

      engine.position.value = 1000; // 首次进度 → 窗口放行 → 刷新当前条目

      final after = coordinator.entries.value;
      expect(notifications, 1, reason: '一次刷新 = 一次通知 (单点)');
      expect(after, hasLength(500));
      // 重建次数证据: 500 条中被替换的实例数 == 1 (旧实现每次重建全部 500 条
      // 的列表, 新实现只换变化的一条, 其余 499 条实例原样沿用).
      var replaced = 0;
      for (var i = 0; i < before.length; i++) {
        if (!identical(before[i], after[i])) replaced++;
      }
      expect(replaced, 1);
      expect(identical(before[250], after[250]), isFalse);
      expect(after[250].path, 'v250.mp4');
      expect(after[250].positionMs, 1000);
    });

    test('旧快照写时复制 — 刷新不改动持有者手里的旧 List', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      final snapshot = coordinator.entries.value;

      engine.position.value = 5000;

      expect(snapshot.first.positionMs, isNull, reason: '旧快照不变');
      expect(coordinator.entries.value.first.positionMs, 5000);
      expect(
        () => coordinator.entries.value.add(PlaylistItem(path: 'x')),
        throwsUnsupportedError,
        reason: '发布的快照恒不可变',
      );
    });

    test('窗口内不重复刷新 — 通知数不随 position 事件线性增长', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      var notifications = 0;
      coordinator.entries.addListener(() => notifications++);

      engine.position.value = 1000; // 放行
      for (var ms = 2000; ms <= 20000; ms += 1000) {
        engine.position.value = ms; // 同一 5s 窗口内 (假时钟未推进)
      }

      expect(notifications, 1, reason: '19 个 position 事件只触发 1 次刷新通知');
    });

    test('开关关闭 — 不记录断点, 不通知', () async {
      final off = ValueNotifier<bool>(false);
      final gated = PlaylistCoordinator(engine: engine, resumeEnabled: off);
      addTearDown(gated.dispose);
      gated.clock = () => now;
      await engine.openPlaylist(['a.mp4']);
      engine.duration.value = 100000;
      var notifications = 0;
      gated.entries.addListener(() => notifications++);

      engine.position.value = 3000;

      expect(notifications, 0);
      expect(gated.entries.value.single.positionMs, isNull);
    });

    test('thumbnailEvict 注入 — 批量删除成功后逐 path 回调, 不碰静态单例', () async {
      final evicted = <String>[];
      final injected = PlaylistCoordinator(
        engine: engine,
        thumbnailEvict: evicted.add,
      );
      addTearDown(injected.dispose);
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);

      await injected.removeEntriesAt({0, 2});

      expect(evicted, ['a.mp4', 'c.mp4']);
      expect([for (final e in injected.entries.value) e.path], ['b.mp4']);
    });
  });

  group('BreakpointSampler', () {
    test('粘性 — 进 0 不回写, reset 归零', () {
      final sampler = BreakpointSampler()
        ..samplePosition(5000)
        ..sampleDuration(90000)
        ..samplePosition(0)
        ..sampleDuration(0);

      expect(sampler.positionMs, 5000);
      expect(sampler.durationMs, 90000);

      sampler.reset();
      expect(sampler.positionMs, 0);
      expect(sampler.durationMs, 0);
    });

    test('节流窗口 — 首次放行, 5s 内拒绝, 满 5s 再放行', () {
      final sampler = BreakpointSampler();
      var now = DateTime(2026, 1, 1);

      expect(sampler.tryAcquireSaveWindow(now), isTrue);
      now = now.add(const Duration(seconds: 4));
      expect(sampler.tryAcquireSaveWindow(now), isFalse);
      now = now.add(const Duration(seconds: 1));
      expect(sampler.tryAcquireSaveWindow(now), isTrue);
    });
  });

  group('applyBreakpoint', () {
    test('中途位置 — 写入位置/时长/时间戳, 保留 addedSeq', () {
      final base = PlaylistItem(path: 'a.mp4', addedSeq: 7);

      final updated = applyBreakpoint(
        base,
        positionMs: 40000,
        durationMs: 100000,
        nowMs: 123,
      );

      expect(updated.positionMs, 40000);
      expect(updated.durationMs, 100000);
      expect(updated.timestamp, 123);
      expect(updated.addedSeq, 7);
    });

    test('近 EOF — 真正清为 null (copyWith 做不到), 时长未知保留旧值', () {
      final base = PlaylistItem(
        path: 'a.mp4',
        positionMs: 30000,
        durationMs: 80000,
        addedSeq: 1,
      );

      final updated = applyBreakpoint(
        base,
        positionMs: 99000,
        durationMs: 0, // 时长未知 — 但 position>0 且 duration<=0 → 保留位置
        nowMs: 5,
      );
      expect(updated.positionMs, 99000);

      final finished = applyBreakpoint(
        base,
        positionMs: 99000,
        durationMs: 100000,
        nowMs: 5,
      );
      expect(finished.positionMs, isNull);
      expect(finished.durationMs, 100000);
    });
  });

  group('BreakpointRecorder', () {
    test('无主记录 (无元数据且不在视图) 跳过; 在视图则兜底登记', () {
      final meta = PlaylistMetaCache();
      final sampler = BreakpointSampler()
        ..samplePosition(1000)
        ..sampleDuration(50000);
      var allowed = true;
      final recorder = BreakpointRecorder(
        meta: meta,
        sampler: sampler,
        isAllowed: () => allowed,
      );

      expect(recorder.record('ghost.mp4', inView: false), isNull);
      expect(meta['ghost.mp4'], isNull, reason: '不产生孤儿断点');

      final item = recorder.record('real.mp4', inView: true);
      expect(item?.positionMs, 1000);
      expect(meta['real.mp4'], same(item));

      allowed = false;
      expect(recorder.record('real.mp4', inView: true), isNull);
    });
  });

  group('PlaylistMetaCache', () {
    test('itemFor 单调分配 addedSeq; restore 推进序号不冲突', () {
      final meta = PlaylistMetaCache();
      expect(meta.itemFor('a').addedSeq, 0);
      expect(meta.itemFor('b').addedSeq, 1);
      expect(identical(meta.itemFor('a'), meta.itemFor('a')), isTrue);

      meta.restore([PlaylistItem(path: 'x', addedSeq: 41)]);
      expect(meta.itemFor('new').addedSeq, 42);

      meta.remove('a');
      expect(meta['a'], isNull);
    });
  });

  group('PlaylistResumeSeeker', () {
    test('低位锁存 + 时长有效才触发, 一次性消费', () {
      fakeAsync((async) {
        final seeker = PlaylistResumeSeeker()..arm(30000);

        // 上曲残留高位 position — 不触发.
        expect(seeker.onPosition(liveMs: 50000, engineDurationMs: 9000), null);
        // 低位但时长未就绪 — 不触发.
        expect(seeker.onPosition(liveMs: 100, engineDurationMs: 0), null);
        // 低位 + 时长有效 → 返回挂起位置并清除.
        expect(seeker.onPosition(liveMs: 100, engineDurationMs: 9000), 30000);
        expect(seeker.hasPending, isFalse);
        expect(seeker.onPosition(liveMs: 100, engineDurationMs: 9000), null);
        seeker.dispose();
      });
    });

    test('onDuration 首次有效即补齐; 超时 5s 放弃挂起', () {
      fakeAsync((async) {
        final seeker = PlaylistResumeSeeker()..arm(1000);
        expect(seeker.onDuration(0), null);
        expect(seeker.onDuration(80000), 1000);

        seeker.arm(2000);
        async.elapse(const Duration(seconds: 5));
        expect(seeker.hasPending, isFalse, reason: '超时放弃, 不悬挂');
        expect(seeker.onDuration(80000), null);
        seeker.dispose();
      });
    });
  });

  group('QueueObserver', () {
    test('重复快照不产生内容变化; index 变化产出切曲; 清空产出停止', () {
      final observer = QueueObserver();
      final paths = List<String>.unmodifiable(['a', 'b']);

      final first = observer.observe(paths, 0);
      expect(first?.queueChanged, isTrue);
      expect(first?.currentPlayingPath, 'a');
      expect(first?.previousPlayingPath, isNull);

      // 内容相同的重复快照 — 无队列变化、无切曲 (调用方据此零重建零落盘).
      final repeat = observer.observe(List<String>.of(paths), 0);
      expect(repeat?.queueChanged, isFalse);
      expect(repeat?.playingChanged, isFalse);

      final switched = observer.observe(paths, 1);
      expect(switched?.queueChanged, isFalse);
      expect(switched?.previousPlayingPath, 'a');
      expect(switched?.currentPlayingPath, 'b');
      expect(switched?.playingChanged, isTrue);

      final cleared = observer.observe(const <String>[], -1);
      expect(cleared?.queueChanged, isTrue);
      expect(cleared?.currentPlayingPath, isNull);
      expect(observer.playingPath, isNull);
    });
  });
}
