import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';

/// 窗口启动引导 — 在 main.dart waitUntilReadyToShow 回调中调用
///
/// 职责:
/// 1. 从 AppSettings 读取保存的几何数据
/// 2. 在多显示器场景下验证窗口可见性，不可见时居中
/// 3. 应用保存的位置/大小，或居中显示
/// 4. 清除 isFullscreen 标志（D-02: 避免崩溃后无法退出全屏）
class WindowBootstrap {
  WindowBootstrap._();

  static const _minVisible = 100.0;

  /// 清除保存的全屏标志（D-02）
  ///
  /// 启动时不恢复全屏状态，因为 _savedFrame 仅在内存中，
  /// 崩溃后丢失会导致无法退出全屏。
  static Future<void> clearFullscreenIfSaved(AppSettings settings) async {
    if (settings.isFullscreen) {
      await SettingsStore.saveIsFullscreen(false);
    }
  }

  /// 恢复保存的窗口几何，或居中显示
  ///
  /// 在 windowManager.show() 之前调用。
  /// 如果有保存的位置且在可见范围内，恢复位置+大小；
  /// 否则居中显示默认大小。
  static Future<void> restoreOrCenter(AppSettings settings) async {
    if (settings.windowX != null && settings.windowY != null) {
      final clamped = _clampToVisibleBounds(
        x: settings.windowX!,
        y: settings.windowY!,
        width: settings.windowWidth,
        height: settings.windowHeight,
      );
      await windowManager.setPosition(clamped);
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
    } else {
      await windowManager.setSize(
        Size(settings.windowWidth, settings.windowHeight),
      );
      await windowManager.center();
    }
  }

  /// 确保窗口在当前屏幕可见区域内
  ///
  /// 使用 PlatformDispatcher 获取主显示器尺寸（无需 screen_retriever）。
  /// 至少 _minVisible 像素必须在屏幕内，否则居中。
  static Offset _clampToVisibleBounds({
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    try {
      final display = PlatformDispatcher.instance.views.first;
      final screenW = display.physicalSize.width / display.devicePixelRatio;
      final screenH = display.physicalSize.height / display.devicePixelRatio;

      final isOffScreen =
          x + width < _minVisible ||
          y + height < _minVisible ||
          x > screenW - _minVisible ||
          y > screenH - _minVisible;

      if (isOffScreen) {
        final cx = ((screenW - width) / 2).clamp(0.0, screenW - _minVisible);
        final cy = ((screenH - height) / 2).clamp(0.0, screenH - _minVisible);
        return Offset(cx, cy);
      }
    } on Exception catch (e) {
      debugPrint('[WindowBootstrap] bounds check failed: $e');
    }
    return Offset(x, y);
  }
}
