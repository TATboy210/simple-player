// ignore_for_file: avoid-unnecessary-type-assertions
/// PlaylistStore 持久化行为测试 (N6: 原子写 + .corrupt 检疫).
///
/// 全部走真实临时目录 (Directory.systemTemp) 端到端验证文件系统行为:
/// 损坏隔离 / 单代留存 / 崩溃残留清扫 / 失败注入历史保全 / schema 锁.
/// 无 libmpv FFI, headless 安全.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/persistence/playlist_store.dart';

/// 删除测试临时目录 — Windows 上 store 的 fire-and-forget 写入可能还握着
/// 文件句柄, 短暂重试规避 errno 32 (文件被占用).
/// 照抄 playlist_coordinator_test.dart 的 _deleteTempDir 惯例.
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

/// 构造注入临时目录的 store — 不触碰 path_provider.
PlaylistStore _storeFor(Directory dir) =>
    PlaylistStore(resolveDirectory: () async => dir);

/// 合法 v3 快照 — 默认 2 条目 (断点元数据齐备), 可注入锚点路径.
PersistedPlaylistSnapshot _snapshot({
  List<String> paths = const ['D:/a.mp4', 'D:/b.mp4'],
  String? lastPlayedPath,
}) {
  return PersistedPlaylistSnapshot(
    items: [
      for (var i = 0; i < paths.length; i++)
        PlaylistItem(path: paths[i], addedSeq: i),
    ],
    playMode: PlayMode.loopAll,
    lastPlayedPath: lastPlayedPath,
  );
}

/// 目录内以 `.corrupt` 结尾的文件数 — 单代上限断言用.
int _corruptFileCount(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.corrupt'))
    .length;

void main() {
  setUpAll(() {
    // Store 走 KernelLogger — 测试环境显式初始化 (项目惯例).
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('损坏隔离', () {
    test('损坏 JSON — load 返回 null 且文件改名 .corrupt 留存原始字节', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_corrupt');
      addTearDown(() => _deleteTempDir(tempDir));
      const broken = '{broken';
      await File('${tempDir.path}/playlist.json').writeAsString(broken);

      final loaded = await _storeFor(tempDir).load();

      expect(loaded, isNull);
      expect(
        File('${tempDir.path}/playlist.json').existsSync(),
        isFalse,
        reason: '损坏文件应已被改名隔离, 不再留在原路径',
      );
      final corrupt = File('${tempDir.path}/playlist.json.corrupt');
      expect(corrupt.existsSync(), isTrue, reason: '损坏现场必须可回溯');
      expect(await corrupt.readAsString(), broken, reason: '原始字节完整留存');
    });

    test('.corrupt 单代 — 再次隔离覆盖旧代, 磁盘恰有一份', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_single');
      addTearDown(() => _deleteTempDir(tempDir));
      const brokenOne = '{broken-generation-one';
      const brokenTwo = '{broken-generation-two-much-longer';
      final store = _storeFor(tempDir);

      // 第一代: 损坏 → 隔离
      await File('${tempDir.path}/playlist.json').writeAsString(brokenOne);
      expect(await store.load(), isNull);
      expect(
        await File('${tempDir.path}/playlist.json.corrupt').readAsString(),
        brokenOne,
      );

      // 第二代: 不同损坏内容 → 旧 .corrupt 被覆盖 (单系统调用 rename 替换)
      await File('${tempDir.path}/playlist.json').writeAsString(brokenTwo);
      expect(await store.load(), isNull);

      expect(
        await File('${tempDir.path}/playlist.json.corrupt').readAsString(),
        brokenTwo,
        reason: '仅保留最新一代, rename-over-existing 天然覆盖',
      );
      expect(_corruptFileCount(tempDir), 1, reason: '磁盘上任何时刻至多一代');
    });

    test('健康文件回归锁 — 合法 v3 快照 load 成功且不产生 .corrupt', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_healthy');
      addTearDown(() => _deleteTempDir(tempDir));
      final store = _storeFor(tempDir);
      await store.save(_snapshot(lastPlayedPath: 'D:/a.mp4'));

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.items.map((e) => e.path), ['D:/a.mp4', 'D:/b.mp4']);
      expect(loaded.playMode, PlayMode.loopAll);
      expect(loaded.lastPlayedPath, 'D:/a.mp4');
      expect(
        File('${tempDir.path}/playlist.json.corrupt').existsSync(),
        isFalse,
        reason: '健康文件零副作用',
      );
    });

    test('无文件 — load 返回 null 且不产生 .corrupt（现状守护）', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_empty');
      addTearDown(() => _deleteTempDir(tempDir));

      final loaded = await _storeFor(tempDir).load();

      expect(loaded, isNull);
      expect(
        File('${tempDir.path}/playlist.json.corrupt').existsSync(),
        isFalse,
        reason: '无文件时不得凭空制造检疫文件',
      );
    });
  });

  group('原子发布', () {
    test('resolveDirectory 抛异常 — save 静默且历史文件无损可回读', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_fail');
      addTearDown(() => _deleteTempDir(tempDir));
      final goodStore = _storeFor(tempDir);
      await goodStore.save(_snapshot(lastPlayedPath: 'D:/a.mp4'));
      final before = await File('${tempDir.path}/playlist.json').readAsString();

      // 注入目录解析失败 — 模拟磁盘/权限故障
      final failingStore = PlaylistStore(
        resolveDirectory: () async => throw Exception('injected io failure'),
      );
      await failingStore.save(_snapshot(paths: ['D:/x.mp4']));

      final after = await File('${tempDir.path}/playlist.json').readAsString();
      expect(after, before, reason: '失败仅记日志, 历史文件字节不变');
      final loaded = await goodStore.load();
      expect(loaded!.items.map((e) => e.path), [
        'D:/a.mp4',
        'D:/b.mp4',
      ], reason: '历史快照仍完整可 load');
    });

    test('写中断残留 — load 无视 .part, save 后残留被清扫且目标完整', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_part');
      addTearDown(() => _deleteTempDir(tempDir));
      final store = _storeFor(tempDir);

      // 预置合法快照 A (2 条目) + 伪造崩溃中断残留 (截断 JSON)
      await store.save(_snapshot(lastPlayedPath: 'D:/a.mp4'));
      final part = File('${tempDir.path}/playlist.json.1728000000000-1.part');
      await part.writeAsString('{"version": 3, "ite');

      // load 无视残留, 返回快照 A
      final loadedA = await store.load();
      expect(loadedA, isNotNull);
      expect(loadedA!.items.map((e) => e.path), ['D:/a.mp4', 'D:/b.mp4']);

      // save 快照 B → 残留被清扫, 目标始终完整可解析
      await store.save(_snapshot(paths: ['D:/c.mp4']));
      final loadedB = await store.load();
      expect(loadedB!.items.map((e) => e.path), ['D:/c.mp4']);
      expect(part.existsSync(), isFalse, reason: '崩溃 .part 残留应被成功发布后的清扫删除');
      final raw = await File('${tempDir.path}/playlist.json').readAsString();
      expect(
        jsonDecode(raw),
        isA<Map<String, dynamic>>(),
        reason: 'playlist.json 任何时刻都是完整 JSON',
      );
    });

    test('schema 红线锁 — save 后顶层键集合与值符合 v3 契约', () async {
      final tempDir = await Directory.systemTemp.createTemp('plstore_schema');
      addTearDown(() => _deleteTempDir(tempDir));
      await _storeFor(tempDir).save(_snapshot(lastPlayedPath: 'D:/a.mp4'));

      final raw = await File('${tempDir.path}/playlist.json').readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      // 顶层键集合精确锁定 — 序列化构造不得因原子写改造而变化
      expect(decoded.keys.toSet(), {
        'version',
        'playMode',
        'sortKey',
        'sortAscending',
        'lastPlayedPath',
        'items',
      });
      expect(decoded['version'], 3);
      expect(decoded['playMode'], 'loopAll');
      expect(decoded['sortKey'], 'addedOrder');
      expect(decoded['sortAscending'], true);
      expect(decoded['lastPlayedPath'], 'D:/a.mp4');
      expect(decoded['items'], isA<List<dynamic>>());
      expect((decoded['items'] as List<dynamic>).length, 2);
    });
  });
}
