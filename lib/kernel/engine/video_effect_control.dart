import 'package:flutter/foundation.dart';

import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';

/// 视频效果控制接口
///
/// 包含亮度/对比度/色调/饱和度调节、旋转、宽高比、反交错。
/// aspectRatio getter 返回与 [EngineStateView] 相同的 ValueNotifier 实例。
abstract class VideoEffectControl {
  /// 设置视频效果值
  void setVideoEffect(VideoEffectType effectType, double value);

  /// 旋转视频（度数，如 0/90/180/270）
  void rotate(int degrees);

  /// 设置视频宽高比
  void setAspectRatio(double ratio);

  /// 启用/禁用反交错
  void setDeinterlace(bool enable);

  /// 视频宽高比 — 与 EngineStateView.aspectRatio 同一实例
  ValueNotifier<double> get aspectRatio;
}
