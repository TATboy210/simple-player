/// MediaOpener 测试 — 使用 FakeMdkPlayer，无需 mdk.dll
///
/// 测试 open 流程：路径验证、prepare、metadata 解析、纹理创建。
/// 所有测试在 headless CI 中运行，不依赖 FFI/DLL。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/media_opener.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';
import 'package:simple_player_flutter/kernel/engine/track_manager.dart';

import '../helpers/fake_mdk_player.dart';

void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });
  group('MediaOpener', () {
    late FakeMdkPlayer player;
    late TrackManager trackManager;
    late MediaOpener opener;

    setUp(() {
      player = FakeMdkPlayer();
      trackManager = TrackManager(player);
      opener = MediaOpener(player, trackManager);

      // 默认成功配置
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 1;
      player.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 120000,
        video: [
          FakeVideoTrack(
            codec: FakeCodecInfo(
              width: 3840,
              height: 2160,
              par: 1.0,
              codec: 'hevc',
            ),
          ),
        ],
        audio: [
          FakeAudioTrack(
            codec: FakeCodecInfo(channels: 6, codec: 'ac3'),
            index: 0,
            metadata: {'language': 'chi'},
          ),
          FakeAudioTrack(
            codec: FakeCodecInfo(channels: 2, codec: 'aac'),
            index: 1,
            metadata: {'language': 'eng'},
          ),
        ],
        subtitle: [
          FakeSubtitleTrack(
            index: 0,
            metadata: {'language': 'chi', 'title': '中文'},
          ),
          FakeSubtitleTrack(
            index: 1,
            metadata: {'language': 'eng', 'title': 'English'},
          ),
        ],
      );
    });

    group('open - path validation', () {
      test('returns error for empty path', () async {
        final result = await opener.open('');
        expect(result, isA<OpenError>());
        final error = (result as OpenError).error;
        expect(error.message, contains('文件路径为空'));
      });

      test('returns error for whitespace-only path', () async {
        final result = await opener.open('   ');
        expect(result, isA<OpenError>());
      });

      test('returns error for non-existent local file', () async {
        final result = await opener.open('C:\\nonexistent\\file.mp4');
        expect(result, isA<OpenError>());
        final error = (result as OpenError).error;
        expect(error.message, contains('文件不存在'));
      });

      test(
        'does not touch the player when local validation becomes stale',
        () async {
          final fileExists = Completer<bool>();
          var canContinue = true;
          final guardedOpener = MediaOpener(
            player,
            trackManager,
            fileExists: (_) => fileExists.future,
          );

          final opening = guardedOpener.open(
            'C:\\media\\first.mp4',
            canContinue: () => canContinue,
          );
          await Future<void>.delayed(Duration.zero);

          // 模拟后续 open 在文件系统查询完成前取得最新 generation。
          canContinue = false;
          fileExists.complete(true);

          expect(await opening, isA<OpenSuperseded>());
          // FakeMdkPlayer 以空字符串表示尚未设置 media。
          expect(player.mediaPath, isEmpty);
          expect(player.prepareCallCount, 0);
          expect(player.updateTextureCallCount, 0);
        },
      );
    });

    group('open - prepare', () {
      test('sets media on player', () async {
        // 使用一个看起来像 URL 的路径来跳过文件存在检查
        await opener.open('https://example.com/video.mp4');
        expect(player.mediaPath, 'https://example.com/video.mp4');
      });

      test('calls prepare on player', () async {
        await opener.open('https://example.com/video.mp4');
        expect(player.prepareCallCount, 1);
      });

      test('returns error on prepare failure', () async {
        player.prepareResult = -1;
        final result = await opener.open('https://example.com/video.mp4');
        expect(result, isA<OpenError>());
      });

      test('waits for the native prepare future to settle', () async {
        final prepareCompleter = Completer<int>();
        player.nextPrepareCompleter = prepareCompleter;

        final opening = opener.open('https://example.com/video.mp4');
        await Future<void>.delayed(Duration.zero);
        expect(player.prepareCallCount, 1);

        prepareCompleter.complete(-1);
        final result = await opening;
        expect(result, isA<OpenError>());
      });
    });

    group('open - metadata parsing', () {
      test('parses video metadata (width/height/codec)', () async {
        final result = await opener.open('https://example.com/video.mp4');
        expect(result, isA<OpenSuccess>());
        final info = (result as OpenSuccess).mediaInfo;
        expect(info.video, isNotNull);
        expect(info.video!.width, 3840);
        expect(info.video!.height, 2160);
        expect(info.video!.codec, 'hevc');
      });

      test('parses duration', () async {
        final result = await opener.open('https://example.com/video.mp4');
        final info = (result as OpenSuccess).mediaInfo;
        expect(info.duration, 120000);
      });

      test('parses audio tracks', () async {
        final result = await opener.open('https://example.com/video.mp4');
        final info = (result as OpenSuccess).mediaInfo;
        expect(info.audioTracks, hasLength(2));
        expect(info.audioTracks[0].language, 'chi');
        expect(info.audioTracks[0].codec, 'ac3');
        expect(info.audioTracks[0].channels, 6);
        expect(info.audioTracks[1].language, 'eng');
      });

      test('parses subtitle tracks', () async {
        final result = await opener.open('https://example.com/video.mp4');
        final info = (result as OpenSuccess).mediaInfo;
        expect(info.subtitleTracks, hasLength(2));
        expect(info.subtitleTracks[0].language, 'chi');
        expect(info.subtitleTracks[0].title, '中文');
        expect(info.subtitleTracks[1].language, 'eng');
      });

      test('updates track manager media info', () async {
        await opener.open('https://example.com/video.mp4');
        final info = trackManager.mediaInfo;
        expect(info.duration, 120000);
        expect(info.audioTracks, hasLength(2));
        expect(info.subtitleTracks, hasLength(2));
      });

      test('handles null video gracefully', () async {
        player.mediaInfoToReturn = FakeMdkMediaInfo(duration: 5000);
        final result = await opener.open('https://example.com/audio.mp3');
        expect(result, isA<OpenSuccess>());
        final info = (result as OpenSuccess).mediaInfo;
        expect(info.video, isNull);
        expect(info.duration, 5000);
      });

      test('handles empty video list gracefully', () async {
        player.mediaInfoToReturn = FakeMdkMediaInfo(duration: 5000, video: []);
        final result = await opener.open('https://example.com/audio.mp3');
        expect(result, isA<OpenSuccess>());
      });
    });

    group('open - texture creation', () {
      test('calls updateTexture on player', () async {
        await opener.open('https://example.com/video.mp4');
        expect(player.updateTextureCallCount, 1);
      });

      test('returns error on texture creation failure', () async {
        player.updateTextureResult = -1;
        final result = await opener.open('https://example.com/video.mp4');
        expect(result, isA<OpenError>());
        final error = (result as OpenError).error;
        expect(error.message, contains('纹理创建失败'));
      });

      test(
        'returns error when textureId is null after updateTexture',
        () async {
          player.updateTextureResult = 1;
          player.textureIdValue = null;
          // textureIdNotifier 默认为 null
          final result = await opener.open('https://example.com/video.mp4');
          expect(result, isA<OpenError>());
          final error = (result as OpenError).error;
          expect(error.message, contains('纹理创建失败'));
        },
      );

      test('returns success with valid textureId', () async {
        player.textureIdValue = 42;
        final result = await opener.open('https://example.com/video.mp4');
        expect(result, isA<OpenSuccess>());
      });
    });

    group('open - network configuration', () {
      test('applies network config for HTTP URLs', () async {
        await opener.open('http://example.com/video.mp4');
        // NetworkConfigurator 设置了 timeout 属性
        expect(player.properties['timeout'], isNotNull);
      });

      test('applies RTSP low-latency config', () async {
        await opener.open('rtsp://example.com/stream');
        expect(player.properties['avformat.fflags'], '+nobuffer');
        expect(player.bufferMin, 0);
        expect(player.bufferMax, 0);
      });

      test('applies HTTP demux buffer config', () async {
        await opener.open('https://example.com/video.mp4');
        // HTTP URL 使用 NetworkConfigurator 启用 demux 缓存
        expect(player.properties['demux.buffer.ranges'], '1');
      });
    });

    group('open - complete success path', () {
      test('returns OpenSuccess with full mediaInfo', () async {
        player.textureIdValue = 7;
        final result = await opener.open('https://example.com/4k.mp4');

        expect(result, isA<OpenSuccess>());
        final success = result as OpenSuccess;
        expect(success.mediaInfo.duration, 120000);
        expect(success.mediaInfo.video!.width, 3840);
        expect(success.mediaInfo.video!.height, 2160);
        expect(success.mediaInfo.audioTracks, hasLength(2));
        expect(success.mediaInfo.subtitleTracks, hasLength(2));
      });
    });
  });
}
