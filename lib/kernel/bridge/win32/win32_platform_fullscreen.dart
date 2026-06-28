/// Win32 平台全屏实现 — 直接 FFI 操作窗口样式，解决 WS_THICKFRAME 缝隙。
///
/// 从 win32_fullscreen.dart 重构为实例类，实现 PlatformFullscreen 接口。
/// FFI 函数查找保持 static final（DLL 句柄全局共享）。
library;
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';

import '../platform_fullscreen.dart';

// ─── Win32 常量 ───

const int _gwlStyle = -16;
const int _wsCaption = 0x00C00000;
const int _wsThickframe = 0x00040000;
const int _wsVisible = 0x10000000;
const int _hwndTop = 0;
const int _swpFrameChanged = 0x0020;
const int _swpNoZOrder = 0x0004;
const int _swpNoActivate = 0x0010;

// ─── Win32 函数签名 ───

typedef _FindWindowNative = IntPtr Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowDart = int Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);

typedef _GetWindowLongPtrNative = IntPtr Function(IntPtr hWnd, IntPtr nIndex);
typedef _GetWindowLongPtrDart = int Function(int hWnd, int nIndex);

typedef _SetWindowLongPtrNative = IntPtr Function(
    IntPtr hWnd, IntPtr nIndex, IntPtr dwNewLong);
typedef _SetWindowLongPtrDart = int Function(
    int hWnd, int nIndex, int dwNewLong);

typedef _SetWindowPosNative = Int32 Function(
    IntPtr hWnd,
    IntPtr hWndInsertAfter,
    Int32 X,
    Int32 Y,
    Int32 cx,
    Int32 cy,
    Uint32 uFlags);
typedef _SetWindowPosDart = int Function(
    int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);

typedef _GetMonitorInfoWNative = Int32 Function(
    IntPtr hMonitor, Pointer<MONITORINFO> lpmi);
typedef _GetMonitorInfoWDart = int Function(
    int hMonitor, Pointer<MONITORINFO> lpmi);

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;
  external RECT rcMonitor;
  external RECT rcWork;
  @Uint32()
  external int dwFlags;
}

const int _monitorDefaultToNearest = 2;

/// Win32 平台全屏 — 实现 PlatformFullscreen 接口。
///
/// 使用 Win32 FFI 直接操作窗口样式，绕过 window_manager 的
/// setFullScreen()（它不处理 WS_THICKFRAME，导致 7px 缝隙）。
class Win32PlatformFullscreen implements PlatformFullscreen {
  static final _user32 = DynamicLibrary.open('user32.dll');

  static final _findWindow = _user32
      .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');

  static final _getWindowLongPtr = _user32
      .lookupFunction<_GetWindowLongPtrNative, _GetWindowLongPtrDart>(
          'GetWindowLongPtrW');

  static final _setWindowLongPtr = _user32
      .lookupFunction<_SetWindowLongPtrNative, _SetWindowLongPtrDart>(
          'SetWindowLongPtrW');

  static final _setWindowPos = _user32
      .lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');

  static final _monitorFromWindow = _user32
      .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
          'MonitorFromWindow');

  static final _getMonitorInfoW = _user32
      .lookupFunction<_GetMonitorInfoWNative, _GetMonitorInfoWDart>(
          'GetMonitorInfoW');

  // ─── PlatformFullscreen 接口 ───

  @override
  bool get requiresStyleSave => true;

  @override
  Future<FullscreenSnapshot> enter() {
    final hwnd = _getHwnd();

    // 保存当前窗口样式（修改前）
    final style = _getWindowLongPtr(hwnd, _gwlStyle);

    // 去掉标题栏和不可见拖拽边框
    _setWindowLongPtr(
        hwnd, _gwlStyle, (style & ~_wsCaption & ~_wsThickframe) | _wsVisible);

    // 获取当前显示器尺寸并铺满（支持多显示器）
    final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
    final mi = calloc<MONITORINFO>();
    try {
      mi.ref.cbSize = sizeOf<MONITORINFO>();
      _getMonitorInfoW(monitor, mi);
      final rc = mi.ref.rcMonitor;
      final screenW = rc.right - rc.left;
      final screenH = rc.bottom - rc.top;
      _setWindowPos(hwnd, _hwndTop, rc.left, rc.top, screenW, screenH,
          _swpFrameChanged | _swpNoZOrder | _swpNoActivate);
    } finally {
      calloc.free(mi);
    }

    // 返回快照（位置/大小由 FullscreenController 通过 WindowOps 保存）
    return Future.value(FullscreenSnapshot(
      windowStyle: style,
      position: Offset.zero,
      size: Size.zero,
    ));
  }

  @override
  void exit(FullscreenSnapshot snapshot) {
    final hwnd = _getHwnd();

    // 1. 先恢复窗口样式（WS_THICKFRAME/WS_CAPTION），再设置位置大小。
    //    反序会导致 SetWindowPos 使用全屏样式计算布局，恢复样式后窗口偏移。
    _setWindowLongPtr(hwnd, _gwlStyle, snapshot.windowStyle);

    // 2. 恢复位置和大小 + SWP_FRAMECHANGED 触发 WM_NCCALCSIZE 重算帧区域
    _setWindowPos(
        hwnd,
        _hwndTop,
        snapshot.position.dx.toInt(),
        snapshot.position.dy.toInt(),
        snapshot.size.width.toInt(),
        snapshot.size.height.toInt(),
        _swpFrameChanged | _swpNoZOrder | _swpNoActivate);
  }

  // ─── 工具方法 ───

  /// 获取 Flutter 窗口的 HWND（通过窗口类名查找）。
  static int _getHwnd() {
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      return _findWindow(className, nullptr);
    } finally {
      calloc.free(className);
    }
  }

  /// 读取当前窗口样式（供测试和诊断用）。
  static int getWindowStyle([int? hwnd]) {
    return _getWindowLongPtr(hwnd ?? _getHwnd(), _gwlStyle);
  }
}
