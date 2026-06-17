import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';

/// 窗口管理服务 — 状态 + 监听者 + 命令 + 几何协调。
class WindowService with WindowListener {
  WindowService();

  // ─── Animation constants (moved from Tokens to fix inverted dependency) ───
  static const int _durationFullscreenAnim = 300;
  static const int _durationWindowResize = 100;

  // ─── Public state ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(1280, 720));

  bool _disposed = false;
  Timer? _resizeDebounce;

  // ─── Fullscreen animation ───
  bool _isAnimating = false;
  Timer? _fsAnimTimer;

  void _safeSet<T>(ValueNotifier<T> notifier, T value) {
    if (!_disposed) notifier.value = value;
  }

  // ─── Init ───

  /// 初始化窗口 — 在 main() 中 runApp() 之前调用。
  Future<void> init() async {
    await windowManager.ensureInitialized();

    // 同步 flutter_fullscreen 初始状态
    isFullscreen.value = FullScreen.isFullScreen;
    logBridge.d('[WindowService] FullScreen initialized, isFullScreen=${FullScreen.isFullScreen}');

    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 480),
    );

    unawaited(windowManager.waitUntilReadyToShow(options, () async {
      final settings = await SettingsStore.load();
      if (settings.isFullscreen) await SettingsStore.saveIsFullscreen(false);

      if (settings.windowX != null && settings.windowY != null) {
        final clamped = _clampToScreen(
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

      await windowManager.show();
      await windowManager.focus();
      if (settings.isMaximized) await windowManager.maximize();
    }));

    windowManager.addListener(this);
  }

  // ─── WindowListener ───

  @override
  void onWindowMaximize() {
    if (!isMaximized.value) _safeSet(isMaximized, true);
  }

  @override
  void onWindowUnmaximize() {
    if (isMaximized.value) _safeSet(isMaximized, false);
  }

  // ─── Fullscreen 由 flutter_fullscreen 驱动 ───

  @override
  void onWindowResize() {
    if (_disposed || _isAnimating) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: _durationWindowResize), () {
      if (_disposed) return;
      windowManager.getSize().then((size) {
        if (size != windowSize.value) _safeSet(windowSize, size);
      });
    });
  }

  @override
  void onWindowClose() {
    _resizeDebounce?.cancel();
    _disposed = true;
    _saveGeometry().whenComplete(() {
      dispose();
      windowManager.destroy();
    });
  }

  // ─── Commands ───

  Future<void> setFullscreen(bool value) async {
    if (value == isFullscreen.value || _isAnimating) return;
    try {
      _isAnimating = true;
      _fsAnimTimer?.cancel();
      logBridge.d('[WindowService] setFullscreen($value)');
      FullScreen.setFullScreen(value);
      if (!_disposed) isFullscreen.value = value;
      if (value) await SettingsStore.saveIsFullscreen(true);
      _fsAnimTimer = Timer(
        const Duration(milliseconds: _durationFullscreenAnim),
        () {
          _isAnimating = false;
          if (!value && !_disposed) SettingsStore.saveIsFullscreen(false);
        },
      );
    } on Exception catch (e) {
      _isAnimating = false;
      logBridge.e('[WindowService.setFullscreen] FAILED: $e');
    }
  }

  Future<void> enterFullscreen() => setFullscreen(true);
  Future<void> exitFullscreen() => setFullscreen(false);

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    isAlwaysOnTop.value = value;
    await SettingsStore.saveIsAlwaysOnTop(value);
  }

  Future<void> minimize() => windowManager.minimize();

  Future<void> maximize() async {
    await windowManager.maximize();
    isMaximized.value = true;
  }

  Future<void> restore() async {
    await windowManager.unmaximize();
    isMaximized.value = false;
  }

  Future<void> close() => windowManager.close();

  Future<void> startDragging() => windowManager.startDragging();

  // ─── Geometry persistence ───

  Future<void> _saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await SettingsStore.saveWindowGeometry(
        width: size.width,
        height: size.height,
        x: pos.dx,
        y: pos.dy,
        isMaximized: isMaximized.value,
      );
    } on Exception catch (e) {
      logBridge.e('[WindowService._saveGeometry] $e');
    }
  }

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
      logBridge.e('[WindowService._clampToScreen] $e');
    }
    return Offset(x, y);
  }

  // ─── Lifecycle ───

  void dispose() {
    _fsAnimTimer?.cancel();
    _disposed = true;
    _resizeDebounce?.cancel();
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
    windowManager.removeListener(this);
  }
}
