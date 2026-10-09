import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/validation_error.dart';
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

    // N2: classify/messageFor 夹具表 — 逐行锁定 类别 + 消息文本。
    // 消息串必须与重构前 validate 的五条消息逐字节恒同
    // (威胁模型 T-261009fiy-02 零漂移红线); classify 是五分支判定的
    // 单一实现, validate 委托 classify + messageFor, 不并存两套分支。
    group('classify + messageFor 类别分类器 (N2)', () {
      // (输入, 期望类别, 期望消息) — message 仅在类别非 null 时有意义。
      // UNC 行用 isPathTraversal 实际检测的反斜杠形式 (\\srv\share);
      // `//srv/...` 行是零漂移锁定: 现行 validate 接受该形式
      // (isPathTraversal 只检测反斜杠 UNC), classify 不得改变这一决定。
      final fixtures = <(String, ValidationErrorType?, String?)>[
        ('', ValidationErrorType.empty, '路径为空'),
        ('   ', ValidationErrorType.empty, '路径为空'),
        ('http://', ValidationErrorType.invalidUrl, 'URL 格式无效: http://'),
        (
          'HTTP:///path',
          ValidationErrorType.invalidUrl,
          'URL 格式无效: HTTP:///path',
        ),
        (
          'C:/a\x01b.mp4',
          ValidationErrorType.controlCharacters,
          '路径包含非法控制字符: C:/a\x01b.mp4',
        ),
        ('../x.mp4', ValidationErrorType.pathTraversal, '路径不安全: ../x.mp4'),
        ('a\x00b.mp4', ValidationErrorType.pathTraversal, '路径不安全: a\x00b.mp4'),
        (
          '\\\\srv\\share\\v.mp4',
          ValidationErrorType.pathTraversal,
          '路径不安全: \\\\srv\\share\\v.mp4',
        ),
        // v0.0.12 S1: file URI 带远端 host — URI 解析等价裸 UNC,
        // 并入同一 pathTraversal 类别拒绝(同错误码/文案语义)。
        (
          'file://server/share/a.mp4',
          ValidationErrorType.pathTraversal,
          '路径不安全: file://server/share/a.mp4',
        ),
        ('~/v.mp4', ValidationErrorType.pathTraversal, '路径不安全: ~/v.mp4'),
        (
          'C:/test/file.txt',
          ValidationErrorType.unsupportedFormat,
          '不支持的文件类型: C:/test/file.txt',
        ),
        // 有效输入 — 不产生类别, validate 放行。
        ('C:/test/video.mp4', null, null),
        // v0.0.12 S1 对照组: 空 host 的 file URI 是本地盘路径,行为不变。
        ('file:///D:/local/a.mp4', null, null),
        ('rtsp://host/s', null, null),
        // N1 语义继承: 大写合法 http URL 经大小写不敏感 isUrl 放行。
        ('HTTP://example.com/v.mp4', null, null),
        // 零漂移锁定: 正斜杠 // 前缀现行即接受 (非 isPathTraversal 检测目标)。
        ('//srv/share/v.mp4', null, null),
      ];

      test('classify 类别 + messageFor/validate 消息逐行恒等', () {
        for (final (input, type, message) in fixtures) {
          expect(
            PathValidator.classify(input),
            type,
            reason: 'classify("$input") 应归类为 $type',
          );
          if (type == null) {
            expect(
              PathValidator.validate(input),
              isNull,
              reason: 'validate("$input") 应放行',
            );
          } else {
            expect(
              PathValidator.messageFor(type, input),
              message,
              reason: 'messageFor($type, "$input") 消息文本逐字节恒等',
            );
            expect(
              PathValidator.validate(input),
              message,
              reason: 'validate("$input") 与 messageFor 输出恒等',
            );
          }
        }
      });
    });

    // v0.0.12 S1: file:// URI 形态的 UNC 绕过拦截。
    // `file://server/share/a.mp4` 经 URI 解析等价 `\\server\share\a.mp4`,
    // 但 file scheme 不在 _urlSchemes 白名单,旧判定落进扩展名分支放行 —
    // 与裸 UNC 的 fail-closed 安全裁决冲突。修复后: file URI host 非空
    // 即远端共享,并入与裸 UNC 同类的 pathTraversal 拒绝;空 host
    // (`file:///D:/local`)是本地路径,行为不变。
    group('file:// URI UNC bypass (v0.0.12 S1)', () {
      test('rejects file URI with remote host — 同裸 UNC 类别 (fail-closed)', () {
        expect(
          PathValidator.classify('file://server/share/a.mp4'),
          ValidationErrorType.pathTraversal,
          reason: 'file URI 远端 host 与裸 UNC 同判 pathTraversal',
        );
        expect(
          PathValidator.validate('file://server/share/a.mp4'),
          '路径不安全: file://server/share/a.mp4',
          reason: '拒绝文案与裸 UNC 同族 (messageFor pathTraversal)',
        );
      });

      test('rejects uppercase FILE:// scheme (N1 大小写不敏感同法)', () {
        expect(
          PathValidator.classify('FILE://SERVER/SHARE/A.MP4'),
          ValidationErrorType.pathTraversal,
        );
        expect(PathValidator.validate('FILE://SERVER/SHARE/A.MP4'), isNotNull);
      });

      test('isPathTraversal detects file-URI UNC form', () {
        expect(
          PathValidator.isPathTraversal('file://server/share/a.mp4'),
          true,
          reason: 'file URI 形态 UNC 必须进遍历/网络路径检测',
        );
        // 对照 — 裸 UNC 同一判定族,维持既有红。
        expect(PathValidator.isPathTraversal(r'\\server\share\a.mp4'), true);
      });

      test('empty-host file URI (本地盘路径) 仍放行 — 对照组', () {
        expect(
          PathValidator.validate('file:///D:/local/a.mp4'),
          isNull,
          reason: '空 host file URI 是本地路径,不得误拒',
        );
        expect(PathValidator.isPathTraversal('file:///D:/local/a.mp4'), false);
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
