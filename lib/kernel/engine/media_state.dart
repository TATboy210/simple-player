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

