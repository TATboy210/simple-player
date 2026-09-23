import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../diagnostics/kernel_logger.dart';

/// Win32 IME 桥 — 窗口级输入法上下文开关（跨线程消息版）。
///
/// 架构位置：runner（C++）创建窗口时已解除默认输入法上下文（IMC），
/// 见 flutter_window.cpp OnCreate 的 `ImmAssociateContext(GetHandle(),
/// nullptr)` — 根治无文本框时中文输入法在窗口左上角弹候选窗的问题
/// （同 flutter/flutter#92050 家族；相关 #190042）。本桥提供 Dart 侧的
/// 恢复/再禁用开关，供未来落地文本输入框时按焦点启停（enable ↔ disable）。
///
/// **线程模型（本版关键）**：窗口由 platform 线程创建（main.cpp
/// RunOnSeparateThread），IMM32 函数族有线程亲和性 — UI isolate 线程
/// 直调 ImmAssociateContextEx 可能静默失效，IMC 未恢复时 IFileOpenDialog
/// 的 TSF 路径会 native 崩溃。因此本桥不再直调 imm32，而是经
/// SendMessageTimeoutW 投递 `WM_APP+0x49` 消息，由 runner 的
/// MessageHandler 在 platform 线程执行切换。Send 语义保证：对话框经
/// platform channel 打开前，此前的消息已被同一消息循环处理 — 时序天然
/// 有序。消息常量与 windows/runner/ime_bridge_messages.h 对偶维护。
///
/// hwnd 定位：FindWindowW 按类名（FLUTTER_RUNNER_WIN32_WINDOW）查找，
/// 不依赖调用瞬间的前台窗口（对话框关闭瞬间前台可能短暂易主）。
/// 已知限制：多实例场景返回首个同类名顶层窗口 — 本应用单实例使用无碍。
class Win32ImeBridge {
  /// runner 主窗口类名 — 与 win32_window.cpp 的 kWindowClassName 对齐.
  static const String _windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';

  /// 自定义消息号 — WM_APP(0x8000) + 0x49，与 runner 侧
  /// ime_bridge_messages.h 的 kAppSetImeEnabled 对偶（勿单边修改）.
  static const int _messageId = 0x8000 + 0x49;

  /// enable 消息 wParam — runner 侧解读为恢复系统默认 IMC（主+子窗口）.
  static const int _wparamEnable = 1;

  /// disable 消息 wParam — runner 侧解读为再次解除 IMC.
  static const int _wparamDisable = 0;

  /// SendMessageTimeoutW 的 SMTO_ABORTIFHUNG — 目标线程挂死时放弃而非永久阻塞.
  static const int _smtoAbortIfHung = 0x0002;

  /// 跨线程 Send 超时（毫秒）— platform 线程正常瞬间处理完毕；
  /// 超时视为失败（跳过收尾 disable，宁可多恢复不禁用）.
  static const int _sendTimeoutMs = 1000;

  final KernelLogger _log;

  /// 可注入的 FFI 函数束 — 测试用 fake 替换，生产走真实动态库.
  final Win32ImeFunctions _fns;

  Win32ImeBridge({KernelLogger? logger, Win32ImeFunctions? functions})
    : _log = logger ?? KernelLogger.I,
      _fns = functions ?? _resolveDefaultFunctions();

  /// 恢复窗口（含 FlutterView 子窗口）的系统默认输入法上下文。
  ///
  /// 返回是否成功（窗口定位失败或消息投递/处理失败均为失败）。
  bool enable() => _deliver(_wparamEnable, 'enable');

  /// 再次解除窗口（含 FlutterView 子窗口）的输入法上下文。
  bool disable() => _deliver(_wparamDisable, 'disable');

  /// 在 [action] 执行期间**临时恢复** IME（仅 Windows；其他平台直接透传）。
  ///
  /// 背景：窗口的 IMC 被解除后，原生文件对话框（IFileOpenDialog）创建
  /// 子窗口/编辑控件时 TSF/UI Automation 路径假定 IMC 存在，NULL 上下文
  /// 触发 imm32/msctf 空指针崩溃（已知 Windows bug 类，Windows 10 多个
  /// 版本受影响）——因此一切原生文件对话框调用必须经本方法包裹：
  /// 弹窗期间恢复输入法（对话框内文件名可正常输入中文），关闭后再禁用。
  ///
  /// enable 失败（如窗口定位/投递超时）时仍执行 [action]，但跳过收尾
  /// 禁用（从未恢复过就无从禁用）；[action] 的异常原样传播。
  static Future<T> withImeRestored<T>(
    Future<T> Function() action, {
    KernelLogger? logger,
    @visibleForTesting Win32ImeFunctions? functions,
  }) async {
    if (!Platform.isWindows) return action();
    final bridge = Win32ImeBridge(logger: logger, functions: functions);
    final restored = bridge.enable();
    try {
      return await action();
    } finally {
      if (restored) bridge.disable();
    }
  }

  /// 统一执行：定位 runner 窗口 → 投递 WM_APP 消息 → 日志与返回。
  ///
  /// side effect：消息在 platform 线程触发对主窗口 + FlutterView 子窗口
  /// 的 ImmAssociateContextEx（见 runner ime_bridge_messages.h）。
  bool _deliver(int wparam, String operation) {
    final hwnd = _resolveRunnerWindow();
    if (hwnd == 0) {
      _log.warn(
        'Win32ImeBridge.$operation: runner window not found by class name, '
        'IME state unchanged',
      );
      return false;
    }
    final ok = _fns.sendMessageTimeout(
      hwnd,
      _messageId,
      wparam,
      _smtoAbortIfHung,
      _sendTimeoutMs,
    );
    _log.info(
      'Win32ImeBridge.$operation: hwnd=0x${hwnd.toRadixString(16)} '
      'wparam=$wparam ok=$ok',
    );
    return ok;
  }

  /// 定位 runner 主窗口 — FindWindowW 按类名查找（不依赖前台窗口）.
  int _resolveRunnerWindow() => _fns.findWindow(_windowClassName);

  /// 生产 FFI 函数束 — 从 user32.dll 解析.
  static Win32ImeFunctions _resolveDefaultFunctions() {
    final user32 = ffi.DynamicLibrary.open('user32.dll');
    final findWindowW = user32.lookupFunction<
      IntPtr Function(Pointer<Uint16>, Pointer<Uint16>),
      int Function(Pointer<Uint16>, Pointer<Uint16>)
    >('FindWindowW');
    final sendMessageTimeoutW = user32.lookupFunction<
      IntPtr Function(
        IntPtr,
        Uint32,
        UintPtr,
        UintPtr,
        Uint32,
        Uint32,
        Pointer<UintPtr>,
      ),
      int Function(int, int, int, int, int, int, Pointer<UintPtr>)
    >('SendMessageTimeoutW');
    return Win32ImeFunctions(
      findWindow: (className) {
        final namePtr = className.toNativeUtf16();
        try {
          // Utf16 与 Uint16 同为 16 位布局，cast 是 FFI 标准惯用法；
          // 第二参数 nullptr — 不按窗口标题过滤，仅按类名.
          return findWindowW(namePtr.cast<Uint16>(), nullptr);
        } finally {
          calloc.free(namePtr);
        }
      },
      sendMessageTimeout: (hwnd, message, wparam, flags, timeoutMs) {
        final result = calloc<UintPtr>();
        try {
          // 返回非零 = 投递成功；lpdwResult 为目标窗口处理返回值 —
          // handler 返回 TRUE 表示切换已执行，二者同时成立才算成功.
          final sent = sendMessageTimeoutW(
            hwnd,
            message,
            wparam,
            0,
            flags,
            timeoutMs,
            result,
          );
          return sent != 0 && result.value != 0;
        } finally {
          calloc.free(result);
        }
      },
    );
  }
}

/// FFI 函数束 — 抽象动态库解析，测试注入 fake 实现.
@visibleForTesting
class Win32ImeFunctions {
  /// 按类名定位顶层窗口（FindWindowW；找不到返回 0）。
  final int Function(String className) findWindow;

  /// 投递自定义消息并等待目标线程处理（SendMessageTimeoutW 封装）。
  ///
  /// 返回「投递成功且 handler 返回非零」；超时/挂死/失败均为 false。
  final bool Function(int hwnd, int message, int wparam, int flags, int timeoutMs)
  sendMessageTimeout;

  const Win32ImeFunctions({
    required this.findWindow,
    required this.sendMessageTimeout,
  });
}
