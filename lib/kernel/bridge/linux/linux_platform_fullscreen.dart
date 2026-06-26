/// Linux 平台全屏实现 — GTK3 FFI 调用 gtk_window_fullscreen/unfullscreen。
///
/// Flutter GTK embedding 已加载 libgtk-3.so，可直接 FFI 调用。
/// gtk_window_fullscreen() 内部自动处理:
/// - X11: 设置 _NET_WM_STATE_FULLSCREEN 属性
/// - Wayland: 调用 xdg_toplevel_set_fullscreen
///
/// requiresStyleSave = false，GTK 内部管理窗口状态。
import 'dart:ffi' hide Size;
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platform_fullscreen.dart';

// ─── GTK3 函数签名 ───

// GtkWidget* -> void (gtk_window_fullscreen)
typedef _GtkWindowFullscreenNative = Void Function(IntPtr window);
typedef _GtkWindowFullscreenDart = void Function(int window);

// GtkWidget* -> void (gtk_window_unfullscreen)
typedef _GtkWindowUnfullscreenNative = Void Function(IntPtr window);
typedef _GtkWindowUnfullscreenDart = void Function(int window);

// GtkWidget*, int*, int* -> void (gtk_window_get_size)
typedef _GtkWindowGetSizeNative = Void Function(
    IntPtr window, IntPtr width, IntPtr height);
typedef _GtkWindowGetSizeDart = void Function(
    int window, int width, int height);

// GtkWidget*, int*, int* -> void (gtk_window_get_position)
typedef _GtkWindowGetPositionNative = Void Function(
    IntPtr window, IntPtr x, IntPtr y);
typedef _GtkWindowGetPositionDart = void Function(
    int window, int x, int y);

/// Linux 平台全屏 — 实现 PlatformFullscreen 接口。
///
/// 使用 GTK3 FFI 操作窗口，自动适配 X11 和 Wayland。
class LinuxPlatformFullscreen implements PlatformFullscreen {
  // MethodChannel — 从 native 端获取 GtkWindow 指针
  static const _channel = MethodChannel('com.simple_player/window');
  static int? _cachedGtkWindow;

  // 尝试加载 GTK3 共享库
  static final DynamicLibrary? _gtk = _loadGtk();

  static DynamicLibrary? _loadGtk() {
    try {
      return DynamicLibrary.open('libgtk-3.so.0');
    } catch (_) {
      try {
        return DynamicLibrary.open('libgtk-3.so');
      } catch (_) {
        debugPrint('[LinuxFullscreen] GTK3 not available, fullscreen disabled');
        return null;
      }
    }
  }

  // GTK3 函数绑定（延迟初始化）
  static final _gtkWindowFullscreen = _gtk?.lookupFunction<
      _GtkWindowFullscreenNative,
      _GtkWindowFullscreenDart>('gtk_window_fullscreen');

  static final _gtkWindowUnfullscreen = _gtk?.lookupFunction<
      _GtkWindowUnfullscreenNative,
      _GtkWindowUnfullscreenDart>('gtk_window_unfullscreen');

  static final _gtkWindowGetSize = _gtk?.lookupFunction<
      _GtkWindowGetSizeNative,
      _GtkWindowGetSizeDart>('gtk_window_get_size');

  static final _gtkWindowGetPosition = _gtk?.lookupFunction<
      _GtkWindowGetPositionNative,
      _GtkWindowGetPositionDart>('gtk_window_get_position');

  @override
  bool get requiresStyleSave => false;

  @override
  Future<FullscreenSnapshot> enter() async {
    final gtkWindow = await _getGtkWindowAsync();
    if (_gtkWindowFullscreen == null) {
      // GTK 不可用，返回空快照
      return const FullscreenSnapshot(
        windowStyle: 0,
        position: Offset.zero,
        size: Size(1280, 720),
      );
    }

    // 保存当前窗口几何
    final position = _getWindowPosition(gtkWindow);
    final size = _getWindowSize(gtkWindow);

    // 进入全屏
    _gtkWindowFullscreen!(gtkWindow);

    return FullscreenSnapshot(
      windowStyle: 0,
      position: position,
      size: size,
    );
  }

  @override
  void exit(FullscreenSnapshot snapshot) {
    // fire-and-forget — 调用端不 await
    _exitAsync(snapshot);
  }

  Future<void> _exitAsync(FullscreenSnapshot snapshot) async {
    final gtkWindow = await _getGtkWindowAsync();
    if (_gtkWindowUnfullscreen == null) return;
    _gtkWindowUnfullscreen!(gtkWindow);
  }

  /// 通过 MethodChannel 获取 Flutter GTK 窗口指针。
  ///
  /// 结果缓存到 _cachedGtkWindow — GTK 窗口指针在应用生命周期内不变。
  static Future<int> _getGtkWindowAsync() async {
    if (_cachedGtkWindow != null && _cachedGtkWindow != 0) {
      return _cachedGtkWindow!;
    }
    final handle = await _channel.invokeMethod<int>('getGtkWindowHandle');
    if (handle == null || handle == 0) {
      throw StateError('Failed to get GTK window handle from native side');
    }
    _cachedGtkWindow = handle;
    return handle;
  }

  /// 重置缓存（供测试用）。
  static void resetCache() => _cachedGtkWindow = null;

  /// 获取窗口位置。
  static Offset _getWindowPosition(int gtkWindow) {
    if (_gtkWindowGetPosition == null) return Offset.zero;
    final xPtr = calloc<Int32>();
    final yPtr = calloc<Int32>();
    try {
      _gtkWindowGetPosition!(gtkWindow, xPtr.address, yPtr.address);
      return Offset(xPtr.value.toDouble(), yPtr.value.toDouble());
    } finally {
      calloc.free(xPtr);
      calloc.free(yPtr);
    }
  }

  /// 获取窗口大小。
  static Size _getWindowSize(int gtkWindow) {
    if (_gtkWindowGetSize == null) return const Size(1280, 720);
    final wPtr = calloc<Int32>();
    final hPtr = calloc<Int32>();
    try {
      _gtkWindowGetSize!(gtkWindow, wPtr.address, hPtr.address);
      return Size(wPtr.value.toDouble(), hPtr.value.toDouble());
    } finally {
      calloc.free(wPtr);
      calloc.free(hPtr);
    }
  }
}
