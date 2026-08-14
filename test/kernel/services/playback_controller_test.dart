import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/services/subtitle_service.dart';
import 'package:simple_player_flutter/kernel/services/track_preference_service.dart';

import '../../helpers/fake_engine.dart';

/// 记录 controller 成功打开后请求的字幕扫描，避免测试触发真实目录 I/O。
class _RecordingSubtitleService extends SubtitleService {
  _RecordingSubtitleService(super.engine);

  final List<String> detectedPaths = <String>[];

  @override
  Future<void> detectAndLoad(String mediaPath) async {
    detectedPaths.add(mediaPath);
  }
}

/// 记录 controller 成功打开后恢复轨道偏好的调用。
class _RecordingTrackPreferenceService extends TrackPreferenceService {
  _RecordingTrackPreferenceService(super.engine);

  final List<MediaInfo> restoredMedia = <MediaInfo>[];

  @override
  void restoreAfterOpen(MediaInfo mediaInfo) {
    restoredMedia.add(mediaInfo);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine engine;
  late PlaybackController controller;
  late List<PlayerError> errors;

  setUp(() {
    engine = FakeEngine();
    errors = <PlayerError>[];
    controller = PlaybackController(engine: engine, onError: errors.add);
  });

  tearDown(() {
    controller.dispose();
    engine.dispose();
  });

  group('PlaybackController', () {
    group('基础播放控制门面', () {
      test('togglePlayPause delegates to the media engine', () {
        controller.togglePlayPause();

        expect(engine.togglePlayPauseCallCount, 1);
      });

      test('skipBack delegates the requested milliseconds', () {
        controller.skipBack(10000);

        expect(engine.skipBackCallCount, 1);
        expect(engine.lastSkipBackMs, 10000);
      });

      test('skipForward delegates the requested milliseconds', () {
        controller.skipForward(30000);

        expect(engine.skipForwardCallCount, 1);
        expect(engine.lastSkipForwardMs, 30000);
      });

      test('play and pause expose the current engine state', () {
        controller.play();
        expect(controller.isPlaying, true);

        controller.pause();
        expect(controller.isPlaying, false);
        expect(engine.playCallCount, 1);
        expect(engine.pauseCallCount, 1);
      });
    });

    group('openAndPlay', () {
      test(
        'opens one file, starts playback, and publishes its identity',
        () async {
          engine.configureMedia(durationMs: 120000);

          final result = await controller.openAndPlay('C:/test/video.mp4');

          expect(result, true);
          expect(engine.openPaths, <String>['C:/test/video.mp4']);
          expect(engine.playCallCount, 1);
          expect(engine.state.value, MediaState.playing);
          expect(controller.currentPath.value, 'C:/test/video.mp4');
          expect(controller.currentFileName.value, 'video.mp4');
          expect(controller.validationError.value, isNull);
          expect(errors, isEmpty);
        },
      );

      test('rejects an invalid path before calling the engine', () async {
        final result = await controller.openAndPlay('');

        expect(result, false);
        expect(engine.openCallCount, 0);
        expect(engine.playCallCount, 0);
        expect(controller.currentPath.value, isNull);
        expect(controller.currentFileName.value, isEmpty);
        expect(controller.validationError.value, isNotNull);
        expect(errors, hasLength(1));
        expect(errors.single, isA<FileError>());
      });

      test('rejects a non-media extension before calling the engine', () async {
        final result = await controller.openAndPlay('C:/test/file.txt');

        expect(result, false);
        expect(engine.openCallCount, 0);
        expect(controller.validationError.value, contains('不支持'));
      });

      test('keeps the previous media identity when opening fails', () async {
        engine.configureMedia(durationMs: 60000);
        expect(await controller.openAndPlay('C:/test/first.mp4'), true);
        engine.failNextOpenWith = 'backend unavailable';

        final result = await controller.openAndPlay('C:/test/broken.mp4');

        expect(result, false);
        expect(engine.playCallCount, 1);
        expect(controller.currentPath.value, 'C:/test/first.mp4');
        expect(controller.currentFileName.value, 'first.mp4');
        expect(errors, hasLength(1));
        expect(errors.single.message, 'backend unavailable');
      });

      test(
        'a superseded request cannot publish stale playback state',
        () async {
          engine.configureMedia(durationMs: 60000);
          final openGate = Completer<void>();
          engine.openGate = openGate;

          final older = controller.openAndPlay('C:/test/older.mp4');
          final latest = controller.openAndPlay('C:/test/latest.mp4');
          await Future<void>.value();
          openGate.complete();

          expect(await older, false);
          expect(await latest, true);
          expect(engine.playCallCount, 1);
          expect(controller.currentPath.value, 'C:/test/latest.mp4');
          expect(controller.currentFileName.value, 'latest.mp4');
          expect(errors, isEmpty);
        },
      );

      test(
        'only the latest request triggers open-success side effects',
        () async {
          final subtitleService = _RecordingSubtitleService(engine);
          final trackPreferenceService = _RecordingTrackPreferenceService(
            engine,
          );
          controller.dispose();
          controller = PlaybackController(
            engine: engine,
            onError: errors.add,
            subtitleService: subtitleService,
            trackPreferenceService: trackPreferenceService,
          );
          engine.configureMedia(durationMs: 60000);
          final openGate = Completer<void>();
          engine.openGate = openGate;

          final older = controller.openAndPlay('C:/test/older.mp4');
          final latest = controller.openAndPlay('C:/test/latest.mp4');
          await Future<void>.value();
          openGate.complete();

          expect(await older, false);
          expect(await latest, true);
          expect(subtitleService.detectedPaths, <String>['C:/test/latest.mp4']);
          expect(trackPreferenceService.restoredMedia, hasLength(1));
          expect(engine.playCallCount, 1);
          expect(controller.currentPath.value, 'C:/test/latest.mp4');
        },
      );
    });

    group('stopCurrentMedia', () {
      test(
        'clears the published identity after the engine unloads media',
        () async {
          engine.configureMedia(durationMs: 60000);
          await controller.openAndPlay('C:/test/video.mp4');
          engine.buffered.value = 4000;
          engine.subtitleText.value = 'stale subtitle';

          await controller.stopCurrentMedia();

          expect(engine.hasMedia, false);
          expect(engine.state.value, MediaState.idle);
          expect(engine.position.value, 0);
          expect(engine.duration.value, 0);
          expect(engine.buffered.value, 0);
          expect(engine.subtitleText.value, isEmpty);
          expect(engine.mediaInfo, const MediaInfo());
          expect(controller.currentPath.value, isNull);
          expect(controller.currentFileName.value, isEmpty);
        },
      );

      test(
        'keeps the published identity when the engine cannot unload',
        () async {
          engine.configureMedia(durationMs: 60000);
          await controller.openAndPlay('C:/test/video.mp4');
          final mediaInfoBeforeStop = engine.mediaInfo;
          engine.failNextStopWith = 'backend unavailable';

          await controller.stopCurrentMedia();

          expect(engine.hasMedia, true);
          expect(engine.mediaInfo, mediaInfoBeforeStop);
          expect(engine.state.value, MediaState.error);
          expect(engine.lastError.value, isNotNull);
          expect(controller.currentPath.value, 'C:/test/video.mp4');
          expect(controller.currentFileName.value, 'video.mp4');
        },
      );

      test('an older stop cannot clear a newer open request', () async {
        engine.configureMedia(durationMs: 60000);
        await controller.openAndPlay('C:/test/first.mp4');
        final stopGate = Completer<void>();
        final openGate = Completer<void>();
        engine.stopGate = stopGate;
        engine.openGate = openGate;

        final stopping = controller.stopCurrentMedia();
        final opening = controller.openAndPlay('C:/test/latest.mp4');
        await Future<void>.value();

        expect(engine.state.value, MediaState.opening);
        stopGate.complete();
        await stopping;
        expect(controller.currentPath.value, 'C:/test/first.mp4');

        openGate.complete();
        expect(await opening, true);
        expect(engine.hasMedia, true);
        expect(engine.state.value, MediaState.playing);
        expect(controller.currentPath.value, 'C:/test/latest.mp4');
        expect(controller.currentFileName.value, 'latest.mp4');
      });

      test(
        'a stop supersedes a pending open without restoring its identity',
        () async {
          final openGate = Completer<void>();
          engine.openGate = openGate;

          final opening = controller.openAndPlay('C:/test/pending.mp4');
          await Future<void>.value();
          await controller.stopCurrentMedia();
          openGate.complete();

          expect(await opening, false);
          expect(engine.playCallCount, 0);
          expect(engine.hasMedia, false);
          expect(controller.currentPath.value, isNull);
          expect(controller.currentFileName.value, isEmpty);
        },
      );
    });
  });
}
