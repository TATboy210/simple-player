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
/// ## 窗口层架构边界（2026-10 迁移至 nativeapi 0.5.2，取代 window_frame_kit）
///
/// 本接口的实现（[WindowService]）只经 `NativeWindowHost` 端口触达平台窗口，
/// 生产实现 `NativeApiWindowHost` 封装 nativeapi（纯 Dart FFI，C++ 核心由
/// cnativeapi 构建钩子从源码编译，无 Flutter 插件/MethodChannel）：
///
/// - **视觉与命中域**（仅 Windows）：`TitleBarStyle.hidden` 保留原生 sizing
///   frame（Aero Snap、系统缩放），顶边带交给客户区并命中 HTTOP；最大化贴合
///   工作区；Win10 关 DWM frame 防主题色顶线。最小尺寸经 WM_GETMINMAXINFO。
/// - **事件与状态域**：最大化/恢复/缩放/焦点/关闭请求事件（关闭请求同步
///   取消默认销毁，持久化完成后退出）、几何读写、置顶、最小化、全屏、
///   窗口移动（startDragging）。
///
/// UI 层约定：一切窗口能力调用必须经本接口，禁止直接依赖 nativeapi，
/// 以保持可替换性与可测试性（测试注入 fake 端口）。
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

  /// 上报标题栏可拖区（逻辑像素，Flutter 视图坐标）；null 清除。
  ///
  /// 返回平台是否原生接管该区域的拖动/双击最大化/系统菜单（Windows）。
  /// 返回 false 时标题栏继续以手势调用 [startDragging] 兜底。
  bool setTitleBarDragRegion(Rect? logicalRect, double devicePixelRatio);

  /// 释放窗口资源；重复调用安全。
  void dispose();
}
