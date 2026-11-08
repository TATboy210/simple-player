import 'package:flutter/foundation.dart';

/// 窗口模式：普通窗口、最大化或全屏。
enum WindowMode {
  /// 普通窗口。
  windowed,

  /// 最大化窗口。
  maximized,

  /// 原生全屏 (标题栏收起、视频铺满)。
  fullscreen;

  bool get isWindowed => this == WindowMode.windowed;
  bool get isMaximized => this == WindowMode.maximized;
  bool get isFullscreen => this == WindowMode.fullscreen;
}

/// 面向 UI 的窗口管理抽象，隐藏平台窗口库的具体实现。
///
/// 生产实现 [WindowService] 经 [NativeWindow] 端口调用 nativeapi。UI 层约定：一切窗口能力必须经本接口，禁止直接依赖
/// nativeapi；生命周期（init/reveal/dispose）归组合根，不在本接口内。
abstract interface class WindowBridge {
  /// 当前窗口模式（单一数据源，原生最大化/全屏事件均映射到此）。
  ValueListenable<WindowMode> get mode;

  /// 当前是否处于用户拖拽调整大小阶段。
  ValueListenable<bool> get isResizing;

  /// 当前 resize 会话的递增标识。
  ValueListenable<int> get resizeSessionId;

  /// 当前是否置顶。
  ValueListenable<bool> get isAlwaysOnTop;

  /// 切换窗口模式（普通 / 最大化 / 全屏），等到原生状态落定后返回。
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
  /// 持有者销毁前应调用以摘除监听.
  void Function() addClosingListener(Future<void> Function() listener);

  /// 开始拖动窗口（进入系统拖动循环，Aero Snap 由系统处理）。
  Future<void> startDragging();

  /// 执行系统标题栏双击动作（最大化/还原）。
  void titleBarDoubleClick();
}
