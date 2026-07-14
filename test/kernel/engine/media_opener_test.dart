import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

void main() {
  group('OpenResult', () {
    test('OpenSuccess carries MediaInfo', () {
      const info = MediaInfo(
        duration: 60000,
        video: VideoCodecInfo(
          width: 1920,
          height: 1080,
          par: 1.0,
          codec: 'h264',
        ),
        audioTracks: [
          AudioTrackInfo(index: 0, language: 'eng', codec: 'aac', channels: 2),
        ],
        subtitleTracks: [
          SubtitleTrackInfo(index: 0, language: 'chi', title: '中文'),
        ],
      );
      final result = const OpenSuccess(info);

      expect(result, isA<OpenResult>());
      expect(result.mediaInfo.duration, 60000);
      expect(result.mediaInfo.video?.width, 1920);
      expect(result.mediaInfo.audioTracks.length, 1);
      expect(result.mediaInfo.subtitleTracks.length, 1);
    });

    test('OpenError carries PlayerError', () {
      const result = OpenError(FileError(FileErrorCode.fileNotFound, '文件不存在'));

      expect(result, isA<OpenResult>());
      expect(result.error, isA<FileError>());
      expect(result.error.message, '文件不存在');
    });

    test('sealed class pattern matching works', () {
      final success = const OpenSuccess(MediaInfo(duration: 1000));
      const error = OpenError(CodecError(CodecErrorCode.unsupportedFormat, '无法解码'));

      String describe(OpenResult r) => switch (r) {
        OpenSuccess(:final mediaInfo) => 'ok:${mediaInfo.duration}',
        OpenError(:final error) => 'err:${error.runtimeType}:${error.message}',
      };

      expect(describe(success), 'ok:1000');
      expect(describe(error), 'err:CodecError:无法解码');
    });

    test('OpenSuccess with minimal MediaInfo', () {
      final result = const OpenSuccess(MediaInfo());
      expect(result.mediaInfo.duration, 0);
      expect(result.mediaInfo.video, isNull);
      expect(result.mediaInfo.audioTracks, isEmpty);
      expect(result.mediaInfo.subtitleTracks, isEmpty);
    });

    test('OpenError with network error', () {
      const result = OpenError(NetworkError(NetworkErrorCode.timeout, '连接超时'));
      expect(result.error, isA<NetworkError>());
      expect(result.message, '连接超时');
    });

    test('OpenError with playback error', () {
      const result = OpenError(PlaybackError(PlaybackErrorCode.playFailed, '播放失败'));
      expect(result.error, isA<PlaybackError>());
      expect(result.message, '播放失败');
    });
  });
}
