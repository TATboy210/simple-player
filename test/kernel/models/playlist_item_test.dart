import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';

void main() {
  group('PlaylistItem', () {
    group('fromJson', () {
      // 正常路径：合法 String
      test('accepts valid path', () {
        final item = PlaylistItem.fromJson({'path': '/video/test.mp4'});
        expect(item.path, '/video/test.mp4');
      });

      // 边界：path 非 String 类型（如 int/null/bool）
      // fromJson 内部用 is! String 检查，必须抛 FormatException
      test('rejects non-string path', () {
        expect(
          () => PlaylistItem.fromJson({'path': 123}),
          throwsA(isA<FormatException>()),
        );
      });

      // 边界：path 缺失（json 里没有 'path' key）
      // json['path'] 返回 null，null is! String → FormatException
      test('rejects missing path', () {
        expect(
          () => PlaylistItem.fromJson({'name': 'test'}),
          throwsA(isA<FormatException>()),
        );
      });

      // 边界：path 为 null（显式传 null）
      test('rejects null path', () {
        expect(
          () => PlaylistItem.fromJson({'path': null}),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('name extraction', () {
      // Unix 路径：取最后一个 / 后的部分
      test('extracts name from unix path', () {
        final item = PlaylistItem(path: '/home/user/video.mp4');
        expect(item.name, 'video.mp4');
      });

      // Windows 路径：取最后一个 \ 后的部分
      test('extracts name from windows path', () {
        final item = PlaylistItem(path: r'D:\Videos\movie.mkv');
        expect(item.name, 'movie.mkv');
      });

      // 混合分隔符：先按 / 分再按 \ 分
      test('handles mixed separators', () {
        final item = PlaylistItem(path: r'C:/Videos/movie.mkv');
        expect(item.name, 'movie.mkv');
      });

      // 无分隔符：整个字符串就是文件名
      test('handles filename only', () {
        final item = PlaylistItem(path: 'song.mp3');
        expect(item.name, 'song.mp3');
      });
    });

    group('equality', () {
      // 相同 path → 相等（== 和 hashCode 基于 path）
      test('equal items have same path', () {
        final a = PlaylistItem(path: '/a.mp4');
        final b = PlaylistItem(path: '/a.mp4');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      // 不同 path → 不等
      test('different paths are not equal', () {
        final a = PlaylistItem(path: '/a.mp4');
        final b = PlaylistItem(path: '/b.mp4');
        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('preserves positionMs when not provided', () {
        final item = PlaylistItem(
          path: '/test.mp4',
          positionMs: 1000,
          durationMs: 5000,
        );
        final updated = item.copyWith(durationMs: 8000);
        expect(updated.positionMs, 1000); // preserved
        expect(updated.durationMs, 8000); // updated
      });

      test('preserves durationMs when not provided', () {
        final item = PlaylistItem(path: '/test.mp4', durationMs: 5000);
        final updated = item.copyWith(positionMs: 2000);
        expect(updated.durationMs, 5000); // preserved
        expect(updated.positionMs, 2000); // updated
      });
    });

    group('toString', () {
      test('returns PlaylistItem(name)', () {
        final item = PlaylistItem(path: '/videos/movie.mp4');
        expect(item.toString(), 'PlaylistItem(movie.mp4)');
      });
    });

    group('serialization', () {
      // toJson → fromJson 往返一致
      test('round-trip', () {
        final original = PlaylistItem(path: '/test/video.mp4');
        final json = original.toJson();
        final restored = PlaylistItem.fromJson(json);
        expect(restored, equals(original));
      });
    });
  });
}
