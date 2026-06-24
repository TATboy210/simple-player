/// 窗口模式枚举 — 替代散装 bool (isMaximized)。
enum WindowMode {
  /// 普通窗口。
  windowed,

  /// 最大化。
  maximized,

  /// 最小化。
  minimized;

  bool get isWindowed => this == WindowMode.windowed;
  bool get isMaximized => this == WindowMode.maximized;
  bool get isMinimized => this == WindowMode.minimized;
}
