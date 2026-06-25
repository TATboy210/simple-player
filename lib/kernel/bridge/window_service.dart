import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
import '../utils/screen_utils.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';

/// 窗口管理服务 — 薄协调者，组合职责组件。
///
/// 职责:
/// - WindowState: 状态容器 (mode, windowSize, isResizing, isAlwaysOnTop)
/// - WindowPersistence: debounce 持久化
///
/// OS 回调驱动状态（WindowListener → WindowState.mode/isResizing）。
class WindowService with WindowListener implements WindowBridge {
  WindowService();

  // ─── Components ───

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();

  bool _disposed = false;

  // ─── Animation constants ───

  static const int _durationWindowResize = 100;
  static const int _durationResizeEnd = 500; // 覆盖 Windows ~300ms 最大化动画

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
      minimumSize: Size(854, 513), // 480 内容高度 + 32px 标题栏 = 16:9 最小比例
    );

    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        final settings = await SettingsStore.load();

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

        if (settings.isMaximized) await windowManager.maximize();
      }),
    );

    windowManager.addListener(this);
  }

  // ─── WindowListener: OS callbacks drive state ───

  /// 统一的 resize 结束定时器 — 冻结 blur 直到动画完全结束
  void _startResizeEndTimer() {
    _resizeEndTimer?.cancel();
    _state.isResizing.value = true;
    _resizeEndTimer = Timer(
      Duration(milliseconds: _durationResizeEnd),
      () { if (!_disposed) _state.isResizing.value = false; },
    );
  }

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    _startResizeEndTimer(); // 冻结 blur 覆盖整个动画周期
    if (_state.mode.value != WindowMode.maximized) {
      _state.mode.value = WindowMode.maximized;
    }
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    _startResizeEndTimer(); // 冻结 blur 覆盖整个动画周期
    if (_state.mode.value == WindowMode.maximized) {
      _state.mode.value = WindowMode.windowed;
    }
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    _startResizeEndTimer(); // 统一逻辑
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(
      const Duration(milliseconds: _durationWindowResize),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (!_disposed && size != _state.windowSize.value) {
            _state.windowSize.value = Size(
              math.max(size.width, 854),
              math.max(size.height, 513),
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
      case WindowMode.windowed:
        if (_state.mode.value == WindowMode.maximized) {
          await windowManager.unmaximize();
          // OS 回调 onWindowUnmaximize 驱动 mode
        }
      case WindowMode.maximized:
        await windowManager.maximize();
      // OS 回调 onWindowMaximize 驱动 mode
      case WindowMode.minimized:
        await windowManager.minimize();
      // OS 回调 onWindowMinimize 驱动 mode
      case WindowMode.fullscreen:
        await windowManager.setFullScreen(true);
      // OS 回调 onWindowEnterFullScreen 驱动 mode
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
