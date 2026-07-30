import 'package:flutter/foundation.dart';

/// 音量控制接口
///
/// 音量设置（0.0~1.0）和静音切换。
/// 具体引擎类实现此接口（MediaKitEngine 经 MediaEngine 暴露 volumeControl getter）。
abstract class VolumeControl {
  /// 设置音量（0.0 ~ 1.0）
  ///
  /// requires: 无
  /// ensures: volume == clamp(value, 0.0, 1.0)；clamp 后为 0 时自动静音
  ///   （isMuted→true），从 0 调高时自动取消静音（isMuted→false，UX 便捷操作）
  /// modifies: [volume], [isMuted]（条件性 — 仅穿越 0 边界时触发）
  void setVolume(double value);

  /// 设置静音
  ///
  /// requires: 无
  /// ensures: isMuted == mute（直接设置，不触发音量联动）
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
