import 'package:flutter/foundation.dart';

/// 音量控制接口
///
/// 音量设置（0.0~1.0）和静音切换。
/// VolumeController 实现此接口，FvpEngine 通过 volumeControl getter 暴露。
abstract class VolumeControl {
  /// 设置音量（0.0 ~ 1.0）
  void setVolume(double value);

  /// 设置静音
  void setMute(bool mute);

  /// 当前音量值
  ValueNotifier<double> get volume;

  /// 是否静音
  ValueNotifier<bool> get isMuted;
}
