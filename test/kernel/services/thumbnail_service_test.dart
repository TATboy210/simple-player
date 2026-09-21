import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart' show ImageProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simple_player_flutter/kernel/services/thumbnail_disk_cache.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_service.dart';

import '../../helpers/fake_thumbnail_provider.dart';

/// 禁用磁盘层 — flight/gate 组专注协调逻辑；
/// resolve 抛 Exception（非 Error）→ DiskCache 永久降级（I9）
ThumbnailDiskCache brokenDisk() => ThumbnailDiskCache(
      resolveDirectory: () async =>
          throw const FileSystemException('disk disabled'),
    );

void main() {
  group('ThumbnailService', () {
    setUp(() {
      ThumbnailService.reset();
    });

    test('getThumbnail returns null for nonexistent file', () async {
      final result = await ThumbnailService.getThumbnail(
        'C:\\nonexistent\\file.mp4',
      );
      expect(result, isNull);
    });

    test('getThumbnail returns null for relative path (X3 identity guard)',
        () async {
      final result = await ThumbnailService.getThumbnail('relative/file.mp4');
      expect(result, isNull);
    });

    test('evict removes specific entry', () {
      // evict on nonexistent path should not throw
      ThumbnailService.evict('nonexistent.mp4');
    });

    test('clearCache clears all entries', () {
      // clearCache on empty cache should not throw
      ThumbnailService.clearCache();
    });

    test('reset clears impl and cache', () {
      ThumbnailService.reset();
      // After reset, getThumbnail should work (re-creates provider)
      expect(ThumbnailService.getThumbnail('test.mp4'), completes);
    });
  });

  group('ThumbnailService LRU ordering', () {
    setUp(() {
      ThumbnailService.reset();
    });

    test('touch on non-existent key is a no-op', () {
      ThumbnailService.touch('nonexistent.mp4');
      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.cacheKeys, isEmpty);
    });

    test('evict removes specific item from cache and others remain', () {
      // evict on empty cache should not throw
      ThumbnailService.evict('a.mp4');
      expect(ThumbnailService.cacheLength, equals(0));
    });

    test('clearCache removes all items', () {
      ThumbnailService.clearCache();
      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.cacheKeys, isEmpty);
    });

    test('cacheLength and cacheKeys are consistent after reset', () {
      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.cacheKeys, isEmpty);

      // After reset, still empty
      ThumbnailService.reset();
      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.cacheKeys, isEmpty);
    });

    test('touch on non-existent key does not corrupt cache state', () {
      // Touch a key that was never added
      ThumbnailService.touch('ghost.mp4');
      ThumbnailService.touch('ghost2.mp4');

      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.cacheKeys, isEmpty);

      // Evict should still be safe
      ThumbnailService.evict('ghost.mp4');
      expect(ThumbnailService.cacheLength, equals(0));
    });

    test('evict on non-existent key does not throw', () {
      expect(
        () => ThumbnailService.evict('does-not-exist.mp4'),
        returnsNormally,
      );
    });

    test('clearCache is idempotent', () {
      ThumbnailService.clearCache();
      ThumbnailService.clearCache();
      expect(ThumbnailService.cacheLength, equals(0));
    });
  });

  group('Cache Identity (P-Thumb v1.3.2 ID1-ID7)', () {
    late Directory tempDir;
    late File videoFile;

    setUp(() async {
      ThumbnailService.reset();
      tempDir = await Directory.systemTemp.createTemp('pthumb_identity');
      videoFile = File(p.join(tempDir.path, 'video.mp4'));
      await videoFile.writeAsString('A' * 10);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort — 临时目录清理失败不影响测试结论
      }
    });

    test('ID1: same file resolved twice yields same cacheKey', () async {
      final key1 = await ThumbnailService.resolveCacheKey(videoFile.path);
      final key2 = await ThumbnailService.resolveCacheKey(videoFile.path);

      expect(key1, isNotNull);
      expect(key1, equals(key2));
      // SHA-256 hex — 64 字符小写十六进制
      expect(key1!.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key1), isTrue);
    });

    test('ID2: size change yields different cacheKey after evict', () async {
      final key1 = await ThumbnailService.resolveCacheKey(videoFile.path);

      // R5 契约：文件变化后必须 evict 才能刷新 identity（memo 失效通道）
      ThumbnailService.evict(videoFile.path);
      await videoFile.writeAsString('A' * 20);
      final key2 = await ThumbnailService.resolveCacheKey(videoFile.path);

      expect(key1, isNotNull);
      expect(key2, isNotNull);
      expect(key1, isNot(equals(key2)));
    });

    test('ID3: mtime change yields different cacheKey after evict', () async {
      final key1 = await ThumbnailService.resolveCacheKey(videoFile.path);

      ThumbnailService.evict(videoFile.path);
      // 固定设置不同的明确 mtime — 避免依赖同毫秒内自然 mtime 变化
      await videoFile.setLastModified(
        DateTime.fromMillisecondsSinceEpoch(1000 * 60 * 60),
      );
      final key2 = await ThumbnailService.resolveCacheKey(videoFile.path);

      expect(key1, isNotNull);
      expect(key2, isNotNull);
      expect(key1, isNot(equals(key2)));
    });

    test('ID4: schema version change rotates the cache key', () {
      final v3 = ThumbnailService.cacheKeyFromCanonical(
        ThumbnailService.buildCanonicalString(
          schemaVersion: 'v3',
          path: 'C:\\v\\a.mp4',
          size: 10,
          modifiedMs: 1000,
        ),
      );
      final v4 = ThumbnailService.cacheKeyFromCanonical(
        ThumbnailService.buildCanonicalString(
          schemaVersion: 'v4',
          path: 'C:\\v\\a.mp4',
          size: 10,
          modifiedMs: 1000,
        ),
      );

      expect(v3, isNot(equals(v4)));
    });

    test('ID4b: any spec field change rotates the cache key', () {
      String keyFor({int? maxWidth, int? timeMs}) {
        return ThumbnailService.cacheKeyFromCanonical(
          ThumbnailService.buildCanonicalString(
            schemaVersion: 'v3',
            path: 'C:\\v\\a.mp4',
            size: 10,
            modifiedMs: 1000,
            maxWidth: maxWidth ?? 320,
            timeMs: timeMs ?? 1000,
          ),
        );
      }

      expect(keyFor(), isNot(equals(keyFor(maxWidth: 256))));
      expect(keyFor(), isNot(equals(keyFor(timeMs: 2000))));
    });

    test('ID5: path normalize collapses .. segments (ID5)', () {
      expect(
        ThumbnailService.normalizePathForTest('C:\\A\\..\\B\\file.mp4'),
        equals(ThumbnailService.normalizePathForTest('C:\\B\\file.mp4')),
      );
    });

    test('ID6: case-differing paths stay distinct (no lower-case)', () {
      expect(
        ThumbnailService.normalizePathForTest('C:\\B\\F.mp4'),
        isNot(equals(ThumbnailService.normalizePathForTest('C:\\B\\f.mp4'))),
      );
    });

    test('ID7: identity memo serves second resolution without stat',
        () async {
      await ThumbnailService.resolveCacheKey(videoFile.path);
      final statCallsAfterFirst = ThumbnailService.metrics.statCalls;

      await ThumbnailService.resolveCacheKey(videoFile.path);

      // memo 命中 — 第二次解析零 stat（I10 hot path 的前提）
      expect(ThumbnailService.metrics.statCalls, equals(statCallsAfterFirst));
      expect(ThumbnailService.metrics.identityMemoHits, equals(1));
    });

    test('evict clears identity memo (R5 contract)', () async {
      await ThumbnailService.resolveCacheKey(videoFile.path);
      final statCallsAfterFirst = ThumbnailService.metrics.statCalls;

      ThumbnailService.evict(videoFile.path);
      await ThumbnailService.resolveCacheKey(videoFile.path);

      // evict 后 memo 失效 — 重新 stat
      expect(ThumbnailService.metrics.statCalls,
          equals(statCallsAfterFirst + 1));
    });

    test('clearCache clears identity memo (R5 contract)', () async {
      await ThumbnailService.resolveCacheKey(videoFile.path);
      final statCallsAfterFirst = ThumbnailService.metrics.statCalls;

      ThumbnailService.clearCache();
      await ThumbnailService.resolveCacheKey(videoFile.path);

      expect(ThumbnailService.metrics.statCalls,
          equals(statCallsAfterFirst + 1));
    });
  });

  group('In-flight + Epoch (P-Thumb v1.3.2 F1-F5 / E1-E6)', () {
    late Directory tempDir;
    late File fileA;
    late File fileB;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pthumb_flight');
      fileA = File(p.join(tempDir.path, 'a.mp4'));
      fileB = File(p.join(tempDir.path, 'b.mp4'));
      await fileA.writeAsString('A' * 10);
      await fileB.writeAsString('B' * 10);
    });

    tearDown(() async {
      ThumbnailService.reset();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });

    test('F1: concurrent same-key requests coalesce to one decode',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();
      final f2 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      expect(fake.calls, equals(1));
      expect(ThumbnailService.metrics.coalescedJoins, equals(1));

      fake.release(fileA.path);
      final r1 = await f1;
      final r2 = await f2;
      expect(r1, isNotNull);
      expect(identical(r1, r2), isTrue); // join 拿同一实例
    });

    test('F2: ten same-key requests still decode once', () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final futures = <Future<ImageProvider?>>[
        ThumbnailService.getThumbnail(fileA.path),
      ];
      await pumpEventQueue();
      for (var i = 0; i < 9; i++) {
        futures.add(ThumbnailService.getThumbnail(fileA.path));
      }
      await pumpEventQueue();

      expect(fake.calls, equals(1));
      expect(ThumbnailService.metrics.coalescedJoins, equals(9));

      fake.release(fileA.path);
      for (final future in futures) {
        expect(await future, isNotNull);
      }
    });

    test('F3: different identities decode independently', () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      final f2 = ThumbnailService.getThumbnail(fileB.path);
      await pumpEventQueue();

      expect(fake.calls, equals(2));

      fake.release(fileA.path);
      fake.release(fileB.path);
      expect(await f1, isNotNull);
      expect(await f2, isNotNull);
    });

    test('F4/E4: old flight completing after new flight cannot commit',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      // evict 使 F1 失效（pathEpoch++）— 新请求 F2 注册
      ThumbnailService.evict(fileA.path);
      final f2 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      // 旧代 F1 晚完成 — 允许返回原请求，但不得 commit（§19.7）
      fake.release(fileA.path);
      final r1 = await f1;
      expect(r1, isNotNull);
      expect(ThumbnailService.cacheLength, equals(0));

      // 新代 F2 完成后正常 commit，且不被旧代完成破坏（E4）
      fake.release(fileA.path, bytes: makeJpegBytes(seed: 9));
      final r2 = await f2;
      expect(r2, isNotNull);
      expect(ThumbnailService.cacheLength, equals(1));
    });

    test('E2: clearCache during decode invalidates flight commit',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      ThumbnailService.clearCache();
      fake.release(fileA.path);

      final r1 = await f1;
      expect(r1, isNotNull); // 仍返回给原请求
      expect(ThumbnailService.cacheLength, equals(0)); // 无 commit
    });

    test('E3: request after evict creates fresh flight and commits',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();
      ThumbnailService.evict(fileA.path);
      fake.release(fileA.path);
      await f1; // 旧代降级返回，无 commit

      final f2 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();
      fake.release(fileA.path);
      final r2 = await f2;
      expect(r2, isNotNull);
      expect(ThumbnailService.cacheLength, equals(1)); // 新 flight commit
    });

    test('E5: clearCache inside disk-write window cannot commit (R7)',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      // 微任务序：release 恢复 _runFlight → write 在 _ensureDirectory
      // 让出 → clearCache 执行（穿透检查点 1）→ write 返回 → 检查点 2 拦截
      fake.release(fileA.path);
      scheduleMicrotask(() => ThumbnailService.clearCache());

      final r = await f1;
      expect(r, isNotNull); // 降级 MemoryImage
      expect(ThumbnailService.cacheLength, equals(0)); // 检查点 2 生效
    });

    test('E6: evict inside disk-write window cannot commit (R7)',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();

      fake.release(fileA.path);
      scheduleMicrotask(() => ThumbnailService.evict(fileA.path));

      final r = await f1;
      expect(r, isNotNull);
      expect(ThumbnailService.cacheLength, equals(0)); // 检查点 2 生效
    });

    test('provider exception yields null and releases the flight',
        () async {
      final fake = FakeThumbnailProvider()
        ..holdJobs = true
        ..error = const FileSystemException('decode failed');
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f1 = ThumbnailService.getThumbnail(fileA.path);
      await pumpEventQueue();
      fake.failJob(fileA.path, const FileSystemException('decode failed'));

      expect(await f1, isNull);
      expect(ThumbnailService.cacheLength, equals(0));
      expect(ThumbnailService.metrics.failures, equals(1));

      // flight 已出表 — 新请求不被旧失败卡住
      fake
        ..holdJobs = false
        ..error = null;
      final f2 = ThumbnailService.getThumbnail(fileA.path);
      expect(await f2, isNotNull);
    });
  });
  group('ConcurrencyGate (P-Thumb v1.3.2 G1-G5)', () {
    late Directory tempDir;
    late List<File> files;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pthumb_gate');
      // 10 个真实文件 — G1 需要 10 个并发请求
      files = List.generate(
        10,
        (i) => File(p.join(tempDir.path, 'v$i.mp4')),
      );
      for (final file in files) {
        await file.writeAsString('v' * 10);
      }
    });

    tearDown(() async {
      ThumbnailService.reset();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // best effort
      }
    });

    test('G1: ten concurrent requests never exceed two decodes', () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final futures = <Future<ImageProvider?>>[];
      for (final file in files) {
        futures.add(ThumbnailService.getThumbnail(file.path));
      }
      await pumpEventQueue();

      // gate 限流 — 第 3 个起的请求在队列中，未触达 provider
      expect(fake.peakActive, equals(2));
      expect(fake.calls, equals(2));

      // 逐个 release + pump — gate 排队者需微任务推进才能进入 provider
      for (final file in files) {
        fake.release(file.path);
        await pumpEventQueue();
      }
      for (final future in futures) {
        expect(await future, isNotNull);
      }
      expect(ThumbnailService.metrics.peakConcurrent, equals(2));
    });

    test('G2: first task throwing releases its slot for the next',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f0 = ThumbnailService.getThumbnail(files[0].path);
      final f1 = ThumbnailService.getThumbnail(files[1].path);
      final f2 = ThumbnailService.getThumbnail(files[2].path);
      await pumpEventQueue();

      // 2 进 provider、1 排队 — 第一个抛异常 → slot 释放 → 排队者进入
      fake.failJob(files[0].path, const FileSystemException('boom'));
      await pumpEventQueue();
      expect(fake.calls, equals(3)); // 第 3 个已进入 provider

      expect(await f0, isNull);
      fake.release(files[1].path);
      fake.release(files[2].path);
      expect(await f1, isNotNull);
      expect(await f2, isNotNull);
    });

    test('G3: task returning null releases its slot', () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f0 = ThumbnailService.getThumbnail(files[0].path);
      final f1 = ThumbnailService.getThumbnail(files[1].path);
      final f2 = ThumbnailService.getThumbnail(files[2].path);
      await pumpEventQueue();

      fake.releaseNull(files[0].path);
      await pumpEventQueue();
      expect(fake.calls, equals(3)); // null 结果同样归还 slot

      expect(await f0, isNull);
      fake.release(files[1].path);
      fake.release(files[2].path);
      expect(await f1, isNotNull);
      expect(await f2, isNotNull);
    });

    test('G4: third request queues while two decodes are active',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      ThumbnailService.reset(provider: fake, diskCache: brokenDisk());

      final f0 = ThumbnailService.getThumbnail(files[0].path);
      final f1 = ThumbnailService.getThumbnail(files[1].path);
      final f2 = ThumbnailService.getThumbnail(files[2].path);
      await pumpEventQueue();

      expect(fake.active, equals(2));
      expect(fake.calls, equals(2)); // 第 3 个尚未触达 provider
      expect(fake.peakActive, equals(2));

      fake.release(files[0].path);
      await pumpEventQueue(); // 第 3 个此时才进入 provider 并挂起 job
      fake.release(files[1].path);
      await pumpEventQueue();
      fake.release(files[2].path);
      await f0;
      await f1;
      await f2;
    });

    test('G5: clearCache while queued — old flights resolve without commit',
        () async {
      final fake = FakeThumbnailProvider()..holdJobs = true;
      // 真实磁盘层 — write 成功路径下验证“检查点拦住而非磁盘没写”
      ThumbnailService.reset(
        provider: fake,
        diskCache: ThumbnailDiskCache(resolveDirectory: () async => tempDir),
      );

      final f0 = ThumbnailService.getThumbnail(files[0].path);
      final f1 = ThumbnailService.getThumbnail(files[1].path);
      final f2 = ThumbnailService.getThumbnail(files[2].path);
      await pumpEventQueue();

      ThumbnailService.clearCache(); // globalEpoch++ 失效全部（含排队者）

      fake.release(files[0].path);
      await pumpEventQueue(); // 排队的第 3 个进入 provider
      fake.release(files[1].path);
      await pumpEventQueue();
      fake.release(files[2].path);
      await pumpEventQueue();

      expect(await f0, isNotNull); // 旧请求仍拿到结果（MemoryImage）
      expect(await f1, isNotNull);
      expect(await f2, isNotNull);
      expect(ThumbnailService.cacheLength, equals(0)); // 全部无 commit
      expect(fake.calls, equals(3)); // gate 不感知 epoch — 排队者照常执行
    });
  });
}

