import 'package:flutter/animation.dart';

/// Apple 风格动画曲线 — 近似 macOS NSAnimationContext 时序。
///
/// macOS 全屏使用临界阻尼弹簧（dampingRatio=1.0），
/// 映射为 cubic bezier (0.25, 0.1, 0.25, 1.0)。
/// 此处使用略更激进的 ease-out 以适配桌面端手感。
///
/// ## 设计原则（Apple HIG）
/// - **进入动画**：快启慢停（ease-out），给用户"内容正在展开"的感觉
/// - **退出动画**：加速离场（ease-in），果断、不拖沓
/// - **弹性元素**：控制栏等 UI 元素使用轻微 overshoot，模拟物理弹簧
/// - **分层时序**：标题栏先退（200ms），内容后退（350ms），创造深度感
class AppleCurves {
  AppleCurves._();

  // ── 主要动画曲线 ──

  /// 全屏进入：快启慢停。
  /// 近似 NSAnimationContext.runAnimationGroup defaultTimingFunction。
  /// Cubic(0.22, 0.61, 0.36, 1.0) — 标准 Apple ease-out。
  static const fullscreenEnter = Cubic(0.22, 0.61, 0.36, 1.0);

  /// 全屏退出：加速离场。
  /// Cubic(0.55, 0.0, 0.79, 0.34) — 标准 Apple ease-in。
  static const fullscreenExit = Cubic(0.55, 0.0, 0.79, 0.34);

  // ── 元素级曲线 ──

  /// 控制栏入场：略带弹性，给控制栏"落地稳定"感。
  /// Cubic(0.33, 1.0, 0.68, 1.0) — overshoot 曲线。
  static const controlBarSlide = Cubic(0.33, 1.0, 0.68, 1.0);

  /// 标题栏退场：平滑 ease-out，略快于内容。
  /// Cubic(0.25, 0.1, 0.25, 1.0) — 标准 Apple 平滑曲线。
  static const titleBarFade = Cubic(0.25, 0.1, 0.25, 1.0);

  // ── 辅助曲线 ──

  /// 内容缩放：更柔和的 ease-out，避免缩放感过强。
  /// Cubic(0.2, 0.0, 0.0, 1.0) — iOS 标准 ease-out。
  static const contentScale = Cubic(0.2, 0.0, 0.0, 1.0);

  /// 背景淡入：平滑过渡，用于全屏时背景色变化。
  /// Cubic(0.4, 0.0, 0.2, 1.0) — Material Design standard。
  static const backgroundFade = Cubic(0.4, 0.0, 0.2, 1.0);

  /// 弹性入场：轻微 overshoot 后回弹，用于强调元素。
  /// Cubic(0.175, 0.885, 0.32, 1.275) — easeOutBack 变体。
  static const elasticEnter = Cubic(0.175, 0.885, 0.32, 1.275);
}
