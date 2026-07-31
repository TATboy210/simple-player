import 'open_result.dart';

/// 播放控制接口 — 核心播放操作（含打开、播放、暂停、停止、跳转、音量、倍速等控制方法）
///
/// 与 [EngineStateView] 分离：此接口仅暴露控制方法，不包含状态。
/// 实现者是具体的引擎类（MediaKitEngine），消费者通过此接口控制播放行为。
///
/// Contract:
/// - Implementations MUST update [state] via the declared transitions on each method.
/// - All seek/volume/rate inputs are clamped by the implementation; no exceptions for out-of-range values.
/// - Errors are surfaced through `lastError` + `state → error`, never thrown to callers.
/// - Implementations MUST be safe to call from any reachable state (no-op when transition is invalid).
abstract class PlaybackControl {
  /// 打开媒体文件
  ///
  /// requires: state ∈ {idle, opening, playing, paused, completed, error}
  /// ensures: 仅最新打开请求可操作共享播放器并发布结果；成功时 state == idle、
  ///   duration/aspectRatio 更新且 lastError == null；调用者须随后 play() 才进入 playing。
  /// states: 旧播放会话在新请求获得播放器独占权后收敛为 idle，再进入
  ///   opening；完成后转换为 idle 或 error。被取代的请求不发布任何状态。
  /// modifies: [state], [position], [duration], [aspectRatio], [lastError], [isBuffering]
  /// returns: [OpenSuccess] 用于提交后续播放副作用；[OpenError] 携带结构化失败；
  ///   [OpenSuperseded] 表示请求被新请求或释放操作取代，调用方不得提交副作用。
  /// throws: 正常失败不会抛异常，且仍同步经 lastError + state→error 供 UI 持续观察。
  Future<OpenResult> open(String path);

  /// 开始播放
  ///
  /// requires: state ∈ {idle, paused, completed}
  /// ensures: state == playing
  /// states: transitions to {playing, error}
  /// modifies: [state]
  /// throws: 经 lastError=PlaybackError + state→error 表达
  void play();

  /// 暂停播放
  ///
  /// requires: state ∈ {playing}（其余状态下调用为 no-op，见基线实现）
  /// ensures: state == paused
  /// states: transitions to {paused}
  /// modifies: [state]
  void pause();

  /// 停止播放并重置位置
  ///
  /// requires: 无（任意可达态均可调用）
  /// ensures: state == idle 且 position == 0
  /// states: transitions to {idle}
  /// modifies: [state], [position]
  void stop();

  /// 切换播放/暂停状态
  ///
  /// requires: 无（任意可达态均可调用；opening/error 态为 no-op）
  /// ensures: state == playing → 转 paused；state ∈ {idle, paused, completed} → 转 playing；
  ///   state ∈ {opening, error} → 保持不变（no-op）
  /// states: transitions to {playing, paused}（continues 同 [play]/[pause] 契约）
  /// modifies: [state]
  void togglePlayPause();

  /// 跳转到指定位置（毫秒）
  ///
  /// requires: state ∉ {idle} 且 duration > 0（否则 no-op）
  /// ensures: 成功时 position 更新为 clamp(ms, 0, duration)；调用前后 state 不变
  ///   （playing 保持 playing，paused 保持 paused）
  /// modifies: [position], [isSeeking]
  /// throws: 经 lastError=PlaybackError(seekFailed) 表达，position 回退为实际引擎位置
  Future<void> seekTo(int ms);

  /// 设置音量（0.0 ~ 1.0）
  ///
  /// requires: 无
  /// ensures: volume == clamp(volume, 0.0, 1.0)；clamp 后为 0 时自动静音
  ///   （isMuted→true），从 0 调高时自动取消静音（isMuted→false，见 [VolumeControl.setVolume]）
  /// modifies: [volume], [isMuted]（条件性 — 仅穿越 0 边界时触发）
  void setVolume(double volume);

  /// 设置静音
  ///
  /// requires: 无
  /// ensures: isMuted == mute（直接设置，不触发音量联动）
  /// modifies: [isMuted]
  void setMute(bool mute);

  /// 设置播放速度倍率（0.25 ~ 4.0）
  ///
  /// requires: 无
  /// ensures: playbackSpeed == clamp(rate, minPlaybackRate, maxPlaybackRate)
  /// modifies: [playbackSpeed]
  void setPlaybackRate(double rate);

  /// 设置 AB 循环范围
  ///
  /// [from] 起始位置（毫秒），[to] 结束位置（毫秒），-1 表示到末尾。
  ///
  /// requires: 无（from/to 越界或反序时内部自动纠正/clamp）
  /// ensures: 底层播放器循环范围更新为纠正后的 [from, to]
  /// modifies: 无 ValueNotifier（仅委托底层引擎设置，不反映到状态视图）
  void setRange({required int from, int to = -1});

  /// 快进（默认 10 秒）
  ///
  /// requires: 与 [seekTo] 相同（内部委托 seekTo）
  /// ensures: position 增加 ms（clamp 到 [0, duration]）
  /// modifies: [position], [isSeeking]（委托 seekTo）
  void skipForward([int ms = 10000]);

  /// 快退（默认 10 秒）
  ///
  /// requires: 与 [seekTo] 相同（内部委托 seekTo）
  /// ensures: position 减少 ms（clamp 到 [0, duration]）
  /// modifies: [position], [isSeeking]（委托 seekTo）
  void skipBack([int ms = 10000]);
}
