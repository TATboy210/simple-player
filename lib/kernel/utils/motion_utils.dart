import 'package:flutter/animation.dart';

/// 减弱动效适配
///
/// 当系统开启 [AccessibilityFeatures.disableAnimations] 时，
/// 返回零 Duration / Curves.linear，否则返回原始值。
class MotionUtils {
  MotionUtils._();

  static bool _reducedMotion = false;

  /// 由顶层 Widget 在 initState 中调用
  static void update(bool disableAnimations) {
    _reducedMotion = disableAnimations;
  }

  /// 返回适配后的 Duration
  static Duration duration(Duration original) {
    return _reducedMotion ? Duration.zero : original;
  }

  /// 返回适配后的 Curve
  static Curve curve(Curve original) {
    return _reducedMotion ? Curves.linear : original;
  }

  static bool get isReducedMotion => _reducedMotion;
}
