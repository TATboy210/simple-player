#include "flutter_window.h"

#include <imm.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "ime_bridge_messages.h"

namespace {
// 关门专线：Dart 启动后经 SetCloseNotifier 注册一个无参回调
// （FFI NativeCallable.listener，可自 platform 线程安全唤起 UI isolate）。
// WM_CLOSE 有通知器时直接消费并唤起 Dart 的 hide-first persist→exit 时序；
// 未注册（启动极早期/降级）则放行默认销毁 — 旧的 close_bridge_messages
// SC_CLOSE 转换路径已退役（事件流退订后它等价于放行销毁，见 CONTRACT.md）。
// 指针在 Dart 侧永久保活：热重启后新注册覆盖旧值；空窗期极小且仅在 debug。
using CloseNotifier = void (*)();
CloseNotifier g_close_notifier = nullptr;

// 主窗口句柄槽 — OnCreate 写入、OnDestroy 清空。Dart 侧经
// SimplerPlayerGetMainWindowHandle 读取（隐藏态即可用，不依赖焦点/枚举）。
HWND g_main_window = nullptr;
}  // namespace

// C 链接导出（x64 无修饰名），Dart 经 DynamicLibrary.process() 查找。
extern "C" __declspec(dllexport) void SetCloseNotifier(CloseNotifier notifier) {
  g_close_notifier = notifier;
}

// C 链接导出 — 主窗口句柄（三平台同名符号，见 platform/window_handle_locator.dart）。
extern "C" __declspec(dllexport) void* SimplerPlayerGetMainWindowHandle() {
  return g_main_window;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  g_main_window = GetHandle();

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

  // frame/命中/拖动/全屏均由 nativeapi（Dart FFI）在
  // 窗口子类化层处理：隐藏标题栏、最大化贴合工作区、全屏摘除
  // caption/thickframe、标题栏拖动由 Dart 手势经系统拖动循环完成。首帧
  // Show() 保留——Dart 侧若在隐藏态请求最大化，nativeapi 记标记并让这次
  // Show 直接以最大化形态出现。runner 只保留关闭转换与 IME 两处消息。

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
  g_main_window = nullptr;
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

  // 关门专线优先：Dart 通知器在线时 WM_CLOSE 被消费，Dart 完成
  // hide→persist→closing-listeners→exit(0) 后进程自退，窗口无需再销毁。
  // 无通知器（启动极早期/降级）→ 落 DefWindowProc 默认销毁。
  if (message == WM_CLOSE) {
    if (CloseNotifier notifier = g_close_notifier) {
      notifier();
      return 0;
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
