/// Win32 原生全屏桥 — 移植 media_kit_video 2.0.1 `windows/utils.cc` 的
/// EnterNativeFullscreen / ExitNativeFullscreen.
///
/// Native fullscreen for the runner window: strip `WS_OVERLAPPEDWINDOW` and
/// cover the nearest monitor; on exit restore the style and either refresh
/// a maximized window or restore the pre-fullscreen normal rect.
///
/// window_frame_kit 协同 (2026-10): customFrame 的 FrameController 把
/// "WS_OVERLAPPEDWINDOW 全部摘除" 识别为外部全屏 (IsExternalFullscreenStyle
/// → 无 frame 客户区映射/无缩放带/屏蔽 SC_SIZE), 故原 runner 的
/// fullscreen_resize_guard 已删除。与 media_kit 原实现唯一的偏差: 退出时
/// 只恢复**进入前实际拥有**的 WS_OVERLAPPEDWINDOW 位, 而非整组 OR 回去 —
/// frame 启用期间窗口刻意不带 WS_CAPTION (否则 Win10 缩放循环重绘主题色
/// 标题栏), 整组恢复会把它加回来。DWM 边距/圆角由 frame 自管, 本桥不触碰.
///
/// 常量逐一核对 Windows SDK 10.0.26100 `WinUser.h` (勿凭记忆改).
library;

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

// ---- WinUser.h 常量 ----
const int _gwlStyle = -16; // GWL_STYLE
// WS_OVERLAPPED(0) | WS_CAPTION(0x00C00000) | WS_SYSMENU(0x00080000) |
// WS_THICKFRAME(0x00040000) | WS_MINIMIZEBOX(0x00020000) | WS_MAXIMIZEBOX(0x00010000)
const int _wsOverlappedWindow = 0x00CF0000;
const int _swpNoSize = 0x0001;
const int _swpNoMove = 0x0002;
const int _swpNoZOrder = 0x0004;
const int _swpNoActivate = 0x0010;
const int _swpFrameChanged = 0x0020;
const int _swpNoOwnerZOrder = 0x0200;
const int _hwndTop = 0; // HWND_TOP ((HWND)0)
const int _monitorDefaultToNearest = 0x00000002;

/// runner 主窗口类名 (windows/runner/win32_window.cpp) 与 Flutter 视图子窗口类名.
const String _runnerWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';
const String _flutterViewClass = 'FLUTTERVIEW';

// ---- user32 绑定 (64 位: *LongPtrW 为真实导出) ----
@Native<IntPtr Function(Pointer<Uint16>, Pointer<Uint16>)>(
  symbol: 'FindWindowW',
  assetId: 'user32',
)
external int _findWindowW(Pointer<Uint16> className, Pointer<Uint16> name);

@Native<IntPtr Function(IntPtr, IntPtr, Pointer<Uint16>, Pointer<Uint16>)>(
  symbol: 'FindWindowExW',
  assetId: 'user32',
)
external int _findWindowExW(
  int parent,
  int childAfter,
  Pointer<Uint16> className,
  Pointer<Uint16> name,
);

@Native<IntPtr Function(IntPtr, Int32)>(
  symbol: 'GetWindowLongPtrW',
  assetId: 'user32',
)
external int _getWindowLongPtrW(int hwnd, int index);

@Native<IntPtr Function(IntPtr, Int32, IntPtr)>(
  symbol: 'SetWindowLongPtrW',
  assetId: 'user32',
)
external int _setWindowLongPtrW(int hwnd, int index, int value);

@Native<Int32 Function(IntPtr, Pointer<_WindowPlacement>)>(
  symbol: 'GetWindowPlacement',
  assetId: 'user32',
)
external int _getWindowPlacement(int hwnd, Pointer<_WindowPlacement> wp);

@Native<IntPtr Function(IntPtr, Uint32)>(
  symbol: 'MonitorFromWindow',
  assetId: 'user32',
)
external int _monitorFromWindow(int hwnd, int flags);

@Native<Int32 Function(IntPtr, Pointer<_MonitorInfo>)>(
  symbol: 'GetMonitorInfoW',
  assetId: 'user32',
)
external int _getMonitorInfoW(int monitor, Pointer<_MonitorInfo> info);

@Native<Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32)>(
  symbol: 'SetWindowPos',
  assetId: 'user32',
)
external int _setWindowPos(
  int hwnd,
  int insertAfter,
  int x,
  int y,
  int cx,
  int cy,
  int flags,
);

@Native<Int32 Function(IntPtr)>(symbol: 'IsZoomed', assetId: 'user32')
external int _isZoomed(int hwnd);

@Native<Int32 Function(IntPtr, Pointer<_Rect>)>(
  symbol: 'GetClientRect',
  assetId: 'user32',
)
external int _getClientRect(int hwnd, Pointer<_Rect> rect);

// ---- 结构体 (WinUser.h / windef.h 布局) ----
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

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

/// WINDOWPLACEMENT (非 _MAC: 无 rcDevice) — 44 字节.
final class _WindowPlacement extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int flags;
  @Uint32()
  external int showCmd;
  external _Point ptMinPosition;
  external _Point ptMaxPosition;
  external _Rect rcNormalPosition;
}

/// MONITORINFO — 40 字节.
final class _MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _Rect rcMonitor;
  external _Rect rcWork;
  @Uint32()
  external int dwFlags;
}

/// runner 窗口的原生全屏进出 (仅 Windows; 其他平台调用方走 window_manager).
///
/// 状态 (是否全屏 + 进入前矩形) 与 media_kit 原实现一样是进程级单例 —
/// 只有一个 runner 窗口.
final class Win32FullscreenBridge {
  Win32FullscreenBridge._();

  static bool _fullscreen = false;
  static (int, int, int, int)? _rectBefore;

  /// 进入全屏前窗口实际拥有的 WS_OVERLAPPEDWINDOW 子位 (customFrame 下不含
  /// WS_CAPTION); 退出时按此恢复. 默认整组, 兼容无 frame 的样式.
  static int _overlappedBitsBefore = _wsOverlappedWindow;

  /// 是否在 Windows 上可用.
  static bool get isSupported => Platform.isWindows;

  /// 进入全屏 — 已在全屏或窗口已无 WS_OVERLAPPEDWINDOW 时 no-op.
  /// side effect: 改写窗口样式并铺满最近显示器 (SWP_FRAMECHANGED 触发重算边框).
  static void enter() {
    if (_fullscreen) return;
    final hwnd = _runnerWindow();
    if (hwnd == 0) return;
    _fullscreen = true;
    final style = _getWindowLongPtrW(hwnd, _gwlStyle);
    if (style & _wsOverlappedWindow == 0) return;
    using((arena) {
      final placement = arena<_WindowPlacement>()
        ..ref.length = sizeOf<_WindowPlacement>();
      _getWindowPlacement(hwnd, placement);
      final r = placement.ref.rcNormalPosition;
      _rectBefore = (r.left, r.top, r.right, r.bottom);
      _overlappedBitsBefore = style & _wsOverlappedWindow;
      final monitor = arena<_MonitorInfo>()
        ..ref.cbSize = sizeOf<_MonitorInfo>();
      _getMonitorInfoW(
        _monitorFromWindow(hwnd, _monitorDefaultToNearest),
        monitor,
      );
      final m = monitor.ref.rcMonitor;
      _setWindowLongPtrW(hwnd, _gwlStyle, style & ~_wsOverlappedWindow);
      _setWindowPos(
        hwnd,
        _hwndTop,
        m.left,
        m.top,
        m.right - m.left,
        m.bottom - m.top,
        _swpNoOwnerZOrder | _swpFrameChanged,
      );
    });
  }

  /// 退出全屏 — 恢复样式; 最大化窗口刷新边框并让 Flutter 视图铺满客户区,
  /// 否则恢复进入前的普通矩形.
  static void exit() {
    if (!_fullscreen) return;
    _fullscreen = false;
    final hwnd = _runnerWindow();
    if (hwnd == 0) return;
    final style = _getWindowLongPtrW(hwnd, _gwlStyle);
    if (style & _wsOverlappedWindow != 0) return;
    _setWindowLongPtrW(hwnd, _gwlStyle, style | _overlappedBitsBefore);
    if (_isZoomed(hwnd) != 0) {
      _setWindowPos(
        hwnd,
        0,
        0,
        0,
        0,
        0,
        _swpNoActivate |
            _swpNoMove |
            _swpNoSize |
            _swpNoZOrder |
            _swpFrameChanged,
      );
      using((arena) {
        final rect = arena<_Rect>();
        _getClientRect(hwnd, rect);
        final view = _findChild(hwnd, _flutterViewClass, arena);
        if (view == 0) return;
        _setWindowPos(
          view,
          0,
          rect.ref.left,
          rect.ref.top,
          rect.ref.right - rect.ref.left,
          rect.ref.bottom - rect.ref.top,
          _swpNoActivate | _swpNoZOrder,
        );
      });
      return;
    }
    final before = _rectBefore;
    if (before == null) return;
    final (left, top, right, bottom) = before;
    _setWindowPos(
      hwnd,
      0,
      left,
      top,
      right - left,
      bottom - top,
      _swpNoActivate | _swpNoZOrder,
    );
  }

  static int _runnerWindow() => using(
    (arena) => _findWindowW(
      _runnerWindowClass.toNativeUtf16(allocator: arena).cast(),
      nullptr,
    ),
  );

  static int _findChild(int parent, String className, Arena arena) =>
      _findWindowExW(
        parent,
        0,
        className.toNativeUtf16(allocator: arena).cast(),
        nullptr,
      );
}
