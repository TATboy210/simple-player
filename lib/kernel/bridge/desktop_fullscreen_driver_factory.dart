// 平台驱动工厂 — 根据 Platform.isXXX 选择具体 Driver (D-P01 + D-P02)。
//
// 编译时 flag 控制驱动选择 (D-P03):
// - USE_WINDOWS_NATIVE_FULLSCREEN=true: Windows 使用 FFI 驱动
// - 默认: Windows 使用 DesktopFullscreenDriver (window_manager fallback)
// - macOS: MacosFullscreenDriver (fullscreen_window 插件 + delegate 回调)
// - Linux: LinuxFullscreenDriver (fullscreen_window 插件 + state-changed 信号)

import 'dart:io' show Platform;

import 'desktop_fullscreen_driver.dart';
import 'fullscreen_driver.dart';
import 'platform/linux_fullscreen_driver.dart';
import 'platform/macos_fullscreen_driver.dart';
import 'platform/windows_fullscreen_driver.dart';

/// 平台驱动工厂 — 根据 Platform.isXXX 选择具体 Driver (D-P01 混合策略 + D-P02 每平台一个 Driver)。
///
/// 编译时 flag 控制驱动选择 (D-P03):
/// - USE_WINDOWS_NATIVE_FULLSCREEN=true: Windows 使用 Win32 FFI 驱动
/// - 默认: Windows 使用 window_manager fallback
/// - macOS: fullscreen_window 插件 + NSWindowDelegate 回调
/// - Linux: fullscreen_window 插件 + window-state-event 信号
///
/// 未知平台降级到 DesktopFullscreenDriver (window_manager)。
class DesktopFullscreenDriverFactory {
  DesktopFullscreenDriverFactory._();

  /// 编译时 flag: Windows 原生 FFI 驱动 (D-P03)。
  ///
  /// 使用 `--dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true` 启用。
  /// 仅在 USE_NEW_FULLSCREEN=true 时生效 (main.dart 控制)。
  static const _useWindowsNative = bool.fromEnvironment(
    'USE_WINDOWS_NATIVE_FULLSCREEN',
    defaultValue: false,
  );

  /// 创建当前平台的 FullscreenDriver。
  ///
  /// 平台选择逻辑:
  /// - Windows + _useWindowsNative: WindowsFullscreenDriver (FFI)
  /// - Windows (default): DesktopFullscreenDriver (window_manager)
  /// - macOS: MacosFullscreenDriver (fullscreen_window + delegate)
  /// - Linux: LinuxFullscreenDriver (fullscreen_window + state-changed)
  /// - 其他: DesktopFullscreenDriver (window_manager fallback)
  static FullscreenDriver create() {
    if (Platform.isWindows) {
      // D-P03: USE_WINDOWS_NATIVE_FULLSCREEN=true 时使用 FFI 驱动
      if (_useWindowsNative) {
        return WindowsFullscreenDriver();
      }
      return DesktopFullscreenDriver();
    }
    if (Platform.isMacOS) {
      return MacosFullscreenDriver();
    }
    if (Platform.isLinux) {
      return LinuxFullscreenDriver();
    }
    // 未知平台: 降级到 window_manager
    return DesktopFullscreenDriver();
  }
}
