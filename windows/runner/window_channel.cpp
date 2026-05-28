#include "window_channel.h"

#include <dwmapi.h>
#include <windowsx.h>

#include <flutter/encodable_value.h>

#include <algorithm>

// DWM attributes for rounded corners (may be missing from older SDKs)
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

// ─── Constants ───

static const char kChannelName[] = "com.simple_player/window";
static const char kEventChannelName[] = "com.simple_player/window_events";

// Title bar height for getTitleBarBounds (D-16: 32px)
static constexpr int kTitleBarHeight = 32;

// Resize edge width (D-09: 8px)
static constexpr int kResizeEdge = 8;

// Default minimum window size (D-19: > 640x360)
static constexpr LONG kDefaultMinWidth = 640;
static constexpr LONG kDefaultMinHeight = 360;

WindowChannel::WindowChannel() = default;
WindowChannel::~WindowChannel() = default;

// ─── Registration ───

void WindowChannel::Register(flutter::PluginRegistrarWindows* registrar,
                             HWND hwnd) {
  hwnd_ = hwnd;

  // MethodChannel: com.simple_player/window
  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  // EventChannel: com.simple_player/window_events
  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const auto* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                    && events)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            event_sink_ = std::move(events);
            return nullptr;
          },
          [this](const auto* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            event_sink_ = nullptr;
            return nullptr;
          });

  event_channel_->SetStreamHandler(std::move(handler));
}

// ─── Method call dispatcher ───

void WindowChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "setFullscreen") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto it = args->find(flutter::EncodableValue("fullscreen"));
    if (it == args->end() || !std::holds_alternative<bool>(it->second)) {
      result->Error("invalid_args", "Missing bool 'fullscreen'");
      return;
    }
    SetFullscreen(std::get<bool>(it->second), *result);
  } else if (method == "setAlwaysOnTop") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto it = args->find(flutter::EncodableValue("alwaysOnTop"));
    if (it == args->end() || !std::holds_alternative<bool>(it->second)) {
      result->Error("invalid_args", "Missing bool 'alwaysOnTop'");
      return;
    }
    SetAlwaysOnTop(std::get<bool>(it->second), *result);
  } else if (method == "setSize") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto w_it = args->find(flutter::EncodableValue("width"));
    auto h_it = args->find(flutter::EncodableValue("height"));
    if (w_it == args->end() || h_it == args->end()) {
      result->Error("invalid_args", "Missing 'width' or 'height'");
      return;
    }
    double w = 0, h = 0;
    if (std::holds_alternative<double>(w_it->second)) {
      w = std::get<double>(w_it->second);
    } else if (std::holds_alternative<int>(w_it->second)) {
      w = static_cast<double>(std::get<int>(w_it->second));
    }
    if (std::holds_alternative<double>(h_it->second)) {
      h = std::get<double>(h_it->second);
    } else if (std::holds_alternative<int>(h_it->second)) {
      h = static_cast<double>(std::get<int>(h_it->second));
    }
    SetSize(w, h, *result);
  } else if (method == "setPosition") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto x_it = args->find(flutter::EncodableValue("x"));
    auto y_it = args->find(flutter::EncodableValue("y"));
    if (x_it == args->end() || y_it == args->end()) {
      result->Error("invalid_args", "Missing 'x' or 'y'");
      return;
    }
    double x = 0, y = 0;
    if (std::holds_alternative<double>(x_it->second)) {
      x = std::get<double>(x_it->second);
    } else if (std::holds_alternative<int>(x_it->second)) {
      x = static_cast<double>(std::get<int>(x_it->second));
    }
    if (std::holds_alternative<double>(y_it->second)) {
      y = std::get<double>(y_it->second);
    } else if (std::holds_alternative<int>(y_it->second)) {
      y = static_cast<double>(std::get<int>(y_it->second));
    }
    SetPosition(x, y, *result);
  } else if (method == "setMinSize") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto w_it = args->find(flutter::EncodableValue("width"));
    auto h_it = args->find(flutter::EncodableValue("height"));
    if (w_it == args->end() || h_it == args->end()) {
      result->Error("invalid_args", "Missing 'width' or 'height'");
      return;
    }
    double w = 0, h = 0;
    if (std::holds_alternative<double>(w_it->second)) {
      w = std::get<double>(w_it->second);
    } else if (std::holds_alternative<int>(w_it->second)) {
      w = static_cast<double>(std::get<int>(w_it->second));
    }
    if (std::holds_alternative<double>(h_it->second)) {
      h = std::get<double>(h_it->second);
    } else if (std::holds_alternative<int>(h_it->second)) {
      h = static_cast<double>(std::get<int>(h_it->second));
    }
    SetMinSize(w, h, *result);
  } else if (method == "setFrameless") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("invalid_args", "Expected map argument");
      return;
    }
    auto it = args->find(flutter::EncodableValue("frameless"));
    if (it == args->end() || !std::holds_alternative<bool>(it->second)) {
      result->Error("invalid_args", "Missing bool 'frameless'");
      return;
    }
    SetFrameless(std::get<bool>(it->second), *result);
  } else if (method == "getTitleBarBounds") {
    GetTitleBarBounds(*result);
  } else if (method == "minimize") {
    Minimize(*result);
  } else if (method == "maximize") {
    Maximize(*result);
  } else if (method == "restore") {
    Restore(*result);
  } else if (method == "close") {
    Close(*result);
  } else if (method == "center") {
    Center(*result);
  } else {
    result->NotImplemented();
  }
}

// ─── Command implementations ───

void WindowChannel::SetFullscreen(
    bool fullscreen,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  if (fullscreen == is_fullscreen_) {
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (fullscreen) {
    // Save current window rect and style for restore
    GetWindowRect(hwnd_, &saved_rect_);
    saved_style_ = static_cast<DWORD>(GetWindowLongPtr(hwnd_, GWL_STYLE));

    // Get monitor rect
    HMONITOR monitor = MonitorFromWindow(hwnd_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {};
    mi.cbSize = sizeof(mi);
    GetMonitorInfo(monitor, &mi);

    // Remove caption and thickframe for borderless fullscreen
    DWORD style = saved_style_;
    style &= ~(WS_CAPTION | WS_THICKFRAME);
    SetWindowLongPtr(hwnd_, GWL_STYLE, style);

    // Cover the entire monitor work area
    SetWindowPos(hwnd_, nullptr, mi.rcMonitor.left, mi.rcMonitor.top,
                 mi.rcMonitor.right - mi.rcMonitor.left,
                 mi.rcMonitor.bottom - mi.rcMonitor.top,
                 SWP_NOZORDER | SWP_FRAMECHANGED);
  } else {
    // Restore saved style and rect
    SetWindowLongPtr(hwnd_, GWL_STYLE, saved_style_);

    SetWindowPos(hwnd_, nullptr, saved_rect_.left, saved_rect_.top,
                 saved_rect_.right - saved_rect_.left,
                 saved_rect_.bottom - saved_rect_.top,
                 SWP_NOZORDER | SWP_FRAMECHANGED);
  }

  is_fullscreen_ = fullscreen;

  // D-21: Re-apply rounded corners after fullscreen transition.
  // Windows 11 DWM resets DWMWA_WINDOW_CORNER_PREFERENCE during transitions.
  DWORD corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(hwnd_, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner, sizeof(corner));

  // Send event to Dart
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onFullscreenChange");
  data[flutter::EncodableValue("fullscreen")] =
      flutter::EncodableValue(fullscreen);
  SendEvent("onFullscreenChange", data);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::SetAlwaysOnTop(
    bool always_on_top,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  HWND insert_after = always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST;
  SetWindowPos(hwnd_, insert_after, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::SetSize(
    double width, double height,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  // Enforce min size
  LONG w = std::max(static_cast<LONG>(width), min_width_);
  LONG h = std::max(static_cast<LONG>(height), min_height_);

  SetWindowPos(hwnd_, nullptr, 0, 0, w, h,
               SWP_NOZORDER | SWP_NOMOVE | SWP_FRAMECHANGED);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::SetPosition(
    double x, double y,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  SetWindowPos(hwnd_, nullptr, static_cast<int>(x), static_cast<int>(y), 0, 0,
               SWP_NOZORDER | SWP_NOSIZE);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::SetMinSize(
    double width, double height,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  min_width_ = static_cast<LONG>(width);
  min_height_ = static_cast<LONG>(height);
  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::SetFrameless(
    bool frameless,
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  is_frameless_ = frameless;

  if (hwnd_) {
    LONG_PTR style = GetWindowLongPtr(hwnd_, GWL_STYLE);
    if (frameless) {
      // Remove WS_CAPTION (title bar + borders), keep WS_THICKFRAME for
      // resize edges and snap layout support (D-08, D-31).
      style &= ~WS_CAPTION;
      style |= WS_THICKFRAME;
    } else {
      // Restore full overlapped window style
      style |= (WS_CAPTION | WS_THICKFRAME);
    }
    SetWindowLongPtr(hwnd_, GWL_STYLE, style);
    SetWindowPos(hwnd_, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
  }

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::GetTitleBarBounds(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  RECT rect;
  GetWindowRect(hwnd_, &rect);

  flutter::EncodableMap bounds;
  bounds[flutter::EncodableValue("x")] = flutter::EncodableValue(0.0);
  bounds[flutter::EncodableValue("y")] = flutter::EncodableValue(0.0);
  bounds[flutter::EncodableValue("width")] =
      flutter::EncodableValue(static_cast<double>(rect.right - rect.left));
  bounds[flutter::EncodableValue("height")] =
      flutter::EncodableValue(static_cast<double>(kTitleBarHeight));

  result->Success(bounds);
}

void WindowChannel::Minimize(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }
  ShowWindow(hwnd_, SW_MINIMIZE);
  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::Maximize(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }
  ShowWindow(hwnd_, SW_MAXIMIZE);

  // Send onMaximize event
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onMaximize");
  data[flutter::EncodableValue("maximized")] =
      flutter::EncodableValue(true);
  SendEvent("onMaximize", data);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::Restore(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }
  ShowWindow(hwnd_, SW_RESTORE);

  // Send onMaximize event (restored = not maximized)
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onMaximize");
  data[flutter::EncodableValue("maximized")] =
      flutter::EncodableValue(false);
  SendEvent("onMaximize", data);

  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::Close(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }
  PostMessage(hwnd_, WM_CLOSE, 0, 0);
  result->Success(flutter::EncodableValue(true));
}

void WindowChannel::Center(
    const flutter::MethodResult<flutter::EncodableValue>& result) {
  if (!hwnd_) {
    result->Error("no_window", "Window handle is null");
    return;
  }

  // Get current window size
  RECT window_rect;
  GetWindowRect(hwnd_, &window_rect);
  LONG w = window_rect.right - window_rect.left;
  LONG h = window_rect.bottom - window_rect.top;

  // Get primary monitor work area
  HMONITOR monitor = MonitorFromWindow(hwnd_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  GetMonitorInfo(monitor, &mi);

  // Calculate centered position within work area
  LONG x = mi.rcWork.left + (mi.rcWork.right - mi.rcWork.left - w) / 2;
  LONG y = mi.rcWork.top + (mi.rcWork.bottom - mi.rcWork.top - h) / 2;

  SetWindowPos(hwnd_, nullptr, x, y, 0, 0,
               SWP_NOZORDER | SWP_NOSIZE | SWP_FRAMECHANGED);

  result->Success(flutter::EncodableValue(true));
}

// ─── MessageHandler delegates ───

LRESULT WindowChannel::HandleNcCalcSize(HWND hwnd, WPARAM wparam,
                                         LPARAM lparam) {
  // D-08: Frameless via WM_NCCALCSIZE — remove non-client area
  // Only intercept when wParam == TRUE (client area validation)
  if (wparam != TRUE || !is_frameless_) {
    return -1;  // Not handled — use default processing
  }

  // Preserve minimal top inset for resize cursor.
  // WS_THICKFRAME provides the resize borders for snap layout support (D-31).
  auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
  params->rgrc[0].top += 1;
  return 0;
}

void WindowChannel::OnGetMinMaxInfo(LPARAM lparam) {
  // D-19: Enforce minimum window size (> 640x360)
  auto mmi = reinterpret_cast<MINMAXINFO*>(lparam);
  if (min_width_ > 0) {
    mmi->ptMinTrackSize.x = min_width_;
  } else {
    mmi->ptMinTrackSize.x = kDefaultMinWidth;
  }
  if (min_height_ > 0) {
    mmi->ptMinTrackSize.y = min_height_;
  } else {
    mmi->ptMinTrackSize.y = kDefaultMinHeight;
  }
}

LRESULT WindowChannel::HitTest(HWND hwnd, LPARAM lparam) {
  if (!is_frameless_) {
    return HTCLIENT;
  }

  POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  ScreenToClient(hwnd, &pt);

  RECT rc;
  GetClientRect(hwnd, &rc);

  const int edge = kResizeEdge;

  bool left = pt.x < edge;
  bool right = pt.x >= rc.right - edge;
  bool top = pt.y < edge;
  bool bottom = pt.y >= rc.bottom - edge;

  // 8-direction resize detection (D-09)
  if (top && left) return HTTOPLEFT;
  if (top && right) return HTTOPRIGHT;
  if (bottom && left) return HTBOTTOMLEFT;
  if (bottom && right) return HTBOTTOMRIGHT;
  if (left) return HTLEFT;
  if (right) return HTRIGHT;
  if (top) return HTTOP;
  if (bottom) return HTBOTTOM;

  // Title bar drag region (D-10: 32px from top)
  if (pt.y < kTitleBarHeight) return HTCAPTION;

  return HTCLIENT;
}

void WindowChannel::OnResize(HWND hwnd) {
  if (!hwnd) return;

  RECT rect;
  GetWindowRect(hwnd, &rect);
  LONG w = rect.right - rect.left;
  LONG h = rect.bottom - rect.top;

  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onResize");
  data[flutter::EncodableValue("width")] =
      flutter::EncodableValue(static_cast<double>(w));
  data[flutter::EncodableValue("height")] =
      flutter::EncodableValue(static_cast<double>(h));
  SendEvent("onResize", data);
}

void WindowChannel::OnClose() {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onClose");
  SendEvent("onClose", data);
}

void WindowChannel::OnMinimize() {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onMinimize");
  SendEvent("onMinimize", data);
}

void WindowChannel::OnMaximizeChanged(HWND hwnd, bool maximized) {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("event")] =
      flutter::EncodableValue("onMaximize");
  data[flutter::EncodableValue("maximized")] =
      flutter::EncodableValue(maximized);
  SendEvent("onMaximize", data);

  // Re-apply rounded corners after maximize/restore (D-21)
  DWORD corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner, sizeof(corner));
}

// ─── Event helpers ───

void WindowChannel::SendEvent(const std::string& event,
                               const flutter::EncodableMap& data) {
  if (event_sink_) {
    event_sink_->Success(data);
  }
}
