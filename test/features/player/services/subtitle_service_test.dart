import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/services/subtitle_service.dart';
import 'package:simple_player_flutter/kernel/engine/media_engine.dart';

class _FakeEngine implements MediaEngine {
  String? lastSubtitle;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #setExternalSubtitle) {
      lastSubtitle = invocation.positionalArguments[0] as String?;
    }
    return null;
  }
}

void main() {
  group('SubtitleService', () {
    late Directory tempDir;
    late _FakeEngine engine;
    late SubtitleService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('subtitle_test_');
      engine = _FakeEngine();
      service = SubtitleService(engine);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('detectAndLoadSync finds matching subtitle', () async {
      // Create media file and matching subtitle
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/movie.srt');
      await mediaFile.create();
      await subFile.create();

      service.detectAndLoadSync(mediaFile.path);
      expect(engine.lastSubtitle, subFile.path.replaceAll('/', Platform.pathSeparator));
    });

    test('detectAndLoadSync finds subtitle with language tag', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/movie.chinese.srt');
      await mediaFile.create();
      await subFile.create();

      service.detectAndLoadSync(mediaFile.path);
      expect(engine.lastSubtitle, subFile.path.replaceAll('/', Platform.pathSeparator));
    });

    test('detectAndLoadSync ignores non-subtitle extensions', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final txtFile = File('${tempDir.path}/movie.txt');
      await mediaFile.create();
      await txtFile.create();

      service.detectAndLoadSync(mediaFile.path);
      expect(engine.lastSubtitle, isNull);
    });

    test('detectAndLoadSync ignores non-matching subtitle', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/other.srt');
      await mediaFile.create();
      await subFile.create();

      service.detectAndLoadSync(mediaFile.path);
      expect(engine.lastSubtitle, isNull);
    });

    test('detectAndLoadSync handles missing directory gracefully', () {
      service.detectAndLoadSync('/nonexistent/path/movie.mp4');
      expect(engine.lastSubtitle, isNull);
    });

    test('subtitleExtensions contains common formats', () {
      expect(SubtitleService.subtitleExtensions, contains('.srt'));
      expect(SubtitleService.subtitleExtensions, contains('.ass'));
      expect(SubtitleService.subtitleExtensions, contains('.vtt'));
      expect(SubtitleService.subtitleExtensions, contains('.sub'));
    });
  });
}
