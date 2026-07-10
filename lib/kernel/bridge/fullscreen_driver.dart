import 'dart:ui';

import '../models/fullscreen_capability.dart';

/// 全屏驱动抽象接口 — 封装平台原生全屏操作。
///
/// DesktopFullscreenAdapter 通过此接口与窗口管理器交互，
/// 不直接依赖 window_manager 或 fullscreen_window。
///
/// 设计约束:
/// - 与 WindowBridge 并列，不继承
/// - 每个方法对应一个原生调用，不做状态管理
/// - Phase B 使用 window_manager 实现，Phase C 可替换为平台特定驱动
/// - 不持有 WindowBridge 引用 (P0-4)
abstract class FullscreenDriver {
  /// 进入全屏。
  ///
  /// [displayId] 目标显示器 ID，默认 0（主显示器）。
  Future<void> enterFullscreen({int displayId = 0});

  /// 退出全屏。
  Future<void> leaveFullscreen();

  /// 查询当前是否全屏。
  ///
  /// 返回 true 表示处于全屏状态。
  Future<bool> queryFullscreen();

  /// 获取窗口当前位置。
  Future<Offset> getPosition();

  /// 获取窗口当前尺寸。
  Future<Size> getSize();

  /// 设置窗口位置和尺寸。
  ///
  /// [position] 为 null 时只设置尺寸。
  /// [size] 为 null 时只设置位置。
  Future<void> setBounds(Offset? position, Size? size);

  /// 最大化窗口。
  Future<void> maximize();

  /// 恢复窗口（从最大化/最小化恢复到普通状态）。
  Future<void> restore();

  /// 聚焦窗口。
  Future<void> focus();

  /// 查询当前是否最大化。
  ///
  /// 通过 windowManager.isMaximized() 查询，不依赖 WindowBridge。
  Future<bool> isMaximized();

  /// 当前是否最小化。
  ///
  /// P2-8: RST-04 需要检测 minimized 状态。
  Future<bool> isMinimized();

  /// 设置原生全屏状态变化回调 — 用于三级确认链的 Level 1 (D-P11)。
  ///
  /// macOS: NSWindow delegate 回调 (windowDidEnterFullScreen/windowDidExitFullScreen)
  /// Linux: GdkWindow window-state-event 信号
  /// Windows: 无需此机制 (FFI 同步操作，queryFullscreen 直接返回)
  ///
  /// [callback] 参数: (windowId, isFullscreen)
  /// 默认空实现 — 不支持原生回调的 Driver (如 WindowsFullscreenDriver) 无需覆盖。
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {
    // 默认空实现 — Windows FFI 驱动不需要回调机制
  }

  /// 获取平台全屏能力 — 每平台 Driver 返回真实值 (PLAT-04)。
  ///
  /// Phase B DesktopFullscreenDriver 返回默认值，
  /// Phase C 平台驱动返回真实能力矩阵。
  FullscreenCapability capabilities() {
    return const FullscreenCapability();
  }
}
