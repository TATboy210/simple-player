#include <windows.h>
#include <commctrl.h>

#include <cstdlib>
#include <iostream>

#include "../fullscreen_resize_guard.h"

namespace {
int resize_commands = 0;

/// 模拟 bitsdojo：不看全屏样式，始终将命中认作边缘。
LRESULT CALLBACK EdgeProc(HWND window, UINT message, WPARAM wparam,
                          LPARAM lparam, UINT_PTR, DWORD_PTR) {
  if (message == WM_NCHITTEST) return HTTOPLEFT;
  if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_SIZE) {
    ++resize_commands;
    return 0;
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

/// 不使用 assert，保证 Release 构建也实际执行所有断言。
void Check(bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << std::endl;
    std::exit(EXIT_FAILURE);
  }
}
}  // namespace

int main() {
  HWND root = CreateWindowEx(0, L"STATIC", L"resize guard test",
                            WS_OVERLAPPEDWINDOW, 0, 0, 800, 600,
                            nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  HWND child = CreateWindowEx(0, L"STATIC", L"view", WS_CHILD,
                             0, 0, 800, 600, root, nullptr,
                             GetModuleHandle(nullptr), nullptr);
  Check(root && child, "create windows");
  Check(SetWindowSubclass(root, EdgeProc, 1, 0) != FALSE, "root edge hook");
  Check(SetWindowSubclass(child, EdgeProc, 1, 0) != FALSE, "child edge hook");
  Check(InstallFullscreenResizeGuard(root, child), "install guard");

  Check(SendMessage(root, WM_NCHITTEST, 0, 0) == HTTOPLEFT, "windowed root");
  Check(SendMessage(child, WM_NCHITTEST, 0, 0) == HTTOPLEFT, "windowed child");
  SendMessage(root, WM_SYSCOMMAND, SC_SIZE | 1, 0);
  Check(resize_commands == 1, "windowed resize forwarded");

  // 与 media_kit 原生全屏相同：移除 WS_OVERLAPPEDWINDOW，而非伪造 Dart 状态。
  const LONG_PTR style = GetWindowLongPtr(root, GWL_STYLE);
  SetWindowLongPtr(root, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
  Check(SendMessage(root, WM_NCHITTEST, 0, 0) == HTCLIENT, "fullscreen root");
  Check(SendMessage(child, WM_NCHITTEST, 0, 0) == HTCLIENT, "fullscreen child");
  for (WPARAM edge = 1; edge <= 8; ++edge) {
    SendMessage(root, WM_SYSCOMMAND, SC_SIZE | edge, 0);
  }
  Check(resize_commands == 1, "all fullscreen resize commands blocked");

  SetWindowLongPtr(root, GWL_STYLE, style);
  Check(SendMessage(child, WM_NCHITTEST, 0, 0) == HTTOPLEFT, "exit restores hit");
  SendMessage(root, WM_SYSCOMMAND, SC_SIZE | 8, 0);
  Check(resize_commands == 2, "exit restores resize");
  Check(DestroyWindow(root) != FALSE, "destroy removes hooks safely");
  std::cout << "fullscreen resize guard: passed" << std::endl;
}
