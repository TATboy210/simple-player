/// 播放器主状态枚举 — 正交 6 值
///
/// 状态模型：idle → opening → playing ⇄ paused → completed → error
///
/// 旧版本的 seeking/buffering 已移至独立的 `ValueNotifier<bool>`
/// （EngineStateView.isSeeking / EngineStateView.isBuffering），
/// 避免主状态枚举的组合爆炸。
///
/// 旧版本的 loading 重命名为 opening 以保持一致性。
/// 旧版本的 stopped 已移除 — stop() 将状态重置为 idle。
enum MediaState {
  /// 初始状态，未加载任何媒体
  idle,

  /// 正在加载/打开媒体
  opening,

  /// 正在播放
  playing,

  /// 已暂停
  paused,

  /// 播放完成（自然播放到末尾）
  completed,

  /// 发生错误
  error,
}

/// 状态转换合法性守卫
///
/// 正交 6 值模型的合法转换：
/// - idle → opening, error
/// - opening → idle, playing, error
/// - playing → paused, completed, error, idle
/// - paused → playing, error, idle
/// - completed → opening, error, idle
/// - error → opening, idle
///
/// debug 模式下非法转换触发 assert 警告（不崩溃）；
/// release 模式下非法转换被静默忽略。
extension MediaStateTransition on MediaState {
  bool canTransitionTo(MediaState next) {
    return switch (this) {
      MediaState.idle => next == MediaState.opening || next == MediaState.error,
      MediaState.opening =>
        next == MediaState.idle ||
            next == MediaState.playing ||
            next == MediaState.error,
      MediaState.playing =>
        next == MediaState.paused ||
            next == MediaState.completed ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.paused =>
        next == MediaState.playing ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.completed =>
        next == MediaState.opening ||
            next == MediaState.error ||
            next == MediaState.idle,
      MediaState.error =>
        next == MediaState.opening || next == MediaState.idle,
    };
  }
}
