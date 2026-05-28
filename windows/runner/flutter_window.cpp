#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // D-35: Register window channel handler after HWND is available
  window_registrar_ = std::make_unique<flutter::PluginRegistrarWindows>(
      flutter_controller_->engine()->GetRegistrarForPlugin("WindowChannel"));
  window_channel_.Register(window_registrar_.get(), GetHandle());

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // ─── Frameless window handling (D-08, D-09, D-10) ───
  if (window_channel_.is_frameless()) {
    switch (message) {
      case WM_NCCALCSIZE:
        // D-08: Frameless via WM_NCCALCSIZE — remove non-client area
        if (wParam == TRUE) {
          auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
          // Preserve minimal top inset for resize cursor
          params->rgrc[0].top += 1;
          return 0;
        }
        break;

      case WM_NCHITTEST:
        // D-09 + D-10: Resize edges + drag region
        return window_channel_.HitTest(hwnd, lparam);
    }
  }

  // ─── EventChannel dispatch ───
  switch (message) {
    case WM_SIZE:
      window_channel_.OnResize(hwnd);
      break;
    case WM_CLOSE:
      window_channel_.OnClose();
      break;
    case WM_SYSCOMMAND:
      if ((wparam & 0xFFF0) == SC_MINIMIZE) {
        window_channel_.OnMinimize();
      }
      break;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
