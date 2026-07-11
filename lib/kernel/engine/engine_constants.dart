/// 引擎层共享常量
///
/// 所有引擎实现共用的数值约束和默认值。
/// 集中管理确保一致性，修改时只需改一处。
abstract final class EngineConstants {
  // ─── 播放速度 ───

  /// 最小播放速率（0.25x 慢放）
  static const minPlaybackRate = 0.25;

  /// 最大播放速率（4.0x 快放）
  static const maxPlaybackRate = 4.0;

  /// 默认播放速率
  static const defaultPlaybackRate = 1.0;

  // ─── 音量 ───

  /// 默认音量（0.0 - 1.0）
  static const defaultVolume = 1.0;

  /// 最小音量
  static const minVolume = 0.0;

  /// 最大音量
  static const maxVolume = 1.0;

  // ─── 默认跳转步长 ───

  /// 默认快进/快退步长（毫秒）
  static const defaultSkipMs = 10000;
}
