import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;
  int rebuildCount = 0;
  List<Object> errors = [];

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    rebuildCount = 0;
    errors = [];
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => rebuildCount++,
      onError: (e) => errors.add(e),
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  /// Helper: register the auto-advance listener (normally done by init()).
  ///
  /// init() cannot be called in tests because it loads SettingsStore from
  /// SharedPreferences. Instead, we manually register the state listener
  /// so auto-advance on completed works.
  void registerAutoAdvance() {
    engine.state.addListener(() {
      final state = engine.state.value;
      if (state != MediaState.completed) return;
      if (playlist.mode == PlayMode.loopSingle) {
        final idx = playlist.currentIndex;
        if (idx >= 0) {
          controller.playIndex(idx).catchError((e) {
            // ignore
          });
        }
      } else {
        controller.playNext().catchError((e) {
          // ignore
        });
      }
    });
  }

  group('PlaybackController', () {
    // ─── openAndPlay ───

    group('openAndPlay', () {
      test('adds file to playlist and starts playback', () async {
        engine.configureMedia(durationMs: 120000);
        final result = await controller.openAndPlay('C:/test/video.mp4');
        // playIndex is backgrounded by openAndPlay; yield to let it complete
        await Future(() {});
        expect(result, true);
        expect(playlist.length, 1);
        expect(playlist.current!.path, 'C:/test/video.mp4');
        expect(engine.state.value, MediaState.playing);
        expect(engine.openCallCount, 1);
        expect(engine.playCallCount, 1);
        expect(rebuildCount, greaterThanOrEqualTo(1));
        expect(controller.currentFileName.value, 'video.mp4');
      });

      test('rejects invalid path (empty string)', () async {
        final result = await controller.openAndPlay('');
        expect(result, false);
        expect(playlist.isEmpty, true);
        expect(controller.validationError.value, isNotNull);
      });

      test('rejects non-media extension', () async {
        final result = await controller.openAndPlay('C:/test/file.txt');
        expect(result, false);
        expect(controller.validationError.value, contains('不支持'));
      });

      test('reuses existing index if file already in playlist', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.openAndPlay('C:/test/a.mp4');
        await Future(() {});
        // Add again — should reuse existing index
        await controller.openAndPlay('C:/test/a.mp4');
        await Future(() {});
        expect(playlist.length, 1);
        // open was called twice (once per openAndPlay)
        expect(engine.openCallCount, 2);
      });
    });

    // ─── playIndex ───

    group('playIndex', () {
      test('opens file at index and plays', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        await controller.playIndex(1);
        expect(playlist.currentIndex, 1);
        expect(engine.state.value, MediaState.playing);
        expect(engine.openPaths.last, contains('b.mp4'));
      });

      test('ignores out-of-range index', () async {
        playlist.add('C:/a.mp4');
        await controller.playIndex(-1);
        await controller.playIndex(99);
        expect(engine.openCallCount, 0);
      });

      test('generation guard discards stale request', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        // Start two playIndex calls concurrently
        final f1 = controller.playIndex(0);
        final f2 = controller.playIndex(1);
        await f1;
        await f2;
        // Last request wins
        expect(playlist.currentIndex, 1);
        expect(controller.navigator.currentGeneration, 2);
      });
    });

    // ─── playNext / playPrevious ───

    group('playNext / playPrevious', () {
      setUp(() {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
      });

      test('playNext advances to next track', () async {
        await controller.playIndex(0);
        await controller.playNext();
        expect(playlist.currentIndex, 1);
      });

      test('playNext at end in loopAll wraps around', () async {
        playlist.currentIndex = 2;
        playlist.mode = PlayMode.loopAll;
        await controller.playNext();
        expect(playlist.currentIndex, 0);
      });

      test('playPrevious goes back', () async {
        playlist.currentIndex = 2;
        await controller.playPrevious();
        expect(playlist.currentIndex, 1);
      });
    });

    // ─── addFiles ───

    group('addFiles', () {
      test('adds multiple valid files', () async {
        final count = await controller.addFiles([
          'C:/a.mp4',
          'C:/b.mp4',
          'C:/c.mp4',
        ]);
        expect(count, 3);
        expect(playlist.length, 3);
      });

      test('starts playback if playlist was empty', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.addFiles(['C:/a.mp4']);
        await Future(() {});
        expect(engine.state.value, MediaState.playing);
        expect(engine.openCallCount, 1);
      });

      test('deduplicates existing files', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.addFiles(['C:/a.mp4']);
        await Future(() {});
        final count = await controller.addFiles(['C:/a.mp4', 'C:/b.mp4']);
        expect(count, 1);
        expect(playlist.length, 2);
      });

      test('filters invalid paths', () async {
        final count = await controller.addFiles(['C:/a.mp4', '', 'C:/bad.txt']);
        expect(count, 1);
        expect(playlist.length, 1);
      });
    });

    // ─── removeAt ───

    group('removeAt', () {
      test('removes non-current item', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        await controller.playIndex(1);
        final stopBefore = engine.stopCallCount;
        await controller.removeAt(0);
        expect(playlist.length, 2);
        expect(playlist.currentIndex, 0);
        // Engine should NOT be stopped (removed item was not current)
        expect(engine.stopCallCount, stopBefore);
      });

      test('removes current item and plays next', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        await controller.playIndex(0);
        final playBefore = engine.playCallCount;
        await controller.removeAt(0);
        // Engine stopped, then next item plays
        expect(engine.stopCallCount, greaterThanOrEqualTo(1));
        expect(engine.playCallCount, greaterThan(playBefore));
      });

      test('removes current last item', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        await controller.removeAt(0);
        expect(playlist.isEmpty, true);
        expect(engine.stopCallCount, greaterThanOrEqualTo(1));
      });
    });

    // ─── clearPlaylist ───

    group('clearPlaylist', () {
      test('stops engine and clears playlist', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        controller.clearPlaylist();
        expect(engine.stopCallCount, greaterThanOrEqualTo(1));
        expect(playlist.isEmpty, true);
        expect(controller.currentFileName.value, '');
      });
    });

    // ─── reorder ───

    group('reorder', () {
      test('reorders items and triggers rebuild + save', () async {
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.currentIndex = 0;
        final before = rebuildCount;

        controller.reorder(0, 2);

        // removeAt(0) → [b, c], insert(2, a) → [b, c, a]
        expect(playlist.items[0].path, 'C:/b.mp4');
        expect(playlist.items[2].path, 'C:/a.mp4');
        // currentIndex tracked: was 0 == oldIndex → becomes newIndex 2
        expect(playlist.currentIndex, 2);
        expect(rebuildCount, greaterThan(before));
      });

      test('reorder non-current item keeps currentIndex stable', () async {
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.currentIndex = 2; // playing c

        controller.reorder(0, 1);

        // removeAt(0) → [b, c], insert(1, a) → [b, a, c]
        expect(playlist.items[0].path, 'C:/b.mp4');
        expect(playlist.items[1].path, 'C:/a.mp4');
        expect(playlist.items[2].path, 'C:/c.mp4');
        // currentIndex=2, oldIndex=0<2 but newIndex=1<2 → neither branch fires
        expect(playlist.currentIndex, 2);
      });
    });

    // ─── togglePlayMode ───

    group('togglePlayMode', () {
      test('cycles through all modes', () {
        expect(playlist.mode, PlayMode.loopAll);
        controller.togglePlayMode();
        expect(playlist.mode, PlayMode.loopSingle);
        controller.togglePlayMode();
        expect(playlist.mode, PlayMode.shuffle);
        controller.togglePlayMode();
        expect(playlist.mode, PlayMode.loopAll);
      });
    });

    // ─── auto-advance on completed ───

    group('auto-advance on completed', () {
      test('auto-plays next in loopAll mode', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.mode = PlayMode.loopAll;
        registerAutoAdvance();
        await controller.playIndex(0);
        engine.simulateCompleted();
        // Listener fires synchronously; yield to let playIndex async complete
        await Future(() {});
        expect(playlist.currentIndex, 1);
      });

      test('replays in loopSingle mode', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopSingle;
        registerAutoAdvance();
        await controller.playIndex(0);
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0);
      });
    });
  });
}
