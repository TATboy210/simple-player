import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
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
  List<Object> errors = [];

  setUp(() {
    engine = FakeEngine();
    playlist = Playlist();
    errors = [];
    controller = PlaybackController(
      engine: engine,
      playlist: playlist,
      onNeedRebuild: () {},
      onError: (e) => errors.add(e),
    );
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('PlaybackNavigator', () {
    group('playIndex', () {
      test('sets currentFileName on success', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/test/my_video.mp4');
        await controller.playIndex(0);
        expect(controller.currentFileName.value, 'my_video.mp4');
      });

      test('restores old index on engine.open failure', () async {
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        await controller.playIndex(0);
        final oldIndex = playlist.currentIndex;
        engine.failNextOpenWith = 'open failed';
        await controller.playIndex(1);
        expect(playlist.currentIndex, oldIndex);
      });

      test('generation guard: only last request wins', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        final f1 = controller.playIndex(0);
        final f2 = controller.playIndex(1);
        final f3 = controller.playIndex(2);
        await f1;
        await f2;
        await f3;
        expect(playlist.currentIndex, 2);
        expect(controller.navigator.currentGeneration, 3);
      });

      test('reports error via onError callback on failure', () async {
        playlist.add('C:/a.mp4');
        engine.failNextOpenWith = 'decode failed';
        await controller.playIndex(0);
        expect(errors, isNotEmpty);
      });

      test('ignores out-of-range index', () async {
        await controller.playIndex(-1);
        await controller.playIndex(99);
        expect(engine.openCallCount, 0);
      });
    });

    group('resume on open', () {
      test('seeks to saved position when positionMs > 1000', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/test/video.mp4');
        // Simulate a saved position
        playlist.updateHistory(0, positionMs: 30000, durationMs: 60000);
        engine.seekToCallCount = 0;
        engine.lastSeekToMs = null;
        await controller.playIndex(0);
        expect(engine.seekToCallCount, 1);
        expect(engine.lastSeekToMs, 30000);
      });

      test('does not seek when positionMs is null', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/test/video.mp4');
        engine.seekToCallCount = 0;
        await controller.playIndex(0);
        // positionMs defaults to null for fresh items
        expect(engine.seekToCallCount, 0);
      });

      test('does not seek when positionMs <= 1000', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/test/video.mp4');
        playlist.updateHistory(0, positionMs: 500, durationMs: 60000);
        engine.seekToCallCount = 0;
        await controller.playIndex(0);
        expect(engine.seekToCallCount, 0);
      });
    });

    group('path validation', () {
      test('rejects path traversal via onError', () async {
        // Add path directly to playlist, bypassing openAndPlay validation
        playlist.add('../../../etc/passwd.mp4');
        await controller.playIndex(0);
        expect(errors, isNotEmpty);
        expect(errors.first.toString(), contains('路径不安全'));
      });
    });

    group('playNext / playPrevious', () {
      test('playPrevious at start in loopAll wraps to end', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopAll;
        await controller.playIndex(0);
        await controller.playPrevious();
        expect(playlist.currentIndex, 1);
      });

      test('playNext at end in loopAll wraps to first', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.mode = PlayMode.loopAll;
        await controller.playIndex(2); // last item
        await controller.playNext();
        expect(playlist.currentIndex, 0);
      });

      test('playNext in loopSingle replays same index', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopSingle;
        await controller.playIndex(0);
        await controller.playNext();
        expect(playlist.currentIndex, 0);
      });

      test('playPrevious in loopSingle replays same index', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.mode = PlayMode.loopSingle;
        await controller.playIndex(1);
        await controller.playPrevious();
        expect(playlist.currentIndex, 1);
      });

      test('playNext at end in shuffle mode advances to different index', () async {
        engine.configureMedia(durationMs: 60000);
        playlist.add('C:/a.mp4');
        playlist.add('C:/b.mp4');
        playlist.add('C:/c.mp4');
        playlist.mode = PlayMode.shuffle;
        await controller.playIndex(0);
        await controller.playNext();
        // shuffle picks a random different index
        expect(playlist.currentIndex, isNot(0));
        expect(playlist.currentIndex, inInclusiveRange(0, 2));
      });
    });

    group('path validation edge cases', () {
      test('rejects path with null bytes', () async {
        playlist.add('C:/test\x00evil.mp4');
        await controller.playIndex(0);
        expect(errors, isNotEmpty);
      });
    });
  });
}
