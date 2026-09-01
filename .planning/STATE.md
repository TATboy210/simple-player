---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: 窗口外观与全屏体验
status: planning
last_updated: "2026-09-02T00:00:00.000Z"
last_activity: 2026-09-02
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-01)

**Core value:** 窗口外壳完全自绘自治——系统主题、平台差异不得渗透到窗口视觉与交互。
**Current focus:** Phase 6 — 能力探测与 C1/C2 钉死

## Current Position

Phase: 6 of 11 (能力探测与 C1/C2 钉死)
Plan: —
Status: Ready to plan
Last activity: 2026-09-02 — Milestone v1.1 roadmap created

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 20 (v1.0)
- Average duration: —
- Total execution time: — hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 6 | 0 | — | — |
| 7 | 0 | — | — |
| 8 | 0 | — | — |
| 9 | 0 | — | — |
| 10 | 0 | — | — |
| 11 | 0 | — | — |

**Recent Trend:**
- Last 5 plans: —
- Trend: Not established

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting current work:

- [Milestone]: media_kit 红线仅为全屏功能解禁（FSCR-02），其余不可改动。
- [Milestone]: Win10 红边框裁决——接受 1px 主题色边框为已知平台差异（BORD-02），不做 WS_THICKFRAME 剥离或 DWMNCRP。
- [Milestone]: 全局 DWMNCRP 方案 2026-08-27 撤回，勿重提（reverted-approaches denylist 硬约束）。
- [Milestone]: DWMWA_TRANSITIONS_FORCEDISABLED 为 spike-gated 项，实机通过 raster<33ms + 视觉无闪烁门才采纳。
- [Milestone]: Linux 结构性正确即可，标记待实机验证。

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 10 DWMWA_TRANSITIONS_FORCEDISABLED spike 须在规划期实机验证，MEDIUM 置信度。
- Phase 11 Linux 无实机，交付物标记待实机验证。
- C1 缝隙与全屏闪烁在 headless 测试中不可见——Phase 6 与 Phase 10 须以实机 UAT 验收。

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Enhancement | corner-preference 用户设置项（round/square，Win11 only） | Deferred to v2 | 2026-09-01 | v1.2 |
| Enhancement | macOS 窗口外壳验证 | Deferred | 2026-09-01 | v2 |
| Enhancement | 多显示器全屏几何恢复 | Deferred | 2026-09-01 | v2 |
| Anti-feature | Win10 伪圆角（透明分层窗口） | Rejected | 2026-09-01 | — |

## Session Continuity

Last session: 2026-09-02
Stopped at: Milestone v1.1 roadmap created — ready to plan Phase 6
Resume file: None

## Operator Next Steps

- Plan Phase 6 with `/gsd-plan-phase 6`
