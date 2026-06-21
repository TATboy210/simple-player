import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/events/window_events.dart';
import '../event_bus/event_bus.dart';
import '../logger/app_logger.dart';

/// 窗口管理服务 — 状态 + 监听者 + 命令。
///
/// v2 版本：EventBus 驱动（无 ValueNotifier），无持久化（MVP）。
class WindowService with WindowListener {
  WindowService(this._bus);

  final EventBus _bus;

  // ─── Animation constants ───
  static const int _durationFullscreenAnim = 300;
  static const int _durationWindowResize = 100;

  // ─── Internal state ───
  bool _isFullscreen = false;
  bool _isAlwaysOnTop = false;
  bool _isMaximized = false;
  Size _windowSize = const Size(1280, 720);

  bool _disposed = false;
  Timer? _resizeDebounce;
  bool _isAnimating = false;
  Timer? _fsAnimTimer;

  // ─── Read-only getters ───
  bool get isFullscreen => _isFullscreen;
  bool get isAlwaysOnTop => _isAlwaysOnTop;
  bool get isMaximized => _isMaximized;
  Size get windowSize => _windowSize;

  // ─── Init ───

  /// 初始化窗口 — 在 main() 中 runApp() 之前调用。
  Future<void> init() async {
    await windowManager.ensureInitialized();
    await FullScreen.ensureInitialized();

    _isFullscreen = FullScreen.isFullScreen;
    AppLogger.info('WindowService', 'FullScreen initialized, isFullScreen=$_isFullscreen');

    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 480),
    );

    unawaited(windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setSize(_windowSize);
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    }));

    windowManager.addListener(this);
  }

  // ─── WindowListener overrides ───

  @override
  void onWindowMaximize() {
    if (_disposed || _isMaximized) return;
    _isMaximized = true;
    _bus.fire(const MaximizeChanged(true));
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed || !_isMaximized) return;
    _isMaximized = false;
    _bus.fire(const MaximizeChanged(false));
  }

  @override
  void onWindowResize() {
    if (_disposed || _isAnimating) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(
      const Duration(milliseconds: _durationWindowResize),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (size != _windowSize) {
            _windowSize = size;
            _bus.fire(WindowSizeChanged(size));
          }
        });
      },
    );
  }

  @override
  void onWindowClose() {
    _resizeDebounce?.cancel();
    _disposed = true;
    dispose();
    windowManager.destroy();
  }

  // ─── Commands (called by WindowFeature) ───

  Future<void> setFullscreen(bool value) async {
    if (value == _isFullscreen || _isAnimating) return;
    try {
      _isAnimating = true;
      _fsAnimTimer?.cancel();
      AppLogger.info('WindowService', 'setFullscreen($value)');
      FullScreen.setFullScreen(value);
      _isFullscreen = value;
      _bus.fire(FullscreenChanged(value));
      _fsAnimTimer = Timer(
        const Duration(milliseconds: _durationFullscreenAnim),
        () => _isAnimating = false,
      );
    } on Exception catch (e) {
      _isAnimating = false;
      AppLogger.error('WindowService', 'setFullscreen FAILED', e);
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    _isAlwaysOnTop = value;
    _bus.fire(AlwaysOnTopChanged(value));
  }

  Future<void> minimize() => windowManager.minimize();

  Future<void> maximize() => windowManager.maximize();

  Future<void> restore() => windowManager.unmaximize();

  Future<void> close() => windowManager.close();

  Future<void> startDragging() => windowManager.startDragging();

  // ─── Screen clamping ───

  /// 将窗口位置限制在屏幕可视区域内（至少 100px 可见），越界时居中。
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
    } on Exception catch (e) {
      AppLogger.error('WindowService', '_clampToScreen failed', e);
    }
    return Offset(x, y);
  }

  // ─── Lifecycle ───

  void dispose() {
    _fsAnimTimer?.cancel();
    _disposed = true;
    _resizeDebounce?.cancel();
    windowManager.removeListener(this);
  }
}
