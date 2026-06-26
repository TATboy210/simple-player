import '../models/aspect_ratio_mode.dart';
import '../models/play_mode.dart';

/// 设置验证 — 纯函数，无 I/O，无副作用。
///
/// 集中管理 AppSettings 字段的边界常量和验证逻辑。
/// 从 SettingsStore 提取（R2-4），消除 37 处内联 clamp 重复。
class SettingsValidator {
  SettingsValidator._(); // 不可实例化

  // ── 窗口尺寸边界 ──
  static const double windowWidthDefault = 1280;
  static const double windowHeightDefault = 752;
  static const double windowWidthMin = 1024;
  static const double windowWidthMax = 8192;
  static const double windowHeightMin = 513;
  static const double windowHeightMax = 4608;

  // ── 窗口坐标边界（覆盖多显示器场景） ──
  static const double coordinateMin = -30000;
  static const double coordinateMax = 30000;

  // ── 字幕设置边界 ──
  static const double subtitleFontSizeMin = 14;
  static const double subtitleFontSizeMax = 28;
  static const double subtitleFontSizeDefault = 17;
  static const int subtitleColorIndexMax = 2;
  static const double subtitleOffsetMin = 60;
  static const double subtitleOffsetMax = 200;
  static const double subtitleOffsetDefault = 80;

  // ── 视频效果边界 ──
  static const double videoEffectMin = -1;
  static const double videoEffectMax = 1;

  // ── 主题索引边界 ──
  static const int themeIndexMax = 2;

  // ── 默认语言 ──
  static const String defaultLocale = 'zh';

  // ── Sanitizers ──

  /// 验证并修正窗口尺寸 — 防止 NaN/Infinity/负值损坏持久化数据
  static double sanitizeDimension(
    double v,
    double fallback,
    double min,
    double max,
  ) {
    if (v.isNaN || v.isInfinite || v <= 0) return fallback;
    return v.clamp(min, max);
  }

  /// 验证并修正窗口坐标 — 防止 NaN/Infinity 损坏持久化数据
  static double sanitizeCoordinate(double v, double fallback) {
    if (v.isNaN || v.isInfinite) return fallback;
    return v.clamp(coordinateMin, coordinateMax);
  }

  /// 验证旋转角度 — 仅允许 0/90/180/270，无效值返回 0
  static int sanitizeRotation(int v) {
    return _validRotations.contains(v) ? v : 0;
  }

  static const _validRotations = [0, 90, 180, 270];

  // ── Per-field 验证器 ──

  /// 音量 [0.0, 1.0]
  static double volume(double v) => v.clamp(0.0, 1.0);

  /// 播放模式索引 [0, PlayMode.values.length - 1]
  static int playMode(int v) => v.clamp(0, PlayMode.values.length - 1);

  /// 主题索引 [0, themeIndexMax]
  static int themeIndex(int v) => v.clamp(0, themeIndexMax);

  /// 字幕字体大小 [subtitleFontSizeMin, subtitleFontSizeMax]
  static double subtitleFontSize(double v) =>
      v.clamp(subtitleFontSizeMin, subtitleFontSizeMax);

  /// 字幕颜色索引 [0, subtitleColorIndexMax]
  static int subtitleColorIndex(int v) => v.clamp(0, subtitleColorIndexMax);

  /// 字幕底部偏移 [subtitleOffsetMin, subtitleOffsetMax]
  static double subtitleOffset(double v) =>
      v.clamp(subtitleOffsetMin, subtitleOffsetMax);

  /// 视频效果值 (亮度/对比度/饱和度/色相) [videoEffectMin, videoEffectMax]
  static double videoEffect(double v) => v.clamp(videoEffectMin, videoEffectMax);

  /// 视频宽高比索引 [0, AspectRatioMode.values.length - 1]
  static int videoAspectRatioIndex(int v) =>
      v.clamp(0, AspectRatioMode.values.length - 1);
}
