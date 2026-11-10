import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../diagnostics/kernel_logger.dart';

/// runner「关门专线」FFI 侧 — 配套 windows/runner/flutter_window.cpp 的
/// `SetCloseNotifier` 导出。阶段二改造：WM_CLOSE 不再绕道 nativeapi 事件流
/// （逐步事件投递是拖拽卡顿主犯，取证见 docs/audit/resize-drag-ab-2026-11.md），
/// 改由 runner 直接唤起一个常驻回调。
///
/// 线程模型：回调在 platform 线程的 WndProc 内被调用；
/// [ffi.NativeCallable.listener] 把它安全投递到 UI isolate，不阻塞消息处理。
typedef _SetCloseNotifierNative = ffi.Void Function(
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>,
);
typedef _SetCloseNotifierDart = void Function(
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>,
);

/// 关门通知器注册桥。
abstract final class CloseNotifierBridge {
  /// 注册 [onHostClose] 直连通知；返回是否成功。
  ///
  /// 失败（非 Windows / runner 缺符号 = 旧构建产物 / FFI 不可用）记 warn 返回
  /// false，调用方（WindowService）自动退回旧关闭路径，不抛。
  /// Side effect：占用 runner 的全局通知器槽位（重复调用覆盖旧回调）。
  static bool install(void Function() onHostClose) {
    if (!Platform.isWindows) return false;
    final log = KernelLogger.I;
    try {
      final setCloseNotifier = ffi.DynamicLibrary.process()
          .lookupFunction<_SetCloseNotifierNative, _SetCloseNotifierDart>(
            'SetCloseNotifier',
          );
      final callable = ffi.NativeCallable<ffi.Void Function()>.listener(() {
        try {
          onHostClose();
        } on Object catch (error, stackTrace) {
          // 回调运行在原生消息栈内 — 任何逃逸异常都可能弄死 WndProc，就地兜住。
          log.e(
            '[CloseNotifierBridge] host-close handler failed: $error',
            error: error,
            stackTrace: stackTrace,
          );
        }
      });
      setCloseNotifier(callable.nativeFunction);
      // 永久保活：runner 槽位持裸指针直到进程退出；覆盖注册（热重启）时旧
      // callable 不再被引用，保留即一个泄漏点，可接受且换取无竞态安全。
      installed = callable;
      return true;
    } on Object catch (error, stackTrace) {
      log.w(
        '[CloseNotifierBridge] install failed, legacy close path remains: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  /// 保活槽 — 当前注册的原生回调（诊断可见）。
  @visibleForTesting
  static ffi.NativeCallable<ffi.Void Function()>? installed;
}
