/// 播放器状态枚举
///
/// 状态机: idle -> loading -> playing ⇄ paused -> stopped -> completed -> error
/// seeking 和 buffering 是 transient 状态，与 playing/paused 并行。
enum MediaState {
  /// 初始状态，未加载任何媒体
  idle,

  /// 正在加载媒体
  loading,

  /// 正在播放
  playing,

  /// 已暂停
  paused,

  /// 已停止（手动停止或播放结束后重置）
  stopped,

  /// 播放完成（自然播放到末尾）
  completed,

  /// 发生错误
  error,

  /// 正在 seek（transient 状态）
  seeking,

  /// 正在缓冲（transient 状态，网络流或 seek 后）
  buffering,
}
