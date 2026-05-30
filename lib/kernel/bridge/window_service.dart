import 'dart:async';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';

import 'win32_bindings.dart';

/// Window management service — wraps window_manager package.
///
/// Provides ValueNotifier state for reactive UI binding via
/// ValueListenableBuilder. Delegates all window operations to
/// the windowManager singleton.
///
/// Uses WindowListener mixin to receive events and update ValueNotifiers.
class WindowService with WindowListener {
  WindowService();

  bool _disposed = false;
  bool _fullscreenTransitioning = false;
  int? _savedStyle;
  Pointer<Rect>? _savedFrame;
  Pointer<Rect>? _savedMaximizeFrame; // 最大化前的窗口位置
  int? _baseStyle; // _removeBorder() 完成后的基准 style
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
    _removeBorder();
  }

  /// 移除窗口标题栏，保留缩放边框和 DWM 阴影。
  ///
  /// 只移除 WS_CAPTION（标题栏文字+按钮），保留 WS_THICKFRAME（原生缩放支持）。
  /// DwmExtendFrameIntoClientArea(0,0,1,0) 在顶部扩展 1px 让 DWM 保留窗口阴影。
  Future<void> _removeBorder() async {
    _baseStyle = await removeBorderImmediate();
  }

  /// 静态版本 — 可在 main.dart 中 windowManager.show() 之前调用。
  ///
  /// 返回设置后的 style，供 _baseStyle 缓存。
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
      swpNoOwnerZOrder | swpFrameChanged | 0x0001 | 0x0002, // NOMOVE | NOSIZE
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
    _saveGeometryImmediate();
    windowManager.destroy();
  }

  /// 500ms 去抖保存窗口几何到 SettingsStore
  void _scheduleGeometrySave() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (_disposed || isFullscreen.value || isMaximized.value) return;
      try {
        final pos = await windowManager.getPosition();
        final size = windowSize.value;
        await SettingsStore.saveWindowGeometry(
          width: size.width,
          height: size.height,
          x: pos.dx,
          y: pos.dy,
          isMaximized: false,
        );
      } on Exception catch (e) {
        debugPrint('WindowService: geometry save failed: $e');
      }
    });
  }

  /// 立即保存窗口几何（关闭时调用，不跳过全屏/最大化）。
  void _saveGeometryImmediate() {
    if (_disposed) return;
    _resizeDebounce?.cancel();
    () async {
      try {
        final pos = await windowManager.getPosition();
        final size = windowSize.value;
        await SettingsStore.saveWindowGeometry(
          width: size.width,
          height: size.height,
          x: pos.dx,
          y: pos.dy,
          isMaximized: isMaximized.value,
        );
      } on Exception catch (e) {
        debugPrint('WindowService: immediate geometry save failed: $e');
      }
    }();
  }

  // ─── Commands (delegate to windowManager) ───

  /// Toggle true borderless fullscreen.
  ///
  /// Uses WS_POPUP + DwmExtendFrameIntoClientArea(-1) for zero-border
  /// fullscreen, bypassing window_manager's setFullScreen which keeps
  /// WS_CAPTION and leaves a visible frame.
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
    if (isFullscreen.value) return;

    final hwnd = await windowManager.getId();

    // Save current style and frame for restoration.
    _savedStyle = _baseStyle ?? win32.getWindowLongPtr(hwnd, gwlStyle);
    final frame = calloc<Rect>();
    try {
      win32.getWindowRect(hwnd, frame);
      final saved = calloc<Rect>();
      saved.ref.left = frame.ref.left;
      saved.ref.top = frame.ref.top;
      saved.ref.right = frame.ref.right;
      saved.ref.bottom = frame.ref.bottom;
      _savedFrame = saved;
    } finally {
      calloc.free(frame);
    }

    // Set WS_POPUP — fully borderless, no DWM frame.
    win32.setWindowLongPtr(hwnd, gwlStyle, wsPopup);

    // Remove DWM shadow/border.
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

    // Get monitor bounds.
    final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
    final mi = calloc<MonitorInfo>();
    mi.ref.cbSize = sizeOf<MonitorInfo>();
    try {
      win32.getMonitorInfo(hMonitor, mi);

      // Position window to fill entire monitor.
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
  }

  Future<void> _exitFullscreen() async {
    if (!isFullscreen.value) return;

    final hwnd = await windowManager.getId();

    // Restore original style.
    if (_savedStyle != null) {
      win32.setWindowLongPtr(hwnd, gwlStyle, _savedStyle!);
    }

    // Restore original window frame.
    try {
      if (_savedFrame != null) {
        win32.setWindowPos(
          hwnd,
          0,
          _savedFrame!.ref.left,
          _savedFrame!.ref.top,
          _savedFrame!.ref.right - _savedFrame!.ref.left,
          _savedFrame!.ref.bottom - _savedFrame!.ref.top,
          swpNoOwnerZOrder | swpFrameChanged,
        );
      }
    } finally {
      if (_savedFrame != null) {
        calloc.free(_savedFrame!);
        _savedFrame = null;
      }
      _savedStyle = null;
    }

    if (isFullscreen.value) isFullscreen.value = false;
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    if (!_disposed) isAlwaysOnTop.value = value;
  }

  Future<void> setSize(double width, double height) =>
      windowManager.setSize(Size(width, height));

  Future<void> setMinSize(double width, double height) =>
      windowManager.setMinimumSize(Size(width, height));

  Future<void> minimize() => windowManager.minimize();

  /// 自定义最大化 — 使用 rcWork（工作区）而非全监视器。
  ///
  /// windowManager.maximize() 在无边框窗口上会覆盖任务栏，
  /// 因为插件的 adjustNCCALCSIZE 将客户区扩展到整个监视器。
  /// 此处直接用 GetMonitorInfoW 获取工作区矩形 + SetWindowPos 定位。
  Future<void> maximize() async {
    if (isMaximized.value) return;
    final hwnd = await windowManager.getId();

    // 保存当前窗口位置（用于 restore）
    final frame = calloc<Rect>();
    try {
      win32.getWindowRect(hwnd, frame);
      final saved = calloc<Rect>()
        ..ref.left = frame.ref.left
        ..ref.top = frame.ref.top
        ..ref.right = frame.ref.right
        ..ref.bottom = frame.ref.bottom;
      _savedMaximizeFrame = saved;
    } finally {
      calloc.free(frame);
    }

    // 获取工作区（排除任务栏）
    final hMonitor = win32.monitorFromWindow(hwnd, monitorDefaultToNearest);
    final mi = calloc<MonitorInfo>();
    mi.ref.cbSize = sizeOf<MonitorInfo>();
    try {
      win32.getMonitorInfo(hMonitor, mi);

      // 定位到工作区（不禁用 DWM 过渡，保留平滑动画）
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
  }

  /// 从自定义最大化恢复到之前的位置。
  Future<void> restore() async {
    if (!isMaximized.value || _savedMaximizeFrame == null) return;
    final hwnd = await windowManager.getId();

    try {
      // 恢复窗口位置（不禁用 DWM 过渡，保留平滑动画）
      win32.setWindowPos(
        hwnd,
        0,
        _savedMaximizeFrame!.ref.left,
        _savedMaximizeFrame!.ref.top,
        _savedMaximizeFrame!.ref.right - _savedMaximizeFrame!.ref.left,
        _savedMaximizeFrame!.ref.bottom - _savedMaximizeFrame!.ref.top,
        swpNoOwnerZOrder | swpFrameChanged,
      );
    } finally {
      calloc.free(_savedMaximizeFrame!);
      _savedMaximizeFrame = null;
    }

    if (isMaximized.value) isMaximized.value = false;
  }

  Future<void> close() => windowManager.close();

  Future<void> center() => windowManager.center();

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
