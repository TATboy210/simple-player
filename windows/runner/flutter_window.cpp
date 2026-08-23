#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view())
  {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  return true;
}

void FlutterWindow::OnDestroy()
{
  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept
{
  // media_kit 原生全屏期间抢先处理 WM_NCCALCSIZE（必须早于插件 delegate，
  // 插件在 HandleTopLevelWindowProc 中先被调用且总是返回结果）。
  //
  // 根因：window_manager 插件 hidden 标题栏分支对非最大化窗口施加 8px
  // 客户区内缩（right/bottom -8, left +8）。media_kit 原生全屏只摘除
  // WS_OVERLAPPEDWINDOW 样式并 resize 到显示器，不更新插件状态，于是小窗
  // 进入全屏时 8px 内缩照样生效，表现为左/右/下黑缝（最大化进入走插件
  // IsMaximized 分支无内缩，故无缝）。
  //
  // 仅当窗口处于 media_kit 全屏样式（WS_OVERLAPPEDWINDOW 六标志全被摘除）
  // 时接管：客户区=整窗，四边无缝。其余模式完全不介入，插件的窗口态 8px
  // 内缩与最大化 adjust 行为保持现状；resize 判定区仍由 WM_NCHITTEST 提供。
  if (message == WM_NCCALCSIZE && wparam != FALSE)
  {
    // LONG_PTR 避免 64 位下 LONG_PTR→LONG 截断警告 (C4244)。
    const LONG_PTR style = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    if ((style & WS_OVERLAPPEDWINDOW) == 0)
    {
      return 0;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
