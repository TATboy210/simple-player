/// 平台全屏能力查询结果 — 每平台返回真实能力。
///
/// 用于 UI 决定是否显示全屏按钮、是否允许多窗口全屏等。
/// Phase C 平台适配时每端返回真实值。
final class FullscreenCapability {
  const FullscreenCapability({
    this.supportsFullscreen = true,
    this.supportsMultiWindow = false,
    this.supportsMultiDisplay = false,
    this.supportsExclusive = false,
    this.requiresUserGesture = false,
    this.platformNotes,
  });

  /// 平台是否支持全屏。
  final bool supportsFullscreen;

  /// 是否支持多窗口同时全屏。
  final bool supportsMultiWindow;

  /// 是否支持指定显示器全屏。
  final bool supportsMultiDisplay;

  /// 是否支持独占全屏模式。
  final bool supportsExclusive;

  /// 是否需要用户手势触发（Web 限制）。
  final bool requiresUserGesture;

  /// 平台特定说明（如 macOS 全屏动画行为）。
  final String? platformNotes;
}
