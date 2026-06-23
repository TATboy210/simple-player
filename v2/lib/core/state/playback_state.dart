/// 播放状态机 — 整个项目唯一的状态枚举
///
/// 禁止: isPlaying / isLoading / isSeeking / isPaused 等布尔状态满天飞。
/// 所有模块通过 PlaybackState 判断当前状态。
enum PlaybackState {
  /// 无媒体加载
  idle,

  /// 正在打开媒体
  opening,

  /// 缓冲中
  buffering,

  /// 播放中
  playing,

  /// 暂停
  paused,

  /// 跳转中
  seeking,

  /// 播放结束
  ended,

  /// 错误
  error,
}
