import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../diagnostics/kernel_logger.dart';

final _log = KernelLogger.I;

/// Win32 原生全屏 FFI 桥 — 方案 A 的物理执行者。
///
/// [media_kit_video] 的 utils.cc 退出全屏时以 `style | WS_OVERLAPPEDWINDOW`
/// 恢复"标准窗口假设"，会把 window_manager hidden/frameless 样式位漂移回
/// 标准位（双头样式管理）；本桥以**进入时的精确快照**还原样式与矩形，是
/// 唯一的窗口样式权威。
///
/// 序列（与 utils.cc 同构，差异仅在退出还原语义）：
/// - enter：快照 (style, rect, maximized) → 摘 WS_OVERLAPPEDWINDOW →
///   SetWindowPos 铺满目标显示器（SWP_FRAMECHANGED）
/// - exit：还原快照样式（不加任何假设位）→ 还原矩形 → 之前最大化则
///   PostMessage(SC_MAXIMIZE) 恢复
///
/// 所有 Win32 调用包裹在 try/catch，失败仅记录日志并 no-op — 物理层故障
/// 绝不炸掉语义层（WindowMode 状态机）。
final class NativeFullscreenBridge {
  NativeFullscreenBridge({
    DynamicLibrary? user32,
    String windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW',
  }) : _user32 = user32,
       _windowClassName = windowClassName;

  final DynamicLibrary? _user32;
  final String _windowClassName;

  // ── 延迟解析的函数指针（user32 不可用时保持 null → 全部 no-op）──
  late final _findWindow = _user32
      ?.lookupFunction<
        IntPtr Function(Pointer<Uint16>, Pointer<Uint16>),
        int Function(Pointer<Uint16>, Pointer<Uint16>)
      >('FindWindowW');

  // ── 快照 ──
  int? _savedStyle;
  int? _savedLeft;
  int? _savedTop;
  int? _savedWidth;
  int? _savedHeight;
  bool _savedMaximized = false;

  /// 当前是否处于本桥管理的原生全屏。
  bool get isNativeFullscreenActive => _savedStyle != null;

  static const int _gwlStyle = -16;

  /// WS_OVERLAPPEDWINDOW = CAPTION|SYSMENU|THICKFRAME|MINIMIZEBOX|MAXIMIZEBOX
  static const int _wsOverlappedWindow = 0x00CF0000;

  static const int _swpNosize = 0x0001;
  static const int _swpNomove = 0x0002;
  static const int _swpNoZorder = 0x0004;
  static const int _swpNoActivate = 0x0010;
  static const int _swpFrameChanged = 0x0020;

  static const int _monitorDefaultToNearest = 2;
  static const int _wmSyscommand = 0x0112;
  static const int _scMaximize = 0xF030;

  /// 进入原生全屏：快照 → 摘样式 → 铺满主显示器。
  void enter() {
    if (kIsWeb) return;
    final user32 = _user32;
    if (user32 == null) return;
    try {
      final hwnd = _resolveHwnd();
      if (hwnd == 0) {
        _log.w('[NativeFullscreenBridge] main window not found; skip enter');
        return;
      }
      if (_savedStyle != null) return; // 已处于全屏，防重入

      final getWindowRect = user32
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<_Rect>),
            int Function(int, Pointer<_Rect>)
          >('GetWindowRect');
      final isZoomed = user32
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'IsZoomed',
          );
      final getWindowLongPtr = user32
          .lookupFunction<
            IntPtr Function(IntPtr, Int32),
            int Function(int, int)
          >('GetWindowLongPtrW');

      final rect = malloc<_Rect>();
      final style = getWindowLongPtr(hwnd, _gwlStyle);
      var gotRect = false;
      try {
        gotRect = getWindowRect(hwnd, rect) != 0;
        _savedStyle = style;
        _savedMaximized = isZoomed(hwnd) != 0;
        if (gotRect) {
          _savedLeft = rect.ref.left;
          _savedTop = rect.ref.top;
          _savedWidth = rect.ref.right - rect.ref.left;
          _savedHeight = rect.ref.bottom - rect.ref.top;
        }
      } finally {
        malloc.free(rect);
      }

      // 摘除标准窗口样式 — 与 utils.cc 相同的位操作；差异在退出还原语义。
      setStyle(hwnd, style & ~_wsOverlappedWindow);
      _stretchToMonitor(user32, hwnd);
      _log.d(
        '[NativeFullscreenBridge] enter (maximizedBefore=$_savedMaximized)',
      );
    } on Object catch (error) {
      _log.w('[NativeFullscreenBridge] enter failed: $error');
    }
  }

  /// 退出原生全屏：按快照精确还原样式与矩形；未处于全屏时 no-op。
  void exit() {
    if (kIsWeb) return;
    final user32 = _user32;
    if (user32 == null) return;
    final style = _savedStyle;
    if (style == null) return; // 未处于全屏
    try {
      final hwnd = _resolveHwnd();
      if (hwnd == 0) {
        _log.w('[NativeFullscreenBridge] main window not found; skip exit');
        _clearSnapshot();
        return;
      }

      // 精确还原 — 关键差异：utils.cc 用 style | WS_OVERLAPPEDWINDOW 套回
      // "标准窗口假设"，会覆盖 window_manager hidden/frameless 样式；这里
      // 只还原进入时快照到的真实样式，双头管理终结。
      setStyle(hwnd, style);
      final left = _savedLeft;
      final top = _savedTop;
      final width = _savedWidth;
      final height = _savedHeight;
      if (left != null && top != null && width != null && height != null) {
        final setWindowPos = user32
            .lookupFunction<
              Int32 Function(
                IntPtr,
                IntPtr,
                Int32,
                Int32,
                Int32,
                Int32,
                Uint32,
              ),
              int Function(int, int, int, int, int, int, int)
            >('SetWindowPos');
        setWindowPos(
          hwnd,
          nullptr.address, // HWND_TOP? 0 即 TOP — 与 enter 的铺满序列一致
          left,
          top,
          width,
          height,
          _swpNoZorder | _swpNoActivate | _swpFrameChanged,
        );
      }
      if (_savedMaximized) {
        // 之前处于最大化 — 以系统命令恢复（window_manager 同款手法）。
        final postMessage = user32
            .lookupFunction<
              Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
              int Function(int, int, int, int)
            >('PostMessageW');
        postMessage(hwnd, _wmSyscommand, _scMaximize, 0);
      }
      _clearSnapshot();
      _log.d(
        '[NativeFullscreenBridge] exit (maximizedBefore=$_savedMaximized)',
      );
    } on Object catch (error) {
      _log.w('[NativeFullscreenBridge] exit failed: $error');
      // 失败也清快照 — 避免 isNativeFullscreenActive 卡死导致后续 no-op。
      _clearSnapshot();
    }
  }

  /// 将窗口样式更新为 [style] 并触发框架重算。
  void setStyle(int hwnd, int style) {
    final user32 = _user32;
    if (user32 == null) return;
    final setWindowLongPtr = user32
        .lookupFunction<
          IntPtr Function(IntPtr, Int32, IntPtr),
          int Function(int, int, int)
        >('SetWindowLongPtrW');
    setWindowLongPtr(hwnd, _gwlStyle, style);
    final setWindowPos = user32
        .lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)
        >('SetWindowPos');
    setWindowPos(
      hwnd,
      nullptr.address,
      0,
      0,
      0,
      0,
      _swpNoZorder |
          _swpNoActivate |
          _swpNomove |
          _swpNosize |
          _swpFrameChanged,
    );
  }

  /// 铺满 [hwnd] 所在显示器（客户区=窗口矩形，frameless 无边框视觉）。
  void _stretchToMonitor(DynamicLibrary user32, int hwnd) {
    final monitorFromWindow = user32
        .lookupFunction<
          IntPtr Function(IntPtr, Uint32),
          int Function(int, int)
        >('MonitorFromWindow');
    final getMonitorInfo = user32
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<_MonitorInfo>),
          int Function(int, Pointer<_MonitorInfo>)
        >('GetMonitorInfoW');
    final setWindowPos = user32
        .lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)
        >('SetWindowPos');

    final monitor = monitorFromWindow(hwnd, _monitorDefaultToNearest);
    if (monitor == 0) return;
    final info = malloc<_MonitorInfo>();
    try {
      info.ref.cbSize = sizeOf<_MonitorInfo>();
      if (getMonitorInfo(monitor, info) == 0) return;
      setWindowPos(
        hwnd,
        nullptr.address,
        info.ref.rcMonitor.left,
        info.ref.rcMonitor.top,
        info.ref.rcMonitor.right - info.ref.rcMonitor.left,
        info.ref.rcMonitor.bottom - info.ref.rcMonitor.top,
        _swpNoZorder | _swpNoActivate | _swpFrameChanged,
      );
    } finally {
      malloc.free(info);
    }
  }

  /// 解析主窗口句柄 — runner 固定窗口类名（win32_window.cpp），一次缓存。
  int? _hwnd;
  int _resolveHwnd() {
    final cached = _hwnd;
    if (cached != null) return cached;
    final findWindow = _findWindow;
    if (findWindow == null) return 0;
    final className = _toUtf16(_windowClassName);
    try {
      _hwnd = findWindow(className, nullptr);
    } finally {
      malloc.free(className);
    }
    return _hwnd ?? 0;
  }

  void _clearSnapshot() {
    _savedStyle = null;
    _savedLeft = null;
    _savedTop = null;
    _savedWidth = null;
    _savedHeight = null;
    _savedMaximized = false;
  }

  /// 分配以 NUL 结尾的 UTF-16 缓冲（调用方负责 malloc.free）。
  Pointer<Uint16> _toUtf16(String value) {
    final units = value.codeUnits;
    final pointer = malloc<Uint16>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      pointer[i] = units[i];
    }
    pointer[units.length] = 0;
    return pointer;
  }
}

/// Win32 RECT — 与 winuser.h 布局一致。
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

/// Win32 MONITORINFO — 与 winuser.h 布局一致。
final class _MonitorInfo extends Struct {
  @Int32()
  external int cbSize;
  external _Rect rcMonitor;
  external _Rect rcWork;
  @Uint32()
  external int dwFlags;
}
