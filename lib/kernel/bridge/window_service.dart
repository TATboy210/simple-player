import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';
import '../diagnostics/kernel_logger.dart';
import '../utils/screen_utils.dart';
import 'display_enumerator.dart';
import 'win32/win32_display_enumerator.dart';
import 'window_bridge.dart';
import 'window_mode.dart';
import 'window_persistence.dart';
import 'window_state.dart';

/// 日志门面 — WindowService 共用。
final logBridge = KernelLogger.I;

/// Window management service - thin coordinator combining responsibility components.
class WindowService with WindowListener implements WindowBridge {
  /// 创建 WindowService。
  ///
  /// [displayEnumerator] 可选注入显示器枚举器，默认使用 Win32DisplayAdapter。
  WindowService({
    DisplayEnumerator? displayEnumerator,
  }) : _displayEnumerator = displayEnumerator ?? Win32DisplayAdapter();

  final WindowState _state = WindowState();
  final WindowPersistence _persistence = WindowPersistence();
  final DisplayEnumerator _displayEnumerator;

  bool _disposed = false;
  bool _isProgrammaticResize = false;
  bool _skipNextResize = false;

  /// resize 防抖延迟 — 500ms 内无新 resize 事件才更新 windowSize。
  static const int _resizeDebounceMs = 500;

  Timer? _resizeTimer;

  /// 当前是否全屏 — 从 mode 派生，单一数据源。
  @override
  bool get isFullscreen => _state.mode.value.isFullscreen;

  @override
  ValueNotifier<WindowMode> get mode => _state.mode;
  @override
  ValueNotifier<Size> get windowSize => _state.windowSize;
  @override
  ValueNotifier<bool> get isResizing => _state.isResizing;
  @override
  ValueNotifier<bool> get isAlwaysOnTop => _state.isAlwaysOnTop;

  WindowState get state => _state;

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(854, 513),
    );
    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        final settings = await SettingsStore.load();
        if (settings.windowX != null && settings.windowY != null) {
          final displays = _displayEnumerator.enumerateDisplays();
          final clamped = ScreenUtils.clampToNearestMonitor(
            displays: displays,
            x: settings.windowX!,
            y: settings.windowY!,
            width: settings.windowWidth,
            height: settings.windowHeight,
          );
          await windowManager.setBounds(
            null,
            position: clamped,
            size: Size(settings.windowWidth, settings.windowHeight),
          );
        } else {
          await windowManager.setBounds(
            null,
            size: Size(settings.windowWidth, settings.windowHeight),
          );
          await windowManager.center();
        }
        _skipNextResize = true;
        await windowManager.show();
        await windowManager.focus();
        if (settings.isMaximized) await windowManager.maximize();
      }),
    );
    windowManager.addListener(this);
  }

  void _updateOnUIThread(VoidCallback update) {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        update();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) => update());
      }
    } catch (_) {
      update();
    }
  }

  /// 单一 resize 定时器 — 合并 isResizing 标记和 windowSize 更新。
  void _startResizeTimer() {
    _resizeTimer?.cancel();
    _updateOnUIThread(() => _state.isResizing.value = true);
    _resizeTimer = Timer(
      const Duration(milliseconds: _resizeDebounceMs),
      () {
        if (_disposed) return;
        windowManager.getSize().then((size) {
          if (!_disposed && size != _state.windowSize.value) {
            _updateOnUIThread(() {
              _state.windowSize.value = Size(
                math.max(size.width, 854),
                math.max(size.height, 513),
              );
              _state.isResizing.value = false;
            });
          }
        });
      },
    );
  }

  @override
  void onWindowMaximize() {
    if (_disposed) return;
    logBridge.d('onWindowMaximize()');
    _startResizeTimer();
    _updateOnUIThread(() {
      if (_state.mode.value != WindowMode.maximized) {
        _state.mode.value = WindowMode.maximized;
      }
    });
  }

  @override
  void onWindowUnmaximize() {
    if (_disposed) return;
    logBridge.d('onWindowUnmaximize()');
    _startResizeTimer();
    _updateOnUIThread(() {
      if (_state.mode.value == WindowMode.maximized) {
        _state.mode.value = WindowMode.windowed;
      }
    });
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    if (_skipNextResize) { _skipNextResize = false; return; }
    if (_isProgrammaticResize) { _isProgrammaticResize = false; return; }
    _startResizeTimer();
  }

  @override
  void onWindowClose() {
    logBridge.i('onWindowClose() - saving geometry');
    _resizeTimer?.cancel();
    _saveGeometry().whenComplete(() {
      dispose();
      windowManager.destroy();
    });
  }

  @override
  Future<void> setMode(WindowMode target) async {
    if (_disposed || target == _state.mode.value) return;
    logBridge.i('setMode($target) <- ${_state.mode.value}');
    switch (target) {
      case WindowMode.windowed:
        if (_state.mode.value == WindowMode.maximized) {
          await windowManager.unmaximize();
        }
      case WindowMode.maximized:
        await windowManager.maximize();
      case WindowMode.minimized:
        await windowManager.minimize();
      case WindowMode.fullscreen:
        // TODO: Phase 2 — wire to fullscreen_window package
        break;
    }
  }

  @override
  Future<void> setAspectRatio(double ratio) async {
    await windowManager.setAspectRatio(ratio);
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

  Future<void> _saveGeometry() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _persistence.saveWindowGeometry(
        x: pos.dx, y: pos.dy,
        width: size.width, height: size.height,
        isMaximized: _state.mode.value.isMaximized,
      );
    } catch (e, st) {
      logBridge.e('[WindowService._saveGeometry] $e\n$st');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _state.dispose();
    _persistence.dispose();
    windowManager.removeListener(this);
  }
}
