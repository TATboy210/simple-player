import 'dart:ui';

/// 原生窗口事件 — [NativeWindowHost] 向 [WindowService] 投递的平台事件。
///
/// Platform window events, decoupled from the concrete window library so the
/// service can be driven by a hand-written fake in tests.
sealed class NativeWindowEvent {
  const NativeWindowEvent();
}

/// 窗口进入最大化。
final class NativeWindowMaximized extends NativeWindowEvent {
  const NativeWindowMaximized();
}

/// 窗口从最大化或最小化恢复 — 是否仍最大化须向宿主重新查询
/// (最大化窗口最小化后再恢复, 平台只报 restored)。
final class NativeWindowRestored extends NativeWindowEvent {
  const NativeWindowRestored();
}

/// 窗口外部尺寸变化 (交互拖拽期间连续触发)。
final class NativeWindowResized extends NativeWindowEvent {
  const NativeWindowResized();
}

/// 窗口获得焦点。
final class NativeWindowFocused extends NativeWindowEvent {
  const NativeWindowFocused();
}

/// 窗口失去焦点。
final class NativeWindowBlurred extends NativeWindowEvent {
  const NativeWindowBlurred();
}

/// 用户请求关闭窗口 (标题栏 ✕ / Alt+F4 / WM_CLOSE)。
///
/// 宿主在投递前已取消平台默认关闭; 服务完成持久化后自行终止进程。
final class NativeWindowCloseRequested extends NativeWindowEvent {
  const NativeWindowCloseRequested();
}

/// 原生窗口宿主端口 — [WindowService] 唯一的平台窗口依赖。
///
/// Narrow port over the platform window library (nativeapi in production).
/// Geometry is in logical pixels. Methods return futures so the close path can
/// apply uniform timeouts, even though the nativeapi implementation is
/// synchronous FFI.
abstract interface class NativeWindowHost {
  /// 绑定当前 Flutter 宿主窗口、应用无标题栏样式与最小尺寸，并开始投递事件。
  ///
  /// [onEvent] 在 UI isolate 上被调用。失败时抛出, 由调用方容纳。
  Future<void> attach({
    required Size minimumSize,
    required void Function(NativeWindowEvent event) onEvent,
  });

  /// 停止投递事件; 重复调用安全。
  void detach();

  Future<Size> getSize();
  Future<Offset> getPosition();
  Future<bool> isMaximized();
  Future<void> setBounds(Rect bounds);
  Future<void> setSize(Size size);
  Future<void> center();
  Future<void> setAlwaysOnTop(bool value);
  Future<void> show();
  Future<void> hide();
  Future<void> focus();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> minimize();
  Future<void> setFullScreen(bool value);
  Future<void> startDragging();

  /// 设置自绘标题栏的原生拖动区（客户区物理像素）；null 清除。
  ///
  /// 返回平台是否接管拖动区命中（Windows: runner 对该矩形回答
  /// HTCAPTION）；false 时调用方须继续以手势 + [startDragging] 兜底。
  bool setTitleBarDragRegion(Rect? physicalRect);

  /// 销毁原生窗口 (关闭拦截已生效时绕过拦截)。
  Future<void> destroy();
}
