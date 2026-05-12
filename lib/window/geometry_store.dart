import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 窗口几何数据
class WindowGeometry {
  final double width;
  final double height;
  final double x;
  final double y;
  final bool isMaximized;
  final bool isFullscreen;

  const WindowGeometry({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    this.isMaximized = false,
    this.isFullscreen = false,
  });

  Offset get position => Offset(x, y);
  Size get size => Size(width, height);
}

/// 窗口几何持久化 — SharedPreferences 存取
///
/// 500ms 去抖写入，避免拖拽/resize 时频繁磁盘 I/O。
/// 全屏时不保存全屏尺寸（由调用方控制）。
class WindowGeometryStore {
  WindowGeometryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyWidth = 'windowWidth';
  static const _keyHeight = 'windowHeight';
  static const _keyX = 'windowX';
  static const _keyY = 'windowY';
  static const _keyMaximized = 'windowIsMaximized';
  static const _keyFullscreen = 'windowIsFullscreen';

  static const defaultWidth = 1280.0;
  static const defaultHeight = 720.0;
  static const minVisible = 100.0;

  Timer? _debounce;
  Completer<void>? _inFlight;

  static const _debounceMs = 500;

  /// 是否有保存的窗口位置（首次启动时为 false）
  bool get hasSavedPosition => _prefs.containsKey(_keyX);

  /// 加载保存的窗口几何，无数据时返回默认值
  WindowGeometry load() {
    return WindowGeometry(
      width: _prefs.getDouble(_keyWidth) ?? defaultWidth,
      height: _prefs.getDouble(_keyHeight) ?? defaultHeight,
      x: _prefs.getDouble(_keyX) ?? 10.0,
      y: _prefs.getDouble(_keyY) ?? 10.0,
      isMaximized: _prefs.getBool(_keyMaximized) ?? false,
      isFullscreen: _prefs.getBool(_keyFullscreen) ?? false,
    );
  }

  /// 去抖保存窗口几何（连续 resize/move 事件合并为 500ms 后一次写入）
  void saveDebounced({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _saveNow(
        size: size,
        position: position,
        isMaximized: isMaximized,
      ),
    );
  }

  /// 立即保存（离散状态变更：最大化/恢复时调用）
  Future<void> saveImmediate({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) {
    _debounce?.cancel();
    return _saveNow(
      size: size,
      position: position,
      isMaximized: isMaximized,
    );
  }

  /// 保存全屏状态
  Future<void> saveFullscreen(bool value) async {
    try {
      await _prefs.setBool(_keyFullscreen, value);
    } on Exception catch (e) {
      debugPrint('[GeometryStore] saveFullscreen failed: $e');
    }
  }

  Future<void> _saveNow({
    required Size size,
    required Offset position,
    required bool isMaximized,
  }) async {
    // 等待上一次写入完成
    if (_inFlight != null && !_inFlight!.isCompleted) {
      await _inFlight!.future;
    }
    _inFlight = Completer<void>();
    try {
      await Future.wait([
        _prefs.setDouble(_keyWidth, size.width),
        _prefs.setDouble(_keyHeight, size.height),
        _prefs.setDouble(_keyX, position.dx),
        _prefs.setDouble(_keyY, position.dy),
        _prefs.setBool(_keyMaximized, isMaximized),
      ]);
    } on Exception catch (e) {
      debugPrint('[GeometryStore] save failed: $e');
    } finally {
      if (!_inFlight!.isCompleted) _inFlight!.complete();
      _inFlight = null;
    }
  }

  /// 等待所有待写入完成（关闭前调用）
  Future<void> flush() async {
    _debounce?.cancel();
    if (_inFlight != null && !_inFlight!.isCompleted) {
      await _inFlight!.future;
    }
  }

  /// 边界检查：确保窗口在当前屏幕可见区域内
  static WindowGeometry clampToVisibleBounds(WindowGeometry geo) {
    try {
      // 简单检查：至少 minVisible 像素在屏幕内
      // 使用 Flutter 的 display 获取屏幕尺寸
      final display = PlatformDispatcher.instance.views.first;
      final screenW = display.physicalSize.width / display.devicePixelRatio;
      final screenH = display.physicalSize.height / display.devicePixelRatio;

      final isOffScreen = geo.x + geo.width < minVisible ||
          geo.y + geo.height < minVisible ||
          geo.x > screenW - minVisible ||
          geo.y > screenH - minVisible;

      if (isOffScreen) {
        // 居中显示
        final cx = (screenW - geo.width) / 2;
        final cy = (screenH - geo.height) / 2;
        return WindowGeometry(
          width: geo.width,
          height: geo.height,
          x: cx.clamp(0, screenW - minVisible),
          y: cy.clamp(0, screenH - minVisible),
          isMaximized: geo.isMaximized,
        );
      }
    } on Exception catch (e) {
      debugPrint('[GeometryStore] bounds check failed: $e');
    }
    return geo;
  }

  /// 清理资源
  void dispose() {
    _debounce?.cancel();
  }
}
