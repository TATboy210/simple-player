import '../models/fullscreen_capability.dart';

/// 全屏驱动抽象接口 — 封装平台原生全屏操作。
///
/// WindowService 通过此接口与窗口管理器交互，
/// 不直接依赖 window_manager 或 fullscreen_window。
///
/// v3 简化: 仅保留 fullscreen 核心操作。
/// 窗口管理操作 (getPosition/setBounds/maximize 等) 由 WindowService
/// 直接通过 windowManager 调用，不在 Driver 接口中重复抽象。
abstract class FullscreenDriver {
  /// 释放平台事件订阅和其他原生资源。
  void dispose() {}

  /// 进入全屏。
  ///
  /// [displayId] 目标显示器 ID，默认 0（主显示器）。
  Future<void> enterFullscreen({int displayId = 0});

  /// 退出全屏。
  Future<void> leaveFullscreen();

  /// 查询当前是否全屏。
  Future<bool> queryFullscreen();

  /// 设置原生全屏状态变化回调 — 用于三级确认链的 Level 1 (D-P11)。
  ///
  /// macOS: NSWindow delegate 回调
  /// Linux: GdkWindow window-state-event 信号
  /// Windows: 无需此机制 (FFI 同步操作)
  set onNativeStateChanged(
    void Function(int windowId, bool isFullscreen)? callback,
  ) {}

  /// 是否支持快速路径全屏操作（跳过确认链）。
  ///
  /// Windows FFI 驱动同步操作，无需等待原生回调或轮询。
  bool get supportsFastPath => false;

  /// 快速进入全屏 — 跳过确认链。
  Future<void> enterFullscreenFast({int displayId = 0}) =>
      enterFullscreen(displayId: displayId);

  /// 快速退出全屏 — 跳过确认链。
  Future<void> leaveFullscreenFast() => leaveFullscreen();

  /// 获取平台全屏能力 (PLAT-04)。
  FullscreenCapability capabilities() => const FullscreenCapability();

  /// 清除显示器信息缓存 (T1)。
  ///
  /// Windows 驱动缓存 monitorFromWindow + getMonitorRect 结果，
  /// WM_DISPLAYCHANGE 时应调用此方法刷新。
  void clearMonitorCache() {}
}

/// 全屏操作结果 — sealed for exhaustive pattern matching.
///
/// 用于 WindowService._handleEnter / _handleLeave 的类型安全错误处理。
/// 替代原来的 `bool` 返回值，携带恢复状态信息。
///
/// ```dart
/// switch (result) {
///   case FullscreenSuccess() => // 全屏成功
///   case FullscreenFailure(:final restored) => // 全屏失败，restored 表示是否已恢复窗口
/// }
/// ```
sealed class FullscreenResult {
  const FullscreenResult();
}

/// 全屏操作成功。
final class FullscreenSuccess extends FullscreenResult {
  const FullscreenSuccess();
}

/// 全屏操作失败 — 携带窗口是否已恢复到原始状态。
///
/// [restored] 为 true 表示窗口已恢复到全屏前的状态，
/// 为 false 表示恢复失败或未尝试恢复。
final class FullscreenFailure extends FullscreenResult {
  /// 窗口是否已恢复到全屏前的状态。
  final bool restored;
  const FullscreenFailure({this.restored = false});
}
