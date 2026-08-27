#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include "resource.h"

namespace
{

  constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

  static int g_active_window_count = 0;

  using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

  int Scale(int source, double scale_factor)
  {
    return static_cast<int>(source * scale_factor);
  }

  void EnableFullDpiSupportIfAvailable(HWND hwnd)
  {
    HMODULE user32_module = LoadLibraryA("User32.dll");
    if (!user32_module)
      return;
    auto enable_non_client_dpi_scaling =
        reinterpret_cast<EnableNonClientDpiScaling *>(
            GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
    if (enable_non_client_dpi_scaling != nullptr)
    {
      enable_non_client_dpi_scaling(hwnd);
    }
    FreeLibrary(user32_module);
  }

  // 统一的四边原生 resize 判定区宽度（物理像素）。
  //
  // window_manager hidden 样式在 WM_NCCALCSIZE 中为左/右/下各保留 8px
  // 非客户区边框（DefWindowProc 据此命中 HTLEFT/HTRIGHT/HTBOTTOM），
  // 但 Win11 上顶部不保留边框，导致自绘标题栏上缘无法缩放窗口。
  // 这里按同样的 8px 补齐顶部，使四边判定区一致。不按 DPI 缩放——
  // 插件保留的边框本身就是 8 物理像素。
  constexpr int kResizeBorderWidth = 8;

  // 根据屏幕坐标点相对窗口 rect 的位置计算 HT* 命中结果。
  //
  // 纯函数（无成员状态），便于独立测试；非边缘区域返回 HTCLIENT，
  // 由调用方继续走 DefWindowProc（鼠标事件进入 Flutter 客户区）。
  int HitTestWindowEdge(RECT window_rect, POINT pt)
  {
    const bool near_left = pt.x - window_rect.left < kResizeBorderWidth;
    const bool near_top = pt.y - window_rect.top < kResizeBorderWidth;
    const bool near_right = window_rect.right - pt.x <= kResizeBorderWidth;
    const bool near_bottom = window_rect.bottom - pt.y <= kResizeBorderWidth;

    // 角落优先：角落区同时命中两条边，返回双向 resize 结果
    if (near_top && near_left)
      return HTTOPLEFT;
    if (near_top && near_right)
      return HTTOPRIGHT;
    if (near_bottom && near_left)
      return HTBOTTOMLEFT;
    if (near_bottom && near_right)
      return HTBOTTOMRIGHT;
    if (near_top)
      return HTTOP;
    if (near_bottom)
      return HTBOTTOM;
    if (near_left)
      return HTLEFT;
    if (near_right)
      return HTRIGHT;
    return HTCLIENT;
  }

} // namespace

// 窗口类注册管理器
class WindowClassRegistrar
{
public:
  ~WindowClassRegistrar() = default;

  static WindowClassRegistrar *GetInstance()
  {
    if (!instance_)
      instance_ = new WindowClassRegistrar();
    return instance_;
  }

  const wchar_t *GetWindowClass();
  void UnregisterWindowClass();

private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar *instance_;
  bool class_registered_ = false;
  HBRUSH background_brush_ = nullptr;
};

WindowClassRegistrar *WindowClassRegistrar::instance_ = nullptr;

const wchar_t *WindowClassRegistrar::GetWindowClass()
{
  if (!class_registered_)
  {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    background_brush_ = CreateSolidBrush(RGB(0, 0, 0));
    window_class.hbrBackground = background_brush_;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass()
{
  UnregisterClass(kWindowClassName, nullptr);
  if (background_brush_)
  {
    DeleteObject(background_brush_);
    background_brush_ = nullptr;
  }
  class_registered_ = false;
}

Win32Window::Win32Window()
{
  ++g_active_window_count;
}

Win32Window::~Win32Window()
{
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring &title,
                         const Point &origin,
                         const Size &size)
{
  Destroy();

  const wchar_t *window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window)
    return false;

  // 全屏切换防闪烁: media_kit 全屏经 SetWindowLongPtr 摘 WS_OVERLAPPEDWINDOW
  // 并 SWP_FRAMECHANGED, 该过程触发 DWM 按中间态样式重绘非客户区, 过渡帧
  // 画出系统标题栏经典外观(实机报告的"老版窗口"闪烁)。禁用本窗口的 DWM
  // 过渡动画 — attribute 独立于窗口样式重设, 一次设置持续生效。
  const BOOL disable_transitions = TRUE;
  DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED,
                        &disable_transitions, sizeof(disable_transitions));

  return OnCreate();
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept
{
  if (message == WM_NCCREATE)
  {
    auto window_struct = reinterpret_cast<CREATESTRUCT *>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window *>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  }
  else if (Win32Window *that = GetThisFromHandle(window))
  {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept
{
  switch (message)
  {
  case WM_DESTROY:
    window_handle_ = nullptr;
    Destroy();
    if (quit_on_close_)
      PostQuitMessage(0);
    return 0;

  case WM_DPICHANGED:
  {
    auto newRectSize = reinterpret_cast<RECT *>(lparam);
    LONG newWidth = newRectSize->right - newRectSize->left;
    LONG newHeight = newRectSize->bottom - newRectSize->top;
    SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top,
                 newWidth, newHeight, SWP_NOZORDER | SWP_NOACTIVATE);
    if (child_content_ != nullptr)
    {
      RECT rect = GetClientArea();
      MoveWindow(child_content_, rect.left, rect.top,
                 rect.right - rect.left, rect.bottom - rect.top, true);
    }
    return 0;
  }

  case WM_SIZE:
  {
    RECT rect = GetClientArea();
    if (child_content_ != nullptr)
    {
      MoveWindow(child_content_, rect.left, rect.top,
                 rect.right - rect.left, rect.bottom - rect.top, true);
    }
    return 0;
  }

  // Chromium 惯用法: 窗口激活态变化时令 DefWindowProc 跳过非客户区重绘
  // (lParam=-1), 压制样式切换期的框架闪帧 — 与 DWM 过渡禁用配合。
  case WM_NCACTIVATE:
    if (wparam != FALSE)
    {
      return DefWindowProc(window_handle_, message, wparam, -1);
    }
    break;

  // 纵深防御:正常情况下 window_manager 插件的 delegate 先于本 handler
  // 处理 WM_NCCALCSIZE(见 flutter_window.cpp 顶部的 media_kit 全屏抢先分支
  // 与插件 hidden 标题栏分支),本分支实际只在插件未接管时生效。
  case WM_NCCALCSIZE:
    if (wparam != FALSE)
      return 0;
    break;

  // Flutter owns the surface repaint; suppressing erase avoids a one-frame
  // background flash while the fullscreen route changes window bounds.
  case WM_ERASEBKGND:
    return 1;

  // 统一四边 resize 判定区。window_manager hidden 样式只在左/右/下保留
  // 8px 非客户区边框（DefWindowProc 只对这些区域返回 HT*），顶部没有；
  // 这里补齐顶部，使自绘标题栏上缘与左右下方一致支持原生 resize loop。
  case WM_NCHITTEST:
  {
    // 最大化/全屏时不进入 resize：边缘“缩放”与 Snap/Aero 语义冲突，
    // 且全屏视频时边缘误触发 resize 光标会破坏沉浸模式。
    if (IsZoomed(hwnd))
      break;
    POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    RECT rect;
    GetWindowRect(hwnd, &rect);
    const int hit = HitTestWindowEdge(rect, pt);
    if (hit != HTCLIENT)
      return hit;
    // 客户区命中交给 DefWindowProc：顶部 32px 标题栏的非边缘部分继续
    // 由 Flutter 层 startDragging() 拖动移动窗口。
    break;
  }
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy()
{
  OnDestroy();
  if (window_handle_)
  {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0)
  {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window *Win32Window::GetThisFromHandle(HWND const window) noexcept
{
  return reinterpret_cast<Win32Window *>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content)
{
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();
  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);
  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea()
{
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle()
{
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close)
{
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() { return true; }
void Win32Window::OnDestroy() {}
