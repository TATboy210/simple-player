# Simple Player — 播放内核重写（兼容式替换与诊断内核）

## What This Is

Simple Player Flutter 桌面播放器（fvp / MDK-FFmpeg 引擎）的内核重写。在保留既有 UI 与播放功能的前提下，以**兼容式替换**重写内核：清晰引擎抽象、状态生命周期一致、统一错误模型与日志、内存诊断一等化，为后续功能（ABR、多实例、插件化）打基础。**v3.0 聚焦内核重写与诊断能力一等化，UI→Kernel 调用契约保持不变，通过适配层逐步迁移以降低回归风险。**

## Core Value

播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入，且**诊断能力（MemoryMonitor、统一日志）为内核一等公民**。Widget↔Kernel 边界清晰、API 统一、可测试。

## Current Milestone: v3.0 内核重写（兼容式替换与诊断内核）

**Goal:** 以兼容式替换重写播放内核，`MemoryMonitor` + 零依赖 `KernelLogger` 一等化，保持 UI→Kernel 契约不变，逐步迁移降低回归风险。

**Target features:**

1. **内核基线学习与契约固化** — 基于现有内核（含 v2.1 产出）梳理真实调用面、状态面与错误面，固化为迁移基线契约
2. **兼容适配层** — UI 调用契约保持不变，通过适配器在旧内核之上/之外逐步替换内核实现，双轨并存
3. **状态与生命周期重写** — 清晰引擎抽象（`MediaEngine`/`FvpEngine`）、状态机穷举、生命周期与 `openGeneration` 守卫
4. **错误模型与统一 `KernelLogger`** — 稳定错误码、结构化上下文、分级日志；零新增依赖（`dart:developer` 为主 + 受控 `debugPrint`）
5. **`MemoryMonitor` 一等化** — 可注入、可关闭、不干扰播放业务状态的诊断组件
6. **测试与迁移验证** — 双轨并存期的回归防护、契约测试、迁移每步可验证
7. **双语 API 文档注释标准** — 新增/重构的公开 API 同时含中文意图说明与英文契约说明

## Requirements

### Validated

- ✓ 播放核心功能（播放/暂停/seek/音量/播放模式）— 现有
- ✓ fvp (MDK/FFmpeg) 播放引擎集成 — 现有
- ✓ ValueNotifier + ValueListenableBuilder 状态管理 — 现有
- ✓ 键盘快捷键系统（20+ 快捷键）— 现有
- ✓ 毛玻璃设计语言（GlassContainer、Tokens.*）— 现有
- ✓ 沉浸式全屏功能 — v2.0 已完成
- ✓ 引擎接口分解（ISP：EngineStateView + PlaybackControl + 能力接口）— v2.1 (09)
- ✓ 状态机穷举（9 状态 ~40 边）— v2.1 (10)
- ✓ `StateMonitor` 拆分为 `PlaybackStateManager` + `AutoAdvancePolicy` — v2.1
- ✓ `openGeneration` 守卫替代 `_isOpening` bool — v2.1
- ✓ `MemoryMonitor` / `EngineMetrics` / `EngineEventLog` 初版 — v2.1 (11/14)

### Active

<!-- v3.0 scope — 内核重写与诊断一等化。Building toward these. -->

- [ ] 内核基线学习与契约固化（梳理 UI→Kernel 调用面/状态面/错误面，固化为迁移基线）
- [ ] 兼容适配层（UI 契约不变，适配器逐步替换内核，双轨并存）
- [ ] 状态与生命周期重写（引擎抽象 + 状态机 + 生命周期 + generation 守卫）
- [ ] 错误模型与统一 `KernelLogger`（稳定错误码 + 结构化上下文 + 分级日志，零依赖）
- [ ] `MemoryMonitor` 一等化（可注入、可关闭、不干扰播放业务）
- [ ] 测试与迁移验证（双轨期回归防护 + 契约测试 + 每步可验证）
- [ ] 双语 API 文档注释标准（公开 API 中文意图 + 英文契约）

### Out of Scope

- 底层引擎更换 — 继续使用 fvp (MDK/FFmpeg)
- UI 层改动 — 本次专注内核，不改播放器界面
- 状态管理模式更换 — 继续使用 ValueNotifier + ValueListenableBuilder
- 新增播放功能 — 本次只重写现有功能的内核实现
- 引入 `logger` package — 采用零新增依赖的 `KernelLogger` 门面（`dart:developer` + 受控 `debugPrint`），保持内核最小依赖边界
- 一次性全量替换内核 — 采用兼容式逐步迁移，避免播放行为一次性回归

## Context

**技术环境：**

- Flutter 桌面播放器，Windows 为主平台
- fvp (MDK/FFmpeg) 作为播放引擎
- ValueNotifier + ValueListenableBuilder 状态管理
- 毛玻璃设计语言（GlassContainer + Tokens.*）

**当前内核结构（v2.1 产出，作为 v3.0 重写的基线与学习对象）：**

- `lib/kernel/engine/media_engine.dart` — 抽象引擎接口
- `lib/kernel/engine/fvp_engine.dart` — fvp 具体实现
- `lib/kernel/engine/position_poller.dart` — Timer-based 位置更新
- `lib/kernel/engine/track_manager.dart` — 音频/字幕轨道管理
- `lib/kernel/services/playback_controller.dart` — 播放编排器
- `lib/kernel/services/playback_navigator.dart` — 曲目推进逻辑
- `lib/kernel/services/playback_state_manager.dart` — 设置/断点/持久化（v2.1 拆分）
- `lib/kernel/services/auto_advance_policy.dart` — 连播策略（v2.1 拆分）
- `lib/kernel/playlist/playlist.dart` — 播放列表模型
- `lib/kernel/models/media_state.dart` — 播放状态枚举
- `lib/kernel/models/track_preferences.dart` — 轨道偏好（v2.1 新增，未提交）
- `lib/kernel/services/track_preference_service.dart` — 轨道偏好服务（v2.1 新增，未提交）
- `lib/kernel/utils/memory_monitor.dart` — 内存监控（v2.1，待一等化重构）

**已知问题（v3.0 要解决）：**

- 引擎抽象层职责不够清晰，状态管理分散
- PlaybackController 过于庞大，职责混合
- 错误恢复机制不完善，边界情况处理差；缺乏稳定错误码与结构化日志
- 诊断能力（MemoryMonitor、日志）非内核一等公民，难以注入/关闭/统一
- 状态变更通知缺乏一致性保证
- 为后续功能扩展（ABR、多实例等）缺乏架构准备

## Constraints

- **引擎绑定**: 继续使用 fvp (MDK/FFmpeg)，不更换底层
- **状态管理**: 继续使用 ValueNotifier + ValueListenableBuilder，不引入新状态管理框架
- **UI 不动**: 本次重构不涉及播放器界面改动
- **平台**: 以 Windows 为主，macOS/Linux 次要
- **依赖边界**: 内核不新增第三方运行时依赖（不引入 `logger` package），日志走零依赖 `KernelLogger` 门面
- **迁移策略**: 兼容式替换，保持 UI→Kernel 契约，通过适配层逐步替换，禁止一次性全量替换
- **文档标准**: 新增/重构的公开 API 必须同时提供中文意图说明与英文契约说明

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持 fvp 引擎 | MDK/FFmpeg 能力足够，更换成本高 | ✓ Good (v2.1 验证) |
| ValueNotifier 不变 | 项目已有成熟模式，引入新框架增加复杂度 | ✓ Good (v2.1 验证) |
| 内核与 UI 解耦重构 | 允许独立演进，降低回归风险 | ✓ Good (v2.1 验证) |
| 为 ABR/多实例做架构准备 | 不实现但确保接口可扩展 | — Pending |
| 兼容式替换迁移（v3.0） | 保持 UI→Kernel 契约，适配器逐步替换内核，降低播放功能一次性回归风险 | — Pending |
| `MemoryMonitor` 一等化（v3.0） | 设计为可注入、可关闭且不干扰播放业务状态的诊断组件 | — Pending |
| 零依赖 `KernelLogger`（v3.0） | `lib/kernel` 轻量门面 + `dart:developer` 为主 + 受控 `debugPrint`，保持内核最小依赖边界；未来落盘/远程上报可在门面内替换 | — Pending |
| 双语 API 注释（v3.0） | 新增/重构公开 API 同时含中文意图与英文契约，提升长期维护与跨语言协作可读性 | — Pending |

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
*Last updated: 2026-07-16 after v3.0 milestone start (内核重写：兼容式替换与诊断内核)*
