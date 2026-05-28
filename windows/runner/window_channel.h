#ifndef RUNNER_WINDOW_CHANNEL_H_
#define RUNNER_WINDOW_CHANNEL_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

// C++ MethodChannel/EventChannel handler for window management.
//
// Handles 7 commands from Dart: setFullscreen, setAlwaysOnTop, setSize,
// setPosition, setMinSize, setFrameless, getTitleBarBounds.
// Streams 5 event types to Dart: onResize, onMove, onFullscreenChange,
// onClose, onMinimize.
class WindowChannel {
 public:
  WindowChannel();
  ~WindowChannel();

  // Register MethodChannel and EventChannel with the Flutter engine.
  // Must be called from FlutterWindow::OnCreate after HWND exists.
  void Register(flutter::PluginRegistrarWindows* registrar, HWND hwnd);

  // ─── Query state ───
  bool is_frameless() const { return is_frameless_; }
  bool is_fullscreen() const { return is_fullscreen_; }

  // ─── MessageHandler delegates (called from FlutterWindow) ───

  // WM_NCCALCSIZE handler — returns 0 when frameless (removes non-client area).
  // Returns -1 if not frameless (caller should use default handling).
  LRESULT HandleNcCalcSize(HWND hwnd, WPARAM wparam, LPARAM lparam);

  // WM_NCHITTEST handler — returns hit-test result for frameless window.
  LRESULT HitTest(HWND hwnd, LPARAM lparam);

  // WM_GETMINMAXINFO handler — enforces minimum window size.
  void OnGetMinMaxInfo(LPARAM lparam);

  // WM_SIZE handler — sends onResize event via EventChannel.
  void OnResize(HWND hwnd);

  // WM_CLOSE handler — sends onClose event via EventChannel.
  void OnClose();

  // WM_MINIMIZE handler — sends onMinimize event via EventChannel.
  void OnMinimize();

  // WM_SIZE maximize/restore handler — sends onMaximize event via EventChannel.
  void OnMaximizeChanged(HWND hwnd, bool maximized);

 private:
  HWND hwnd_ = nullptr;
  bool is_frameless_ = false;
  bool is_fullscreen_ = false;

  // Pre-fullscreen state for restore
  RECT saved_rect_ = {};
  DWORD saved_style_ = 0;

  // Min size constraints (set via setMinSize command)
  LONG min_width_ = 0;
  LONG min_height_ = 0;

  // Channel objects — must outlive the handler
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;

  // EventChannel sink — null when no listener is attached
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // ─── Command handlers ───
  void SetFullscreen(bool fullscreen,
                     flutter::MethodResult<flutter::EncodableValue>& result);
  void SetAlwaysOnTop(
      bool always_on_top,
      flutter::MethodResult<flutter::EncodableValue>& result);
  void SetSize(double width, double height,
               flutter::MethodResult<flutter::EncodableValue>& result);
  void SetPosition(double x, double y,
                   flutter::MethodResult<flutter::EncodableValue>& result);
  void SetMinSize(double width, double height,
                  flutter::MethodResult<flutter::EncodableValue>& result);
  void SetFrameless(bool frameless,
                    flutter::MethodResult<flutter::EncodableValue>& result);
  void GetTitleBarBounds(
      flutter::MethodResult<flutter::EncodableValue>& result);
  void Minimize(flutter::MethodResult<flutter::EncodableValue>& result);
  void Maximize(flutter::MethodResult<flutter::EncodableValue>& result);
  void Restore(flutter::MethodResult<flutter::EncodableValue>& result);
  void Close(flutter::MethodResult<flutter::EncodableValue>& result);
  void Center(flutter::MethodResult<flutter::EncodableValue>& result);

  // ─── Event helpers ───
  void SendEvent(const std::string& event,
                 const flutter::EncodableMap& data);

  // Method call dispatcher
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // RUNNER_WINDOW_CHANNEL_H_
