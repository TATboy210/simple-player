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

const _gwlStyle = -16;
const _wsCaption = 0x00C00000;
const _wsThickframe = 0x00040000;
const _wsMaximizebox = 0x00010000;
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
  /// window_manager's setFullScreen only removes WS_THICKFRAME and
  /// WS_MAXIMIZEBOX but keeps WS_CAPTION, resulting in a maximized look.
  /// We fix this by also removing WS_CAPTION via Win32 FFI and positioning
  /// the window to cover the full monitor.
  Future<void> setFullscreen(bool value) async {
    if (value) {
      await _enterFullscreen();
    } else {
      await _exitFullscreen();
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

    // Remove WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZEBOX.
    _setWindowLongPtr(
      hwnd,
      _gwlStyle,
      _savedStyle! & ~(_wsCaption | _wsThickframe | _wsMaximizebox),
    );

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

    // Restore original style (includes WS_CAPTION).
    _setWindowLongPtr(
      hwnd,
      _gwlStyle,
      _savedStyle! | _wsThickframe | _wsMaximizebox,
    );

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

  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);

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
