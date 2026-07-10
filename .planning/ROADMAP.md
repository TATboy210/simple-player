# Roadmap: Player Fullscreen

**Created:** 2026-07-09
**Total Phases:** 4
**Total Requirements:** 22
**Mode:** standard

---

### Phase A — 架构定稿与核心模型

**Goal:** 建立 FullscreenAdapter 抽象层、状态模型、事件流和错误模型，UI 不再直接依赖插件

**Requirements:**

- STATE-01, STATE-02, STATE-03 (状态模型)
- EVT-01, EVT-02, EVT-03 (事件系统)
- ERR-01, ERR-02, ERR-03 (错误处理)
- ARCH-01, ARCH-02 (架构边界)

**Success Criteria:**

1. FullscreenAdapter 接口定义完成，UI 层只依赖此接口
2. FullscreenSnapshot 模型包含 phase/effectiveMode/restoreMode/lastError 等完整字段
3. FullscreenEvent 流覆盖 7 种事件类型
4. FullscreenError 枚举覆盖 7 种错误类型
5. WindowBridge 全屏相关职责迁出，保留通用窗口操作
6. flutter analyze 通过，无新增 warning

**Files to create/modify:**

- `lib/kernel/bridge/fullscreen_adapter.dart` (新建)
- `lib/kernel/models/fullscreen_snapshot.dart` (新建)
- `lib/kernel/models/fullscreen_event.dart` (新建)
- `lib/kernel/models/fullscreen_error.dart` (新建)
- `lib/kernel/models/fullscreen_capability.dart` (新建)
- `lib/kernel/models/fullscreen_request.dart` (新建)
- `test/kernel/bridge/fullscreen_adapter_test.dart` (新建)

**Dependencies:** 无
**Risk:** Medium — 接口设计决定后续所有实现

---

### Phase B — 命令队列与恢复策略

**Goal:** 实现 per-window 命令串行化、幂等合并、真实状态回读和完整恢复策略

**Requirements:**

- CMD-01, CMD-02, CMD-03 (命令队列)
- RST-01, RST-02, RST-03, RST-04 (恢复策略)
- ARCH-03 (旧实现迁移)

**Success Criteria:**

1. 快速连按 F 10 次不出现状态错位
2. windowed→fullscreen→exit 恢复到原始窗口几何
3. maximized→fullscreen→exit 恢复到 maximized
4. 副屏拖拽后全屏→exit 恢复到副屏原始位置
5. 旧 fullscreen_window 调用点全部迁移到 FullscreenAdapter
6. feature flag 可切换新旧实现

**Plans:** 3 plans

Plans:

- [x] 02-01-PLAN.md — FullscreenCommandQueue 核心队列逻辑（per-window 串行化、幂等合并、超时）
- [x] 02-02-PLAN.md — FullscreenDriver + DesktopFullscreenAdapter 完整实现（状态回读、恢复策略、事件流）
- [x] 02-03-PLAN.md — WindowService 迁移 + feature flag 配置（USE_NEW_FULLSCREEN）

**Files to create/modify:**

- `lib/kernel/bridge/fullscreen_command_queue.dart` (新建)
- `lib/kernel/bridge/fullscreen_driver.dart` (新建)
- `lib/kernel/bridge/desktop_fullscreen_driver.dart` (新建)
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` (新建)
- `lib/kernel/bridge/window_service.dart` (修改 — 迁移全屏逻辑)
- `lib/app.dart` (修改 — 注入 FullscreenAdapter + feature flag)
- `test/kernel/bridge/fullscreen_command_queue_test.dart` (新建)
- `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` (新建)

**Dependencies:** Phase A 完成
**Risk:** High — 竞态处理和恢复策略是最容易出 bug 的部分

---

### Phase C — 平台适配与深化

**Goal:** Windows/macOS/Linux 三端全屏体验生产级稳定，平台差异文档化

**Requirements:**

- PLAT-01 (Windows WS_THICKFRAME)
- PLAT-02 (macOS 原生生命周期)
- PLAT-03 (Linux GTK/WM 兜底)
- PLAT-04 (FullscreenCapability 查询)

**Success Criteria:**

1. Windows: 全屏无 7px 缝隙，退出后焦点正确，TopMost 无残留
2. macOS: 全屏过渡平滑，等待系统回调确认状态
3. Linux: GTK/WM 差异下状态回读正确
4. capabilities() 返回每平台真实能力
5. 三端 E2E 测试脚本通过
6. 主路径可日常使用

**Plans:** 4 plans

Plans:

- [x] 03-01-PLAN.md — WindowsFullscreenDriver (Win32 FFI: WS_THICKFRAME 剥离 + 焦点恢复 + TopMost 清理)
- [x] 03-02-PLAN.md — macOSFullscreenDriver (fullscreen_window 插件 + NSWindowDelegate 回调确认)
- [x] 03-03-PLAN.md — LinuxFullscreenDriver (fullscreen_window 插件 + window-state-event 信号 + WM 检测)
- [x] 03-04-PLAN.md — DesktopFullscreenDriverFactory + capabilities() + 集成接线

**Files to create/modify:**

- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` (新建)
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` (新建)
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` (新建)
- `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` (新建)
- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` (新建)
- `lib/kernel/bridge/fullscreen_driver.dart` (修改 — 添加 onNativeStateChanged + capabilities)
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` (修改 — 回调转发)
- `lib/main.dart` (修改 — 使用工厂)
- `packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.{h,m}` (修改 — NSWindowDelegate)
- `packages/fullscreen_window/linux/fullscreen_window_plugin.cc` (修改 — window-state-event)
- `packages/fullscreen_window/lib/fullscreen_window_{method_channel,platform_interface}.dart` (修改 — 回调流)
- `test/platform/windows_fullscreen_driver_test.dart` (新建)
- `test/platform/macos_fullscreen_driver_test.dart` (新建)
- `test/platform/linux_fullscreen_driver_test.dart` (新建)
- `test/platform/fullscreen_driver_factory_test.dart` (新建)

**Dependencies:** Phase B 完成
**Risk:** High — macOS/Linux 平台行为不一致是最大风险

---

### Phase D — 质量收尾与迁移完成

**Goal:** 回归矩阵验证、CI 补齐、旧实现可下线、RC 版本发布

**Requirements:**

- 所有 v1 需求验收

**Success Criteria:**

1. flutter analyze 零 warning
2. flutter test 全通过
3. Windows/macOS/Linux 构建冒烟通过
4. 必测场景 8 项全部通过（播放中/暂停中/连续切换/F 与按钮一致/ESC 语义/maximized 恢复/副屏恢复/多窗口隔离）
5. 旧 fullscreen_window 直连调用可下线或保留 feature flag fallback
6. 回归矩阵文档完成

**Plans:** 3 plans

Plans:

- [ ] 04-01-PLAN.md — 回归测试矩阵（高风险套件 + 冒烟套件 + 矩阵文档）
- [ ] 04-02-PLAN.md — CI/CD 流水线 + MSIX 打包配置
- [ ] 04-03-PLAN.md — 旧实现废弃标记 + RC 版本号 + E2E 测试脚手架

**Files to create/modify:**

- `test/regression/high_risk_suite_test.dart` (新建)
- `test/regression/smoke_suite_test.dart` (新建)
- `test/regression/regression_matrix.md` (新建)
- `.github/workflows/ci.yml` (新建)
- `.github/workflows/release.yml` (新建)
- `lib/kernel/bridge/window_service.dart` (修改 — deprecated 标记)
- `lib/main.dart` (修改 — 默认 flag 切换)
- `pubspec.yaml` (修改 — RC 版本号 + msix 配置)
- `test/integration/fullscreen_e2e_test.dart` (新建)

**Dependencies:** Phase C 完成
**Risk:** Low — 收尾阶段，主要是验证

---

## Summary

| Phase | Name | Requirements | Success Criteria | Risk |
|-------|------|-------------|------------------|------|
| A | 架构定稿与核心模型 | 11 | 6 | Medium |
| B | 命令队列与恢复策略 | 8 | 6 | High |
| C | 平台适配与深化 | 4 | 6 | High |
| D | 质量收尾与迁移完成 | 0 (验收) | 6 | Low |

**Total:** 22 v1 requirements + 5 v2 requirements

---
*Created: 2026-07-09*
*Last updated: 2026-07-09 after initialization*
