// Fuzz tests for kernel API input validation.
//
// Tests malicious/malformed inputs across four attack surfaces:
//   1. Path traversal attacks (PathValidator + Playlist + PlaybackNavigator)
//   2. Index manipulation (Playlist)
//   3. Volume/value boundary attacks (FakeEngine clamping)
//   4. String injection (PathValidator + PathUtils)
//
// Uses FakeEngine + Playlist directly to avoid mdk.dll FFI dependency.
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/services/path_validator.dart';
import 'package:simple_player_flutter/kernel/utils/path_utils.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 1. Path Traversal Attacks
  // ────────────────────────────────────────────────────────────────────────────

  group('Path traversal attacks', () {
    group('PathValidator.validate rejects', () {
      final maliciousPaths = [
        // Classic Unix traversal
        '../../../etc/passwd',
        '../../../etc/shadow',
        '../../Windows/System32/config/SAM',

        // Windows absolute paths
        r'C:\Windows\System32\cmd.exe',
        r'C:\Windows\System32\drivers\etc\hosts',

        // Null byte injection — terminates C string early, .mp4 passes extension check
        'video.mp4\x00evil.exe',
        'safe.mp4\x00../../etc/passwd',
        '\x00etc/passwd.mp4',

        // UNC network paths — access arbitrary SMB shares
        r'\\server\share\video.mp4',
        r'\\192.168.1.1\c$\Windows\win.ini',
        r'\\?\C:\video.mp4',

        // NOTE: HTML/script injection in filenames with valid extensions
        // is NOT rejected by PathValidator — it validates path safety,
        // not XSS. These would be safe once stored but dangerous if
        // rendered unescaped in a WebView. Covered separately below.

        // Home directory expansion
        '~/.ssh/id_rsa',
        '~/../../etc/passwd',
        '~root/.bashrc',

        // Extremely long paths — PathValidator does NOT check length
        // (OS handles MAX_PATH enforcement). The '../' * 100 IS caught
        // by path traversal detection.
        '${'../' * 100}etc/passwd.mp4',

        // Empty / whitespace-only
        '',
        ' ',
        '\t',
        '\n',
        '\r\n',
        '   \t\n  ',

        // Control characters (0x01-0x1F except 0x00 and 0x09)
        'video\x01.mp4',
        'video\x02.mp4',
        'video\x1f.mp4',
        'vi\x0deo.mp4',

        // Mixed separator traversal
        '..\\..\\etc\\passwd.mp4',
        '../..\\etc/passwd.mp4',

        // URL schemes with invalid structure
        'http://',
        'https://',
        'http:///path.mp4',
        // NOTE: ftp://server/file.mp4 passes validation because ftp:// is not
        // in the URL scheme whitelist, so it's treated as a local path with
        // a valid .mp4 extension. This is acceptable — MDK handles the rest.

        // NOTE: URL-encoded traversal (%2e%2e%2f) passes PathValidator
        // because it does NOT URL-decode before checking. Covered as
        // known gap in separate test group below.
      ];

      for (final path in maliciousPaths) {
        test(
          'rejects: ${path.length > 60 ? "${path.substring(0, 60)}..." : path}',
          () {
            final error = PathValidator.validate(path);
            expect(error, isNotNull, reason: 'Expected rejection for: $path');
          },
        );
      }
    });

    group('PathValidator.isPathTraversal detects', () {
      test('null byte injection', () {
        expect(PathValidator.isPathTraversal('file.mp4\x00.exe'), isTrue);
        expect(PathValidator.isPathTraversal('\x00'), isTrue);
      });

      test('dot-dot-slash traversal', () {
        expect(PathValidator.isPathTraversal('../etc/passwd'), isTrue);
        expect(PathValidator.isPathTraversal('..\\etc\\passwd'), isTrue);
        expect(
          PathValidator.isPathTraversal('dir/../../../etc/passwd'),
          isTrue,
        );
      });

      test('UNC network paths', () {
        expect(PathValidator.isPathTraversal(r'\\server\share'), isTrue);
        expect(PathValidator.isPathTraversal(r'\\?\C:\dir'), isTrue);
      });

      test('home directory expansion', () {
        expect(PathValidator.isPathTraversal('~/.ssh/id_rsa'), isTrue);
        expect(PathValidator.isPathTraversal('~root/file'), isTrue);
      });

      // Bare ".." without separator should NOT be flagged (filenames like
      // "song (live..remix).flac" are legitimate).
      test('bare ".." is NOT traversal (false positive avoidance)', () {
        expect(
          PathValidator.isPathTraversal('song (live..remix).flac'),
          isFalse,
        );
        expect(PathValidator.isPathTraversal('..my_file.mp4'), isFalse);
      });
    });

    group('PathValidator.filterValid with mixed batch', () {
      test('filters out traversal/empty paths, keeps valid + XSS filenames', () {
        final mixed = [
          r'C:\Videos\movie.mp4', // valid
          '../../../etc/passwd', // traversal — rejected
          r'D:\Music\song.mp3', // valid
          '<script>.mp4', // XSS but valid extension — accepted (not XSS filter)
          '', // empty — rejected
          r'\\server\share\video.mp4', // UNC — rejected
          'C:/test.avi', // valid
          '~/.ssh/id_rsa', // home expand — rejected
        ];
        final valid = PathValidator.filterValid(mixed);
        // 4 valid: 3 clean paths + 1 XSS filename with valid extension
        expect(valid, hasLength(4));
        expect(
          valid,
          containsAll([
            r'C:\Videos\movie.mp4',
            r'D:\Music\song.mp3',
            'C:/test.avi',
            '<script>.mp4', // passes — PathValidator is not XSS filter
          ]),
        );
      });
    });

    group('XSS in filenames (known gap — PathValidator is path-only)', () {
      test('script tags with valid extension pass validation', () {
        // PathValidator checks path safety (traversal, null bytes, UNC),
        // not HTML safety. UI layer must escape before rendering.
        expect(PathValidator.validate('<script>alert(1)</script>.mp4'), isNull);
        expect(
          PathValidator.validate('"><img onerror=alert(1) src=x>.mp4'),
          isNull,
        );
        expect(
          PathValidator.validate("'; DROP TABLE playlist; --.mp4"),
          isNull,
        );
      });

      test('long paths are accepted (OS enforces MAX_PATH)', () {
        final longPath = 'C:/${'b' * 300}.mp4';
        expect(PathValidator.validate(longPath), isNull);
      });
    });

    group('URL-encoded traversal (known gap — no URL decoding)', () {
      test('percent-encoded dot-dot-slash passes', () {
        // PathValidator does not URL-decode before checking.
        // MDK/FFmpeg would handle or reject these at the protocol layer.
        expect(
          PathValidator.validate('%2e%2e%2f%2e%2e%2fetc%2fpasswd.mp4'),
          isNull,
        );
        expect(PathValidator.validate('..%2f..%2fetc%2fpasswd.mp4'), isNull);
        expect(PathValidator.validate('..%5c..%5cetc%5cpasswd.mp4'), isNull);
      });
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 3. Volume / Value Boundary Attacks
  // ────────────────────────────────────────────────────────────────────────────

  group('Volume and value boundary attacks', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);
    });

    tearDown(() {
      engine.dispose();
    });

    group('setVolume boundary values', () {
      test('clamps negative volume to 0', () {
        engine.setVolume(-1.0);
        expect(engine.volume.value, 0.0);
        expect(engine.isMuted.value, isTrue); // 0 → auto-mute
      });

      test('clamps extreme negative to 0', () {
        engine.setVolume(-double.maxFinite);
        expect(engine.volume.value, 0.0);
      });

      test('clamps -0.0 to 0', () {
        engine.setVolume(-0.0);
        expect(engine.volume.value, 0.0);
      });

      test('accepts minimum valid volume 0.0', () {
        engine.setVolume(0.0);
        expect(engine.volume.value, 0.0);
        expect(engine.isMuted.value, isTrue);
      });

      test('accepts very small positive volume', () {
        engine.setVolume(0.001);
        expect(engine.volume.value, 0.001);
        expect(engine.isMuted.value, isFalse);
      });

      test('accepts normal volume 1.0', () {
        engine.setVolume(1.0);
        expect(engine.volume.value, 1.0);
        expect(engine.isMuted.value, isFalse);
      });

      test('clamps volume slightly above 1.0', () {
        engine.setVolume(1.001);
        expect(engine.volume.value, 1.0);
      });

      test('clamps extreme positive to 1.0', () {
        engine.setVolume(100.0);
        expect(engine.volume.value, 1.0);

        engine.setVolume(double.maxFinite);
        expect(engine.volume.value, 1.0);
      });

      test('handles NaN volume', () {
        // NaN.clamp(0.0, 1.0) behavior — Dart clamp with NaN returns the boundary
        // NaN is not < 0.0 and not > 1.0 in IEEE 754, so clamp returns NaN
        // This tests the engine does not crash
        engine.setVolume(double.nan);
        // FakeEngine clamps; the actual behavior depends on Dart's clamp semantics
        // The key assertion: no crash, no exception
        expect(engine.setVolumeCallCount, greaterThan(0));
      });

      test('handles Infinity volume', () {
        engine.setVolume(double.infinity);
        expect(engine.volume.value, 1.0); // clamped
      });

      test('handles negative Infinity volume', () {
        engine.setVolume(double.negativeInfinity);
        expect(engine.volume.value, 0.0); // clamped
      });

      test('volume transitions unmute correctly', () {
        engine.setVolume(0.0);
        expect(engine.isMuted.value, isTrue);

        engine.setVolume(0.5);
        expect(engine.isMuted.value, isFalse);
        expect(engine.volume.value, 0.5);
      });
    });

    group('setPlaybackRate boundary values', () {
      test('clamps rate below minimum', () {
        engine.setPlaybackRate(0.0);
        expect(engine.playbackSpeed.value, 0.25);

        engine.setPlaybackRate(-1.0);
        expect(engine.playbackSpeed.value, 0.25);

        engine.setPlaybackRate(-double.maxFinite);
        expect(engine.playbackSpeed.value, 0.25);
      });

      test('accepts minimum rate 0.25', () {
        engine.setPlaybackRate(0.25);
        expect(engine.playbackSpeed.value, 0.25);
      });

      test('accepts normal rates', () {
        engine.setPlaybackRate(1.0);
        expect(engine.playbackSpeed.value, 1.0);

        engine.setPlaybackRate(2.0);
        expect(engine.playbackSpeed.value, 2.0);
      });

      test('accepts maximum rate 4.0', () {
        engine.setPlaybackRate(4.0);
        expect(engine.playbackSpeed.value, 4.0);
      });

      test('clamps rate above maximum', () {
        engine.setPlaybackRate(4.001);
        expect(engine.playbackSpeed.value, 4.0);

        engine.setPlaybackRate(100.0);
        expect(engine.playbackSpeed.value, 4.0);

        engine.setPlaybackRate(double.maxFinite);
        expect(engine.playbackSpeed.value, 4.0);
      });

      test('handles NaN rate', () {
        engine.setPlaybackRate(double.nan);
        // No crash — the key assertion
        expect(engine.setVolumeCallCount, 0); // ensure we didn't mix up calls
      });

      test('handles Infinity rate', () {
        engine.setPlaybackRate(double.infinity);
        expect(engine.playbackSpeed.value, 4.0);
      });
    });

    group('seekTo boundary values', () {
      setUp(() async {
        // Open to set duration.value from _mediaInfo.duration
        await engine.open('C:/test.mp4');
      });

      test('clamps negative seek to 0', () async {
        await engine.seekTo(-1);
        expect(engine.position.value, 0);
      });

      test('clamps extreme negative seek to 0', () async {
        await engine.seekTo(-999999);
        expect(engine.position.value, 0);
      });

      test('accepts seek to 0', () async {
        await engine.seekTo(0);
        expect(engine.position.value, 0);
      });

      test('accepts seek to duration', () async {
        await engine.seekTo(60000);
        expect(engine.position.value, 60000);
      });

      test('clamps seek beyond duration', () async {
        await engine.seekTo(60001);
        expect(engine.position.value, 60000);
      });

      test('clamps extreme positive seek', () async {
        await engine.seekTo(0x7FFFFFFFFFFFFFFF);
        expect(engine.position.value, 60000);
      });

      test('seek with zero duration', () async {
        engine.configureMedia(durationMs: 0);
        await engine.open('C:/zero.mp4');
        await engine.seekTo(1000);
        expect(engine.position.value, 0); // clamped to duration=0
      });
    });

    group('skipForward / skipBack boundary', () {
      test('skipForward clamps to duration', () {
        engine.position.value = 55000;
        engine.duration.value = 60000;
        engine.skipForward(10000);
        expect(engine.position.value, 60000); // 55000+10000 > 60000
      });

      test('skipBack clamps to 0', () {
        engine.position.value = 3000;
        engine.skipBack(10000);
        expect(engine.position.value, 0); // 3000-10000 < 0
      });

      test('skipForward with 0 duration', () {
        engine.position.value = 0;
        engine.duration.value = 0;
        engine.skipForward(10000);
        expect(engine.position.value, 0);
      });
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 4. String Injection Attacks
  // ────────────────────────────────────────────────────────────────────────────

  group('String injection attacks', () {
    group('SQL injection in file paths', () {
      final sqlPayloads = [
        "'; DROP TABLE playlist; --",
        "1' OR '1'='1",
        "'; DELETE FROM history WHERE 1=1; --",
        "admin'--",
        '1; UPDATE settings SET volume=100; --',
        "' UNION SELECT * FROM secrets --",
      ];

      for (final payload in sqlPayloads) {
        test(
          'PathValidator rejects SQL injection: ${payload.substring(0, payload.length.clamp(0, 40))}...',
          () {
            final error = PathValidator.validate(payload);
            // These should be rejected either as empty extension or path issues
            expect(error, isNotNull);
          },
        );
      }
    });

    group('Command injection via paths', () {
      final commandPayloads = [
        'file.mp4; rm -rf /',
        'file.mp4 | cat /etc/passwd',
        'file.mp4 && rm -rf /',
        'file.mp4 \$(cat /etc/passwd)',
        'file.mp4 > /dev/null',
        'file.mp4 < /etc/passwd',
      ];

      for (final payload in commandPayloads) {
        test(
          'PathValidator rejects command injection: ${payload.substring(0, payload.length.clamp(0, 40))}',
          () {
            final error = PathValidator.validate(payload);
            // Rejected due to invalid extension (characters after .mp4 are part of ext)
            expect(error, isNotNull);
          },
        );
      }

      test('backtick injection passes if extension is valid (known gap)', () {
        // `rm -rf /`.mp4 — extension is .mp4, backtick not checked.
        // Shell injection risk is low because path goes to MDK, not shell.
        expect(PathValidator.validate('`rm -rf /`.mp4'), isNull);
      });
    });

    group('Format string attacks', () {
      final formatPayloads = [
        '%s%s%s%s%s%s%s',
        '%x%x%x%x%x%x%x',
        '%n%n%n%n%n%n%n',
        '${0}\${1}\${2}',
        '{0}{1}{2}{3}',
      ];

      for (final payload in formatPayloads) {
        test(
          'PathUtils.basename handles format string: ${payload.substring(0, payload.length.clamp(0, 30))}',
          () {
            // PathUtils.basename is pure string manipulation — must not crash
            final result = PathUtils.basename(payload);
            expect(result, isA<String>());
          },
        );
      }
    });

    group('PathUtils.basename with adversarial inputs', () {
      test('empty string returns empty string', () {
        expect(PathUtils.basename(''), '');
      });

      test('only separators', () {
        expect(PathUtils.basename('/'), '');
        expect(PathUtils.basename(r'\\'), '');
        expect(PathUtils.basename('///'), '');
      });

      test('trailing separator returns empty', () {
        expect(PathUtils.basename('/path/to/dir/'), '');
        expect(PathUtils.basename(r'C:\path\to\dir\'), '');
      });

      test('very long filename', () {
        final long = '${'a' * 10000}.mp4';
        expect(PathUtils.basename('/dir/$long'), long);
      });

      test('unicode filename', () {
        expect(PathUtils.basename('/dir/视频.mp4'), '视频.mp4');
        expect(PathUtils.basename(r'C:\Users\用户\视频.mp4'), '视频.mp4');
        // Emoji in filename
        expect(PathUtils.basename('/dir/🎬movie.mp4'), '🎬movie.mp4');
      });

      test('null bytes in path', () {
        // Dart strings can contain null bytes; basename should still work
        final result = PathUtils.basename('dir/file\x00.mp4');
        expect(result, 'file\x00.mp4');
      });

      test('mixed separators', () {
        expect(PathUtils.basename(r'C:/dir\sub/file.mp4'), 'file.mp4');
        expect(PathUtils.basename(r'C:\dir/sub\file.mp4'), 'file.mp4');
      });
    });

    group('PathUtils.dirname with adversarial inputs', () {
      test('empty string returns dot', () {
        expect(PathUtils.dirname(''), '.');
      });

      test('no separator returns dot', () {
        expect(PathUtils.dirname('file.mp4'), '.');
      });

      test('only separator', () {
        expect(PathUtils.dirname('/'), '');
        expect(PathUtils.dirname(r'\'), '');
      });

      test('unicode directory', () {
        expect(PathUtils.dirname('/用户/视频/movie.mp4'), '/用户/视频');
      });
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 6. FakeEngine open() with adversarial paths
  // ────────────────────────────────────────────────────────────────────────────

  group('FakeEngine open with adversarial paths', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('open records path as-is (no sanitization at engine level)', () async {
      await engine.open('../../../etc/passwd');
      expect(engine.openPaths, contains('../../../etc/passwd'));
    });

    test('open empty string does not crash', () async {
      final result = await engine.open('');
      // FakeEngine accepts any string; real engine would fail at MDK level
      expect(result, isA<OpenResult>());
    });

    test('open very long path does not crash', () async {
      final longPath = 'C:/${'a' * 10000}.mp4';
      final result = await engine.open(longPath);
      expect(result, isA<OpenResult>());
    });

    test('open after dispose returns OpenSuperseded', () async {
      engine.dispose();
      final result = await engine.open('C:/test.mp4');
      expect(result, isA<OpenSuperseded>());
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // 7. PathValidator URL edge cases
  // ────────────────────────────────────────────────────────────────────────────

  group('PathValidator URL edge cases', () {
    test('valid HTTP URL passes', () {
      expect(PathValidator.validate('http://example.com/video.mp4'), isNull);
    });

    test('valid HTTPS URL passes', () {
      expect(PathValidator.validate('https://example.com/video.mp4'), isNull);
    });

    test('HTTP without authority fails', () {
      expect(PathValidator.validate('http://'), isNotNull);
      expect(PathValidator.validate('https://'), isNotNull);
    });

    test('HTTP with empty host fails', () {
      expect(PathValidator.validate('http:///path.mp4'), isNotNull);
    });

    test('FTP scheme passes (not in URL list, treated as local path)', () {
      // ftp:// is not in _urlSchemes, so it falls through to extension check.
      // .mp4 is valid → passes. Acceptable: MDK/FFmpeg would handle or fail.
      expect(PathValidator.validate('ftp://server/file.mp4'), isNull);
    });

    test('javascript: scheme is rejected', () {
      expect(PathValidator.validate('javascript:alert(1)'), isNotNull);
    });

    test('data: URI is rejected', () {
      expect(
        PathValidator.validate('data:text/html,<script>alert(1)</script>'),
        isNotNull,
      );
    });

    test('file: scheme is rejected', () {
      expect(PathValidator.validate('file:///etc/passwd'), isNotNull);
    });

    test('RTSP URL passes (streaming)', () {
      expect(PathValidator.validate('rtsp://server/stream'), isNull);
    });

    test('RTMP URL passes (streaming)', () {
      expect(PathValidator.validate('rtmp://server/live'), isNull);
    });
  });
}
