# Roadmap: 播放内核重构强化 (v2.1)

**Created:** 2026-07-14
**Mode:** standard
**Granularity:** standard (4 phases)

## Overview

播放内核从 mixin-with-fields 模式重构为 ISP 接口分解 + 独立状态机 + 统一轨道管理。零新依赖，纯架构改进。Phase 9-12 延续上个里程碑编号。

## Milestones

<details>
<summary>✅ v2.0 沉浸式全屏重构 (Phases 1-8) - SHIPPED 2026-07-13</summary>

Previous milestone: fullscreen cleanup, WindowService simplification, immersive UI, test updates.
Phase numbering: 1-8.

</details>

### 🚧 v2.1 播放内核重构强化 (In Progress)

**Milestone Goal:** 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入

## Phases

- [ ] **Phase 9: 接口分解 + 状态模型统一** - EngineState mixin 拆分为 ISP 接口，统一错误模型，修正服务层边界
- [ ] **Phase 10: 状态机提取 + 引擎瘦身** - 独立状态机强制转换守卫，FvpEngine 从 641 行优化至 <350 行
- [ ] **Phase 11: 引擎解耦 + 防御增强** - open() 防御增强（generation 计数器），StateMonitor 职责拆分
- [ ] **Phase 12: 轨道管理统一** - 合并轨道管理接口，实现轨道偏好记忆

## Phase Details

### Phase 9: 接口分解 + 状态模型统一
**Goal**: 引擎接口按职责分解，错误体系统一，服务层位置正确
**Depends on**: Nothing (本里程碑第一阶段)
**Requirements**: ENG-01, ENG-03, SVC-01
**Success Criteria** (what must be TRUE):
  1. EngineState mixin 不再强制 12 个 ValueNotifier 字段的 @override — 实现类只实现所需接口
  2. 错误处理使用 exhaustive pattern matching — switch on PlayerError 不会有 missing case
  3. PlaybackController 从 features/player/services/ 迁移到 kernel/services/ — import 路径全部更新
  4. `flutter analyze` 无错误，现有测试全部通过
**Plans:** 2 plans

Plans:
- [ ] 09-01-PLAN.md — ISP interface creation + PlayerError sealed class + MediaState split + FakeEngine update
- [ ] 09-02-PLAN.md — Service migration to kernel/ + FvpEngine rewrite + UI consumer updates + test rewrites

### Phase 10: 状态机提取 + 引擎瘦身
**Goal**: 状态转换由独立状态机强制守卫，FvpEngine 职责精简到 <350 行
**Depends on**: Phase 9
**Requirements**: ENG-02, SVC-02
**Success Criteria** (what must be TRUE):
  1. 非法状态转换（如 Playing → Playing）在 debug 和 release 模式下均被拦截 — 不会静默执行
  2. FvpEngine 从 641 行减至 <350 行 — 状态转换守卫提取到独立类，helper 组合模式深化
  3. switch expression 穷举 9 状态 ~40 条边 — 新增状态时编译器强制处理所有边
  4. `flutter analyze` 无错误，现有测试全部通过
**Plans**: TBD

Plans:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

### Phase 11: 引擎解耦 + 防御增强
**Goal**: open() 调用安全可靠（无过期回调干扰），StateMonitor 职责清晰
**Depends on**: Phase 9
**Requirements**: ENG-04, SVC-03
**Success Criteria** (what must be TRUE):
  1. 快速切歌场景下不会出现上一个视频的回调干扰新视频 — generation 计数器隔离过期回调
  2. openGeneration + _isOpening 双守卫统一为单守卫层 — 不存在两套冲突的保护逻辑
  3. StateMonitor 拆分为 PlaybackStateManager（设置恢复 + 断点保存）和 AutoAdvancePolicy（自动连播） — 职责不混合
  4. `flutter analyze` 无错误，现有测试全部通过
**Plans**: TBD

Plans:
- [ ] 11-01: TBD
- [ ] 11-02: TBD

### Phase 12: 轨道管理统一
**Goal**: 音频/字幕/视频效果轨道由统一接口管理，用户偏好自动恢复
**Depends on**: Phase 9
**Requirements**: TRK-01, TRK-02
**Success Criteria** (what must be TRUE):
  1. TrackManager + SubtitleConfigurator + VideoEffectController 合并为统一 MediaControl 接口 — 调用方不再需要感知多个分散的管理器
  2. 用户选择的音频/字幕轨道偏好被持久化 — 下次打开文件时自动应用上次的轨道选择
  3. `flutter analyze` 无错误，现有测试全部通过
**Plans**: TBD

Plans:
- [ ] 12-01: TBD
- [ ] 12-02: TBD

## Phase Dependency Graph

```
Phase 9 (接口分解 + 状态模型统一)
  ├── Phase 10 (状态机提取 + 引擎瘦身)
  ├── Phase 11 (引擎解耦 + 防御增强)  ← 可与 Phase 10 并行
  └── Phase 12 (轨道管理统一)          ← 可与 Phase 10/11 并行
```

## Progress

**Execution Order:**
Phases execute in numeric order: 9 → 10 → 11 → 12
(Phase 10/11/12 all depend only on Phase 9, can be parallelized)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 9. 接口分解 + 状态模型统一 | v2.1 | 0/2 | Planning complete | - |
| 10. 状态机提取 + 引擎瘦身 | v2.1 | 0/2 | Not started | - |
| 11. 引擎解耦 + 防御增强 | v2.1 | 0/2 | Not started | - |
| 12. 轨道管理统一 | v2.1 | 0/2 | Not started | - |

---
*Created: 2026-07-14*
