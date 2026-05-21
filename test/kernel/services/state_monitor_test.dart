import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/models/media_state.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/window/aspect_ratio_service.dart';
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
        await Future(() {});
        final item = playlist.items[0];
        expect(item.positionMs, 5000);
      });
    });
  });

  group('aspect ratio integration (WP-01..WP-04)', () {
    final List<MethodCall> aspectCalls = [];

    setUp(() {
      aspectCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            (MethodCall methodCall) async {
              aspectCalls.add(methodCall);
              return null;
            },
          );
      // Reset AspectRatioService internal state by setting ratio to 0
      AspectRatioService.I.setAspectRatio(0.0);
      aspectCalls.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.simple_player/aspect_ratio'),
            null,
          );
    });

    test('playing locks aspect ratio to video ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 2.35; // Cinema ratio
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);

      // StateMonitor._onStateChanged fires synchronously on state change
      // AspectRatioService.I.matchVideo(2.35) should have been called
      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      expect(aspectCalls.last.arguments, closeTo(2.35, 0.01));
    });

    test('stopped unlocks aspect ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 1.78;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      aspectCalls.clear();

      engine.stop();
      await Future(() {});

      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isNotEmpty);
    });

    test('paused does NOT unlock aspect ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 1.78;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      aspectCalls.clear();

      engine.pause();
      await Future(() {});

      // No new aspect ratio call should have been made
      // (pause saves breakpoint but does not touch aspect ratio)
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isEmpty);
    });

    test('completed unlocks aspect ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 1.78;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      aspectCalls.clear();

      engine.simulateCompleted();
      await Future(() {});

      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isNotEmpty);
    });

    test('error unlocks aspect ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 1.78;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      aspectCalls.clear();

      engine.simulateError('test error');
      await Future(() {});

      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isNotEmpty);
    });

    test('idle unlocks aspect ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 1.78;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      aspectCalls.clear();

      engine.state.value = MediaState.idle;
      await Future(() {});

      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isNotEmpty);
    });

    test('playing with zero ratio does not call matchVideo', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 0.0;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);

      // matchVideo(0) is a no-op, so no setAspectRatio call
      final lockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && (c.arguments as double) > 0,
      );
      expect(lockCalls, isEmpty);
    });

    test('rapid state changes maintain correct ratio', () async {
      await controller.init();
      engine.configureMedia(durationMs: 60000);
      engine.aspectRatio.value = 2.35;
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);

      // Playing -> pause -> playing should maintain lock
      engine.pause();
      engine.play();
      await Future(() {});

      // The last call should be matchVideo(2.35) from the second play
      expect(aspectCalls, isNotEmpty);
      expect(aspectCalls.last.method, 'setAspectRatio');
      expect(aspectCalls.last.arguments, closeTo(2.35, 0.01));

      // No unlock calls should have occurred during pause
      final unlockCalls = aspectCalls.where(
        (c) => c.method == 'setAspectRatio' && c.arguments == 0.0,
      );
      expect(unlockCalls, isEmpty);
    });
  });
}
