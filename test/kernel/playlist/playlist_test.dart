import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/models/playlist_item.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  group('Playlist', () {
    late Playlist playlist;

    setUp(() {
      playlist = Playlist();
    });

    group('empty state', () {
      test('length is 0', () => expect(playlist.length, 0));
      test('isEmpty', () => expect(playlist.isEmpty, true));
      test('current is null', () => expect(playlist.current, isNull));
      test('currentIndex is -1', () => expect(playlist.currentIndex, -1));
      test('peekNext returns -1', () => expect(playlist.peekNext(), -1));
      test(
        'peekPrevious returns -1',
        () => expect(playlist.peekPrevious(), -1),
      );
      test('hasNext is false', () => expect(playlist.hasNext, false));
      test('hasPrevious is false', () => expect(playlist.hasPrevious, false));
    });

    group('add', () {
      test('adds item and sets index to 0', () {
        final idx = playlist.add('/video.mp4');
        expect(idx, 0);
        expect(playlist.length, 1);
        expect(playlist.currentIndex, 0);
        expect(playlist.current!.path, '/video.mp4');
      });

      test('adds multiple items', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
        expect(playlist.length, 3);
        expect(playlist.currentIndex, 0);
      });
    });

    group('removeAt', () {
      setUp(() {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
      });

      test('removes item before current', () {
        playlist.currentIndex = 1;
        expect(playlist.removeAt(0), true);
        expect(playlist.length, 2);
        expect(playlist.currentIndex, 0);
        expect(playlist.current!.path, '/b.mp4');
      });

      test('removes current item', () {
        playlist.currentIndex = 1;
        expect(playlist.removeAt(1), true);
        expect(playlist.currentIndex, 1);
        expect(playlist.current!.path, '/c.mp4');
      });

      test('removes last item, current clamps', () {
        playlist.currentIndex = 2;
        expect(playlist.removeAt(2), true);
        expect(playlist.currentIndex, 1);
        expect(playlist.current!.path, '/b.mp4');
      });

      test('removes all items', () {
        playlist.removeAt(0);
        playlist.removeAt(0);
        playlist.removeAt(0);
        expect(playlist.isEmpty, true);
        expect(playlist.currentIndex, -1);
      });

      test('rejects invalid index', () {
        expect(playlist.removeAt(-1), false);
        expect(playlist.removeAt(3), false);
      });
    });

    group('reorder', () {
      setUp(() {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
      });

      test('moves item forward', () {
        playlist.reorder(0, 2);
        expect(playlist.items[0].path, '/b.mp4');
        expect(playlist.items[1].path, '/c.mp4');
        expect(playlist.items[2].path, '/a.mp4');
      });

      test('tracks current item when it moves', () {
        playlist.currentIndex = 0;
        playlist.reorder(0, 2);
        expect(playlist.currentIndex, 2);
      });
    });

    group('navigation — loopAll mode', () {
      setUp(() {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
        playlist.mode = PlayMode.loopAll;
      });

      test('peekNext wraps around', () {
        playlist.currentIndex = 2;
        expect(playlist.peekNext(), 0);
      });

      test('peekPrevious wraps around', () {
        expect(playlist.peekPrevious(), 2);
      });
    });

    group('navigation — loopSingle mode', () {
      setUp(() {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.mode = PlayMode.loopSingle;
      });

      test('peekNext returns same index', () {
        expect(playlist.peekNext(), 0);
      });

      test('peekPrevious returns same index', () {
        expect(playlist.peekPrevious(), 0);
      });
    });

    group('CQS — peekNext does not mutate state', () {
      test('calling peekNext does not change currentIndex', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.currentIndex = 0;
        final _ = playlist.peekNext();
        expect(playlist.currentIndex, 0);
      });
    });

    group('addAll', () {
      test('adds multiple paths at once', () {
        playlist.addAll(['/a.mp4', '/b.mp4', '/c.mp4']);
        expect(playlist.length, 3);
        expect(playlist.currentIndex, 0);
        expect(playlist.items[1].path, '/b.mp4');
      });

      test('addAll on empty list sets index to 0', () {
        playlist.addAll(['/x.mkv']);
        expect(playlist.currentIndex, 0);
      });
    });

    group('addItem', () {
      test('adds item preserving metadata', () {
        final item = PlaylistItem(
          path: '/test.mp4',
          timestamp: 1000,
          positionMs: 500,
          durationMs: 2000,
        );
        final idx = playlist.addItem(item);
        expect(idx, 0);
        expect(playlist.current!.timestamp, 1000);
        expect(playlist.current!.positionMs, 500);
      });
    });

    group('clear', () {
      test('empties list and resets index', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.currentIndex = 1;
        playlist.clear();
        expect(playlist.isEmpty, true);
        expect(playlist.currentIndex, -1);
      });
    });

    group('updateHistory', () {
      test('updates timestamp and position', () {
        playlist.add('/a.mp4');
        playlist.updateHistory(0, positionMs: 1000, durationMs: 5000);
        expect(playlist.items[0].positionMs, 1000);
        expect(playlist.items[0].durationMs, 5000);
        expect(playlist.items[0].timestamp, isPositive);
      });

      test('preserves existing values when null', () {
        playlist.add('/a.mp4');
        playlist.updateHistory(0, positionMs: 1000);
        playlist.updateHistory(0, durationMs: 5000);
        expect(playlist.items[0].positionMs, 1000);
        expect(playlist.items[0].durationMs, 5000);
      });

      test('rejects invalid index', () {
        playlist.add('/a.mp4');
        playlist.updateHistory(-1, positionMs: 1000);
        playlist.updateHistory(5, positionMs: 1000);
        // No crash
      });
    });

    group('updatePosition', () {
      test('updates position without changing timestamp', () {
        playlist.add('/a.mp4');
        playlist.updateHistory(0, positionMs: 1000);
        final ts = playlist.items[0].timestamp;
        playlist.updatePosition(0, 2000, 5000);
        expect(playlist.items[0].positionMs, 2000);
        expect(playlist.items[0].durationMs, 5000);
        expect(playlist.items[0].timestamp, ts); // unchanged
      });

      test('rejects invalid index', () {
        playlist.updatePosition(-1, 1000, null);
        playlist.updatePosition(5, 1000, null);
        // No crash
      });

      test('preserves existing durationMs when null', () {
        playlist.add('/a.mp4');
        playlist.updateHistory(0, positionMs: 1000, durationMs: 5000);
        playlist.updatePosition(0, 2000, null);
        expect(playlist.items[0].positionMs, 2000);
        expect(playlist.items[0].durationMs, 5000); // preserved
      });
    });

    group('mergeHistory', () {
      test('merges metadata into existing items', () {
        playlist.add('/a.mp4');
        playlist.mergeHistory({
          '/a.mp4': {'timestamp': 1000, 'positionMs': 500, 'durationMs': 3000},
        });
        expect(playlist.items[0].timestamp, 1000);
        expect(playlist.items[0].positionMs, 500);
      });

      test('adds items from history not in playlist', () {
        playlist.add('/a.mp4');
        playlist.mergeHistory({
          '/b.mp4': {'timestamp': 2000},
        });
        expect(playlist.length, 2);
        expect(playlist.items[1].path, '/b.mp4');
        expect(playlist.items[1].timestamp, 2000);
      });

      test('sets currentIndex to 0 when playlist was empty', () {
        playlist.mergeHistory({
          '/a.mp4': {'timestamp': 1000},
        });
        expect(playlist.currentIndex, 0);
        expect(playlist.length, 1);
      });
    });

    group('reorder edge cases', () {
      setUp(() {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
      });

      test('moves item backward', () {
        playlist.reorder(2, 0);
        expect(playlist.items[0].path, '/c.mp4');
        expect(playlist.items[1].path, '/a.mp4');
        expect(playlist.items[2].path, '/b.mp4');
      });

      test('tracks current when moving item past current', () {
        playlist.currentIndex = 0; // current is /a.mp4
        playlist.reorder(0, 2); // move /a.mp4 to index 2
        expect(playlist.currentIndex, 2);
      });

      test('no-op when oldIndex equals newIndex', () {
        playlist.reorder(1, 1);
        expect(playlist.items[1].path, '/b.mp4');
      });

      test('rejects out-of-range indices', () {
        playlist.reorder(-1, 0);
        playlist.reorder(0, 5);
        playlist.reorder(5, 0);
        // No crash, list unchanged
        expect(playlist.length, 3);
      });

      test('decrements currentIndex when item crosses current', () {
        playlist.add('/d.mp4');
        playlist.currentIndex = 3; // playing d
        // reorder(1, 3): removeAt(1)→[a,c,d], insert(3,b)→[a,c,d,b]
        // oldIndex=1 < currentIndex=3, newIndex=3 >= currentIndex=3
        // → currentIndex-- → 2
        playlist.reorder(1, 3);
        expect(playlist.currentIndex, 2);
        expect(playlist.current!.path, '/d.mp4');
      });
    });

    group('navigation — shuffle mode', () {
      test('peekNext returns different index (with high probability)', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
        playlist.mode = PlayMode.shuffle;
        playlist.currentIndex = 0;
        // With 3 items, peekNext must return 1 or 2
        final next = playlist.peekNext();
        expect(next, isNot(0));
        expect(next, inInclusiveRange(0, 2));
      });

      test('peekPrevious returns different index (with high probability)', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.add('/c.mp4');
        playlist.mode = PlayMode.shuffle;
        playlist.currentIndex = 0;
        final prev = playlist.peekPrevious();
        expect(prev, isNot(0));
      });
    });

    group('toString', () {
      test('includes item count and mode', () {
        playlist.add('/a.mp4');
        final s = playlist.toString();
        expect(s, contains('1 items'));
        expect(s, contains('loopAll'));
      });
    });

    group('serialization', () {
      test('round-trip', () {
        playlist.add('/a.mp4');
        playlist.add('/b.mp4');
        playlist.currentIndex = 1;
        playlist.mode = PlayMode.loopAll;

        final json = playlist.toJson();
        final restored = Playlist.fromJson(json);

        expect(restored.length, 2);
        expect(restored.currentIndex, 1);
        expect(restored.mode, PlayMode.loopAll);
        expect(restored.items[1].path, '/b.mp4');
      });

      test('fromJson handles empty map', () {
        final restored = Playlist.fromJson({});
        expect(restored.isEmpty, true);
        expect(restored.currentIndex, -1);
        expect(restored.mode, PlayMode.loopAll);
      });

      test('fromJson clamps out-of-range mode', () {
        final restored = Playlist.fromJson(<String, dynamic>{'mode': 99, 'items': <dynamic>[]});
        expect(restored.mode, PlayMode.loopAll);
      });

      test('fromJson skips corrupt items', () {
        final restored = Playlist.fromJson({
          'items': [
            {'path': '/good.mp4'},
            {'bad': 'data'},
            {'path': '/also-good.mkv'},
          ],
        });
        expect(restored.length, 2);
      });
    });
  });
}
