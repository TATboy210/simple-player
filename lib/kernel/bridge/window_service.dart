import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

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

const _gwlStyle = -16;
const _wsThickFrame = 0x00040000;
const _wsCaption = 0x00C00000;
const _wsPopup = 0x80000000;
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

  /// 移除窗口非客户区边框（WS_THICKFRAME + WS_CAPTION + DWM 阴影）。
  ///
  /// TitleBarStyle.hidden 只移除了标题栏，但保留了 WS_THICKFRAME
  /// 用于窗口缩放，导致窗口周围出现灰/白边。此方法将其彻底移除，
  /// 并通过 DwmExtendFrameIntoClientArea(-1) 消除 DWM 合成边框。
  Future<void> _removeBorder() async {
    final hwnd = await windowManager.getId();
    final style = _getWindowLongPtr(hwnd, _gwlStyle);
    final newStyle = style & ~_wsThickFrame & ~_wsCaption;
    _setWindowLongPtr(hwnd, _gwlStyle, newStyle);

    // 消除 DWM 窗口阴影和合成边框
    final margins = calloc<_Margins>()
      ..ref.left = -1
      ..ref.right = -1
      ..ref.top = -1
      ..ref.bottom = -1;
    _dwmExtendFrameIntoClientArea(hwnd, margins);
    calloc.free(margins);

    _setWindowPos(
      hwnd, 0, 0, 0, 0, 0,
      _swpNoOwnerZOrder | _swpFrameChanged | 0x0001 | 0x0002, // NOMOVE | NOSIZE
    );
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
      if (!_disposed) windowSize.value = size;
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
    _savedStyle = _getWindowLongPtr(hwnd, _gwlStyle);
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

  Future<void> maximize() => windowManager.maximize();

  Future<void> restore() => windowManager.restore();

  Future<void> close() => windowManager.close();

  Future<void> center() => windowManager.center();

  Future<void> startDragging() => windowManager.startDragging();

  void dispose() {
    _disposed = true;
    windowManager.removeListener(this);
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
