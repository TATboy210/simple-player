---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: 内核重写（兼容式替换与诊断内核）(Phases 15-22 — In Progress)
current_phase_name: "Phase 15: 契约固化与基线盘点"
status: planning
stopped_at: roadmap approved, proceeding to /gsd-discuss-phase 15 (2026-07-16)
last_updated: "2026-07-16T12:49:28.000Z"
last_activity: 2026-07-16
last_activity_desc: v3.0 roadmap approved (8 phases 15-22); Phase 15 discussion next
progress:
  total_phases: 8
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State: 播放内核重构强化 (expanded)

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-14)

**Core value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。Widget↔Kernel 边界清晰、API 统一、可测试。
**Current focus:** Phase 14 — testability-data-flow

## Current Position

Phase: 15 of 22 (Phase 15: 契约固化与基线盘点 — ready to plan)
Plan: — (0/TBD in Phase 15)
Status: Roadmap approved — awaiting Phase 15 discussion (CONTEXT.md missing)
Last activity: 2026-07-16 — v3.0 ROADMAP.md approved (commit 5387c8a amended to docs:), Phase 15 discussion next

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

Last session: 2026-07-16T12:49:28.000Z
Stopped at: v3.0 roadmap approved; proceeding to /gsd-discuss-phase 15
Resume file: (none — Phase 15 未规划，下一步 /gsd-discuss-phase 15)

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

### 2026-07-16 第四次恢复（/gsd-resume-work 确认 → 待启动 roadmapper）

- 恢复源：`.planning/HANDOFF.json`（task 4/4 paused）+ `.planning/.continue-here.md`（8 项 blocking constraints）一致，无漂移。
- **状态核对**：工作树干净；最新 commit `6a15cd5` "wip: milestone v3.0 paused at 4/4 (definition complete, awaiting roadmapper)"（比 HANDOFF 记录的 `ec1e530` 更新，已超越移交快照）。
- **关键判断**：现有 `.planning/ROADMAP.md` 是 **v2.1 残留**（标题 "v2.1 expanded"、Phase 9-14、Jul 14），v3.0 路线图尚未生成 → STATE frontmatter `total_phases: 0` 印证。下一步确认为 `/gsd-roadmapper` 重写，而非 `/gsd-plan-phase`。
- **噪声文件**：根目录 `./.continue-here.md` 是 2026-07-10 v1.0/v1.6 全屏迁移时代遗留，与 v3.0 无关（未清理，待用户决定）。
- **下一步**：启动 `/gsd-roadmapper` 生成 8 阶段 ROADMAP.md（Phase 15 起续编号），须遵守 8 项 blocking constraints + 构建顺序 P1 契约冻结→P2 适配层→P3 KernelLogger→P4 错误模型→P5 MemoryMonitor→P6 状态重写→P7 验证收拢→P8 双语文档；回填 REQUIREMENTS.md 40 REQ-ID Traceability；呈批批准后提交。

### 2026-07-16 第五次（路线图生成 — Agent 分类器宕机，主会话直产）

- **阻塞绕行**：`/gsd-roadmapper` 无独立 skill 入口（是 agent，由 `/gsd-new-milestone` 编排）；用 Agent 工具 spawn `gsd-roadmapper` 时 glm-5.2 分类器宕机（HANDOFF 预警的间歇宕机）。read-only 与 Write/Edit 不受影响 → 在主会话直接产出 roadmapper 三件套（上下文已持 PROJECT/REQUIREMENTS/SUMMARY/.continue-here/config 全部输入）。
- **产出**：(1) `ROADMAP.md` 覆盖 v2.1 残留，8 phases（Phase 15-22 续编号），每 phase 含 Goal/Depends on/Requirements/Success Criteria/**Blocking Constraints honored**/Plans TBD + Progress Table + Build Order Rationale；(2) `STATE.md` 外科手术更新（frontmatter total_phases 0→8、current_phase_name→Phase 15、Current Position→15 of 22 ready to plan），历史 Session Continuity 全保留；(3) `REQUIREMENTS.md` Traceability 回填 40 行映射表，Coverage 40/40 归零。
- **关键决策固化为各 phase 硬要求**：8 项 blocking constraints 已分别写入对应 phase（#2→P15, #6+#8→P16, #1+#7→P17, #5→P19, #3+#4→P20, #7 release→P21）。构建顺序严格遵守 P15→P16→P17→P18→P19→P20→P21→P22，Depends on 体现依赖链。
- **granularity 张力**：config.json `standard`（默认 4-6 phases），但 8 phases 是需求驱动自然边界，ROADMAP.md Overview 已注明未压缩（压缩会破坏诊断能力依赖链）。
- **未提交**：三件套待用户呈批批准后提交（建议 commit message: `docs: roadmap v3.0 — 8 phases (15-22) compatible-replacement kernel rewrite`）。未删除 HANDOFF.json（待路线图批准提交后作为一次性工件闭环删除）。
- **下一步（上下文 71% 已紧）**：呈批 → 批准后提交 + 删 HANDOFF.json → `/clear` → `/gsd-plan-phase 15`（Phase 15 规划，新上下文窗口）。

### 2026-07-16 第六次恢复（/gsd-resume-work → 批准路线图 + 收尾提交 → 待 Phase 15 讨论）

- **恢复源**：`.planning/HANDOFF.json`（task 4/4 paused）+ `.planning/.continue-here.md`（8 项 blocking constraints）。无中断 agent、无 async-jobs、无"PLAN 无 SUMMARY"未完成执行（旧 v2.1 phases 09-14 已归档到 `.planning/milestones/v3.0-phases/`）。
- **状态分歧已核并修复**：HANDOFF.json + .continue-here.md 写于提交前（12:26:12Z），均称"三件套写盘未提交"；但 git 显示已在 `5387c8a` 一起提交（`wip: ... paused — awaiting approval`），工作树干净，`git diff HEAD` 为空。即 handoff 已陈旧（一次性快照非实时镜像），提交步骤实际已完成，唯余"用户批准"门未过。
- **用户决策**：经 `/gsd-resume-work` 呈批，用户**批准** v3.0 路线图（8 phases Phase 15-22），并选择**先讨论 Phase 15**（Phase 15 无 CONTEXT.md，先 `/gsd-discuss-phase 15` 梳理上下文再规划）。
- **收尾提交（amend 5387c8a）**：因 5387c8a 未 push（`@{u}..HEAD` 含之，分支 ahead 379），amend 安全。操作：(1) `git rm .planning/HANDOFF.json` 删一次性工件；(2) 更新本 STATE.md 会话连续性；(3) `git commit --amend -m "docs: roadmap v3.0 — 8 phases (15-22) compatible-replacement kernel rewrite"`，把 wip commit message 修正为 docs: 并纳入 HANDOFF.json 删除 + STATE.md 更新，单 commit 收尾。
- **保留未动**：`.planning/.continue-here.md`（v3.0 的 8 项 blocking constraints 集中参考，Phase 15+ 仍须复核）+ 根目录 `./.continue-here.md`（v1.0/v1.6 全屏迁移时代遗留噪声，待用户决定是否清理）均未删——用户仅授权删 HANDOFF.json。
- **下一步**：`/clear` → `/gsd-discuss-phase 15`（新上下文窗口，读 Phase 15 RESEARCH/CONTEXT）。
