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
    group('标题跟随队列切换 (v0.0.6.1)', () {
      test('播放列表 jumpTo — 标题/路径跟随实际装载条目', () async {
        // 模拟播放列表场景: 队列已装载, playEntryAt 走 jumpTo 分支
        // (不经过 openAndPlay, 旧实现标题因此永不更新).
        await engine.openPlaylist([
          r'D:\v\a.mp4',
          r'D:\v\b.mp4',
        ], startIndex: 0);
        engine.state.value = MediaState.playing;
        engine.play();

        expect(controller.currentFileName.value, 'a.mp4');
        expect(controller.currentPath.value, r'D:\v\a.mp4');

        await engine.jumpTo(1);

        expect(controller.currentFileName.value, 'b.mp4');
        expect(controller.currentPath.value, r'D:\v\b.mp4');
      });

      test('自动续播 — 队列 index 变化时标题跟随', () async {
        await engine.openPlaylist(['a.mp4', 'b.mp4'], startIndex: 0);
        engine.state.value = MediaState.playing;
        engine.play();
        expect(controller.currentFileName.value, 'a.mp4');

        // EOF 自动续播: mpv 直接推进 index + revision (无 openAndPlay).
        engine.queueIndex.value = 1;
        engine.queueRevision.value++;

        expect(controller.currentFileName.value, 'b.mp4');
      });

      test('门控 — opening/idle (乐观镜像) 不写入标题', () async {
        // openPlaylist 内部乐观镜像先于装载确认; 失败时状态回落 idle,
        // 标题不得短暂指向打不开的文件.
        await engine.openPlaylist(['a.mp4'], startIndex: 0);
        // openPlaylist 成功后 state=idle (FakeEngine 同构) — 手动清空标题
        // 模拟"尚未确认装载", 随后的 revision 抖动不得写入.
        controller.currentFileName.value = '';
        controller.currentPath.value = null;
        engine.queueRevision.value++; // 乐观镜像抖动

        expect(controller.currentFileName.value, '');
        expect(controller.currentPath.value, isNull);
      });

      test('stopCurrentMedia — 标题清空契约保持', () async {
        await engine.openPlaylist(['a.mp4'], startIndex: 0);
        engine.state.value = MediaState.playing;
        engine.play();
        expect(controller.currentFileName.value, 'a.mp4');

        await controller.stopCurrentMedia();

        expect(controller.currentFileName.value, '');
        expect(controller.currentPath.value, isNull);
      });
    });

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

      test('play and pause expose the current engine state', () async {
        // 先加载媒体 — 空置态 (hasMedia=false) play 已被引擎幂等忽略
        // (guard 契约由 race_condition_test 的 Play guard group 锁定).
        await controller.openAndPlay('/test.mp4');
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
          // v0.0.5: openAndPlay 走队列装载 (同目录扫描退化 → 单元素队列).
          expect(engine.openPlaylistCallCount, 1);
          expect(engine.lastOpenPlaylistPaths, <String>['C:/test/video.mp4']);
          expect(engine.lastOpenPlaylistStartIndex, 0);
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
        expect(engine.openPlaylistCallCount, 0);
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
        expect(engine.openPlaylistCallCount, 0);
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
          await pumpEventQueue(); // flush 同目录扫描 IO, 使 openPlaylist 到达 gate
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
          await pumpEventQueue(); // flush 同目录扫描 IO, 使 openPlaylist 到达 gate
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
        // flush 同目录扫描 IO, 使 openPlaylist 到达 gate — CI 磁盘 IO 时序
        // 不定, 固定 pump 一次在慢盘上不够; opening 在 openGate 之前发布,
        // 轮询必然收敛 (上限防病态挂死).
        var pumps = 0;
        while (engine.state.value != MediaState.opening && pumps < 200) {
          await pumpEventQueue();
          pumps++;
        }

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
          await pumpEventQueue(); // flush 同目录扫描 IO, 使 openPlaylist 到达 gate
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
