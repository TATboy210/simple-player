// macOS 原生全屏驱动 — fullscreen_window 插件 + NSWindowDelegate 回调确认。
//
// 实现 FullscreenDriver 接口，使用 macOS 原生全屏动画 (D-P10)。
// 通过 NSWindow delegate 回调确认状态变化 (D-P09)，不乐观更新。
//
// 设计:
// - _plugin: FullScreenWindowPlatform — 全屏进出 + 状态查询 + 回调流
// - _wm: WindowManager — 其他窗口操作 (getPosition/getSize/setBounds 等)
// - onNativeStateChanged 回调通知 DesktopFullscreenAdapter (D-P09)
// - delegate 回调通过 _plugin.onFullScreenChanged 流接收

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/fullscreen_capability.dart';
import '../fullscreen_driver.dart';

/// macOS 原生全屏驱动 — fullscreen_window 插件 + NSWindowDelegate 回调。
///
/// 使用 macOS 原生全屏动画 (绿色按钮效果，D-P10)，
/// 通过 NSWindow delegate 回调确认全屏状态变化 (D-P09)。
///
/// 注入依赖:
/// ```dart
/// final driver = MacosFullscreenDriver(
///   plugin: mockPlugin,
///   wm: mockWindowManager,
/// );
/// ```
class MacosFullscreenDriver implements FullscreenDriver {
  /// 创建 MacosFullscreenDriver。
  ///
  /// [plugin] fullscreen_window 插件平台接口，用于全屏操作和回调。
  /// [wm] window_manager 窗口管理器，用于其他窗口操作。
  MacosFullscreenDriver({FullScreenWindowPlatform? plugin, WindowManager? wm})
    : _plugin = plugin ?? FullScreenWindowPlatform.instance,
      _wm = wm ?? windowManager {
    // 订阅原生回调流 (D-P09)
    // windowId=0 单窗口场景
    _stateStreamSub = _plugin.onFullScreenChanged.listen((isFullscreen) {
      debugPrint(
        '[MacosFullscreenDriver] native callback: isFullscreen=$isFullscreen',
      );
      _onNativeCallback?.call(0, isFullscreen);
    });
  }

  /// fullscreen_window 插件 — 全屏操作 + 回调流。
  final FullScreenWindowPlatform _plugin;

  /// window_manager — 其他窗口操作。
  final WindowManager _wm;

  /// 原生回调流订阅。
  StreamSubscription<bool>? _stateStreamSub;

  /// 原生回调通知 Adapter 的回调 (D-P09)。
  ///
  /// 签名: (windowId, isFullscreen)
  /// 由 DesktopFullscreenAdapter.onNativeFullScreenChanged 设置。
  void Function(int windowId, bool isFullscreen)? _onNativeCallback;

  // ─── 回调桥接 (D-P09) ───

  /// 设置原生状态变化回调。
  ///
  /// DesktopFullscreenAdapter 通过此 setter 注册回调，
  /// 当 NSWindowDelegate 触发时收到通知。
  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    _onNativeCallback = callback;
  }

  // ─── FullscreenDriver 接口实现 ───

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    // D-P10: 使用 macOS 原生 toggleFullScreen: 动画
    // 不等待动画完成 — 状态确认由 Adapter 的三级确认链处理
    await _plugin.setFullScreen(true);
  }

  @override
  Future<void> leaveFullscreen() async {
    await _plugin.setFullScreen(false);
  }

  @override
  Future<bool> queryFullscreen() async {
    // 优先查询插件的真实状态 (styleMask 检查)
    try {
      return await _plugin.isFullScreen();
    } on Exception catch (e) {
      debugPrint(
        '[MacosFullscreenDriver] plugin.isFullScreen failed: $e, '
        'falling back to window_manager',
      );
      // 回退到 window_manager — 也做异常保护
      try {
        return await _wm.isFullScreen();
      } on Exception catch (e2) {
        debugPrint('[MacosFullscreenDriver] wm.isFullScreen also failed: $e2');
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

  /// 返回 macOS 平台全屏能力。
  ///
  /// macOS 使用原生全屏动画 (绿色按钮效果)，
  /// 通过 NSWindow delegate 回调确认状态。
  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability(
      supportsFullscreen: true,
      supportsMultiWindow: false,
      supportsMultiDisplay: true,
      supportsExclusive: false,
      requiresUserGesture: false,
      platformNotes:
          'Native macOS fullscreen animation (green button). '
          'Confirmation via NSWindow delegate callback. '
          'Transition time ~700ms.',
    );
  }

  // ─── Lifecycle ───

  /// macOS 驱动无显示器缓存。
  @override
  void clearMonitorCache() {}

  /// 释放资源 — 取消流订阅。
  @override
  void dispose() {
    _stateStreamSub?.cancel();
    _stateStreamSub = null;
    _onNativeCallback = null;
  }
}
