import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:simple_player_flutter/kernel/engine/media_kit_engine.dart';
import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/video_codec_info.dart';

/// MediaKitEngine 纯逻辑单测.
///
/// 不实例化 [MediaKitEngine] (依赖 native libmpv, headless 不可用).
/// 仅覆盖 [@visibleForTesting] 静态方法: 路径→URI 转换 + track 映射.
/// 引擎集成 (stream 桥接 / open generation 取消 / stub) 留阶段 2 手动验证.
void main() {
  group('MediaKitEngine.mediaUriFromPath', () {
    test('Windows 反斜杠路径转 file URI', () {
      expect(
        MediaKitEngine.mediaUriFromPath(r'D:\video.mp4'),
        'file:///D:/video.mp4',
      );
    });

    test('正斜杠路径转 file URI', () {
      expect(
        MediaKitEngine.mediaUriFromPath('C:/Users/a/b.mp4'),
        'file:///C:/Users/a/b.mp4',
      );
    });

    test('嵌套反斜杠全部转正斜杠', () {
      expect(
        MediaKitEngine.mediaUriFromPath(r'D:\media\subs\video.mkv'),
        'file:///D:/media/subs/video.mkv',
      );
    });

    test('https URL 原样返回', () {
      const url = 'https://example.com/v.mp4';
      expect(MediaKitEngine.mediaUriFromPath(url), url);
    });

    test('rtsp URL 原样返回', () {
      const url = 'rtsp://example.com/live';
      expect(MediaKitEngine.mediaUriFromPath(url), url);
    });

    test('已有 file:// 前缀原样返回 (不重复加)', () {
      const url = 'file:///D:/video.mp4';
      expect(MediaKitEngine.mediaUriFromPath(url), url);
    });
  });

  group(
    'MediaKitEngine.mediaUriFromPath — percent-encoding roundtrip (K1)',
    () {
      // media_kit Media() 构造内部走 Uri.parse/normalizeURI 二次解析: 手工拼接
      // 的裸 `#` 被切 fragment、合法 `%XX` 逃逸被解码 — 文件名含这些字符的
      // 媒体必然打不开 (v0.0.12 K1).
      // 契约: 产出必须经 Uri.parse().toFilePath(windows: true) 往返恒等回原路径.
      // 注: `windows: true` 显式锁定 Windows 语义 — 引擎映射与宿主 OS 无关,
      // CI 三平台跑同一套用例; `?` 是 Windows 文件名非法字符, 不设用例.

      /// 往返恒等断言: 产出经 Uri 解析还原后须逐字符等于原路径.
      void expectRoundtrip(String path) {
        final uri = MediaKitEngine.mediaUriFromPath(path);
        expect(
          Uri.parse(uri).toFilePath(windows: true),
          path,
          reason: 'uri=$uri 未往返恒等回原路径',
        );
      }

      test('井号路径往返恒等 (# 被 Uri.parse 切 fragment — 现行为红)', () {
        expectRoundtrip(r'D:\music\c#minor\a.mp4');
      });

      test('文件名含合法 %XX 逃逸往返恒等 (%20 被误解码 — 现行为红)', () {
        expectRoundtrip(r'D:\downloads\report%20final.mp4');
      });

      test('文件名含孤立百分号往返恒等 (100%.mkv)', () {
        expectRoundtrip(r'D:\影 库\100%.mkv');
      });

      test('空格路径往返恒等', () {
        expectRoundtrip(r'D:\my videos\a b.mp4');
      });

      test('中文路径往返恒等', () {
        expectRoundtrip(r'D:\影库\电影.mp4');
      });

      test('混合特殊字符路径往返恒等 (# + %XX + 空格)', () {
        expectRoundtrip(r'D:\mix\c#1\100%25 a.mp4');
      });

      test('编码格式锁定 — # 必须编码为 %23 (裸 # 禁入交给 mpv 的 URI)', () {
        expect(
          MediaKitEngine.mediaUriFromPath(r'D:\music\c#minor\a.mp4'),
          'file:///D:/music/c%23minor/a.mp4',
        );
      });
    },
  );

  group('MediaKitEngine.audioTracksFromMediaKit', () {
    test('null 返回空列表', () {
      expect(MediaKitEngine.audioTracksFromMediaKit(null), isEmpty);
    });

    test('过滤 auto/no 占位轨, 真实轨按索引映射', () {
      final tracks = Tracks(
        audio: [
          AudioTrack.auto(),
          AudioTrack.no(),
          const AudioTrack(
            '1',
            'English',
            'en',
            codec: 'aac',
            channelscount: 2,
          ),
          const AudioTrack(
            '2',
            'Chinese',
            'zh',
            codec: 'opus',
            channelscount: 6,
          ),
        ],
      );
      final result = MediaKitEngine.audioTracksFromMediaKit(tracks);
      expect(result, [
        const AudioTrackInfo(
          index: 0,
          language: 'en',
          codec: 'aac',
          channels: 2,
        ),
        const AudioTrackInfo(
          index: 1,
          language: 'zh',
          codec: 'opus',
          channels: 6,
        ),
      ]);
    });

    test('无真实轨 (仅 auto/no) 返回空', () {
      final tracks = Tracks(audio: [AudioTrack.auto(), AudioTrack.no()]);
      expect(MediaKitEngine.audioTracksFromMediaKit(tracks), isEmpty);
    });

    test('language/codec/channels null 时填默认空值', () {
      final tracks = const Tracks(audio: [AudioTrack('1', null, null)]);
      final result = MediaKitEngine.audioTracksFromMediaKit(tracks);
      expect(result, [
        const AudioTrackInfo(index: 0, language: '', codec: '', channels: 0),
      ]);
    });
  });

  group('MediaKitEngine.subtitleTracksFromMediaKit', () {
    test('null 返回空列表', () {
      expect(MediaKitEngine.subtitleTracksFromMediaKit(null), isEmpty);
    });

    test('过滤 auto/no, 映射 title/language', () {
      final tracks = Tracks(
        subtitle: [
          SubtitleTrack.auto(),
          SubtitleTrack.no(),
          const SubtitleTrack('1', 'Forced', 'en'),
          const SubtitleTrack('2', 'SDH', 'zh'),
        ],
      );
      final result = MediaKitEngine.subtitleTracksFromMediaKit(tracks);
      expect(result, [
        const SubtitleTrackInfo(index: 0, language: 'en', title: 'Forced'),
        const SubtitleTrackInfo(index: 1, language: 'zh', title: 'SDH'),
      ]);
    });

    test('无真实字幕轨返回空', () {
      final tracks = Tracks(
        subtitle: [SubtitleTrack.auto(), SubtitleTrack.no()],
      );
      expect(MediaKitEngine.subtitleTracksFromMediaKit(tracks), isEmpty);
    });
  });

  group('MediaKitEngine.videoInfoFromMediaKit', () {
    test('有有效宽高时返回 VideoCodecInfo', () {
      expect(
        MediaKitEngine.videoInfoFromMediaKit(
          width: 1920,
          height: 1080,
          codec: 'h264',
          par: 1.0,
        ),
        const VideoCodecInfo(
          width: 1920,
          height: 1080,
          codec: 'h264',
          par: 1.0,
        ),
      );
    });

    test('宽高缺失或非正时返回 null', () {
      expect(
        MediaKitEngine.videoInfoFromMediaKit(width: 0, height: 1080),
        isNull,
      );
      expect(
        MediaKitEngine.videoInfoFromMediaKit(width: 1920, height: 0),
        isNull,
      );
      expect(
        MediaKitEngine.videoInfoFromMediaKit(width: null, height: 1080),
        isNull,
      );
    });
  });
}
