import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'window_mode.dart';

/// 窗口状态容器 — 组合所有窗口相关 ValueNotifier。
///
/// WindowService 持有此类，UI 层监听。
///
/// 设计约束:
/// - 纯状态容器，不含业务逻辑
/// - 不可继承（final class）
/// - mode 是窗口模式的 SSOT（isMaximized 通过 mode.value 读取）
final class WindowState {
  WindowState({
    Size initialSize = const Size(1280, 752), // 720 内容高度 + 32px 标题栏 = 16:9
  }) : _windowSize = ValueNotifier(initialSize);

  // ─── 核心状态 ───

  /// 当前窗口模式（SSOT）。
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);

  /// 窗口尺寸。
  final ValueNotifier<Size> _windowSize;
  ValueNotifier<Size> get windowSize => _windowSize;

  // ─── 交互状态 ───

  /// 当前连续用户 resize 会话的单调标识；0 表示尚未开始。
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);

  /// 当前是否处于用户拖拽调整窗口大小的会话中。
  final ValueNotifier<bool> isResizing = ValueNotifier(false);

  /// 当前窗口是否保持置顶。
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  // ─── Lifecycle ───

  bool _disposed = false;
  bool get disposed => _disposed;

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
