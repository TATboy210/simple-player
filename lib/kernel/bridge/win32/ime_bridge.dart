import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../diagnostics/kernel_logger.dart';

/// Win32 IME 桥 — 窗口级输入法上下文开关（ImmAssociateContext 家族）。
///
/// 架构位置：runner（C++）创建窗口时已解除默认输入法上下文（IMC），
/// 见 flutter_window.cpp OnCreate 的 `ImmAssociateContext(GetHandle(),
/// nullptr)` — 根治无文本框时中文输入法在窗口左上角弹候选窗的问题
/// （flutter/flutter#74723 同款）。本桥提供 Dart 侧的恢复/再禁用开关，
/// 供未来落地文本输入框时按焦点启停（enable ↔ disable）。
///
/// hwnd 定位：GetForegroundWindow + 窗口类名校验
/// （FLUTTER_RUNNER_WIN32_WINDOW）— 排除调用瞬间前台已切走的竞态；
/// 类名不符视为失败（不误伤其他窗口的 IME 上下文）。
///
/// 恢复走 [ImmAssociateContextEx] 的 IACE_DEFAULT — 重新关联系统默认
/// IMC，无需跨进程缓存禁用前的旧句柄。
class Win32ImeBridge {
  /// runner 主窗口类名 — 与 win32_window.cpp 的 kWindowClassName 对齐.
  static const String _windowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';

  /// ImmAssociateContextEx 的恢复标志 — 重新关联系统默认输入法上下文.
  static const int _iaceDefault = 0x0001;

  /// ImmAssociateContextEx 的解除标志 — 不关联任何输入法上下文.
  static const int _iaceIgnore = 0x0002;

  /// 同时作用于子窗口 — Flutter 键盘焦点在 FlutterView 子窗口上,
  /// 只解除主窗口候选窗照弹 (首版实测踩坑).
  static const int _iaceChildren = 0x0008;

  final KernelLogger _log;

  /// 可注入的 FFI 函数束 — 测试用 fake 替换，生产走真实动态库.
  final Win32ImeFunctions _fns;

  Win32ImeBridge({KernelLogger? logger, Win32ImeFunctions? functions})
    : _log = logger ?? KernelLogger.I,
      _fns = functions ?? _resolveDefaultFunctions();

  /// 恢复窗口（含 FlutterView 子窗口）的系统默认输入法上下文。
  ///
  /// 返回是否成功（hwnd 定位失败或 API 返回 0 均为失败）。
  bool enable() => _associate(_iaceDefault | _iaceChildren, 'enable');

  /// 再次解除窗口（含 FlutterView 子窗口）的输入法上下文。
  bool disable() => _associate(_iaceIgnore | _iaceChildren, 'disable');

  /// 在 [action] 执行期间**临时恢复** IME（仅 Windows；其他平台直接透传）。
  ///
  /// 背景：窗口的 IMC 被解除后，原生文件对话框（IFileOpenDialog）创建
  /// 子窗口/编辑控件时 TSF/UI Automation 路径假定 IMC 存在，NULL 上下文
  /// 触发 imm32/msctf 空指针崩溃（已知 Windows bug 类，Windows 10 多个
  /// 版本受影响）——因此一切原生文件对话框调用必须经本方法包裹：
  /// 弹窗期间恢复输入法（对话框内文件名可正常输入中文），关闭后再禁用。
  ///
  /// enable 失败（如前台已切走）时仍执行 [action]，但跳过收尾禁用
  /// （从未恢复过就无从禁用）；[action] 的异常原样传播。
  static Future<T> withImeRestored<T>(
    Future<T> Function() action, {
    KernelLogger? logger,
  }) async {
    if (!Platform.isWindows) return action();
    final bridge = Win32ImeBridge(logger: logger);
    final restored = bridge.enable();
    try {
      return await action();
    } finally {
      if (restored) bridge.disable();
    }
  }

  /// 统一执行：定位 hwnd → 按模式关联（含子窗口）→ 日志与返回。
  bool _associate(int flags, String operation) {
    final hwnd = _resolveForegroundHwnd();
    if (hwnd == 0) {
      _log.warn(
        'Win32ImeBridge.$operation: foreground window is not the player '
        '(class name mismatch), IME state unchanged',
      );
      return false;
    }
    // 空上下文以句柄 0 表示 (HIMC NULL); IACE_CHILDREN 覆盖 FlutterView
    // 子窗口 — 组合发生在持有键盘焦点的子窗口 IMC 上.
    final ok = _fns.associateContextEx(hwnd, 0, flags) != 0;
    _log.info(
      'Win32ImeBridge.$operation: hwnd=0x${hwnd.toRadixString(16)} ok=$ok',
    );
    return ok;
  }

  /// 定位 runner 主窗口 — 前台窗口且类名匹配才返回句柄.
  int _resolveForegroundHwnd() {
    final hwnd = _fns.foregroundWindow();
    if (hwnd == 0) return 0;
    return _fns.windowClassNameMatches(hwnd, _windowClassName) ? hwnd : 0;
  }

  /// 生产 FFI 函数束 — 从 user32.dll / imm32.dll 解析.
  static Win32ImeFunctions _resolveDefaultFunctions() {
    final user32 = ffi.DynamicLibrary.open('user32.dll');
    final imm32 = ffi.DynamicLibrary.open('imm32.dll');
    final getClassNames = user32
        .lookupFunction<
          Uint32 Function(IntPtr, Pointer<Uint16>, Uint32),
          int Function(int, Pointer<Uint16>, int)
        >('GetClassNameW');
    return Win32ImeFunctions(
      foregroundWindow: user32
          .lookupFunction<IntPtr Function(), int Function()>(
            'GetForegroundWindow',
          ),
      windowClassNameMatches: (hwnd, expected) {
        final buffer = calloc<Uint16>(64);
        try {
          final length = getClassNames(hwnd, buffer, 64);
          if (length <= 0) return false;
          final name = buffer.cast<Utf16>().toDartString(length: length);
          return name == expected;
        } finally {
          calloc.free(buffer);
        }
      },
      associateContextEx: imm32
          .lookupFunction<
            Int32 Function(IntPtr, IntPtr, Uint32),
            int Function(int, int, int)
          >('ImmAssociateContextEx'),
    );
  }
}

/// FFI 函数束 — 抽象动态库解析，测试注入 fake 实现.
@visibleForTesting
class Win32ImeFunctions {
  /// 前台窗口句柄（GetForegroundWindow）。
  final int Function() foregroundWindow;

  /// 校验句柄的窗口类名是否匹配（GetClassNameW + Utf16 解码）。
  final bool Function(int hwnd, String expected) windowClassNameMatches;

  /// 带标志的上下文关联（ImmAssociateContextEx；非零 = 成功）。
  final int Function(int hwnd, int context, int flags) associateContextEx;

  const Win32ImeFunctions({
    required this.foregroundWindow,
    required this.windowClassNameMatches,
    required this.associateContextEx,
  });
}
