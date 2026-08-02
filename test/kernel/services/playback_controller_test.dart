import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

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

      test('latest open result determines the selected track', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');

        final first = controller.playIndex(0);
        final latest = controller.playIndex(1);
        await Future.wait<void>([first, latest]);

        expect(playlist.currentIndex, 1);
        expect(engine.playCallCount, 1);
        expect(controller.currentFileName.value, 'b.mp4');
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

      test(
        'keeps current item and does not play next when stop fails',
        () async {
          engine.configureMedia(durationMs: 60000);
          playlist.add('C:/a.mp4');
          playlist.add('C:/b.mp4');
          await controller.playIndex(0);
          final titleBeforeStop = controller.currentFileName.value;
          final openCallsBeforeStop = engine.openCallCount;
          engine.failNextStopWith = 'backend unavailable';

          await controller.removeAt(0);

          expect(engine.hasMedia, true);
          expect(engine.state.value, MediaState.error);
          expect(playlist.length, 2);
          expect(playlist.current?.path, 'C:/a.mp4');
          expect(controller.currentFileName.value, titleBeforeStop);
          expect(engine.openCallCount, openCallsBeforeStop);
        },
      );
    });

    // ─── stopCurrentMedia / clearPlaylist ───

    group('stopCurrentMedia', () {
      test(
        'unloads media, clears the active title, and keeps the playlist',
        () async {
          engine.configureMedia(durationMs: 60000);
          playlist.add('C:/a.mp4');
          await controller.playIndex(0);
          engine.buffered.value = 4000;
          engine.aspectRatio.value = 16 / 9;
          engine.subtitleText.value = 'stale subtitle';

          await controller.stopCurrentMedia();

          expect(engine.hasMedia, false);
          expect(engine.state.value, MediaState.idle);
          expect(engine.position.value, 0);
          expect(engine.duration.value, 0);
          expect(engine.buffered.value, 0);
          expect(engine.aspectRatio.value, 0);
          expect(engine.subtitleText.value, '');
          expect(engine.mediaInfo, const MediaInfo());
          expect(controller.currentFileName.value, '');
          expect(playlist.length, 1);
          expect(playlist.currentIndex, 0);
          expect(rebuildCount, greaterThan(0));
        },
      );

      test('keeps the active title when stop fails', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        final titleBeforeStop = controller.currentFileName.value;
        final mediaInfoBeforeStop = engine.mediaInfo;
        engine.failNextStopWith = 'backend unavailable';

        await controller.stopCurrentMedia();

        expect(engine.hasMedia, true);
        expect(engine.mediaInfo, mediaInfoBeforeStop);
        expect(engine.state.value, MediaState.error);
        expect(engine.lastError.value, isNotNull);
        expect(controller.currentFileName.value, titleBeforeStop);
      });

      test('does not let an older stop clear a newer open request', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        await controller.playIndex(0);
        final stopGate = Completer<void>();
        final openGate = Completer<void>();
        engine.stopGate = stopGate;
        engine.openGate = openGate;

        final stopping = controller.stopCurrentMedia();
        final opening = controller.playIndex(1);
        await Future<void>.value();

        expect(engine.state.value, MediaState.opening);
        stopGate.complete();
        await stopping;
        expect(engine.state.value, MediaState.opening);

        openGate.complete();
        await opening;

        expect(engine.hasMedia, true);
        expect(engine.state.value, MediaState.playing);
        expect(controller.currentFileName.value, 'b.mp4');
      });
    });

    group('clearPlaylist', () {
      test('stops engine and clears playlist', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        await controller.clearPlaylist();
        expect(engine.stopCallCount, greaterThanOrEqualTo(1));
        expect(playlist.isEmpty, true);
        expect(controller.currentFileName.value, '');
      });

      test('keeps playlist and title when stop fails', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        await controller.playIndex(0);
        final titleBeforeStop = controller.currentFileName.value;
        engine.failNextStopWith = 'backend unavailable';

        await controller.clearPlaylist();

        expect(engine.hasMedia, true);
        expect(engine.state.value, MediaState.error);
        expect(playlist.length, 2);
        expect(playlist.current?.path, 'C:/a.mp4');
        expect(controller.currentFileName.value, titleBeforeStop);
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

      test('cycles from any starting mode', () {
        // Start from shuffle
        playlist.mode = PlayMode.shuffle;
        controller.togglePlayMode();
        expect(playlist.mode, PlayMode.loopAll);
      });
    });

    // ─── addFiles edge cases ───

    group('addFiles edge cases', () {
      test('addFiles with empty list returns 0', () async {
        final count = await controller.addFiles([]);
        expect(count, 0);
        expect(playlist.isEmpty, true);
      });

      test('addFiles all invalid returns 0', () async {
        final count = await controller.addFiles(['', 'bad.txt', 'noext']);
        expect(count, 0);
        expect(playlist.isEmpty, true);
      });
    });

    // ─── reorder edge cases ───

    group('reorder edge cases', () {
      test('reorder to same position is no-op', () {
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.currentIndex = 1;

        controller.reorder(1, 1);

        // No change — same position
        expect(playlist.items[1].path, 'C:/b.mp4');
        expect(playlist.currentIndex, 1);
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
