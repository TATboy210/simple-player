import 'dart:ui';

import 'package:flutter/foundation.dart';


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
///
/// ## 单包架构（2026-09-05 迁移，替代 2026-09-03 双包方案）
///
/// 本接口的实现（[WindowService]）之下是 **window_frame_kit** 单包
/// （window_manager 0.5.2 verbatim 底座 + FrameController frame 嫁接）：
///
/// - **FrameController 命中与视觉域**（`WindowOptions customFrame: true`
///   接线）：原生 NCCALCSIZE 无边框（无主题色描边、无 Win11 顶部内缩）、
///   四边四角 DPI 感知 WM_NCHITTEST 缩放、协作式 GETMINMAXINFO
///   （setMinimumSize 真正生效，无双包时代的 minSize 双通道同步）、
///   全屏双路径禁缩放。
/// - **窗口事件与状态域**：WindowListener 事件流
///   （maximize/resize/move/close/focus/blur）、setPreventClose 关闭拦截、
///   几何读写（setBounds/setSize/getPosition）、置顶、最小化、窗口移动
///   （startDragging）——与原 window_manager 同名同语义。
///
/// UI 层约定：一切**能力调用**（拖动/模式切换/置顶/关闭）必须经本接口，
/// 禁止直接持有 `windowManager` 全局单例，以保持可替换性。
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
