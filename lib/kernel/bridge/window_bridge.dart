import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'window_mode.dart';

/// 窗口管理抽象接口 — UI 层依赖此接口，不依赖具体实现。
///
/// 实现方：
/// - [WindowService] — Win32 真实实现
/// - 测试中的 FakeWindowService — 无平台依赖的测试替身
abstract class WindowBridge {
  // ─── 5 个状态 ───
  ValueNotifier<WindowMode> get mode;
  ValueNotifier<Size> get windowSize;
  ValueNotifier<bool> get isResizing;
  ValueNotifier<bool> get isAlwaysOnTop;

  /// 当前是否全屏 — 从 [mode] 派生，单一数据源。
  bool get isFullscreen;

  // ─── 7 个命令 ───
  // Importers: WindowService, player_screen.dart, test fakes
  // Affected API: setAspectRatio is new, wraps windowManager.setAspectRatio
  Future<void> init();
  Future<void> setMode(WindowMode target);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setAspectRatio(double ratio);
  Future<void> minimize();
  Future<void> close();
  Future<void> startDragging();
  void dispose();
}
