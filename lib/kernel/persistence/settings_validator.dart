import '../models/aspect_ratio_mode.dart';
import '../models/play_mode.dart';

/// 设置验证 — 纯函数，无 I/O，无副作用。
///
/// 集中管理 AppSettings 字段的边界常量和验证逻辑。
/// 从 SettingsStore 提取（R2-4），消除 37 处内联 clamp 重复。
///
/// Contract:
/// - Pure functions only: no I/O, no side effects, no state mutation.
/// - All `sanitize*` methods return a clamped/fallback value — never throw.
/// - All `*` per-field validators clamp to their declared range constants.
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

  // ── 播放速度边界 ──
  static const double playbackSpeedMin = 0.25;
  static const double playbackSpeedMax = 4.0;
  static const double playbackSpeedDefault = 1.0;

  // ── 音频设置边界（Phase 33）──
  static const int audioEqPresetMax = 4;
  static const double audioBalanceMin = -1.0;
  static const double audioBalanceMax = 1.0;
  static const int audioSyncMsMax = 10000;

  // ── 主题索引边界 ──
  static const int themeIndexMax = 2;

  // ── 默认语言 ──
  static const String defaultLocale = 'zh';

  // ── Sanitizers ──

  /// 验证并修正窗口尺寸 — 防止 NaN/Infinity/负值损坏持久化数据
  ///
  /// Contract:
  /// - [v] is the raw dimension value.
  /// - [fallback] is returned when [v] is NaN, infinite, or non-positive.
  /// - [min]/[max] define the clamp range (inclusive).
  /// - Returns [fallback] if [v] is NaN, infinite, or <= 0.
  /// - Otherwise returns `v.clamp(min, max)`.
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
  ///
  /// Contract:
  /// - [v] is the raw coordinate value.
  /// - [fallback] is returned when [v] is NaN or infinite.
  /// - Returns [fallback] if [v] is NaN or infinite.
  /// - Otherwise returns `v.clamp(coordinateMin, coordinateMax)`.
  static double sanitizeCoordinate(double v, double fallback) {
    if (v.isNaN || v.isInfinite) return fallback;
    return v.clamp(coordinateMin, coordinateMax);
  }

  /// 验证旋转角度 — 仅允许 0/90/180/270，无效值返回 0
  ///
  /// Contract:
  /// - [v] is the raw rotation angle in degrees.
  /// - Returns [v] if it is one of {0, 90, 180, 270}.
  /// - Returns 0 for any other value.
  static int sanitizeRotation(int v) {
    return _validRotations.contains(v) ? v : 0;
  }

  static const _validRotations = [0, 90, 180, 270];

  // ── Per-field 验证器 ──

  /// 音量 [0.0, 1.0]
  ///
  /// Contract:
  /// - [v] is clamped to [0.0, 1.0].
  /// - Returns `v.clamp(0.0, 1.0)`.
  static double volume(double v) => v.clamp(0.0, 1.0);

  /// 播放模式索引 [0, PlayMode.values.length - 1]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, PlayMode.values.length - 1]`.
  static int playMode(int v) => v.clamp(0, PlayMode.values.length - 1);

  /// 主题索引 [0, themeIndexMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, themeIndexMax]`.
  static int themeIndex(int v) => v.clamp(0, themeIndexMax);

  /// 播放速度 [playbackSpeedMin, playbackSpeedMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[playbackSpeedMin, playbackSpeedMax]`.
  static double playbackSpeed(double v) =>
      v.clamp(playbackSpeedMin, playbackSpeedMax);

  /// 字幕字体大小 [subtitleFontSizeMin, subtitleFontSizeMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[subtitleFontSizeMin, subtitleFontSizeMax]`.
  static double subtitleFontSize(double v) =>
      v.clamp(subtitleFontSizeMin, subtitleFontSizeMax);

  /// 字幕颜色索引 [0, subtitleColorIndexMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, subtitleColorIndexMax]`.
  static int subtitleColorIndex(int v) => v.clamp(0, subtitleColorIndexMax);

  /// 字幕底部偏移 [subtitleOffsetMin, subtitleOffsetMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[subtitleOffsetMin, subtitleOffsetMax]`.
  static double subtitleOffset(double v) =>
      v.clamp(subtitleOffsetMin, subtitleOffsetMax);

  /// 视频效果值 (亮度/对比度/饱和度/色相) [videoEffectMin, videoEffectMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[videoEffectMin, videoEffectMax]`.
  static double videoEffect(double v) => v.clamp(videoEffectMin, videoEffectMax);

  /// 视频宽高比索引 [0, AspectRatioMode.values.length - 1]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, AspectRatioMode.values.length - 1]`.
  static int videoAspectRatioIndex(int v) =>
      v.clamp(0, AspectRatioMode.values.length - 1);

  // ── Phase 33 音频偏好验证器 ──

  /// EQ 预设索引 [0, audioEqPresetMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, audioEqPresetMax]`（5 个预设）。
  static int audioEqPreset(int v) => v.clamp(0, audioEqPresetMax);

  /// 立体声平衡 [audioBalanceMin, audioBalanceMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[audioBalanceMin, audioBalanceMax]`（-1.0..1.0）。
  static double audioBalance(double v) =>
      v.clamp(audioBalanceMin, audioBalanceMax);

  /// 音频延迟毫秒 [0, audioSyncMsMax]
  ///
  /// Contract:
  /// - [v] is clamped to `[0, audioSyncMsMax]`（0..10000，仅延迟）。
  static int audioSyncMs(int v) => v.clamp(0, audioSyncMsMax);
}
