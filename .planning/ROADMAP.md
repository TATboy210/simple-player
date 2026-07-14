# Roadmap: 播放内核重构强化 (v2.1 expanded)

**Created:** 2026-07-14
**Updated:** 2026-07-14 — expanded with Widget↔Kernel optimization
**Mode:** standard
**Granularity:** standard (6 phases)

## Overview

播放内核从 mixin-with-fields 模式重构为 ISP 接口分解 + 独立状态机 + 统一轨道管理。零新依赖，纯架构改进。**扩展：** 同时优化 Widget 层与内核层的对接方式，统一 API、提升可测试性、优化状态通知、清晰化数据流。Phase 9-14 延续上个里程碑编号。

## Milestones

<details>
<summary>✅ v2.0 沉浸式全屏重构 (Phases 1-8) - SHIPPED 2026-07-13</summary>

Previous milestone: fullscreen cleanup, WindowService simplification, immersive UI, test updates.
Phase numbering: 1-8.

</details>

### 🚧 v2.1 播放内核重构强化 (expanded — In Progress)

**Milestone Goal:** 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入 + Widget↔Kernel 边界清晰、API 统一、可测试

## Phases

- [x] **Phase 9: 接口分解 + 状态模型统一** ✅ DONE — EngineState mixin 拆分为 ISP 接口，统一错误模型，修正服务层边界
- [x] **Phase 10: 状态机提取 + 引擎瘦身** — 独立状态机强制转换守卫，FvpEngine 从 641 行优化至 <350 行 (completed 2026-07-14)
- [x] **Phase 11: 引擎解耦 + 防御增强** — open() generation 计数器，StateMonitor → PlaybackStateManager + AutoAdvancePolicy (completed 2026-07-14)
- [ ] **Phase 12: 轨道管理统一** — 合并轨道管理接口，实现轨道偏好记忆
- [x] **Phase 13: Widget API 统一 + 状态通知优化** — 已在 Phase 9-11 实施中自然完成 (verified 2026-07-14)
- [ ] **Phase 14: 可测试性提升 + 数据流清晰化** — Widget 测试 mock 简化，数据流单向可预测

## Phase Details

### Phase 9: 接口分解 + 状态模型统一 ✅

**Goal**: 引擎接口按职责分解，错误体系统一，服务层位置正确
**Status**: COMPLETE (2026-07-14)
**Requirements**: ENG-01 ✓, ENG-03 ✓, SVC-01 ✓

### Phase 10: 状态机提取 + 引擎瘦身

**Goal**: 状态转换由独立状态机强制守卫，FvpEngine 职责精简到 <350 行
**Depends on**: Phase 9
**Requirements**: ENG-02, SVC-02
**Plans**: 2/2 plans complete

Plans:
**Wave 1**

- [x] 10-01-PLAN.md — EngineStateMachine + PlaybackSkipMixin (TDD, Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 10-02-PLAN.md — FvpEngine 瘦身: 集成状态机 + 接口 getter + 删除 delegation (Wave 2)

**Success Criteria**:

1. 非法状态转换（如 Playing → Playing）在 debug 和 release 模式下均被拦截
2. FvpEngine 从 641 行减至 <350 行
3. switch expression 穷举 6 状态 + 2 bool 标志
4. `flutter analyze` 无错误，现有测试全部通过

### Phase 11: 引擎解耦 + 防御增强 ✅

**Goal**: open() 调用安全可靠（无过期回调干扰），StateMonitor 职责清晰
**Status**: COMPLETE (2026-07-14)
**Depends on**: Phase 9
**Requirements**: ENG-04 ✓, SVC-03 ✓
**Plans**: 1/1 plan complete

**Success Criteria**:

1. ✅ 快速切歌场景下不会出现上一个视频的回调干扰新视频
2. ✅ openGeneration 计数器替代 _isOpening bool（Phase 10 已实现）
3. ✅ StateMonitor 拆分为 PlaybackStateManager + AutoAdvancePolicy
4. ✅ `flutter analyze` 无错误，测试通过（1115 tests, 4 pre-existing failures）

### Phase 12: 轨道管理统一

**Goal**: 音频/字幕/视频效果轨道由统一接口管理，用户偏好自动恢复
**Depends on**: Phase 9
**Requirements**: TRK-01, TRK-02
**Success Criteria**:

1. TrackManager + SubtitleConfigurator + VideoEffectController 合并为统一 MediaControl 接口
2. 用户选择的音频/字幕轨道偏好被持久化
3. `flutter analyze` 无错误，现有测试全部通过

### Phase 13: Widget API 统一 + 状态通知优化 (NEW)

**Goal**: 所有 PlayerScreen 子 widget 通过统一接口访问内核，ValueNotifier 粒度与实际消费匹配
**Depends on**: Phase 10 (状态机提供清晰的状态模型)
**Requirements**: WGT-01, WGT-02, WGT-03, NOTIF-01, NOTIF-02, NOTIF-03
**Success Criteria**:

1. 所有 PlayerScreen 子 widget 构造函数接收 EngineStateView + PlaybackControl — 不直接依赖 FvpEngine
2. ControlBar/VolumeControls/SpeedButton 使用 PlaybackControl 接口调用命令
3. ValueListenableBuilder 粒度与实际消费匹配 — 不 rebuild on unrelated changes
4. 控制栏 auto-hide 逻辑不因 position 更新触发 rebuild
5. 进度条 seek preview 不触发整个 ControlBar rebuild
6. `flutter analyze` 无错误，现有测试全部通过

### Phase 14: 可测试性提升 + 数据流清晰化 (NEW)

**Goal**: Widget 测试可通过 FakeEngine 完整 mock，数据流单向可预测
**Depends on**: Phase 13
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, FLOW-01, FLOW-02, FLOW-03
**Success Criteria**:

1. Widget 测试可通过 FakeEngine + FakeWindowService 完整 mock 内核行为
2. 每个 PlayerScreen 子 widget 可独立测试
3. PlaybackController 可通过构造函数注入 mock 依赖
4. Widget→Kernel 命令流单向，Kernel→Widget 状态流单向
5. 错误传播路径清晰 — FvpEngine → PlaybackController → ErrorBanner
6. 测试覆盖率达到 80%+
7. `flutter analyze` 无错误，现有测试全部通过

## Phase Dependency Graph

```
Phase 9 ✅ (接口分解 + 状态模型统一)
  ├── Phase 10 (状态机提取 + 引擎瘦身)
  ├── Phase 11 (引擎解耦 + 防御增强)  ← 可与 Phase 10 并行
  ├── Phase 12 (轨道管理统一)          ← 可与 Phase 10/11 并行
  ├── Phase 13 (Widget API 统一 + 状态通知优化) ← 依赖 Phase 10
  └── Phase 14 (可测试性提升 + 数据流清晰化)    ← 依赖 Phase 13
```

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 9. 接口分解 + 状态模型统一 | v2.1 | 2/2 | ✅ Done | 2026-07-14 |
| 10. 状态机提取 + 引擎瘦身 | v2.1 | 2/2 | Complete   | 2026-07-14 |
| 11. 引擎解耦 + 防御增强 | v2.1 | 1/1 | ✅ Done | 2026-07-14 |
| 12. 轨道管理统一 | v2.1 | 0/TBD | Not started | - |
| 13. Widget API 统一 + 状态通知优化 | v2.1 | — | ✅ Done | 2026-07-14 |
| 14. 可测试性提升 + 数据流清晰化 | v2.1 | 0/TBD | Not started | - |

---
*Created: 2026-07-14*
*Updated: 2026-07-14 — expanded with Phase 13-14 for Widget↔Kernel optimization*
