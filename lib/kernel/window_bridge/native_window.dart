import 'dart:async';
import 'dart:ui';

/// 原生窗口事件 — 只保留 [WindowService] 用得到的几类。
///
/// 与 nativeapi 的 WindowEvent 一一对应，但不暴露 nativeapi 类型，
/// 服务层因此可以脱离 FFI 做单元测试。
sealed class NativeWindowEvent {
  const NativeWindowEvent();
}

/// 窗口进入最大化。
final class NativeMaximized extends NativeWindowEvent {
  const NativeMaximized();
}

/// 窗口从最大化或最小化恢复（原生只发一个 restored，两种来源共用）。
final class NativeRestored extends NativeWindowEvent {
  const NativeRestored();
}

/// 窗口被最小化。
final class NativeMinimized extends NativeWindowEvent {
  const NativeMinimized();
}

/// 窗口尺寸变化 — 拖拽 resize 期间每个中间步都会触发，原生侧不合并。
final class NativeResized extends NativeWindowEvent {
  const NativeResized();
}

/// 窗口位置变化。
final class NativeMoved extends NativeWindowEvent {
  const NativeMoved();
}

/// 平台关闭请求（✕ / Alt+F4 / 被 runner 转成 SC_CLOSE 的 WM_CLOSE）。
final class NativeCloseRequested extends NativeWindowEvent {
  const NativeCloseRequested(this.cancel);

  /// 取消默认销毁，返回是否取消成功。必须在事件回调内**同步**调用，
  /// 回调返回后原生侧即按未取消继续关闭。
  final bool Function() cancel;
}

/// 原生窗口端口 — [WindowService] 依赖的全部窗口能力。
///
/// 几何一律为逻辑像素。生产实现见 `nativeapi_window.dart`；测试用手写 fake。
/// 约束：会跨线程 marshal 的属性（如 [isFullScreen]）读写可能阻塞窗口线程，
/// 不要放进 resize 事件热路径。
abstract interface class NativeWindow {
  /// 同步广播流 — 订阅者在原生回调内即被调用（[NativeCloseRequested.cancel]
  /// 依赖这一点）。
  Stream<NativeWindowEvent> get events;

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

  /// 隐藏原生标题栏（保留 sizing frame 与 Aero Snap）。
  void hideTitleBar();

  /// 各显示器的工作区（不含任务栏）。查询失败可抛 Exception，调用方降级。
  List<Rect> get workAreas;

  /// 进入系统拖动循环（Aero Snap 由系统处理）。
  void startDragging();

  /// 执行系统标题栏双击动作（最大化/还原）。
  void performTitleBarDoubleClick();

  /// 释放监听与事件流；重复调用安全。
  void dispose();
}
