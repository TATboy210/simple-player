#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <algorithm>

#include "resource.h"

namespace
{

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

  /// Re-apply rounded corners. Windows 11 DWM resets DWMWA_WINDOW_CORNER_PREFERENCE
  /// during snap/maximize/restore transitions.
  void ApplyRoundedCorners(HWND hwnd)
  {
    DWORD corner = DWMWCP_ROUND;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                          &corner, sizeof(corner));
  }

  // Classify the physical-pixel border under the pointer so Windows can run
  // its native resize loop for this frameless window.
  LRESULT HitTestResizeBorder(HWND hwnd, LPARAM lparam)
  {
    // A non-resizable window must never expose HT* even if the pointer is on
    // the physical border; this also protects against plugin style timing.
    const LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
    if (IsZoomed(hwnd) || IsIconic(hwnd) ||
        (style & WS_THICKFRAME) == 0) {
      return HTCLIENT;
    }

    RECT window_rect{};
    if (!GetWindowRect(hwnd, &window_rect)) {
      return HTCLIENT;
    }

    const UINT dpi = GetDpiForWindow(hwnd);
    const int dpi_scale = dpi == 0 ? USER_DEFAULT_SCREEN_DPI : dpi;
    const int frame_x = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi_scale) +
                        GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi_scale);
    const int frame_y = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi_scale) +
                        GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi_scale);
    // Use one DPI-aware thickness for every edge so HTTOP has the same
    // physical hit area as the left, right, and bottom edges.
    const int resize_border_thickness = std::max(frame_x, frame_y);
    const POINT cursor = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    const bool left = cursor.x < window_rect.left + resize_border_thickness;
    const bool right = cursor.x >= window_rect.right - resize_border_thickness;
    const bool top = cursor.y < window_rect.top + resize_border_thickness;
    const bool bottom =
        cursor.y >= window_rect.bottom - resize_border_thickness;

    // The Flutter title-bar controls occupy the rightmost four 36 px slots
    // (the pin button may be hidden, but reserving the full strip is safe).
    // Keep this area client hit-testable so native resize cannot swallow
    // minimize/maximize/close/pin clicks.
    constexpr LONG kTitleBarHeight = 32;
    constexpr LONG kTitleBarControlWidth = 36;
    constexpr LONG kTitleBarControlSlots = 4;
    const LONG title_bar_height =
        MulDiv(kTitleBarHeight, dpi_scale, USER_DEFAULT_SCREEN_DPI);
    const LONG title_bar_controls_width = MulDiv(
        kTitleBarControlWidth * kTitleBarControlSlots, dpi_scale,
        USER_DEFAULT_SCREEN_DPI);
    const bool title_bar_controls =
        cursor.y >= window_rect.top &&
        cursor.y < window_rect.top + title_bar_height &&
        cursor.x >= window_rect.right - title_bar_controls_width;
    if (title_bar_controls) return HTCLIENT;

    if (left && top) return HTTOPLEFT;
    if (right && top) return HTTOPRIGHT;
    if (left && bottom) return HTBOTTOMLEFT;
    if (right && bottom) return HTBOTTOMRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    return HTCLIENT;
  }

  constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

  /// Registry key for app theme preference.
  ///
  /// A value of 0 indicates apps should use dark mode. A non-zero or missing
  /// value indicates apps should use light mode.
  constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
  constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

  // The number of Win32Window objects that currently exist.
  static int g_active_window_count = 0;

  using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

  // Scale helper to convert logical scaler values to physical using passed in
  // scale factor
  int Scale(int source, double scale_factor)
  {
    return static_cast<int>(source * scale_factor);
  }

  // Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
  // This API is only needed for PerMonitor V1 awareness mode.
  void EnableFullDpiSupportIfAvailable(HWND hwnd)
  {
    HMODULE user32_module = LoadLibraryA("User32.dll");
    if (!user32_module)
    {
      return;
    }
    auto enable_non_client_dpi_scaling =
        reinterpret_cast<EnableNonClientDpiScaling *>(
            GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
    if (enable_non_client_dpi_scaling != nullptr)
    {
      enable_non_client_dpi_scaling(hwnd);
    }
    FreeLibrary(user32_module);
  }

} // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar
{
public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar *GetInstance()
  {
    if (!instance_)
    {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t *GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
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
    // Flutter manages its own surface invalidation; CS_HREDRAW|CS_VREDRAW
    // forces a full black-flash erase on every resize frame.
    window_class.style = 0;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    background_brush_ = CreateSolidBrush(RGB(0, 0, 0));
    if (background_brush_ == nullptr)
    {
      return nullptr;
    }
    window_class.hbrBackground = background_brush_;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    if (RegisterClass(&window_class) == 0)
    {
      DeleteObject(background_brush_);
      background_brush_ = nullptr;
      return nullptr;
    }
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
  if (window_class == nullptr)
  {
    return false;
  }

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const UINT effective_dpi = dpi == 0 ? USER_DEFAULT_SCREEN_DPI : dpi;
  const double scale_factor =
      static_cast<double>(effective_dpi) / USER_DEFAULT_SCREEN_DPI;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window)
  {
    return false;
  }

  UpdateTheme(window);

  // Restore rounded corners on Windows 11 (stripped by setAsFrameless)
  ApplyRoundedCorners(window);

  destroy_notified_ = false;
  if (!OnCreate())
  {
    // Roll back a partially initialized window so callers can retry safely.
    Destroy();
    return false;
  }

  return true;
}

bool Win32Window::Show()
{
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept
{
  if (message == WM_NCCREATE)
  {
    const auto *window_struct = reinterpret_cast<const CREATESTRUCT *>(lparam);
    if (window_struct == nullptr || window_struct->lpCreateParams == nullptr)
    {
      return FALSE;
    }

    auto that = static_cast<Win32Window *>(window_struct->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(that));
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
    // Notify subclasses while the HWND is still available, matching the
    // explicit Destroy() path. Destroy() then clears the handle and performs
    // class cleanup without repeating OnDestroy().
    if (!destroy_notified_)
    {
      destroy_notified_ = true;
      OnDestroy();
    }
    window_handle_ = nullptr;
    child_content_ = nullptr;
    Destroy();
    if (quit_on_close_)
    {
      PostQuitMessage(0);
    }
    return 0;

  case WM_DPICHANGED:
  {
    const auto *new_rect = reinterpret_cast<const RECT *>(lparam);
    if (new_rect == nullptr)
    {
      return 0;
    }

    const LONG new_width = new_rect->right - new_rect->left;
    const LONG new_height = new_rect->bottom - new_rect->top;
    SetWindowPos(hwnd, nullptr, new_rect->left, new_rect->top, new_width,
                 new_height, SWP_NOZORDER | SWP_NOACTIVATE);

    return 0;
  }
  case WM_SIZE:
  {
    const RECT rect = GetClientArea();
    if (IsWindow(child_content_) && rect.right >= rect.left &&
        rect.bottom >= rect.top)
    {
      // FALSE: defer repaint to DWM composition, avoid synchronous
      // repaint-per-frame during drag resize (eliminates tearing).
      MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                 rect.bottom - rect.top, FALSE);
    }
    // Re-apply rounded corners after snap/maximize/restore.
    ApplyRoundedCorners(hwnd);
    return 0;
  }

  case WM_NCHITTEST:
    return HitTestResizeBorder(hwnd, lparam);

  case WM_NCCALCSIZE:
  {
    // Frameless window: fold non-client area to zero for ALL states
    // (windowed, maximized, fullscreen). Eliminates WS_THICKFRAME ~7px
    // invisible borders. WM_NCHITTEST below restores native edge/corner
    // resize hit-testing without reintroducing a visible non-client frame.
    // Note: maximized window covers taskbar — use rcWork in SetWindowPos
    // for correct maximize bounds (already handled in WindowService).
    if (wparam == TRUE)
    {
      return 0;
    }
    break;
  }

  case WM_ERASEBKGND:
    // Skip background erase - Flutter handles its own surface.
    // Prevents black-flash during resize when CS_HREDRAW/CS_VREDRAW is off.
    return 1;

  case WM_ACTIVATE:
    if (LOWORD(wparam) != WA_INACTIVE && IsWindow(child_content_))
    {
      SetFocus(child_content_);
    }
    return 0;

  case WM_DWMCOLORIZATIONCOLORCHANGED:
    UpdateTheme(hwnd);
    return 0;
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}

void Win32Window::Destroy()
{
  if (!destroy_notified_)
  {
    destroy_notified_ = true;
    OnDestroy();
  }

  if (window_handle_)
  {
    const HWND window = window_handle_;
    if (DestroyWindow(window))
    {
      window_handle_ = nullptr;
    }
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
  if (!IsWindow(content) || !IsWindow(window_handle_))
  {
    child_content_ = nullptr;
    return;
  }

  child_content_ = content;
  SetLastError(ERROR_SUCCESS);
  SetParent(content, window_handle_);
  if (GetLastError() != ERROR_SUCCESS)
  {
    child_content_ = nullptr;
    return;
  }

  const RECT frame = GetClientArea();
  if (frame.right < frame.left || frame.bottom < frame.top)
  {
    child_content_ = nullptr;
    return;
  }

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, TRUE);
  SetFocus(content);
}

RECT Win32Window::GetClientArea()
{
  RECT frame{};
  if (!IsWindow(window_handle_) || !GetClientRect(window_handle_, &frame))
  {
    return {};
  }
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

bool Win32Window::OnCreate()
{
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy()
{
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window)
{
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS)
  {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
