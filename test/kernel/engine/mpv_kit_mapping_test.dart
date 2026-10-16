// mpv_kit 轨道/错误映射纯函数 — 不依赖 native libmpv.
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_kit_video/mpv_kit_video.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_kit_errors.dart';
import 'package:simple_player_flutter/kernel/engine/mpv_kit_tracks.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';

MpvTrack _track(
  int id,
  MpvTrackType type, {
  String? lang,
  String? codec,
  String? title,
  int? channels,
}) => MpvTrack(
  id: id,
  type: type,
  lang: lang,
  codec: codec,
  title: title,
  channels: channels,
  selected: false,
  isDefault: false,
  external: false,
  isAlbumArt: false,
  raw: const {},
);

MpvPlaybackError _err(MpvError e) =>
    MpvPlaybackError(error: e, message: 'boom', playlistEntryId: 1);

void main() {
  final tracks = [
    _track(1, MpvTrackType.video, codec: 'h264'),
    _track(1, MpvTrackType.audio, lang: 'jpn', codec: 'aac', channels: 2),
    _track(2, MpvTrackType.audio, lang: 'eng', codec: 'ac3', channels: 6),
    _track(1, MpvTrackType.sub, lang: 'chi', title: '简体'),
  ];

  group('轨道映射', () {
    test('音轨按 mpv 原序映射为 0..n, 字段缺省填空值', () {
      final audio = audioTracksFromMpv(tracks);
      expect(audio.map((t) => t.index), [0, 1]);
      expect(audio[1].language, 'eng');
      expect(audio[1].channels, 6);
      expect(
        audioTracksFromMpv([_track(1, MpvTrackType.audio)]).single.codec,
        '',
      );
    });

    test('字幕轨映射 title/language, 空表返回空', () {
      final subs = subtitleTracksFromMpv(tracks);
      expect(subs.single.title, '简体');
      expect(subtitleTracksFromMpv(const []), isEmpty);
    });

    test('项目 index ↔ mpv id 互逆, 越界为 null', () {
      expect(mpvTrackIdAt(tracks, MpvTrackType.audio, 1), 2);
      expect(mpvTrackIdAt(tracks, MpvTrackType.audio, 2), isNull);
      expect(activeIndexOf(tracks, MpvTrackType.audio, 2), [1]);
      expect(activeIndexOf(tracks, MpvTrackType.sub, null), isEmpty);
    });

    test('videoInfoFromMpv: 无参数或非正尺寸返回 null', () {
      expect(videoInfoFromMpv(null), isNull);
      expect(
        videoInfoFromMpv(const MpvVideoParams(width: 0, height: 0)),
        isNull,
      );
      final info = videoInfoFromMpv(
        const MpvVideoParams(width: 1920, height: 1080),
        codec: 'hevc',
      );
      expect((info?.width, info?.height, info?.codec), (1920, 1080, 'hevc'));
    });
  });

  group('错误映射', () {
    test('格式不识别 → CodecError.unsupportedFormat', () {
      final e = playerErrorFromMpv(_err(MpvError.unknownFormat), path: 'a.xyz');
      expect(e, isA<CodecError>());
      expect((e as CodecError).code, CodecErrorCode.unsupportedFormat);
      expect(e.context?.path, 'a.xyz');
    });

    test('输出初始化失败 → PlaybackError.playFailed', () {
      expect(
        playerErrorFromMpv(_err(MpvError.aoInitFailed)),
        isA<PlaybackError>(),
      );
    });

    test('loadingFailed: 本地文件不存在 → FileError, 存在/URL → UnknownError', () {
      final missing = playerErrorFromMpv(
        _err(MpvError.loadingFailed),
        path: r'C:\gone.mkv',
        fileExists: (_) => false,
      );
      expect(missing, isA<FileError>());
      final present = playerErrorFromMpv(
        _err(MpvError.loadingFailed),
        path: r'C:\here.mkv',
        fileExists: (_) => true,
      );
      expect(present, isA<UnknownError>());
      final url = playerErrorFromMpv(
        _err(MpvError.loadingFailed),
        path: 'https://x/y.mp4',
        fileExists: (_) => false,
      );
      expect(url, isA<UnknownError>());
    });
  });
}
