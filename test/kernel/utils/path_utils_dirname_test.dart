import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/utils/path_utils.dart';

void main() {
  group('PathUtils.dirname', () {
    test('Windows path with backslashes', () {
      expect(PathUtils.dirname(r'C:\Videos\movie.mkv'), r'C:\Videos');
    });

    test('Unix path with forward slashes', () {
      expect(PathUtils.dirname('/home/user/video.mp4'), '/home/user');
    });

    test('mixed separators', () {
      expect(PathUtils.dirname(r'C:/Videos\movie.mkv'), r'C:/Videos');
    });

    test('filename only returns dot', () {
      expect(PathUtils.dirname('song.mp3'), '.');
    });

    test('deeply nested path', () {
      expect(PathUtils.dirname('/a/b/c/d/e/f/file.txt'), '/a/b/c/d/e/f');
    });

    test('trailing separator', () {
      expect(PathUtils.dirname('/home/user/'), '/home/user');
    });

    test('root path', () {
      expect(PathUtils.dirname('/'), '');
    });

    test('empty string returns dot', () {
      expect(PathUtils.dirname(''), '.');
    });

    test('Windows drive root', () {
      expect(PathUtils.dirname(r'C:\'), r'C:');
    });
  });
}
