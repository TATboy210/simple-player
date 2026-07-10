import 'package:flutter/foundation.dart' show listEquals;

import 'package:simple_player_flutter/kernel/engine/models/audio_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/subtitle_track_info.dart';
import 'package:simple_player_flutter/kernel/engine/models/video_codec_info.dart';

/// 媒体文件信息（打开后可用）
class MediaInfo {
  final int duration; // 毫秒
  final VideoCodecInfo? video;
  final List<AudioTrackInfo> audioTracks;
  final List<SubtitleTrackInfo> subtitleTracks;

  const MediaInfo({
    this.duration = 0,
    this.video,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
  });

  bool get hasVideo => video != null && video!.width > 0;
  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasSubtitles => subtitleTracks.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaInfo &&
          duration == other.duration &&
          video == other.video &&
          listEquals(audioTracks, other.audioTracks) &&
          listEquals(subtitleTracks, other.subtitleTracks);

  @override
  int get hashCode => Object.hash(
    duration,
    video,
    Object.hashAll(audioTracks),
    Object.hashAll(subtitleTracks),
  );
}
