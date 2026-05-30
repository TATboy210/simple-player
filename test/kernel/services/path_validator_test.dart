import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/path_validator.dart';

void main() {
  group('PathValidator', () {
    group('isAllowedMedia', () {
      test('accepts video extensions', () {
        expect(PathValidator.isAllowedMedia('/video.mp4'), true);
        expect(PathValidator.isAllowedMedia('/video.mkv'), true);
        expect(PathValidator.isAllowedMedia('/video.avi'), true);
        expect(PathValidator.isAllowedMedia('/video.webm'), true);
      });

      test('accepts audio extensions', () {
        expect(PathValidator.isAllowedMedia('/audio.mp3'), true);
        expect(PathValidator.isAllowedMedia('/audio.flac'), true);
        expect(PathValidator.isAllowedMedia('/audio.wav'), true);
        expect(PathValidator.isAllowedMedia('/audio.ogg'), true);
      });

      test('rejects non-media extensions', () {
        expect(PathValidator.isAllowedMedia('/file.txt'), false);
        expect(PathValidator.isAllowedMedia('/file.exe'), false);
        expect(PathValidator.isAllowedMedia('/file.jpg'), false);
      });

      test('rejects no extension', () {
        expect(PathValidator.isAllowedMedia('/noext'), false);
      });

      test('case insensitive', () {
        expect(PathValidator.isAllowedMedia('/VIDEO.MP4'), true);
        expect(PathValidator.isAllowedMedia('/Video.Mkv'), true);
      });

      test('accepts URLs', () {
        expect(
          PathValidator.isAllowedMedia('http://example.com/video.mp4'),
          true,
        );
        expect(
          PathValidator.isAllowedMedia('https://example.com/stream'),
          true,
        );
        expect(PathValidator.isAllowedMedia('rtmp://live.example.com'), true);
      });
    });

    group('isPathTraversal', () {
      test('detects null byte', () {
        expect(PathValidator.isPathTraversal('/safe\x00/path'), true);
      });

      test('detects path traversal', () {
        expect(
          PathValidator.isPathTraversal('/safe/../../../etc/passwd'),
          true,
        );
      });

      test('detects UNC path', () {
        expect(PathValidator.isPathTraversal('\\\\server\\share'), true);
      });

      test('detects home expansion', () {
        expect(PathValidator.isPathTraversal('~/secret'), true);
      });

      test('accepts safe paths', () {
        expect(PathValidator.isPathTraversal('/home/user/video.mp4'), false);
        expect(PathValidator.isPathTraversal('D:\\Videos\\movie.mkv'), false);
      });
    });

    group('validate', () {
      test('returns null for valid path', () {
        expect(PathValidator.validate('/video.mp4'), isNull);
      });

      test('returns error for empty path', () {
        expect(PathValidator.validate(''), isNotNull);
        expect(PathValidator.validate('  '), isNotNull);
      });

      test('returns error for traversal', () {
        expect(PathValidator.validate('/safe/../../../bad'), isNotNull);
      });

      test('returns error for non-media', () {
        expect(PathValidator.validate('/file.txt'), isNotNull);
      });

      test('returns null for URL', () {
        expect(PathValidator.validate('https://example.com/stream'), isNull);
      });
    });

    group('HTTP/HTTPS URL validation', () {
      test('accepts valid HTTP URL', () {
        expect(PathValidator.validate('http://example.com/video.mp4'), isNull);
      });

      test('accepts valid HTTPS URL', () {
        expect(PathValidator.validate('https://example.com/stream'), isNull);
      });

      test('rejects malformed HTTP URL', () {
        expect(PathValidator.validate('http://'), isNotNull);
      });

      test('rejects HTTP URL without authority', () {
        expect(PathValidator.validate('http:///path'), isNotNull);
      });
    });

    group('RTSP/RTMP protocol passthrough', () {
      test('RTSP URL skips validation', () {
        expect(PathValidator.validate('rtsp://192.168.1.1/stream'), isNull);
      });

      test('RTMP URL skips validation', () {
        expect(PathValidator.validate('rtmp://live.example.com'), isNull);
      });

      test('SRT URL skips validation', () {
        expect(PathValidator.validate('srt://192.168.1.1:9000'), isNull);
      });
    });

    group('control character filtering', () {
      test('rejects path with control character \\x01', () {
        expect(PathValidator.validate('/video\x01.mp4'), isNotNull);
      });

      test('rejects path with newline \\x0A', () {
        expect(PathValidator.validate('/video\n.mp4'), isNotNull);
      });

      test('rejects path with carriage return \\x0D', () {
        expect(PathValidator.validate('/video\r.mp4'), isNotNull);
      });

      test('accepts path with tab \\x09', () {
        expect(PathValidator.validate('/video\t.mp4'), isNull);
      });

      test('accepts normal path without control chars', () {
        expect(PathValidator.validate('/video.mp4'), isNull);
      });
    });

    group('filterValid', () {
      test('filters mixed list', () {
        final result = PathValidator.filterValid([
          '/video.mp4',
          '/file.txt',
          '/audio.flac',
          '/../../../bad',
          '',
        ]);
        expect(result, ['/video.mp4', '/audio.flac']);
      });
    });
  });
}
