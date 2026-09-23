import 'package:flutter/foundation.dart';

/// 音量控制接口
///
/// 音量设置（0.0~1.0 感知刻度）和静音切换。
/// 具体引擎类实现此接口（MediaKitEngine 经 MediaEngine 暴露 volumeControl getter）。
///
/// 感知刻度约定 (v0.0.8.1)：[volume] notifier 与持久化均为用户空间 0.0~1.0，
/// 滑条位置即感知响度 — 引擎内部经立方根曲线映射到 mpv `volume` 属性
/// （mpv 软增益本身是立方 gain=(v/100)³，见 MpvPropertyMapper.mapVolumeToMpv）。
abstract class VolumeControl {
  /// 设置音量（0.0 ~ 1.0）
  ///
  /// requires: 无
  /// ensures: volume == clamp(value, 0.0, 1.0)；clamp 后为 0 时自动静音
  ///   （isMuted→true），从 0 调高时自动取消静音（isMuted→false，UX 便捷操作）
  /// modifies: [volume], [isMuted]（条件性 — 仅穿越 0 边界时触发）
  void setVolume(double value);

  /// 设置静音（mpv 原生 `mute` 属性）
  ///
  /// requires: 无
  /// ensures: isMuted == mute（直接设置，不触发音量联动；音量属性在静音
  ///   期间不动 — unmute 即恢复原响度，无需"静音前快照"）
  /// modifies: [isMuted]
  void setMute(bool mute);

  /// 当前音量值
  ///
  /// requires: 无
  /// ensures: 返回最近一次 setVolume 写入的值
  /// modifies: 无（纯读取）
  ValueNotifier<double> get volume;

  /// 是否静音
  ///
  /// requires: 无
  /// ensures: 返回最近一次 setMute/setVolume 联动写入的值
  /// modifies: 无（纯读取）
  ValueNotifier<bool> get isMuted;
}
