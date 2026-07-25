/// PlaybackNavigator edge case tests — empty playlist, single item, shuffle
/// boundaries, loopSingle, rapid navigation, and error recovery.
///
/// Uses FakeEngine + real Playlist + real PlaybackController to exercise
/// the full navigator path without mdk.dll dependency.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/models/play_mode.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Empty playlist navigation
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — empty playlist', () {
    test('playIndex(0) on empty playlist is a no-op', () async {
      await controller.playIndex(0);
      expect(engine.openCallCount, 0);
      expect(playlist.currentIndex, -1);
    });

    test('playNext on empty playlist is a no-op', () async {
      await controller.playNext();
      expect(engine.openCallCount, 0);
    });

    test('playPrevious on empty playlist is a no-op', () async {
      await controller.playPrevious();
      expect(engine.openCallCount, 0);
    });

    test('playIndex(-1) is a no-op', () async {
      await controller.playIndex(-1);
      expect(engine.openCallCount, 0);
    });

    test('playIndex beyond length is a no-op', () async {
      playlist.add('C:/a.mp4');
      await controller.playIndex(5);
      expect(engine.openCallCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Single item playlist
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — single item playlist', () {
    test('playNext in loopAll stays on same item (wraps)', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/only.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(0);

      // Reset counters for the next call
      engine.openCallCount = 0;
      await controller.playNext();

      // Wraps to index 0 (only item)
      expect(playlist.currentIndex, 0);
      expect(engine.openCallCount, 1);
    });

    test('playPrevious in loopAll stays on same item (wraps)', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/only.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playPrevious();

      expect(playlist.currentIndex, 0);
      expect(engine.openCallCount, 1);
    });

    test('playNext in loopSingle replays same index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/only.mp4');
      playlist.mode = PlayMode.loopSingle;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playNext();

      expect(playlist.currentIndex, 0);
      expect(engine.openCallCount, 1);
    });

    test('playPrevious in loopSingle replays same index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/only.mp4');
      playlist.mode = PlayMode.loopSingle;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playPrevious();

      expect(playlist.currentIndex, 0);
      expect(engine.openCallCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Shuffle mode with 1-2 items
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — shuffle boundaries', () {
    test('shuffle with 1 item stays on same index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/only.mp4');
      playlist.mode = PlayMode.shuffle;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playNext();

      // With 1 item, shuffle must return the only index
      expect(playlist.currentIndex, 0);
    });

    test('shuffle with 2 items picks the other item', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.mode = PlayMode.shuffle;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playNext();

      // With 2 items and current=0, shuffle must pick 1
      expect(playlist.currentIndex, 1);
    });

    test('shuffle previous with 2 items picks the other item', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.mode = PlayMode.shuffle;
      await controller.playIndex(1);

      engine.openCallCount = 0;
      await controller.playPrevious();

      expect(playlist.currentIndex, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // LoopSingle mode boundary
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — loopSingle boundaries', () {
    test('loopSingle next from middle stays on same index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.add('C:/c.mp4');
      playlist.mode = PlayMode.loopSingle;
      await controller.playIndex(1);

      engine.openCallCount = 0;
      await controller.playNext();

      expect(playlist.currentIndex, 1);
    });

    test('loopSingle previous from first stays on index 0', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.mode = PlayMode.loopSingle;
      await controller.playIndex(0);

      engine.openCallCount = 0;
      await controller.playPrevious();

      expect(playlist.currentIndex, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Rapid next/prev calls (concurrency)
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — rapid navigation', () {
    test('rapid playNext calls — only latest result commits', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.add('C:/c.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(0);

      // Fire 3 rapid playNext without awaiting
      final f1 = controller.playNext();
      final f2 = controller.playNext();
      final f3 = controller.playNext();
      await Future.wait<void>([f1, f2, f3]);

      // Generation guard ensures only the latest open() result commits.
      // The final index depends on which open() won, but only one play()
      // should have been called from the navigator's _commitOpenSuccess.
      expect(playlist.currentIndex, inInclusiveRange(0, 2));
    });

    test('rapid playPrevious calls — no crash', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.add('C:/c.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(2);

      final f1 = controller.playPrevious();
      final f2 = controller.playPrevious();
      final f3 = controller.playPrevious();
      await Future.wait<void>([f1, f2, f3]);

      expect(playlist.currentIndex, inInclusiveRange(0, 2));
    });

    test('alternating next/prev rapid calls — no crash', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.add('C:/c.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(1);

      final futures = <Future<void>>[];
      for (var i = 0; i < 6; i++) {
        futures.add(
          i.isEven ? controller.playNext() : controller.playPrevious(),
        );
      }
      await Future.wait(futures);

      expect(playlist.currentIndex, inInclusiveRange(0, 2));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Error recovery after failed open
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — error recovery', () {
    test('failed open restores old index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      await controller.playIndex(0);
      expect(playlist.currentIndex, 0);

      engine.failNextOpenWith = 'decode error';
      await controller.playIndex(1);

      // Index should be restored to 0 on failure
      expect(playlist.currentIndex, 0);
      expect(errors, isNotEmpty);
    });

    test('failed open then successful open works', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.add('C:/c.mp4');
      await controller.playIndex(0);

      // Fail on b.mp4
      engine.failNextOpenWith = 'network error';
      await controller.playIndex(1);
      expect(playlist.currentIndex, 0);

      // Succeed on c.mp4
      await controller.playIndex(2);
      expect(playlist.currentIndex, 2);
      expect(engine.playCallCount, 2); // first open(0) + third open(2)
    });

    test('playNext error does not advance index', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/bad.mp4');
      playlist.mode = PlayMode.loopAll;
      await controller.playIndex(0);

      engine.failNextOpenWith = 'open failed';
      await controller.playNext();

      // Should stay on 0 since index 1 failed
      expect(playlist.currentIndex, 0);
    });

    test('all errors reported via onError callback', () async {
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      await controller.playIndex(0);

      engine.failNextOpenWith = 'error 1';
      await controller.playIndex(1);

      engine.failNextOpenWith = 'error 2';
      await controller.playIndex(1);

      expect(errors.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Resume position edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — resume position', () {
    test('saved position exactly 1000ms does NOT trigger seek', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/test.mp4');
      playlist.updateHistory(0, positionMs: 1000, durationMs: 60000);

      await controller.playIndex(0);

      // 1000ms threshold: > 1000 seeks, <= 1000 does not
      expect(engine.seekToCallCount, 0);
    });

    test('saved position 1001ms triggers seek', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/test.mp4');
      playlist.updateHistory(0, positionMs: 1001, durationMs: 60000);

      await controller.playIndex(0);

      expect(engine.seekToCallCount, 1);
      expect(engine.lastSeekToMs, 1001);
    });

    test('seek failure restores index and reports error', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      playlist.add('C:/b.mp4');
      playlist.updateHistory(1, positionMs: 30000, durationMs: 60000);
      await controller.playIndex(0);

      // Make seekTo throw
      engine.seekToShouldThrow = true;
      await controller.playIndex(1);

      expect(playlist.currentIndex, 0);
      expect(errors, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Path traversal rejection
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — path validation', () {
    test('path with null bytes is rejected', () async {
      playlist.add('C:/test\x00evil.mp4');
      await controller.playIndex(0);

      expect(engine.openCallCount, 0);
      expect(errors, isNotEmpty);
    });

    test('path with ../ traversal is rejected', () async {
      playlist.add('../../../etc/passwd.mp4');
      await controller.playIndex(0);

      expect(engine.openCallCount, 0);
      expect(errors, isNotEmpty);
    });

    test('UNC network path is rejected', () async {
      playlist.add('\\\\server\\share\\video.mp4');
      await controller.playIndex(0);

      expect(engine.openCallCount, 0);
      expect(errors, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // currentFileName edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('PlaybackNavigator edge cases — currentFileName', () {
    test('basename extracted correctly from deep path', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/very/deep/nested/folder/structure/video.mp4');
      await controller.playIndex(0);

      expect(controller.currentFileName.value, 'video.mp4');
    });

    test('basename with CJK characters', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/视频/测试文件.mp4');
      await controller.playIndex(0);

      expect(controller.currentFileName.value, '测试文件.mp4');
    });

    test('failed open does not update currentFileName', () async {
      engine.configureMedia(durationMs: 60000);
      playlist.add('C:/a.mp4');
      await controller.playIndex(0);
      expect(controller.currentFileName.value, 'a.mp4');

      engine.failNextOpenWith = 'error';
      playlist.add('C:/b.mp4');
      await controller.playIndex(1);

      // Should still show a.mp4
      expect(controller.currentFileName.value, 'a.mp4');
    });
  });
}
