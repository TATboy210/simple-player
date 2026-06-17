import 'dart:ui';

import '../persistence/settings_store.dart';
import '../utils/log.dart';

/// 窗口启动引导 — 位置校正 + 全屏状态清理。
class WindowBootstrap {
  WindowBootstrap._();

  static const double _minVisible = 100;

  /// 将窗口位置限制在屏幕可见范围内。
  /// 若窗口完全超出可见区域，则居中放置。
  static Offset clampToVisibleBounds({
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
          x + width < _minVisible ||
          y + height < _minVisible ||
          x > screenW - _minVisible ||
          y > screenH - _minVisible;

      if (offScreen) {
        return Offset(
          ((screenW - width) / 2).clamp(0.0, screenW - _minVisible),
          ((screenH - height) / 2).clamp(0.0, screenH - _minVisible),
        );
      }
    } on Exception catch (e) {
      logBridge.e('[WindowBootstrap.clampToVisibleBounds] $e');
    }
    return Offset(x, y);
  }

  /// 若设置中标记为全屏，则清除该标记（防止启动时卡在全屏）。
  static Future<void> clearFullscreenIfSaved(AppSettings settings) async {
    if (settings.isFullscreen) {
      await SettingsStore.saveIsFullscreen(false);
    }
  }
}
