import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart' show ImageProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simple_player_flutter/kernel/services/thumbnail_disk_cache.dart';
import 'package:simple_player_flutter/kernel/services/thumbnail_service.dart';

import '../../helpers/fake_thumbnail_provider.dart';

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

    /// 禁用磁盘层 — F/E 组专注 flight/epoch；
    /// resolve 抛 Exception（非 Error）→ DiskCache 永久降级（I9）
    ThumbnailDiskCache brokenDisk() => ThumbnailDiskCache(
          resolveDirectory: () async =>
              throw const FileSystemException('disk disabled'),
        );

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
}
