/// 播放模式（从 Python Playlist 移植）
///
/// Canonical location for PlayMode enum.
/// Used by Playlist (core/playlist.dart) and SettingsStore (persistence/settings_store.dart).
enum PlayMode {
  normal, // 顺序播放，播完停止
  loopAll, // 列表循环
  loopSingle, // 单曲循环
  shuffle, // 随机播放
}
