import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/persistence/playlist_store.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_store_test_');
    // R2-5: 使用 create() 注入临时目录，无需 mock platform channel
    PlaylistStore.reset(newInstance: PlaylistStore.create(storagePath: tempDir.path));
  });

  tearDown(() async {
    PlaylistStore.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('PlaylistStore', () {
    test('save/load round-trip persists playlist', () async {
      final playlist = Playlist();
      playlist.add('/video/test.mp4');
      playlist.add('/video/test2.mkv');

      PlaylistStore.save(playlist);
      await PlaylistStore.dispose();

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

      await PlaylistStore.dispose();

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
      await PlaylistStore.dispose();
    });

    test('save preserves currentIndex', () async {
      final playlist = Playlist();
      playlist.add('/a.mp4');
      playlist.add('/b.mp4');
      playlist.currentIndex = 1;

      PlaylistStore.save(playlist);
      await PlaylistStore.dispose();

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.currentIndex, 1);
    });

    test('save preserves play mode', () async {
      final playlist = Playlist();
      playlist.add('/a.mp4');
      playlist.mode = PlayMode.shuffle;

      PlaylistStore.save(playlist);
      await PlaylistStore.dispose();

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.mode, PlayMode.shuffle);
    });

    test('load handles corrupt JSON gracefully', () async {
      final f = File('${tempDir.path}/playlist.json');
      await f.writeAsString('{bad json!!!}');

      final loaded = await PlaylistStore.load();
      expect(loaded, isNull);
    });

    test('loadInBackground loads playlist in isolate', () async {
      final playlist = Playlist();
      playlist.add('/iso_a.mp4');
      playlist.add('/iso_b.mp4');
      playlist.currentIndex = 1;

      PlaylistStore.save(playlist);
      await PlaylistStore.dispose();

      final loaded = await PlaylistStore.loadInBackground();
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded.currentIndex, 1);
      expect(loaded.items[0].path, '/iso_a.mp4');
    });

    test('loadInBackground returns null on missing file', () async {
      await PlaylistStore.clear();
      final loaded = await PlaylistStore.loadInBackground();
      expect(loaded, isNull);
    });
  });

  group('PlaylistStore migration', () {
    test('migrates history.json into playlist', () async {
      // Write a playlist file
      final playlistFile = File('${tempDir.path}/playlist.json');
      await playlistFile.writeAsString('''
        {"mode":0,"currentIndex":0,"items":[{"path":"/existing.mp4"}]}
      ''');

      // Write a history file
      final historyFile = File('${tempDir.path}/history.json');
      await historyFile.writeAsString('''
        [{"path":"/existing.mp4","timestamp":12345,"positionMs":500},
         {"path":"/from_history.mkv","timestamp":99999,"positionMs":100}]
      ''');

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      // existing.mp4 should have merged metadata
      expect(loaded!.items[0].timestamp, 12345);
      // from_history.mkv should be added
      expect(loaded.length, 2);
      expect(loaded.items[1].path, '/from_history.mkv');
      // history.json should be deleted
      expect(await historyFile.exists(), isFalse);
    });

    test('migrates history.json when playlist is empty', () async {
      final historyFile = File('${tempDir.path}/history.json');
      await historyFile.writeAsString('''
        [{"path":"/old_video.mp4","timestamp":777,"positionMs":300}]
      ''');

      final loaded = await PlaylistStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.length, 1);
      expect(loaded.items[0].path, '/old_video.mp4');
      expect(loaded.items[0].timestamp, 777);
    });

    test('handles corrupt history.json gracefully', () async {
      final historyFile = File('${tempDir.path}/history.json');
      await historyFile.writeAsString('not valid json');

      final loaded = await PlaylistStore.load();
      // Should not crash, returns null or empty
      expect(loaded, isNull);
    });

    test('migrateHistory skips entries without path field', () async {
      final historyFile = File('${tempDir.path}/history.json');
      // Entry with no 'path' key — triggers inner catch block (line 169-170)
      await historyFile.writeAsString('[{"timestamp":123,"positionMs":500}]');

      final loaded = await PlaylistStore.load();
      // No valid entries → history deleted, returns null
      expect(loaded, isNull);
    });

    test('loadInBackground handles corrupt JSON via _loadPlaylistSync',
        () async {
      final f = File('${tempDir.path}/playlist.json');
      await f.writeAsString('{corrupt json!!!}');

      // _loadPlaylistSync catches FormatException, returns null
      // Then _migrateHistory runs (no history file) → returns null
      final loaded = await PlaylistStore.loadInBackground();
      expect(loaded, isNull);
    });
  });

  group('PlaylistStore error paths', () {
    test('clear does not throw when file does not exist', () async {
      await PlaylistStore.clear();
    });

    test('clear with previously saved data deletes file', () async {
      final playlist = Playlist();
      playlist.add('/test_clear.mp4');
      PlaylistStore.save(playlist);
      await PlaylistStore.dispose();

      final f = File('${tempDir.path}/playlist.json');
      expect(await f.exists(), isTrue);

      await PlaylistStore.clear();
      expect(await f.exists(), isFalse);
    });

    test('_flush retries on write failure', () async {
      // R2-5: 使用 create() 注入无效路径，无需 mock platform channel
      PlaylistStore.reset(newInstance: PlaylistStore.create(storagePath: '/nonexistent_dir_xyz'));

      final playlist = Playlist();
      playlist.add('/retry_test.mp4');
      PlaylistStore.save(playlist);
      // dispose triggers _flush — retries 3 times then gives up
      await PlaylistStore.dispose();

      // Restore valid instance for tearDown
      PlaylistStore.reset(newInstance: PlaylistStore.create(storagePath: tempDir.path));
    });
  });
}
