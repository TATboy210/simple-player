/// 播放模式（从 Python Playlist 移植）
///
/// Canonical location for PlayMode enum.
/// Used by Playlist (core/playlist.dart) and SettingsStore (persistence/settings_store.dart).
enum PlayMode {
  /// 顺序播放（列表循环）.
  ///
  /// Sequential playback; loops the entire playlist.
  loopAll,

  /// 单曲循环.
  ///
  /// Loops the current track.
  loopSingle,

  /// 随机播放.
  ///
  /// Shuffles tracks randomly.
  shuffle,
}
