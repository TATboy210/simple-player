import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import '../../bridge/win32/runner_window_handle.dart';
import '../../diagnostics/kernel_logger.dart';

/// 句柄定位策略 — 返回原生窗口句柄地址（HWND/NSWindow*/GtkWindow* 的
/// 整型表示），失败返回 null。
typedef HandleStrategy = int? Function();

/// runner 导出的主窗口句柄符号名 — 三平台同一 C ABI（与 SetCloseNotifier
/// 同模式；Windows flutter_window.cpp / macOS @_cdecl / Linux extern "C"）。
const String kMainWindowHandleSymbol = 'SimplerPlayerGetMainWindowHandle';

/// 主窗口句柄定位器 — 按注入顺序尝试策略，取第一个非空句柄。
///
/// 生产装配（nativeapi_window.dart）：符号导出为主路径（隐藏态可用、
/// 不依赖焦点），平台 fallback 兜底（Windows=FindWindowExW 枚举，
/// macOS/Linux=WindowManager.getCurrent）。策略全部可注入，纯逻辑可测。
class WindowHandleLocator {
  WindowHandleLocator(this._strategies);

  final List<HandleStrategy> _strategies;

  /// 依序尝试；单条策略抛异常记日志后继续下一条；全部失败返回 null。
  int? locate() {
    final log = KernelLogger.I;
    for (final strategy in _strategies) {
      try {
        final handle = strategy();
        if (handle != null && handle != 0) return handle;
      } on Object catch (error, stackTrace) {
        log.w(
          '[WindowHandleLocator] strategy failed: $error',
          context: <String, Object?>{'stackTrace': stackTrace.toString()},
        );
      }
    }
    return null;
  }
}

/// 查 runner 导出的句柄符号（三平台通用主路径）。
///
/// 符号缺失（旧构建产物 / Wave 2-4 之前的 runner）时 lookup 抛
/// ArgumentError → 返回 null，由调用方走 fallback 链，不记 error。
int? lookupRunnerHandleSymbol() {
  try {
    final getHandle = ffi.DynamicLibrary.process()
        .lookupFunction<ffi.Pointer<ffi.Void> Function(),
            ffi.Pointer<ffi.Void> Function()>(kMainWindowHandleSymbol);
    final handle = getHandle();
    return handle == ffi.nullptr ? null : handle.address;
  } on Object {
    return null;
  }
}

/// 生产策略链装配 — 平台判定收口在本文件（platform 层）。
///
/// [managerFallback] 为 nativeapi WindowManager 兜底（getCurrent/getAll，
/// 由 port 层注入闭包以免本文件依赖 nativeapi）：仅 macOS/Linux 接入 —
/// Windows 隐藏态 GetActiveWindow 必 null，兜底走 FindWindowExW 枚举。
List<HandleStrategy> defaultHandleStrategies({
  required HandleStrategy managerFallback,
  String Function()? operatingSystem,
}) {
  final os = (operatingSystem ?? () => Platform.operatingSystem)();
  return <HandleStrategy>[
    lookupRunnerHandleSymbol,
    if (os == 'windows') findRunnerWindowHandle,
    if (os == 'macos' || os == 'linux') managerFallback,
  ];
}
