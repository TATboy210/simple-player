#include "flutter_window.h"

#include <windows.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kFilePickerAttentionChannel[] =
    "com.simple_player/file_picker_attention";
constexpr char kFocusExistingPickerMethod[] = "focusExistingPicker";

struct PickerSearchContext {
  HWND parent_window;
  DWORD process_id;
  HWND picker_window = nullptr;
};

// Common Item Dialog windows are #32770 dialogs owned by this Flutter process.
// Restricting by process and owner prevents activating an unrelated application.
BOOL CALLBACK FindOwnedPickerWindow(HWND window, LPARAM parameter) {
  auto* context = reinterpret_cast<PickerSearchContext*>(parameter);
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  if (process_id != context->process_id || !IsWindowVisible(window) ||
      GetWindow(window, GW_OWNER) != context->parent_window) {
    return TRUE;
  }

  wchar_t class_name[16] = {};
  if (GetClassName(window, class_name, 16) == 0 ||
      wcscmp(class_name, L"#32770") != 0) {
    return TRUE;
  }

  context->picker_window = window;
  return FALSE;
}

bool FocusOwnedPicker(HWND parent_window) {
  PickerSearchContext context{parent_window, GetCurrentProcessId()};
  EnumWindows(FindOwnedPickerWindow, reinterpret_cast<LPARAM>(&context));
  if (context.picker_window == nullptr) {
    return false;
  }

  // Foreground policy can reject the request; the audible cue still confirms
  // that the already-open picker was targeted without creating another one.
  return SetForegroundWindow(context.picker_window) != FALSE;
}

}  // namespace

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

  file_picker_attention_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          kFilePickerAttentionChannel,
          &flutter::StandardMethodCodec::GetInstance());
  file_picker_attention_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != kFocusExistingPickerMethod) {
          result->NotImplemented();
          return;
        }

        const bool found = FocusOwnedPicker(GetHandle());
        // MessageBeep is intentionally unconditional: it provides feedback on
        // Windows even when foreground activation is blocked by OS policy.
        MessageBeep(MB_OK);
        result->Success(flutter::EncodableValue(found));
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
  // Resize hit-testing must be resolved by the runner before Flutter/plugins;
  // otherwise a plugin can consume WM_NCHITTEST and bypass the native resize loop.
  if (message == WM_NCHITTEST) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  // Give Flutter, including plugins, an opportunity to handle other messages.
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
