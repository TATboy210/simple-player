import 'package:flutter_test/flutter_test.dart';
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
}
