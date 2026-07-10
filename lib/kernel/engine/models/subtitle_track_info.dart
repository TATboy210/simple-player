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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleTrackInfo &&
          index == other.index &&
          language == other.language &&
          title == other.title;

  @override
  int get hashCode => Object.hash(index, language, title);

  @override
  String toString() => 'SubtitleTrack($index, $language, $title)';
}
