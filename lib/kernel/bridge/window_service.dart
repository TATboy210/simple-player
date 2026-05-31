import 'dart:async';
import 'dart:developer';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';

import 'win32_bindings.dart';

/// 窗口管理服务 — 封装 window_manager，暴露 ValueNotifier 状态。
class WindowService with WindowListener {
  WindowService();

  bool _disposed = false;
  bool _fullscreenTransitioning = false;
  int? _savedStyle;
  Pointer<Rect>? _savedFrame;
  Pointer<Rect>? _savedMaximizeFrame; // 最大化前的窗口位置
  Timer? _resizeDebounce;
  Timer? _fullscreenTimeout;

  // ─── State (ValueNotifier pattern) ───

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);
  final ValueNotifier<bool> isMaximized = ValueNotifier(false);
  final ValueNotifier<Size> windowSize = ValueNotifier(const Size(960, 540));

  /// Initialize event listener — call after construction.
  void init() {
    windowManager.addListener(this);
  }

  /// 在 show() 之前调用，移除 WS_CAPTION 保留 WS_THICKFRAME。返回新 style。
  static Future<int> removeBorderImmediate() async {
    final hwnd = await windowManager.getId();
    final style = win32.getWindowLongPtr(hwnd, gwlStyle);
    // 只移除 WS_CAPTION，保留 WS_THICKFRAME 用于原生缩放
    final newStyle = style & ~wsCaption;
    win32.setWindowLongPtr(hwnd, gwlStyle, newStyle);

    // 保留 DWM 阴影：顶部 1px frame 让 DWM 认为窗口有边框
    final margins = calloc<Margins>()
      ..ref.left = 0
      ..ref.right = 0
      ..ref.top = 1
      ..ref.bottom = 0;
    try {
      win32.dwmExtendFrameIntoClientArea(hwnd, margins);
    } finally {
      calloc.free(margins);
    }

    win32.setWindowPos(
      hwnd,
      0,
      0,
      0,
      0,
      0,
      swpNoOwnerZOrder | swpFrameChanged | swpNomove | swpNosize,
    );

    return newStyle;
  }

  // ─── WindowListener callbacks → update ValueNotifiers ───

  @override
  void onWindowMaximize() {
    if (!_disposed) isMaximized.value = true;
  }

  @override
  void onWindowUnmaximize() {
    if (!_disposed) isMaximized.value = false;
  }

  @override
  void onWindowEnterFullScreen() {
    if (!_disposed && !isFullscreen.value) isFullscreen.value = true;
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!_disposed && isFullscreen.value) isFullscreen.value = false;
  }

  @override
  void onWindowResize() {
    if (_disposed) return;
    windowManager.getSize().then((size) {
      if (!_disposed) {
        windowSize.value = size;
        _scheduleGeometrySave();
      }
    });
  }

  @override
  void onWindowClose() {
    _saveGeometryImmediate().whenComplete(() {
      windowManager.destroy();
    });
  }

  /// 500ms 去抖保存窗口几何
  void _scheduleGeometrySave() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_disposed || isFullscreen.value || isMaximized.value) return;
      _saveGeometry(isMaximized: false);
    });
  }

  /// 立即保存窗口几何（关闭时调用）。
  Future<void> _saveGeometryImmediate() async {
    if (_disposed) return;
    _resizeDebounce?.cancel();
    await _saveGeometry(isMaximized: isMaximized.value);
  }

  Future<void> _saveGeometry({required bool isMaximized}) async {
    try {
      final pos = await windowManager.getPosition();
      final size = windowSize.value;
      await SettingsStore.saveWindowGeometry(
        width: size.width,
        height: size.height,
        x: pos.dx,
        y: pos.dy,
        isMaximized: isMaximized,
      );
    } on Exception catch (e) {
      debugPrint('WindowService: geometry save failed: $e');
    }
  }

  // ─── Commands (delegate to windowManager) ───

  /// 读取当前窗口矩形，返回新分配的 `Pointer<Rect>`（调用方负责 free）。
  Pointer<Rect> _readWindowRect(int hwnd) {
    final rect = calloc<Rect>();
    win32.getWindowRect(hwnd, rect);
    return rect;
  }

  /// 用保存的矩形恢复窗口位置。
  void _restoreWindowRect(int hwnd, Pointer<Rect> rect) => win32.setWindowPos(
        hwnd,
        0,
        rect.ref.left,
        rect.ref.top,
        rect.ref.right - rect.ref.left,
        rect.ref.bottom - rect.ref.top,
        swpNoOwnerZOrder | swpFrameChanged,
      );

  /// 真正的无边框全屏（WS_POPUP，绕过 window_manager 的 setFullScreen）。
  Future<void> setFullscreen(bool value) async {
    if (_fullscreenTransitioning) return;
    _fullscreenTransitioning = true;
    _fullscreenTimeout?.cancel();
    _fullscreenTimeout = Timer(const Duration(seconds: 5), () {
      if (_fullscreenTransitioning) {
        debugPrint('WindowService: fullscreen transition timeout, force reset');
        _fullscreenTransitioning = false;
      }
    });
    try {
      if (value) {
        await _enterFullscreen();
      } else {
        await _exitFullscreen();
      }
    } finally {
      _fullscreenTimeout?.cancel();
      _fullscreenTransitioning = false;
    }
  }

  Future<void> _enterFullscreen() async {
    Timeline.startSync('window.enterFullscreen');
    try {
      if (isFullscreen.value) return;
      final hwnd = await windowManager.getId();

      // 保存 style + frame 用于恢复
      _savedStyle = win32.getWindowLongPtr(hwnd, gwlStyle);
      if (_savedFrame != null) calloc.free(_savedFrame!);
      _savedFrame = _readWindowRect(hwnd);

      // WS_POPUP — 完全无边框
      win32.setWindowLongPtr(hwnd, gwlStyle, wsPopup);

      // 移除 DWM 阴影
      final margins = calloc<Margins>()
        ..ref.left = -1
        ..ref.right = -1
        ..ref.top = -1
        ..ref.bottom = -1;
      try {
        win32.dwmExtendFrameIntoClientArea(hwnd, margins);
      } finally {
        calloc.free(margins);
      }

      // 定位到整个监视器
      final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
      final mi = calloc<MonitorInfo>();
      mi.ref.cbSize = sizeOf<MonitorInfo>();
      try {
        win32.getMonitorInfo(hMonitor, mi);
        win32.setWindowPos(
          hwnd,
          hwndTop,
          mi.ref.rcMonitor.left,
          mi.ref.rcMonitor.top,
          mi.ref.rcMonitor.right - mi.ref.rcMonitor.left,
          mi.ref.rcMonitor.bottom - mi.ref.rcMonitor.top,
          swpNoOwnerZOrder | swpFrameChanged,
        );
      } finally {
        calloc.free(mi);
      }

      if (!isFullscreen.value) isFullscreen.value = true;
    } finally {
      Timeline.finishSync();
    }
  }

  Future<void> _exitFullscreen() async {
    Timeline.startSync('window.exitFullscreen');
    try {
      if (!isFullscreen.value) return;
      final hwnd = await windowManager.getId();

      if (_savedStyle != null) {
        win32.setWindowLongPtr(hwnd, gwlStyle, _savedStyle!);
      }
      if (_savedFrame != null) {
        _restoreWindowRect(hwnd, _savedFrame!);
        calloc.free(_savedFrame!);
        _savedFrame = null;
      }
      _savedStyle = null;

      if (isFullscreen.value) isFullscreen.value = false;
    } finally {
      Timeline.finishSync();
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    if (!_disposed) isAlwaysOnTop.value = value;
  }

  Future<void> minimize() => windowManager.minimize();

  /// 自定义最大化 — 使用 rcWork（工作区）而非全监视器。
  ///
  /// windowManager.maximize() 在无边框窗口上会覆盖任务栏，
  /// 因为插件的 adjustNCCALCSIZE 将客户区扩展到整个监视器。
  /// 此处直接用 GetMonitorInfoW 获取工作区矩形 + SetWindowPos 定位。
  Future<void> maximize() async {
    Timeline.startSync('window.maximize');
    try {
      if (isMaximized.value) return;
      final hwnd = await windowManager.getId();

      _savedMaximizeFrame = _readWindowRect(hwnd);

      // 获取工作区（排除任务栏）
      final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
      final mi = calloc<MonitorInfo>();
      mi.ref.cbSize = sizeOf<MonitorInfo>();
      try {
        win32.getMonitorInfo(hMonitor, mi);
        win32.setWindowPos(
          hwnd,
          hwndTop,
          mi.ref.rcWork.left,
          mi.ref.rcWork.top,
          mi.ref.rcWork.right - mi.ref.rcWork.left,
          mi.ref.rcWork.bottom - mi.ref.rcWork.top,
          swpNoOwnerZOrder | swpFrameChanged,
        );
      } finally {
        calloc.free(mi);
      }
      if (!isMaximized.value) isMaximized.value = true;
    } finally {
      Timeline.finishSync();
    }
  }

  /// 从自定义最大化恢复到之前的位置。
  Future<void> restore() async {
    Timeline.startSync('window.restore');
    try {
      if (!isMaximized.value || _savedMaximizeFrame == null) return;
      final hwnd = await windowManager.getId();

      _restoreWindowRect(hwnd, _savedMaximizeFrame!);
      calloc.free(_savedMaximizeFrame!);
      _savedMaximizeFrame = null;

      if (isMaximized.value) isMaximized.value = false;
    } finally {
      Timeline.finishSync();
    }
  }

  Future<void> close() => windowManager.close();

  Future<void> startDragging() => windowManager.startDragging();

  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    _fullscreenTimeout?.cancel();
    if (_savedFrame != null) {
      calloc.free(_savedFrame!);
      _savedFrame = null;
    }
    if (_savedMaximizeFrame != null) {
      calloc.free(_savedMaximizeFrame!);
      _savedMaximizeFrame = null;
    }
    windowManager.removeListener(this);
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
