/// 窗口状态命令桥 — 把全屏/最大化/还原/最小化投递给 Windows runner 执行。
///
/// Why: nativeapi's state calls are synchronous Dart FFI. The UI isolate runs
/// on the platform thread, so a resize that starts inside such a call cannot
/// produce a new-size frame (the engine's resize wait cannot run Dart while
/// Dart is on the stack): it times out after 100ms and DWM composites stale,
/// stretched content plus the changing system frame — visible in Debug as a
/// Windows-style border flashing on fullscreen enter/exit. Posting the
/// command lets it run from the message loop, where the engine's synchronous
/// resize renders the new frame inside WM_SIZE (the same path as a native
/// edge drag or caption double-click). See windows/runner/
/// window_command_messages.h; 签名逐一核对 Windows SDK `WinUser.h`.
library;

import 'dart:ffi';

/// runner 侧 `kAppWindowCommand` (WM_APP + 0x4B) — 两侧同值。
const int _kAppWindowCommand = 0x8000 + 0x4B;

/// runner `window_command_messages::Command` 同序 — 勿单边修改。
enum WindowCommand {
  enterFullScreen(1),
  exitFullScreen(2),
  maximize(3),
  unmaximize(4),
  minimize(5);

  const WindowCommand(this.code);

  /// 投递给 runner 的 wParam。
  final int code;
}

@Native<Int32 Function(IntPtr, Uint32, IntPtr, IntPtr)>(
  symbol: 'PostMessageW',
  assetId: 'user32',
)
external int _postMessageW(int hwnd, int message, int wParam, int lParam);

/// 投递 [command] 到 runner 窗口 [hwnd]; [nativeWindow] 为 nativeapi 的
/// `na.Window.nativeHandle` (runner 用它调 nativeapi C API)。
///
/// side effect: 异步窗口状态变化 (命令在消息循环执行)。返回是否投递成功。
bool postRunnerWindowCommand(
  int hwnd,
  WindowCommand command,
  int nativeWindow,
) => _postMessageW(hwnd, _kAppWindowCommand, command.code, nativeWindow) != 0;
