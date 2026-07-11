// Linux 原生全屏驱动 — fullscreen_window 插件 + window-state-event 信号。
//
// 实现 FullscreenDriver 接口，使用 GTK fullscreen/unfullscreen 原生 API。
// 通过 GdkWindow state-changed 信号确认全屏状态变化 (D-P12)。
// WM 类型检测记录到 platformNotes + 日志 (D-P13)。
//
// 设计:
// - _plugin: FullScreenWindowPlatform — 全屏操作 + GDK 状态查询 + 回调流
// - _wm: WindowManager — 其他窗口操作 (getPosition/getSize/setBounds 等)
// - onNativeStateChanged 回调通知 DesktopFullscreenAdapter (D-P12)
// - WM 检测通过 XDG 环境变量读取 (D-P13)

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/fullscreen_capability.dart';
import '../fullscreen_driver.dart';

/// Linux 原生全屏驱动 — fullscreen_window 插件 + window-state-event 信号。
///
/// 使用 GTK fullscreen/unfullscreen 原生 API，
/// 通过 GdkWindow state-changed 信号确认全屏状态变化 (D-P12)。
///
/// 三级确认链 (D-P11):
/// - Level 1: state-changed 信号回调确认 (500ms)
/// - Level 2: queryFullscreen() 轮询 (100ms x 20)
/// - Level 3: 超时，返回 false (Adapter 层处理)
///
/// 注入依赖:
/// ```dart
/// final driver = LinuxFullscreenDriver(
///   plugin: mockPlugin,
///   wm: mockWindowManager,
/// );
/// ```
class LinuxFullscreenDriver implements FullscreenDriver {
  /// 创建 LinuxFullscreenDriver。
  ///
  /// [plugin] fullscreen_window 插件平台接口，用于全屏操作和回调。
  /// [wm] window_manager 窗口管理器，用于其他窗口操作。
  LinuxFullscreenDriver({FullScreenWindowPlatform? plugin, WindowManager? wm})
    : _plugin = plugin ?? FullScreenWindowPlatform.instance,
      _wm = wm ?? windowManager {
    // 订阅原生回调流 (D-P12)
    // window-state-event 信号通过 MethodChannel 到达此流
    _stateStreamSub = _plugin.onFullScreenChanged.listen((isFullscreen) {
      debugPrint(
        '[LinuxFullscreenDriver] native callback: isFullscreen=$isFullscreen',
      );
      _onNativeCallback?.call(0, isFullscreen);
    });

    // WM 检测 — 记录到日志 (D-P13)
    _wmInfo = _detectWindowManager();
    debugPrint('[LinuxFullscreenDriver] WM detected: $_wmInfo');
  }

  /// fullscreen_window 插件 — 全屏操作 + 回调流。
  final FullScreenWindowPlatform _plugin;

  /// window_manager — 其他窗口操作。
  final WindowManager _wm;

  /// 原生回调流订阅。
  StreamSubscription<bool>? _stateStreamSub;

  /// 原生回调通知 Adapter 的回调 (D-P12)。
  ///
  /// 签名: (windowId, isFullscreen)
  /// 由 DesktopFullscreenAdapter.onNativeFullScreenChanged 设置。
  void Function(int windowId, bool isFullscreen)? _onNativeCallback;

  /// WM 检测结果 (D-P13) — 记录到 platformNotes。
  late final String _wmInfo;

  // ─── WM 检测 (D-P13) ───

  /// 检测当前窗口管理器类型，用于诊断日志和 platformNotes。
  ///
  /// 读取 XDG 环境变量:
  /// - XDG_SESSION_TYPE: "x11" 或 "wayland"
  /// - XDG_CURRENT_DESKTOP: 桌面环境名 (如 "GNOME", "KDE")
  /// - GDMSESSION / DESKTOP_SESSION: 会话名
  static String _detectWindowManager() {
    final sessionType = Platform.environment['XDG_SESSION_TYPE'] ?? 'unknown';
    final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';
    final wmName =
        Platform.environment['GDMSESSION'] ??
        Platform.environment['DESKTOP_SESSION'] ??
        '';
    return 'session=$sessionType, desktop=$desktop, wm=$wmName';
  }

  // ─── 回调桥接 (D-P12) ───

  // ─── 能力标志 (ARCH-01) ───

  @override
  bool get supportsFastPath => false;

  @override
  bool get supportsBatchSnapshot => false;

  @override
  Future<void> enterFullscreenFast({int displayId = 0}) =>
      enterFullscreen(displayId: displayId);

  @override
  Future<void> leaveFullscreenFast() => leaveFullscreen();

  /// 设置原生状态变化回调。
  ///
  /// DesktopFullscreenAdapter 通过此 setter 注册回调，
  /// 当 GdkWindow state-changed 信号触发时收到通知。
  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    _onNativeCallback = callback;
  }

  // ─── FullscreenDriver 接口实现 ───

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    // D-P12: 使用 GTK fullscreen 原生 API
    // 不等待确认 — 状态确认由 Adapter 的三级确认链处理
    await _plugin.setFullScreen(true);
  }

  @override
  Future<void> leaveFullscreen() async {
    await _plugin.setFullScreen(false);
  }

  @override
  Future<bool> queryFullscreen() async {
    // 优先查询插件的真实 GDK 状态 (D-P12)
    try {
      return await _plugin.isFullScreen();
    } on Exception catch (e) {
      debugPrint(
        '[LinuxFullscreenDriver] plugin.isFullScreen failed: $e, '
        'falling back to window_manager',
      );
      // 回退到 window_manager
      try {
        return await _wm.isFullScreen();
      } on Exception catch (e2) {
        debugPrint('[LinuxFullscreenDriver] wm.isFullScreen also failed: $e2');
        return false;
      }
    }
  }

  @override
  Future<Offset> getPosition() async {
    return _wm.getPosition();
  }

  @override
  Future<Size> getSize() async {
    return _wm.getSize();
  }

  @override
  Future<void> setBounds(Offset? position, Size? size) async {
    await _wm.setBounds(null, position: position, size: size);
  }

  @override
  Future<void> maximize() async {
    await _wm.maximize();
  }

  @override
  Future<void> restore() async {
    await _wm.restore();
  }

  @override
  Future<void> focus() async {
    await _wm.focus();
  }

  @override
  Future<bool> isMaximized() async {
    return _wm.isMaximized();
  }

  @override
  Future<bool> isMinimized() async {
    return _wm.isMinimized();
  }

  // ─── 能力查询 ───

  /// 返回 Linux 平台全屏能力。
  ///
  /// 使用 GTK fullscreen/unfullscreen 原生 API，
  /// 通过 GdkWindow state-changed 信号确认状态。
  /// WM 差异通过三级确认链覆盖。
  @override
  FullscreenCapability capabilities() {
    return FullscreenCapability(
      supportsFullscreen: true,
      supportsMultiWindow: false,
      supportsMultiDisplay: true,
      supportsExclusive: false,
      requiresUserGesture: false,
      platformNotes:
          'GTK fullscreen via fullscreen_window plugin. '
          'WM: $_wmInfo. '
          'Three-tier confirmation (callback -> poll -> timeout). '
          'Tiling WMs (i3, Sway) may have non-standard behavior.',
    );
  }

  // ─── Lifecycle ───

  /// Linux 驱动无显示器缓存。
  @override
  void clearMonitorCache() {}

  @override
  Future<({bool isMaximized, Offset position, Size size})> captureSnapshot() async {
    return (
      isMaximized: await isMaximized(),
      position: await getPosition(),
      size: await getSize(),
    );
  }

  /// 释放资源 — 取消流订阅。
  @override
  void dispose() {
    _stateStreamSub?.cancel();
    _stateStreamSub = null;
    _onNativeCallback = null;
  }
}
