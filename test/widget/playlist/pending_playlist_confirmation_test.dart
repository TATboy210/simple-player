import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';
import 'package:simple_player_flutter/ui/playlist/pending_playlist_confirmation.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  group('PendingPlaylistConfirmation', () {
    // H3 修复语义锁定: 同一实例注入两次 = _itemFor path 级缓存下的
    // 生产孪生形态 (path 与 addedSeq 完全相同), 精确性由冻结原始索引承担。
    test('constructor keeps duplicate-path entries (no longer dropped)', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, a, b],
        indices: {0, 1},
      );
      expect(pending.targetCount, 2);
      expect(pending.isEmpty, isFalse);
    });

    test('constructor still drops out-of-bounds indices', () {
      final a = PlaylistItem(path: 'a.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, a, a],
        indices: {0, 5},
      );
      expect(pending.targetCount, 1);
    });

    test('resolve prefers the frozen index even with a twin present', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, b],
        indices: {0},
      );
      // 孪生在场也只删用户点的那一格 (冻结位 0 精确命中)。
      expect(pending.resolve([a, a, b]), <int>{0});
    });

    test(
      'resolve falls back to the unique (path, addedSeq) match after shift',
      () {
        final a = PlaylistItem(path: 'a.mp4');
        final b = PlaylistItem(path: 'b.mp4');
        final pending = PendingPlaylistConfirmation(
          message: (count) => 'remove $count',
          entries: [a, b],
          indices: {0},
        );
        // 列表移位后冻结位失效, (path, addedSeq) 恰好唯一命中 → 回退取之。
        expect(pending.resolve([b, a]), <int>{1});
      },
    );

    test('resolve skips a vanished target', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, b],
        indices: {0},
      );
      expect(pending.resolve([b]), isEmpty);
    });

    test('resolve skips an ambiguous twin pair (frozen index lost)', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, b],
        indices: {0},
      );
      // 冻结位 0 现在是 b → 回退; a 在 [b, a, a] 有两处 → 歧义, 宁可不删。
      expect(pending.resolve([b, a, a]), isEmpty);
    });

    test('resolve mixes a frozen duplicate hit with a vanished target', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      final pending = PendingPlaylistConfirmation(
        message: (count) => 'remove $count',
        entries: [a, b],
        indices: {0, 1},
      );
      // a 命中冻结位 0; b 消失跳过。
      expect(pending.resolve([a, a]), <int>{0});
    });

    test('message is evaluated with the frozen target count', () {
      final a = PlaylistItem(path: 'a.mp4');
      final b = PlaylistItem(path: 'b.mp4');
      var captured = -1;
      final pending = PendingPlaylistConfirmation(
        message: (count) {
          captured = count;
          return 'remove $count';
        },
        entries: [a, a, b],
        indices: {0, 1},
      );
      expect(captured, 2);
      expect(pending.message, 'remove 2');
    });
  });
}
