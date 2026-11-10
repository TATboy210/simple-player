/// 窗口边缘 resize 方向 — 自有枚举，不泄漏 nativeapi 类型。
///
/// 仅 [WindowPlatformProfile.needsResizeHotZones] 为真的平台（Linux
/// frameless）由 UI 热区消费；Windows/macOS 的系统 resize 边缘走原生路径。
enum WindowResizeEdge {
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
