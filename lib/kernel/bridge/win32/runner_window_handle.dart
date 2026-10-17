/// runner 主窗口句柄定位 — 为 nativeapi 提供当前 Flutter 宿主 HWND.
///
/// Why this FFI exists (nativeapi 0.5.2 gap): `WindowManager.getCurrent()`
/// on Windows is `GetActiveWindow()`, which is null while the runner window is
/// still hidden — and this app restores geometry *before* the first show (no
/// white flash). We therefore look the runner window up ourselves and wrap it
/// with `Window.createWithNativeWindow(hwnd)`.
///
/// Lookup is scoped to the current process (two player instances each own a
/// `FLUTTER_RUNNER_WIN32_WINDOW`, so a bare `FindWindowW` could return the
/// other one). 常量/签名逐一核对 Windows SDK `WinUser.h` (勿凭记忆改).
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// runner 主窗口类名 (windows/runner/win32_window.cpp kWindowClassName).
const String _runnerWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

@Native<IntPtr Function(IntPtr, IntPtr, Pointer<Uint16>, Pointer<Uint16>)>(
  symbol: 'FindWindowExW',
  assetId: 'user32',
)
external int _findWindowExW(
  int parent,
  int childAfter,
  Pointer<Uint16> className,
  Pointer<Uint16> name,
);

@Native<Uint32 Function(IntPtr, Pointer<Uint32>)>(
  symbol: 'GetWindowThreadProcessId',
  assetId: 'user32',
)
external int _getWindowThreadProcessId(int hwnd, Pointer<Uint32> processId);

@Native<Uint32 Function()>(symbol: 'GetCurrentProcessId', assetId: 'kernel32')
external int _getCurrentProcessId();

/// 返回本进程 runner 主窗口 HWND; 未找到返回 0.
///
/// 仅 Windows 调用 (调用方负责平台门控)。顶层窗口枚举 (FindWindowExW
/// parent=0) 包含隐藏窗口, 故隐藏态 init 期间可用。
int findRunnerWindowHandle() => using((arena) {
  final className = _runnerWindowClass
      .toNativeUtf16(allocator: arena)
      .cast<Uint16>();
  final processId = arena<Uint32>();
  final self = _getCurrentProcessId();
  var hwnd = 0;
  // 每轮从上一个命中之后继续, 直到类名匹配耗尽 (返回 0)。
  while (true) {
    hwnd = _findWindowExW(0, hwnd, className, nullptr);
    if (hwnd == 0) return 0;
    _getWindowThreadProcessId(hwnd, processId);
    if (processId.value == self) return hwnd;
  }
});

/// runner 关闭放行属性名 — 与 windows/runner/close_bridge_messages.h 同名.
const String _allowCloseProperty = 'SimplePlayerAllowClose';

@Native<Int32 Function(IntPtr, Pointer<Uint16>, IntPtr)>(
  symbol: 'SetPropW',
  assetId: 'user32',
)
external int _setPropW(int hwnd, Pointer<Uint16> name, int data);

/// 放行本应用自身发起的关闭 — 在 [hwnd] 上设置 runner 识别的属性,
/// 之后到达的 WM_CLOSE 不再被改投 SC_CLOSE (见 close_bridge_messages.h).
///
/// side effect: 写窗口属性 (随窗口销毁自动释放, 无需 RemoveProp)。
void allowRunnerWindowClose(int hwnd) => using((arena) {
  _setPropW(
    hwnd,
    _allowCloseProperty.toNativeUtf16(allocator: arena).cast<Uint16>(),
    1,
  );
});
