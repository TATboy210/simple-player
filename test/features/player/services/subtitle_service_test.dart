// ignore_for_file: no-empty-block, avoid-passing-async-when-sync-expected, avoid-dynamic, avoid-redundant-async, avoid-self-compare, avoid-unnecessary-type-assertions, avoid-unused-parameters
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/subtitle_service.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

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

    test('detectAndLoad matches movie.<lang>.srt to the exact path', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/movie.chinese.srt');
      await mediaFile.create();
      await subFile.create();

      await service.detectAndLoad(mediaFile.path);
      expect(
        engine.lastSubtitle,
        subFile.path.replaceAll('/', Platform.pathSeparator),
      );
    });

    test('detectAndLoad ignores a subtitle of another media file', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/other.srt');
      await mediaFile.create();
      await subFile.create();

      await service.detectAndLoad(mediaFile.path);
      expect(engine.lastSubtitle, isNull);
    });

    test('detectAndLoad skips loading when the request is stale', () async {
      // 快速连续切文件: 旧文件的目录扫描晚于新请求完成, 不得把旧字幕挂到新文件.
      final mediaFile = File('${tempDir.path}/movie.mp4');
      await mediaFile.create();
      await File('${tempDir.path}/movie.srt').create();

      await service.detectAndLoad(mediaFile.path, isStale: () => true);
      expect(engine.lastSubtitle, isNull);

      await service.detectAndLoad(mediaFile.path, isStale: () => false);
      expect(engine.lastSubtitle, isNotNull);
    });

    test('subtitleExtensions contains common formats', () {
      expect(SubtitleService.subtitleExtensions, contains('.srt'));
      expect(SubtitleService.subtitleExtensions, contains('.ass'));
      expect(SubtitleService.subtitleExtensions, contains('.vtt'));
      expect(SubtitleService.subtitleExtensions, contains('.sub'));
    });

    test('detectAndLoad finds matching subtitle asynchronously', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/movie.srt');
      await mediaFile.create();
      await subFile.create();

      await service.detectAndLoad(mediaFile.path);
      expect(
        engine.lastSubtitle,
        subFile.path.replaceAll('/', Platform.pathSeparator),
      );
    });

    test('detectAndLoad finds subtitle with language tag async', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final subFile = File('${tempDir.path}/movie.english.ass');
      await mediaFile.create();
      await subFile.create();

      await service.detectAndLoad(mediaFile.path);
      expect(engine.lastSubtitle, isNotNull);
    });

    test('detectAndLoad ignores non-subtitle files', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final txtFile = File('${tempDir.path}/movie.txt');
      await mediaFile.create();
      await txtFile.create();

      await service.detectAndLoad(mediaFile.path);
      expect(engine.lastSubtitle, isNull);
    });

    test('detectAndLoad handles missing directory', () async {
      await service.detectAndLoad('/nonexistent/path/movie.mp4');
      expect(engine.lastSubtitle, isNull);
    });

    test('detectAndLoad stops at the first match', () async {
      final mediaFile = File('${tempDir.path}/movie.mp4');
      final sub1 = File('${tempDir.path}/movie.srt');
      final sub2 = File('${tempDir.path}/movie.ass');
      await mediaFile.create();
      await sub1.create();
      await sub2.create();

      await service.detectAndLoad(mediaFile.path);
      // Should load exactly one subtitle (first match)
      expect(engine.lastSubtitle, isNotNull);
    });

    test('detectAndLoad loads all subtitle extensions', () async {
      for (final ext in ['.srt', '.ass', '.vtt', '.sub', '.ssa']) {
        final subDir = await Directory.systemTemp.createTemp('sub_ext_');
        try {
          final mediaFile = File('${subDir.path}/video.mp4');
          final subFile = File('${subDir.path}/video$ext');
          await mediaFile.create();
          await subFile.create();

          final fakeEngine = _FakeEngine();
          final svc = SubtitleService(fakeEngine);
          await svc.detectAndLoad(mediaFile.path);
          expect(
            fakeEngine.lastSubtitle,
            isNotNull,
            reason: 'Extension $ext should match',
          );
        } finally {
          if (await subDir.exists()) await subDir.delete(recursive: true);
        }
      }
    });
  });
}
