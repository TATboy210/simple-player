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

/// 状态转换守卫 — 定义合法的 MediaState 转换
///
/// 防御非法跳转（如 idle → completed），debug 模式下打印警告。
/// 转换矩阵基于播放器实际行为：
///   - idle: 初始状态，只能进入 loading 或 error
///   - loading: 加载中，可进入 playing/paused/error
///   - playing: 播放中，可暂停/停止/完成/seek/缓冲/出错
///   - paused: 已暂停，可恢复播放/停止/seek
///   - stopped: 已停止，只能重新加载或回到 idle
///   - completed: 播放完成，可重新加载/回到 idle/重播
///   - error: 出错，只能回到 idle 或重新加载
///   - seeking/buffering: transient 状态，恢复到 playing/paused 或出错
extension MediaStateTransition on MediaState {
  /// 当前状态是否可以转换到 [next] 状态
  bool canTransitionTo(MediaState next) => switch (this) {
    MediaState.idle => const {
      MediaState.loading,
      MediaState.error,
    }.contains(next),
    MediaState.loading => const {
      MediaState.playing,
      MediaState.paused,
      MediaState.idle,
      MediaState.error,
    }.contains(next),
    MediaState.playing => const {
      MediaState.paused,
      MediaState.stopped,
      MediaState.completed,
      MediaState.error,
      MediaState.seeking,
      MediaState.buffering,
    }.contains(next),
    MediaState.paused => const {
      MediaState.playing,
      MediaState.stopped,
      MediaState.seeking,
    }.contains(next),
    MediaState.stopped => const {
      MediaState.loading,
      MediaState.idle,
    }.contains(next),
    MediaState.completed => const {
      MediaState.loading,
      MediaState.idle,
      MediaState.playing,
    }.contains(next),
    MediaState.error => const {
      MediaState.idle,
      MediaState.loading,
    }.contains(next),
    MediaState.seeking => const {
      MediaState.playing,
      MediaState.paused,
      MediaState.error,
    }.contains(next),
    MediaState.buffering => const {
      MediaState.playing,
      MediaState.paused,
      MediaState.error,
    }.contains(next),
  };
}
