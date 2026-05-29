import 'dart:async';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';

/// Win32 API bindings for fullscreen management.
final _user32 = DynamicLibrary.open('user32.dll');

typedef _GetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr);
typedef _GetWindowLongPtrDart = int Function(int, int);
typedef _SetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr, IntPtr);
typedef _SetWindowLongPtrDart = int Function(int, int, int);
typedef _SetWindowPosNative = Int32 Function(
    IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32);
typedef _SetWindowPosDart = int Function(
    int, int, int, int, int, int, int);
typedef _MonitorFromWindowNative = IntPtr Function(IntPtr, Uint32);
typedef _MonitorFromWindowDart = int Function(int, int);
typedef _GetMonitorInfoNative = Int32 Function(IntPtr, Pointer);
typedef _GetMonitorInfoDart = int Function(int, Pointer);
typedef _GetWindowRectNative = Int32 Function(IntPtr, Pointer<_Rect>);
typedef _GetWindowRectDart = int Function(int, Pointer<_Rect>);

final _getWindowLongPtr = _user32
    .lookupFunction<_GetWindowLongPtrNative, _GetWindowLongPtrDart>(
        'GetWindowLongPtrW');
final _setWindowLongPtr = _user32
    .lookupFunction<_SetWindowLongPtrNative, _SetWindowLongPtrDart>(
        'SetWindowLongPtrW');
final _setWindowPos = _user32
    .lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');
final _monitorFromWindow = _user32
    .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
        'MonitorFromWindow');
final _getMonitorInfo = _user32
    .lookupFunction<_GetMonitorInfoNative, _GetMonitorInfoDart>(
        'GetMonitorInfoW');
final _getWindowRect = _user32
    .lookupFunction<_GetWindowRectNative, _GetWindowRectDart>(
        'GetWindowRect');

final _dwmapi = DynamicLibrary.open('dwmapi.dll');

typedef _DwmExtendFrameIntoClientAreaNative = Int32 Function(
    IntPtr, Pointer<_Margins>);
typedef _DwmExtendFrameIntoClientAreaDart = int Function(
    int, Pointer<_Margins>);

final _dwmExtendFrameIntoClientArea = _dwmapi.lookupFunction<
    _DwmExtendFrameIntoClientAreaNative,
    _DwmExtendFrameIntoClientAreaDart>('DwmExtendFrameIntoClientArea');

typedef _DwmSetWindowAttributeNative = Int32 Function(
    IntPtr, IntPtr, Pointer<Uint32>, Uint32);
typedef _DwmSetWindowAttributeDart = int Function(
    int, int, Pointer<Uint32>, int);

final _dwmSetWindowAttribute = _dwmapi.lookupFunction<
    _DwmSetWindowAttributeNative,
    _DwmSetWindowAttributeDart>('DwmSetWindowAttribute');

const _gwlStyle = -16;
const _wsCaption = 0x00C00000;
const _wsPopup = 0x80000000;
const _dwmwaTransitionsForcedisabled = 3;
const _hwndTop = 0;
const _swpNoOwnerZOrder = 0x0200;
const _swpFrameChanged = 0x0020;
const _monitorDefaultToNearest = 2;

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _Rect rcMonitor;
  external _Rect rcWork;
  @Uint32()
  external int dwFlags;
}

final class _Margins extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int right;
  @Int32()
  external int top;
  @Int32()
  external int bottom;
}

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
  Pointer<_Rect>? _savedFrame;
  int? _baseStyle;  // _removeBorder() 完成后的基准 style
  Timer? _resizeDebounce;

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

  /// 禁用/启用 DWM 过渡动画。
  ///
  /// 最大化/恢复时禁用动画，消除白边闪现和卡顿。
  /// PostMessage(SC_MAXIMIZE) 是异步的，发送后立即恢复设置即可。
  static Future<void> _setTransitionsDisabled(bool disabled) async {
    final hwnd = await windowManager.getId();
    final value = calloc<Uint32>()..value = disabled ? 1 : 0;
    _dwmSetWindowAttribute(
        hwnd, _dwmwaTransitionsForcedisabled, value, sizeOf<Uint32>());
    calloc.free(value);
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
    final style = _getWindowLongPtr(hwnd, _gwlStyle);
    // 只移除 WS_CAPTION，保留 WS_THICKFRAME 用于原生缩放
    final newStyle = style & ~_wsCaption;
    _setWindowLongPtr(hwnd, _gwlStyle, newStyle);

    // 保留 DWM 阴影：顶部 1px frame 让 DWM 认为窗口有边框
    final margins = calloc<_Margins>()
      ..ref.left = 0
      ..ref.right = 0
      ..ref.top = 1
      ..ref.bottom = 0;
    _dwmExtendFrameIntoClientArea(hwnd, margins);
    calloc.free(margins);

    _setWindowPos(
      hwnd, 0, 0, 0, 0, 0,
      _swpNoOwnerZOrder | _swpFrameChanged | 0x0001 | 0x0002, // NOMOVE | NOSIZE
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

  // ─── Commands (delegate to windowManager) ───

  /// Toggle true borderless fullscreen.
  ///
  /// Uses WS_POPUP + DwmExtendFrameIntoClientArea(-1) for zero-border
  /// fullscreen, bypassing window_manager's setFullScreen which keeps
  /// WS_CAPTION and leaves a visible frame.
  Future<void> setFullscreen(bool value) async {
    if (_fullscreenTransitioning) return;
    _fullscreenTransitioning = true;
    try {
      if (value) {
        await _enterFullscreen();
      } else {
        await _exitFullscreen();
      }
    } finally {
      _fullscreenTransitioning = false;
    }
  }

  Future<void> _enterFullscreen() async {
    if (isFullscreen.value) return;

    final hwnd = await windowManager.getId();

    // Save current style and frame for restoration.
    _savedStyle = _baseStyle ?? _getWindowLongPtr(hwnd, _gwlStyle);
    final frame = calloc<_Rect>();
    _getWindowRect(hwnd, frame);
    final saved = calloc<_Rect>();
    saved.ref.left = frame.ref.left;
    saved.ref.top = frame.ref.top;
    saved.ref.right = frame.ref.right;
    saved.ref.bottom = frame.ref.bottom;
    _savedFrame = saved;
    calloc.free(frame);

    // Set WS_POPUP — fully borderless, no DWM frame.
    _setWindowLongPtr(hwnd, _gwlStyle, _wsPopup);

    // Remove DWM shadow/border.
    final margins = calloc<_Margins>()
      ..ref.left = -1
      ..ref.right = -1
      ..ref.top = -1
      ..ref.bottom = -1;
    _dwmExtendFrameIntoClientArea(hwnd, margins);
    calloc.free(margins);

    // Get monitor bounds.
    final hMonitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
    final mi = calloc<_MonitorInfo>();
    mi.ref.cbSize = sizeOf<_MonitorInfo>();
    _getMonitorInfo(hMonitor, mi);

    // Position window to fill entire monitor.
    _setWindowPos(
      hwnd,
      _hwndTop,
      mi.ref.rcMonitor.left,
      mi.ref.rcMonitor.top,
      mi.ref.rcMonitor.right - mi.ref.rcMonitor.left,
      mi.ref.rcMonitor.bottom - mi.ref.rcMonitor.top,
      _swpNoOwnerZOrder | _swpFrameChanged,
    );
    calloc.free(mi);

    if (!isFullscreen.value) isFullscreen.value = true;
  }

  Future<void> _exitFullscreen() async {
    if (!isFullscreen.value) return;

    final hwnd = await windowManager.getId();

    // Restore original style.
    _setWindowLongPtr(hwnd, _gwlStyle, _savedStyle!);

    // Restore original window frame.
    if (_savedFrame != null) {
      _setWindowPos(
        hwnd,
        0,
        _savedFrame!.ref.left,
        _savedFrame!.ref.top,
        _savedFrame!.ref.right - _savedFrame!.ref.left,
        _savedFrame!.ref.bottom - _savedFrame!.ref.top,
        _swpNoOwnerZOrder | _swpFrameChanged,
      );
      calloc.free(_savedFrame!);
    }

    _savedStyle = null;
    _savedFrame = null;
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

  Future<void> maximize() async {
    await _setTransitionsDisabled(true);
    await windowManager.maximize();
    await _setTransitionsDisabled(false);
  }

  Future<void> restore() async {
    await _setTransitionsDisabled(true);
    await windowManager.restore();
    await _setTransitionsDisabled(false);
  }

  Future<void> close() => windowManager.close();

  Future<void> center() => windowManager.center();

  Future<void> startDragging() => windowManager.startDragging();

  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    windowManager.removeListener(this);
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
