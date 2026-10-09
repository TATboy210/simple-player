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
        expect(PathValidator.isAllowedMedia('/video.mxf'), true);
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

    // N1: isUrl 对 scheme 前缀做大小写不敏感比较 — Windows 用户直觉全系统
    // 大小写不敏感, `HTTP://HOST/v.mp4` 不再被误判本地文件拒为
    // "不支持的文件类型"。白名单集合本身不变, 仅输入侧折叠大小写。
    group('isUrl scheme case-insensitive matching (N1)', () {
      test('recognises uppercase and mixed-case scheme prefixes', () {
        expect(PathValidator.isUrl('HTTP://example.com/v.mp4'), true);
        expect(PathValidator.isUrl('HTTPS://example.com/stream'), true);
        expect(PathValidator.isUrl('RtSp://192.168.1.1/s'), true);
      });

      test('keeps all 7 lowercase schemes recognised (regression)', () {
        expect(PathValidator.isUrl('http://example.com/v.mp4'), true);
        expect(PathValidator.isUrl('https://example.com/stream'), true);
        expect(PathValidator.isUrl('rtmp://live.example.com'), true);
        expect(PathValidator.isUrl('rtsp://192.168.1.1/stream'), true);
        expect(PathValidator.isUrl('srt://192.168.1.1:9000'), true);
        expect(PathValidator.isUrl('udp://example.com:1234'), true);
        expect(PathValidator.isUrl('tcp://example.com:1234'), true);
      });

      test('stays fail-closed: unknown scheme and scheme whitespace', () {
        // 未知 scheme 不进 URL 分支 — 大小写折叠不得放宽接受集
        expect(PathValidator.isUrl('FTP://host/v'), false);
        // scheme 后空白不算前缀 — 折叠后仍非 'http://' 前缀
        expect(PathValidator.isUrl('HTTP ://x/v'), false);
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

      // N1: validate 内层 http/https 结构化门与 isUrl 同步大小写不敏感 —
      // 否则大写 HTTP URL 通过 isUrl 却跳过 Uri authority 校验, 形成放行
      // `HTTP://`(无 authority) 的 fail-open 缺口。
      test('accepts uppercase HTTP URL (case + trim combined)', () {
        expect(PathValidator.validate('HTTP://example.com/v.mp4'), isNull);
        expect(PathValidator.validate('  HTTP://example.com/v.mp4  '), isNull);
      });

      test('still rejects malformed uppercase HTTP URL (fail-closed)', () {
        expect(PathValidator.validate('HTTP://'), isNotNull);
        expect(PathValidator.validate('HTTP:///path'), isNotNull);
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
