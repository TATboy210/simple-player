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
/// ## 单包架构边界（2026-10 迁移至 window_frame_kit，取代 bitsdojo +
/// window_manager 双包）
///
/// 本接口的实现（[WindowService]）之下只有一个窗口包 window_frame_kit，
/// 它是 window_manager 0.5.2 API 的超集，且只注册**一个** WndProc delegate：
///
/// - **视觉与命中域**（`WindowOptions(customFrame: true)`，仅 Windows）：
///   原生 FrameController 接管 NCCALCSIZE（整窗即客户区、无 Win10 主题色线）、
///   NCHITTEST（四边+四角按当前 DPI 等宽缩放带）、交互缩放预同步（防撕裂）；
///   最小尺寸经 setMinimumSize 单通道真实生效。外部全屏（摘除
///   WS_OVERLAPPEDWINDOW）由 frame 自行识别为无缩放带。runner 零自写窗口
///   消息代码。
/// - **事件与状态域**（同名 `windowManager` 门面）：WindowListener 事件流
///   （maximize/resize/move/close/focus/blur）、setPreventClose 关闭拦截、
///   几何读写（setBounds/setSize/getPosition）、置顶、最小化、窗口移动
///   （startDragging）。
///
/// UI 层约定：widget 级视觉件（如 `DragToMoveArea`）可直接使用该包；一切
/// **能力调用**（模式切换/置顶/关闭）必须经本接口，禁止直接持有
/// `windowManager` 全局单例，以保持可替换性。
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

  /// 订阅窗口关闭前的持久化窗口 (v0.0.6.2) — 通用能力, 不感知订阅者业务.
  ///
  /// 在 hide/窗口几何持久化之后、destroy/进程终止之前依次 await 各监听器;
  /// 单条超时兜底, 失败记日志后继续, 绝不阻塞退出. 返回移除函数 (幂等) —
  /// 持有者销毁前应调用以摘除监听 (借用规则: notifier 持有者先于本服务销毁).
  void Function() addClosingListener(Future<void> Function() listener);

  /// 开始拖动窗口。
  Future<void> startDragging();

  /// 释放窗口资源；重复调用安全。
  void dispose();
}
