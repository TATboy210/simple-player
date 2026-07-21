/// 音频轨道信息。
///
/// Metadata for a single audio track within a media file.
///
/// - `index`: Engine-level track index (used by [MediaEngine] to select tracks).
/// - `language`: ISO 639 language code (e.g. "en", "zh"), empty if unknown.
/// - `codec`: Audio codec identifier (e.g. "aac", "opus").
/// - `channels`: Channel count (0 if unknown).
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackInfo &&
          index == other.index &&
          language == other.language &&
          codec == other.codec &&
          channels == other.channels;

  @override
  int get hashCode => Object.hash(index, language, codec, channels);

  @override
  String toString() => 'AudioTrack($index, $language, $codec, ${channels}ch)';
}
