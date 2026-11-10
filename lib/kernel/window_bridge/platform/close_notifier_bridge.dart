import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../diagnostics/kernel_logger.dart';

/// runner「关门专线」FFI 侧 — 配套三平台 runner 的 `SetCloseNotifier` 导出
/// （Windows flutter_window.cpp / macOS MainFlutterWindow.swift+AppDelegate /
/// Linux my_application.cc，同一 C ABI）。用户发起的关窗（✕ 之外的系统路径：
/// Alt+F4、Cmd+W、Cmd+Q、GTK delete-event）由 runner 直接唤起常驻回调，
/// 不经过 nativeapi 事件流（逐步事件投递是拖拽卡顿主犯，取证见
/// docs/audit/resize-drag-ab-2026-11.md）。
///
/// 线程模型：回调在平台线程的窗口消息处理内被调用（Windows WndProc /
/// macOS AppKit 主线程 / Linux GTK 主循环）；[ffi.NativeCallable.listener]
/// 把它安全投递到 UI isolate，不阻塞消息处理。
typedef _SetCloseNotifierNative = ffi.Void Function(
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>,
);
typedef _SetCloseNotifierDart = void Function(
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>>,
);

/// 关门通知器注册桥 — 三平台统一（无平台门：符号缺失即降级）。
abstract final class CloseNotifierBridge {
  /// 注册 [onHostClose] 直连通知；返回是否成功。
  ///
  /// 失败（runner 缺符号 = 旧构建产物 / FFI 不可用）记日志返回 false，
  /// 调用方（WindowService）自动退回旧关闭路径（runner 放行原生关闭，
  /// Dart ✕ 按钮仍走 hide-first），不抛。
  /// Side effect：占用 runner 的全局通知器槽位（重复调用覆盖旧回调）。
  static bool install(void Function() onHostClose) {
    final log = KernelLogger.I;
    try {
      final setCloseNotifier = _lookupSetCloseNotifier();
      if (setCloseNotifier == null) {
        log.i(
          '[CloseNotifierBridge] SetCloseNotifier not exported by runner — '
          'host close falls back to native destroy',
        );
        return false;
      }
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

  /// process() 查不到再试 executable()（静态链入 exe 的符号在部分平台
  /// 只对 executable 作用域可见）。
  static _SetCloseNotifierDart? _lookupSetCloseNotifier() {
    try {
      return ffi.DynamicLibrary.process()
          .lookupFunction<_SetCloseNotifierNative, _SetCloseNotifierDart>(
            'SetCloseNotifier',
          );
    } on Object {
      try {
        return ffi.DynamicLibrary.executable()
            .lookupFunction<_SetCloseNotifierNative, _SetCloseNotifierDart>(
              'SetCloseNotifier',
            );
      } on Object {
        return null;
      }
    }
  }

  /// 保活槽 — 当前注册的原生回调（诊断可见）。
  @visibleForTesting
  static ffi.NativeCallable<ffi.Void Function()>? installed;
}
