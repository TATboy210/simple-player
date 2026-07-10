---
phase: 02-command-queue-recovery
date: 2026-07-09
status: pending
---

# Phase B Validation Strategy

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Quick run | `flutter test test/kernel/bridge/` |
| Full suite | `flutter test` |

### Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| CMD-01 | per-window 命令串行化 | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` |
| CMD-02 | 连续相同目标命令合并 | unit | `flutter test test/kernel/bridge/fullscreen_command_queue_test.dart` |
| CMD-03 | 状态回读 + StateDesync | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` |
| RST-01 | windowed 恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` |
| RST-02 | maximized 恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` |
| RST-03 | 副屏恢复 | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` |
| RST-04 | minimized 先 restore | unit | `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart` |
| ARCH-03 | 迁移调用点 | integration | `flutter test test/kernel/bridge/window_service_test.dart` |

### Sampling Rate
- Per task: `flutter test test/kernel/bridge/`
- Per wave: `flutter test`
- Phase gate: Full suite green

---
*Created: 2026-07-09*
