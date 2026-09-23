#include "flutter_window.h"

#include <imm.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "fullscreen_resize_guard.h"
#include "ime_bridge_messages.h"

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

  // 临时兼容 bitsdojo：必须晚于插件注册，先于其父子窗口边缘命中处理。
  // media_kit 入原生全屏时摘除 WS_OVERLAPPEDWINDOW、退出时恢复；全屏态下
  // bitsdojo 的 WM_NCHITTEST 仍会对四边给出缩放命中，且 Flutter 子窗口可能
  // 被判 HTTRANSPARENT——本 guard 在全屏态屏蔽两者。销毁时经 WM_NCDESTROY
  // 自动解除，runner 不持有 Dart/Flutter 对象。
  if (!InstallFullscreenResizeGuard(
          GetHandle(), flutter_controller_->view()->GetNativeWindow())) {
    OutputDebugStringW(L"Failed to install fullscreen resize guard.\n");
    return false;
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // 播放器无文本输入场景 — 解除窗口与默认输入法上下文 (IMC) 的关联,
  // 根治中文输入法在窗口左上角弹候选窗的问题 (同 flutter/flutter#92050
  // 家族: 无 EditableText 锚点时组合窗定位到 0,0; 相关 #190042)。
  // 恢复入口已迁至本线程的 kAppSetImeEnabled 消息 (见 MessageHandler) —
  // Dart 侧 Win32ImeBridge 经 SendMessageTimeoutW 投递, IMC 切换始终在
  // 创建窗口的 platform 线程执行 (IMM32 线程亲和, UI 线程直调会静默
  // 失效)。未来落地文本输入框时按焦点启停 enable/disable。
  // ⚠ 必须同时解除 **主窗口与 FlutterView 子窗口** — 键盘焦点在子窗口,
  // 组合发生在子窗口的 IMC 上, 只解除主窗口候选窗照弹 (首版实测踩坑)。
  // ⚠ NULL IMC 与原生文件对话框冲突 (IFileOpenDialog 子窗口的 TSF 路径
  // 假定 IMC 存在 → imm32/msctf 空指针崩溃) — 一切原生文件对话框调用
  // 必须经 Dart 侧 Win32ImeBridge.withImeRestored 包裹 (弹窗期间临时
  // 恢复 IME), 新增 picker 时务必遵循。
  ImmAssociateContext(GetHandle(), nullptr);
  ImmAssociateContext(flutter_controller_->view()->GetNativeWindow(), nullptr);

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
    case ime_bridge_messages::kAppSetImeEnabled:
      // Dart 侧 Win32ImeBridge 投递 — 本线程即创建窗口的 platform 线程,
      // IMM32 调用在此亲和正确。flutter_view 句柄从控制器现取 (可能为
      // null 仅在销毁期, HandleSetImeEnabled 内部已判空跳过)。
      return ime_bridge_messages::HandleSetImeEnabled(
          hwnd, wparam,
          flutter_controller_ ? flutter_controller_->view()->GetNativeWindow()
                              : nullptr);
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
