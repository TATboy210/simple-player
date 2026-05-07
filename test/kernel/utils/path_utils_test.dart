import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/path_utils.dart';

void main() {
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
      expect(
        PathUtils.basename('/a/b/c/d/e/f/file.txt'),
        'file.txt',
      );
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
}
