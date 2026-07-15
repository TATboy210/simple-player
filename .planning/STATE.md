---
gsd_state_version: 1.0
milestone: v2.1
milestone_name: 播放内核重构强化 (expanded — In Progress)
current_phase: 12
current_phase_name: 轨道管理统一
status: planning
stopped_at: Phase 11 verification complete (2026-07-15)
last_updated: "2026-07-15T12:00:00.000Z"
last_activity: 2026-07-15
last_activity_desc: Phase 11 verified — StateMonitor split + generation guard confirmed
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 9
  completed_plans: 8
  percent: 67
---

# Project State: 播放内核重构强化 (expanded)

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-14)

**Core value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。Widget↔Kernel 边界清晰、API 统一、可测试。
**Current focus:** Phase 14 — testability-data-flow

## Current Position

Phase: 12 — 轨道管理统一
Plan: Not started
Status: Ready to plan
Last activity: 2026-07-15 — Phase 14 complete, transitioned to Phase 12

Progress: [███████░░░] 67% (4/6 phases done, Phase 12 in progress)

## Performance Metrics

**Velocity:**

- Total plans completed: 2
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9. 接口分解 | 2/2 | — | — |
| 10. 状态机 | 2/2 | — | — |
| 11. 防御增强 | 1/1 | — | — |
| 12. 轨道统一 | 0/2 | — | — |
| 14 | 2 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v2.1]: 保持 fvp 引擎 + ValueNotifier，纯架构重构
- [v2.1]: 接口分解采用 ISP 模式（EngineStateView + PlaybackControl + 4 能力接口）
- [v2.1]: 状态机采用 switch expression 穷举 9 状态 ~40 条边
- [v2.1]: StateMonitor 拆分为 PlaybackStateManager（设置+断点+持久化）+ AutoAdvancePolicy（连播策略）
- [v2.1]: open() 使用 _openGeneration 计数器替代 _isOpening bool

### Pending Todos

None yet.

### Blockers/Concerns

- 状态机转换矩阵遗漏风险 — 9 状态 ~40 条边需要穷举验证
- mdk 回调线程安全时序窗口 — generation 计数器方案待验证
- Service 层迁移后 import 路径变更影响范围待评估

## Deferred Items

Items acknowledged and carried forward:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Future | D1: 引擎能力查询接口 | Deferred | v2.1 |
| Future | D2: 播放列表序列化解耦 | Deferred | v2.1 |
| Future | D5: NetworkConfigurator 自适应策略 | Deferred | v2.1 |
| Future | D6: EngineEventLog 结构化导出 | Deferred | v2.1 |
| Future | T4: PositionPoller 策略模式 | Deferred | v2.1 |
| Future | T6: 结构化 EngineMetrics | Deferred | v2.1 |

## Session Continuity

Last session: 2026-07-15T07:20:36.856Z
Stopped at: context exhaustion at 75% (2026-07-15)
Resume file: .planning/phases/10-state-machine-extraction/10-CONTEXT.md
