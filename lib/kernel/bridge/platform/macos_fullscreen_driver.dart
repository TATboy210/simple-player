// macOS 原生全屏驱动 — fullscreen_window 插件 + NSWindowDelegate 回调确认。
//
// 实现 FullscreenDriver 接口，使用 macOS 原生全屏动画 (D-P10)。
// 通过 NSWindow delegate 回调确认状态变化 (D-P09)，不乐观更新。
//
// v3 简化: 仅封装 fullscreen 操作。
// 窗口管理操作 (getPosition/getSize/setBounds 等) 由 WindowService
// 直接通过 windowManager 调用。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fullscreen_window/fullscreen_window_platform_interface.dart';

import '../../models/fullscreen_capability.dart';
import '../fullscreen_driver.dart';

/// macOS 原生全屏驱动 — fullscreen_window 插件 + NSWindowDelegate 回调。
///
/// 使用 macOS 原生全屏动画 (绿色按钮效果，D-P10)，
/// 通过 NSWindow delegate 回调确认全屏状态变化 (D-P09)。
///
/// 注入依赖:
/// ```dart
/// final driver = MacosFullscreenDriver(plugin: mockPlugin);
/// ```
class MacosFullscreenDriver implements FullscreenDriver {
  /// 创建 MacosFullscreenDriver。
  ///
  /// [plugin] fullscreen_window 插件平台接口，用于全屏操作和回调。
  MacosFullscreenDriver({FullScreenWindowPlatform? plugin})
    : _plugin = plugin ?? FullScreenWindowPlatform.instance {
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

  /// 原生回调流订阅。
  StreamSubscription<bool>? _stateStreamSub;

  /// 原生回调通知 Adapter/WindowService 的回调 (D-P09)。
  ///
  /// 签名: (windowId, isFullscreen)
  void Function(int windowId, bool isFullscreen)? _onNativeCallback;

  // ─── 能力标志 (ARCH-01) ───

  @override
  bool get supportsFastPath => false;

  @override
  Future<void> enterFullscreenFast({int displayId = 0}) =>
      enterFullscreen(displayId: displayId);

  @override
  Future<void> leaveFullscreenFast() => leaveFullscreen();

  /// 设置原生状态变化回调。
  ///
  /// WindowService 通过此 setter 注册回调，
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
    // D-P10: 使用 macOS 原生 toggleFullScreen 动画
    // 不等待动画完成 — 状态确认由 WindowService 的三级确认链处理
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
        '[MacosFullscreenDriver] plugin.isFullScreen failed: $e',
      );
      return false;
    }
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
