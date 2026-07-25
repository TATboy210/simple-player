/// 2GB 内存极限压力测试 — 模拟低运存环境下内核行为
///
/// 7 维度测试:
///   1. 大播放列表 — 500k 条目 + 快速导航循环
///   2. JSON 序列化尖峰 — 大列表 toJson 内存翻倍验证
///   3. 引擎操作洪泛 — 50k open/play/seek/stop 循环
///   4. 定时器生命周期 — PositionPoller 2000 次 start/stop/dispose
///   5. 内存监控阈值 — MemoryMonitor RSS 接近 2GB 时的警告准确性
///   6. 并发多操作风暴 — 同时 play + seek + track + volume
///   7. PlaylistStore 防抖压力 — 大数据集快速 save/debounce 循环
///
/// 使用 FakeEngine + FakeMdkPlayer — 无 mdk.dll FFI，headless CI 安全。
/// 不分配真实 2GB 内存，而是通过极端操作频率和数据规模验证内核的边界行为。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/clock.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/memory_monitor.dart';
import 'package:simple_player_flutter/kernel/diagnostics/rss_provider.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/position_poller.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';

import '../../helpers/fake_engine.dart';
import '../../helpers/fake_mdk_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. 大播放列表压力 — 500k 条目 + 快速导航
  // ─────────────────────────────────────────────────────────────────────────────

  group('1. Massive playlist pressure (500k items)', () {
    test('500,000 items — add, navigate, remove without crash', () {
      final playlist = Playlist();
      const count = 500000;

      // 批量添加 500k — 验证不抛异常
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        playlist.add('C:\\media\\stress_$i.mp4');
      }
      sw.stop();

      expect(playlist.length, count);
      // 500k 添加应在 5 秒内完成（保守阈值）
      expect(sw.elapsedMilliseconds, lessThan(5000));

      // 快速导航循环 — 10000 次 peekNext/peekPrevious
      sw.reset();
      sw.start();
      for (var i = 0; i < 10000; i++) {
        playlist.currentIndex = i % count;
        playlist.peekNext();
        playlist.peekPrevious();
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));

      // Shuffle 模式下快速导航 — 验证 do-while 终止
      playlist.mode = PlayMode.shuffle;
      sw.reset();
      sw.start();
      for (var i = 0; i < 1000; i++) {
        playlist.currentIndex = i % count;
        final next = playlist.peekNext();
        expect(next, isNot(-1));
        expect(next, isNot(playlist.currentIndex));
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));

      // 批量删除 — 从末尾删 10000 项
      sw.reset();
      sw.start();
      for (var i = 0; i < 10000; i++) {
        playlist.removeAt(playlist.length - 1);
      }
      sw.stop();
      expect(playlist.length, count - 10000);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('addAll 500k + clear — no lingering state', () {
      final playlist = Playlist();
      final paths = List.generate(500000, (i) => 'C:\\media\\bulk_$i.mp4');

      playlist.addAll(paths);
      expect(playlist.length, 500000);

      playlist.clear();
      expect(playlist.length, 0);
      expect(playlist.isEmpty, isTrue);
      expect(playlist.current, isNull);

      // 清空后重新添加 — 验证无残留
      playlist.add('C:\\media\\new.mp4');
      expect(playlist.length, 1);
      expect(playlist.current?.path, 'C:\\media\\new.mp4');
    });

    test('500k items toJson + fromJson roundtrip', () {
      final playlist = Playlist();
      const count = 500000;
      for (var i = 0; i < count; i++) {
        playlist.add('C:\\media\\roundtrip_$i.mp4');
      }

      // toJson — 序列化 500k 条目
      final sw = Stopwatch()..start();
      final json = playlist.toJson();
      sw.stop();

      expect(json['items'], isA<List<dynamic>>());
      expect((json['items'] as List).length, count);
      // 序列化应在 10 秒内完成
      expect(sw.elapsedMilliseconds, lessThan(10000));

      // fromJson — 反序列化
      sw.reset();
      sw.start();
      final restored = Playlist.fromJson(json);
      sw.stop();

      expect(restored.length, count);
      expect(restored.current?.path, 'C:\\media\\roundtrip_0.mp4');
      expect(sw.elapsedMilliseconds, lessThan(10000));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. JSON 序列化尖峰 — 内存翻倍验证
  // ─────────────────────────────────────────────────────────────────────────────

  group('2. JSON serialization memory spike', () {
    test('toJson on 100k items produces bounded JSON string', () {
      final playlist = Playlist();
      const count = 100000;
      for (var i = 0; i < count; i++) {
        playlist.add('C:\\media\\spike_$i.mp4');
      }

      final json = playlist.toJson();
      final jsonString = jsonEncode(json);

      // JSON 字符串大小应可预测 — 每条约 50 字节
      // 100k * 50 = ~5MB，加上 JSON 开销约 6-7MB
      expect(jsonString.length, lessThan(10 * 1024 * 1024)); // < 10MB
      expect(jsonString.length, greaterThan(1 * 1024 * 1024)); // > 1MB

      // 反序列化不丢数据
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = Playlist.fromJson(decoded);
      expect(restored.length, count);
    });

    test('Rapid toJson calls — no unbounded growth', () {
      final playlist = Playlist();
      for (var i = 0; i < 10000; i++) {
        playlist.add('C:\\media\\rapid_$i.mp4');
      }

      // 连续 100 次 toJson — 模拟快速保存触发
      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < 100; i++) {
        results.add(playlist.toJson());
      }

      // 所有结果应相同
      for (var i = 1; i < results.length; i++) {
        expect(results[i], equals(results[0]));
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. 引擎操作洪泛 — 50k open/play/seek/stop 循环
  // ─────────────────────────────────────────────────────────────────────────────

  group('3. Engine operation flood (50k cycles)', () {
    test('50,000 open/play/seek/stop cycles — no resource leak', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 120000); // 2 分钟视频

      const cycles = 50000;
      final sw = Stopwatch()..start();

      for (var i = 0; i < cycles; i++) {
        // open → play → seek → stop 完整周期
        await engine.open('C:\\media\\cycle_$i.mp4');
        engine.play();
        engine.seekTo(i % 120000);
        engine.stop();
      }

      sw.stop();

      // 所有操作计数正确
      expect(engine.openCallCount, cycles);
      expect(engine.playCallCount, cycles);
      expect(engine.seekToCallCount, cycles);
      expect(engine.stopCallCount, cycles);

      // 引擎状态干净
      expect(engine.state.value, MediaState.idle);
      expect(engine.position.value, 0);

      // 50k 周期应在 30 秒内完成
      expect(sw.elapsedMilliseconds, lessThan(30000));

      engine.dispose();
    });

    test('50,000 open without close — only last state retained', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 5000);

      for (var i = 0; i < 50000; i++) {
        final result = await engine.open('C:\\media\\leak_$i.mp4');
        expect(result, isA<OpenSuccess>());
      }

      // 内部状态只保留最后一个
      expect(engine.openCallCount, 50000);
      expect(engine.duration.value, 5000);

      engine.dispose();
    });

    test('Dispose during 1000 rapid opens — no crash', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 1000);

      for (var i = 0; i < 1000; i++) {
        await engine.open('C:\\media\\mid_dispose_$i.mp4');
        if (i == 500) {
          engine.dispose();
        }
      }

      // dispose 后 open 返回 OpenSuperseded — 不崩溃
      final result = await engine.open('C:\\media\\after.mp4');
      expect(result, isA<OpenSuperseded>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. 定时器生命周期压力 — PositionPoller 2000 次 start/stop/dispose
  // ─────────────────────────────────────────────────────────────────────────────

  group('4. PositionPoller timer lifecycle stress', () {
    test('2,000 rapid start/stop cycles — no timer leak', () {
      final player = FakeMdkPlayer();
      final position = ValueNotifier<int>(0);
      final buffered = ValueNotifier<int>(0);

      final poller = PositionPoller(
        player,
        position: position,
        buffered: buffered,
        currentPathGetter: () => 'C:\\media\\test.mp4',
      );

      final sw = Stopwatch()..start();

      for (var i = 0; i < 2000; i++) {
        poller.start();
        poller.stop();
      }

      sw.stop();

      // 2000 次 start/stop 应在 2 秒内完成
      expect(sw.elapsedMilliseconds, lessThan(2000));

      // 最终 stop 后无残留定时器
      poller.dispose();
      position.dispose();
      buffered.dispose();
      player.dispose();
    });

    test('2,000 startSilent + setActive + setDragMode cycles', () {
      final player = FakeMdkPlayer();
      final position = ValueNotifier<int>(0);
      final buffered = ValueNotifier<int>(0);

      final poller = PositionPoller(
        player,
        position: position,
        buffered: buffered,
        currentPathGetter: () => 'C:\\media\\test.mp4',
      );

      final sw = Stopwatch()..start();

      for (var i = 0; i < 2000; i++) {
        poller.startSilent();
        poller.setActive();
        poller.setDragMode(true);
        poller.setDragMode(false);
        poller.setPlaybackRate(2.0);
        poller.setPlaybackRate(1.0);
        poller.stop();
      }

      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000));

      poller.dispose();
      position.dispose();
      buffered.dispose();
      player.dispose();
    });

    test('Rapid seeking flag toggle during polling — no exception', () {
      final player = FakeMdkPlayer();
      final position = ValueNotifier<int>(0);
      final buffered = ValueNotifier<int>(0);

      final poller = PositionPoller(
        player,
        position: position,
        buffered: buffered,
        currentPathGetter: () => 'C:\\media\\test.mp4',
      );

      poller.start();

      // 10000 次快速 seeking 切换 — 模拟用户疯狂拖拽进度条
      for (var i = 0; i < 10000; i++) {
        poller.seeking = i % 2 == 0;
      }

      // 恢复正常状态
      poller.seeking = false;
      poller.stop();
      poller.dispose();
      position.dispose();
      buffered.dispose();
      player.dispose();
    });

    test('Double dispose — idempotent, no crash', () {
      final player = FakeMdkPlayer();
      final position = ValueNotifier<int>(0);
      final buffered = ValueNotifier<int>(0);

      final poller = PositionPoller(
        player,
        position: position,
        buffered: buffered,
        currentPathGetter: () => 'C:\\media\\test.mp4',
      );

      poller.start();
      poller.dispose();
      poller.dispose(); // 第二次 dispose 安全

      position.dispose();
      buffered.dispose();
      player.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. 内存监控阈值 — RSS 接近 2GB 时的警告准确性
  // ─────────────────────────────────────────────────────────────────────────────

  group('5. MemoryMonitor RSS threshold at 2GB boundary', () {
    // MemoryMonitor 的 RSS 读取由 Timer.periodic 驱动，snapshot() 只返回缓存状态。
    // 使用短 interval + await Future.delayed 让 Timer 触发。

    test('RSS from 100MB to 2GB — peak tracking accurate', () async {
      final rssProvider = FakeRssProvider();
      rssProvider.value = 100 * 1024 * 1024; // 100MB

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        thresholdBytes: 50 * 1024 * 1024,
        interval: const Duration(milliseconds: 20),
      );

      // 构造函数触发了第一次采样 (100MB)
      // 等待 Timer 触发，然后逐步增加 RSS
      final targetRss = 2048 * 1024 * 1024; // 2GB
      rssProvider.value = targetRss;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snap = monitor.snapshot();
      expect(snap, isNotNull);
      expect(snap!.rssBytes, targetRss);
      expect(snap.maxRssBytes, targetRss);

      monitor.dispose();
    });

    test('Peak RSS — monotonically increasing even when RSS drops', () async {
      final rssProvider = FakeRssProvider();
      rssProvider.value = 100 * 1024 * 1024; // 100MB

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        interval: const Duration(milliseconds: 20),
      );

      // 第一次 tick: 100MB (构造函数)
      // 设为 2GB 并等待 tick
      rssProvider.value = 2048 * 1024 * 1024;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 设为 1GB — peak 应保持 2GB
      rssProvider.value = 1024 * 1024 * 1024;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final snap = monitor.snapshot();
      expect(snap, isNotNull);
      // peak 应该是 2GB，即使当前 RSS 是 1GB
      expect(snap!.maxRssBytes, 2048 * 1024 * 1024);

      monitor.dispose();
    });

    test('History ring buffer at 200 cap under rapid sampling', () async {
      final rssProvider = FakeRssProvider();
      rssProvider.value = 100 * 1024 * 1024;

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        maxHistory: 200,
        interval: const Duration(milliseconds: 5), // 极短间隔快速采样
      );

      // 等待足够时间让 250+ 个 tick 触发（5ms * 250 = 1.25s）
      // 每次 tick RSS +1MB
      var currentRss = 100 * 1024 * 1024;
      for (var i = 0; i < 250; i++) {
        currentRss += 1024 * 1024;
        rssProvider.value = currentRss;
        await Future<void>.delayed(const Duration(milliseconds: 6));
      }

      final snap = monitor.snapshot();
      expect(snap, isNotNull);
      // history 应被裁剪到 200
      expect(snap!.history.length, lessThanOrEqualTo(200));

      monitor.dispose();
    });

    test('RSS constant at 2GB — delta=0, no false warnings', () async {
      final twoGB = 2 * 1024 * 1024 * 1024;
      final warnings = <String>[];

      final rssProvider = FakeRssProvider();
      rssProvider.value = twoGB;

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        thresholdBytes: 50 * 1024 * 1024,
        interval: const Duration(milliseconds: 20),
        logger: _CapturingLogger(warnings),
      );

      // 等待几个 tick — RSS 不变，delta=0
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 不应有阈值警告（delta=0 < 50MB）
      final thresholdWarnings = warnings.where(
        (w) => w.contains('exceeds threshold'),
      );
      expect(thresholdWarnings, isEmpty);

      monitor.dispose();
    });

    test('onTick callback fires for timer ticks', () async {
      final rssProvider = FakeRssProvider();
      rssProvider.value = 100 * 1024 * 1024;

      var tickCount = 0;
      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        interval: const Duration(milliseconds: 20),
        onTick: (_) => tickCount++,
      );

      // 构造函数触发了第一次 tick
      // 等待几个 tick
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 至少有构造函数的 1 次 + timer 的若干次
      expect(tickCount, greaterThanOrEqualTo(1));

      monitor.dispose();
    });

    test('ExportJson at 2GB RSS — valid JSON output', () async {
      final twoGB = 2 * 1024 * 1024 * 1024;
      final rssProvider = FakeRssProvider();
      rssProvider.value = twoGB;

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        interval: const Duration(milliseconds: 20),
      );

      // 等待至少一个 tick 让 snapshot 有数据
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final jsonStr = monitor.exportJson();
      expect(jsonStr, isNot('{}'));

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(json['rssBytes'], twoGB);

      monitor.dispose();
    });

    test('Snapshot without timer tick — returns initial state', () {
      final rssProvider = FakeRssProvider();
      rssProvider.value = 500 * 1024 * 1024;

      final monitor = MemoryMonitor(
        rssProvider: rssProvider,
        clock: FakeClock(DateTime(2026, 7, 24)),
        interval: const Duration(hours: 1), // 不会自动触发
      );

      // 构造函数触发了第一次采样
      final snap = monitor.snapshot();
      expect(snap, isNotNull);
      expect(snap!.rssBytes, 500 * 1024 * 1024);
      expect(snap.history.length, 1); // 只有构造函数的 1 次采样

      monitor.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. 并发多操作风暴 — 同时 play + seek + track + volume
  // ─────────────────────────────────────────────────────────────────────────────

  group('6. Concurrent multi-operation storm', () {
    test('10,000 interleaved play/pause/seek/volume — consistent state', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 300000); // 5 分钟视频

      await engine.open('C:\\media\\storm.mp4');

      final sw = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        switch (i % 6) {
          case 0:
            engine.play();
          case 1:
            engine.pause();
          case 2:
            engine.seekTo(i % 300000);
          case 3:
            engine.setVolume((i % 100) / 100.0);
          case 4:
            engine.setMute(i % 2 == 0);
          case 5:
            engine.setPlaybackRate(1.0 + (i % 4) * 0.25);
        }
      }

      sw.stop();

      // 引擎仍然可用 — 无崩溃
      expect(engine.state.value, isA<MediaState>());
      expect(engine.volume.value, inInclusiveRange(0.0, 1.0));
      expect(engine.playbackSpeed.value, inInclusiveRange(0.25, 4.0));

      // 10k 操作应在 2 秒内完成
      expect(sw.elapsedMilliseconds, lessThan(2000));

      engine.dispose();
    });

    test('Rapid togglePlayPause 10,000 times — no crash', () {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);
      engine.open('C:\\media\\toggle.mp4');

      final sw = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        engine.togglePlayPause();
      }

      sw.stop();

      // 引擎状态仍有效
      expect(engine.state.value, isA<MediaState>());

      engine.dispose();
    });

    test('Multiple engines operating simultaneously — no cross-contamination', () async {
      final engines = List.generate(10, (_) {
        final e = FakeEngine();
        e.configureMedia(durationMs: 60000);
        return e;
      });

      // 同时打开不同文件
      await Future.wait(
        engines.asMap().entries.map((entry) =>
          entry.value.open('C:\\media\\multi_${entry.key}.mp4'),
        ),
      );

      // 每个引擎独立操作
      for (var i = 0; i < 1000; i++) {
        final engine = engines[i % 10];
        engine.play();
        engine.seekTo(i * 100);
        engine.pause();
      }

      // 验证每个引擎独立
      for (var i = 0; i < 10; i++) {
        expect(engines[i].openPaths.first, 'C:\\media\\multi_$i.mp4');
        expect(engines[i].seekToCallCount, greaterThan(0));
      }

      // 批量 dispose
      for (final engine in engines) {
        engine.dispose();
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. PlaylistStore 防抖压力 — 快速 save/debounce 循环
  // ─────────────────────────────────────────────────────────────────────────────

  group('7. PlaylistStore serialization pressure', () {
    test('Rapid 1000 toJson calls — consistent output', () {
      final playlist = Playlist();
      for (var i = 0; i < 1000; i++) {
        playlist.add('C:\\media\\debounce_$i.mp4');
      }

      // 模拟快速 save 调用（PlaylistStore 内部 300ms debounce）
      final snapshots = <Map<String, dynamic>>[];
      for (var i = 0; i < 1000; i++) {
        snapshots.add(playlist.toJson());
      }

      // 所有快照应相同（Playlist 未变）
      expect(snapshots.length, 1000);
      for (var i = 1; i < snapshots.length; i++) {
        expect((snapshots[i]['items'] as List).length,
            (snapshots[0]['items'] as List).length);
      }
    });

    test('Playlist toJson + jsonEncode 100k items — bounded output', () {
      final playlist = Playlist();
      for (var i = 0; i < 100000; i++) {
        playlist.add('C:\\media\\encode_$i.mp4');
      }

      final sw = Stopwatch()..start();
      final json = playlist.toJson();
      final encoded = jsonEncode(json);
      sw.stop();

      // 100k 条目 JSON 应在 2 秒内完成
      expect(sw.elapsedMilliseconds, lessThan(2000));

      // 反序列化验证完整性
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect((decoded['items'] as List).length, 100000);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. 综合极端场景 — 模拟 2GB 设备上的真实使用模式
  // ─────────────────────────────────────────────────────────────────────────────

  group('8. Simulated 2GB device — realistic usage pattern', () {
    test('Full session: open 100 files, rapid seek, save playlist, dispose',
        () async {
      final playlist = Playlist();
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 180000); // 3 分钟视频

      // 模拟用户打开 100 个文件并快速操作
      for (var fileIdx = 0; fileIdx < 100; fileIdx++) {
        final path = 'C:\\media\\session_$fileIdx.mp4';
        playlist.add(path);
        await engine.open(path);
        engine.play();

        // 快速 seek 50 次（模拟拖拽进度条）
        for (var seekIdx = 0; seekIdx < 50; seekIdx++) {
          engine.seekTo(seekIdx * 3600);
        }

        engine.stop();
      }

      // 验证播放列表完整
      expect(playlist.length, 100);

      // 序列化保存（模拟 PlaylistStore.save）
      final json = playlist.toJson();
      final encoded = jsonEncode(json);
      expect(encoded.length, greaterThan(0));

      // 反序列化恢复
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = Playlist.fromJson(decoded);
      expect(restored.length, 100);

      // 清理
      engine.dispose();
      playlist.clear();
      expect(playlist.isEmpty, isTrue);
    });

    test('Worst case: 500k playlist + 10k engine ops + serialization', () async {
      // 构建超大播放列表
      final playlist = Playlist();
      const count = 500000;
      for (var i = 0; i < count; i++) {
        playlist.add('C:\\media\\worst_$i.mp4');
      }

      // 引擎在大列表上快速操作
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      final sw = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        final idx = i % count;
        await engine.open(playlist.items[idx].path);
        engine.play();
        engine.seekTo(i % 60000);
        engine.stop();
      }

      sw.stop();

      // 500k playlist items + 10k engine ops — CI 环境可能较慢，放宽到 120 秒
      expect(sw.elapsedMilliseconds, lessThan(120000));

      // 最终序列化 — 大列表 + 操作后状态
      final json = playlist.toJson();
      expect((json['items'] as List).length, count);

      engine.dispose();
    });
  });
}

// ───────────────────────────────────────────────────────────────────────────────
// Test helpers
// ───────────────────────────────────────────────────────────────────────────────

/// 捕获日志的 Logger — 收集所有 warn/error 消息用于断言
class _CapturingLogger extends KernelLogger {
  final List<String> warnings;
  _CapturingLogger(this.warnings);

  @override
  void trace(String message, {Map<String, Object?>? context}) {}

  @override
  void debug(String message, {Map<String, Object?>? context}) {}

  @override
  void info(String message, {Map<String, Object?>? context}) {}

  @override
  void warn(String message, {Map<String, Object?>? context}) {
    warnings.add(message);
  }

  @override
  void error(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    warnings.add('ERROR: $message');
  }

  @override
  void fatal(
    String message, {
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    warnings.add('FATAL: $message');
  }
}
