/// mpv 属性映射 — 项目层值 → mpv 属性键值对的纯函数层 (v0.0.6).
///
/// mpv property mapper — pure mapping from project-layer values to
/// mpv property key/value pairs. 经 media_kit 公开 API
/// `NativePlayer.setProperty` 应用 (不改 media_kit).
///
/// 范围约定 (VideoProcessingState 为权威): brightness/contrast/saturation/hue
/// 项目层均为 -1..1 (0 = 无调整) → mpv -100..100 线性映射 ×100.
library;

import '../models/aspect_ratio_mode.dart';
import 'video_effect_type.dart';

/// 一条待应用的 mpv 属性.
typedef MpvProperty = ({String key, String value});

/// mpv 属性映射 — 无状态纯函数集合.
abstract final class MpvPropertyMapper {
  /// 视频效果 → mpv 属性.
  static MpvProperty mapVideoEffect(VideoEffectType type, double v) =>
      switch (type) {
        VideoEffectType.brightness => (key: 'brightness', value: _mapUnit(v)),
        VideoEffectType.contrast => (key: 'contrast', value: _mapUnit(v)),
        VideoEffectType.saturation => (key: 'saturation', value: _mapUnit(v)),
        VideoEffectType.hue => (key: 'hue', value: _mapUnit(v)),
      };

  /// 旋转角度 (0/90/180/270) → mpv `video-rotate`.
  static MpvProperty mapRotation(int degrees) =>
      (key: 'video-rotate', value: '${degrees.clamp(0, 270)}');

  /// 去隔行开关 → mpv `deinterlace`.
  static MpvProperty mapDeinterlace(bool enable) =>
      (key: 'deinterlace', value: enable ? 'yes' : 'no');

  /// 硬解开关 → mpv `hwdec` (全局属性 — 不入 file-scoped 重放缓存).
  static MpvProperty mapHardwareDecoding(bool enabled) =>
      (key: 'hwdec', value: enabled ? 'auto' : 'no');

  /// 延迟 (毫秒) → mpv `sub-delay` / `audio-delay` (秒, 3 位小数).
  static MpvProperty mapDelay(String key, int ms) =>
      (key: key, value: (ms / 1000).toStringAsFixed(3));

  /// 宽高比 → mpv `video-aspect-override`.
  ///
  /// 引擎 facet 传的是 mdk 常量浮点 ([AspectRatioMode.mdkValue]) — 先还原
  /// 枚举再映射. `stretch` / `cropFill` 无法用单属性表达 → 返回 null
  /// (调用方诚实降级记日志, 保持原状, 不伪造).
  static MpvProperty? mapAspectRatio(double mdkRatio) {
    for (final mode in AspectRatioMode.values) {
      if (mode.mdkValue == mdkRatio) {
        return switch (mode) {
          AspectRatioMode.keepOriginal => (
            key: 'video-aspect-override',
            value: 'no',
          ),
          AspectRatioMode.ratio4_3 => (
            key: 'video-aspect-override',
            value: '4:3',
          ),
          AspectRatioMode.ratio16_9 => (
            key: 'video-aspect-override',
            value: '16:9',
          ),
          AspectRatioMode.ratio21_9 => (
            key: 'video-aspect-override',
            value: '21:9',
          ),
          // 单属性不可表达 — 显式不支持.
          AspectRatioMode.stretch || AspectRatioMode.cropFill => null,
        };
      }
    }
    return null; // 未知 mdk 常量 — 防御.
  }

  /// -1..1 (0 = 中性) → mpv -100..100 整数字符串.
  static String _mapUnit(double v) =>
      (v * 100).clamp(-100.0, 100.0).toStringAsFixed(0);
}
