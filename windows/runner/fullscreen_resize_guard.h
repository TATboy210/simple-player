#ifndef RUNNER_FULLSCREEN_RESIZE_GUARD_H_
#define RUNNER_FULLSCREEN_RESIZE_GUARD_H_

#include <windows.h>
#include <commctrl.h>

namespace fullscreen_resize_guard {
// callback 地址与 ID 共同标识子类；不占用 bitsdojo 的 callback/ID 对。
constexpr UINT_PTR kSubclassId = 1;

/// 只屏蔽 media_kit 原生全屏中的缩放命中与尺寸命令。
/// ref_data 借用顶层 HWND；子窗口随顶层销毁，不持有 Dart/Flutter 对象。
inline LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                   LPARAM lparam, UINT_PTR id,
                                   DWORD_PTR ref_data) {
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, WindowProc, id);
    return DefSubclassProc(window, message, wparam, lparam);
  }
  if (message == WM_NCHITTEST || message == WM_SYSCOMMAND) {
    const HWND root = reinterpret_cast<HWND>(ref_data);
    // media_kit 入全屏摘掉此样式、退出时恢复。读取原生样式避免 Dart
    // 通知滞后；不改窗口样式、几何或 media_kit 的全屏切换权威。
    const bool fullscreen =
        (GetWindowLongPtr(root, GWL_STYLE) & WS_OVERLAPPEDWINDOW) == 0;
    if (fullscreen) {
      if (message == WM_NCHITTEST) return HTCLIENT;
      // 低四位是 Win32 的边缘编号，必须先掩码再比较命令。
      if ((wparam & 0xFFF0) == SC_SIZE) return 0;
    }
  }
  return DefSubclassProc(window, message, wparam, lparam);
}
}  // namespace fullscreen_resize_guard

/// 在插件注册之后、窗口所属线程上安装临时全屏缩放保护。
/// 同时拦截父子窗口，避免 Flutter 子窗口被 bitsdojo 判成 HTTRANSPARENT。
/// 安装失败时撤回本函数已装的 hook；销毁时各自通过 WM_NCDESTROY 解除。
inline bool InstallFullscreenResizeGuard(HWND root, HWND child) {
  using namespace fullscreen_resize_guard;
  if (!root || !child) return false;
  const auto data = reinterpret_cast<DWORD_PTR>(root);
  if (!SetWindowSubclass(root, WindowProc, kSubclassId, data)) return false;
  if (!SetWindowSubclass(child, WindowProc, kSubclassId, data)) {
    RemoveWindowSubclass(root, WindowProc, kSubclassId);
    return false;
  }
  return true;
}

#endif  // RUNNER_FULLSCREEN_RESIZE_GUARD_H_
