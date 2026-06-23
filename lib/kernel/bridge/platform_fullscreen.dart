/// 平台全屏抽象接口 — 通过 DI 注入，解耦 FullscreenController 与平台实现。
///
/// 设计原则:
/// - enter() 返回不可变快照，用于失败回滚
/// - requiresStyleSave 能力标志，让控制器跳过不需要的保存逻辑
/// - macOS/Linux 平台内部处理状态保存/恢复，Win32 需要外部保存
import 'dart:ui';

/// 全屏操作快照 — 不可变值对象，用于回滚。
class FullscreenSnapshot {
  const FullscreenSnapshot({
    required this.windowStyle,
    required this.position,
    required this.size,
  });

  /// Win32 窗口样式 (GWL_STYLE)。macOS/Linux 不使用，设为 0。
  final int windowStyle;

  /// 全屏前的窗口位置。
  final Offset position;

  /// 全屏前的窗口大小。
  final Size size;
}

/// 平台特定全屏操作。
///
/// 实现类:
/// - `Win32PlatformFullscreen` (Win32 FFI)
/// - `MacosPlatformFullscreen` (MethodChannel)
/// - `LinuxPlatformFullscreen` (FFI / MethodChannel)
abstract class PlatformFullscreen {
  /// 平台是否需要在进入全屏前保存窗口样式。
  /// Win32: true（必须保存 WS_THICKFRAME）。macOS/Linux: false。
  bool get requiresStyleSave;

  /// 进入全屏。返回快照用于失败时回滚。
  Future<FullscreenSnapshot> enter();

  /// 退出全屏，从快照恢复。
  void exit(FullscreenSnapshot snapshot);
}
