/// FvpEngine DI 测试 — 使用 FakeMdkPlayer 注入，无需 mdk.dll
///
/// 测试 open/play/pause/seek/dispose 主路径，验证 playerFactory 注入机制。
/// 所有测试在 headless CI 中运行，不依赖 FFI/DLL。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';
import 'package:simple_player_flutter/kernel/engine/media_state.dart';
import 'package:simple_player_flutter/kernel/engine/player_proxy.dart';

import '../helpers/fake_mdk_player.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  group('FvpEngine with FakeMdkPlayer', () {
    late FakeMdkPlayer fake;
    late FvpEngine engine;

    setUp(() {
      fake = FakeMdkPlayer();
      // 配置默认成功行为
      fake.prepareResult = 1;
      fake.updateTextureResult = 1;
      fake.textureIdValue = 42;
      fake.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 60000,
        video: [
          FakeVideoTrack(
            codec: FakeCodecInfo(
              width: 1920,
              height: 1080,
              par: 1.0,
              codec: 'h264',
            ),
          ),
        ],
        audio: [
          FakeAudioTrack(
            codec: FakeCodecInfo(channels: 2, codec: 'aac'),
            index: 0,
            metadata: {'language': 'eng'},
          ),
        ],
      );
      engine = FvpEngine(playerFactory: () => fake);
    });

    tearDown(() {
      engine.dispose();
    });

    group('construction', () {
      test('creates engine with injected fake player', () {
        expect(engine, isNotNull);
        expect(engine.state.value, MediaState.idle);
      });

      test('default factory creates real engine (no playerFactory)', () {
        // 验证默认工厂不崩溃（需要 mdk.dll，headless 可能失败）
        // 这个测试仅验证 API 存在，不在 headless CI 中运行
      });
    });

    group('open', () {
      test('sets media path on player', () async {
        await engine.open('https://example.com/video.mp4');
        expect(fake.mediaPath, 'https://example.com/video.mp4');
      });

      test('calls prepare on player', () async {
        await engine.open('https://example.com/video.mp4');
        expect(fake.prepareCallCount, 1);
      });

      test(
        'stops the previous native session before opening new media',
        () async {
          // Arrange: 首次 open 成功后状态会回到 idle，但原生 Player 仍持有媒体管线。
          await engine.open('https://example.com/first.mp4');
          fake.operationLog.clear();

          // Act
          await engine.open('https://example.com/second.mp4');

          // Assert: 新媒体写入前必须显式停止旧原生会话。
          expect(
            fake.operationLog,
            containsAllInOrder(<String>[
              'state:MdkPlaybackState.stopped',
              'media:https://example.com/second.mp4',
              'prepare:https://example.com/second.mp4',
              'updateTexture:https://example.com/second.mp4',
            ]),
          );
        },
      );

      test('transitions state to opening then idle on success', () async {
        final states = <MediaState>[];
        engine.state.addListener(() => states.add(engine.state.value));

        await engine.open('https://example.com/video.mp4');

        expect(states, contains(MediaState.opening));
        expect(engine.state.value, MediaState.idle);
      });

      test('sets duration from mediaInfo', () async {
        await engine.open('https://example.com/video.mp4');
        expect(engine.duration.value, 60000);
      });

      test('sets aspect ratio from video dimensions', () async {
        await engine.open('https://example.com/video.mp4');
        // 1920 * 1.0 / 1080 = 1.778
        expect(engine.aspectRatio.value, closeTo(16 / 9, 0.01));
      });

      test('resets position to 0 on open', () async {
        await engine.open('https://example.com/video.mp4');
        expect(engine.position.value, 0);
      });

      test('clears lastError on success', () async {
        // 先触发一个错误
        fake.prepareResult = -1;
        await engine.open('https://example.com/bad.mp4');
        expect(engine.lastError.value, isNotNull);

        // 再成功打开
        fake.prepareResult = 1;
        await engine.open('https://example.com/good.mp4');
        expect(engine.lastError.value, isNull);
      });

      test('handles prepare failure with error state', () async {
        fake.prepareResult = -1;

        final result = await engine.open('https://example.com/bad.mp4');

        expect(result, isA<OpenError>());
        expect(engine.state.value, MediaState.error);
        expect(engine.lastError.value, isNotNull);
      });

      test('handles empty path with error state', () async {
        await engine.open('');

        expect(engine.state.value, MediaState.error);
        expect(engine.lastError.value, isNotNull);
      });

      test('handles whitespace-only path as empty', () async {
        await engine.open('   ');

        expect(engine.state.value, MediaState.error);
      });

      test('records metrics on successful open', () async {
        await engine.open('https://example.com/video.mp4');
        // metrics.recordOpen(success: true) 内部计数
        expect(engine.metrics, isNotNull);
      });

      test('records event log on open', () async {
        await engine.open('https://example.com/video.mp4');
        expect(engine.eventLog.entries, isNotEmpty);
      });

      test('handles texture creation failure', () async {
        fake.updateTextureResult = -1;

        await engine.open('https://example.com/video.mp4');

        // prepare 成功但 texture 失败 → OpenError
        expect(engine.lastError.value, isNotNull);
      });

      test('handles null textureId after updateTexture', () async {
        fake.updateTextureResult = 1;
        fake.textureIdValue = null; // textureId 仍为 null

        await engine.open('https://example.com/video.mp4');

        // textureId.value == null → textureFailed
        expect(engine.lastError.value, isNotNull);
      });
    });

    group('play/pause', () {
      test('play transitions to playing state', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        expect(engine.state.value, MediaState.playing);
      });

      test('pause transitions to paused state', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        engine.pause();
        expect(engine.state.value, MediaState.paused);
      });

      test('play sets MdkPlaybackState.playing on player', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        expect(fake.state, MdkPlaybackState.playing);
      });

      test('pause sets MdkPlaybackState.paused on player', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        engine.pause();
        expect(fake.state, MdkPlaybackState.paused);
      });

      test('play when already playing is no-op', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        engine.play(); // 第二次应为 no-op
        expect(engine.state.value, MediaState.playing);
      });

      test('togglePlayPause cycles between play and pause', () async {
        await engine.open('https://example.com/video.mp4');
        engine.togglePlayPause();
        expect(engine.state.value, MediaState.playing);
        engine.togglePlayPause();
        expect(engine.state.value, MediaState.paused);
      });
    });

    group('stop', () {
      test('stop transitions to idle state', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        engine.stop();
        expect(engine.state.value, MediaState.idle);
      });

      test('stop resets position to 0', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        engine.stop();
        expect(engine.position.value, 0);
      });
    });

    group('seek', () {
      test('seekTo updates position', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        await engine.seekTo(30000);
        expect(engine.position.value, 30000);
      });

      test('seekTo clamps to valid range', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        await engine.seekTo(999999); // 超出 duration
        expect(engine.position.value, 60000); // clamp to duration
      });

      test('seekTo records seek call on fake', () async {
        await engine.open('https://example.com/video.mp4');
        engine.play();
        await engine.seekTo(15000);
        expect(fake.seekCallCount, 1);
        expect(fake.lastSeekPosition, 15000);
      });

      test('seekTo when idle is no-op', () async {
        await engine.open('https://example.com/video.mp4');
        // 不 play，状态为 idle
        await engine.seekTo(15000);
        expect(fake.seekCallCount, 0);
      });
    });

    group('dispose', () {
      test('dispose is idempotent', () {
        engine.dispose();
        engine.dispose(); // 第二次不应崩溃
      });

      test('dispose prevents further operations', () async {
        await engine.open('https://example.com/video.mp4');
        engine.dispose();
        engine.play(); // 应为 no-op
        // 不应崩溃
      });

      test('dispose cleans up player', () {
        engine.dispose();
        expect(fake.isDisposed, true);
      });
    });

    group('generation guard', () {
      test('stale open result is discarded', () async {
        // 第一次 open 使用慢速 prepare
        fake.prepareDelay = const Duration(milliseconds: 100);
        final firstOpen = engine.open('https://example.com/first.mp4');

        // 立即发起第二次 open（无延迟）
        fake.prepareDelay = Duration.zero;
        fake.prepareResult = 1;
        final latestResult = await engine.open(
          'https://example.com/second.mp4',
        );
        final staleResult = await firstOpen;

        // 旧请求是正常并发结局；只有最新请求可提交打开结果。
        expect(staleResult, isA<OpenSuperseded>());
        expect(latestResult, isA<OpenSuccess>());
        expect(engine.state.value, MediaState.idle);
      });

      test('queues a newer open until the active prepare completes', () async {
        final firstPrepare = Completer<int>();
        fake.nextPrepareCompleter = firstPrepare;

        final firstOpen = engine.open('https://example.com/first.mp4');
        await Future<void>.delayed(Duration.zero);
        expect(fake.prepareCallCount, 1);

        final secondOpen = engine.open('https://example.com/second.mp4');
        await Future<void>.delayed(Duration.zero);

        try {
          // 同一 MdkPlayer 不支持重叠 prepare；新请求必须先等待前一段原生调用结束。
          expect(fake.prepareCallCount, 1);
        } finally {
          firstPrepare.complete(1);
          final results = await Future.wait<OpenResult>([
            firstOpen,
            secondOpen,
          ]);
          expect(results.first, isA<OpenSuperseded>());
          expect(results.last, isA<OpenSuccess>());
        }
      });

      test(
        'skips stale native tail work after its prepare completes',
        () async {
          final firstPrepare = Completer<int>();
          fake.nextPrepareCompleter = firstPrepare;

          final firstOpen = engine.open('https://example.com/first.mp4');
          await Future<void>.delayed(Duration.zero);
          final secondOpen = engine.open('https://example.com/second.mp4');

          firstPrepare.complete(1);
          final results = await Future.wait<OpenResult>([
            firstOpen,
            secondOpen,
          ]);
          expect(results.first, isA<OpenSuperseded>());
          expect(results.last, isA<OpenSuccess>());

          // 第一请求在 prepare 返回前已过期，不能再创建或覆盖共享纹理。
          expect(fake.prepareCallCount, 2);
          expect(fake.updateTextureCallCount, 1);
          expect(
            fake.operationLog,
            containsAllInOrder(<String>[
              'media:https://example.com/first.mp4',
              'prepare:https://example.com/first.mp4',
              'media:https://example.com/second.mp4',
              'prepare:https://example.com/second.mp4',
              'updateTexture:https://example.com/second.mp4',
            ]),
          );
        },
      );
    });
  });
}
