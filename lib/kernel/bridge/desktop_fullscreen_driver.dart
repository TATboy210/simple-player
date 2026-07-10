import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../models/fullscreen_capability.dart';
import 'fullscreen_driver.dart';

/// Desktop 平台全屏驱动 — 使用 window_manager 包实现。
///
/// 封装所有 window_manager 调用，DesktopFullscreenAdapter 通过此驱动
/// 与原生窗口管理器交互，不直接调用 windowManager。
///
/// 设计约束:
/// - 实现 FullscreenDriver 抽象接口
/// - 不持有 WindowBridge 引用 (P0-4)
/// - 所有状态查询通过 windowManager API，不依赖外部状态
/// - 使用 window_manager 跨平台 API (setFullScreen/isFullScreen)
class DesktopFullscreenDriver implements FullscreenDriver {
  /// 创建 DesktopFullscreenDriver。
  ///
  /// [wm] 可选参数，用于测试注入 mock。
  /// 默认使用 window_manager 包的全局 windowManager 实例。
  DesktopFullscreenDriver({WindowManager? wm}) : _wm = wm ?? windowManager;

  final WindowManager _wm;

  @override
  Future<void> enterFullscreen({int displayId = 0}) async {
    await _wm.setFullScreen(true);
  }

  @override
  Future<void> leaveFullscreen() async {
    await _wm.setFullScreen(false);
  }

  @override
  Future<bool> queryFullscreen() async {
    return _wm.isFullScreen();
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

  // ─── 回调桥接 ───

  /// window_manager fallback 驱动不需要原生回调机制 (D-P11)。
  ///
  /// 接受但不使用回调 — 与 WindowsFullscreenDriver 行为一致。
  @override
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    // fallback 驱动无需回调
  }

  // ─── 能力查询 ───

  /// 返回 window_manager fallback 的默认能力。
  ///
  /// 作为通用 fallback，不报告平台特定能力。
  @override
  FullscreenCapability capabilities() {
    return const FullscreenCapability();
  }
}
