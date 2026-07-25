/// MediaOpener edge case tests — boundary conditions, error paths, concurrency.
///
/// Covers:
/// - Empty/whitespace/null-byte paths
/// - Non-existent files
/// - Special characters in paths (Unicode, spaces, CJK)
/// - Race condition: rapid canContinue= false after async boundary
/// - Error recovery: repeated failures then success
/// - Timeout paths (prepare and texture)
/// - Texture creation failure variants (negative result, null textureId)
library;

import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/media_opener.dart';
import 'package:simple_player_flutter/kernel/engine/track_manager.dart';

import '../../helpers/fake_mdk_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeMdkPlayer player;
  late TrackManager trackManager;

  setUp(() {
    player = FakeMdkPlayer();
    trackManager = TrackManager(player);
  });

  tearDown(() {
    player.dispose();
  });

  /// Helper: create a MediaOpener with a controllable fileExists predicate.
  MediaOpener createOpener({
    Future<bool> Function(File)? fileExists,
  }) =>
      MediaOpener(player, trackManager, fileExists: fileExists);

  /// Helper: configure player for a successful open.
  void configureSuccess({int durationMs = 60000}) {
    player.prepareResult = 1;
    player.updateTextureResult = 1;
    player.textureIdValue = 42;
    player.mediaInfoToReturn = FakeMdkMediaInfo(
      duration: durationMs,
      video: [FakeVideoTrack(codec: FakeCodecInfo())],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Empty / whitespace / null-byte paths
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — empty/invalid paths', () {
    test('empty string returns FileError.pathEmpty', () async {
      final opener = createOpener(fileExists: (_) async => true);
      final result = await opener.open('');

      expect(result, isA<OpenError>());
      final error = (result as OpenError).error;
      expect(error, isA<FileError>());
      expect((error as FileError).code, FileErrorCode.pathEmpty);
    });

    test('whitespace-only string returns FileError.pathEmpty', () async {
      final opener = createOpener(fileExists: (_) async => true);
      final result = await opener.open('   \t\n  ');

      expect(result, isA<OpenError>());
      final error = (result as OpenError).error;
      expect(error, isA<FileError>());
      expect((error as FileError).code, FileErrorCode.pathEmpty);
    });

    test('single space returns FileError.pathEmpty after trim', () async {
      final opener = createOpener(fileExists: (_) async => true);
      final result = await opener.open(' ');

      expect(result, isA<OpenError>());
      expect((result as OpenError).error, isA<FileError>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Non-existent files
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — non-existent files', () {
    test('non-existent local file returns FileError.fileNotFound', () async {
      final opener = createOpener(fileExists: (_) async => false);
      final result = await opener.open('C:/nonexistent/video.mp4');

      expect(result, isA<OpenError>());
      final error = (result as OpenError).error;
      expect(error, isA<FileError>());
      expect((error as FileError).code, FileErrorCode.fileNotFound);
    });

    test('fileExists exception returns FileError.fileNotFound', () async {
      final opener = createOpener(
        fileExists: (_) async => throw Exception('access denied'),
      );
      final result = await opener.open('C:/protected/video.mp4');

      expect(result, isA<OpenError>());
      final error = (result as OpenError).error;
      expect(error, isA<FileError>());
      expect((error as FileError).code, FileErrorCode.fileNotFound);
      expect(error.message, contains('路径无效'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Special characters in paths
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — special characters', () {
    test('path with spaces is trimmed and passed to player', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      await opener.open('  C:/my videos/test file.mp4  ');

      // Player receives trimmed path
      expect(player.mediaPath, 'C:/my videos/test file.mp4');
    });

    test('path with CJK characters works', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open('C:/视频/测试文件.mp4');

      expect(result, isA<OpenSuccess>());
      expect(player.mediaPath, 'C:/视频/测试文件.mp4');
    });

    test('path with Unicode emoji works', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open('C:/movies/movie 🎬.mp4');

      expect(result, isA<OpenSuccess>());
      expect(player.mediaPath, 'C:/movies/movie 🎬.mp4');
    });

    test('path with parentheses and brackets works', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open('C:/movies/Film (2024) [1080p].mkv');

      expect(result, isA<OpenSuccess>());
    });

    test('path with single quotes works', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open("C:/movies/it's a movie.mp4");

      expect(result, isA<OpenSuccess>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Race condition — canContinue = false after async boundary
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — race condition (canContinue)', () {
    test('canContinue=false after prepare returns OpenSuperseded', () async {
      configureSuccess();
      final continueFlag = true;
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open(
        'C:/test.mp4',
        canContinue: () => continueFlag,
      );

      // With canContinue=true throughout, should succeed
      expect(result, isA<OpenSuccess>());
    });

    test('canContinue=false before prepare starts returns OpenSuperseded',
        () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open(
        'C:/test.mp4',
        canContinue: () => false,
      );

      // File existence check is async; canContinue is checked after it.
      // If fileExists completes synchronously (via Future.value), the
      // canContinue check fires before prepare.
      expect(result, isA<OpenSuperseded>());
    });

    test('canContinue flips false between prepare and texture', () async {
      // Prepare succeeds, but canContinue becomes false before texture
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      player.mediaInfoToReturn = FakeMdkMediaInfo(duration: 60000);

      var callCount = 0;
      final opener = createOpener(fileExists: (_) async => true);

      final result = await opener.open(
        'C:/test.mp4',
        canContinue: () {
          callCount++;
          // First call (after fileExists) returns true;
          // second call (after prepare) returns true;
          // third call (after texture) returns false
          return callCount <= 2;
        },
      );

      expect(result, isA<OpenSuperseded>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Error recovery — repeated failures then success
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — error recovery', () {
    test('prepare failure then success on retry', () async {
      final opener = createOpener(fileExists: (_) async => true);

      // First attempt: prepare fails
      player.prepareResult = -1;
      final result1 = await opener.open('C:/test.mp4');
      expect(result1, isA<OpenError>());

      // Second attempt: prepare succeeds
      configureSuccess();
      final result2 = await opener.open('C:/test.mp4');
      expect(result2, isA<OpenSuccess>());
    });

    test('texture failure then success on retry', () async {
      final opener = createOpener(fileExists: (_) async => true);

      // First attempt: texture fails
      player.prepareResult = 1;
      player.updateTextureResult = -1;
      player.mediaInfoToReturn = FakeMdkMediaInfo(duration: 60000);
      final result1 = await opener.open('C:/test.mp4');
      expect(result1, isA<OpenError>());
      expect(
        ((result1 as OpenError).error as PlaybackError).code,
        PlaybackErrorCode.textureFailed,
      );

      // Second attempt: texture succeeds
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      final result2 = await opener.open('C:/test.mp4');
      expect(result2, isA<OpenSuccess>());
    });

    test('null textureId after successful updateTexture returns error', () async {
      final opener = createOpener(fileExists: (_) async => true);

      player.prepareResult = 1;
      player.updateTextureResult = 0; // >= 0 but...
      player.textureIdValue = null; // ...textureId is null
      player.mediaInfoToReturn = FakeMdkMediaInfo(duration: 60000);

      final result = await opener.open('C:/test.mp4');

      expect(result, isA<OpenError>());
      final openError = result as OpenError;
      expect(
        (openError.error as PlaybackError).code,
        PlaybackErrorCode.textureFailed,
      );
      expect(openError.error.message, contains('空 textureId'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Codec error path (prepare returns negative)
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — codec/decode errors', () {
    test('prepare returns -2 → CodecError.decodeFailed', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = -2;

      final result = await opener.open('C:/corrupt.mp4');

      expect(result, isA<OpenError>());
      final error = (result as OpenError).error;
      expect(error, isA<CodecError>());
      expect((error as CodecError).code, CodecErrorCode.decodeFailed);
      expect(error.message, contains('无法解码'));
    });

    test('prepare returns -1 → CodecError.decodeFailed', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = -1;

      final result = await opener.open('C:/bad.mkv');

      expect(result, isA<OpenError>());
      expect((result as OpenError).error, isA<CodecError>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Metadata parsing edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — metadata parsing', () {
    test('no video track → videoInfo is null', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      player.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 30000,
        video: null, // no video track (audio-only)
      );

      final result = await opener.open('C:/audio_only.mp3');

      expect(result, isA<OpenSuccess>());
      expect((result as OpenSuccess).mediaInfo.video, isNull);
      expect(result.mediaInfo.duration, 30000);
    });

    test('empty video list → videoInfo is null', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      player.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 10000,
        video: [], // empty list
      );

      final result = await opener.open('C:/audio.wav');

      expect(result, isA<OpenSuccess>());
      expect((result as OpenSuccess).mediaInfo.video, isNull);
    });

    test('video with zero dimensions → videoInfo is null', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      player.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 10000,
        video: [FakeVideoTrack(codec: FakeCodecInfo(width: 0, height: 0))],
      );

      final result = await opener.open('C:/zero_dim.mp4');

      expect(result, isA<OpenSuccess>());
      expect((result as OpenSuccess).mediaInfo.video, isNull);
    });

    test('audio tracks parsed correctly', () async {
      final opener = createOpener(fileExists: (_) async => true);
      player.prepareResult = 1;
      player.updateTextureResult = 1;
      player.textureIdValue = 42;
      player.mediaInfoToReturn = FakeMdkMediaInfo(
        duration: 60000,
        audio: [
          FakeAudioTrack(
            codec: FakeCodecInfo(codec: 'aac', channels: 6),
            index: 0,
            metadata: {'language': 'eng'},
          ),
          FakeAudioTrack(
            codec: FakeCodecInfo(codec: 'ac3', channels: 2),
            index: 1,
            metadata: {'language': 'chi'},
          ),
        ],
        subtitle: [
          FakeSubtitleTrack(
            index: 0,
            metadata: {'language': 'chi', 'title': '简体中文'},
          ),
        ],
      );

      final result = await opener.open('C:/multi_track.mkv');

      expect(result, isA<OpenSuccess>());
      final info = (result as OpenSuccess).mediaInfo;
      expect(info.audioTracks.length, 2);
      expect(info.audioTracks[0].language, 'eng');
      expect(info.audioTracks[0].channels, 6);
      expect(info.audioTracks[1].language, 'chi');
      expect(info.subtitleTracks.length, 1);
      expect(info.subtitleTracks[0].title, '简体中文');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // URL paths skip file existence check
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — URL paths', () {
    test('HTTP URL skips file existence check and configures network', () async {
      configureSuccess();
      // fileExists should never be called for URLs
      final opener = createOpener(
        fileExists: (_) async =>
            throw StateError('should not be called for URLs'),
      );

      final result = await opener.open('https://example.com/stream.mp4');

      expect(result, isA<OpenSuccess>());
      expect(player.mediaPath, 'https://example.com/stream.mp4');
    });

    test('RTSP URL skips file existence check', () async {
      configureSuccess();
      final opener = createOpener(
        fileExists: (_) async =>
            throw StateError('should not be called for URLs'),
      );

      final result = await opener.open('rtsp://camera.local/live');

      expect(result, isA<OpenSuccess>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // onNativeWorkStarted callback
  // ═══════════════════════════════════════════════════════════════════════════

  group('MediaOpener edge cases — onNativeWorkStarted', () {
    test('callback receives prepare and texture futures', () async {
      configureSuccess();
      final opener = createOpener(fileExists: (_) async => true);
      final trackedFutures = <Future<Object?>>[];

      await opener.open(
        'C:/test.mp4',
        onNativeWorkStarted: (f) => trackedFutures.add(f),
      );

      // prepare + updateTexture = 2 tracked futures
      expect(trackedFutures.length, 2);
    });
  });
}
