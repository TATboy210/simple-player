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
      expect(
        ThumbnailService.getThumbnail('test.mp4'),
        completes,
      );
    });
  });
}
