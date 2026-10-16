/// mpv 轨道表 → 项目轨道模型 — 纯函数, 单测不依赖 native libmpv.
///
/// mpv_kit [MpvTrack] list (mpv `track-list`) → project track models. The
/// project indexes tracks 0..n per type (UI/preference contract); mpv
/// addresses them by its own per-type id, so callers map back with
/// [audioTrackIds] / [subtitleTrackIds].
library;

import 'package:mpv_kit_video/mpv_kit_video.dart';

import 'models/audio_track_info.dart';
import 'models/subtitle_track_info.dart';
import 'models/video_codec_info.dart';

/// 某类型的真实轨道 (保持 mpv 原序) — 项目侧 index 即在此列表中的位置.
List<MpvTrack> tracksOfType(List<MpvTrack> tracks, MpvTrackType type) =>
    tracks.where((t) => t.type == type).toList(growable: false);

/// 音轨 → [AudioTrackInfo] (index 0..n, 与 mpv 原序一致).
List<AudioTrackInfo> audioTracksFromMpv(List<MpvTrack> tracks) {
  final audio = tracksOfType(tracks, MpvTrackType.audio);
  return [
    for (var i = 0; i < audio.length; i++)
      AudioTrackInfo(
        index: i,
        language: audio[i].lang ?? '',
        codec: audio[i].codec ?? '',
        channels: audio[i].channels ?? 0,
      ),
  ];
}

/// 字幕轨 → [SubtitleTrackInfo] (index 0..n, 与 mpv 原序一致).
List<SubtitleTrackInfo> subtitleTracksFromMpv(List<MpvTrack> tracks) {
  final subs = tracksOfType(tracks, MpvTrackType.sub);
  return [
    for (var i = 0; i < subs.length; i++)
      SubtitleTrackInfo(
        index: i,
        language: subs[i].lang ?? '',
        title: subs[i].title ?? '',
      ),
  ];
}

/// 当前选中轨道的项目侧 index — mpv `aid`/`sid` 为 null (关闭) 或不在表中
/// 时返回空列表 (契约: activeAudioTracks/activeSubtitleTracks).
List<int> activeIndexOf(
  List<MpvTrack> tracks,
  MpvTrackType type,
  int? selectedId,
) {
  if (selectedId == null) return const [];
  final idx = tracksOfType(tracks, type).indexWhere((t) => t.id == selectedId);
  return idx >= 0 ? <int>[idx] : const <int>[];
}

/// 项目侧 index → mpv 轨道 id; 越界返回 null (调用方 no-op).
int? mpvTrackIdAt(List<MpvTrack> tracks, MpvTrackType type, int index) {
  final list = tracksOfType(tracks, type);
  if (index < 0 || index >= list.length) return null;
  return list[index].id;
}

/// 视频参数 → [VideoCodecInfo]; 无视频 (纯音频/封面图) 或尺寸非正返回 null,
/// 避免把纯音频文件误识别成有效视频流.
VideoCodecInfo? videoInfoFromMpv(MpvVideoParams? params, {String codec = ''}) {
  if (params == null) return null;
  final w = params.width;
  final h = params.height;
  if (w == null || h == null || w <= 0 || h <= 0) return null;
  return VideoCodecInfo(width: w, height: h, par: 1.0, codec: codec);
}
