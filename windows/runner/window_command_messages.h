#ifndef RUNNER_WINDOW_COMMAND_MESSAGES_H_
#define RUNNER_WINDOW_COMMAND_MESSAGES_H_

#include <windows.h>
#include <dwmapi.h>

#include <cstdint>

// 窗口状态命令在 runner 消息循环里执行（2026-10 nativeapi 迁移补位）。
//
// Why: nativeapi 的全屏/最大化/还原经 Dart FFI 同步调用 → SetWindowPos →
// WM_SIZE 时 Dart 正在执行该 FFI 调用。UI isolate 跑在 platform 线程，
// FlutterWindowsView::OnWindowSizeChanged 等新尺寸帧的 PollOnce 无法在
// Dart 栈上再跑 Dart 帧任务 → 100ms 超时，DWM 先按新几何合成旧内容：
// Debug 下全屏切换可见拉伸残帧与系统边框。Dart 改为 PostMessageW 投递本
// 命令后立即返回，命令在消息循环（Dart 栈外）执行，引擎的同步 resize
// 才能在 WM_SIZE 内产出新尺寸帧（与原生拖边/双击标题栏同路径）。
//
// 全屏额外 DWM cloak：样式位摘除/恢复（WS_CAPTION|WS_THICKFRAME）与几何
// 变化期间 DWM 会重算 frame（边框、圆角、阴影），先隐去合成，nativeapi
// 返回时新尺寸帧已呈现（同步 resize），再取消 cloak — Chromium
// ScopedFullscreenVisibility 同款思路（其用 SW_HIDE；cloak 不改可见性/
// 激活/任务栏状态）。
//
// 命令经 GetProcAddress 调 nativeapi 自身的 C API（cnativeapi.dll 已由
// Dart native assets 载入本进程），行为与 Dart 侧 na.Window 完全一致，
// 只是换了调用栈。wParam = 命令码，lParam = native_window_t（Dart
// na.Window.nativeHandle，64 位句柄，本应用只发 x64/arm64）。
namespace window_command_messages {

// WM_APP + 0x4B — 与 ime(0x49)/sizemove(0x4A) 相邻，Dart 侧同值。
constexpr UINT kAppWindowCommand = WM_APP + 0x4B;

// Dart 侧 WindowCommand 枚举同序 — 勿单边修改。
enum Command : WPARAM {
  kEnterFullScreen = 1,
  kExitFullScreen = 2,
  kMaximize = 3,
  kUnmaximize = 4,
  kMinimize = 5,
};

using native_window_t = uint64_t;
using VoidFn = void (*)(native_window_t);
using SetFullScreenFn = void (*)(native_window_t, bool);

struct NativeApi {
  SetFullScreenFn set_full_screen = nullptr;
  VoidFn maximize = nullptr;
  VoidFn unmaximize = nullptr;
  VoidFn minimize = nullptr;
};

// 首次使用时解析（Dart 投递首个命令前 nativeapi 必已载入）。
inline const NativeApi* ResolveNativeApi() {
  static NativeApi api;
  static bool resolved = false;
  if (resolved) return api.set_full_screen ? &api : nullptr;
  HMODULE module = GetModuleHandleW(L"cnativeapi.dll");
  if (!module) return nullptr;  // 未载入：下次再试
  resolved = true;
  api.set_full_screen = reinterpret_cast<SetFullScreenFn>(
      GetProcAddress(module, "native_window_set_full_screen"));
  api.maximize =
      reinterpret_cast<VoidFn>(GetProcAddress(module, "native_window_maximize"));
  api.unmaximize = reinterpret_cast<VoidFn>(
      GetProcAddress(module, "native_window_unmaximize"));
  api.minimize =
      reinterpret_cast<VoidFn>(GetProcAddress(module, "native_window_minimize"));
  if (!api.set_full_screen || !api.maximize || !api.unmaximize ||
      !api.minimize) {
    api = NativeApi{};
  }
  return api.set_full_screen ? &api : nullptr;
}

inline void SetCloaked(HWND hwnd, BOOL cloaked) {
  DwmSetWindowAttribute(hwnd, DWMWA_CLOAK, &cloaked, sizeof(cloaked));
}

// 执行一条命令；返回 false 表示 nativeapi 不可用（Dart 侧回退直调）。
inline bool Handle(HWND hwnd, WPARAM command, LPARAM handle) {
  const NativeApi* api = ResolveNativeApi();
  if (!api || handle == 0) return false;
  const auto window = static_cast<native_window_t>(handle);
  switch (command) {
    case kEnterFullScreen:
    case kExitFullScreen: {
      // 最小化窗口不可见，无需 cloak（且 cloak 会延续到还原）。
      const bool cloak = IsWindowVisible(hwnd) && !IsIconic(hwnd);
      if (cloak) SetCloaked(hwnd, TRUE);
      api->set_full_screen(window, command == kEnterFullScreen);
      // set_full_screen 内的 SetWindowPos 已同步等到新尺寸帧（≤100ms），
      // 再刷一次 DWM 合成队列后揭开。
      if (cloak) {
        DwmFlush();
        SetCloaked(hwnd, FALSE);
      }
      return true;
    }
    case kMaximize:
      api->maximize(window);
      return true;
    case kUnmaximize:
      api->unmaximize(window);
      return true;
    case kMinimize:
      api->minimize(window);
      return true;
    default:
      return false;
  }
}

}  // namespace window_command_messages

#endif  // RUNNER_WINDOW_COMMAND_MESSAGES_H_
