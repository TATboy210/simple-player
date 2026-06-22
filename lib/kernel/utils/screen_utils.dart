import 'dart:ui';

import 'log.dart';

/// 屏幕几何工具 — 窗口位置校正。
///
/// 仅支持单显示器。多显示器环境下会将窗口拉回主显示器。
class ScreenUtils {
  ScreenUtils._();

  /// 窗口边缘最小可见像素数。
  static const double minVisible = 100.0;

  /// 将窗口位置限制在主显示器可见范围内。
  ///
  /// 若窗口完全超出可见区域（四边均小于 [minVisible]），则居中放置。
  /// 否则返回原始位置不变。
  ///
  /// 注意：仅查询主显示器 (views.first)。副显示器上的窗口会被拉回主显示器。
  static Offset clampToPrimaryDisplay({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    try {
      final display = PlatformDispatcher.instance.views.first;
      final screenW = display.physicalSize.width / display.devicePixelRatio;
      final screenH = display.physicalSize.height / display.devicePixelRatio;

      final offScreen =
          x + width < minVisible ||
          y + height < minVisible ||
          x > screenW - minVisible ||
          y > screenH - minVisible;

      if (offScreen) {
        return Offset(
          ((screenW - width) / 2).clamp(0.0, screenW - minVisible),
          ((screenH - height) / 2).clamp(0.0, screenH - minVisible),
        );
      }
    } catch (e, st) {
      logBridge.e('[ScreenUtils.clampToPrimaryDisplay] $e\n$st');
    }
    return Offset(x, y);
  }
}
