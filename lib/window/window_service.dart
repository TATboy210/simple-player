import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'aspect_ratio_service.dart';
import 'window_constants.dart';
import 'window_lifecycle.dart';
import 'window_state.dart';

class WindowService {
  WindowService._();
  static WindowService instance = WindowService._();

  final WindowState state = WindowState();

  /// 仅用于测试 — 替换 singleton 实例
  @visibleForTesting
  static void overrideInstance(WindowService svc) => instance = svc;

  final _resizeController = StreamController<bool>.broadcast();
  Stream<bool> get onResize => _resizeController.stream;

  final _moveController = StreamController<bool>.broadcast();
  Stream<bool> get onMove => _moveController.stream;

  Future<void> initialize() async {
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: Size(
        WindowConstants.defaultWidth,
        WindowConstants.defaultHeight,
      ),
      center: true,
      backgroundColor: Colors.black,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility:
          defaultTargetPlatform == TargetPlatform.macOS,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(WindowConstants.minSize);
      await windowManager.setPreventClose(true);
      await windowManager.setAsFrameless();
      await windowManager.show();
      await windowManager.focus();
      windowManager.addListener(_WindowListener(this));
    });
  }

  Future<void> setFullscreen(bool value) async {
    await windowManager.setFullScreen(value);
    // state 由 _WindowListener.onWindowEnterFullScreen/LeaveFullScreen 驱动
  }

  Future<void> maximize() async {
    await windowManager.maximize();
    // state 由 _WindowListener.onWindowMaximize 驱动
  }

  Future<void> restore() async {
    await windowManager.unmaximize();
    // state 由 _WindowListener.onWindowUnmaximize 驱动
  }

  Future<void> toggleMaximize() async {
    if (state.maximized.value) {
      await restore();
    } else {
      await maximize();
    }
  }

  Future<void> minimize() async {
    await windowManager.minimize();
  }

  Future<void> startDragging() async {
    await windowManager.startDragging();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    state.alwaysOnTop.value = value; // 无 OS listener，必须手动同步
  }

  Future<void> close() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  void dispose() {
    _resizeController.close();
    _moveController.close();
    WindowLifecycleBus.instance.dispose();
    AspectRatioService.I.dispose();
    state.dispose();
  }
}

class _WindowListener extends WindowListener {
  _WindowListener(this._svc);
  final WindowService _svc;

  @override
  void onWindowMaximize() => _svc.state.maximized.value = true;

  @override
  void onWindowUnmaximize() => _svc.state.maximized.value = false;

  @override
  void onWindowEnterFullScreen() =>
      _svc.state.fullscreen.value = true;

  @override
  void onWindowLeaveFullScreen() =>
      _svc.state.fullscreen.value = false;

  @override
  void onWindowFocus() => _svc.state.focused.value = true;

  @override
  void onWindowBlur() => _svc.state.focused.value = false;

  @override
  void onWindowClose() => _svc.close();

  @override
  void onWindowResize() {
    _svc._resizeController.add(true);
    _dispatchWithSize(WindowEventType.resizeStart);
  }

  @override
  void onWindowResized() {
    _svc._resizeController.add(false);
    _dispatchWithSize(WindowEventType.resizeEnd);
  }

  @override
  void onWindowMove() {
    _svc._moveController.add(true);
    WindowLifecycleBus.instance.dispatch(
      WindowEvent(WindowEventType.moveStart),
    );
  }

  @override
  void onWindowMoved() {
    _svc._moveController.add(false);
    WindowLifecycleBus.instance.dispatch(
      WindowEvent(WindowEventType.moveEnd),
    );
  }

  Future<void> _dispatchWithSize(WindowEventType type) async {
    final size = await windowManager.getSize();
    WindowLifecycleBus.instance.dispatch(WindowEvent(type, size: size));
  }
}
