/// PlaylistCoordinator + PlaylistStore 服务层测试 (v0.0.5 Phase 3).
///
/// Coordinator: 引擎镜像同步/停止保留逻辑队列/path 键断点/磁盘恢复装载分支.
/// Store: JSON 往返 + 损坏容错. 全部 FakeEngine — 无 libmpv FFI, headless 安全.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';
import 'package:simple_player_flutter/kernel/persistence/playlist_store.dart';
import 'package:simple_player_flutter/kernel/services/playlist_coordinator.dart';

import '../../helpers/fake_engine.dart';

/// 删除测试临时目录 — Windows 上 Coordinator 的 fire-and-forget _save 可能
/// 还握着 playlist.json 句柄, 短暂重试规避 errno 32 (文件被占用).
Future<void> _deleteTempDir(Directory dir) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

/// 计数包装 — 断点节流落盘测试用（save 次数可观测, 内容仍真写盘）.
class _CountingStore extends PlaylistStore {
  _CountingStore({required super.resolveDirectory});

  int saveCount = 0;

  @override
  Future<void> save(PersistedPlaylistSnapshot snapshot) async {
    saveCount++;
    return super.save(snapshot);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Store/Coordinator 走 KernelLogger — 测试环境显式初始化 (项目惯例).
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late PlaylistCoordinator coordinator;

  setUp(() {
    engine = FakeEngine();
    coordinator = PlaylistCoordinator(engine: engine); // 纯内存 — store 测试单独跑
  });

  tearDown(() {
    coordinator.dispose();
    engine.dispose();
  });

  group('引擎镜像同步', () {
    test('装载队列 — entries 重建且顺序跟随引擎', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4'], startIndex: 0);

      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4', 'c.mp4'],
      );
      expect(coordinator.currentIndex.value, 0);
    });

    test('追加/移除 — 经引擎镜像回流', () async {
      await engine.openPlaylist(['a.mp4']);
      await coordinator.appendEntries(['b.mp4']);

      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4'],
      );

      await coordinator.removeEntryAt(0);

      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['b.mp4'],
      );
    });

    test('引擎 stop 清空装载队列 — 逻辑队列保留（停止不清面板）', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      expect(coordinator.entries.value, hasLength(2));

      await engine.stop();

      // 引擎镜像已清空…
      expect(engine.queuePaths.value, isEmpty);
      // …但逻辑队列（面板视图）保留.
      expect(coordinator.entries.value, hasLength(2));
    });

    test('打开新内容 — 逻辑队列被新装载覆盖', () async {
      await engine.openPlaylist(['old1.mp4', 'old2.mp4']);
      await engine.openPlaylist(['new.mp4']);

      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['new.mp4'],
      );
    });
  });

  group('断点续播', () {
    test('切曲时旧条目按 path 记断点（最后位置 + 时间戳）', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      engine.position.value = 42000; // 模拟 a.mp4 播到 42s

      await coordinator.playEntryAt(1); // 切到 b.mp4

      final a = coordinator.entries.value.firstWhere((e) => e.path == 'a.mp4');
      expect(a.positionMs, 42000);
      expect(a.durationMs, 100000);
      expect(a.timestamp, isNotNull);
    });

    test('换队列后切曲 — 旧队列断点保留, 新队列条目各自归属', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 90000;
      engine.position.value = 10000;
      await coordinator.playEntryAt(1); // 播 a 到 10s → 切到 b, a 记 10000

      // 换一个含 a 的新队列 — a 的旧断点应原样保留.
      await engine.openPlaylist(['x.mp4', 'a.mp4'], startIndex: 0);
      engine.position.value = 7000;
      await coordinator.playEntryAt(1); // 播 x → 切到 a, x 记 7000

      final a = coordinator.entries.value.firstWhere((e) => e.path == 'a.mp4');
      final x = coordinator.entries.value.firstWhere((e) => e.path == 'x.mp4');
      expect(a.positionMs, 10000); // 旧断点未错位到别的条目
      expect(x.positionMs, 7000);
    });
  });

  group('断点补全 (v0.0.6)', () {
    test('effectiveBreakpointMs — 近 EOF 规则纯函数', () {
      // 正常中途 — 保留.
      expect(PlaylistCoordinator.effectiveBreakpointMs(50000, 100000), 50000);
      // ≥ duration−5s — 视为看完.
      expect(PlaylistCoordinator.effectiveBreakpointMs(95000, 100000), isNull);
      // ≥ 98% — 视为看完.
      expect(PlaylistCoordinator.effectiveBreakpointMs(98000, 100000), isNull);
      // 未播放 — 不留断点.
      expect(PlaylistCoordinator.effectiveBreakpointMs(0, 100000), isNull);
      // 时长未知 — 位置有效即保留.
      expect(PlaylistCoordinator.effectiveBreakpointMs(42000, 0), 42000);
      // 短文件 (<5s) — 整个都在片尾阈值区, 永不留断点.
      expect(PlaylistCoordinator.effectiveBreakpointMs(3000, 4000), isNull);
      // 防御: 非法负值.
      expect(PlaylistCoordinator.effectiveBreakpointMs(-1, 100000), isNull);
    });

    test('stop 保留断点 — 粘性最后非零位置（修复停止清零）', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 0);
      engine.duration.value = 100000;
      engine.position.value = 42000;

      // FakeEngine.stop 同步置 position=0 先于 revision 回流 —
      // 与真机 _clearLoadedMediaState 时序同构, 复现"停止清零"场景.
      await engine.stop();

      final a = coordinator.entries.value.firstWhere((e) => e.path == 'a.mp4');
      expect(a.positionMs, 42000);
      expect(a.durationMs, 100000);
    });

    test('切曲竞态 — 新曲 position(0) 先到不污染旧曲断点', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      engine.position.value = 42000;

      // 模拟 mpv 真实时序: 新文件 position(0) 先于 playlist 事件到达.
      engine.position.value = 0;
      await coordinator.playEntryAt(1);

      final a = coordinator.entries.value.firstWhere((e) => e.path == 'a.mp4');
      expect(a.positionMs, 42000);
    });

    test('曲目切换后粘性取材重置 — 死文件不继承上曲断点', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      engine.position.value = 42000;
      await coordinator.playEntryAt(1); // a 记 42000, 粘性取材重置

      // b 是"死文件": position/duration 从不推进 (b 未被断点污染的前提).
      await coordinator.playEntryAt(0); // 切回 a — 给 b 记断点

      final b = coordinator.entries.value.firstWhere((e) => e.path == 'b.mp4');
      expect(b.positionMs, isNull); // 不是 42000 — 无上曲残留
    });

    test('节流落盘 — 5s 窗口内多次 position 只落盘一次', () async {
      final tempDir = await Directory.systemTemp.createTemp('bp_throttle_test');
      final store = _CountingStore(resolveDirectory: () async => tempDir);
      final coord = PlaylistCoordinator(engine: engine, store: store);
      addTearDown(() => coord.dispose());
      addTearDown(() => _deleteTempDir(tempDir));

      var now = DateTime(2026, 1, 1);
      coord.clock = () => now;

      await engine.openPlaylist(['a.mp4']);
      engine.duration.value = 100000;

      // 装载本身触发一次 _save (既有行为) — 以此为基线计数.
      final baseline = store.saveCount;
      expect(baseline, greaterThanOrEqualTo(1));

      engine.position.value = 1000; // 首次进度 → 立即落盘
      expect(store.saveCount, baseline + 1);

      now = now.add(const Duration(seconds: 1));
      engine.position.value = 2000; // 窗口内 → 不落盘
      expect(store.saveCount, baseline + 1);

      now = now.add(const Duration(seconds: 6));
      engine.position.value = 3000; // 窗口已过 → 落盘
      expect(store.saveCount, baseline + 2);

      // 当前曲目断点内容已随节流保存刷新.
      final a = coord.entries.value.firstWhere((e) => e.path == 'a.mp4');
      expect(a.positionMs, 3000);
    });
  });

  group('排序 (v0.0.6)', () {
    test('sortEntries 按名称 — 引擎队列物理重排, 当前 index 跟随', () async {
      await engine.openPlaylist(['c.mp4', 'a.mp4', 'b.mp4'], startIndex: 2);

      await coordinator.sortEntries(PlaylistSortKey.name);

      expect(engine.lastSortQueueTarget, ['a.mp4', 'b.mp4', 'c.mp4']);
      // 引擎镜像已重排 (FakeEngine 同构), 视图经 revision 回流重建.
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4', 'c.mp4'],
      );
      // 当前播放 b.mp4 (原 index 2) → 新 index 1 — 播放身份不丢.
      expect(coordinator.currentIndex.value, 1);
    });

    test('同键再次排序 — 翻转方向', () async {
      await engine.openPlaylist(['b.mp4', 'a.mp4']);

      await coordinator.sortEntries(PlaylistSortKey.name);
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4'],
      );

      await coordinator.sortEntries(PlaylistSortKey.name);
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['b.mp4', 'a.mp4'],
      );
    });

    test('停止态排序 — 仅重排逻辑队列, 引擎队列不动', () async {
      await engine.openPlaylist(['b.mp4', 'a.mp4']);
      await engine.stop(); // 引擎装载清空, 逻辑队列保留

      await coordinator.sortEntries(PlaylistSortKey.name);

      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4'],
      );
      expect(engine.queuePaths.value, isEmpty);
      // 下次点击装载时按排序后的逻辑队列装载.
      await coordinator.playEntryAt(0);
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4']);
    });

    test('addedOrder 排序 — 依 addedSeq 还原添加顺序 (物理重排后仍可逆)',
        () async {
      await engine.openPlaylist(['c.mp4', 'a.mp4', 'b.mp4']);

      await coordinator.sortEntries(PlaylistSortKey.name);
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4', 'c.mp4'],
      );

      await coordinator.sortEntries(PlaylistSortKey.addedOrder);
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['c.mp4', 'a.mp4', 'b.mp4'], // 添加顺序还原
      );
    });

    test('排序状态持久化 — 落盘含 sortKey/排序方向/addedSeq', () async {
      final tempDir = await Directory.systemTemp.createTemp('sort_persist');
      final store = PlaylistStore(resolveDirectory: () async => tempDir);
      final coord = PlaylistCoordinator(engine: engine, store: store);
      addTearDown(() => coord.dispose());
      addTearDown(() => _deleteTempDir(tempDir));

      await engine.openPlaylist(['b.mp4', 'a.mp4']);
      await coord.sortEntries(PlaylistSortKey.name);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.sortKey, PlaylistSortKey.name);
      expect(loaded.sortAscending, isTrue);
      expect(loaded.items.first.path, 'a.mp4');
      expect(loaded.items.first.addedSeq, isNotNull); // addedSeq 已持久化
    });

    test('恢复重放排序 — restoreFromDisk 按持久化排序键重排逻辑队列',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('sort_restore');
      final store = PlaylistStore(resolveDirectory: () async => tempDir);
      addTearDown(() => _deleteTempDir(tempDir));
      await store.save(
        PersistedPlaylistSnapshot(
          items: [
            PlaylistItem(path: 'b.mp4', addedSeq: 0),
            PlaylistItem(path: 'a.mp4', addedSeq: 1),
          ],
          playMode: PlayMode.loopAll,
          sortKey: PlaylistSortKey.name,
          sortAscending: true,
        ),
      );

      final restoring = PlaylistCoordinator(engine: engine, store: store);
      addTearDown(restoring.dispose);
      await restoring.restoreFromDisk();

      expect(
        [for (final e in restoring.entries.value) e.path],
        ['a.mp4', 'b.mp4'], // name 排序重放
      );
      expect(restoring.sortKey, PlaylistSortKey.name);
    });
  });

  group('shuffle 解耦 (v0.0.6)', () {
    test('随机播放不再乱序列表 — 面板顺序恒定 (bug 修复直接断言)', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4', 'c.mp4']);
      await coordinator.setPlayMode(PlayMode.shuffle);

      // 连续步进 — 旧实现此处会触发 mpv playlist-shuffle 物理重排.
      coordinator.next();
      coordinator.next();
      coordinator.next();

      expect(engine.lastSetPlayMode, PlayMode.shuffle);
      expect(
        [for (final e in coordinator.entries.value) e.path],
        ['a.mp4', 'b.mp4', 'c.mp4'],
      );
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(coordinator.currentIndex.value, isNonNegative);
    });

    test('shuffle 下切曲 — 断点仍按 path 正常记录', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      engine.duration.value = 100000;
      engine.position.value = 42000;
      await coordinator.setPlayMode(PlayMode.shuffle);

      coordinator.next(); // 随机跳走 — a 的断点照记

      final a = coordinator.entries.value.firstWhere((e) => e.path == 'a.mp4');
      expect(a.positionMs, 42000);
    });
  });

  group('playEntryAt 装载分支', () {
    test('停止态点击条目 — 重新装载完整逻辑队列并起播', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      await engine.stop(); // 引擎装载清空, 逻辑队列保留

      final ok = await coordinator.playEntryAt(1);

      expect(ok, isTrue);
      // 引擎重新装载了逻辑队列, 且从点击索引起播.
      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4']);
      expect(engine.lastOpenPlaylistStartIndex, 1);
      expect(engine.state.value, MediaState.playing);
    });

    test('引擎已装载同队列 — 直接 jumpTo（不重建装载）', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);
      final loadsBefore = engine.openPlaylistCallCount;

      await coordinator.playEntryAt(0);

      expect(engine.openPlaylistCallCount, loadsBefore); // 无新装载
      expect(engine.jumpedToIndices, [0]);
    });

    test('越界索引 — false', () async {
      await engine.openPlaylist(['a.mp4']);
      expect(await coordinator.playEntryAt(5), isFalse);
    });
  });

  group('播放模式', () {
    test('setPlayMode — 转发引擎（单一数据源）', () async {
      await coordinator.setPlayMode(PlayMode.shuffle);

      expect(coordinator.playMode.value, PlayMode.shuffle);
      expect(engine.lastSetPlayMode, PlayMode.shuffle);
    });

    test('next/previous — 薄委托引擎步进', () async {
      await engine.openPlaylist(['a.mp4', 'b.mp4']);

      expect(coordinator.next(), isTrue);
      expect(coordinator.currentIndex.value, 1);
      expect(coordinator.previous(), isTrue);
      expect(coordinator.currentIndex.value, 0);
    });
  });

  group('磁盘恢复', () {
    late Directory tempDir;
    late PlaylistStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_store_test');
      store = PlaylistStore(resolveDirectory: () async => tempDir);
    });

    tearDown(() => _deleteTempDir(tempDir));

    test('restoreFromDisk — 恢复逻辑队列与模式, 不装载引擎', () async {
      // 预置快照.
      await store.save(
        PersistedPlaylistSnapshot(
          items: [
            PlaylistItem(
              path: 'a.mp4',
              positionMs: 30000,
              durationMs: 90000,
              timestamp: 1700000000000,
            ),
            PlaylistItem(path: 'b.mp4'),
          ],
          playMode: PlayMode.loopSingle,
        ),
      );

      final restoring = PlaylistCoordinator(engine: engine, store: store);
      addTearDown(restoring.dispose);
      await restoring.restoreFromDisk();

      expect(restoring.entries.value, hasLength(2));
      expect(restoring.entries.value.first.positionMs, 30000);
      expect(restoring.playMode.value, PlayMode.loopSingle);
      // 不装载: 引擎队列仍空, state 仍 idle — 满足"恢复不自动播放".
      expect(engine.queuePaths.value, isEmpty);
      expect(engine.state.value, MediaState.idle);
    });

    test('恢复后点击条目 — 走装载分支并从该条目起播', () async {
      await store.save(
        PersistedPlaylistSnapshot(
          items: [PlaylistItem(path: 'a.mp4'), PlaylistItem(path: 'b.mp4')],
          playMode: PlayMode.loopAll,
        ),
      );
      final restoring = PlaylistCoordinator(engine: engine, store: store);
      addTearDown(restoring.dispose);
      await restoring.restoreFromDisk();

      await restoring.playEntryAt(1);

      expect(engine.queuePaths.value, ['a.mp4', 'b.mp4']);
      expect(engine.queueIndex.value, 1);
      expect(engine.state.value, MediaState.playing);
    });
  });

  group('PlaylistStore', () {
    late Directory tempDir;
    late PlaylistStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('playlist_store_test');
      store = PlaylistStore(resolveDirectory: () async => tempDir);
    });

    tearDown(() => _deleteTempDir(tempDir));

    test('save → load 往返保真', () async {
      await store.save(
        PersistedPlaylistSnapshot(
          items: [
            PlaylistItem(
              path: r'D:\v\a.mp4',
              positionMs: 12000,
              durationMs: 90000,
              timestamp: 1700000000000,
            ),
            PlaylistItem(path: r'D:\v\b.mp4'),
          ],
          playMode: PlayMode.shuffle,
        ),
      );

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.items, hasLength(2));
      expect(loaded.items.first.path, r'D:\v\a.mp4');
      expect(loaded.items.first.positionMs, 12000);
      expect(loaded.items.first.durationMs, 90000);
      expect(loaded.items.first.timestamp, 1700000000000);
      expect(loaded.items.last.positionMs, isNull);
      expect(loaded.playMode, PlayMode.shuffle);
    });

    test('无文件 — load 返回 null', () async {
      expect(await store.load(), isNull);
    });

    test('损坏 JSON — load 返回 null 不抛', () async {
      await File('${tempDir.path}/playlist.json').writeAsString('{broken');

      expect(await store.load(), isNull);
    });

    test('损坏条目跳过, 好条目保留', () async {
      await File('${tempDir.path}/playlist.json').writeAsString(
        '{"version":1,"playMode":"loopAll",'
        '"items":[{"path":"good.mp4"},{"positionMs":"bad"},'
        '"not-a-map",{"path":42}]}',
      );

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.items, hasLength(1));
      expect(loaded.items.first.path, 'good.mp4');
    });

    test('未知 playMode 回退 loopAll', () async {
      await File('${tempDir.path}/playlist.json').writeAsString(
        '{"version":1,"playMode":"bogus","items":[{"path":"a.mp4"}]}',
      );

      final loaded = await store.load();

      expect(loaded!.playMode, PlayMode.loopAll);
    });
  });
}
