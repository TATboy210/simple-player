import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';

/// 视频效果控制接口
///
/// 包含亮度/对比度/色调/饱和度调节、旋转、宽高比、反交错。
/// 只包含控制方法；aspectRatio 状态由 [EngineStateView] 提供。
abstract class VideoEffectControl {
  /// 设置视频效果值
  ///
  /// requires: 无（value 范围由具体 effectType 语义约束，见 VideoEffectController）
  /// ensures: 底层渲染管线应用指定效果值
  /// modifies: 无 ValueNotifier（仅委托 VideoEffectController，不反映到状态视图）
  void setVideoEffect(VideoEffectType effectType, double value);

  /// 旋转视频（度数，如 0/90/180/270）
  ///
  /// requires: 无
  /// ensures: 底层渲染管线应用指定旋转角度
  /// modifies: 无 ValueNotifier（仅委托 VideoEffectController）
  void rotate(int degrees);

  /// 设置视频宽高比
  ///
  /// requires: 无
  /// ensures: 底层播放器应用指定宽高比进行渲染
  /// modifies: 无 ValueNotifier（注：不写回 [EngineStateView.aspectRatio]，
  ///   该 ValueNotifier 仅由 open() 成功时自动计算写入 — 契约-实现落差，非本计划修复范围）
  void setAspectRatio(double ratio);

  /// 启用/禁用反交错
  ///
  /// requires: 无
  /// ensures: 底层渲染管线反交错开关状态更新为 enable
  /// modifies: 无 ValueNotifier（仅委托 VideoEffectController）
  void setDeinterlace(bool enable);
}
