/// 播放器主状态枚举 — 正交 6 值
///
/// Playback state enum — 6 orthogonal values.
///
/// State model: `idle → opening → playing ⇄ paused → completed → error`.
///
/// `seeking`/`buffering` are tracked by separate `ValueNotifier<bool>`
/// ([EngineStateView.isSeeking] / [EngineStateView.isBuffering])
/// to avoid combinatorial explosion of the main state enum.
enum MediaState {
  /// 初始状态，未加载任何媒体.
  ///
  /// Initial state; no media loaded.
  idle,

  /// 正在加载/打开媒体.
  ///
  /// Loading/opening media.
  opening,

  /// 正在播放.
  ///
  /// Actively playing.
  playing,

  /// 已暂停.
  ///
  /// Paused.
  paused,

  /// 播放完成（自然播放到末尾）.
  ///
  /// Playback completed (reached end of media naturally).
  completed,

  /// 发生错误.
  ///
  /// An error occurred.
  error,
}

