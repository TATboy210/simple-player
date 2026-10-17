#ifndef RUNNER_CLOSE_BRIDGE_MESSAGES_H_
#define RUNNER_CLOSE_BRIDGE_MESSAGES_H_

#include <windows.h>

// 关闭拦截补位（2026-10 nativeapi 迁移）。
//
// nativeapi 0.5.2 只把 WM_SYSCOMMAND/SC_CLOSE（✕ 系统菜单、Alt+F4、任务栏
// 关闭）当作可取消的关闭请求交给 Dart；直接到达的 WM_CLOSE（外部
// PostMessage、taskkill 无 /f）被视为「必须关闭」，默认 DestroyWindow 会在
// Dart 持久化播放列表之前销毁窗口。window_manager 时代 setPreventClose 能
// 拦截它，这里补回：WM_CLOSE 改投一次 SC_CLOSE，走 nativeapi 的可取消路径。
//
// 防循环：SC_CLOSE 若未被 nativeapi 截获（Dart 未绑定/无监听）会落到这里，
// 置 g_in_sc_close 后交 DefWindowProc —— 它同步发出的 WM_CLOSE 放行销毁。
// Dart 侧 NativeApiWindowHost.destroy 先在窗口上设 kAllowCloseProperty，
// 自身发起的关闭同样放行。
namespace close_bridge_messages {

// Dart 侧 (lib/kernel/bridge/win32/runner_window_handle.dart) 同名常量。
constexpr wchar_t kAllowCloseProperty[] = L"SimplePlayerAllowClose";

inline bool g_in_sc_close = false;

// 返回 true 表示消息已处理（调用方 return 0）。
inline bool HandleClose(HWND hwnd, UINT message, WPARAM wparam) {
  if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_CLOSE) {
    g_in_sc_close = true;
    DefWindowProc(hwnd, message, wparam, 0);
    g_in_sc_close = false;
    return true;
  }
  if (message != WM_CLOSE || g_in_sc_close ||
      GetPropW(hwnd, kAllowCloseProperty) != nullptr) {
    return false;
  }
  PostMessageW(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
  return true;
}

}  // namespace close_bridge_messages

#endif  // RUNNER_CLOSE_BRIDGE_MESSAGES_H_
