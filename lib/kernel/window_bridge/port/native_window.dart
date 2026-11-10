import 'dart:ui';

import 'window_resize_edge.dart';

/// 原生窗口命令端口 — [WindowService] 依赖的全部窗口能力。
///
/// 几何一律为逻辑像素。生产实现见 `nativeapi_window.dart`；测试用手写 fake。
///
/// **纯命令通道**（契约 1）：不含任何事件流成员 — nativeapi 的逐步几何事件
/// 是边缘拖拽卡顿根因，本层三平台统一零订阅；几何变化检测走引擎指标
/// （WindowMetricsObserver），关门走 runner 专线（CloseNotifierBridge）。
/// 模式落定不等待事件：nativeapi 命令为同步 FFI marshal，状态用现查
/// （[isMaximized] 等）校准。
///
/// 约束：会跨线程 marshal 的属性（如 [isFullScreen]）读写可能阻塞窗口线程，
/// 不要放进 resize 事件热路径。
abstract interface class NativeWindow {
  void show();
  void hide();
  void focus();

  void maximize();
  void unmaximize();
  void minimize();
  bool get isMaximized;
  bool get isMinimized;

  bool get isFullScreen;
  set isFullScreen(bool value);

  bool get isAlwaysOnTop;
  set isAlwaysOnTop(bool value);

  /// 窗口外框矩形（含位置）。
  Rect get bounds;
  set bounds(Rect value);

  /// 仅改尺寸，位置由 [center] 另行决定。
  void setSize(Size size);
  void center();

  /// 窗口最小尺寸。注意它与窗口对象寿命绑定，实现需长期持有同一窗口。
  set minimumSize(Size value);

  /// 关闭 DWM 阴影/边框（Win10 防主题色顶线）。须先于 [hideTitleBar] 调用。
  set hasShadow(bool value);

  /// 隐藏原生标题栏。Windows 保留 sizing frame 与 Aero Snap；Linux 转为
  /// decorated(FALSE)（边缘 resize 由 UI 热区经 [startResizing] 补）；
  /// macOS 隐藏标题栏外观并强制 setMovable:NO（拖动走 [startDragging]）。
  void hideTitleBar();

  /// 各显示器的工作区（不含任务栏）。查询失败可抛 Exception，调用方降级。
  List<Rect> get workAreas;

  /// 进入系统拖动循环（Aero Snap / Wayland 移动由系统处理）。
  void startDragging();

  /// 从指定边缘进入系统 resize 循环 — Linux frameless 的热区专用入口
  /// （Windows/macOS 有系统 resize 边缘，UI 不挂热区）。
  void startResizing(WindowResizeEdge edge);

  /// 执行系统标题栏双击动作（最大化/还原）。
  void performTitleBarDoubleClick();

  /// 释放资源；重复调用安全。
  void dispose();
}
