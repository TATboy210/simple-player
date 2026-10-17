#include "flutter_window.h"

#include <imm.h>
#include <optional>

#include "caption_region.h"
#include "close_bridge_messages.h"
#include "flutter/generated_plugin_registrant.h"
#include "ime_bridge_messages.h"
#include "sizemove_bridge_messages.h"

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

  // frame/命中/全屏均由 nativeapi（Dart FFI）在窗口子类化层处理：隐藏
  // 标题栏、最大化贴合工作区、全屏摘除 caption/thickframe。首帧 Show()
  // 保留——Dart 侧若在隐藏态请求最大化，nativeapi 记标记并让这次 Show
  // 直接以最大化形态出现。runner 不自写窗口消息 hook。

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

  // 标题栏原生拖动区：FlutterView 在 Dart 上报的拖动区内命中穿透，顶层
  // 窗口回答 HTCAPTION（见 caption_region.h）。
  caption_region::AttachFlutterView(
      flutter_controller_->view()->GetNativeWindow());

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

  // WM_CLOSE → SC_CLOSE 补位，让外部关闭也走 nativeapi 的可取消关闭请求
  // （Dart 持久化后退出），见 close_bridge_messages.h。
  if (close_bridge_messages::HandleClose(hwnd, message, wparam)) {
    return 0;
  }

  // 自绘标题栏拖动区 → HTCAPTION（拖动/双击最大化/Snap/系统菜单全原生）。
  LRESULT hit_result = 0;
  if (caption_region::HandleHitTest(hwnd, message, lparam, &hit_result)) {
    return hit_result;
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
    case WM_ENTERSIZEMOVE:
      // v0.0.9 P0-1 拖窗/Resize 取证 — 仅记录原生模态循环起点, 不消费
      // 消息(落到 DefWindowProc), 窗口行为零变化 (见 sizemove_bridge_messages.h)。
      sizemove_bridge_messages::OnEnter();
      break;
    case WM_EXITSIZEMOVE:
      // 同上 — 记录模态循环终点。lag 由查询时刻现算, 此处只落 tick。
      sizemove_bridge_messages::OnExit();
      break;
    case sizemove_bridge_messages::kAppQuerySizemove:
      // Dart 侧 Win32SizemoveBridge 在 settle 关键时点查询 — 返回打包
      // 状态 (active + exitLag + enterTick), 见 sizemove_bridge_messages.h。
      return sizemove_bridge_messages::HandleQuerySizemove();
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
