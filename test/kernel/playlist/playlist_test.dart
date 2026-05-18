import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';

void main() {
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
        final restored = Playlist.fromJson({'mode': 99, 'items': []});
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
