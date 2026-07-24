# Simple Player — 设置面板框架重构（v4.0）

## What This Is

Simple Player Flutter 桌面播放器（fvp / MDK-FFmpeg 引擎）的设置面板框架重构。以 Kodi + Steam 混合导航范式为核心，重建设置面板框架骨架，支持 D-pad/手柄/键鼠三模态交互，保持毛玻璃设计语言一致性。**v4.0 聚焦框架层（窗口绘制 + 导航系统 + 交互模式），不实现具体设置功能，先建立更加详细高效的计划。**

## Core Value

设置面板的框架质量与交互一致性 — 毛玻璃设计语言统一、D-pad/手柄/键鼠三模态导航流畅、框架与功能分离（先骨架后填充），且**延迟应用模式保护用户设置安全**。状态模型清晰、组件可复用、可测试。

## Current Milestone: v4.0 设置面板框架重构

**Goal:** 重建设置面板框架骨架，支持 D-pad/手柄/键鼠三模态交互，毛玻璃设计语言一致，先框架后功能。

**Target features:**

1. **Overlay Shell & State Model** — 毛玻璃覆盖层壳 + SettingsPanelState (ValueNotifier) + Controller (open/close/pause/resume)
2. **Sidebar Navigation** — 固定 200px 侧边栏 + 7 tab 列表 + FadeTransition 动画 + LB/RB 切换
3. **Tab Content Framework** — SettingRow 组件（Switch/Slider/SpinControl/Dropdown）+ OK/Cancel/Apply 延迟应用
4. **Gamepad & Keyboard Navigation** — FocusTraversalGroup 分区 + SpinControl + D-pad ←→ 调值 + A 确认 + B 关闭
5. **Responsive Scaling** — 全屏/小窗口适配 + Scale+Fade 动效 + 集成测试

## Requirements

### Validated

- ✓ 播放核心功能（播放/暂停/seek/音量/播放模式）— 现有
- ✓ fvp (MDK/FFmpeg) 播放引擎集成 — 现有
- ✓ ValueNotifier + ValueListenableBuilder 状态管理 — 现有
- ✓ 键盘快捷键系统（20+ 快捷键）— 现有
- ✓ 毛玻璃设计语言（GlassContainer、Tokens.*）— 现有
- ✓ 沉浸式全屏功能 — v2.0 已完成
- ✓ 引擎接口分解（ISP：EngineStateView + PlaybackControl + 能力接口）— v2.1
- ✓ 状态机穷举（6 态正交 MediaState）— v2.1
- ✓ `MemoryMonitor` / `EngineMetrics` / `EngineEventLog` 初版 — v2.1
- ✓ 内核基线契约固化（Phase 15）— v3.0
- ✓ 兼容适配层骨架 + DiagnosticsBundle（Phase 16）— v3.0
- ✓ 零依赖 KernelLogger 门面（Phase 17）— v3.0
- ✓ Sealed 错误模型稳化（Phase 18）— v3.0
- ✓ MemoryMonitor 一等化（Phase 19）— v3.0
- ✓ 状态与生命周期重写（Phase 20）— v3.0
- ✓ 测试与迁移验证（Phase 21）— v3.0
- ✓ 双语 API 文档注释标准（Phase 22）— v3.0

### Active

<!-- v4.0 scope — 设置面板框架重构。Building toward these. -->

- [ ] Overlay Shell & State Model（毛玻璃覆盖层 + 状态模型 + 控制器 + 暂停/恢复）
- [ ] Sidebar Navigation（固定 200px 侧边栏 + 7 tab + FadeTransition + LB/RB 切换）
- [ ] Gamepad & Keyboard Navigation（FocusTraversalGroup + SpinControl + D-pad + A/B 键）
- [ ] Responsive Scaling（全屏/小窗口适配 + 动效 + 集成测试）

### Validated (continued)

- ✓ Tab Content Framework（SettingRow 组件 + OK/Cancel/Apply 延迟应用模式）— Phase 25

### Out of Scope

- 具体设置功能逻辑 — 本里程碑只建框架骨架，功能在 v4.1+ 填充
- 导入导出 — 非核心框架功能，推迟到 v4.2+
- 独立窗口模式 — 当前使用覆盖层架构
- 手柄输入适配层 — Steam Input API 自动映射，无需 Flutter 侧代码
- 内核重写 — v3.0 已完成，本次不涉及内核改动

## Context

**技术环境：**

- Flutter 桌面播放器，Windows 为主平台
- fvp (MDK/FFmpeg) 作为播放引擎
- ValueNotifier + ValueListenableBuilder 状态管理
- 毛玻璃设计语言（GlassContainer + Tokens.*）

**v3.0 内核状态（已完成）：**

内核经过 Phase 15-22 完整重写：兼容适配层 → 零依赖 Logger → sealed 错误 → MemoryMonitor 一等化 → 状态机重写 → 测试验证 → 双语文档。内核稳定，可作为 v4.0 的基础。

**v4.0 设置面板现状（重写对象）：**

- `lib/ui/dialogs/settings_panel.dart` — 当前实现（~500 行，7 tab，可拖拽覆盖层，OK/Cancel/Apply）
- `lib/ui/shared/settings_card.dart` — SettingRow 布局组件
- 依赖：MediaEngine + VideoProcessingService + WindowBridge
- 状态：`_selectedIndex`、`_offset`（ValueNotifier<Offset>）、`_pendingLocale`、`_pendingThemeIndex`、`_originalShortcuts`

**已知问题（v4.0 要解决）：**

- 当前设置面板（settings_panel.dart ~500 行）职责混合：状态管理 + UI 渲染 + 拖拽逻辑 + 延迟应用全在一个文件
- 无手柄/D-pad 导航支持 — 当前仅鼠标点击交互
- 无响应式缩放 — 固定尺寸，全屏/小窗口下不协调
- 缺少独立的状态模型和控制器 — 状态散落在 StatefulWidget 内

## Constraints

- **框架优先**: 本里程碑只建框架骨架（窗口绘制 + 导航系统 + 交互模式），不实现具体设置功能
- **状态管理**: 继续使用 ValueNotifier + ValueListenableBuilder，不引入新状态管理框架
- **设计语言**: 所有视觉值通过 `Tokens.*`，毛玻璃 `BackdropFilter` + `bgGlass` + `borderHighlight`
- **平台**: 以 Windows 为主，macOS/Linux 次要
- **手柄兼容**: Steam Input API 自动映射手柄→键盘，无需 Flutter 侧适配层；FocusTraversalGroup 处理 D-pad
- **覆盖层模式**: 使用居中覆盖层（非独立窗口），不可拖拽到播放器窗口外
- **延迟应用**: locale/theme/shortcuts 更改必须延迟到 OK/Apply 时提交

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持 fvp 引擎 | MDK/FFmpeg 能力足够，更换成本高 | ✓ Good (v2.1 验证) |
| ValueNotifier 不变 | 项目已有成熟模式，引入新框架增加复杂度 | ✓ Good (v2.1 验证) |
| 内核与 UI 解耦重构 | 允许独立演进，降低回归风险 | ✓ Good (v2.1 验证) |
| 兼容式替换迁移（v3.0） | 保持 UI→Kernel 契约，适配器逐步替换内核 | ✓ Done (Phase 15-22) |
| `MemoryMonitor` 一等化（v3.0） | 可注入、可关闭、不干扰播放业务 | ✓ Done (Phase 19) |
| 零依赖 `KernelLogger`（v3.0） | `dart:developer` 为主 + 受控 `debugPrint` | ✓ Done (Phase 17) |
| 双语 API 注释（v3.0） | 中文意图 + 英文契约 | ✓ Done (Phase 22) |
| 居中覆盖层（v4.0） | 复用 overlay 架构，不创建独立窗口 | — Pending |
| Kodi + Steam 混合导航（v4.0） | D-pad ↑↓ 选项, ←→ 调值, LB/RB 切 tab, A 确认, B 返回 | — Pending |
| 框架优先（v4.0） | 先建骨架后填功能，SettingRow 占位渲染 | — Pending |
| Steam Input API 自动映射（v4.0） | 手柄输入自动转键盘事件，无需 Flutter 适配层 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-24 — Phase 25 complete (Tab Content Framework: 7 skeleton tabs + deferred apply + button bar)*
