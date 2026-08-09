import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'window_mode.dart';

/// 窗口管理抽象接口 — UI 层依赖此接口，不依赖具体实现
///
/// 实现方：[WindowService]（Win32 真实实现）、FakeWindowService（测试替身）。
///
/// Contract:
/// - All state is exposed via [ValueNotifier] getters; widgets rebuild through `ValueListenableBuilder`.
/// - Command methods return `Future<void>` and are safe to call concurrently; ordering is implementation-defined.
/// - [dispose] MUST be called once when the bridge is no longer needed; calling commands after dispose is undefined.
abstract class WindowBridge {
  // ─── 5 个状态 ───

  /// 当前窗口模式（普通/最大化/全屏等）
  ///
  /// Contract: never null; changes notify all attached `ValueListenableBuilder` listeners.
  ValueNotifier<WindowMode> get mode;

  /// 当前窗口尺寸（像素）
  ///
  /// Contract: updated after resize completes; during drag-resize see [isResizing].
  ValueNotifier<Size> get windowSize;

  /// 窗口是否正在被用户拖拽调整大小
  ///
  /// Contract: `true` between drag-start and drag-end; useful for suppressing layout thrashing.
  ValueNotifier<bool> get isResizing;

  /// 当前连续 resize 会话的单调标识；0 表示尚未发生用户 resize。
  ///
  /// Contract: read-only diagnostic correlation source; it must not drive UI layout.
  ValueListenable<int> get resizeSessionId;

  /// 窗口是否置顶
  ///
  /// Contract: toggled via [setAlwaysOnTop]; persists across mode changes.
  ValueNotifier<bool> get isAlwaysOnTop;

  /// 当前是否全屏 — 从 [mode] 派生，单一数据源
  ///
  /// Contract: read-only convenience; `true` iff `mode.value == WindowMode.fullscreen`.
  bool get isFullscreen;

  // ─── 7 个命令 ───

  /// 初始化窗口（恢复持久化状态、注册平台回调）
  ///
  /// Contract: MUST be called once before any other command; calling twice is a no-op.
  Future<void> init();

  /// 切换窗口模式（普通/最大化/全屏等）
  ///
  /// Contract: [target] is applied atomically; notifies [mode], [windowSize], [isFullscreen] listeners.
  Future<void> setMode(WindowMode target);

  /// 设置窗口置顶状态
  ///
  /// Contract: [value] persisted across mode changes; notifies [isAlwaysOnTop] listener.
  Future<void> setAlwaysOnTop(bool value);

  /// 设置窗口宽高比（用于视频播放时锁定比例）
  ///
  /// Contract: [ratio] > 0; 0 or negative resets to free-resize. Delegates to platform `setAspectRatio`.
  Future<void> setAspectRatio(double ratio);

  /// 最小化窗口
  ///
  /// Contract: platform-level minimize; does not change [mode] notifier.
  Future<void> minimize();

  /// 关闭窗口
  ///
  /// Contract: triggers platform close sequence; after completion the bridge is unusable.
  Future<void> close();

  /// 启动窗口拖拽移动（标题栏拖拽）
  ///
  /// Contract: delegates to platform drag; no-op if platform does not support programmatic drag.
  Future<void> startDragging();

  /// 释放所有资源（取消回调、清理状态）
  ///
  /// Contract: MUST be called exactly once; calling any command after dispose is undefined behavior.
  void dispose();
}
