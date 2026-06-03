import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import 'window_service.dart';

/// 窗口几何持久化 — 保存/恢复窗口位置、尺寸、最大化状态。
class WindowGeometryStore {
  WindowGeometryStore(this._service);

  final WindowService _service;

  /// 从设置恢复窗口几何。在 init 的 waitUntilReadyToShow 回调中调用。
  Future<void> restoreGeometry(AppSettings settings) async {
    if (settings.windowX != null && settings.windowY != null) {
      logBridge.d('[WindowGeometryStore.restoreGeometry] saved pos=(${settings.windowX}, ${settings.windowY})');
      final clamped = _clampToScreen(
        x: settings.windowX!,
        y: settings.windowY!,
        width: settings.windowWidth,
        height: settings.windowHeight,
      );
      logBridge.d('[WindowGeometryStore.restoreGeometry] clamped pos=(${clamped.dx}, ${clamped.dy})');
      await windowManager.setPosition(clamped);
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
    } else {
      logBridge.d('[WindowGeometryStore.restoreGeometry] no saved position, centering');
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
      await windowManager.center();
    }
  }

  /// 保存当前窗口几何到 SettingsStore。在 onWindowClose 中调用。
  Future<void> saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = _service.windowSize.value;
      logBridge.d('[WindowGeometryStore.saveGeometry] pos=(${pos.dx}, ${pos.dy}) '
          'size=${size.width.toInt()}×${size.height.toInt()} max=${_service.isMaximized.value}');
      await SettingsStore.saveWindowGeometry(
        width: size.width,
        height: size.height,
        x: pos.dx,
        y: pos.dy,
        isMaximized: _service.isMaximized.value,
      );
      logBridge.d('[WindowGeometryStore.saveGeometry] done');
    } on Exception catch (e) {
      logBridge.w('[WindowGeometryStore.saveGeometry] FAILED: $e');
    }
  }

  /// 将窗口坐标限制在屏幕可见范围内。超出时居中。
  static Offset _clampToScreen({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    const minVisible = 100.0;
    try {
      final display = PlatformDispatcher.instance.views.first;
      final screenW = display.physicalSize.width / display.devicePixelRatio;
      final screenH = display.physicalSize.height / display.devicePixelRatio;

      final offScreen = x + width < minVisible ||
          y + height < minVisible ||
          x > screenW - minVisible ||
          y > screenH - minVisible;

      if (offScreen) {
        logBridge.d('[WindowGeometryStore._clampToScreen] OFF-SCREEN detected '
            '($x,$y ${width}x$height) screen=${screenW}x$screenH');
        final center = Offset(
          ((screenW - width) / 2).clamp(0.0, screenW - minVisible),
          ((screenH - height) / 2).clamp(0.0, screenH - minVisible),
        );
        logBridge.d('[WindowGeometryStore._clampToScreen] recentered to (${center.dx}, ${center.dy})');
        return center;
      }
    } on Exception catch (e) {
      logBridge.w('[WindowGeometryStore._clampToScreen] screen bounds check failed: $e');
    }
    return Offset(x, y);
  }
}
