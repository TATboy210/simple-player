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

  // ForceRedraw 由 Dart 侧 WindowManagerService 通过 MethodChannel 触发，
  // 确保在 setAsFrameless() 完成后、show() 之前执行，
  // 使 Flutter 首帧在正确的 frameless 客户区尺寸下渲染。
  redraw_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.simple_player/redraw",
      &flutter::StandardMethodCodec::GetInstance());
  redraw_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "forceRedraw") {
              if (flutter_controller_) {
                  flutter_controller_->ForceRedraw();
              }
              result->Success(true);
          } else {
              result->NotImplemented();
          }
      });

  // Aspect ratio channel — Dart 侧设置窗口宽高比约束
  aspect_ratio_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.simple_player/aspect_ratio",
      &flutter::StandardMethodCodec::GetInstance());
  aspect_ratio_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "setAspectRatio") {
              const auto* args = std::get_if<double>(call.arguments());
              if (args) {
                  aspect_ratio_ = *args;
                  result->Success(nullptr);
              } else {
                  result->Error("INVALID_ARGS", "Expected a double value");
              }
          } else {
              result->NotImplemented();
          }
      });

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

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_SIZING: {
      if (aspect_ratio_ > 0.0) {
        auto* rect = reinterpret_cast<RECT*>(lparam);
        LONG w = rect->right - rect->left;
        LONG h = rect->bottom - rect->top;
        // Frameless window (TitleBarStyle.hidden): non-client area is
        // effectively zero.  Using GetClientRect here returns stale
        // pre-resize values, causing jittery ncW/ncH on every frame.
        LONG cw = w;
        LONG ch = h;

        // Calculate target client size based on drag edge
        int edge = static_cast<int>(wparam);
        switch (edge) {
          case WMSZ_LEFT:
          case WMSZ_RIGHT:
            ch = static_cast<LONG>(cw / aspect_ratio_);
            break;
          case WMSZ_TOP:
          case WMSZ_BOTTOM:
            cw = static_cast<LONG>(ch * aspect_ratio_);
            break;
          default:
            // Corners: use width as driver
            ch = static_cast<LONG>(cw / aspect_ratio_);
            break;
        }

        // Apply back to window rect (frameless: window == client)
        LONG newW = cw;
        LONG newH = ch;

        // Anchor opposite edge
        switch (edge) {
          case WMSZ_LEFT:
          case WMSZ_TOPLEFT:
          case WMSZ_BOTTOMLEFT:
            rect->left = rect->right - newW;
            break;
          default:
            rect->right = rect->left + newW;
            break;
        }
        switch (edge) {
          case WMSZ_TOP:
          case WMSZ_TOPLEFT:
          case WMSZ_TOPRIGHT:
            rect->top = rect->bottom - newH;
            break;
          default:
            rect->bottom = rect->top + newH;
            break;
        }
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
