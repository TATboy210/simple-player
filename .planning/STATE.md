---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: 窗口外观与全屏体验
status: planning
last_updated: "2026-09-01T14:45:36.908Z"
last_activity: 2026-09-01
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-30)

**Core value:** 出错可定位——任何错误发生时，无需接调试器即可知道错误在哪个文件哪一行、调用链是什么，一键复制或从日志文件回溯。
**Current focus:** Phase 5 — 端到端韧性验证

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-09-01 — Milestone v1.1 started

## Performance Metrics

**Velocity:**

- Total plans completed: 20
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 2 | 4 | - | - |
| 3 | 6 | - | - |
| 260901-eyw | 日志写入挪进独立 isolate 加心跳日志 | 2026-09-01 | 2cee141e | [260901-eyw-logging-isolate](./quick/260901-eyw-logging-isolate/) |
| 4 | 5 | - | - |
| 5 | 1 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: Not established

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02 P02-01 | 620 | 2 tasks | 6 files |
| Phase 02 P02-02 | 1123 | 2 tasks | 4 files |
| Phase 02 P02-03 | 773 | 2 tasks | 7 files |
| Phase 02 P02-04 | 870 | 2 tasks | 7 files |
| Phase 03 P03-01 | 45 | 2 tasks | 10 files |
| Phase 03 P03-02 | 25 | 2 tasks | 4 files |
| Phase 03 P03-03 | 34 | 2 tasks | 6 files |
| Phase 03 P03-04 | 4 | 3 tasks | 6 files |
| Phase 03 P03-05 | 920 | 3 tasks | 7 files |
| Phase 03 P03-06 | 3840 | 3 tasks | 11 files |
| Phase 04 P04-01 | 17min | 2 tasks | 5 files |
| Phase 04 P04-02 | 30min | 3 tasks | 11 files |
| Phase 04 P04-03 | 24min | 2 tasks | 2 files |
| Phase 04 P04-04 | 107min | 3 tasks | 9 files |
| Phase 04 P04-05 | 42min | 3 tasks | 15 files |
| Phase 05 P05-01 | 58min | 3 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting current work:

- [Phase 1]: Four capture sources share an immutable ErrorReport through one reentrancy-safe ErrorReporter.
- [Phase 2]: Error-only diagnostics use KernelLogger's facade with logger FileOutput and one append-only plain-text file.
- [Phase 3]: A persistent, non-modal top-left ErrorCard replaces the old ErrorBanner after equivalent PlayerError bridge coverage.
- [Phase 4]: Hiding cards must never disable capture or file logging.
- [Phase 02]: File evidence attaches only through ErrorReporter effects, not KernelLogger CompositeSink. — File evidence attaches only through ErrorReporter effects, not KernelLogger CompositeSink.
- [Phase 02]: Direct dart:io append+UTF-8+flush writes are serialized through a non-poisoning Future chain. — Direct dart:io append+UTF-8+flush writes are serialized through a non-poisoning Future chain.
- [Phase 02]: Formatter escapes all non-stack fields; raw stack is terminal and copied verbatim. — Formatter escapes all non-stack fields; raw stack is terminal and copied verbatim.
- [Phase 02]: D-05 location extraction accepts only exact package:simple_player_flutter frames; the first is primary and no more than two later project frames are retained. — D-05 location extraction accepts only exact package:simple_player_flutter frames; the first is primary and no more than two later project frames are retained.
- [Phase 02]: D-01 source I/O is limited to debug/profile after an owned diagnostics file frame establishes a trusted root; there is no cwd, executable-directory, or arbitrary-frame fallback. — D-01 source I/O is limited to debug/profile after an owned diagnostics file frame establishes a trusted root; there is no cwd, executable-directory, or arbitrary-frame fallback.
- [Phase 02]: Exact component-aware canonical containment, after pre-canonical traversal rejection, is required for every source path. — Exact component-aware canonical containment, after pre-canonical traversal rejection, is required for every source path.
- [Phase 02]: D-07 stores fullMediaPath and failedOpenPath separately; ordinary mediaPath remains basename-safe for presentation and existing effects. — D-07 stores fullMediaPath and failedOpenPath separately; ordinary mediaPath remains basename-safe for presentation and existing effects.
- [Phase 02]: D-05 enrichment uses the stored raw stack and completes before queue/effect fan-out; failures degrade to null location without dropping reports. — D-05 enrichment uses the stored raw stack and completes before queue/effect fan-out; failures degrade to null location without dropping reports.
- [Phase 02]: D-03 default location is exclusively getApplicationSupportDirectory()/logs/error.log; no cwd, executable, home, or last-known-good fallback exists. — D-03 default location is exclusively getApplicationSupportDirectory()/logs/error.log; no cwd, executable, home, or last-known-good fallback exists.
- [Phase 02]: D-08 production persistence remains an ErrorReporter effect, not a KernelLogger CompositeSink responsibility. — D-08 production persistence remains an ErrorReporter effect, not a KernelLogger CompositeSink responsibility.
- [Phase 02]: A stable unavailable delegating effect is constructed before hooks; successful activation changes only its internal writer and notifier values. — A stable unavailable delegating effect is constructed before hooks; successful activation changes only its internal writer and notifier values.
- [Phase 02]: Pending or failed activation never blocks MediaKit, window initialization, runApp, or the global capture chain. — Pending or failed activation never blocks MediaKit, window initialization, runApp, or the global capture chain.
- [Phase 3]: D-11 badge-cycling snapshot feeds from the existing reporter effects seam (ErrorCaptureSnapshot, UI-layer, bounded 20) because presentation only publishes the FIFO head — Plan assumption falsified by tests during 03-03 Task 2: _publishSafely exposes only queue.first, so D-01 newest-display and captured-count badge are unachievable via presentation notifications; the effects seam keeps kernel at zero changes with no new read-only API
- [Phase 3]: D-01 replacement semantics: the card always shows the newest captured error; manual close consumes the real FIFO head and removes it from the snapshot — Plan Task 2 RED mandates newest-on-card and older-first cycling; 03-02 FIFO-head display assertions were flipped accordingly
- [Phase 3]: MIG-01 收官：旧横幅在删前双路径等效证明（372b10a9）+ 用户批准后全量删除（0805618b）——错误展示收敛为 ErrorCard 单一路径；动作按钮按 D-09 不迁移；error_card.dart doc 字面量同步改写以满足 grep 门（Rule 3）
- [Phase 04]: D-02 修订落地:三层回退链(配置目录→exe根 logs/→Application Support logs/)取代 Phase-02 D-03 单一 AS 位置 — D-02 是对 Phase 2 单点位置函数的修订;回退链本身即 last-known-good(research OQ2),旧 AS 日志不迁移是一次性行为决策(零迁移代码)
- [Phase 04]: 设置存储放 UI 层单例 store(便携 settings.json + 注入文件 seam),kernel 编辑仅限 error_log_location.dart 三层链扩展;reporter/单写者语义零接触 — main.dart:20 导入 UI 层文件已有先例;kernel_logger_gate GATE 1/2 与 reporter/sink/deps 零 diff 验证通过;原子写走 tmp+rename 四级降级(research 实测 errno-5 瞬态)
- [Phase 04]: SET-01 呈现门控：ErrorCardHost.build 外层 ValueListenableBuilder 订阅 ErrorFeedbackSettings.I.state，off 同帧消失/on 恢复最新，_apply/_routeWarning 零改动 — 门控只影响渲染，捕获/快照/落盘链零接触（D-05 零 kernel 由 diff 面与 kernel gate 双重证明）；默认开语义由 store 损坏矩阵（04-01）+ host 回归锁用例双层锁定
- [Phase 4]: 04-04 设置 UI 收口:file_picker v11.0.3 无 WindowsOptions 类,getDirectoryPath(lockParentWindow) 为实际 v11 形态 — pub-cache 11.0.3 实源核查:无 WindowsOptions/无 windowsOptions 参数/顶层 lockParentWindow 无 @Deprecated;计划字面 API 无法编译,采用与 file_picker_adapters pickFiles 同参先例
- [Phase 4]: 04-04 UI 提交链单点化:行内校验后直接调用协调器 apply(),不做 validate→apply 双探测 — 同一可观察行为(校验中/三不/通过即保存换位),减半真实探测 I/O,消除校验与换位之间的中间窗口,T-04-04-01 单一校验实现对齐
- [Phase 4]: 04-04 widget 测试真实 I/O 协议:teardown 禁 await plain async fn(改 fire-and-forget dispose),body 禁 await 真实 I/O,等待条件锚定 effectiveLogPath 落点 — FakeAsync 微任务饥饿使 teardown 对 plain future 的 await 永不完成(10 分钟超时实证);dart:io 完成事件经真实事件循环派发故可完成;store 同步先置早于 swap 会造成条件早退竞态

### Pending Todos

None yet.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|

### Blockers/Concerns

- Phases 1–3 require brownfield investigation of startup lifecycle, existing KernelLogger, PlayerError ownership, root Stack, and legacy ErrorBanner before implementation.
- Phase 3 and Phase 5 require Windows manual smoke validation because widget tests cannot fully prove hit testing, drag, fullscreen, or media-key behavior.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Enhancement | Open-log-directory action, per-origin throttling, and in-app read-only log viewer | Deferred to v2 | 2026-08-28 | v2.1 |

## Session Continuity

Last session: 2026-09-01T12:17:05.435Z
Stopped at: Phase 5 complete — all phases complete
Resume file: None

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
