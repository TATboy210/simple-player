---
gsd_state_version: 1.0
milestone: v1.9
milestone_name: 控制栏进度条修复与精简
current_phase: 39
current_phase_name: 进度条三症状根因诊断与修复
status: executing
stopped_at: Wave 2 (plan 39-02) ready to dispatch — context exhaustion at 77% before spawn; re-run /gsd-execute-phase 39 to resume
last_updated: "2026-08-22T15:56:30.183Z"
last_activity: 2026-08-22
last_activity_desc: Phase 39 execution resumed (wave continue)
state_head: a6bd92b4a495d94918a1dadb351a1eb5338f2a66
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State: 播放器 Widget 稳定性与 PC Resize 流畅度

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-11)

**Core value:** 保持播放器主要功能、视觉状态和交互契约不变，同时降低 PC 窗口频繁变换时的 widget rebuild、布局和渲染卡顿。
**Current focus:** Phase 39 — 进度条三症状根因诊断与修复

## Current Position

Phase: 39 (进度条三症状根因诊断与修复) — EXECUTING
Plan: 1 of 2
Status: Executing Phase 39
Last activity: 2026-08-22 — Phase 39 execution resumed (wave continue)

## Performance Metrics

**Velocity:**

- Total plans completed: 25
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
| 16 | 5 | - | - |
| 17 | 3 | - | - |
| 18 | 3 | - | - |
| 19 | 2 | - | - |
| 22 | 1 | - | - |
| 23 | 2 | - | - |
| 24 | 2 | - | - |
| 25 | 2 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 16-diagnosticsbundle P04 | 45min | 4 tasks | 4 files |
| Phase 31 P02 | 34 min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v2.1]: 保持 fvp 引擎 + ValueNotifier，纯架构重构
- [v2.1]: 接口分解采用 ISP 模式（EngineStateView + PlaybackControl + 4 能力接口）
- [v2.1]: 状态机采用 switch expression 穷举 9 状态 ~40 条边
- [v2.1]: StateMonitor 拆分为 PlaybackStateManager（设置+断点+持久化）+ AutoAdvancePolicy（连播策略）
- [v2.1]: open() 使用 _openGeneration 计数器替代 _isOpening bool
- [Phase ?]: No adapter-layer openGeneration test created; texture-channel mock copied verbatim; native DLLs copied for local test env per Phase 15 precedent
- [Phase ?]: FocusableSettingRow remains the sole keyboard focus owner; embedded InkWell is pointer-only.
- [Phase ?]: focusedBuilder delivers focus state to active values without Focus.of polling.

### Pending Todos

- Phase 35：完成基于本地 Git widget tree 的行为基线与高风险回归测试。
- 检查未追踪截图用途；未经确认不删除、不提交。
- 保持当前未提交源码增量，不执行整体 reset 或历史 tree 覆盖。

### Blockers/Concerns

- 当前工作树包含播放器 widget、测试和 `.planning` 未提交改动，后续历史应用必须文件/方法级。
- `GlassButton` action cache 是否会持有旧 callback，需要 Phase 35 定点验证。
- `PlayerVideoControls.updateSources()`、reparent 和 subtitle padding 生命周期需要继续验证。
- Windows profile 才能最终确认 BackdropFilter、texture resize 和窗口模式过渡的 raster 峰值。

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

Last session: 2026-08-22T15:56:30.164Z
Stopped at: Wave 2 (plan 39-02) ready to dispatch — context exhaustion at 77% before spawn; re-run /gsd-execute-phase 39 to resume
Resume file: None

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
- **关键判断**：现有 `.planning/ROADMAP.md` 是 **v2.1 拋留**（标题 "v2.1 expanded"、Phase 9-14、Jul 14），v3.0 路线图尚未生成 → STATE frontmatter `total_phases: 0` 印证。下一步确认为 `/gsd-roadmapper` 重写，而非 `/gsd-plan-phase`。
- **噪声文件**：根目录 `./.continue-here.md` 是 2026-07-10 v1.0/v1.6 全屏迁移时代遗留，与 v3.0 无关（未清理，待用户决定）。
- **下一步**：启动 `/gsd-roadmapper` 生成 8 阶段 ROADMAP.md（Phase 15 起续编号），须遵守 8 项 blocking constraints + 构建顺序 P1 契约冻结→P2 适配层→P3 KernelLogger→P4 错误模型→P5 MemoryMonitor→P6 状态重写→P7 验证收拢→P8 双语文档；回填 REQUIREMENTS.md 40 REQ-ID Traceability；呈批批准后提交。

### 2026-07-16 第五次（路线图生成 — Agent 分类器宕机，主会话直产）

- **阻塞绕行**：`/gsd-roadmapper` 无独立 skill 入口（是 agent，由 `/gsd-new-milestone` 编排）；用 Agent 工具 spawn `gsd-roadmapper` 时 glm-5.2 分类器宕机（HANDOFF 预警的间歇宕机）。read-only 与 Write/Edit 不受影响 → 在主会话直接产出 roadmapper 三件套（上下文已持 PROJECT/REQUIREMENTS/SUMMARY/.continue-here/config 全部输入）。
- **产出**：(1) `ROADMAP.md` 覆盖 v2.1 拋留，8 phases（Phase 15-22 续编号），每 phase 含 Goal/Depends on/Requirements/Success Criteria/**Blocking Constraints honored**/Plans TBD + Progress Table + Build Order Rationale；(2) `STATE.md` 外科手术更新（frontmatter total_phases 0→8、current_phase_name→Phase 15、Current Position→15 of 22 ready to plan），历史 Session Continuity 全保留；(3) `REQUIREMENTS.md` Traceability 回填 40 行映射表，Coverage 40/40 归零。
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
- **auto_advance 警告**：规划通过后工作流会自动 spawn execute-phase 16（STATE 第七次恢复已确认 auto_advance 是用户有意开启）。但当前工作树有 12 个脏文件（lib/kernel/engine/media_opener.dart、lib/main.dart、lib/ui/player/*、lib/l10n/*、未追踪 playback_status_overlay.dart + 测试 + .planning/debug/）是上一会话 playback_status_overlay debug 拋留，**与 Phase 16 无关**。execute-phase 会新建 lib/kernel/adapter + lib/kernel/diagnostics 触碰 lib/kernel/。建议在 auto-advance 触发前先提交/暂存这些无关脏改动，或在新窗口首步先处理。P16 规划本身只写 .planning/ 不碰 lib/，规划阶段安全。
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
- **状态核对**：Phase 15 已完整闭环（3 PLAN+SUMMARY+VERIFICATION.md+BASELINE-AUDIT，commit `dc93d20` PASSED 4/4）；Phase 16 规划 Step 5 暂停（gsd-phase-researcher 未 spawn）。git HEAD = `6b9c381`。工作树 12 个 lib/ debug 拋留 + 3 个 Phase 15 零星残留，均与 Phase 16 无关。
- **用户决策**：经 AskUserQuestion，选择**直接规划 Phase 16**（推荐项）——规划阶段只写 `.planning/`，对 lib/ 脏文件免疫；lib/ 拋留留到规划通过后、auto-advance→execute 触发前再处理。
- **下一步**：`/gsd-plan-phase 16 --research`（`--research` flag 跳过已答的 Step 5.1 交互门，直接 spawn gsd-phase-researcher）。

### 2026-07-17 第九次（/gsd-plan-phase 16 --research — 只跑研究，落盘后检查点停）

- **恢复源**：`16-PLAN-CHECKPOINT.json`（第八次恢复已核对，本次直接消费）+ 第八次 STATE 记录。git HEAD = `6b9c381`，工作树 12 个 lib/ debug 拋留（与 P16 无关）。
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
- **git 状态**：HEAD `0eae691`，其上 `e99ead2`（research）。两个 P16 提交均隔离（仅 .planning/）。12 个 lib/ debug 拋留 + Phase 15 零星残留 + STATE.md(M) 仍未动 —— auto-advance→execute 触发前须处理（见下）。
- **未提交**：本 STATE.md 更新（下一步将随 checkpoint 一起提交）。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-plan-phase 16`（**不带 --research**，因 has_research=true 会自动复用 RESEARCH.md，走 Step 5.1 "Use existing, skip to step 6"）。续跑：Step 5.55 security threat-model 门禁（planner 须发 `<threat_model>`，低风险）→ Step 7.8 spawn gsd-pattern-mapper（写 PATTERNS.md）→ Step 7.9 regenerate API-SURFACE.md → Step 8 spawn gsd-planner opus（写 *-PLAN.md，须含 D27 wc 预算明细 / D24 测试构成 / D21 类级迁移清单 / D22 grep 闸门 / D6 84-调用点签名 / VolumeControl 单路由决策）→ Step 10 checker(sonnet) → Step 12 修订循环(max 3) → Step 13 需求覆盖门(ADAPT-01..05) + 13a 决策覆盖门(D1-D27) + 13b STATE + 13c ROADMAP 注释 + 13d 提交 → 13e gap 分析 → Step 15 auto_advance=true 链 execute-phase 16。
- **auto-advance 警告（重申）**：规划通过后工作流自动 spawn execute-phase 16（会动 lib/kernel/adapter + lib/kernel/diagnostics 新目录）。触发前务必先提交/暂存 12 个无关 lib/ debug 脏文件，否则 execute 阶段工作树混乱。P16 规划本身只写 .planning/，安全。

### 2026-07-25 Step 10 ROADMAP

- **产出**：`ROADMAP.md` 创建（覆盖 v4.0 拋留）— 7 phases（Phase 28-34 续 v4.0 Phase 27 编号），每 phase 含 Goal / Depends on / Requirements / Success Criteria (2-5 observable) / **Blocking Constraints honored** / Plans TBD + Phase Progress Table + Build Order Rationale + Research Flags + Risk Profile + Traceability 表。
- **Coverage**：35/35 v1 requirements mapped，0 orphaned，0 duplicated。Phase 分布 28(REFAC)=2 / 29(PAUSE)=4 / 30(LAYOUT)=5 / 31(VISUAL)=5 / 32(NAV)=7 / 33(AUDIO)=7 / 34(CTRLBAR)=5。Traceability 与 REQUIREMENTS.md Step 9 预填一致，roadmapper 复核确认无分歧。
- **3 项 PRODUCT 决策固化进 phase 硬要求**：① 前置重构纳入 v4.5（REFAC-01/02 → Phase 28，Pitfalls shell-split 硬规则）；② 音频 EQ 纯延迟应用（AUDIO-06 → Phase 33 Success Criterion #3，无 live preview，无引擎快照管理）；③ 面板 16:9 主约束 + 50% 面积次约束（LAYOUT-02 → Phase 30 Success Criterion #1，`width = min(0.5 × screenW, screenH × 16/9)` clamp `[400, 960]`）。
- **构建顺序**：28→29→30→31→32→33→34。Rationale 4 条写入 ROADMAP：split-before-features (Pitfalls 硬规则) + auto-pause-early (Features MVP order + 解锁安全迭代) + layout→visual→navigation (Features 依赖图) + audio-last (33/34 独立于 layout/nav，可并行，config parallelization=true)。
- **Research Flags**：Phase 32 须 `--research-phase 32`（InputModeDetector 是 v4.5 唯一新基础设施，验证 Steam Input 事件签名可分性）；Phase 33 须 `--research-phase 33`（验证 MDK `af` 滤镜 pan/adelay/dynaudnorm 在链接 FFmpeg build 中编译可用）；Phase 34 light research（字幕按钮 primitive 确认 showMenu vs OverlayEntry，可能可跳过）。28/29/30/31 标准模式跳过 research-phase。
- **Risk Profile**：LOW(28,29) → LOW-MEDIUM(30,34) → MEDIUM(31,33) → MEDIUM-HIGH(32, 最高)。最高风险 Phase 32（唯一新基础设施 + Steam Input 边缘案例 + focus-tree 拆分风险），所有风险在 SUMMARY Pitfalls 1-12 有具体缓解。
- **granularity 张力**：config.json `standard`（默认 4-6 phases），但 7 phases 是需求驱动自然边界（每 phase 交付恰好一个 PROJECT.md target feature 或前置重构/安全修复），ROADMAP Overview 已注明未压缩（压缩会混合不相关 feature 跨独立交付边界，同 v3.0 8-phase 先例）。
- **STATE.md 外科手术更新**：frontmatter `total_phases: 0→7`、`last_updated` 刷新；`total_plans`/`completed_phases`/`completed_plans`/`percent` 保持 0（plans 未定义）；历史 Session Continuity（v2.1/v3.0/v4.0 记录）全保留，仅追加本条。
- **UI hint**：7 个 phase 全部含 `**UI hint**: yes`（全部涉及 settings panel / control bar / widget / 视觉/交互）。
- **未提交**：ROADMAP.md + STATE.md(M) + REQUIREMENTS.md（Traceability 已在 Step 9 预填，无需改动）待 orchestrator 呈批批准后提交。建议 commit message: `docs: roadmap v4.5 — 7 phases (28-34) settings panel redesign + audio backfill`。
- **下一步**：呈批 → 批准后提交 → `/clear` → `/gsd-plan-phase 28`（Phase 28 规划，新上下文窗口，纯 refactor 无需 research-phase）。

### 2026-07-25 Phase 28 planning complete (paused for execute, context 71%)

- **规划完整闭环**：planner(opus) `## PLANNING COMPLETE` → checker(sonnet) `## VERIFICATION PASSED` 14/14 → 3 gates (需求门 REFAC-01/02 ✓, 决策门 N/A 无 CONTEXT.md, STATE.md planned-phase ✓)。Step 12 revision loop 跳过 (checker PASSED)。
- **commit `3f99f6e`** (`docs(28): create phase plan`): 28-01-PLAN.md (203 行, new) + STATE.md + ROADMAP.md。工作树干净。amend 自 planner 的 `e8f5139` (未 push, amend 安全)。
- **28-01-PLAN.md 结构**: 1 plan / 1 wave / 3 tasks / 8 files, tracer-first (Task 1 `type="tracer"` extract tab_strip.dart 端到端 → Task 2 extract tab_content+panel_key_bindings → Task 3 delete settings_panel + migrate callers + grep gate)。每 task 有 read_first + acceptance_criteria + concrete action (无 fenced code)。
- **checker live verification**: `grep -rn "SettingsPanel(" lib/ test/` 只返回 legacy class declaration (无外部生产调用者, Task 3 删除安全); 6 test files 存在; settings_overlay_shell.dart=517 行, settings_panel.dart=945 行。
- **跳过的 plan:pre 门控**: pattern-mapper (has_context=false AND has_research=false), intel API-SURFACE (纯重构 planner 直读源文件), specless probe (EDGE_ABSENT, ROADMAP 3 成功标准派生 must_haves), research (纯重构标准模式)。
- **上下文 71% 暂停**: 用户选 checkpoint-then-resume (Phase 15/16 验证模式)。auto_advance=true 但 29% 剩余不足以 spawn execute-phase 28 (动 lib/, 长寿命 subagent)。
- **下一步**: `/clear` → `/gsd-execute-phase 28` (新上下文窗口)。execute-phase 会读 28-01-PLAN.md + STATE.md, 创建 lib/ui/dialogs/settings/tab_strip.dart + tab_content.dart + panel_key_bindings.dart, 删除 lib/ui/dialogs/settings_panel.dart, 跑 flutter test 验证零行为改变。

### 2026-07-25 Phase 28 execute-phase 预 spawn 暂停（上下文 68%，未 spawn executor）

- **恢复源**：28-01-PLAN.md + STATE.md（本条）+ init.execute-phase 28 已跑（全部字段已验证，下个会话可秒级复跑）。
- **状态核对**：工作树干净（`git status --porcelain` 空），分支 `feat/v1.8-stability-polish-plan-02-02`，HEAD `7a0b1b2`（与规划 checkpoint 一致）。
- **init.execute-phase 28 验证结果**：`phase_found=true`, `phase_dir=D:/simple_player_flutter/.planning/phases/28-settings-shell-split-legacy-deletion`, `plan_count=1`, `incomplete_count=1` (28-01-PLAN.md), `executor_model=sonnet`, `verifier_model=sonnet`, `parallelization=true`, `branching_strategy=none`（留当前分支）, `context_window=200000`, `agents_installed=true`, `missing_agents=[]`, `agent_runtime=claude`, `phase_req_ids=REFAC-01, REFAC-02`, `requirements_path=.planning/REQUIREMENTS.md`。28-01 frontmatter: `autonomous=true`, `wave=1`, `depends_on=[]`, 8 files_modified。
- **阻塞反模式检查（check_blocking_antipatterns 步）**：Phase 28 目录无 `.continue-here.md`（只有 28-01-PLAN.md）；`.planning/.continue-here.md` 的 8 项 blocking constraints 全是 v3.0 内核重写相关（logger/状态机/适配层/MemoryMonitor，归属 Phase 15-22），**不适用于** v4.5 Phase 28 设置面板重构。无 blocking 反模式，继续。
- **interactive mode 检查**：用户调用 `/gsd-execute-phase 28` 无 `--interactive` flag → 走标准 subagent 模式（Claude Code + Agent 工具可用 → 必须 spawn gsd-executor，inline 未授权）。
- **执行计划摘要**：单 plan 单 wave，3 tasks tracer-first。Task 1 (`type="tracer"`, tdd=true) 提取 `tab_strip.dart` 端到端证明 tab 选择链路 → Task 2 (auto, tdd=true) 提取 `tab_content.dart`+`panel_key_bindings.dart` → Task 3 (auto) 删 `settings_panel.dart` (945行) + 更新 stale comments + grep gate。每文件 <300 行，shell <500 行，pubspec 不变，`flutter test` 全绿。
- **worktree 决策（下个会话执行时）**：单 plan 单 wave 无并行收益，worktree 隔离只增 `.git/config.lock` 风险。建议 **sequential 模式**（`USE_WORKTREES_FOR_PLAN=false`，不传 `isolation="worktree"`）——功能等价、更简单、避开 glm-5.2 间歇宕机期 worktree 清理复杂度。
- **上下文 68% 暂停决策**：系统警告 32% 剩余不宜启动复杂工作。STATE 历史第 228 行用户已评估"29% 不足以 spawn execute-phase 28（动 lib/, 长寿命 subagent）"——本次仅 +3%。沿用 Phase 15/16 验证模式：**checkpoint-then-resume**。不对称风险：现在 spawn 最佳情况勉强够，最坏情况测试失败/verifier 发现 gap 时无恢复预算，中途 checkpoint 状态更差；现在 checkpoint 无下行风险。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-execute-phase 28`。init 已验证可秒级复跑；orchestrator 从 fresh 200K 开始 → spawn gsd-executor (sonnet, sequential mode) 读 28-01-PLAN.md + 6 源文件 + 6 测试文件（fresh 200K 上下文）→ 执行 3 tasks 原子提交 → 跑 `flutter test`（`D:/flutter/bin/flutter`，不在 PATH，用全路径）→ 写 28-01-SUMMARY.md → orchestrator spot-check + post-merge gate + tracking update → spawn gsd-verifier (sonnet) → phase completion。

### 2026-07-26 Phase 28 execute spawn halt（fresh 子代理注入耗尽，零改动）

- **spawn gsd-executor (sonnet, sequential) 安全 halt，零改动**：HEAD 仍 `eee0aac`，工作树仅 `M .planning/STATE.md`（state.begin-phase 改）。executor 报告加载 PLAN+STATE 后 89%，`subagent_tokens=52453`(52K) vs 89% 表明 fresh 子代理窗口远小于 200K（~60K）。注入开销：execute-plan.md(~25K)+CLAUDE.md(~15K)+STATE.md(244 行全历史)+模板+system prompt。**系统性 GSD 子代理注入问题，非 Phase 28 特有**。
- **checkpoint 文件**：`.planning/phases/28-settings-shell-split-legacy-deletion/28-EXECUTE-CHECKPOINT.md`（精简 spawn 策略 + `--interactive` fallback 详节）。
- **用户决策**：精简 spawn 模式（省 STATE/PROJECT/config/checkpoints/tdd 注入，只留 PLAN+CLAUDE+execute-plan+summary）。风险：若子代理窗口确实 ~60K，精简后注入仍可能 80%+ halt。
- **Fallback**：若精简 spawn 再 halt → `/gsd-execute-phase 28 --interactive`（主会话 200K 窗口 inline 跑 3 tasks，每 task checkpoint，避开子代理注入开销）。
- **下一步**：`/clear` → `/gsd-execute-phase 28`（orchestrator 读 checkpoint 应用精简 spawn 策略；若再 halt 呈 `--interactive` fallback）。

### 2026-07-26 Phase 28 execute 3rd halt（orchestrator 预算 67%，零 spawn）

- **恢复源**：28-EXECUTE-CHECKPOINT.md + 28-01-PLAN.md + init.execute-phase 28（秒级复跑，字段已验证）。
- **状态核对**：HEAD `eee0aac`，工作树 `M .planning/STATE.md` + 未追踪 checkpoint，分支 `feat/v1.8-stability-polish-plan-02-02`，零代码改动。
- **halt 原因（与 2nd attempt 不同）**：orchestrator 上下文在加载 execute-phase.md(1676 行) + STATE.md(250 行历史) + plan(200 行) + CLAUDE.md + 系统 prompt + agent registry 后已耗 67%。剩余 33% 不足以跑完 post-spawn 全流程（executor dispatch + return + spot-check + post-merge `flutter test` gate + verifier spawn + phase completion + STATE/ROADMAP 写入）。
- **用户决策（AskUserQuestion）**：选 **"Checkpoint, fresh window"**（最安全路径），不 spawn、不 inline，记录状态后 `/clear` 新窗口重试。
- **slim spawn 子代理风险不变**：subagent 有效窗口 ~60K（2nd attempt 实测 52K=89%），slim 注入 ~50K 仅余 ~9K 给 3 tasks，仍可能 halt。
- **checkpoint 更新**：28-EXECUTE-CHECKPOINT.md frontmatter `attempts: 3`、`created: 2026-07-26`、halt_reason 改为 orchestrator-budget；append 3rd-halt 节 + 下窗口建议（slim spawn 或 `--interactive`，推荐 `--interactive` 因 3 次 halt 后最可恢复；lean orchestrator tip：下窗口只读 checkpoint+plan+execute-phase.md，跳过重读 STATE.md 全历史省 ~10K）。
- **下一步（新窗口）**：`/clear` → `/gsd-execute-phase 28`（fresh 200K）。读 checkpoint 应用 lean 加载（跳过 STATE 全历史）→ 选 slim spawn 或 `--interactive`（后者主会话 inline 跑 3 tasks，无子代理注入开销，fresh 窗口预算够 Task 1+2+3 + post-merge gate）。

### 2026-07-26 Phase 28 complete (interactive inline mode, 3/3 tasks + SUMMARY)

- **执行模式**：`/gsd-execute-phase 28 --interactive inline`（主会话直接跑，避开 3 次 subagent spawn halt）。3 次 fresh 子代理注入耗尽后用户切 inline 模式，单窗口 200K 主会话跑完 Task 1+2+3 + SUMMARY + 全套件验证。
- **3 个原子 commit + 1 docs commit**：
  - `e2d7f3f` refactor(28-01): extract SettingsTabStrip (91 行) — tracer tdd
  - `1592386` refactor(28-02): extract SettingsTabContent (121 行) + SettingsPanelKeyBindings (82 行) — tdd
  - `364676f` refactor(28-03): delete legacy settings_panel.dart (945 行) + refresh 3 stale comments
  - `650acd3` docs(28): record Phase 28 SUMMARY
- **验收数据**：shell 467→331 行 (<500 ✓); 4 个提取文件全 <300 行 (tab_strip 91 / tab_content 121 / panel_key_bindings 82); pubspec.yaml 未变; grep gate `SettingsPanel(` 零外部调用; 7-child IndexedStack 显式结构保持; FocusTraversalGroup ≥4 不变; 状态归属不变 (SettingsPanelController.state.selectedTab 唯一拥有者)。
- **测试结果**：dialogs 子集 128/132 (4 预存在失败 stash 鉴别非回归: settings_nav_item_test 2 个 = Phase 25 SettingsNavItem; settings_tab_content_test DropdownButton 2 个 = GeneralTab headless); 全套件 2361 通过 + 26 跳过 + 68 失败 (4 dialogs 预存在 + 64 engine/kernel mdk.dll FFI 预存在, Phase 28 不触及这些模块, 按模块边界判断)。
- **关键工程教训**：(1) 提取时 import 完整性 — panel_key_bindings.dart 需 material.dart (FocusNode/KeyEventResult via widgets) + services.dart (LogicalKeyboardKey/KeyEvent/KeyDownEvent), widgets.dart 用 `show` 限定 re-export 子集不能依赖传递性; (2) Tracer TDD 鉴别 — stash + 跑 HEAD 基线把"测试全绿"(不可达, 预存在失败)转化为"提取零回归"(可达, 对比基线); (3) 按模块边界快速判断预存在失败 — Phase 28 只改 lib/ui/dialogs/settings/, 全套件 68 失败中 64 在 engine/kernel, 物理上无法触及。
- **预存在技术债登记**（非 Phase 28）: settings_nav_item_test 2 个 (Phase 25 SettingsNavItem), settings_tab_content_test DropdownButton 2 个 (GeneralTab headless), fvp_engine_contract_test ~57 个 mdk.dll FFI 加载失败 (headless 环境, 见 memory reference_mdk_dll_headless_test_failures.md)。
- **STATE.md 外科手术更新**: frontmatter status executing→phase_complete, completed_phases 0→1, completed_plans 0→1, percent 0→14; Current Position EXECUTING→COMPLETE; 追加本条历史。历史 Session Continuity 全保留。
- **下一步**: Phase 28 结构债务清零, 可启动 v4.5 设置面板重设计下一 phase。Phase 29 = auto-pause-detector (PAUSE, 4 reqs), 标准模式 (无需 research-phase, ROADMAP 仅 32/33 须 research)。`/clear` → `/gsd-plan-phase 29`。ROADMAP phases 28-34, 构建顺序 28→29→30→31→32→33→34, Phase 28 已完成 1/7。

### 2026-07-26 Phase 30 research-only resume (spawn 成功, RESEARCH.md a813590, HANDOFF闭环)

- **恢复源**: `.planning/HANDOFF.json` (一次性工件, 2026-07-26T11:23:04Z) + `.planning/phases/30-panel-layout-redesign/.continue-here.md` + `30-RESEARCH-CHECKPOINT.md` (verbatim researcher prompt)。
- **blocker 校验**: HANDOFF 记录两 blocker — ① classifier kimi-k3 down (外部间歇) ② context 75% critical。本次 fresh 窗口 (context 已清) spawn gsd-phase-researcher (sonnet, 同步, run_in_background=false) 成功，classifier 已恢复。
- **researcher 产出**: `30-RESEARCH.md` (441 行, HIGH confidence) 已自提交 `a813590` (commit_docs=true 指示)。researcher 校正 CONTEXT.md 3 处漂移 (sizing seam 行号 172-180 非 172-179; "800px breakpoint" 仅驱动 tab-compact 非 sizing → Assumption A2; `SettingsPanelController.open()` 重置 selectedTab=0 的 D-01 ripple → Pitfall 1) + 识别 multi-monitor clamp 设计缺口 (无同步窗口位置源, 推荐 Option A drag-start 缓存) + test re-baseline 风险升级 (3 文件 14 断言 + 2 文件 ~8 tab-index 断言, 非 CONTEXT 点的 2 文件)。
- **3 Open Questions 留给 planner**: A1 open() 重置→index 3 (保"开在 General"); A2 D-04 "删 breakpoint"=sizing-only, 保留 tab-compact; A3 窗口位置源 Option A (drag-session 缓存) vs B (WindowService notifier), A 推荐。
- **HANDOFF 闭环**: `git rm .planning/HANDOFF.json` + `git rm .planning/phases/30-panel-layout-redesign/.continue-here.md` (两一次性工件, 恢复成功后删除 per workflow)。`30-RESEARCH-CHECKPOINT.md` 保留 (含 verbatim prompt + resume 史, 规划通过后安全删除)。
- **§5.1 research-only early-exit**: RESEARCH_ONLY=true → 不 spawn planner/checker/verifier。下一步 = `/clear` → `/gsd-plan-phase 30` (has_research=true → 走 §5.1 "Use existing, skip to step 6", 直接 spawn planner opus 消费 30-RESEARCH.md + 30-CONTEXT.md 写 30-01-PLAN.md)。
- **未提交**: 本次 STATE.md frontmatter+body 更新 + HANDOFF/.continue-here 删除, 随本条 commit 闭环。3 个非本会话 untracked checkpoint (30-DISCUSS-CHECKPOINT.json / 30-PLAN-CHECKPOINT.md / 29-EXECUTE-CHECKPOINT.md) 仍 ?? 未动 per HANDOFF exclude 规则。

### 2026-07-26 Phase 30 UI-phase checkpoint（Step 1-4 done, spawn deferred @ 65%）

- **恢复源**: fresh `/clear` → `/gsd-ui-phase 30` skill 调用。本会话不是恢复旧 checkpoint, 是 fresh 窗口启动 ui-phase 工作流。
- **本会话已完成 (Step 1-4)**:
  1. **Step 1 Initialize**: `gsd-tools query init.plan-phase 30` 全字段已解析 — phase_found=true, phase_dir=`D:/simple_player_flutter/.planning/phases/30-panel-layout-redesign`, padded_phase="30", phase_req_ids=LAYOUT-01..05, phase_status=Pending, has_context=true, has_research=true, has_plans=false, commit_docs=true, text_mode=false, auto_advance=true, researcher_model=sonnet/planner_model=opus/checker_model=sonnet, agents_installed=true/missing_agents=[], agent_runtime=claude, project_title="Simple Player — 设置面板横向重构 + 音频功能 (v4.5)"。`config-get workflow.ui_phase`=true (ENABLED)。
  2. **Step 2 Validate**: `roadmap.get-phase 30` found=true, 5 success criteria + blocking constraints honored section 确认 (overlay mode / Windows primary / 现有 FFI 无新 deps / Tokens.* 无 hardcoded)。
  3. **Step 3 Prereqs**: has_context=true (30-CONTEXT.md 143 行, 8 CF + 6 D pre-locked); has_research=true (30-RESEARCH.md 442 行, HIGH confidence, 4 seams verified, 3 drifts corrected); sketch findings=none; response_language 未设 (subagent prompts English, user-facing 简体中文 per CLAUDE.md)。
  4. **Step 4 Existing UI-SPEC**: Glob `*CHECKPOINT*` 返回 DISCUSS/RESEARCH/PLAN 三个, 无 `*-UI-SPEC.md` → AskUserQuestion (update/view/skip) 不适用, 直接进 Step 5。
- **halt 原因 (context budget 65%)**: memory `feedback_gsd_context_budget_pause` (2026-07-26, today) 硬约束 "60%+ 窗口启动 spawn 会 halt mid-spawn, 先写 checkpoint 暂停而非强行 spawn"。ui-phase 要 spawn **两个**子代理 (researcher + checker) + revision loop (max 2) + UI-consideration probe (node + AskUserQuestion multi-round) + commit + state, 35% 不足以跑完全链。不对称风险 (STATE.md L241 已验证): spawn 最佳情况勉强够, 最坏 researcher 返回后无预算处理 checker/revision/probe → 中途 halt 状态更差; checkpoint 无下行风险。
- **checkpoint 工件**: `.planning/phases/30-panel-layout-redesign/30-UI-CHECKPOINT.md` (frontmatter attempts=1/created=2026-07-26/halt_reason=context_budget_65pct/step_at_halt=between Step 4 and Step 5)。含: init 验证 verbatim 表 (fresh 窗口不必重跑) + 5 success criteria + 8 CF/6 D pre-locked 清单 (researcher MUST NOT re-ask) + **预构造 researcher prompt 模板** (含 files_to_read 5 条 + locked_decisions 块 + design_focus 6 项: Tokens/tab-sequence/multi-monitor-clamp/vertical-unify/copywriting/state-coverage) + spawn 策略 (gsd-ui-researcher/sonnet/sync/run_in_background=false, 参考 a813590 成功模式) + fresh 窗口 lean 复用指令 (跳过 STATE 全历史省 ~10K) + 上下文预算守卫 (fresh 200K 估算: 32% baseline + 26% spawn chain = 58%, 42% margin) + interactive-inline fallback (Phase 28 先例) + 3 个 open assumptions (A1/A2/A3) 留给 researcher。
- **未提交**: 本次 STATE.md frontmatter+body 更新 + 30-UI-CHECKPOINT.md (new untracked)。建议 commit message: `docs(30): UI-phase checkpoint — Step 1-4 done, spawn deferred @ 65%`。
- **下一步 (新上下文窗口)**: `/clear` → `/gsd-ui-phase 30`。fresh 窗口读 30-UI-CHECKPOINT.md (lean, 跳过 STATE 全历史) + 30-CONTEXT.md + 30-RESEARCH.md → 跳 Step 4 AskUserQuestion → spawn gsd-ui-researcher (sonnet, sync, 用预构造 prompt 模板填 `${AGENT_SKILLS_UI}`) → 写 30-UI-SPEC.md → spawn gsd-ui-checker (sonnet, 6 维度) → revision loop (if ISSUES, max 2) → Step 9.5 UI-consideration probe (resolve ui-consideration-probe.cjs + ELEMENTS_JSON + AskUserQuestion resolution) → Step 10 READY banner → Step 11 commit docs(30): UI design contract → Step 12 state.record-session → 删 30-UI-CHECKPOINT.md (一次性工件闭环) → 下一步 `/gsd-plan-phase 30` (has_research=true 走 §5.1 "Use existing, skip to step 6", planner 消费 30-RESEARCH.md + 30-CONTEXT.md + 30-UI-SPEC.md 写 30-01-PLAN.md)。
- **若 researcher spawn halt 备选**: fresh 子代理窗口 ~60K (STATE.md L246 实测), 若注入后 halt, fall back `--interactive inline` 模式 (Phase 28 先例 STATE.md L262-275, 主会话直接写 30-UI-SPEC.md 用 template + RESEARCH + CONTEXT 作输入, 无子代理)。但 Phase 30 phase-researcher a813590 已证明 fresh 窗口 spawn 可行, 首选 spawn。

### 2026-07-27 第十次恢复（/gsd-resume-work → 用户选恢复 Phase 31 discuss）

- **恢复源**：`.planning/HANDOFF.json`（2026-07-27T08:49:25Z，phase 31 discuss pre-gray-area，4/10 done）+ `.planning/phases/31-visual-design-alignment/.continue-here.md`（phase-level checkpoint）。无 interrupted agent、无 async-job、无 PLAN-without-SUMMARY。
- **三个状态偏差已核对**：(1) STATE.md frontmatter 滞后（本条已修正：phase 30→31、status complete→discuss-paused、completed_phases 2→3、percent 29→43）；(2) `29-EXECUTE-CHECKPOINT.md`（untracked）过时残留——记录 execute 3 次 halt/zero edit，但 git full-history 显示 Phase 29 在那之后成功闭环（plan `d8aeb585` → Task1-4 `39bb649f`/`4cc4eb28`/`7524d221`/`8e88577b` → summary `ed6828bd` → complete `a63650a6` → verification `2f1c4ccb`，29-01 PLAN+SUMMARY+VERIFICATION 三件齐），checkpoint 是过时快照可删；(3) 工作树脏 43 files（23 lib/kernel + tests + pubspec，净 -670 行）跨会话累积，与 Phase 31 discuss（只写 .planning/）物理隔离当前安全，但 `/gsd-ui-phase 31` 的 ui-researcher 读 lib/ui/player/ 源码（player_screen.dart 脏、control_bar.dart 干净）触发前应处理。
- **用户决策**（AskUserQuestion）：选 **"恢复 Phase 31 discuss (推荐)"** —— 从 HANDOFF.json 恢复 gray-area discussion（remaining tasks 5-10：scout_codebase → analyze_phase → present_gray_areas → discuss_areas → write_context → git_commit）。
- **未提交**：本次 STATE.md frontmatter + Current Position + 本条 Session Continuity。43 个无关脏 lib/kernel 文件不动。不单独提交 STATE.md——/clear → `/gsd-discuss-phase 31` 的 git_commit 步骤（commit "docs(31): capture phase context"）会带上 STATE.md 改动闭环。HANDOFF.json 由 discuss-phase 成功恢复后自动闭环删除。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-discuss-phase 31`。fresh 200K 窗口，check_existing 检测 HANDOFF.json 提供 Resume → 从 `remaining_tasks[5]=scout_codebase` 续跑。预读 `lib/ui/player/control_bar.dart`（`_decorationPlaying` 4-shadow 实现）+ `30-UI-SPEC.md`（视觉参数直接来源）+ `30-CONTEXT.md`（D-02 deferred chrome boundary）。预期 4 gray areas：① 共享 decoration token 命名 ② 三态按钮 Tokens.* 颜色值 ③ density 像素值 ④ 透看选项 border policy。
- **上下文预算守卫**：memory `feedback_gsd_context_budget_pause`（2026-07-26）硬约束 60%+ 启动交互式多轮工作流会 halt。discuss-phase = 4 区 × 4 轮 AskUserQuestion + 写 CONTEXT.md/DISCUSSION-LOG.md + commit + state。本 resume 窗口已耗 66%，不建议本窗口续跑 → /clear 后 fresh 跑。

### 2026-07-28 第十一次恢复（/gsd-resume-work → 用户选启动 Phase 32 research）

- **恢复源**：`.planning/HANDOFF.json`（2026-07-28T08:22:49Z，phase 32 paused-pre-research，0/7 tasks）+ `.planning/.continue-here.md`（phase 32 level checkpoint，同时间戳，内容一致）。无 interrupted agent、无 async-job、无 PLAN-without-SUMMARY（Phase 32 目录尚未创建，pre-research 阶段）。
- **三方状态核对一致**：(1) git HEAD `54b348f7 wip: phase-32 paused at pre-research`（工作树干净，HANDOFF 记录的 `uncommitted_files: [.planning/STATE.md]` 已被该 commit 提交闭环）；(2) Phase 31 闭环确认 — `55f90724` verification passed-with-note + `ae8145b4` phase complete + `64fd9f91`/`2737d537`/`d2496aaf` SettingRow three-state plan；(3) Phase 32 目录 `.planning/phases/32-navigation-interaction-polish/` **不存在**（pre-research，research 会创建）。
- **两个 .continue-here 区分**：`.planning/.continue-here.md` = Phase 32 有效 checkpoint（paused-pre-research，7 项 NAV 需求 + 2 blocking constraints）；`./.continue-here.md`（根目录）= 2026-07-10 v1.6 时代遗留噪声（HEAD `b8d431b3`，待清理，非当前 phase）。
- **STATE.md 滞后修正**：frontmatter `current_phase 31→32`、`status complete→paused-pre-research`、`completed_phases 3→4`、`percent 43→57`、`last_activity 2026-07-27→2026-07-28`；Current Position + Project Reference Current focus 同步到 Phase 32。历史 Session Continuity 全保留。
- **用户决策**（AskUserQuestion）：选 **"启动 Phase 32 research (推荐)"** —— 按 HANDOFF.next_action + ROADMAP L145/L210 硬性要求，spawn gsd-phase-researcher 验证 Steam Input 事件签名可分性（核心 blocker）+ InputModeDetector heuristic 信号可靠性 + gameButton 绑定影响面，产出 32-RESEARCH.md。
- **未提交**：本次 STATE.md frontmatter + Current Position + Project Reference + 本条 Session Continuity。不单独提交——fresh 窗口 `/gsd-plan-phase 32 --research-phase 32` 的 git_commit 步骤会带上 STATE.md 改动闭环（第十次恢复先例 STATE L309）。HANDOFF.json + `.planning/.continue-here.md` 由 research 成功恢复后闭环删除（一次性工件）。
- **强耦合约束（blocking，research 喂给 planner）**：NAV-04（删 `gameButtonLeft1/Right1` 绑定）与 NAV-07（单一根 `Focus(onKeyEvent:_handleKeyEvent)`）**必须同批落地**于同一 plan —— 否则 ←/→ 逃逸到 `KeyboardHandler` 触发 seek ±5s 回归。
- **下一步（新上下文窗口）**：`/clear` → `/gsd-plan-phase 32 --research-phase 32`（fresh 200K 窗口，spawn gsd-phase-researcher/sonnet，参考 Phase 30 researcher `a813590` 成功模式）。researcher 核心必答：Flutter `Focus.onKeyEvent` / `HardwareKeyboard` 能否区分 Steam Input 映射的 LB/RB vs 原生 ←/→（若 byte-identical，heuristic 须依赖 absence-of-mouse-move + arrow-key-presence）。读 `lib/ui/player/keyboard_handler.dart` + Steam Input docs + cross-reference `project_steam_steamos_plan` memory。产出 32-RESEARCH.md → 派生 32-VALIDATION.md → 后续 plan→execute→validate。
- **上下文预算守卫**：memory `feedback_gsd_context_budget_pause`（2026-07-26）硬约束 60%+ 窗口启动 spawn 会 halt mid-spawn。本 resume 窗口已读 STATE.md(316 行)+PROJECT.md+HANDOFF+.continue-here+ROADMAP sections，不建议本窗口 spawn researcher → /clear 后 fresh 跑。
- **附带清理候选（非阻塞，HANDOFF 记录）**：删 `lib/kernel/player_services.dart.bak`；同步 CLAUDE.md 架构树（漏记 `lib/features/`、`kernel/adapter|diagnostics|startup`、`ui/window/`(含迁出的 `custom_title_bar.dart`)、`ui/dialogs/settings/*`；Design System 节 tokens 路径应为 `lib/ui/theme/` 非 `kernel/ui/theme/`）。
- **交接 plan 文件**（上次会话产出，researcher 可参考但非执行 plan）：`C:/Users/35490/.claude/plans/32-snappy-lantern.md`（7 项需求、research 必答问题、关键文件路径、6 条验收标准）。

### 2026-07-28 Phase 32 research-only complete (RESEARCH.md 645904ab, MEDIUM confidence)

- **恢复源**：`32-RESEARCH-CHECKPOINT.md`（lean load: init 已查 + VERBATIM prompt + post-spawn procedure 已固化）+ HANDOFF.json + .continue-here.md（phase 32 paused-pre-research 快照）。
- **本会话**：fresh 200K → spawn gsd-phase-researcher (sonnet, sync, VERBATIM prompt) → `## RESEARCH COMPLETE` MEDIUM（265K tokens, 80 tool_uses, ~13.4 min）。隔离自提交 `645904ab`（仅 32-RESEARCH.md）。
- **核心 blocker 解决**：Steam Input 事件签名可分性 — 直接 gamepad key events 有 distinct Flutter key constants，但 Steam Input 映射注入的 normal keyboard ←/→ 失去 controller provenance → InputModeDetector heuristic MUST 用 mouse-idle + arrow-key-presence + manual toggle fallback（非 key event 本身路由）。
- **3 项假设校正（喂 planner）**：① `gameButtonLeft1/Right1` 实际在 `lib/ui/dialogs/settings/panel_key_bindings.dart`（**非** `keyboard_handler.dart`）→ NAV-04 位置纠正；② mouse detection 主信号 `Listener.onPointerHover`（`onPointerMove` 仅 pointer-down）；③ panel 已有 `GlassContainer` blur，NAV-05 MUST color-only Container 无嵌套 BackdropFilter。
- **NAV-04/NAV-07 强耦合确认**：settings-root `Focus` 须对所有方向键返回 `handled` 防止 player seek/volume 泄漏 — 同 plan 原子落地。
- **3 Open Questions 留 planner**：① Windows 上目标 Steam Input LB/RB profile 的实际 Flutter event fields（manual capture）；② manual toggle user-facing 位置；③ 第一个 NAV-05/06 overlay 的 option-list tab。
- **Validation Architecture 已写**：32-RESEARCH.md L353 → 下次 `/gsd-plan-phase 32` 派生 32-VALIDATION.md。
- **一次性工件闭环**：`git rm HANDOFF.json` + `git rm .continue-here.md`（research 成功恢复后闭环）。`32-RESEARCH-CHECKPOINT.md` 保留（规划通过后删，Phase 30 先例）。
- **下一步**：`/clear` → `/gsd-plan-phase 32`（不带 --research，has_research=true 走 §5.1 "Use existing" 直接 spawn planner opus 消费 32-RESEARCH.md 写 32-0X-PLAN.md）。

### 2026-07-30 Phase 32 wrap-up complete (32-03-SUMMARY.md + STATE update; awaiting verifier)

- **恢复源**：`.planning/HANDOFF.json`（2026-07-29T17:20:13Z，paused-task2-resolved-with-deferral，task 2/2）+ `.planning/phases/32-navigation-interaction-polish/.continue-here.md`（phase-level checkpoint，同时间戳）。无 interrupted agent、无 async-job、无 PLAN-without-SUMMARY（除 32-03-PLAN.md 本身）。
- **本会话**：fresh 窗口 → 写 `32-03-SUMMARY.md`（lead with Diagnostic finding: Xbox LB/RB 不到达 `Focus.onKeyEvent` on Windows desktop; 32-01 `gameButton12/13` premise falsified; deferred to 32-04 XInput bridge）→ Task 1 summary（`52764c33`, 6/6 tests, gate PASS, BP3 extraction override）→ Task 2 checkpoint resolution（keyboard verified, gamepad deferred per Step 5, diagnostic NOTE `cac31475`）→ Rule 1 deviations（gamepad deferral plan-sanctioned; BP3 extraction override; ShortcutsTab overflow fix）→ 更新 STATE.md frontmatter（status executing→phase_complete, completed_phases 3→4, completed_plans 10→11, percent 43→57, last_activity 2026-07-29→2026-07-30）+ Current Position（EXECUTING→COMPLETE, Plan 1 of 3→3 of 3）。
- **32-03-SUMMARY.md 结构**：Diagnostic finding（最重要输出，falsified 32-01 premise）→ Task 1（overlay + mount + gate）→ Task 2（checkpoint resolved with deferral）→ Artifacts（2 commits: `52764c33` + `cac31475`）→ must_haves truths 7/7 → Rule 1 deviations（4 项）→ Handoff to verifier（all 3 waves complete, 9 commits total）。
- **一次性工件待闭环**：`HANDOFF.json` + `.planning/.continue-here.md`（phase 32 level）— verifier 成功运行后删除。`32-RESEARCH-CHECKPOINT.md` 保留（规划通过后删，Phase 30/32 先例）。
- **下一步**：(1) 提交 `32-03-SUMMARY.md` + `STATE.md`（建议 commit message: `docs(32): record Phase 32 Wave 3 SUMMARY`）；(2) 删 `HANDOFF.json` + `.planning/.continue-here.md`（一次性工件闭环）；(3) run `gsd-verifier` for Phase 32（会 flag gamepad gap → 32-04 gap-closure plan: XInput bridge）；(4) `/clear` → 下一会话处理 32-04（或 verifier 后 auto-advance 到 Phase 33）。
- **上下文预算守卫**：本窗口已耗 ~70%。提交 + 删 HANDOFF/.continue-here + 呈批 verifier 可本窗口做；spawn gsd-verifier (sonnet) 建议 fresh 窗口（参考 Phase 31 verifier 模式）。

### 2026-07-30 v4.5 wrap-up (P33 deferred, P34 skipped)

- **触发**：Phase 33 运行时门——用户在 target Windows 真机应用音频滤镜（pan/adelay/dynaudnorm，含 EQ）后判定「完全无法使用」，听感完全无效。
- **根因（强嫌疑，未验证）**：`setProperty('af', afFilter)` 路由在 fvp 0.37.2 上未接线到音频滤镜管线。RESEARCH 的"af already works"从未经听感验证（`_guardedAction` 吞异常致 probe 不权威）。视频滤镜用 `video.avfilter`（MDK 原生命名），按对称性音频应为 `audio.avfilter` 而非 `af`（mpv 别名）——RESEARCH L183 锁定 `af` 建立在未验证假设上。源注释 `subtitle_configurator.dart:71-77` 自相矛盾（lavfi 包装 vs 裸逗号语法）。详见 `33-DEFERRED.md`。
- **用户决策（AskUserQuestion）**：选「保留代码 + deferred 收尾」——不试 `audio.avfilter`（30 秒验证），直接止损。撤回此前锁定的"不允许部分遗漏"硬约束（用户主动撤回）。Phase 34 skipped。v4.5 收尾。
- **保留产物**：P33 三 plan 代码 + 121/121 聚焦测试 + 3 SUMMARY + `33-DEFERRED.md` 根因记录全部保留。未来重启 = 改 1 行属性名 `af`→`audio.avfilter` + 真机听感，见 33-DEFERRED.md「How to resume」。
- **未做**：未 spawn verifier（P33 不完成）；未改 lib/ 代码（保留）；未回滚 P33 提交。
- **ROADMAP 校准**：P33 标 deferred、P34 标 skipped、v4.5 milestone 行 IN PROGRESS→WRAPPED。ROADMAP Progress 表 P28-32 仍滞后（标 "Not started" 但实际完成），非本次范围，留作技术债。
- **提交**：`docs(33): defer audio tab — af route unverified; skip P34; wrap v4.5`（含 33-DEFERRED.md + STATE.md + ROADMAP.md + 删 33-EXECUTE-CHECKPOINT.md）。
- **下一步**：v4.5 收尾完成。用户可选 `/gsd-new-milestone` 启动下一里程碑，或在未来重启 P33（1 行属性名改动可能救活）。

### 2026-08-11 Phase 36 planning complete

- 生成并校验 3 个可执行计划：36-01 ControlBar 局部 rebuild tracer、36-02 PlayerScreen/video identity 与 source replacement、36-03 listener/timer 生命周期收口。
- checker 修正 36-03 为 Wave 3 并依赖 36-01/36-02，避免并行修改同一 controls 生命周期文件；修正 `CenterGroup` 的实际源码路径。
- 所有生产修复均受“测试先 RED，只有真实失败才修复”约束；保护当前未提交 `custom_title_bar.dart` 与未确认 PNG，不恢复 ControlsOverlay、不修改 media_kit。
- 下一步：`/gsd-execute-phase 36`。

### 2026-07-31 C 增强后两个 bug 诊断(需求1全屏控制栏 + 需求5打开文件)— 未实施,待下窗口

**背景**:C 增强计划(media-kit-wise-river.md,控制栏 auto-hide 对齐 media_kit)代码+测试已完成。用户报两个新 bug,AskUserQuestion 确认:需求1现象="切换瞬间立即消失",本次范围="仅先修两个 bug(1,5)"。

**需求1:全屏切换控制栏立即消失**

- 根因(确定):`window_service.dart:193-195` `setMode(WindowMode.fullscreen)` 是 TODO 空实现。全屏走 `videoKey.toggleFullscreen()`(player_keyboard_actions:64,media_kit→fullscreen_window cpp→`SC_MAXIMIZE`)→ `onWindowMaximize:144` 设 mode=maximized(非 fullscreen)→ `isFullscreen` 永远 false → `ControlsOverlay.didUpdateWidget` isFullscreen 分支不触发 → `_isFullscreenTransition` 永不置 true → `_onResizeChanged:169` `reverse()` 淡出。C 增强把 fade 400→150ms 让淡出变"瞬间消失"。
- 连累(系统性):① C 增强全屏隐藏鼠标/字幕上移失效(isFullscreen=false);② ESC 退全屏 `if(isFullscreen)`(player_keyboard_actions:66)失效;③ 窗口/全屏 auto-hide 延迟统一(isFullscreen=false 永走 windowed 延迟)。
- 治本深坑:fullscreen_window cpp 用 `SC_MAXIMIZE`→`onWindowMaximize` 覆盖 mode=maximized。即使 setMode 设 mode=fullscreen 也会被立即覆盖。必须加 `_fullscreenIntent` 守卫。
- 方案A(推荐):① `window_service.setMode(fullscreen)` 调 `FullScreenWindowPlatform.instance.setFullScreen(true)`+`_fullscreenIntent=true`+`mode=fullscreen`;② `onWindowMaximize` 检查 `_fullscreenIntent` 跳过 mode=maximized;③ `onToggleFullscreen`(player_keyboard_actions:64 + player_screen _buildPlayerActions:372)改走 `windowService.setMode(isFullscreen?windowed:fullscreen)`,弃 `videoKey.toggleFullscreen`;④ `onExitFullscreen` 保留(isFullscreen 修正后生效)。
- 方案B(替代):弃 fullscreen_window,改用 `windowManager.setFullScreen`(window_manager 自带),onWindowMaximize 不冲突。但需验证 window_manager setFullScreen 与现有 fullscreen_window 不冲突(media_kit 是否还调)。
- 用户可先手动验证根因:全屏后按 ESC — 若 ESC 也退不出全屏,印证 `isFullscreen=false`(mode 不同步)。

**需求5:停止后打开文件无反应**

- 链路:`_openFile`(player_feature:162)→`controller.openAndPlay`→`fileOps.openAndPlay`(file_operations:36)→`PathValidator.validate`+`navigator.playIndex(idx)`→`engine.open`(idle→opening→idle,契约允许 idle)+`play()`。代码链路无 idle 阻塞。
- 根因(待确认):疑 FilePicker 不弹(与需求6 file picker 多开同源)非状态机阻塞。
- 需手动复现:点打开文件按钮(EmptyState 中间 或 ControlBar 右下)观察 picker 是否弹出。①不弹→需求6同源(FilePicker guard/聚焦);②弹但选文件不播→查 PlaybackNavigator.playIndex + engine.open generation 守卫。

**未实施原因**:context ~72% + 两 bug 需 GUI 手动验证(无头测不出全屏/FilePicker)+ 需求1治本涉及 4-5 文件 + SC_MAXIMIZE 深坑 + 核心交互风险。半成品(全屏坏)比不修更糟。记录根因+方案,下窗口实施+手动验证。memory `project-bug-fullscreen-mode-desync`。

### 2026-08-22 window_bridge 桥接层重构完成（独立重构任务，非 GSD phase）

- **范围**: 用户直接任务（非 GSD 工作流）— 在保留 `window_manager: ^0.5.2` 平台层前提下全面重构 `lib/kernel/window_Bridge/` → `lib/kernel/window_bridge/`，行为零改变。
- **8 个 commit 全部落盘**（分支 feat/v1.8-stability-polish-plan-02-02）:
  1. `52d5e3fb` 基线: window bridge 迁移（4 文件协调器架构替代已删 window_manager_service/ 670 行单文件）
  2. `05cad89e` windows runner 加固（CMP0175 + 简化 Win32Window）
  3. `e683ce85` misc（engine VideoCodecInfo / drop adaptive_theme / probe 扩展）
  4. `e2822631` 结构规范化: window_Bridge→window_bridge（两步 git mv）+ window_service_state.dart 288 行拆为 state + 3 协调器，主文件 barrel export
  5. `ec7711c1` 死代码: 删 WindowState 类 / syncFullscreenState 接口方法（协调器内部保留）/ FakeWindowService.showAfterFirstFrame / 薄重复测试×2; logBridge→_log
  6. `7dd73c82` 常量统一: window_persistence.dart 改用 window_constants.dart 单一来源
  7. `3480e29e` _updateOnUIThread 去重: 提取 window_ui_thread.dart 共享函数（warn 回调保留各日志前缀）
  8. `243a3e4a` 文档同步: CLAUDE.md + docs/ 6 文件路径更新，删 ADR003 失实 WindowState 描述
- **终验**: analyze 零问题；unit/kernel 118 测试全过；widget 全量 +408 -10 中 10 失败全部鉴别为预存（control_bar_rebuild_boundary_test 5 个基线对照同失败 + control_bar_test 4-5 个文件内共享状态污染，单独跑全过；两文件与 window 代码零 import 依赖）。
- **预存技术债登记**: control_bar_test.dart 整文件运行时 4-5 测试失败/未完成（共享状态污染 + 1 个 10 分钟超时），单独运行全过——与 window_bridge 无关，归属 widget 测试隔离性问题。
- **实机 smoke 待用户执行**: `flutter run -d windows` 验证 几何恢复/resize 防抖(500ms)/最大化/置顶/全屏进出(F/双击)/关闭落盘。

## Operator Next Steps

- 下一窗口:实施需求1治本方案 A(window_service.setMode 实现 + _fullscreenIntent 守卫 + onToggleFullscreen 改走 windowService)+ 需求5手动复现定位。需 Windows GUI 手动验证。
- Start the next milestone with /gsd-new-milestone
