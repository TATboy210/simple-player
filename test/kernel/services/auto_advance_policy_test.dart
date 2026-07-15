import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/persistence/settings_store.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late Playlist playlist;
  late PlaybackController controller;

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () {},
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('AutoAdvancePolicy', () {
    group('via init (StateMonitor listener)', () {
      test('completed + loopSingle replays', () async {
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
        // Trigger completed state — AutoAdvancePolicy should replay
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0);
      });

      test('completed + loopAll advances', () async {
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

      test('completed + loopAll wraps around', () async {
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

    group('direct (without init)', () {
      test('loopSingle replays same index', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopSingle;
        // Register auto-advance listener directly (simulating init)
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
        // Register auto-advance listener directly
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
        await controller.playIndex(1);
        engine.simulateCompleted();
        await Future(() {});
        expect(playlist.currentIndex, 0);
      });
    });
  });
}
