# Roadmap: Simple Player — 内核重写（兼容式替换与诊断内核）v3.0

**Created:** 2026-07-16
**Updated:** 2026-07-16 — v3.0 roadmap (8 phases, Phase 15-22 continuing numbering)
**Mode:** standard
**Granularity:** standard — *但 8 phases 是需求驱动的自然交付边界，未按 standard 默认 4-6 压缩（压缩会破坏诊断能力的依赖链）*

## Overview

v3.0 是对现有 working fvp/MDK-FFmpeg 内核的**兼容式重写**（Strangler Fig + Anti-Corruption Layer），**不是 greenfield**。在保持 UI→Kernel 契约（`MediaEngine`/`EngineStateView`/`PlaybackController` facade 形状）**冻结不变**的前提下，通过适配层逐步从 `OldFvpEngine` 切换到 `NewFvpEngine`，并将诊断能力（零依赖 `KernelLogger`、`MemoryMonitor`、sealed 错误模型）提升为内核一等公民。构建顺序由代码接地研究固化：**契约冻结 → 适配层 → 诊断(logger→error→memory) → 状态重写 → 验证收拢 → 双语文档**。适配层必须先于状态重写存在，否则替换引擎成禁断 big-bang swap。**零新增第三方运行时依赖**（`dart:*` stdlib + `package:flutter/foundation.dart` only）。

**Phase 编号约定：** 续编号。v2.1 止于 Phase 14（已归档到 `.planning/milestones/v3.0-phases/`，git rename 100%，历史连续，移动非删除）。v3.0 从 **Phase 15** 起续编号至 **Phase 22**（8 phases）。未传 `--reset-phase-numbers`，旧 phases 归档非删除。

## Milestones

<details>
<summary>✅ v2.0 沉浸式全屏重构 (Phases 1-8) - SHIPPED 2026-07-13</summary>

Fullscreen cleanup, WindowService simplification, immersive UI, test updates. Phase numbering 1-8.

</details>

<details>
<summary>✅ v2.1 播放内核重构强化 expanded (Phases 9-14) - SHIPPED 2026-07-15</summary>

引擎接口 ISP 分解 + 独立状态机 + StateMonitor 拆分（PlaybackStateManager + AutoAdvancePolicy）+ openGeneration 守卫 + Widget↔Kernel 边界优化。Phase 9-14 全部完成并归档。**v3.0 的重写基线与学习对象。**

</details>

<details>
<summary>✅ v3.0 内核重写（兼容式替换与诊断内核）(Phases 15-22) - SHIPPED 2026-07-20</summary>

兼容式替换 + 诊断内核一等化（KernelLogger/MemoryMonitor/sealed 错误）+ 双语文档。

</details>

### 🚧 v4.0 设置面板框架重构 (Phases 23-27 — Not Started)

**Milestone Goal:** 重建设置面板框架骨架，支持 D-pad/手柄/键鼠三模态交互，毛玻璃设计语言一致，先框架后功能。

**Target features (5):** Overlay Shell & State Model · Sidebar Navigation · Tab Content Framework · Gamepad & Keyboard Navigation · Responsive Scaling.

## Phases

**Phase Numbering:**

- Integer phases (15, 16, ...): Planned v3.0 milestone work (continuing from v2.1 Phase 14)
- Decimal phases (15.1, 15.2): Urgent insertions (marked with INSERTED), created via `/gsd-phase --insert`

- [x] **Phase 15: 契约固化与基线盘点** - 冻结 MediaEngine 行为契约规约，盘点静态调用点，核对 9 态 vs 6 态差异，编写接口级契约测试作为迁移闸门 (completed 2026-07-17)
- [x] **Phase 16: 兼容适配层骨架 + DiagnosticsBundle** - KernelAdapter 100% 路由旧引擎零行为变更，DiagnosticsBundle 载体骨架，单一 KernelMode 仲裁者，尺寸预算受控 (completed 2026-07-18)
- [x] **Phase 17: 零依赖 KernelLogger 门面（替换迁移）** - dart:developer 门面 + kDebugMode 门控，121 调用点替换迁移保留 log*.w() 形状，CI grep 闸门内核永不 import package:logger (completed 2026-07-20)
- [x] **Phase 18: Sealed 错误模型稳化** - 扩展现有 sealed PlayerError + ErrorContext + ErrorCode 注册表，引擎 catch 点结构化发射，UI 边界 ErrorView 翻译，跨 mdk 回调线程封送 (completed 2026-07-20)
- [x] **Phase 19: MemoryMonitor 一等化** - 实例化构造注入 RssProvider+Clock，start/stop/dispose 生命周期，单例→实例一个原子提交，纳入 DiagnosticsBundle，对播放业务零干扰 (completed 2026-07-20)
- [x] **Phase 20: 状态与生命周期重写** - NewFvpEngine 实现 MediaEngine，OpenGenerationTracker 统一守卫移入机器，Result.err 替换静默 assert 忽略，lifecycle 态加固，mdk 回调主线程封送，竞态测试 (completed 2026-07-20)
- [x] **Phase 21: 测试与迁移验证 + 适配层收拢** - 契约测试对 NewFvpEngine 通过，双轨回归套件差异为零，codegraph 推导迁移顺序，适配层删除闸门清单，--release 冒烟闸门，flutter analyze 严格干净 + 覆盖率≥80% (completed 2026-07-21)
- [x] **Phase 22: 双语 API 文档注释标准** - Phase 1 即约定结构（中文意图行 + 英文契约块），扫尾 lib/kernel/** v3.0 修改的公开符号，lint 校验双语注释 + KernelError 子类错误码 (completed 2026-07-21)

## Phase Details

### Phase 15: 契约固化与基线盘点

**Goal**: 为适配层与后续所有阶段固化稳定的行为契约与迁移基线，让适配层实现的是 frozen audited behavioral spec 而非 signature-level 猜测
**Depends on**: Nothing (first phase of v3.0)
**Requirements**: BASE-01, BASE-02, BASE-03, BASE-04
**Success Criteria** (what must be TRUE):

  1. 每个 `MediaEngine`/`EngineStateView` 成员都有书面行为契约（前置/后置条件、允许的 `MediaState` 转换、错误情形、被修改的 `ValueNotifier`），可作为迁移闸门被独立审查
  2. 静态调用点盘点完成并可复现 — `package:logger` 121 处/30 文件、`MemoryMonitor.start/snapshot` 2 处、`openGeneration` 引用全部定位且数量稳定
  3. 9 态（PROJECT.md）vs 6 态（`engine_state_machine.dart`）差异已核对并裁决 — 明确冻结基线是哪一方，v3.0 须补的生命周期态（disposed/disposing/error-恢复）已列出，适配层契约不再有分叉风险
  4. 针对接口（非实现）编写的契约测试存在且通过旧引擎，作为后续每次 capability 翻转的迁移闸门

**Blocking Constraints honored**:

  - **#2 (9 态 vs 6 态矛盾)** — BASE-03 必须核对决定冻结基线 + v3.0 须补的 lifecycle 态（disposed/disposing/error-恢复），再固化 BCS；未核对会让适配层契约分叉。

**Plans**: 3/3 plans executed
Plans:
**Wave 1**

- [x] 15-01-PLAN.md — BASE-02 可重跑审计脚本 + 快照 + 陈旧 maps 水印 + PROJECT.md 状态修正（Wave 1）
- [x] 15-02-PLAN.md — BASE-01/BASE-03 接口 /// 双语契约冻结 + 9v6 裁决 + LifecyclePhase 高层语义 + P20 lifecycle-gap 清单（Wave 1）

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 15-03-PLAN.md — BASE-04 7 组接口契约测试（参数化 accepts MediaEngine）+ 真实 FvpEngine 挂载点 + 坏文件 fixture + open→idle→play 回归闸门（Wave 2）

### Phase 16: 兼容适配层骨架 + DiagnosticsBundle

**Goal**: 建立 Strangler Fig 接缝 — KernelAdapter 100% 路由到旧引擎且零行为变更（全测试绿），DiagnosticsBundle 载体骨架就位，让后续每个诊断能力与新引擎都有地方住、有路由可用
**Depends on**: Phase 15
**Requirements**: ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-04, ADAPT-05
**Success Criteria** (what must be TRUE):

  1. `KernelAdapter implements MediaEngine` 100% 路由到旧引擎，既有全测试套件保持绿色，UI 行为零可观测变化（cutover 未发生，仅 seam 就位）
  2. `DiagnosticsBundle` 载体（`KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog`）含 `noop` 默认，构造注入，`app.dart` 组合根在 `FvpEngine` 原位装配 `KernelAdapter(old, old, policyAllOld)`
  3. 适配层转发活动引擎持有的**同一 `ValueNotifier` 实例**（不重新包装），既有 `ValueListenableBuilder` 监听器不脱钩 — 可用同一 widget 测试对 adapter 验证 notifier 实例相等性
  4. 单一 `KernelMode { legacy, migrated }` 仲裁者由适配层持有；`openGeneration` 统一计数器 P16 由旧引擎持有（适配层无 counter 字段，D20），P20 经 `OpenGenerationTracker` 迁入适配层/机器（STATE-02）；无双数据源（不存在两套 `MediaState`/`position`/`openGeneration` 流） — P16 经 D22 grep 闸门（`_openGeneration` 0 命中 `lib/kernel/adapter/`）验证
  5. 尺寸预算受控且已审计 — 适配层+门面+sealed 错误+tracker 合计 < 旧 `FvpEngine` 行数；适配层除 `KernelMode` + generation 计数器外无状态；已召 senior-architect / red-team 挑战范围蔓延并记录结论

**Blocking Constraints honored**:

  - **#6 (适配层转发 ValueNotifier 实例非重新包装)** — ADAPT-03 适配层返回活动引擎持有的同一 notifier 实例；重新包装会脱钩所有 ValueListenableBuilder 监听器 → cutover 时 UI 静默冻结。
  - **#8 (过度工程化是项目宿敌)** — ADAPT-05 尺寸预算：适配层+门面+sealed 错误+tracker 合计 < 旧 FvpEngine；适配层除 KernelMode + generation 计数器外无状态；Phase 2 须召 senior-architect/red-team 挑战范围蔓延。

**Plans**: 5/5 plans executed

- [x] 16-01-PLAN.md — KernelAdapter seam (single file per D19): 7-interface ternary dispatch, pure-forward open() (no counter, D20), DelegationPolicy + KernelMode, identity-preserving notifier forwarding, D21 class-level P20 migration checklist [wave 2]
- [x] 16-02-PLAN.md — DiagnosticsBundle + 5 diagnostics files: KernelLogger + 3 slots + bundle, all noop, const .noop() factory, cascading dispose [wave 1]
- [x] 16-03-PLAN.md — PlayerServices wiring: composition-root swap FvpEngine → KernelAdapter(old, old, policyAllOld, noop bundle) [wave 3]
- [x] 16-04-PLAN.md — Test suite (D24 three layers): contract mount (factory swap) + same() identity (13 notifiers) + diagnostics units + full-suite regression; no adapter-layer openGeneration test (D20/#8 KISS) [wave 3]
- [x] 16-05-PLAN.md — Static gates: D22 grep (`_openGeneration` 0 hits in lib/kernel/adapter/, `openGeneration` class-level doc-only) + D27 wc (6 files < 636) in tool/audit/phase16_gates.sh [wave 3]

### Phase 17: 零依赖 KernelLogger 门面（替换迁移）

**Goal**: 在 `lib/kernel/diagnostics/` 落地零依赖 KernelLogger 门面，替换内核对 `package:logger` 的依赖（保留 `log*.w()` 调用形状），让内核永不 import `package:logger` 且 release 构建零 debugPrint 泄漏
**Depends on**: Phase 16
**Requirements**: LOG-01, LOG-02, LOG-03, LOG-04, LOG-05
**Success Criteria** (what must be TRUE):

  1. `lib/kernel/diagnostics/` 内零依赖 `KernelLogger` 门面存在，以 `dart:developer` + 受控 `debugPrint` 实现；CI grep 闸门验证 `lib/kernel/**` 永不 import `package:logger`/`path_provider`
  2. 78 处内核调用点完成替换迁移（24 文件），`log*.w(...)`/`log.i(...)` 调用形状保留 — 仅改 import/声明即迁移，无逐点改写（注：121 为 Phase 15 全码基线含 app 级，内核范围 78）
  3. 发布门控生效 — `kDebugMode` 编译时剥离 `DebugPrintSink`，warn/error 走 `dart:developer.log`；release 构建产出零 `debugPrint`/debug/info 行（可由 `--release` 冒烟验证）
  4. 日志级别（trace/debug/info/warn/error/fatal）+ 结构化 `Map` 上下文 + 文件路径脱敏 + 稳定调用点 API 可用，app 级 `log.dart` 作为 `LogSink` 在 `app.dart` 注册（接线在内核之外）
  5. 可插拔 `LogSink`（`DevToolsSink`/`DebugPrintSink`/`NullSink`）可用，release 默认 `NullSink`，debug 默认 `DevToolsSink`

**Blocking Constraints honored**:

  - **#1 (logger 决策语义校正)** — 零依赖 = 内核解耦对 `package:logger` 的依赖（保留 `log*.w()` 调用形状的替换迁移），非"app 无 logger 包"。`log.dart` 已 import package:logger + path_provider，78 内核调用点/24 文件（Phase 16 researcher 实测）。LOG-04（保留调用形状）+ LOG-01（内核永不 import package:logger，CI grep 闸门）为硬要求；勿把 KernelLogger 当全新门面从零写。
  - **#7 (debugPrint 发布不剥离)** — debugPrint 在 release 仍在二进制中执行（throttled print）。零依赖门面须用 `kDebugMode` 门控，warn/error 走 `dart:developer.log`。LOG-03 + Phase 21 VERIFY-06（--release 冒烟闸门）。

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 17-01-PLAN.md — KernelLogger concrete implementation (LogLevel + LogSink + 3 sinks + KernelLoggerImpl) + PlayerServices wiring [wave 1]

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 17-02-PLAN.md — Batch-migrate 22 kernel files (78 call sites, import+declaration only) + CI grep gate script [wave 2]

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 17-03-PLAN.md — Extended behavioral tests for all sink types + full verification (gate + analyze + test suite) [wave 3]

### Phase 18: Sealed 错误模型稳化

**Goal**: 稳化并扩展现有 sealed `PlayerError`（非新建），让错误带结构化上下文端到端传播（引擎构造 → lastError 赋值 → logger 发射 → service 富化 → UI 翻译），且永不静默吞错、永不以原始 sealed 对象暴露给 UI
**Depends on**: Phase 17
**Requirements**: ERR-01, ERR-02, ERR-03, ERR-04, ERR-05
**Success Criteria** (what must be TRUE):

  1. 现有 sealed `PlayerError` 已扩展 `ErrorContext`（action/generation/path/timestamp/module）+ `ErrorCode` 注册表，`ValueNotifier<PlayerError?>` 契约保留（`FvpEngine.lastError` 与 `error_banner.dart` 依赖不破坏）
  2. 引擎每个 `on Exception catch` 点构造带上下文的 `PlayerError`、赋值 `lastError`、经 `bundle.logger.e` 发射；`PlaybackController._onError` 签名取 `PlayerError`，无裸 `catch (e)`、永不捕获 `Error` 子类
  3. 可恢复 vs 致命分裂根植于层级顶端，错误码冻结永不重命名
  4. UI 边界 `ErrorView` 翻译生效（字符串码 + 本地化消息 + 严重级），sealed `KernelError` 永不以原始 sealed 对象暴露给 UI
  5. 错误跨 mdk 回调线程封送 — 主线程重建 `PlayerError`，回调栈作为 `callbackStackTrace` 字段携带

**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 18-01-PLAN.md — Model layer: ErrorContext + isFatal + l10nKey + recoverable enums + ARB keys + model tests [wave 1]

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 18-02-PLAN.md — Engine catch points → three-step pattern + PlaybackController signature + callback marshalling [wave 2]
- [x] 18-03-PLAN.md — ErrorBanner l10nKey translation + widget tests [wave 2]

### Phase 19: MemoryMonitor 一等化

**Goal**: 把 `MemoryMonitor` 从静态单例重构为可注入、可关闭、不干扰播放业务状态的实例化诊断组件，纳入 `DiagnosticsBundle`，单例→实例迁移在一个原子提交内完成（永不跨提交拆分）
**Depends on**: Phase 16 (DiagnosticsBundle 载体)，受益于 Phase 17 (KernelLogger 集成)
**Requirements**: MEM-01, MEM-02, MEM-03, MEM-04, MEM-05
**Success Criteria** (what must be TRUE):

  1. `MemoryMonitor` 实例化（非静态单例），构造注入 `RssProvider`（默认 `ProcessInfo`）+ `Clock`，阈值/间隔/历史上限可配置，`FakeRssProvider` ~10 行用于测试（无 mocktail）
  2. `start`/`stop`/`dispose` 生命周期完整，可关闭（`NoopMemoryMonitor`/`disabled` 工厂），对播放业务状态零干扰 — 永不调用 `PlaybackController`、永不改 `MediaState`（这是定义性属性，可测）
  3. `ValueNotifier<MemorySnapshot?>` + `snapshot()`/`exportJson()` 保留，移至 `diagnostics/`，数据类拆至 `memory_snapshot.dart`
  4. 单例→实例迁移在**一个原子提交**内完成（瞬态静态桥 shim + 重写 2 处调用 `main.dart:16`/`debug_exporter.dart:57` + 删除 shim），git 历史无跨提交拆分
  5. `MemoryMonitor` 实例纳入 `DiagnosticsBundle`，与 `KernelLogger` 集成（替换直接 `debugPrint`）

**Blocking Constraints honored**:

  - **#5 (MemoryMonitor 单例→实例原子提交)** — 项目记忆 R2-5：删 `_instance` 但留静态方法致构建失败。MemoryMonitor 仅 2 静态调用（`main.dart:16`, `debug_exporter.dart:57`）。MEM-04 在一个原子提交内：瞬态静态桥 shim + 重写 2 调用 + 删 shim，**永不跨提交拆分**。

**Plans**: 2/2 plans executed

Plans:
**Wave 1**

- [x] 19-01-PLAN.md — Abstraction layer: RssProvider + Clock + data class extraction + instance-based MemoryMonitor implementation [wave 1]

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 19-02-PLAN.md — Atomic singleton→instance migration + DiagnosticsBundle wiring + KernelLogger integration [wave 2]

### Phase 20: 状态与生命周期重写

**Goal**: 在已就位的适配层与诊断能力之上，落地 `NewFvpEngine` 实现 `MediaEngine`，重写状态机（lifecycle 加固 + openGeneration 统一 + 显式拒绝非法转换），按能力逐个翻转 `DelegationPolicy` 并每次跑契约测试，让新引擎生于一等公民诊断内核而非重写两遍
**Depends on**: Phase 15, 16, 17, 18, 19
**Requirements**: STATE-01, STATE-02, STATE-03, STATE-04, STATE-05, STATE-06, STATE-07
**Success Criteria** (what must be TRUE):

  1. `new_fvp_engine.dart` 实现 `MediaEngine`，依赖 `DiagnosticsBundle`，发射 `PlayerError` + 上下文；`DelegationPolicy` 可按能力逐个翻转到新引擎，每次翻转后 Phase 15 契约测试通过
  2. `openGeneration` 经 `OpenGenerationTracker` 与状态机统一 — 守卫移入机器，`transitionTo` 原子拒绝过时 generation 的转换（同一正确性属性"仅最新 open 的结果生效"的两半合一）
  3. `EngineStateMachine` 静默 assert-only 忽略非法转换替换为 `Result.err` + `KernelLogger` 警告；穷举 `switch`（无 `default`），非法转换仅在文档化幂等 no-op 时静默
  4. 生命周期加固 — `disposed`/`disposing`/`error`-恢复态存在，显式 `recover()` 转换，双重 dispose 安全
  5. mdk 回调封送至主 isolate；监听器触发的 open 延迟至 `scheduleMicrotask`；竞态测试（open→seek→open 快速连发）断言最终状态仅匹配最后一次 open

**Blocking Constraints honored**:

  - **#3 (openGeneration 与状态机分离)** — `openGeneration` 在 `fvp_engine.dart:194`，与 `engine_state_machine.dart` 分离；两者是同一正确性属性（"仅最新 open 的结果生效"）的两半。STATE-02 须用 `OpenGenerationTracker` 统一，守卫移入机器，`transitionTo` 原子拒绝过时 generation。
  - **#4 (EngineStateMachine 静默忽略非法转换)** — `engine_state_machine.dart:52-58` 用 assert-only 静默忽略非法转换（release 无效），是项目记忆里的"静默失败"反模式。STATE-03 替换为 `Result.err` + `KernelLogger` 警告。

**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 20-01-PLAN.md — State machine rewrite: LifecyclePhase + TransitionResult + OpenGenerationTracker + recover() + double-dispose (STATE-02, STATE-03, STATE-04)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 20-02-PLAN.md — FvpEngine DiagnosticsBundle injection + lifecycle integration + per-method DelegationPolicy + PlayerServices wiring (STATE-01, STATE-02, STATE-04, STATE-06)
- [x] 20-03-PLAN.md — FvpCallbackHandler scheduleMicrotask marshalling + race condition tests (STATE-05, STATE-07)

### Phase 21: 测试与迁移验证 + 适配层收拢

**Goal**: 在 cutover 完成后验证新内核与旧内核行为一致（双轨差异为零），按依赖图推导迁移顺序，以显式删除闸门清单守护适配层收拢（独立提交，永不与 feature 捆绑），release 构建冒烟通过
**Depends on**: Phase 20
**Requirements**: VERIFY-01, VERIFY-02, VERIFY-03, VERIFY-04, VERIFY-05, VERIFY-06
**Success Criteria** (what must be TRUE):

  1. Phase 15 契约测试对 `NewFvpEngine` 通过
  2. 双轨回归套件 — 同一 widget 测试对 `KernelAdapter` all-old vs all-new 输出一致，时序敏感用例经 `fakeAsync` 验证差异为零
  3. 迁移顺序由依赖图（`codegraph`）推导：叶子 → 编排器 → 状态管理器 → UI 绑定
  4. 适配层删除闸门清单全部满足（100% 调用方迁移、对等通过、守卫已移入新引擎、回退路径已审计），收拢在**独立提交**内完成，适配层在删除前曾保留于 kill-switch 一个里程碑
  5. `flutter analyze` 严格干净；`kernel/` 覆盖率 ≥ 80%；`--release` 冒烟测试产出零 `debugPrint`/debug/info 行

**Blocking Constraints honored**:

  - **#7 的 release 闸门部分** — VERIFY-06 发布构建 CI 闸门：`--release` 冒烟测试产出零 `debugPrint`/debug/info 行（与 Phase 17 LOG-03 的 `kDebugMode` 门控配套验证）。

**Plans**: 12/12 plans executed

Plans:
**Wave 1** (parallel)

- [x] 21-01-PLAN.md — VERIFY-01: 契约测试挂载点验证 FvpEngine 契约（7 组 run*ContractTests 全 PASS）
- [x] 21-02-PLAN.md — VERIFY-02: 参数化双轨回归套件（RegressionFixture + DiffReport + 全方法覆盖 + fakeAsync）
- [x] 21-05-PLAN.md — VERIFY-03: codegraph 依赖图分析 + 迁移顺序文档（叶子→编排器→状态管理→UI 绑定）

**Wave 2** *(blocked on Wave 1)*

- [x] 21-03-PLAN.md — VERIFY-05/VERIFY-06: 修复 analyze errors + 清理 lib/kernel/ debugPrint + lint rule 防新增

**Wave 3** *(blocked on Wave 2, parallel)*

- [x] 21-04-PLAN.md — VERIFY-04/VERIFY-06: 适配层闸门脚本 + 回退脚本/文档 + release 冒烟脚本 + 删 adapter 测试
- [x] 21-06-PLAN.md — VERIFY-05/VERIFY-06: 最终验证（release 冒烟 + 契约 + 双轨回归 + 覆盖率 + analyze）

**Wave 4 — Gap Closure** *(parallel, blocked on Wave 3 verification)*

- [x] 21-07-PLAN.md — VERIFY-04: DelegationPolicy 翻转为 all-migrated（BLOCKER 1 修复：GATE 1 从 FAIL 变 PASS）
- [x] 21-08-PLAN.md — VERIFY-05: kernel/ 覆盖率提升（BLOCKER 2 修复：KernelAdapter + DelegationPolicy 单元测试）

**Wave 5 — Coverage Gap Closure** *(blocked on Wave 4)*

- [x] 21-09-PLAN.md — VERIFY-05: kernel/ 覆盖率提升 Wave 5（纯 Dart 模块扩展 + mdk.dll 瓶颈量化，目标 ≥70%）

**Wave 6 — Final Gap Closure** *(parallel, blocked on Wave 5)*

- [x] 21-10-PLAN.md — VERIFY-05: mdk.Player DI 注入 + 覆盖率实测（playerFactory + FakeMdkPlayer + FvpEngine open 测试）
- [x] 21-11-PLAN.md — VERIFY-01/VERIFY-02: SDK bug 修复 + 契约测试/双轨回归运行验证

**Wave 7 — Coverage Deep Dive** *(blocked on Wave 6)*

- [x] 21-12-PLAN.md — VERIFY-05: kernel/ 覆盖率深度提升（Tier 1 大文件深度测试 + Tier 2 薄测试扩展，目标 ≥80%）

### Phase 22: 双语 API 文档注释标准

**Goal**: 保证 v3.0 修改的每个公开符号同时含中文意图说明与英文契约说明，结构在 Phase 1 即约定使 Phase 17-20 代码双语编写，本阶段扫尾 lint 校验无遗漏
**Depends on**: 与 Phase 17-20 并行（结构 Phase 15 即约定），扫尾在 Phase 21 之后
**Requirements**: DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):

  1. 注释结构约定存在且已从 Phase 15 起执行 — `///` 意图行（中文）、空行、`///` 契约块（英文：params/returns/throws/states/invariants）；英文行为权威，中文"为何"权威
  2. `lib/kernel/**` 中 v3.0 修改的每个公开符号同时含中文意图 + 英文契约（lint/grep 校验通过）
  3. 每个 `KernelError` 子类附错误码 + 英文契约；既有中文-only 注释仅对重写触及的符号迁移（避免 scope creep）

**Plans**: 1/1 plans executed

- [x] 22-01-PLAN.md

### Phase 23: Overlay Shell & State Model

**Goal**: 绘制设置面板的覆盖层壳（毛玻璃 + 遮罩 + 标题栏），建立状态模型和控制器，实现打开/关闭/暂停/恢复的完整生命周期
**Depends on**: Nothing (first phase of v4.0)
**Requirements**: PANEL-01, PANEL-02, PANEL-03, PANEL-04, PANEL-05, PANEL-06, PANEL-07
**Success Criteria** (what must be TRUE):

  1. `SettingsPanelState` 含 3 个 ValueNotifier（isOpen/selectedTab/dragOffset），无其他状态管理框架
  2. `SettingsPanelController.open()` 暂停视频并记录 wasPlaying，`close()` 恢复先前状态
  3. 毛玻璃覆盖层居中显示，BackdropFilter + bgGlass + borderHighlight 匹配控制栏设计语言
  4. 标题栏可拖拽，拖拽范围限制在播放器窗口内
  5. 点击遮罩 / ESC / B 键均可关闭面板
  6. 面板基础尺寸 500×400，不超过窗口 80%
  7. 打开/关闭动画（Scale + Fade）流畅无卡顿

**Plans**: 2/2 plans executed
Plans:

**Wave 0**

- [x] 23-01-PLAN.md — Track AppleCurves, add playback facade controls, and establish testable settings state/controller lifecycle

**Wave 1** *(blocked on Wave 0)*

- [x] 23-02-PLAN.md — Mount and cut over the in-tree glass overlay shell with interaction-safety, drag, keyboard, and responsive-bound tests

### Phase 24: Sidebar Navigation

**Goal**: 在 Phase 23 壳内建立水平 tab bar 导航系统（Top/Middle/Bottom 三段式布局），支持点击/键盘方向键/手柄 LB/RB 切换 7 个 tab，IndexedStack + FadeTransition 200ms 动画过渡
**Depends on**: Phase 23
**Requirements**: SIDEBAR-01, SIDEBAR-02, SIDEBAR-03, SIDEBAR-04
**Success Criteria** (what must be TRUE):

  1. 水平 tab bar 固定 40px 高，7 个等宽 tab 项含 Material Icons + 文字标签（用户决定：Top/Middle/Bottom 三段式替代原 200px 垂直侧边栏）
  2. 7 个 tab 完整渲染（General/EQ/Audio/Video/Shortcuts/About/Performance）
  3. 选中态：accent 色背景 + 白色文字，未选中态：透明背景 + 次要文字色
  4. Tab 切换时内容区 TweenAnimationBuilder 200ms 淡入淡出，IndexedStack 保持所有 tab 存活
  5. ← → 方向键 + LB/RB 手柄键循环切换 tab（首尾循环），面板 Focus subtree 消费不冒泡

**Plans**: 2 plans
Plans:
- [ ] 24-01-PLAN.md — 水平 tab bar + IndexedStack + FadeTransition + click switching (Wave 1)
- [ ] 24-02-PLAN.md — 键盘 ← → + 手柄 LB/RB tab 切换 + 跨平台 gamepad 支持 (Wave 2)

### Phase 25: Tab Content Framework

**Goal**: 建立 tab 内容框架和通用设置项组件，实现 OK/Cancel/Apply 延迟应用模式
**Depends on**: Phase 24
**Requirements**: TABS-01, TABS-02, TABS-03, TABS-04
**Success Criteria** (what must be TRUE):

  1. 每个 tab 页独立 StatelessWidget，渲染 SettingRow 骨架列表（占位内容）
  2. SettingRow 支持 Switch/Slider/SpinControl/Dropdown 四种控件类型
  3. 内联描述文本在标签下方（灰色小字），不单独占行
  4. OK/Cancel/Apply 按钮栏固定在面板底部
  5. 延迟应用：更改存入 pending 状态，OK/Apply 提交，Cancel 恢复原始值

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 26: Gamepad & Keyboard Navigation

**Goal**: 实现 D-pad/手柄三模态导航，FocusTraversalGroup 分区管理，SpinControl 手柄友好组件
**Depends on**: Phase 25
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06
**Success Criteria** (what must be TRUE):

  1. 面板整体和侧边栏/内容区各包裹 FocusTraversalGroup
  2. 每个 SettingRow 有 FocusableActionDetector，焦点态高亮边框，hover 态背景变化
  3. SpinControl 组件：左右方向键循环选项值，显示当前值 + 箭头指示器
  4. D-pad ←→ 在 Switch/Slider/SpinControl 上调整值（Slider 步进 5%）
  5. A 键触发确认（Switch 切换、SpinControl 选择、Button 点击）
  6. B 键关闭面板（与 ESC 等效），焦点在控件上时先退回侧边栏

**Plans**: TBD (via `/gsd-plan-phase`)

### Phase 27: Responsive Scaling & Polish

**Goal**: 实现面板响应式缩放（全屏/小窗口适配），完善动画动效，集成测试覆盖关键路径
**Depends on**: Phase 26
**Requirements**: SCALE-01, SCALE-02, SCALE-03
**Success Criteria** (what must be TRUE):

  1. MediaQuery.size 检测窗口尺寸，面板按比例缩放
  2. 全屏模式：600×480（5:4 比例），侧边栏 200px
  3. 小窗口（<800px 宽）：400×320，侧边栏 160px
  4. 打开/关闭动画 Scale + Fade 流畅（60fps）
  5. 关键路径集成测试：打开/关闭/切换 tab/拖拽/键盘导航

**Plans**: TBD (via `/gsd-plan-phase`)

## Progress

**Execution Order:**
Phases execute in numeric order: 15 → ... → 22 → 23 → ... → 27

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 15. 契约固化与基线盘点 | v3.0 | 3/3 | Complete | 2026-07-17 |
| 16. 兼容适配层骨架 + DiagnosticsBundle | v3.0 | 5/5 | Complete | 2026-07-18 |
| 17. 零依赖 KernelLogger 门面 | v3.0 | 3/3 | Complete | 2026-07-20 |
| 18. Sealed 错误模型稳化 | v3.0 | 3/3 | Complete | 2026-07-20 |
| 19. MemoryMonitor 一等化 | v3.0 | 2/2 | Complete | 2026-07-20 |
| 20. 状态与生命周期重写 | v3.0 | 3/3 | Complete | 2026-07-20 |
| 21. 测试与迁移验证 + 适配层收拢 | v3.0 | 12/12 | Complete | 2026-07-21 |
| 22. 双语 API 文档注释标准 | v3.0 | 1/1 | Complete    | 2026-07-23 |
| 23. Overlay Shell & State Model | v4.0 | 2/2 | Complete    | 2026-07-23 |
| 24. Sidebar Navigation | v4.0 | 0/2 | Planning complete | - |
| 25. Tab Content Framework | v4.0 | 0/TBD | Not started | - |
| 26. Gamepad & Keyboard Navigation | v4.0 | 0/TBD | Not started | - |
| 27. Responsive Scaling & Polish | v4.0 | 0/TBD | Not started | - |

## Build Order Rationale

**v3.0（已完成）：**

- 契约冻结 → 适配层 → 诊断(logger→error→memory) → 状态重写 → 验证收拢 → 双语文档

**v4.0：**

- **壳先于内容（P23→P25）**：覆盖层壳 + 状态模型是所有后续组件的容器
- **侧边栏先于 tab 内容（P24→P25）**：tab 切换是内容渲染的前提
- **内容框架先于手柄导航（P25→P26）**：FocusTraversalGroup 需要已存在的 SettingRow 组件树
- **缩放在最后（P27）**：响应式缩放依赖完整的面板结构

---
*Roadmap updated: 2026-07-21 — v4.0 settings panel framework refactoring, 5 phases continuing from Phase 23*
