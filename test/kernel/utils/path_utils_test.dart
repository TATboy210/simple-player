import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/utils/path_utils.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  group('PathUtils.basename', () {
    test('Windows path with backslashes', () {
      expect(PathUtils.basename(r'C:\Videos\movie.mkv'), 'movie.mkv');
    });

    test('Unix path with forward slashes', () {
      expect(PathUtils.basename('/home/user/video.mp4'), 'video.mp4');
    });

    test('mixed separators', () {
      expect(PathUtils.basename(r'C:/Videos\movie.mkv'), 'movie.mkv');
    });

    test('filename only (no directory)', () {
      expect(PathUtils.basename('song.mp3'), 'song.mp3');
    });

    test('deeply nested path', () {
      expect(PathUtils.basename('/a/b/c/d/e/f/file.txt'), 'file.txt');
    });

    test('trailing separator returns empty', () {
      expect(PathUtils.basename('/home/user/'), '');
    });

    test('root path', () {
      expect(PathUtils.basename('/'), '');
    });

    test('empty string', () {
      expect(PathUtils.basename(''), '');
    });

    test('Windows drive root', () {
      expect(PathUtils.basename(r'C:\'), '');
    });

    test('path with spaces', () {
      expect(PathUtils.basename(r'C:\My Documents\my file.txt'), 'my file.txt');
    });

    test('path with unicode characters', () {
      expect(PathUtils.basename('/视频/测试.mp4'), '测试.mp4');
    });
  });

  group('PathUtils.openFileLocation', () {
    test('calls runner with explorer on Windows', () {
      String? calledCmd;
      List<String>? calledArgs;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      PathUtils.openFileLocation(
        r'C:\Videos\movie.mkv',
        runner: (cmd, args) async {
          calledCmd = cmd;
          calledArgs = args;
        },
      );

      expect(calledCmd, 'explorer');
      expect(calledArgs, [r'C:\Videos']);
    });

    test('calls runner with xdg-open on Linux', () {
      String? calledCmd;
      List<String>? calledArgs;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      PathUtils.openFileLocation(
        '/home/user/video.mp4',
        runner: (cmd, args) async {
          calledCmd = cmd;
          calledArgs = args;
        },
      );

      expect(calledCmd, 'xdg-open');
      expect(calledArgs, ['/home/user']);
    });

    test('calls runner with open on macOS', () {
      String? calledCmd;
      List<String>? calledArgs;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      PathUtils.openFileLocation(
        '/Users/dev/movie.mp4',
        runner: (cmd, args) async {
          calledCmd = cmd;
          calledArgs = args;
        },
      );

      expect(calledCmd, 'open');
      expect(calledArgs, ['/Users/dev']);
    });

    test('does not call runner on unsupported platform (Android)', () {
      var called = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      PathUtils.openFileLocation(
        '/sdcard/video.mp4',
        runner: (cmd, args) async {
          called = true;
        },
      );

      expect(called, isFalse);
    });

    test('extracts dirname correctly for runner', () {
      String? calledArgs;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      PathUtils.openFileLocation(
        r'D:\Movies\sub\clip.mkv',
        runner: (cmd, args) async {
          calledArgs = args[0];
        },
      );

      expect(calledArgs, r'D:\Movies\sub');
    });
  });
}
