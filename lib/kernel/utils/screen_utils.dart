import 'dart:ui';

import '../bridge/display_enumerator.dart';
import '../diagnostics/kernel_logger.dart';

final log = KernelLogger.I;
final logBridge = KernelLogger.I;

/// 屏幕几何工具 — 窗口位置校正。
///
/// 支持多显示器：窗口保留在上次所在的显示器上。
class ScreenUtils {
  ScreenUtils._();

  /// 窗口边缘最小可见像素数。
  static const double minVisible = 100.0;

  /// 将窗口位置限制在最近的显示器可见范围内。
  ///
  /// 1. 找到窗口中心所在的显示器
  /// 2. 若找到，钳制到该显示器的 workArea
  /// 3. 若未找到（显示器断开），找最近的显示器
  /// 4. 若无显示器数据，回退到 [clampToPrimaryDisplay]
  static Offset clampToNearestMonitor({
    required List<DisplayInfo> displays,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    if (displays.isEmpty) {
      return clampToPrimaryDisplay(x: x, y: y, width: width, height: height);
    }

    final centerX = x + width / 2;
    final centerY = y + height / 2;

    // 找窗口中心所在的显示器
    final containing = _findContainingDisplay(displays, centerX, centerY);

    // 使用 workArea 钳制（排除任务栏）
    final target = containing ?? _findNearestDisplay(displays, centerX, centerY);
    return _clampToArea(
      area: target.workArea,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  /// 将窗口位置限制在主显示器可见范围内（已废弃 — 仅作回退）。
  ///
  /// 副显示器上的窗口会被拉回主显示器。
  /// 请改用 [clampToNearestMonitor]。
  @Deprecated('Use clampToNearestMonitor for multi-monitor support')
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

      return _clampToArea(
        area: Rect.fromLTWH(0, 0, screenW, screenH),
        x: x,
        y: y,
        width: width,
        height: height,
      );
    } catch (e, st) {
      logBridge.e('[ScreenUtils.clampToPrimaryDisplay] $e\n$st');
    }
    return Offset(x, y);
  }

  // ─── 内部方法 ───

  /// 找到包含指定点的显示器，未找到返回 null。
  static DisplayInfo? _findContainingDisplay(
    List<DisplayInfo> displays,
    double px,
    double py,
  ) {
    for (final d in displays) {
      if (d.workArea.contains(Offset(px, py))) {
        return d;
      }
    }
    return null;
  }

  /// 找到离指定点最近的显示器（按中心距离）。
  static DisplayInfo _findNearestDisplay(
    List<DisplayInfo> displays,
    double px,
    double py,
  ) {
    var nearest = displays.first;
    var minDist = double.infinity;

    for (final d in displays) {
      final cx = d.workArea.center.dx;
      final cy = d.workArea.center.dy;
      final dist = (cx - px) * (cx - px) + (cy - py) * (cy - py);
      if (dist < minDist) {
        minDist = dist;
        nearest = d;
      }
    }
    return nearest;
  }

  /// 将窗口钳制到指定区域。
  ///
  /// 若窗口完全超出可见区域（四边均小于 [minVisible]），则居中放置。
  /// 否则返回原始位置不变。
  static Offset _clampToArea({
    required Rect area,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final offScreen =
        x + width < area.left + minVisible ||
        y + height < area.top + minVisible ||
        x > area.right - minVisible ||
        y > area.bottom - minVisible;

    if (offScreen) {
      return Offset(
        (area.left + (area.width - width) / 2)
            .clamp(area.left, area.right - minVisible),
        (area.top + (area.height - height) / 2)
            .clamp(area.top, area.bottom - minVisible),
      );
    }
    return Offset(x, y);
  }
}
