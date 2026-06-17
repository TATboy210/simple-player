import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:player_engine/player_engine.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;
  int rebuildCount = 0;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    rebuildCount = 0;
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () => rebuildCount++,
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  /// Helper: register auto-advance listener
  void registerAutoAdvance() {
    engine.state.addListener(() {
      final state = engine.state.value;
      if (state != MediaState.completed) return;
      if (playlist.mode == PlayMode.loopSingle) {
        final idx = playlist.currentIndex;
        if (idx >= 0) {
          controller.playIndex(idx).catchError((e) {});
        }
      } else {
        controller.playNext().catchError((e) {});
      }
    });
  }

  group('StateMonitor', () {
    group('removeAt', () {
      test('stops engine when removing currently-playing item', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        await controller.playIndex(0);
        await controller.removeAt(0);
        expect(engine.stopCallCount, greaterThanOrEqualTo(1));
        expect(playlist.length, 1);
      });

      test('does not stop engine when removing non-current item', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        await controller.playIndex(1);
        final stopsBefore = engine.stopCallCount;
        await controller.removeAt(0);
        expect(engine.stopCallCount, stopsBefore);
      });
    });

    group('clearPlaylist', () {
      test('resets currentFileName to empty', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        expect(controller.currentFileName.value, isNotEmpty);
        controller.clearPlaylist();
        expect(controller.currentFileName.value, '');
      });

      test('triggers onNeedRebuild', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        rebuildCount = 0;
        controller.clearPlaylist();
        expect(rebuildCount, greaterThanOrEqualTo(1));
      });
    });

    group('togglePlayMode', () {
      test('persists mode change', () {
        expect(playlist.mode, PlayMode.loopAll);
        controller.togglePlayMode();
        expect(playlist.mode, PlayMode.loopSingle);
      });
    });

    group('auto-advance', () {
      test('loopSingle replays same index', () async {
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

      test('loopAll wraps around at end', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopAll;
        registerAutoAdvance();
        await controller.playIndex(1);
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0);
      });
    });

    group('pause breakpoint', () {
      test('saves position on pause state', () async {
        await controller.init(); // registers state listener
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        await controller.playIndex(0);
        engine.position.value = 5000;
        engine.state.value = MediaState.paused;
        // allow synchronous listeners and microtasks to run
        await Future.microtask(() {});
        final item = playlist.items[0];
        expect(item.positionMs, 5000);
      });
    });

    group('StateMonitor.init', () {
      test('init with preloaded settings sets volume and mute', () async {
        const settings = AppSettings(
          volume: 0.7,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: true,
        );
        await controller.init(settings: settings);
        expect(engine.volume.value, closeTo(0.7, 0.01));
        expect(engine.isMuted.value, isTrue);
      });

      test('init is idempotent', () async {
        const settings = AppSettings(
          volume: 0.5,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: false,
        );
        await controller.init(settings: settings);
        // Second init should be a no-op
        await controller.init(settings: settings);
        expect(engine.volume.value, closeTo(0.5, 0.01));
      });
    });

    group('StateMonitor auto-advance via init', () {
      test('completed + loopSingle replays via StateMonitor listener',
          () async {
        const settings = AppSettings(
          volume: 1.0,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: false,
        );
        await controller.init(settings: settings);
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopSingle;
        await controller.playIndex(0);
        // Trigger completed state — StateMonitor._onStateChanged should replay
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0);
      });

      test('completed + loopAll advances via StateMonitor listener', () async {
        const settings = AppSettings(
          volume: 1.0,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: false,
        );
        await controller.init(settings: settings);
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopAll;
        await controller.playIndex(0);
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 1);
      });

      test('completed + loopAll wraps around via StateMonitor', () async {
        const settings = AppSettings(
          volume: 1.0,
          lastFile: '',
          windowWidth: 1280,
          windowHeight: 720,
          playMode: 0,
          isMuted: false,
        );
        await controller.init(settings: settings);
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopAll;
        await controller.playIndex(1); // play last item
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0); // wraps to first
      });
    });
  });
}
