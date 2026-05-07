/// 音频轨道信息
class AudioTrackInfo {
  final int index;
  final String language;
  final String codec;
  final int channels;

  const AudioTrackInfo({
    required this.index,
    this.language = '',
    this.codec = '',
    this.channels = 0,
  });

  @override
  String toString() => 'AudioTrack($index, $language, $codec, ${channels}ch)';
}

/// 字幕轨道信息
class SubtitleTrackInfo {
  final int index;
  final String language;
  final String title;

  const SubtitleTrackInfo({
    required this.index,
    this.language = '',
    this.title = '',
  });

  @override
  String toString() => 'SubtitleTrack($index, $language, $title)';
}

/// 视频编解码信息
class VideoCodecInfo {
  final int width;
  final int height;
  final double par; // pixel aspect ratio
  final String codec;

  const VideoCodecInfo({
    this.width = 0,
    this.height = 0,
    this.par = 1.0,
    this.codec = '',
  });

  /// 含 PAR 修正的宽高比
  double get aspectRatio =>
      (width > 0 && height > 0) ? (width * par) / height : 16 / 9;
}

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
}
