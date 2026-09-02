/// DWM 能力探测门面 + 数据类 — Phase 6 (ENAB-01)
///
/// Platform-aware facade that probes DWM attribute availability at startup
/// via Dart FFI (D-01). Exposes an immutable [DwmCapabilitySnapshot] on a
/// [ValueNotifier] so Phase 7/8 attribute gates can read it without wrapping.
library;

import 'package:flutter/foundation.dart';

import 'dwm_capabilities_probe.dart';

/// Win11 build 门槛 — DWM 属性可用性阈值（ENAB-01 boundary）
///
/// Single source of truth for the Win10/Win11 threshold. Build 21999 = Win10
/// (all attribute booleans false), build 22000 = Win11 (booleans reflect
/// attribute probes). One step either side is the test boundary.
const int kWin11BuildFloor = 22000;

/// DWM 能力快照 — 启动期一次性探测的不可变结果
///
/// Immutable snapshot of DWM capability probe results. Produced once at
/// startup by [DwmCapabilitiesProbe] via Dart FFI (D-01). All fields are
/// final; the [isWin11OrLater] getter derives from [buildNumber] and
/// [kWin11BuildFloor].
final class DwmCapabilitySnapshot {
  /// 创建不可变的 DWM 能力快照
  ///
  /// Creates an immutable snapshot of DWM attribute availability.
  const DwmCapabilitySnapshot({
    required this.buildNumber,
    required this.supportsBorderColor,
    required this.supportsCornerPreference,
    required this.supportsCaptionColor,
    required this.supportsTextColor,
  });

  /// Windows build number (RtlGetVersion dwBuildNumber, integer-exact)
  final int buildNumber;

  /// DWMWA_BORDER_COLOR (34) 可用 — Win11 22000+
  final bool supportsBorderColor;

  /// DWMWA_WINDOW_CORNER_PREFERENCE (33) 可用 — Win11 22000+
  final bool supportsCornerPreference;

  /// DWMWA_CAPTION_COLOR (35) 可用 — Win11 22000+
  final bool supportsCaptionColor;

  /// DWMWA_TEXT_COLOR (36) 可用 — Win11 22000+
  final bool supportsTextColor;

  /// 是否 Win11 或更高版本 — build 号 ≥ [kWin11BuildFloor]
  ///
  /// Returns true when [buildNumber] >= [kWin11BuildFloor] (22000).
  bool get isWin11OrLater => buildNumber >= kWin11BuildFloor;
}

/// Linux compositor 能力探测占位 — Phase 11 对等形态（D-01 peer slot）
///
/// Linux compositor capability probe placeholder. NOT implemented this
/// phase — exists so the facade's platform switch has a Linux branch that
/// compiles. Phase 11 will implement the real Wayland/X11/gamescope probe
/// with an equivalent Dart-side snapshot structure.
class LinuxCompositorCapabilities {
  const LinuxCompositorCapabilities();

  /// 返回 null — Phase 11 将返回真实的 compositor 快照
  ///
  /// Returns null — Phase 11 will return a real compositor snapshot.
  DwmCapabilitySnapshot? probe() => null;
}

/// DWM 能力探测门面 — 平台感知单例（D-01）
///
/// Platform-aware singleton facade following [ThumbnailService]'s lazy
/// platform-select pattern. On Windows, delegates to [DwmCapabilitiesProbe]
/// (FFI leaf). On Linux/macOS, delegates to [LinuxCompositorCapabilities]
/// (Phase 11 placeholder). Exposes [snapshot] as an identity-preserved
/// [ValueNotifier] — Phase 7/8 attribute gates addListener directly.
class DwmCapabilities {
  DwmCapabilities._();

  static final DwmCapabilities _instance = DwmCapabilities._();

  /// 全局单例访问
  static DwmCapabilities get I => _instance;

  /// 探测结果 notifier — null until [probe] is called
  final ValueNotifier<DwmCapabilitySnapshot?> _snapshot =
      ValueNotifier<DwmCapabilitySnapshot?>(null);

  /// 探测结果 — 同一 notifier 实例，不包装（identity-preservation）
  ///
  /// The probe result notifier; forwarded directly (no wrapping).
  /// Phase 7/8 attribute gates addListener on THIS instance.
  ValueNotifier<DwmCapabilitySnapshot?> get snapshot => _snapshot;

  /// 缓存的平台探测器实例（Windows FFI leaf or Linux placeholder）
  Object? _probeImpl;

  /// 延迟初始化的平台探测器 — 首次访问时按 [defaultTargetPlatform] 选择
  Object get _probe {
    final existing = _probeImpl;
    if (existing != null) return existing;
    final created = switch (defaultTargetPlatform) {
      TargetPlatform.windows => DwmCapabilitiesProbe(),
      TargetPlatform.linux || TargetPlatform.macOS =>
        const LinuxCompositorCapabilities(),
      _ => const LinuxCompositorCapabilities(),
    };
    _probeImpl = created;
    return created;
  }

  /// 执行启动期 DWM 能力探测（one-shot, synchronous FFI, D-01）
  ///
  /// Runs the one-shot startup DWM capability probe. On Windows, calls
  /// [DwmCapabilitiesProbe.probe] via FFI. On Linux/macOS, returns null
  /// (Phase 11 placeholder). Writes the result to [_snapshot].
  void probe() {
    final impl = _probe;
    _snapshot.value = switch (impl) {
      final DwmCapabilitiesProbe p => p.probe(),
      final LinuxCompositorCapabilities p => p.probe(),
      _ => null,
    };
  }
}
