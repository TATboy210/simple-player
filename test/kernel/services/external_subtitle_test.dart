import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/features/player/services/playback_controller.dart';
import 'package:simple_player_flutter/features/player/services/subtitle_service.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;
  late Directory tempDir;

  setUp(() {
    // Mock platform channels to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return Directory.systemTemp.createTempSync('app_support').path;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});

    engine = FakeEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () {},
      onError: (_) {},
      subtitleService: SubtitleService(engine),
    );
    tempDir = Directory.systemTemp.createTempSync('subtitle_test_');
  });

  tearDown(() {
    // 清除 mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    // PlaylistStore.dispose() uses path_provider which isn't available in tests
    try {
      controller.dispose();
    } on Exception {
      // ignore path_provider MissingPluginException
    }
    engine.dispose();
    try {
      tempDir.deleteSync(recursive: true);
    } on Exception {
      // ignore cleanup failures
    }
  });

  /// Helper: create a file in tempDir with given name and optional content.
  File createFile(String name, [String content = '']) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  group('External subtitle auto-detection', () {
    test('detects .srt file with matching base name', () async {
      createFile('video.mp4');
      createFile('video.srt');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/video.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('video.srt'));
    });

    test('detects .ass file with matching base name', () async {
      createFile('movie.mp4');
      createFile('movie.ass');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/movie.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('movie.ass'));
    });

    test('detects .ssa file with matching base name', () async {
      createFile('film.mkv');
      createFile('film.ssa');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/film.mkv');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('film.ssa'));
    });

    test('detects .vtt file with matching base name', () async {
      createFile('clip.mp4');
      createFile('clip.vtt');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/clip.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('clip.vtt'));
    });

    test('detects subtitle with language tag (movie.en.srt)', () async {
      createFile('movie.mp4');
      createFile('movie.en.srt');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/movie.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 1);
      expect(engine.lastExternalSubtitlePath, contains('movie.en.srt'));
    });

    test('ignores subtitle files with different base name', () async {
      createFile('video.mp4');
      createFile('other.srt');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/video.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 0);
    });

    test('ignores non-subtitle extensions', () async {
      createFile('video.mp4');
      createFile('video.txt');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/video.mp4');
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 0);
    });

    test('handles missing directory gracefully (no crash)', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('Z:/nonexistent/path/video.mp4');
      // Should not throw
      await controller.playIndex(0);
      expect(engine.setExternalSubtitleCallCount, 0);
    });

    test('loads only the first matching subtitle', () async {
      createFile('video.mp4');
      createFile('video.srt');
      createFile('video.ass');
      engine.configureMedia(durationMs: 60000);
      playlist.add('${tempDir.path}/video.mp4');
      await controller.playIndex(0);
      // Should load exactly one subtitle (first match found)
      expect(engine.setExternalSubtitleCallCount, 1);
    });
  });
}
