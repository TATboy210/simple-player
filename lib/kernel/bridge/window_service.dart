import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'fullscreen_controller.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';

/// 窗口管理服务 — 薄协调者，组合 4 个职责组件。
///
/// 职责:
/// - WindowState: 状态容器 (mode, windowSize, isResizing, isAlwaysOnTop)
/// - FullscreenController: 原子全屏 + mutex + 回滚
/// - WindowPersistence: debounce 持久化
/// - lastInteractionTime: 窗口交互时间戳（防误触）
///
/// OS 回调驱动状态（WindowListener → WindowState.mode/isResizing）。
class WindowService with WindowListener implements WindowBridge {
  WindowService();

  // ─── Components ───

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();

  /// 最后一次窗口交互时间（毫秒时间戳）。
  final ValueNotifier<int> lastInteractionTime = ValueNotifier<int>(0);

  FullscreenController? _fullscreenCtrl;
  bool _disposed = false;

  // ─── Animation constants ───

  static const int _durationWindowResize = 100;

  Timer? _resizeDebounce;
  Timer? _resizeEndTimer;

  // ─── WindowBridge backward-compatible getters ───

  @override
  ValueNotifier<bool> get isFullscreen => _state.isFullscreen;

  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  @override
  ValueNotifier<bool> get isMaximized => _state.isMaximized;

  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;

  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;

  // ─── Extended accessors (new API) ───

  /// 窗口状态容器 — 新代码优先使用此接口。
  WindowState get state => _state;

  // ─── Init ───

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();

    // 同步 flutter_fullscreen 初始状态
    _state.isFullscreen.value = FullScreen.isFullScreen;
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

      // 初始化全屏控制器
      _fullscreenCtrl = FullscreenController(state: _state);

      if (settings.isMaximized) await windowManager.maximize();
    }));

    windowManager.addListener(this);
  }

  // ─── WindowListener: OS callbacks drive state ───

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    if (_state.mode.value != WindowMode.maximized) {
      _state.mode.value = WindowMode.maximized;
      lastInteractionTime.value = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    if (_state.mode.value == WindowMode.maximized) {
      _state.mode.value = WindowMode.windowed;
      lastInteractionTime.value = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  void onWindowResize() {
    if (_disposed || (_fullscreenCtrl?.isAnimating ?? false)) return;
    _safeSet(_state.isResizing, true);
    _resizeEndTimer?.cancel();
    _resizeEndTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_disposed) _safeSet(_state.isResizing, false);
    });
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: _durationWindowResize), () {
      if (_disposed) return;
      windowManager.getSize().then((size) {
        if (size != _state.windowSize.value) {
          _safeSet(_state.windowSize, Size(
            math.max(size.width, 854),
            math.max(size.height, 480),
          ));
        }
      });
    });
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
  Future<void> setFullscreen(bool value) async {
    if (_disposed) return;
    final ctrl = _fullscreenCtrl;
    if (ctrl == null) {
      logBridge.e('[WindowService.setFullscreen] controller not initialized');
      return;
    }
    await ctrl.setFullscreen(value);
    // 持久化全屏状态
    if (value) {
      await _persistence.saveIsFullscreen(true);
    } else {
      // 延迟保存退出全屏（等待动画完成）
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_disposed) _persistence.saveIsFullscreen(false);
      });
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
  Future<void> maximize() async {
    await windowManager.maximize();
    // OS 回调 onWindowMaximize 会驱动 mode
  }

  @override
  Future<void> restore() async {
    await windowManager.unmaximize();
    // OS 回调 onWindowUnmaximize 会驱动 mode
  }

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
        isMaximized: _state.isMaximized.value,
      );
    } catch (e, st) {
      logBridge.e('[WindowService._saveGeometry] $e\n$st');
    }
  }

  // ─── Lifecycle ───

  void _safeSet<T>(ValueNotifier<T> notifier, T value) {
    if (!_disposed) notifier.value = value;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeDebounce?.cancel();
    _resizeEndTimer?.cancel();
    _state.dispose();
    lastInteractionTime.dispose();
    _persistence.dispose();
    windowManager.removeListener(this);
  }
}
