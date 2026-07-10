// Windows 原生全屏驱动 — Win32 FFI 直调 user32.dll。
//
// 实现 FullscreenDriver 接口，替代 fullscreen_window C++ 插件的 Windows 实现。
// 核心能力:
// - WS_THICKFRAME 剥离解决 7px 缝隙 (D-P06)
// - 退出全屏后焦点恢复 (D-P07)
// - TopMost 残留清理 (D-P08)
// - IsZoomed 真实状态查询
//
// 设计:
// - 可选注入 Win32FullscreenApi mock 用于测试 (D-P05)
// - 保存/恢复窗口样式、扩展样式和窗口位置
// - 焦点恢复有安全护栏: 仅在窗口可见且未最小化时执行

import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../models/fullscreen_capability.dart';
import '../fullscreen_driver.dart';
import '../win32/win32_fullscreen_ffi.dart';

/// Windows 原生全屏驱动 — Win32 FFI 直调。
///
/// 复用 fullscreen_window_plugin.cpp 的 WS_THICKFRAME 剥离逻辑 (D-P05)，
/// 增加焦点恢复 (D-P07) 和 TopMost 清理 (D-P08)。
///
/// 可选注入 [Win32FullscreenApi] 的替代实现用于测试:
/// ```dart
/// final driver = WindowsFullscreenDriver(api: mockApi);
/// ```
class WindowsFullscreenDriver implements FullscreenDriver {
  /// 创建 WindowsFullscreenDriver。
  ///
  /// [api] 可选参数，用于测试注入 mock。
  /// 默认使用 Win32FullscreenApi 静态方法。
  WindowsFullscreenDriver({Win32FullscreenApiWrapper? api})
      : _api = api ?? const Win32FullscreenApiWrapper();

  final Win32FullscreenApiWrapper _api;

  /// 保存的窗口样式 — 进入全屏前快照。
  int _savedStyle = 0;

  /// 保存的扩展窗口样式 — 进入全屏前快照。
  int _savedExStyle = 0;

  /// 保存的窗口位置指针 — 进入全屏前快照。
  /// 需要在 leaveFullscreen 后 free。
  Pointer<WindowPlacement>? _savedPlacement;

  /// 内部全屏状态跟踪。
  bool _isFullscreen = false;

  // ─── 回调桥接 ───

  /// Windows FFI 驱动不需要原生回调机制 (D-P11)。
  ///
  /// FFI 同步操作完成后 queryFullscreen() 直接返回真实状态，
  /// 不需要 delegate 回调确认。此 setter 接受但不使用回调。
  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    // Windows FFI 驱动无需回调 — 操作同步完成
  }

  // ─── FullscreenDriver 接口实现 ───

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0 || !_api.isWindow(hwnd)) {
      debugPrint('[WindowsFullscreenDriver] invalid HWND: $hwnd');
      return;
    }

    // 保存当前窗口样式 (D-P06 前快照)
    _savedStyle = _api.getWindowLong(hwnd, gwlStyle);
    _savedExStyle = _api.getWindowLong(hwnd, gwlExStyle);

    // 保存窗口位置
    _freeSavedPlacement();
    _savedPlacement = _api.getWindowPlacement(hwnd);

    // 剥离 WS_THICKFRAME + WS_CAPTION (D-P06: 解决 7px 缝隙)
    // 同时移除 WS_MAXIMIZE 防止系统自动最大化行为
    _api.setWindowLong(
      hwnd,
      gwlStyle,
      _savedStyle & ~(wsCaption | wsThickframe | wsMaximize),
    );

    // 设置 WS_EX_TOPMOST + 剥离边框样式
    _api.setWindowLong(
      hwnd,
      gwlExStyle,
      _savedExStyle | wsExTopmost & ~(wsExDlgmodalframe |
          wsExWindowedge | wsExClientedge | wsExStaticedge),
    );

    // 防御性验证: 确认样式已正确应用 (T-05-01)
    // 在 setWindowPos 前回读样式，检测 Win32 API 静默失败
    final verifyStyle = _api.getWindowLong(hwnd, gwlStyle);
    final verifyExStyle = _api.getWindowLong(hwnd, gwlExStyle);
    if (verifyStyle & (wsCaption | wsThickframe | wsMaximize) != 0) {
      debugPrint(
        '[WindowsFullscreenDriver] WARN: style strip failed '
        '(expected border bits cleared, got 0x${verifyStyle.toRadixString(16)})',
      );
    }
    if (verifyExStyle & wsExTopmost == 0) {
      debugPrint(
        '[WindowsFullscreenDriver] WARN: WS_EX_TOPMOST not set '
        '(got 0x${verifyExStyle.toRadixString(16)})',
      );
    }

    // 获取显示器区域并覆盖整个显示器
    final monitor = _api.monitorFromWindow(hwnd);
    if (monitor != 0) {
      final rc = _api.getMonitorRect(monitor);
      if (rc != null) {
        _api.setWindowPos(
          hwnd,
          hwndTopmost,
          rc.left,
          rc.top,
          rc.right - rc.left,
          rc.bottom - rc.top,
          swpNoownerzorder | swpFramechanged,
        );
      }
    }

    _isFullscreen = true;
  }

  @override
  Future<void> leaveFullscreen() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0 || !_api.isWindow(hwnd)) {
      debugPrint('[WindowsFullscreenDriver] invalid HWND: $hwnd');
      return;
    }

    // 恢复窗口样式 (D-P06)
    _api.setWindowLong(hwnd, gwlStyle, _savedStyle);
    _api.setWindowLong(hwnd, gwlExStyle, _savedExStyle);

    // 清理 TopMost (D-P08)
    _api.setWindowPos(
      hwnd,
      hwndNotopmost,
      0, 0, 0, 0,
      swpNomove | swpNosize | swpNoownerzorder | swpFramechanged,
    );

    // 恢复窗口位置
    if (_savedPlacement != null) {
      _api.setWindowPlacement(hwnd, _savedPlacement!);
      _freeSavedPlacement();
    }

    // 强制 Flutter 布局刷新
    // 参考 fullscreen_window_plugin.cpp 第 55 行:
    // SetWindowPos(hwnd, 0, ..., SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)
    final bounds = _api.getWindowRect(hwnd);
    if (bounds != null) {
      _api.setWindowPos(
        hwnd,
        0,
        bounds.left,
        bounds.top,
        bounds.right - bounds.left,
        bounds.bottom - bounds.top,
        swpNozorder | swpNoactivate | swpFramechanged,
      );
    }

    // 焦点恢复 (D-P07): 安全护栏
    // 仅在窗口可见且未最小化时执行
    if (_api.isWindowVisible(hwnd) && !_api.isIconic(hwnd)) {
      _api.setForegroundWindow(hwnd);
      _api.setFocus(hwnd);
    }

    _isFullscreen = false;
  }

  @override
  Future<bool> queryFullscreen() async {
    final hwnd = _api.getFlutterHwnd();
    // 优先使用 IsZoomed 查询真实状态
    if (hwnd != 0 && _api.isWindow(hwnd)) {
      return _api.isZoomed(hwnd);
    }
    // HWND 无效时回退到内部状态
    return _isFullscreen;
  }

  @override
  Future<Offset> getPosition() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0) return Offset.zero;
    final placement = _api.getWindowPlacement(hwnd);
    if (placement == null) return Offset.zero;
    try {
      final dpr = _getDevicePixelRatio();
      return Offset(
        placement.ref.rcNormalPosition.left / dpr,
        placement.ref.rcNormalPosition.top / dpr,
      );
    } finally {
      calloc.free(placement);
    }
  }

  @override
  Future<Size> getSize() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0) return Size.zero;
    final placement = _api.getWindowPlacement(hwnd);
    if (placement == null) return Size.zero;
    try {
      final dpr = _getDevicePixelRatio();
      final rc = placement.ref.rcNormalPosition;
      return Size(
        (rc.right - rc.left) / dpr,
        (rc.bottom - rc.top) / dpr,
      );
    } finally {
      calloc.free(placement);
    }
  }

  @override
  Future<void> setBounds(Offset? position, Size? size) async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0) return;

    final dpr = _getDevicePixelRatio();
    int x = 0;
    int y = 0;
    int cx = 0;
    int cy = 0;
    int flags = swpFramechanged;

    if (position != null) {
      x = (position.dx * dpr).round();
      y = (position.dy * dpr).round();
    } else {
      flags |= swpNomove;
    }

    if (size != null) {
      cx = (size.width * dpr).round();
      cy = (size.height * dpr).round();
    } else {
      flags |= swpNosize;
    }

    _api.setWindowPos(hwnd, 0, x, y, cx, cy, flags);
  }

  @override
  Future<void> maximize() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd != 0) {
      _api.maximizeWindow(hwnd);
    }
  }

  @override
  Future<void> restore() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd != 0) {
      _api.restoreWindow(hwnd);
    }
  }

  @override
  Future<void> focus() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd != 0 && _api.isWindowVisible(hwnd)) {
      _api.setForegroundWindow(hwnd);
      _api.setFocus(hwnd);
    }
  }

  @override
  Future<bool> isMaximized() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0) return false;
    return _api.isZoomed(hwnd);
  }

  @override
  Future<bool> isMinimized() async {
    final hwnd = _api.getFlutterHwnd();
    if (hwnd == 0) return false;
    return _api.isIconic(hwnd);
  }

  // ─── 能力查询 ───

  /// 返回 Windows 平台全屏能力。
  ///
  /// Windows 支持多显示器全屏 (MonitorFromWindow + GetMonitorInfoW)。
  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability(
      supportsFullscreen: true,
      supportsMultiWindow: false,
      supportsMultiDisplay: true,
      supportsExclusive: false,
      requiresUserGesture: false,
      platformNotes:
          'Win32 FFI: WS_THICKFRAME removal, focus recovery, TopMost cleanup',
    );
  }

  // ─── 内部辅助 ───

  /// 释放保存的窗口位置指针。
  void _freeSavedPlacement() {
    final p = _savedPlacement;
    if (p != null) {
      calloc.free(p);
      _savedPlacement = null;
    }
  }

  /// 获取 devicePixelRatio。
  double _getDevicePixelRatio() {
    try {
      return PlatformDispatcher.instance.views.first.devicePixelRatio;
    } catch (_) {
      return 1.0;
    }
  }
}

/// Win32FullscreenApi 包装器 — 将静态方法转为可 mock 的实例方法。
///
/// 默认实现委托给 Win32FullscreenApi 静态方法。
/// 测试中可替换为自定义实现。
class Win32FullscreenApiWrapper {
  const Win32FullscreenApiWrapper();

  int getFlutterHwnd() => Win32FullscreenApi.getFlutterHwnd();
  int getWindowLong(int hwnd, int index) =>
      Win32FullscreenApi.getWindowLong(hwnd, index);
  int setWindowLong(int hwnd, int index, int value) =>
      Win32FullscreenApi.setWindowLong(hwnd, index, value);
  bool setWindowPos(int hwnd, int insertAfter, int x, int y, int cx, int cy,
          int flags) =>
      Win32FullscreenApi.setWindowPos(
          hwnd, insertAfter, x, y, cx, cy, flags);
  ({int left, int top, int right, int bottom})? getWindowRect(int hwnd) =>
      Win32FullscreenApi.getWindowRect(hwnd);
  bool setForegroundWindow(int hwnd) =>
      Win32FullscreenApi.setForegroundWindow(hwnd);
  int setFocus(int hwnd) => Win32FullscreenApi.setFocus(hwnd);
  bool isWindow(int hwnd) => Win32FullscreenApi.isWindow(hwnd);
  bool isWindowVisible(int hwnd) => Win32FullscreenApi.isWindowVisible(hwnd);
  bool isIconic(int hwnd) => Win32FullscreenApi.isIconic(hwnd);
  bool isZoomed(int hwnd) => Win32FullscreenApi.isZoomed(hwnd);
  int monitorFromWindow(int hwnd) =>
      Win32FullscreenApi.monitorFromWindow(hwnd);
  ({int left, int top, int right, int bottom})? getMonitorRect(int hMonitor) =>
      Win32FullscreenApi.getMonitorRect(hMonitor);
  Pointer<WindowPlacement>? getWindowPlacement(int hwnd) =>
      Win32FullscreenApi.getWindowPlacement(hwnd);
  bool setWindowPlacement(int hwnd, Pointer<WindowPlacement> placement) =>
      Win32FullscreenApi.setWindowPlacement(hwnd, placement);
  bool maximizeWindow(int hwnd) => Win32FullscreenApi.maximizeWindow(hwnd);
  bool restoreWindow(int hwnd) => Win32FullscreenApi.restoreWindow(hwnd);
}
