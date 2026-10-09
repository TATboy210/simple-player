#ifndef RUNNER_SIZEMOVE_BRIDGE_MESSAGES_H_
#define RUNNER_SIZEMOVE_BRIDGE_MESSAGES_H_

#include <windows.h>

namespace sizemove_bridge_messages {
// v0.0.9 P0-1 拖窗/Resize 取证 — WM_ENTERSIZEMOVE / WM_EXITSIZEMOVE
// 原生模态循环观测。设计要点：
//  1. 纯观测：MessageHandler 对两个系统消息只记录状态、不消费（落到
//     DefWindowProc），窗口拖拽/缩放行为零变化。
//  2. 现有 Dart 侧 resize 起止完全靠 500ms 防抖推断（无原生边沿信号）；
//     本桥让 Dart 在 settle 关键时点查询「原生模态循环是否仍在进行」，
//     用于判定 debounce 推断与真实 session 的偏差（stale strip 取证）。
//  3. 消息号与 Dart 侧对齐：lib/kernel/bridge/win32/sizemove_bridge.dart
//     的 _messageId = WM_APP(0x8000) + 0x4A。与 ime 的 0x49 相邻，
//     runner 全目录无其他 WM_APP 占用（ime_bridge_messages.h 同款实证），
//     bitsdojo/window_manager 走 RegisterWindowMessage（>0xC000），不相交。
constexpr UINT kAppQuerySizemove = WM_APP + 0x4A;

// 模态循环状态 — 写入与读取都发生在窗口所属的 platform 线程
// （ENTERSIZEMOVE/EXITSIZEMOVE 由 WndProc 记录，kAppQuerySizemove 由
// Dart 经 SendMessageTimeoutW 投递回同一线程读取），无需锁。
bool g_active = false;
DWORD g_enterTick = 0;
DWORD g_exitTick = 0;

inline void OnEnter() {
  g_active = true;
  g_enterTick = ::GetTickCount();
}

inline void OnExit() {
  g_active = false;
  g_exitTick = ::GetTickCount();
}

// 返回打包状态（x64 LRESULT 64 位布局）：
//   bit 0       active — 查询时原生模态循环是否仍在进行
//   bits 1-16   exitLagMs — 距上次 WM_EXITSIZEMOVE 的毫秒数（active 时为 0；
//               16 位上限 65535ms，远超 settle 防抖 500ms 的观测窗口；
//               超限时饱和停在 65535，不回绕，见下）
//   bits 17-48  enterTick — 进入时刻（GetTickCount 时钟；0 = 本次运行从未
//               进入过，Dart 侧解码为 null）
inline LRESULT HandleQuerySizemove() {
  const LRESULT now = static_cast<LRESULT>(::GetTickCount());
  const LRESULT lagMs =
      g_active ? 0 : (now - static_cast<LRESULT>(g_exitTick));
  // 16 位饱和钳制而非 & 0xFFFF 位截断：取证数据超 65.5s 时应显式停在
  // 65535；回绕成小值会让 Dart 侧把「很久前已退出」误读成「刚退出」，
  // 直接污染 stale strip 判定（enterTick 字段不受影响——它是 32 位时钟
  // 原值，位宽内无回绕语义问题）。
  const LRESULT lagClamped = lagMs > 0xFFFF ? 0xFFFF : lagMs;
  return (g_active ? 1 : 0) | ((lagClamped) << 1) |
         ((static_cast<LRESULT>(g_enterTick) & 0xFFFFFFFFLL) << 17);
}
}  // namespace sizemove_bridge_messages

#endif  // RUNNER_SIZEMOVE_BRIDGE_MESSAGES_H_
