import 'package:player_engine/player_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoCodecInfo', () {
    group('aspectRatio', () {
      // 正常 16:9 视频
      test('16:9 with PAR 1.0', () {
        final info = const VideoCodecInfo(width: 1920, height: 1080, par: 1.0);
        expect(info.aspectRatio, closeTo(16 / 9, 0.01));
      });

      // PAL 视频：720x576, PAR=16:15 → 显示 4:3
      // 这是 DVD/电视广播的典型场景，不做 PAR 修正会变形
      test('PAL with PAR correction', () {
        final info = const VideoCodecInfo(
          width: 720,
          height: 576,
          par: 16 / 15,
        );
        expect(info.aspectRatio, closeTo(4 / 3, 0.01));
      });

      // 边界：宽为 0（无视频流）
      test('width 0 returns default 16/9', () {
        final info = const VideoCodecInfo(width: 0, height: 1080);
        expect(info.aspectRatio, 16 / 9);
      });

      // 边界：高为 0（损坏的视频头）
      test('height 0 returns default 16/9', () {
        final info = const VideoCodecInfo(width: 1920, height: 0);
        expect(info.aspectRatio, 16 / 9);
      });

      // 边界：宽高都为 0
      test('both 0 returns default 16/9', () {
        final info = const VideoCodecInfo();
        expect(info.aspectRatio, 16 / 9);
      });
    });
  });

  group('AudioTrackInfo', () {
    test('toString includes index, language, codec, channels', () {
      const track = AudioTrackInfo(
        index: 0,
        language: 'eng',
        codec: 'aac',
        channels: 2,
      );
      expect(track.toString(), 'AudioTrack(0, eng, aac, 2ch)');
    });

    test('toString with defaults', () {
      const track = AudioTrackInfo(index: 1);
      expect(track.toString(), 'AudioTrack(1, , , 0ch)');
    });
  });

  group('SubtitleTrackInfo', () {
    test('toString includes index, language, title', () {
      const track = SubtitleTrackInfo(
        index: 0,
        language: 'chi',
        title: '简体中文',
      );
      expect(track.toString(), 'SubtitleTrack(0, chi, 简体中文)');
    });

    test('toString with defaults', () {
      const track = SubtitleTrackInfo(index: 2);
      expect(track.toString(), 'SubtitleTrack(2, , )');
    });
  });

  group('MediaInfo', () {
    // hasVideo：video 非 null 且宽高 > 0
    group('hasVideo', () {
      test('true when video exists with valid dimensions', () {
        final info = const MediaInfo(
          video: VideoCodecInfo(width: 1920, height: 1080),
        );
        expect(info.hasVideo, true);
      });

      // video 为 null（纯音频文件）
      test('false when video is null', () {
        const info = MediaInfo();
        expect(info.hasVideo, false);
      });

      // video 存在但宽高为 0（音频文件被误识别为视频）
      test('false when video has zero dimensions', () {
        final info = const MediaInfo(video: VideoCodecInfo());
        expect(info.hasVideo, false);
      });
    });

    // hasAudio：音轨列表非空
    group('hasAudio', () {
      test('true when audio tracks exist', () {
        const info = MediaInfo(
          audioTracks: [AudioTrackInfo(index: 0, language: 'eng')],
        );
        expect(info.hasAudio, true);
      });

      // 无音轨（纯视频流或损坏文件）
      test('false when no audio tracks', () {
        const info = MediaInfo();
        expect(info.hasAudio, false);
      });
    });

    // hasSubtitles：字幕轨道非空
    group('hasSubtitles', () {
      test('true when subtitle tracks exist', () {
        const info = MediaInfo(
          subtitleTracks: [SubtitleTrackInfo(index: 0, language: 'chi')],
        );
        expect(info.hasSubtitles, true);
      });

      test('false when no subtitle tracks', () {
        const info = MediaInfo();
        expect(info.hasSubtitles, false);
      });
    });
  });
}
