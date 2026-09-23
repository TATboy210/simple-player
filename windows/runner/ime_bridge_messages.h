#ifndef RUNNER_IME_BRIDGE_MESSAGES_H_
#define RUNNER_IME_BRIDGE_MESSAGES_H_

#include <windows.h>
#include <imm.h>

namespace ime_bridge_messages {
// Dart 侧 Win32ImeBridge 经 SendMessageTimeoutW 投递本消息，把 IMC 切换
// 挪回创建窗口的 platform 线程执行（IMM32 有线程亲和性，UI 线程直调
// ImmAssociateContextEx 可能静默失效，导致文件对话框 TSF 路径崩溃）。
// 消息号与 Dart 侧对齐：lib/kernel/bridge/win32/ime_bridge.dart 的
// _messageId = WM_APP(0x8000) + 0x49 = 0x8049。runner 全目录无其他
// WM_APP 占用（实证），
// bitsdojo/window_manager 走 RegisterWindowMessage（>0xC000），不相交。
constexpr UINT kAppSetImeEnabled = WM_APP + 0x49;

// wParam: 1 = 恢复系统默认输入法上下文（IACE_DEFAULT|IACE_CHILDREN），
//         0 = 再次解除（IACE_IGNORE|IACE_CHILDREN）。
// 两者均作用于顶层窗口与 FlutterView 子窗口，与 OnCreate 的解除对偶。
constexpr WPARAM kImeEnable = 1;
constexpr WPARAM kImeDisable = 0;

// 在窗口所属线程上执行 IMC 切换 — 仅由 FlutterWindow::MessageHandler 调用。
// ⚠ 常量以 SDK imm.h 为准：IACE_CHILDREN=0x0001, IACE_DEFAULT=0x0010，
// 不存在 IACE_IGNORE——上一版 Dart 桥自造的 0x0001/0x0002/0x0008 组合
// 恰好把"恢复"发成了"再次解除"，这是修复始终无效的真正元凶。
inline LRESULT HandleSetImeEnabled(HWND window, WPARAM wparam, HWND flutter_view) {
  const UINT flags = (wparam == kImeEnable)
                         ? (IACE_DEFAULT | IACE_CHILDREN)  // 0x0011 恢复默认 IMC（主+子）
                         : IACE_CHILDREN;                  // 0x0001 hIMC=NULL 解除关联（主+子）
  // 主窗口与 FlutterView 子窗口一并处理 — 键盘焦点在子窗口，组合发生在
  // 子窗口的 IMC 上，只处理主窗口候选窗照弹（00f94d79 实测踩坑）。
  ::ImmAssociateContextEx(window, nullptr, flags);
  if (flutter_view) {
    ::ImmAssociateContextEx(flutter_view, nullptr, flags);
  }
  return TRUE;
}
}  // namespace ime_bridge_messages

#endif  // RUNNER_IME_BRIDGE_MESSAGES_H_
