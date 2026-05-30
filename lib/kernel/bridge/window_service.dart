import 'dart:async';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

import '../persistence/settings_store.dart';

// ─── FFI type definitions (no side effects at import time) ───

typedef _GetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr);
typedef _GetWindowLongPtrDart = int Function(int, int);
typedef _SetWindowLongPtrNative = IntPtr Function(IntPtr, IntPtr, IntPtr);
typedef _SetWindowLongPtrDart = int Function(int, int, int);
typedef _SetWindowPosNative =
    Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32);
typedef _SetWindowPosDart = int Function(int, int, int, int, int, int, int);
typedef _MonitorFromWindowNative = IntPtr Function(IntPtr, Uint32);
typedef _MonitorFromWindowDart = int Function(int, int);
typedef _GetMonitorInfoNative = Int32 Function(IntPtr, Pointer);
typedef _GetMonitorInfoDart = int Function(int, Pointer);
typedef _GetWindowRectNative = Int32 Function(IntPtr, Pointer<_Rect>);
typedef _GetWindowRectDart = int Function(int, Pointer<_Rect>);
typedef _DwmExtendFrameIntoClientAreaNative =
    Int32 Function(IntPtr, Pointer<_Margins>);
typedef _DwmExtendFrameIntoClientAreaDart =
    int Function(int, Pointer<_Margins>);
const _gwlStyle = -16;
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

/// Win32 API bindings — lazy singleton to avoid import-time DLL loading.
///
/// All FFI lookups execute on first access, not at import time.
/// This makes importing WindowService safe in test environments.
class _Win32Bindings {
  late final DynamicLibrary _user32;
  late final DynamicLibrary _dwmapi;

  late final _GetWindowLongPtrDart getWindowLongPtr;
  late final _SetWindowLongPtrDart setWindowLongPtr;
  late final _SetWindowPosDart setWindowPos;
  late final _MonitorFromWindowDart monitorFromWindow;
  late final _GetMonitorInfoDart getMonitorInfo;
  late final _GetWindowRectDart getWindowRect;
  late final _DwmExtendFrameIntoClientAreaDart dwmExtendFrameIntoClientArea;

  _Win32Bindings() {
    _user32 = DynamicLibrary.open('user32.dll');
    _dwmapi = DynamicLibrary.open('dwmapi.dll');

    getWindowLongPtr = _user32
        .lookupFunction<_GetWindowLongPtrNative, _GetWindowLongPtrDart>(
          'GetWindowLongPtrW',
        );
    setWindowLongPtr = _user32
        .lookupFunction<_SetWindowLongPtrNative, _SetWindowLongPtrDart>(
          'SetWindowLongPtrW',
        );
    setWindowPos = _user32
        .lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');
    monitorFromWindow = _user32
        .lookupFunction<_MonitorFromWindowNative, _MonitorFromWindowDart>(
          'MonitorFromWindow',
        );
    getMonitorInfo = _user32
        .lookupFunction<_GetMonitorInfoNative, _GetMonitorInfoDart>(
          'GetMonitorInfoW',
        );
    getWindowRect = _user32
        .lookupFunction<_GetWindowRectNative, _GetWindowRectDart>(
          'GetWindowRect',
        );
    dwmExtendFrameIntoClientArea = _dwmapi
        .lookupFunction<
          _DwmExtendFrameIntoClientAreaNative,
          _DwmExtendFrameIntoClientAreaDart
        >('DwmExtendFrameIntoClientArea');
  }
}

/// Lazy-initialized Win32 bindings. First access triggers DLL loading.
final _win32 = _Win32Bindings();

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
  Pointer<_Rect>? _savedMaximizeFrame; // 最大化前的窗口位置
  int? _baseStyle; // _removeBorder() 完成后的基准 style
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
    final style = _win32.getWindowLongPtr(hwnd, _gwlStyle);
    // 只移除 WS_CAPTION，保留 WS_THICKFRAME 用于原生缩放
    final newStyle = style & ~_wsCaption;
    _win32.setWindowLongPtr(hwnd, _gwlStyle, newStyle);

    // 保留 DWM 阴影：顶部 1px frame 让 DWM 认为窗口有边框
    final margins = calloc<_Margins>()
      ..ref.left = 0
      ..ref.right = 0
      ..ref.top = 1
      ..ref.bottom = 0;
    _win32.dwmExtendFrameIntoClientArea(hwnd, margins);
    calloc.free(margins);

    _win32.setWindowPos(
      hwnd,
      0,
      0,
      0,
      0,
      0,
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
    _savedStyle = _baseStyle ?? _win32.getWindowLongPtr(hwnd, _gwlStyle);
    final frame = calloc<_Rect>();
    _win32.getWindowRect(hwnd, frame);
    final saved = calloc<_Rect>();
    saved.ref.left = frame.ref.left;
    saved.ref.top = frame.ref.top;
    saved.ref.right = frame.ref.right;
    saved.ref.bottom = frame.ref.bottom;
    _savedFrame = saved;
    calloc.free(frame);

    // Set WS_POPUP — fully borderless, no DWM frame.
    _win32.setWindowLongPtr(hwnd, _gwlStyle, _wsPopup);

    // Remove DWM shadow/border.
    final margins = calloc<_Margins>()
      ..ref.left = -1
      ..ref.right = -1
      ..ref.top = -1
      ..ref.bottom = -1;
    _win32.dwmExtendFrameIntoClientArea(hwnd, margins);
    calloc.free(margins);

    // Get monitor bounds.
    final hMonitor = _win32.monitorFromWindow(hwnd, _monitorDefaultToNearest);
    final mi = calloc<_MonitorInfo>();
    mi.ref.cbSize = sizeOf<_MonitorInfo>();
    _win32.getMonitorInfo(hMonitor, mi);

    // Position window to fill entire monitor.
    _win32.setWindowPos(
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
    _win32.setWindowLongPtr(hwnd, _gwlStyle, _savedStyle!);

    // Restore original window frame.
    if (_savedFrame != null) {
      _win32.setWindowPos(
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

  /// 自定义最大化 — 使用 rcWork（工作区）而非全监视器。
  ///
  /// windowManager.maximize() 在无边框窗口上会覆盖任务栏，
  /// 因为插件的 adjustNCCALCSIZE 将客户区扩展到整个监视器。
  /// 此处直接用 GetMonitorInfoW 获取工作区矩形 + SetWindowPos 定位。
  Future<void> maximize() async {
    if (isMaximized.value) return;
    final hwnd = await windowManager.getId();

    // 保存当前窗口位置（用于 restore）
    final frame = calloc<_Rect>();
    _win32.getWindowRect(hwnd, frame);
    final saved = calloc<_Rect>()
      ..ref.left = frame.ref.left
      ..ref.top = frame.ref.top
      ..ref.right = frame.ref.right
      ..ref.bottom = frame.ref.bottom;
    _savedMaximizeFrame = saved;
    calloc.free(frame);

    // 获取工作区（排除任务栏）
    final hMonitor = _win32.monitorFromWindow(hwnd, _monitorDefaultToNearest);
    final mi = calloc<_MonitorInfo>();
    mi.ref.cbSize = sizeOf<_MonitorInfo>();
    _win32.getMonitorInfo(hMonitor, mi);

    // 定位到工作区（不禁用 DWM 过渡，保留平滑动画）
    _win32.setWindowPos(
      hwnd,
      _hwndTop,
      mi.ref.rcWork.left,
      mi.ref.rcWork.top,
      mi.ref.rcWork.right - mi.ref.rcWork.left,
      mi.ref.rcWork.bottom - mi.ref.rcWork.top,
      _swpNoOwnerZOrder | _swpFrameChanged,
    );

    calloc.free(mi);
    if (!isMaximized.value) isMaximized.value = true;
  }

  /// 从自定义最大化恢复到之前的位置。
  Future<void> restore() async {
    if (!isMaximized.value || _savedMaximizeFrame == null) return;
    final hwnd = await windowManager.getId();

    // 恢复窗口位置（不禁用 DWM 过渡，保留平滑动画）
    _win32.setWindowPos(
      hwnd,
      0,
      _savedMaximizeFrame!.ref.left,
      _savedMaximizeFrame!.ref.top,
      _savedMaximizeFrame!.ref.right - _savedMaximizeFrame!.ref.left,
      _savedMaximizeFrame!.ref.bottom - _savedMaximizeFrame!.ref.top,
      _swpNoOwnerZOrder | _swpFrameChanged,
    );

    calloc.free(_savedMaximizeFrame!);
    _savedMaximizeFrame = null;
    if (isMaximized.value) isMaximized.value = false;
  }

  Future<void> close() => windowManager.close();

  Future<void> center() => windowManager.center();

  Future<void> startDragging() => windowManager.startDragging();

  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    if (_savedMaximizeFrame != null) {
      calloc.free(_savedMaximizeFrame!);
    }
    windowManager.removeListener(this);
    isFullscreen.dispose();
    isAlwaysOnTop.dispose();
    isMaximized.dispose();
    windowSize.dispose();
  }
}
