---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: 内核重写（兼容式替换与诊断内核）(Phases 15-22 — In Progress)
current_phase: 16
current_phase_name: 兼容适配层骨架 + DiagnosticsBundle
status: planned
stopped_at: Phase 16 planning complete + dirty-tree isolated (bf12821 Phase15 residue + b28c37f playback_status_overlay debug, 2026-07-18), awaiting execute-phase 16 in fresh window
last_updated: "2026-07-18T01:59:00.000Z"
last_activity: 2026-07-18
last_activity_desc: Phase 16 planning complete (5 PLANs, checker PASS, coverage gates PASS) + Step 15 dirty-tree isolated to 2 commits (bf12821 + b28c37f), working tree clean
progress:
  total_phases: 8
  completed_phases: 0
  total_plans: 4
  completed_plans: 3
  percent: 0
---

# Project State: 播放内核重构强化 (expanded)

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-14)

**Core value:** 播放内核的健壮性与可扩展性 — 引擎抽象清晰、状态一致、错误恢复可靠、新功能易于接入。Widget↔Kernel 边界清晰、API 统一、可测试。
**Current focus:** Phase 16 — 兼容适配层骨架 + DiagnosticsBundle (planning complete, awaiting execution)

## Current Position

Phase: 16 — 兼容适配层骨架 + DiagnosticsBundle
Plan: 5 PLANs created (16-01..05), checker PASS, coverage gates PASS
Status: Planning complete + dirty-tree isolated — awaiting execute-phase 16 in fresh window
Last activity: 2026-07-18 — Phase 16 planning complete (5 PLANs, checker PASS, ADAPT-01..05 + D1-D27 coverage PASS) + Step 15 dirty-tree isolated (bf12821 Phase15 residue + b28c37f playback_status_overlay debug), working tree clean

## Performance Metrics

**Velocity:**

- Total plans completed: 5
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
| 15 | 3 | - | - |

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

Last session: 2026-07-17T16:34:55.316Z
Stopped at: context exhaustion at 80% (2026-07-17)
Resume file: .planning/phases/16-diagnosticsbundle/16-CONTEXT.md

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

### 2026-07-17 Phase 16 planning 暂停（上下文预算 72%，checkpoint 已落盘）

- **恢复源**：`.planning/phases/16-diagnosticsbundle/16-PLAN-CHECKPOINT.json`（本次新建，plan-phase 桥接工件，非 GSD 自动消费；安全删除时机 = PLAN.md 提交后）。
- **已完成的规划前置**：(1) `gsd-tools.cjs` 定位 `/c/Users/35490/.claude/gsd-core/bin/gsd-tools.cjs`；(2) `init.plan-phase 16` 全字段已解析（phase_found=true, phase_req_ids=ADAPT-01..05, has_context=true, has_research=false, has_plans=false, phase_status=Pending, planner=opus/checker=sonnet/researcher=sonnet, auto_advance=true, context_window=200000）；(3) `phase.mvp-mode 16` = false（标准水平分层）；(4) plan:pre hooks 已渲染并逐能力判定：research=ACTIVE、pattern-mapper=ACTIVE(Step 7.8)、security=ACTIVE(须 `<threat_model>`)、intel=ACTIVE(Step 7.9)、ai-integration=SKIP(无 AI 关键词)、ui=SKIP(纯内核 seam 无 frontend)；(5) research hook 的 `fragment.inline` 提示模板 + 9 个字段替换值已固化进 checkpoint；(6) Step 5.1 用户选 "Research first (Recommended)"。
- **未完成（下个窗口做）**：未 spawn 任何子代理。下个窗口 `/clear` → `/gsd-plan-phase 16 --research`：跳过 Step 5.1 交互门 → spawn gsd-phase-researcher(sonnet, 写 RESEARCH.md，含 D6 调用点普查 + Validation Architecture 喂 Nyquist D8) → Step 5.5 派生 VALIDATION.md → Step 5.55 security 门禁 → Step 7.8 pattern-mapper → Step 7.9 intel API-SURFACE → Step 8 planner(opus, 写 *-PLAN.md，须含 `<threat_model>` + D27 wc 预算明细 + D24/D25 测试构成 + D21 类级迁移清单三项 + D22 grep 闸门) → Step 10 checker(sonnet) → Step 12 修订循环(max 3) → Step 13 需求覆盖门(ADAPT-01..05) + 13a 决策覆盖门(D1-D27) + 13b STATE + 13c ROADMAP 注释 + 13d 提交 → Step 13e gap 分析 → Step 15 auto_advance=true 链到 execute-phase 16。
- **auto_advance 警告**：规划通过后工作流会自动 spawn execute-phase 16（STATE 第七次恢复已确认 auto_advance 是用户有意开启）。但当前工作树有 12 个脏文件（lib/kernel/engine/media_opener.dart、lib/main.dart、lib/ui/player/*、lib/l10n/*、未追踪 playback_status_overlay.dart + 测试 + .planning/debug/）是上一会话 playback_status_overlay debug 残留，**与 Phase 16 无关**。execute-phase 会新建 lib/kernel/adapter + lib/kernel/diagnostics 触碰 lib/kernel/。建议在 auto-advance 触发前先提交/暂存这些无关脏改动，或在新窗口首步先处理。P16 规划本身只写 .planning/ 不碰 lib/，规划阶段安全。
- **open research questions 已固化**：checkpoint `open_research_questions_for_researcher` 列 7 条（D6 调用点普查、Nyquist D8 验证架构、FvpEngine 636 行基线核实、MediaEngine 7 接口成员枚举、EngineStateView notifier 字段枚举、现有 3 诊断组件形状、cast audit 复核）。
- **下一步**：`/clear` → `/gsd-plan-phase 16 --research`（带 --research flag 跳过已答的研究交互门，直接 spawn researcher）。

### 2026-07-16 第七次（/gsd-discuss-phase 15 起步 — git 收尾提交执行 + 上下文加载 + checkpoint）

- **恢复源**：第六次恢复记录 + `.planning/.continue-here.md`（8 项 blocking constraints）。git 现状核对发现：上一会话计划的 v3.0 路线图收尾提交**从未执行**——HEAD 仍是 `5387c8a wip: ...paused`，HANDOFF.json 仍在，STATE.md 含未提交的"第六次恢复"记录。
- **用户决策（AskUserQuestion）**：选择 **amend 5387c8a**（推荐项）处理悬挂的收尾提交。
- **git 收尾提交已执行**：`git rm .planning/HANDOFF.json` + `git add .planning/STATE.md` + `git commit --amend -m "docs: roadmap v3.0 — 8 phases (15-22) compatible-replacement kernel rewrite"`。新 HEAD = **`3ecf382`**（docs:，5 files changed，含 HANDOFF.json delete mode）。工作树干净。分支 ahead 379 未 push（amend 安全可逆，reflog 可回退）。HANDOFF.json 已从磁盘删除闭环。
- **discuss-phase 15 起步完成**：`init.phase-op 15`（phase_found=true, phase_name="契约固化与基线盘点", has_context=false）；无 phase 级 `.continue-here.md`，里程碑级 5 个 blocking 反模式已核查——Phase 15 直接相关仅"一次性 big-bang 替换内核"，三问已答（契约测试即其结构闸门）；其余 4 个由各自归属阶段拥有。无 SPEC.md（spec_loaded=false）。无既有 context/checkpoint/plans（全新阶段）。无 todo 匹配。discuss:pre hooks 空。
- **先验上下文已加载**：PROJECT.md（v3.0 milestones + 陈旧"9 态~40 边"待修正）、REQUIREMENTS.md（BASE-01..04 + Traceability 40/40）、ROADMAP.md Phase 15 detail（goal/success criteria/blocking constraint #2）、.continue-here.md（8 constraints）、v2.1 归档 09-CONTEXT（接口分解 D-01..D-19）/10-CONTEXT（状态机 D-01..D-12）、codebase maps ARCHITECTURE/CONCERNS/TESTING（**关键发现：maps 是 2026-07-12 v2.1 重构前陈旧快照，Phase 15 基线盘点必须对 LIVE code 做**）。
- **承袭 v2.1 已锁决策（不再问）**：6 态正交 MediaState + isSeeking/isBuffering（9 态已废）、ISP 接口分解（EngineStateView+PlaybackControl+4 能力接口）、PlayerError sealed、EngineStateMachine.transitionTo→bool（静默忽略即 #4 反模式 Phase 20 修）、FvpEngine <350 行、双语注释结构。
- **灰色区选择（AskUserQuestion multiSelect）**：用户选**全部 4 区**——①契约文档落点（BASE-01：接口 /// 双语文档 vs 独立 CONTRACT.md）②9v6 裁决+生命周期态（BASE-03+#2：6 态已锁但 PROJECT.md 仍写 9 态陈旧；disposed/disposing/error-恢复 态加枚举还是独立标志；只列还是连转换语义冻结）③契约测试策略（BASE-04：复用 FakeEngine vs 新 harness；按方法 vs 按接口；是否参数化供 Phase 21 对 NewFvpEngine 复用）④盘点工件+陈旧 maps（BASE-02：121 logger/MemoryMonitor 2 处/openGeneration 盘点产物形态；maps 刷新还是标注）。
- **上下文耗尽收尾（75% 警告）**：discuss-phase 是交互式多轮工作流，剩余 25% 不足跑完 4 区讨论 + 写 CONTEXT.md/DISCUSSION-LOG.md + 提交。改为**创建 phase 15 目录 + 写 checkpoint** 收尾——`mkdir .planning/phases/15-contract-freeze-baseline-audit`，写 `15-DISCUSS-CHECKPOINT.json`（含全部已加载先验上下文 + 4 已选灰色区 + 承袭决策 + codebase 上下文 + canonical refs seed + blocking 反模式三答 + git 状态）。
- **未提交**：phase-15 目录 + checkpoint + STATE.md 本次更新。建议提交 message：`docs(15): discuss-phase checkpoint — git 收尾完成, 4 灰色区已选`（或下次 `/gsd-discuss-phase 15` Resume 后由其 git_commit 步骤连同 CONTEXT.md 一起提交）。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-discuss-phase 15`。`check_existing` 会检测 `15-DISCUSS-CHECKPOINT.json` 并提供 Resume → 从 `areas_pending[0]=契约文档落点` 开始默认模式讨论（每区 4 单问题轮次 → Next area 检查）→ 4 区全完成写 CONTEXT.md + DISCUSSION-LOG.md → git_commit（会 `rm` checkpoint）→ update_state → 可选 `/gsd-plan-phase 15`（auto_advance 已开）。

### 2026-07-17 第八次恢复（/gsd-resume-work → 确认直接规划 Phase 16）

- **恢复源**：`.planning/phases/16-diagnosticsbundle/16-PLAN-CHECKPOINT.json`（plan-phase 桥接工件，Step 5 暂停）。`.planning/HANDOFF.json` 已陈旧（2026-07-16 Phase 15 plan-phase 产物，被 `dc93d20` 执行超越），不予采信。
- **状态核对**：Phase 15 已完整闭环（3 PLAN+SUMMARY+VERIFICATION.md+BASELINE-AUDIT，commit `dc93d20` PASSED 4/4）；Phase 16 规划 Step 5 暂停（gsd-phase-researcher 未 spawn）。git HEAD = `6b9c381`。工作树 12 个 lib/ debug 残留 + 3 个 Phase 15 零星残留，均与 Phase 16 无关。
- **用户决策**：经 AskUserQuestion，选择**直接规划 Phase 16**（推荐项）——规划阶段只写 `.planning/`，对 lib/ 脏文件免疫；lib/ 残留留到规划通过后、auto-advance→execute 触发前再处理。
- **下一步**：`/gsd-plan-phase 16 --research`（`--research` flag 跳过已答的 Step 5.1 交互门，直接 spawn gsd-phase-researcher）。

### 2026-07-17 第九次（/gsd-plan-phase 16 --research — 只跑研究，落盘后检查点停）

- **恢复源**：`16-PLAN-CHECKPOINT.json`（第八次恢复已核对，本次直接消费）+ 第八次 STATE 记录。git HEAD = `6b9c381`，工作树 12 个 lib/ debug 残留（与 P16 无关）。
- **上下文预算现实**：本窗口启动时已 66%（剩 34%），不足以跑完 Research→Plan→Verify→Step13 门禁→auto-advance→execute-phase 全链。经 AskUserQuestion，用户选 **"只跑研究，落盘后检查点停 (推荐)"** —— 单窗口产出一个持久工件（RESEARCH.md），下一窗口复用继续。
- **本窗口已完成**：
  1. **Step 5 — spawn gsd-phase-researcher (sonnet)**：用 checkpoint 固化的 `fragment.inline` 模板 + 9 字段替换 + 7 条 open research questions 注入。researcher 写 `16-RESEARCH.md`（含 `## Validation Architecture` 段）并以**隔离提交** `e99ead2` 落盘（仅 RESEARCH.md，未碰 12 个无关脏文件）。返回 `## RESEARCH COMPLETE`，confidence HIGH，111K subagent tokens。
  2. **Step 5.5 — 派生 16-VALIDATION.md**：从 RESEARCH 的 `## Validation Architecture`（481-515 行）派生 Nyquist Dimension 8 种子，填 frontmatter（phase=16, slug=diagnosticsbundle, status=draft, nyquist_compliant=false, created=2026-07-17）+ Flutter 适配 body（Test Infrastructure / Phase Requirements→Test Map ADAPT-01..05 / Wave 0 / Manual-Only / Security Domain）。GateGuard 事实闸已过。提交 `0eae691`（仅 VALIDATION.md，隔离）。
- **researcher 关键发现（喂给下窗口 planner）**：
  - **D6 解决 + stale figure 纠正**：活码 log 调用点实为 **84**（非 ROADMAP/REQUIREMENTS 写的 121）—— 48 `.e` / 7 `.w` / 12 `.i` / 17 `.d` / 0 `.t` / 0 `.f`，二次确认（Phase 15 baseline JSON + 本会话独立 grep）。planner 须用 84。
  - `.e()` 仅 3 处用命名参，两种 shape（`error:`+`stackTrace:` 或仅 `stackTrace:`）→ `KernelLogger.error()` 须接受 `{Object? error, StackTrace? stackTrace}` 均可选命名参；`fatal()` 零活点，签名按对称性 `[ASSUMED]` 外推。
  - **ADAPT-05 基线精确**：`wc -l lib/kernel/engine/fvp_engine.dart` = **636**（非估计）。
  - **7 接口 MediaEngine 面枚举完成**：EngineStateView 15 / PlaybackControl 12 / TrackControl 3 / SubtitleConfig 8 / VideoEffectControl 4 / RendererControl 2 / VolumeControl 4 成员；**发现未文档化重叠**：`PlaybackControl.setVolume/setMute` + `EngineStateView.volume/isMuted` 与 `VolumeControl` 成员签名同型 → 一个 Dart override 满足多接口。记为 Pitfall 2 / Open Question 1，推荐经 `VolumeControl` 的 policy 字段单路由（planner 须显式决策 + 代码注释）。
  - **契约测试复用机制已存在且可用**：Phase 15 的 7 个 `run*ContractTests` + `contract_test_runner.dart` 聚合器专为对 `KernelAdapter` 重挂而设计（换 factory 即可），挂点 `test/engine/fvp_engine_contract_test.dart` 已确认。
  - **cast audit 再确认**：`as FvpEngine` 0 hits + 5 个便捷 getter（trackControl/videoEffectControl/rendererControl/volumeControl/subtitleConfig）0 用量 —— drop-in 透明性证据齐。
  - **Open Questions（喂 planner）**：(1) setVolume/setMute/volume/isMuted 经 `DelegationPolicy.volume` 单路由 vs 模糊双字段治理（推荐单路由）；(2) `migrated:` 与 `legacy:` 是否同一 FvpEngine 实例（推荐同实例，避免资源重复问题，D19 允许二者）。
- **git 状态**：HEAD `0eae691`，其上 `e99ead2`（research）。两个 P16 提交均隔离（仅 .planning/）。12 个 lib/ debug 残留 + Phase 15 零星残留 + STATE.md(M) 仍未动 —— auto-advance→execute 触发前须处理（见下）。
- **未提交**：本 STATE.md 更新（下一步将随 checkpoint 一起提交）。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-plan-phase 16`（**不带 --research**，因 has_research=true 会自动复用 RESEARCH.md，走 Step 5.1 "Use existing, skip to step 6"）。续跑：Step 5.55 security threat-model 门禁（planner 须发 `<threat_model>`，低风险）→ Step 7.8 spawn gsd-pattern-mapper（写 PATTERNS.md）→ Step 7.9 regenerate API-SURFACE.md → Step 8 spawn gsd-planner opus（写 *-PLAN.md，须含 D27 wc 预算明细 / D24 测试构成 / D21 类级迁移清单 / D22 grep 闸门 / D6 84-调用点签名 / VolumeControl 单路由决策）→ Step 10 checker(sonnet) → Step 12 修订循环(max 3) → Step 13 需求覆盖门(ADAPT-01..05) + 13a 决策覆盖门(D1-D27) + 13b STATE + 13c ROADMAP 注释 + 13d 提交 → 13e gap 分析 → Step 15 auto_advance=true 链 execute-phase 16。
- **auto-advance 警告（重申）**：规划通过后工作流自动 spawn execute-phase 16（会动 lib/kernel/adapter + lib/kernel/diagnostics 新目录）。触发前务必先提交/暂存 12 个无关 lib/ debug 脏文件，否则 execute 阶段工作树混乱。P16 规划本身只写 .planning/，安全。
