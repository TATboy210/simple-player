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
/// ## 双包架构边界（BB 同款，2026-09-03 迁移）
///
/// 本接口的实现（[WindowService]）之下是两个窗口包的分工：
///
/// - **bitsdojo_window**（BDW_CUSTOM_FRAME，`windows/runner/main.cpp` 全局接线）：
///   窗口**视觉与命中域**——原生 NCCALCSIZE return 0（无边框、无系统主题色
///   描边、无顶部内缩），原生 WM_NCHITTEST 四边等宽 resize 判定，连带其
///   GETMINMAXINFO hook 要求的 minSize 双通道同步。runner 保持 Flutter 上游
///   模板，零自写窗口消息代码。
///   **取舍裁决（2026-09-03 用户裁决）**：bitsdojo 只做上述两件事，其余一切
///   ——包括标题栏拖动（窗口移动）——归 window_manager；接触面最小化，
///   日后单点替换只需动 main.cpp 一行 + WindowBorder 容器。
/// - **window_manager**：窗口**事件与状态域**——WindowListener 事件流
///   （maximize/resize/move/close/focus/blur）、setPreventClose 关闭拦截、
///   几何读写（setBounds/setSize/getPosition）、置顶、最小化、窗口移动
///   （startDragging）。
///
/// UI 层约定：widget 级视觉件（如 `WindowBorder`）可直接使用 bitsdojo 包；
/// 一切**能力调用**（拖动/模式切换/置顶/关闭）必须经本接口，禁止直接持有
/// `appWindow` / `windowManager` 全局单例，以保持可替换性。
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
