// Win32 fullscreen FFI bindings — direct user32.dll calls.
//
// Provides all Win32 API functions needed for WindowsFullscreenDriver:
// window style manipulation (WS_THICKFRAME removal), window positioning,
// focus recovery, TopMost cleanup, and monitor info queries.
//
// Architecture:
// - Win32FullscreenApi: static utility class (direct FFI calls)
//   Each method wraps a single Win32 API with try-catch and safe defaults.
//
// Pattern reference: win32_display_enumerator.dart
// Decision reference: D-P05 (reuse FFI pattern), D-P06 (WS_THICKFRAME),
//   D-P07 (focus recovery), D-P08 (TopMost cleanup)

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../utils/log.dart';

// ─── Win32 结构体 ───

/// Win32 RECT — 矩形区域 (left, top, right, bottom)。
final class Win32Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

/// Win32 POINT — 二维坐标点。
final class Win32Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

/// Win32 WINDOWPLACEMENT — 窗口位置和状态快照。
///
/// 用于保存/恢复窗口在进入全屏前的位置。
/// length 字段必须在使用前设置为 sizeof(WINDOWPLACEMENT)。
final class WindowPlacement extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int flags;
  @Uint32()
  external int showCmd;
  external Win32Point ptMinPosition;
  external Win32Point ptMaxPosition;
  external Win32Rect rcNormalPosition;
}

/// Win32 MONITORINFO — 显示器几何信息。
final class MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external Win32Rect rcMonitor;
  external Win32Rect rcWork;
  @Uint32()
  external int dwFlags;
}

// ─── Win32 函数签名 (Native / Dart 对) ───

// GetWindowLongW / SetWindowLongW — 窗口样式读写
typedef _GetWindowLongNative = Int32 Function(IntPtr hWnd, Int32 nIndex);
typedef _GetWindowLongDart = int Function(int hWnd, int nIndex);

typedef _SetWindowLongNative = Int32 Function(
    IntPtr hWnd, Int32 nIndex, Int32 dwNewLong);
typedef _SetWindowLongDart = int Function(
    int hWnd, int nIndex, int dwNewLong);

// SetWindowPos — 窗口位置/尺寸/Z-order
typedef _SetWindowPosNative = Int32 Function(IntPtr hWnd, IntPtr hWndInsertAfter,
    Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef _SetWindowPosDart = int Function(
    int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

// SetForegroundWindow / SetFocus — 焦点恢复 (D-P07)
typedef _SetForegroundWindowNative = Int32 Function(IntPtr hWnd);
typedef _SetForegroundWindowDart = int Function(int hWnd);

typedef _SetFocusNative = IntPtr Function(IntPtr hWnd);
typedef _SetFocusDart = int Function(int hWnd);

// 状态查询
typedef _IsWindowVisibleNative = Int32 Function(IntPtr hWnd);
typedef _IsWindowVisibleDart = int Function(int hWnd);

typedef _IsIconicNative = Int32 Function(IntPtr hWnd);
typedef _IsIconicDart = int Function(int hWnd);

typedef _IsWindowNative = Int32 Function(IntPtr hWnd);
typedef _IsWindowDart = int Function(int hWnd);

typedef _IsZoomedNative = Int32 Function(IntPtr hWnd);
typedef _IsZoomedDart = int Function(int hWnd);

// 显示器信息
typedef _MonitorFromWindowNative = IntPtr Function(IntPtr hwnd, Uint32 dwFlags);
typedef _MonitorFromWindowDart = int Function(int hwnd, int dwFlags);

typedef _GetMonitorInfoWNative = Int32 Function(
    IntPtr hMonitor, Pointer<MonitorInfo> lpmi);
typedef _GetMonitorInfoWDart = int Function(
    int hMonitor, Pointer<MonitorInfo> lpmi);

// 窗口位置保存/恢复
typedef _GetWindowPlacementNative = Int32 Function(
    IntPtr hWnd, Pointer<WindowPlacement> lpwndpl);
typedef _GetWindowPlacementDart = int Function(
    int hWnd, Pointer<WindowPlacement> lpwndpl);

typedef _SetWindowPlacementNative = Int32 Function(
    IntPtr hWnd, Pointer<WindowPlacement> lpwndpl);
typedef _SetWindowPlacementDart = int Function(
    int hWnd, Pointer<WindowPlacement> lpwndpl);

// FindWindowW — 查找 Flutter 窗口 HWND
typedef _FindWindowNative = IntPtr Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowDart = int Function(
    Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);

// ShowWindow — 最大化/恢复
typedef _ShowWindowNative = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef _ShowWindowDart = int Function(int hWnd, int nCmdShow);

// GetWindowRect — 获取窗口屏幕坐标
typedef _GetWindowRectNative = Int32 Function(
    IntPtr hWnd, Pointer<Win32Rect> lpRect);
typedef _GetWindowRectDart = int Function(
    int hWnd, Pointer<Win32Rect> lpRect);

// ─── Win32 常量 (公开 — 供 WindowsFullscreenDriver 使用) ───

// 窗口样式索引
const int gwlStyle = -16;
const int gwlExStyle = -20;

// 窗口样式标志
// D-P06: WS_THICKFRAME 剥离解决 7px 缝隙
const int wsCaption = 0x00C00000;
const int wsThickframe = 0x00040000;
const int wsMaximize = 0x01000000;

// 扩展窗口样式
const int wsExTopmost = 0x00000008;
const int wsExDlgmodalframe = 0x00000001;
const int wsExWindowedge = 0x00000100;
const int wsExClientedge = 0x00000200;
const int wsExStaticedge = 0x00020000;

// SetWindowPos Z-order 句柄
// D-P08: HWND_NOTOPMOST 用于清理 TopMost 残留
const int hwndTopmost = -1;
const int hwndNotopmost = -2;

// SetWindowPos 标志
const int swpNosize = 0x0001;
const int swpNomove = 0x0002;
const int swpNozorder = 0x0004;
const int swpNoactivate = 0x0010;
const int swpFramechanged = 0x0020;
const int swpNoownerzorder = 0x0200;

// ShowWindow 命令
const int swMaximize = 3;
const int swRestore = 9;

// MonitorFromWindow 标志
const int monitorDefaultToNearest = 2;

// ─── DLL 加载 ───

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

// ─── 函数查找 ───

final _GetWindowLongDart _getWindowLong = _user32
    .lookupFunction<_GetWindowLongNative, _GetWindowLongDart>('GetWindowLongW');

final _SetWindowLongDart _setWindowLong = _user32
    .lookupFunction<_SetWindowLongNative, _SetWindowLongDart>('SetWindowLongW');

final _SetWindowPosDart _setWindowPos = _user32
    .lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');

final _SetForegroundWindowDart _setForegroundWindow = _user32
    .lookupFunction<_SetForegroundWindowNative, _SetForegroundWindowDart>(
        'SetForegroundWindow');

final _SetFocusDart _setFocus = _user32
    .lookupFunction<_SetFocusNative, _SetFocusDart>('SetFocus');

final _IsWindowVisibleDart _isWindowVisible = _user32
    .lookupFunction<_IsWindowVisibleNative, _IsWindowVisibleDart>(
        'IsWindowVisible');

final _IsIconicDart _isIconic = _user32
    .lookupFunction<_IsIconicNative, _IsIconicDart>('IsIconic');

final _IsWindowDart _isWindow = _user32
    .lookupFunction<_IsWindowNative, _IsWindowDart>('IsWindow');

final _IsZoomedDart _isZoomed = _user32
    .lookupFunction<_IsZoomedNative, _IsZoomedDart>('IsZoomed');

final _MonitorFromWindowDart _monitorFromWindow = _user32
    .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
        'MonitorFromWindow');

final _GetMonitorInfoWDart _getMonitorInfoW = _user32
    .lookupFunction<_GetMonitorInfoWNative, _GetMonitorInfoWDart>(
        'GetMonitorInfoW');

final _GetWindowPlacementDart _getWindowPlacement = _user32
    .lookupFunction<_GetWindowPlacementNative, _GetWindowPlacementDart>(
        'GetWindowPlacement');

final _SetWindowPlacementDart _setWindowPlacement = _user32
    .lookupFunction<_SetWindowPlacementNative, _SetWindowPlacementDart>(
        'SetWindowPlacement');

final _FindWindowDart _findWindow = _user32
    .lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');

final _ShowWindowDart _showWindow = _user32
    .lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow');

final _GetWindowRectDart _getWindowRect = _user32
    .lookupFunction<_GetWindowRectNative, _GetWindowRectDart>('GetWindowRect');

// ─── Win32FullscreenApi 静态工具类 ───

/// Win32 全屏操作 API — 静态工具类。
///
/// 封装所有 user32.dll FFI 调用，每个方法内部 try-catch，
/// 失败时通过 logBridge 记录错误并返回安全默认值。
///
/// 使用模式:
/// ```dart
/// final hwnd = Win32FullscreenApi.getFlutterHwnd();
/// if (hwnd == 0) return;
/// Win32FullscreenApi.setWindowLong(hwnd, gwlStyle, newStyle);
/// ```
class Win32FullscreenApi {
  Win32FullscreenApi._();

  // ─── 窗口句柄 ───

  /// 查找 Flutter 窗口 HWND。
  ///
  /// Flutter 窗口类名固定为 FLUTTER_RUNNER_WIN32_WINDOW。
  /// 返回 0 表示未找到。
  static int getFlutterHwnd() {
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    try {
      return _findWindow(className, nullptr);
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.getFlutterHwnd] $e');
      return 0;
    } finally {
      calloc.free(className);
    }
  }

  // ─── 窗口样式操作 ───

  /// 读取窗口样式 (GWL_STYLE) 或扩展样式 (GWL_EXSTYLE)。
  ///
  /// [index] 使用 gwlStyle (-16) 或 gwlExStyle (-20)。
  /// 失败时返回 0。
  static int getWindowLong(int hwnd, int index) {
    try {
      return _getWindowLong(hwnd, index);
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.getWindowLong] $e');
      return 0;
    }
  }

  /// 设置窗口样式或扩展样式。
  ///
  /// 返回先前的样式值。失败时返回 0。
  static int setWindowLong(int hwnd, int index, int value) {
    try {
      return _setWindowLong(hwnd, index, value);
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.setWindowLong] $e');
      return 0;
    }
  }

  // ─── 窗口位置 ───

  /// 设置窗口位置、尺寸和 Z-order。
  ///
  /// 失败时返回 false。
  static bool setWindowPos(
    int hwnd,
    int insertAfter,
    int x,
    int y,
    int cx,
    int cy,
    int flags,
  ) {
    try {
      return _setWindowPos(hwnd, insertAfter, x, y, cx, cy, flags) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.setWindowPos] $e');
      return false;
    }
  }

  /// 获取窗口屏幕坐标矩形。
  ///
  /// 返回 null 表示失败 (HWND 无效或 API 调用异常)。
  static ({int left, int top, int right, int bottom})? getWindowRect(int hwnd) {
    final rect = calloc<Win32Rect>();
    try {
      final result = _getWindowRect(hwnd, rect);
      if (result == 0) return null;
      return (
        left: rect.ref.left,
        top: rect.ref.top,
        right: rect.ref.right,
        bottom: rect.ref.bottom,
      );
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.getWindowRect] $e');
      return null;
    } finally {
      calloc.free(rect);
    }
  }

  // ─── 焦点恢复 (D-P07) ───

  /// 将窗口设为前台窗口。
  ///
  /// Windows 限制前台窗口切换频率，失败只报日志，不循环重试。
  static bool setForegroundWindow(int hwnd) {
    try {
      return _setForegroundWindow(hwnd) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.setForegroundWindow] $e');
      return false;
    }
  }

  /// 设置键盘焦点到指定窗口。
  static int setFocus(int hwnd) {
    try {
      return _setFocus(hwnd);
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.setFocus] $e');
      return 0;
    }
  }

  // ─── 状态查询 ───

  /// 检查 HWND 是否有效。
  static bool isWindow(int hwnd) {
    try {
      return _isWindow(hwnd) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.isWindow] $e');
      return false;
    }
  }

  /// 检查窗口是否可见。
  static bool isWindowVisible(int hwnd) {
    try {
      return _isWindowVisible(hwnd) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.isWindowVisible] $e');
      return false;
    }
  }

  /// 检查窗口是否最小化 (iconic)。
  static bool isIconic(int hwnd) {
    try {
      return _isIconic(hwnd) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.isIconic] $e');
      return false;
    }
  }

  /// 检查窗口是否最大化 (zoomed)。
  ///
  /// 全屏后 IsZoomed 返回 true，用于 queryFullscreen 的真实状态查询。
  static bool isZoomed(int hwnd) {
    try {
      return _isZoomed(hwnd) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.isZoomed] $e');
      return false;
    }
  }

  // ─── 显示器信息 ───

  /// 获取窗口所在显示器的句柄。
  ///
  /// [hwnd] 窗口句柄。
  /// 失败时返回 0。
  static int monitorFromWindow(int hwnd) {
    try {
      return _monitorFromWindow(hwnd, monitorDefaultToNearest);
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.monitorFromWindow] $e');
      return 0;
    }
  }

  /// 获取显示器的物理像素矩形区域。
  ///
  /// 返回 null 表示失败。
  static ({int left, int top, int right, int bottom})? getMonitorRect(
      int hMonitor) {
    final mi = calloc<MonitorInfo>();
    try {
      mi.ref.cbSize = sizeOf<MonitorInfo>();
      final result = _getMonitorInfoW(hMonitor, mi);
      if (result == 0) return null;
      return (
        left: mi.ref.rcMonitor.left,
        top: mi.ref.rcMonitor.top,
        right: mi.ref.rcMonitor.right,
        bottom: mi.ref.rcMonitor.bottom,
      );
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.getMonitorRect] $e');
      return null;
    } finally {
      calloc.free(mi);
    }
  }

  // ─── 窗口位置保存/恢复 ───

  /// 保存窗口位置到 WINDOWPLACEMENT 结构。
  ///
  /// 返回已分配的指针，调用方负责在 finally 中 free。
  /// 返回 null 表示失败。
  static Pointer<WindowPlacement>? getWindowPlacement(int hwnd) {
    final placement = calloc<WindowPlacement>();
    try {
      placement.ref.length = sizeOf<WindowPlacement>();
      final result = _getWindowPlacement(hwnd, placement);
      if (result == 0) {
        calloc.free(placement);
        return null;
      }
      return placement;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.getWindowPlacement] $e');
      calloc.free(placement);
      return null;
    }
  }

  /// 恢复窗口到保存的 WINDOWPLACEMENT 位置。
  ///
  /// 失败时返回 false。调用方负责 free [placement] 指针。
  static bool setWindowPlacement(int hwnd, Pointer<WindowPlacement> placement) {
    try {
      return _setWindowPlacement(hwnd, placement) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.setWindowPlacement] $e');
      return false;
    }
  }

  // ─── ShowWindow ───

  /// 最大化窗口。
  static bool maximizeWindow(int hwnd) {
    try {
      return _showWindow(hwnd, swMaximize) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.maximizeWindow] $e');
      return false;
    }
  }

  /// 恢复窗口 (从最大化/最小化恢复)。
  static bool restoreWindow(int hwnd) {
    try {
      return _showWindow(hwnd, swRestore) != 0;
    } catch (e) {
      logBridge.e('[Win32FullscreenApi.restoreWindow] $e');
      return false;
    }
  }
}
