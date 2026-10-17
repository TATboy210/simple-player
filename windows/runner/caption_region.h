#ifndef RUNNER_CAPTION_REGION_H_
#define RUNNER_CAPTION_REGION_H_

#include <windows.h>
#include <commctrl.h>

// 自绘标题栏的原生拖动区（2026-10 nativeapi 迁移后补位）。
//
// Dart 侧（lib/kernel/bridge/win32/caption_region_bridge.dart）把标题栏可拖区
// 的客户区物理像素矩形打包成一个指针宽度值写进窗口属性 kCaptionRectProperty；
// 本文件在 WM_NCHITTEST 里对该矩形回答 HTCAPTION——拖动、双击最大化/还原、
// 从最大化拖出还原、Aero Snap、右键系统菜单全部由 DefWindowProc 原生完成，
// 不再经 Flutter 手势竞技场模拟（Chromium app-region: drag 同款做法）。
//
// 命中顺序：FlutterView 子窗口覆盖整个客户区并先被命中，其子类过程在拖动区
// 内返回 HTTRANSPARENT（同线程才穿透——UI isolate 已跑在 platform 线程），
// 命中落到顶层窗口：nativeapi 子类 → DefSubclassProc → 本 runner 的
// MessageHandler 回答 HTCAPTION。nativeapi 只在命中为 HTCLIENT 时才补 HTTOP
// 等缩放边，所以这里必须先让出缩放边带，否则顶边/（Win10 无 frame 模式）左右
// 边缩放会被拖动吞掉。
//
// 全屏时 nativeapi 摘除 WS_CAPTION，此处一并失效（Dart 侧也会清空矩形）。
namespace caption_region {

// Dart 侧同名常量 — 勿单边修改。
constexpr wchar_t kCaptionRectProperty[] = L"SimplePlayerCaptionRect";

// nativeapi 0.5.2 window_windows.cpp 的属性名（只读，用于对齐缩放边判定）。
constexpr wchar_t kNativeApiFramelessProperty[] = L"NativeAPIFramelessClient";

// 子类 id — 与 nativeapi 的 TopEdgeChildProc（id 1）区分。
constexpr UINT_PTR kCaptionChildSubclassId = 0x5350;  // 'SP'

// 96 DPI 下系统缩放边宽度（SM_CXSIZEFRAME + SM_CXPADDEDBORDER）。
constexpr int kResizeBorderAt96Dpi = 8;

// 读取打包矩形：left | top<<16 | right<<32 | bottom<<48（各 16 位无符号）。
inline bool ReadCaptionRect(HWND root, RECT* rect) {
  const auto packed = reinterpret_cast<ULONG_PTR>(
      GetPropW(root, kCaptionRectProperty));
  if (packed == 0) return false;
  const unsigned long long value = packed;
  rect->left = static_cast<LONG>(value & 0xFFFF);
  rect->top = static_cast<LONG>((value >> 16) & 0xFFFF);
  rect->right = static_cast<LONG>((value >> 32) & 0xFFFF);
  rect->bottom = static_cast<LONG>((value >> 48) & 0xFFFF);
  return rect->right > rect->left && rect->bottom > rect->top;
}

// 屏幕点（WM_NCHITTEST 的 lParam）是否落在标题栏拖动区内且不在缩放边带上。
inline bool IsCaptionPoint(HWND root, LPARAM point) {
  const LONG_PTR style = GetWindowLongPtrW(root, GWL_STYLE);
  // 全屏（nativeapi 摘除 WS_CAPTION）或最小化时无标题栏可拖。
  if (!(style & WS_CAPTION) || IsIconic(root)) return false;
  RECT caption;
  if (!ReadCaptionRect(root, &caption)) return false;

  // GET_X/Y_LPARAM，不引 <windowsx.h>（其宏与 nativeapi 方法名冲突的先例）。
  const POINT screen = {static_cast<short>(LOWORD(point)),
                        static_cast<short>(HIWORD(point))};
  if (!IsZoomed(root)) {
    RECT window;
    GetWindowRect(root, &window);
    POINT client_origin = {0, 0};
    ClientToScreen(root, &client_origin);
    // 与 nativeapi HiddenFrameResizeHit 同口径：有 frame 时顶边带与左侧
    // frame 等厚；无 frame（Win10 hasShadow=false）时按 8px×DPI。
    int frame = client_origin.x - window.left;
    if (frame <= 0 || GetPropW(root, kNativeApiFramelessProperty)) {
      frame = MulDiv(kResizeBorderAt96Dpi, GetDpiForWindow(root), 96);
    }
    if (screen.y < window.top + frame || screen.x < window.left + frame ||
        screen.x >= window.right - frame) {
      return false;
    }
  }
  POINT client = screen;
  if (!ScreenToClient(root, &client)) return false;
  return client.x >= caption.left && client.x < caption.right &&
         client.y >= caption.top && client.y < caption.bottom;
}

// FlutterView 子窗口的子类过程：拖动区内让命中穿透到顶层窗口。
inline LRESULT CALLBACK CaptionChildProc(HWND child, UINT message,
                                         WPARAM wparam, LPARAM lparam,
                                         UINT_PTR subclass_id, DWORD_PTR) {
  if (message == WM_NCHITTEST) {
    HWND root = GetAncestor(child, GA_ROOT);
    if (root && IsCaptionPoint(root, lparam)) return HTTRANSPARENT;
  } else if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(child, CaptionChildProc, subclass_id);
  }
  return DefSubclassProc(child, message, wparam, lparam);
}

// 安装到 FlutterView 子窗口（OnCreate 调用一次）。
inline void AttachFlutterView(HWND flutter_view) {
  if (flutter_view) {
    SetWindowSubclass(flutter_view, CaptionChildProc, kCaptionChildSubclassId,
                      0);
  }
}

// 顶层窗口 WM_NCHITTEST：拖动区内回答 HTCAPTION，否则交还默认处理。
inline bool HandleHitTest(HWND root, UINT message, LPARAM lparam,
                          LRESULT* result) {
  if (message != WM_NCHITTEST || !IsCaptionPoint(root, lparam)) return false;
  *result = HTCAPTION;
  return true;
}

}  // namespace caption_region

#endif  // RUNNER_CAPTION_REGION_H_
