import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/subtitle_path_validator.dart';

void main() {
  group('SubtitlePathValidator', () {
    test('accepts supported local subtitle paths case-insensitively', () {
      const paths = <String>[
        r'C:\Videos\movie.SRT',
        r'C:\Videos\movie.ass',
        r'C:\Videos\movie.ssa',
        r'C:\Videos\movie.sub',
        r'C:\Videos\movie.vtt',
        r'C:\Videos\movie.idx',
        r'C:\Videos\movie.sup',
        '/Users/test/字幕 movie.srt',
      ];

      for (final path in paths) {
        expect(
          SubtitlePathValidator.validate(path),
          isNull,
          reason: 'Expected $path to be a supported local subtitle path.',
        );
      }
    });

    test('rejects paths that cannot be passed safely to the subtitle engine', () {
      const paths = <String>[
        '',
        ' \t ',
        'C:\\Videos\\bad\n.srt',
        r'C:\Videos\..\secret.srt',
        'C:/Videos/../secret.srt',
        r'\\server\share\movie.srt',
        '//server/share/movie.srt',
        r'\\?\C:\Videos\movie.srt',
        'https://example.test/movie.srt',
        'file:///C:/Videos/movie.srt',
        r'C:\Videos\movie.txt',
      ];

      for (final path in paths) {
        expect(
          SubtitlePathValidator.validate(path),
          isNotNull,
          reason: 'Expected $path to be rejected at the subtitle boundary.',
        );
      }
    });

    test('accepts only existing regular files within the configured size limit', () async {
      final directory = await Directory.systemTemp.createTemp('subtitle_path_');
      addTearDown(() => directory.delete(recursive: true));
      final subtitle = File('${directory.path}${Platform.pathSeparator}movie.srt');
      await subtitle.writeAsString('1\n00:00:00,000 --> 00:00:01,000\nHello\n');

      expect(await SubtitlePathValidator.isLoadableLocalFile(subtitle.path), isTrue);
      expect(
        await SubtitlePathValidator.isLoadableLocalFile(directory.path),
        isFalse,
      );
    });
  });
}
