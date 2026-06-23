import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'fullscreen_controller.dart';
import 'platform_fullscreen.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';
import 'linux/linux_platform_fullscreen.dart';
import 'macos/macos_platform_fullscreen.dart';
import 'win32/win32_platform_fullscreen.dart';

/// 窗口管理服务 — 薄协调者，组合 4 个职责组件。
///
/// 职责:
/// - WindowState: 状态容器 (mode, windowSize, isResizing, isAlwaysOnTop)
/// - FullscreenController: 原子全屏 + mutex + 回滚
/// - WindowPersistence: debounce 持久化
///
/// OS 回调驱动状态（WindowListener → WindowState.mode/isResizing）。
class WindowService with WindowListener implements WindowBridge {
  WindowService();

  // ─── Components ───

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();

  FullscreenController? _fullscreenCtrl;
  bool _disposed = false;

  // ─── Animation constants ───

  static const int _durationWindowResize = 100;

  Timer? _resizeDebounce;
  Timer? _resizeEndTimer;

  // ─── WindowBridge state getters ───

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;

  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;

  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;

  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  // ─── Extended accessors (new API) ───

  /// 窗口状态容器 — 新代码优先使用此接口。
  WindowState get state => _state;

  // ─── Init ───

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 480),
    );

    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        final settings = await SettingsStore.load();
        if (settings.isFullscreen) await SettingsStore.saveIsFullscreen(false);

        if (settings.windowX != null && settings.windowY != null) {
          final clamped = ScreenUtils.clampToPrimaryDisplay(
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

        // 初始化全屏控制器（注入平台特定实现）
        _fullscreenCtrl = FullscreenController(
          state: _state,
          platform: _createPlatformFullscreen(),
        );

        if (settings.isMaximized) await windowManager.maximize();
      }),
    );

    windowManager.addListener(this);
  }

  // ─── WindowListener: OS callbacks drive state ───

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    if (_state.mode.value != WindowMode.maximized) {
      _state.mode.value = WindowMode.maximized;
    }
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    if (_state.mode.value == WindowMode.maximized) {
      _state.mode.value = WindowMode.windowed;
    }
  }

  @override
  void onWindowResize() {
    if (_disposed || (_fullscreenCtrl?.isAnimating ?? false)) return;
    _state.isResizing.value = true;
    _resizeEndTimer?.cancel();
    _resizeEndTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_disposed) _state.isResizing.value = false;
    });
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(
      const Duration(milliseconds: _durationWindowResize),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (!_disposed && size != _state.windowSize.value) {
            _state.windowSize.value = Size(
              math.max(size.width, 854),
              math.max(size.height, 480),
            );
          }
        });
      },
    );
  }

  @override
  void onWindowClose() {
    _resizeDebounce?.cancel();
    _resizeEndTimer?.cancel();
    _disposed = true;
    _saveGeometry().whenComplete(() {
      dispose();
      windowManager.destroy();
    });
  }

  // ─── Commands ───

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed || target == _state.mode.value) return;

    switch (target) {
      case WindowMode.fullscreen:
        final ctrl = _fullscreenCtrl;
        if (ctrl == null) {
          logBridge.e('[WindowService.setMode] controller not initialized');
          return;
        }
        await ctrl.setFullscreen(true);
        await _persistence.saveIsFullscreen(true);
      case WindowMode.windowed:
        final current = _state.mode.value;
        if (current == WindowMode.fullscreen) {
          final ctrl = _fullscreenCtrl;
          if (ctrl == null) return;
          await ctrl.setFullscreen(false);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!_disposed) _persistence.saveIsFullscreen(false);
          });
        } else if (current == WindowMode.maximized) {
          await windowManager.unmaximize();
          // OS 回调 onWindowUnmaximize 驱动 mode
        }
      case WindowMode.maximized:
        await windowManager.maximize();
      // OS 回调 onWindowMaximize 驱动 mode
      case WindowMode.minimized:
        await windowManager.minimize();
      // OS 回调 onWindowMinimize 驱动 mode
    }
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    _state.isAlwaysOnTop.value = value;
    await SettingsStore.saveIsAlwaysOnTop(value);
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  // ─── Geometry persistence ───

  Future<void> _saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _persistence.saveWindowGeometry(
        x: pos.dx,
        y: pos.dy,
        width: size.width,
        height: size.height,
        isMaximized: _state.mode.value.isMaximized,
      );
    } catch (e, st) {
      logBridge.e('[WindowService._saveGeometry] $e\n$st');
    }
  }

  // ─── Platform factory ───

  PlatformFullscreen _createPlatformFullscreen() {
    if (Platform.isWindows) return Win32PlatformFullscreen();
    if (Platform.isMacOS) return MacosPlatformFullscreen();
    if (Platform.isLinux) return LinuxPlatformFullscreen();
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  // ─── Lifecycle ───

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeDebounce?.cancel();
    _resizeEndTimer?.cancel();
    _state.dispose();
    _persistence.dispose();
    windowManager.removeListener(this);
  }
}
