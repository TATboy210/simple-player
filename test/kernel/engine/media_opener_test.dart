import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/open_result.dart';

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

    test('OpenError carries type and message', () {
      const result = OpenError(MediaErrorType.file, '文件不存在');

      expect(result, isA<OpenResult>());
      expect(result.type, MediaErrorType.file);
      expect(result.message, '文件不存在');
    });

    test('sealed class pattern matching works', () {
      final success = const OpenSuccess(MediaInfo(duration: 1000));
      const error = OpenError(MediaErrorType.codec, '无法解码');

      String describe(OpenResult r) => switch (r) {
        OpenSuccess(:final mediaInfo) => 'ok:${mediaInfo.duration}',
        OpenError(:final type, :final message) => 'err:$type:$message',
      };

      expect(describe(success), 'ok:1000');
      expect(describe(error), 'err:MediaErrorType.codec:无法解码');
    });

    test('OpenSuccess with minimal MediaInfo', () {
      final result = const OpenSuccess(MediaInfo());
      expect(result.mediaInfo.duration, 0);
      expect(result.mediaInfo.video, isNull);
      expect(result.mediaInfo.audioTracks, isEmpty);
      expect(result.mediaInfo.subtitleTracks, isEmpty);
    });

    test('OpenError with network type', () {
      const result = OpenError(MediaErrorType.network, '连接超时');
      expect(result.type, MediaErrorType.network);
    });

    test('OpenError with playback type', () {
      const result = OpenError(MediaErrorType.playback, '播放失败');
      expect(result.type, MediaErrorType.playback);
    });
  });
}
