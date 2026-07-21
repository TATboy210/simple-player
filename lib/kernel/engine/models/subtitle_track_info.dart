/// 字幕轨道信息。
///
/// Metadata for a single subtitle track within a media file.
///
/// - `index`: Engine-level track index (used by [MediaEngine] to select tracks).
/// - `language`: ISO 639 language code (e.g. "en", "zh"), empty if unknown.
/// - `title`: Human-readable track label (e.g. "Forced", "SDH"), empty if absent.
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
