import 'package:simple_player_flutter/kernel/engine/video_effect_type.dart';

/// 视频效果控制接口
///
/// 包含亮度/对比度/色调/饱和度调节、旋转、宽高比、反交错。
/// 只包含控制方法；aspectRatio 状态由 [EngineStateView] 提供。
///
/// Contract:
/// - All methods delegate to the underlying engine — no ValueNotifier mutation.
/// - Implementations must be no-op when the engine is disposed.
abstract class VideoEffectControl {
  /// 设置视频效果值
  ///
  /// - `effectType`: which effect to adjust (brightness, contrast, etc.).
  /// - `value`: effect magnitude; valid range depends on [effectType] semantics.
  /// - Side effect: applies the value to the underlying render pipeline.
  /// - No-op when the engine is disposed.
  void setVideoEffect(VideoEffectType effectType, double value);

  /// 旋转视频（度数，如 0/90/180/270）
  ///
  /// - `degrees`: rotation angle; typically one of {0, 90, 180, 270}.
  /// - Side effect: applies rotation to the underlying render pipeline.
  /// - No-op when the engine is disposed.
  void rotate(int degrees);

  /// 设置视频宽高比
  ///
  /// - `ratio`: aspect ratio value (e.g. 16/9, 4/3).
  /// - Side effect: applies ratio to the underlying player renderer.
  /// - Note: does NOT write back to [EngineStateView.aspectRatio] —
  ///   that ValueNotifier is only set by `open()` on success.
  /// - No-op when the engine is disposed.
  void setAspectRatio(double ratio);

  /// 启用/禁用反交错
  ///
  /// - `enable`: true to enable deinterlacing, false to disable.
  /// - Side effect: toggles the deinterlace flag in the render pipeline.
  /// - No-op when the engine is disposed.
  void setDeinterlace(bool enable);
}
