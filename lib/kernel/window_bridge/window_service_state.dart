import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../diagnostics/dwm_capabilities.dart';
import 'window_bridge.dart';
import 'window_constants.dart';

/// WindowService 的内部可变状态容器。
///
/// 仅持有 ValueNotifier 状态与释放语义；resize 防抖、模式切换与持久化
/// 串行化分别由同目录的三个协调器负责（window_resize_coordinator.dart、
/// window_mode_coordinator.dart、window_persistence_coordinator.dart）。
final class WindowServiceState {
  /// 创建窗口状态，默认使用稳定的启动尺寸。
  WindowServiceState({Size initialSize = defaultWindowSize})
    : _windowSize = ValueNotifier(initialSize);

  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);
  final ValueNotifier<Size> _windowSize;
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);
  final ValueNotifier<bool> isResizing = ValueNotifier(false);
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  bool _disposed = false;
  bool get disposed => _disposed;

  /// 当前窗口尺寸的内部写入端。
  ValueNotifier<Size> get windowSize => _windowSize;

  /// DWM 能力快照 — 转发 DwmCapabilities 门面的同一 notifier 实例。
  ///
  /// Forwards the SAME notifier instance owned by [DwmCapabilities]
  /// (identity-preserved per CONTEXT.md D-01：Phase 7/8 属性门监听的就是
  /// 门面这一个实例，不复制不包装)。借用语义：通知器生命周期由门面持有，
  /// 本容器 [dispose] 不释放它（同 PlayerServices 不 dispose WindowBridge
  /// 的既有借用约束）。
  ValueNotifier<DwmCapabilitySnapshot?> get dwmCapabilities =>
      DwmCapabilities.I.snapshot;

  /// 释放所有 notifier；重复调用安全。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    _windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
  }
}
