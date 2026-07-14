/// 播放控制接口 — 核心播放操作
///
/// 包含打开、播放、暂停、停止、跳转、音量、倍速等控制方法。
/// 与 [EngineStateView] 分离：此接口仅暴露控制方法，不包含状态。
///
/// 实现者通常是具体的引擎类（如 FvpEngine），
/// 消费者通过此接口控制播放行为。
abstract class PlaybackControl {
  /// 打开媒体文件
  Future<void> open(String path);

  /// 开始播放
  void play();

  /// 暂停播放
  void pause();

  /// 停止播放并重置位置
  void stop();

  /// 切换播放/暂停状态
  void togglePlayPause();

  /// 跳转到指定位置（毫秒）
  Future<void> seekTo(int ms);

  /// 设置音量（0.0 ~ 1.0）
  void setVolume(double volume);

  /// 设置静音
  void setMute(bool mute);

  /// 设置播放速度倍率（0.25 ~ 4.0）
  void setPlaybackRate(double rate);

  /// 设置 AB 循环范围
  ///
  /// [from] 起始位置（毫秒），[to] 结束位置（毫秒），-1 表示到末尾。
  void setRange({required int from, int to = -1});

  /// 快进（默认 10 秒）
  void skipForward([int ms = 10000]);

  /// 快退（默认 10 秒）
  void skipBack([int ms = 10000]);
}
