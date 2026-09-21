/// PlaylistSortKey 比较器纯函数测试 (v0.0.6 Phase 2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/kernel/models/playlist_sort.dart';

PlaylistItem _item(
  String path, {
  int? addedSeq,
  int? timestamp,
  int? durationMs,
}) => PlaylistItem(
  path: path,
  addedSeq: addedSeq,
  timestamp: timestamp,
  durationMs: durationMs,
);

void main() {
  group('name 键', () {
    test('字典序升序', () {
      final b = _item('b.mp4');
      final a = _item('a.mp4');
      expect(
        comparePlaylistEntries(
          a,
          b,
          key: PlaylistSortKey.name,
          ascending: true,
        ),
        isNegative,
      );
    });

    test('自然序 — file2 排在 file10 前 (资源管理器惯例)', () {
      final f10 = _item('file10.mp4');
      final f2 = _item('file2.mp4');
      expect(
        comparePlaylistEntries(
          f2,
          f10,
          key: PlaylistSortKey.name,
          ascending: true,
        ),
        isNegative,
      );
    });

    test('大小写不敏感 — B.mp4 排在 a.mp4 后', () {
      final upper = _item('B.mp4');
      final lower = _item('a.mp4');
      expect(
        comparePlaylistEntries(
          upper,
          lower,
          key: PlaylistSortKey.name,
          ascending: true,
        ),
        isPositive,
      );
    });

    test('降序翻转', () {
      final b = _item('b.mp4');
      final a = _item('a.mp4');
      expect(
        comparePlaylistEntries(
          a,
          b,
          key: PlaylistSortKey.name,
          ascending: false,
        ),
        isPositive,
      );
    });

    test('同名平局 — path 字典序稳定 tie-break', () {
      final x1 = _item(r'D:\v\a.mp4');
      final x2 = _item(r'D:\w\a.mp4');
      final cmp = comparePlaylistEntries(
        x1,
        x2,
        key: PlaylistSortKey.name,
        ascending: true,
      );
      expect(cmp, isNegative);
    });
  });

  group('addedOrder 键', () {
    test('按 addedSeq 升序', () {
      final second = _item('b.mp4', addedSeq: 1);
      final first = _item('a.mp4', addedSeq: 0);
      expect(
        comparePlaylistEntries(
          first,
          second,
          key: PlaylistSortKey.addedOrder,
          ascending: true,
        ),
        isNegative,
      );
    });

    test('null addedSeq 恒排末尾 (方向无关)', () {
      final unsequenced = _item('z.mp4');
      final sequenced = _item('a.mp4', addedSeq: 0);
      expect(
        comparePlaylistEntries(
          unsequenced,
          sequenced,
          key: PlaylistSortKey.addedOrder,
          ascending: true,
        ),
        isPositive,
      );
      expect(
        comparePlaylistEntries(
          unsequenced,
          sequenced,
          key: PlaylistSortKey.addedOrder,
          ascending: false,
        ),
        isPositive, // 降序也不前置
      );
    });

    test('双 null — path tie-break', () {
      final a = _item('a.mp4');
      final b = _item('b.mp4');
      expect(
        comparePlaylistEntries(
          a,
          b,
          key: PlaylistSortKey.addedOrder,
          ascending: true,
        ),
        isNegative,
      );
    });
  });

  group('lastPlayed 键', () {
    test('升序 = 旧→新', () {
      final old = _item('a.mp4', timestamp: 100);
      final recent = _item('b.mp4', timestamp: 200);
      expect(
        comparePlaylistEntries(
          old,
          recent,
          key: PlaylistSortKey.lastPlayed,
          ascending: true,
        ),
        isNegative,
      );
    });

    test('null timestamp = 从未播放 = 最旧 (升序最前 / 降序最后)', () {
      final never = _item('a.mp4');
      final played = _item('b.mp4', timestamp: 200);
      expect(
        comparePlaylistEntries(
          never,
          played,
          key: PlaylistSortKey.lastPlayed,
          ascending: true,
        ),
        isNegative,
      );
      expect(
        comparePlaylistEntries(
          never,
          played,
          key: PlaylistSortKey.lastPlayed,
          ascending: false,
        ),
        isPositive,
      );
    });
  });

  group('duration 键', () {
    test('按时长升序 (短→长)', () {
      final short = _item('a.mp4', durationMs: 1000);
      final long = _item('b.mp4', durationMs: 90000);
      expect(
        comparePlaylistEntries(
          short,
          long,
          key: PlaylistSortKey.duration,
          ascending: true,
        ),
        isNegative,
      );
    });

    test('null duration 恒排末尾 (方向无关)', () {
      final unknown = _item('z.mp4');
      final known = _item('a.mp4', durationMs: 1000);
      expect(
        comparePlaylistEntries(
          unknown,
          known,
          key: PlaylistSortKey.duration,
          ascending: true,
        ),
        isPositive,
      );
      expect(
        comparePlaylistEntries(
          unknown,
          known,
          key: PlaylistSortKey.duration,
          ascending: false,
        ),
        isPositive,
      );
    });

    test('双 null — path tie-break', () {
      final a = _item('a.mp4');
      final b = _item('b.mp4');
      expect(
        comparePlaylistEntries(
          a,
          b,
          key: PlaylistSortKey.duration,
          ascending: true,
        ),
        isNegative,
      );
    });
  });
}
