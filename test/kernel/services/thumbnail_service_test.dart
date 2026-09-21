import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:simple_player_flutter/kernel/services/thumbnail_service.dart';

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
}
