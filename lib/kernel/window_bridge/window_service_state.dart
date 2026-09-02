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

  /// DWM 能力快照 — 启动期探测结果（null until probed）
  ///
  /// DWM capability snapshot notifier (peer to [mode]). Identity-preserved:
  /// Phase 7/8 attribute gates addListener on THIS instance directly.
  final ValueNotifier<DwmCapabilitySnapshot?> dwmCapabilities =
      ValueNotifier<DwmCapabilitySnapshot?>(null);

  bool _disposed = false;
  bool get disposed => _disposed;

  /// 当前窗口尺寸的内部写入端。
  ValueNotifier<Size> get windowSize => _windowSize;

  /// 释放所有 notifier；重复调用安全。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    mode.dispose();
    _windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
    dwmCapabilities.dispose();
  }
}
