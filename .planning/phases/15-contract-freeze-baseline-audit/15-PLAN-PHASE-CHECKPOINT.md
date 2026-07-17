---
checkpoint: plan-phase-prespawn
phase: 15
phase_name: 契约固化与基线盘点
paused_at: 2026-07-17 pre-planner spawn (context budget 28%)
reason: 上下文 72% 已用；planner(Opus)→checker→revision→§13/§13a 覆盖闸门→§15 auto-advance 链是最重环节,超出 28% 安全余量。在干净检查点暂停。
resume_command: /gsd-plan-phase 15
---

# Plan-Phase 15 Pre-Spawn Checkpoint

## Resume 路径（无损）

`/clear` → `/gsd-plan-phase 15`。所有已完成验证均为确定性重跑,新会话几秒内补回:

- `init.plan-phase 15`: phase_status=Pending(非 Complete,closed-phase gate 跳过),has_research/has_context=true,has_plans=false,plan_count=0 → 直接进 §8 planner
- §4 CONTEXT.md: `15-CONTEXT.md` ✓ (23 decisions D1-D23)
- §5 research: 自动复用 `15-RESEARCH.md` ✓
- §5.5/§7.5 nyquist: `15-VALIDATION.md` ✓
- §5.6 UI gate: `check ui-plan-gate 15` → frontend=false → 跳过(Phase 15 纯 kernel 无 UI)
- §5.65 drift gate: `verify codebase-drift` → block:true 但 gate blocking:false(非阻塞),last_mapped_commit=null(从未映射),规划继续
- §7.8 pattern-mapper: activeHooks 含此 step,`15-PATTERNS.md` 缺失 → **需 spawn gsd-pattern-mapper**(planner 前置)
- §7.95 specless-probe: workflow.specless_probe_fallback 缺失=默认 ON,无 SPEC 文件 → **需跑 edge-probe** 注入 planner 的 `$COVERAGE`
- §13a decision gate: workflow.context_coverage_gate 缺失=启用,**阻塞式**验证 23 D-decision 全覆盖(exit 1 若遗漏)
- auto_advance=true → §15 规划通过后自动链入 execute-phase

## 唯一非显而易见判断(请传入 planner prompt)

`.planning/debug/` 两份诊断 stub(`video-playback-cannot-load.md`、`fvp-playback-history-regression.md`,均 `status: investigating`,root_cause/fix 仍空)+ 未提交改动 `lib/kernel/engine/media_opener.dart`/`lib/main.dart` 表明**用户正在经历"加载视频但无法播放"回归**。

这与 Phase 15"基线盘点"强相关:正在发生的播放回归恰好证明现有内核契约(open→play 路径)存在缺陷。

**planner 应把"加载→播放"路径的正确性断言纳入 must_haves.truths**,而非只做契约冻结的静态文档工作——让 Phase 15 的契约测试(BASE-04)显式覆盖 `open() 成功后必须能进入 play()` 这条当前正在回归的路径,使契约测试成为该回归的结构闸门。两份 debug 笔记是外部上下文信号,不是 Phase 15 产物;planner 引用其假设(fvp decoder API 误用、open-to-play 转换守卫)即可,不负责修复(那是后续 phase)。

## 子代理配置(init 已解析)

- researcher_model=sonnet / planner_model=opus / checker_model=sonnet
- granularity=standard / text_mode=false(可用 AskUserQuestion)
- commit_docs=true(§13d 提交 plans)
- phase_req_ids=BASE-01, BASE-02, BASE-03, BASE-04(4 个,§13 gate 必须全覆盖)

## 已就绪文件路径(resume 时传给子代理)

- state: `.planning/STATE.md`
- roadmap: `.planning/ROADMAP.md`
- requirements: `.planning/REQUIREMENTS.md`(BASE-01..04 text 在 §v1 Requirements/BASE 节)
- context: `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md`
- research: `.../15-RESEARCH.md`(含 Validation Architecture)
- validation: `.../15-VALIDATION.md`
- discussion-log: `.../15-DISCUSSION-LOG.md`
- 输出: `.../15-NN-PLAN.md`(planner 写盘)

## planner prompt 必含(除标准 files_to_read 外)

1. 上述"加载→播放"回归判断 → must_haves.truths
2. 23 个 D-decision 全覆盖硬约束(§13a 阻塞)
3. BASE-01..04 全覆盖(§13 gate)
4. edge-probe `$COVERAGE`(§7.95 产出)按 specless-probe-fallback.md §C lift 进 must_haves
5. contribution hooks: security threat_model / api-coverage(无外部 API,detector 判 false 跳过) / assumption-delta(advisory) / schema-gate(无 schema 跳过)
6. "Artifacts this phase produces" 节(必备)
