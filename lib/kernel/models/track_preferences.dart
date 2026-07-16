/// 轨道偏好 — 用户选择的音频/字幕轨道和字幕延迟
///
/// 持久化到 [SettingsStore]，在每次 open() 后由 [TrackPreferenceService] 自动恢复。
/// 索引-based（非语言匹配），跨文件可能不精确，但对大多数使用场景足够。
///
/// 设计决策：
/// - audioTrackIndex/subtitleTrackIndex 为 nullable — null 表示使用 demuxer 默认值
/// - subtitleTrackIndex 特殊值 -1 表示用户主动关闭字幕
/// - subtitleDelay 为非 null — 0 表示无延迟（最常见情况）
class TrackPreferences {
  const TrackPreferences({
    this.audioTrackIndex,
    this.subtitleTrackIndex,
    this.subtitleDelay = 0,
  });

  /// 空偏好 — 使用所有默认值
  static const empty = TrackPreferences();

  /// 用户选择的音频轨道索引。null = 使用 demuxer 默认
  final int? audioTrackIndex;

  /// 用户选择的字幕轨道索引。null = 使用 demuxer 默认，-1 = 字幕关闭
  final int? subtitleTrackIndex;

  /// 字幕延迟（毫秒）。正值延后，负值提前。0 = 无延迟
  final int subtitleDelay;

  /// 创建副本，可选覆盖字段
  ///
  /// 使用 sentinel 模式区分 "未提供" 和 "显式 null"，
  /// 允许调用方将 audioTrackIndex/subtitleTrackIndex 设为 null（恢复默认）。
  TrackPreferences copyWith({
    Object? audioTrackIndex = _sentinel,
    Object? subtitleTrackIndex = _sentinel,
    int? subtitleDelay,
  }) {
    return TrackPreferences(
      audioTrackIndex: audioTrackIndex == _sentinel
          ? this.audioTrackIndex
          : audioTrackIndex as int?,
      subtitleTrackIndex: subtitleTrackIndex == _sentinel
          ? this.subtitleTrackIndex
          : subtitleTrackIndex as int?,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackPreferences &&
          audioTrackIndex == other.audioTrackIndex &&
          subtitleTrackIndex == other.subtitleTrackIndex &&
          subtitleDelay == other.subtitleDelay;

  @override
  int get hashCode => Object.hash(audioTrackIndex, subtitleTrackIndex, subtitleDelay);

  @override
  String toString() =>
      'TrackPreferences(audio: $audioTrackIndex, subtitle: $subtitleTrackIndex, delay: ${subtitleDelay}ms)';
}
