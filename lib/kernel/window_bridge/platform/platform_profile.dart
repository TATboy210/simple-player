import 'dart:io' show Platform;

/// Windows 11 起始内部版本号 — 低于此值的 Windows 10 走无 DWM frame 模式。
const int kWindows11Build = 22000;

/// 平台差异画像 — 窗口层唯一允许出现平台判定的地方（契约见 CONTRACT.md）。
///
/// service/port 层禁止 `Platform.isX`：一切平台分支在 [detect] 收口为
/// 纯数据，协作者只消费布尔语义。探测闭包全部可注入（测试不触真实
/// Platform/environment）。
class WindowPlatformProfile {
  const WindowPlatformProfile({
    required this.dropDwmFrame,
    required this.supportsWindowPositioning,
    required this.needsResizeHotZones,
  });

  /// Win10 去 DWM frame 防主题色顶线（init 顺序契约：hasShadow=false 先于
  /// hideTitleBar，由 WindowService 保证）。
  final bool dropDwmFrame;

  /// 窗口定位语义是否可用。Wayland 下 x/y 恒 0（compositor 管位置）→
  /// 恢复只 setSize、落盘 position=null。误判方向安全（少恢复位置不丢尺寸）。
  final bool supportsWindowPositioning;

  /// 是否需要 UI 层挂边缘 resize 热区。Linux frameless（decorated=FALSE 或
  /// 隐藏 CSD headerbar）后无系统 resize 边缘，需热区调 startResizing；
  /// Windows 保留 sizing frame、macOS hidden 保留 frame，均为 false。
  final bool needsResizeHotZones;

  /// 生产探测。[operatingSystem]/[osVersion]/[environment] 可注入测试替身。
  factory WindowPlatformProfile.detect({
    String Function()? operatingSystem,
    String Function()? osVersion,
    Map<String, String> Function()? environment,
  }) {
    final os = (operatingSystem ?? () => Platform.operatingSystem)();
    final isWindows = os == 'windows';
    final isLinux = os == 'linux';
    final env = (environment ?? () => Platform.environment)();
    return WindowPlatformProfile(
      dropDwmFrame: isWindows &&
          _isWindows10((osVersion ?? () => Platform.operatingSystemVersion)()),
      supportsWindowPositioning: !(isLinux && env.containsKey('WAYLAND_DISPLAY')),
      needsResizeHotZones: isLinux,
    );
  }

  /// 全能力画像 — 测试/降级用（Windows 11 语义）。
  static const WindowPlatformProfile fullSupport = WindowPlatformProfile(
    dropDwmFrame: false,
    supportsWindowPositioning: true,
    needsResizeHotZones: false,
  );

  /// operatingSystemVersion 形如 '"Windows 10 Pro" 10.0 (Build 19045)'。
  static bool _isWindows10(String version) {
    final match = RegExp(r'Build (\d+)').firstMatch(version);
    final build = int.tryParse(match?.group(1) ?? '');
    return build != null && build < kWindows11Build;
  }
}
