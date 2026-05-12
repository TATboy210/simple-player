
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/persistence/playlist_store.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PlaylistStore.reset();
  });

  group('PlaylistStore', () {
    test('save/load round-trip persists playlist', () async {
      final playlist = Playlist();
      playlist.add('/video/test.mp4');
      playlist.add('/video/test2.mkv');

      PlaylistStore.save(playlist);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded.items[0].path, '/video/test.mp4');
      expect(loaded.items[1].path, '/video/test2.mkv');
    });

    test('load returns null or empty on missing file', () async {
      await PlaylistStore.clear();
      final loaded = await PlaylistStore.load();
      // Either null or empty playlist is acceptable
      if (loaded != null) {
        expect(loaded.length, 0);
      }
    });

    test('debounce coalesces rapid saves', () async {
      final p1 = Playlist();
      p1.add('/a.mp4');
      final p2 = Playlist();
      p2.add('/b.mp4');
      p2.add('/c.mkv');

      PlaylistStore.save(p1);
      PlaylistStore.save(p2); // should overwrite p1

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.length, 2); // p2's items, not p1's
      expect(loaded.items[0].path, '/b.mp4');
    });

    test('clear deletes file and cancels debounce', () async {
      final playlist = Playlist();
      playlist.add('/test.mp4');
      PlaylistStore.save(playlist);

      await PlaylistStore.clear();

      final loaded = await PlaylistStore.load();
      expect(loaded, isNull);
    });

    test('dispose flushes pending writes', () async {
      final playlist = Playlist();
      playlist.add('/flush.mp4');

      PlaylistStore.save(playlist);
      await PlaylistStore.dispose(); // should flush immediately

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.length, 1);
      expect(loaded.items[0].path, '/flush.mp4');
    });

    test('reset clears all state without crash', () async {
      final playlist = Playlist();
      playlist.add('/test.mp4');
      PlaylistStore.save(playlist);

      // Should not throw
      PlaylistStore.reset();

      // After reset, debounce is cancelled
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });

    test('save preserves currentIndex', () async {
      final playlist = Playlist();
      playlist.add('/a.mp4');
      playlist.add('/b.mp4');
      playlist.currentIndex = 1;

      PlaylistStore.save(playlist);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.currentIndex, 1);
    });
  });
}
