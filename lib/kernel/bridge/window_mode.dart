/// 窗口模式枚举 — 替代散装 bool (isFullscreen/isMaximized)。
///
/// Window presentation modes, replacing scattered boolean flags.
///
/// - `windowed`: Normal resizable window.
/// - `maximized`: OS-level maximized state.
/// - `fullscreen`: Borderless full-screen (covers taskbar).
/// - `minimized`: Minimized to taskbar.
enum WindowMode {
  /// 普通窗口。
  windowed,

  /// 最大化。
  maximized,

  /// 无边框全屏。
  fullscreen,

  /// 最小化。
  minimized;

  bool get isWindowed => this == WindowMode.windowed;
  bool get isMaximized => this == WindowMode.maximized;
  bool get isFullscreen => this == WindowMode.fullscreen;
  bool get isMinimized => this == WindowMode.minimized;
}
