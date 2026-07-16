---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: 内核重写（兼容式替换与诊断内核）
current_phase_name: defining requirements
status: planning
stopped_at: context exhaustion at 96% (2026-07-16)
last_updated: "2026-07-16T10:38:46.028Z"
last_activity: 2026-07-16
last_activity_desc: Milestone v3.0 started
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 9
  completed_plans: 9
---

# Project State: 播放内核重构强化 (expanded)

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-14)

**Core value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。Widget↔Kernel 边界清晰、API 统一、可测试。
**Current focus:** Phase 14 — testability-data-flow

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-07-16 — Milestone v3.0 started

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

Last session: 2026-07-16T10:38:46.013Z
Stopped at: context exhaustion at 96% (2026-07-16)
Resume file: .planning/phases/10-state-machine-extraction/10-CONTEXT.md

### 2026-07-16 续会话（恢复 + logger 决策固化）

- 恢复源：`.planning/HANDOFF.json`（优先于旧 Phase 12 状态）。
- logger 策略已由 Claude 决定并固化：**零新增依赖** —— `lib/kernel` 内轻量 `KernelLogger` 门面 + `dart:developer` 为主 + 受控 `debugPrint`；HANDOFF.json task 1→2、`.continue-here.md` 阻塞项已清。
- 受保护约束：未改写 PROJECT.md / ROADMAP.md，未清理旧 phases；现有未提交源码与测试保留。
- 下一步：`/gsd-new-milestone` 确认里程碑版本与范围。

### 2026-07-16 三次恢复（v2.1 收尾已提交 + 归档待 Bash 恢复）

- 恢复源：`HANDOFF.json` + 里程碑级 `.continue-here.md`（一致，无漂移）。
- **本会话已完成**：核对 v2.1 未提交源码归属（track_preferences 真实功能代码）；跑 9 测试文件/127 测试全绿；提交 v2.1 收尾 3 原子提交 `76918ab` feat / `fd789eb` test / `94bf39b` docs；工作树仅剩 5 个 v3.0 定义文档（均 M）。
- **待 Bash 恢复后完成**（Task #3/#4，glm-5.2 间歇宕机阻塞）：`gsd-tools.cjs phases list` 确认范围 → `phases clear --confirm` 归档到 milestones（移动非删除）→ `git add -A .planning/ && git commit "docs: start milestone v3.0"` → 启动 `/gsd-roadmapper`（8 阶段 Phase 15 起，须遵守 8 项 blocking constraints）。
- **gsd-tools 语法校正**：正确 `phases clear`（子命令 list/clear），非旧记 `query phases.clear`。
- **阻塞**：Bash + Agent 子代理均被 glm-5.2 分类器宕机阻塞；read-only 与 Write/Edit 可用。
