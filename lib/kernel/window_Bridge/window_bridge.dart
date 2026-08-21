import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'window_constants.dart';

/// 窗口模式：普通窗口、最大化或由 media_kit 承担的全屏。
enum WindowMode {
  /// 普通窗口。
  windowed,

  /// 最大化窗口。
  maximized,

  /// media_kit 视频 route 的全屏语义。
  fullscreen;

  bool get isWindowed => this == WindowMode.windowed;
  bool get isMaximized => this == WindowMode.maximized;
  bool get isFullscreen => this == WindowMode.fullscreen;
}

/// 面向 UI 的窗口管理抽象，隐藏平台窗口库的具体实现。
abstract interface class WindowBridge {
  /// 当前窗口模式；全屏状态由 media_kit 同步，而非本接口执行原生切换。
  ValueListenable<WindowMode> get mode;

  /// 当前窗口外部尺寸（逻辑像素）。
  ValueListenable<Size> get windowSize;

  /// 当前是否处于用户拖拽调整大小阶段。
  ValueListenable<bool> get isResizing;

  /// 当前 resize 会话的递增标识。
  ValueListenable<int> get resizeSessionId;

  /// 当前是否置顶。
  ValueListenable<bool> get isAlwaysOnTop;

  /// 当前是否处于语义上的全屏模式。
  bool get isFullscreen;

  /// 初始化窗口并注册平台回调。
  Future<void> init();

  /// 切换普通窗口或最大化窗口。
  Future<void> setMode(WindowMode target);

  /// 同步 media_kit 当前真实全屏状态，不执行原生全屏操作。
  void syncFullscreenState(bool isFullscreen);

  /// 设置窗口置顶状态。
  Future<void> setAlwaysOnTop(bool value);

  /// 最小化窗口。
  Future<void> minimize();

  /// 关闭窗口。
  Future<void> close();

  /// 开始拖动窗口。
  Future<void> startDragging();

  /// 释放窗口资源；重复调用安全。
  void dispose();
}

/// 旧调用方使用的可变状态兼容入口。
@Deprecated('WindowService owns active state; prefer WindowBridge.')
class WindowState {
  /// 创建窗口状态。
  WindowState({Size initialSize = defaultWindowSize})
    : windowSize = ValueNotifier(initialSize);

  /// 当前模式。
  final ValueNotifier<WindowMode> mode = ValueNotifier(WindowMode.windowed);

  /// 当前尺寸。
  final ValueNotifier<Size> windowSize;

  /// 当前 resize 会话标识。
  final ValueNotifier<int> resizeSessionId = ValueNotifier(0);

  /// 当前是否 resizing。
  final ValueNotifier<bool> isResizing = ValueNotifier(false);

  /// 当前是否置顶。
  final ValueNotifier<bool> isAlwaysOnTop = ValueNotifier(false);

  /// 是否已经释放。
  bool disposed = false;

  /// 释放状态 notifier。
  void dispose() {
    if (disposed) return;
    disposed = true;
    mode.dispose();
    windowSize.dispose();
    resizeSessionId.dispose();
    isResizing.dispose();
    isAlwaysOnTop.dispose();
  }
}
