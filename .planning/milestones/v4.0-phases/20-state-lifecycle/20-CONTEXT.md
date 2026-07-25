# Phase 20: 状态与生命周期重写 - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

在已就位的适配层（P16）与诊断能力（P17-P19）之上，重构 FvpEngine 实现 MediaEngine，重写状态机（lifecycle 加固 + openGeneration 统一 + 显式拒绝非法转换），按方法逐个翻转 DelegationPolicy 并每次跑完整测试套件，落地 mdk 回调封送与竞态防护。

**本 phase 不交付**: 适配层收拢（P21）、双语注释（P22）、新功能。P20 只交付 **引擎重构 + 状态机重写 + 方法级翻转 + 回调封送 + 竞态测试**。
</domain>

<decisions>
## Implementation Decisions

### Area 1: NewFvpEngine 架构 (D1-D5)

- **D1 — 构建方式：** 直接修改 `fvp_engine.dart`（非新建文件）。在现有文件内渐进替换实现，双轨期通过 DelegationPolicy 控制新旧路径切换。不创建 `new_fvp_engine.dart`。
- **D2 — 依赖注入：** FvpEngine 构造函数接收 `DiagnosticsBundle`，从中取 logger/metrics/eventLog/memoryMonitor。与 KernelAdapter 同模式（Phase 16 D10）。
- **D3 — Helper 复用策略：** 复用现有 FvpCallbackHandler、PositionPoller、VolumeController、TrackManager、SubtitleConfigurator、D3D11Configurator，但适配它们的接口（注入 logger、修改回调签名），使 helper 也受益于诊断能力。分两步：先让引擎跑通，再逐步改造 helper。
- **D4 — Result 类型：** 新建 `TransitionResult` 枚举 `{ ok, illegal, staleGeneration }`（非 sealed `Result<T>`）。`EngineStateMachine.transitionTo` 返回 `TransitionResult`，替代现有 `bool`。STATE-03 "Result.err + KernelLogger 警告" 通过枚举 + logger.warn 实现。简洁、类型安全、无新抽象层。
- **D5 — OpenGenerationTracker 集成：** 嵌入 `EngineStateMachine` 内部。状态机持有 generation 计数器，`transitionTo` 自动检查 generation。`openGeneration` 从 PlaybackNavigator 迁移到 tracker（单一真相源）。Navigator 通过 tracker 查询。

### Area 2: 生命周期状态机 (D6-D8)

- **D6 — LifecyclePhase 正交：** 新增独立 `LifecyclePhase { alive, disposing, disposed }`，与 `MediaState` 正交。状态机持有两个独立 ValueNotifier（`state` + `lifecyclePhase`）。Phase 15 BASE-03 裁决的 v3.0 lifecycle 态在此落地。
- **D7 — recover() 语义：** error → idle 直接重置。`recover()` 是显式方法调用，将 error 状态转为 idle，同时清理 lastError。不自动触发，由 UI 或服务层调用。简单明确。
- **D8 — 双重 dispose 安全：** `dispose()` 检查 `_disposed` bool 标志，第二次调用直接 return（静默返回）。已有模式，简单可靠。LifecyclePhase 同步更新为 `disposed`。

### Area 3: DelegationPolicy 翻转策略 (D9-D11)

- **D9 — 翻转粒度：** 按单个方法粒度翻转（非按 ISP 接口、非按子系统）。每个 MediaEngine 方法独立标记为 `legacy` 或 `migrated`。最细粒度控制，每次翻转影响最小。
- **D10 — 验证策略：** 每次方法翻转后跑完整测试套件（契约测试 + 集成测试 + widget 测试）。绿了才继续下一个方法。STATE-06 "每次翻转后 Phase 15 契约测试通过" 扩展为完整套件。
- **D11 — 翻转顺序：** 核心优先 — open() → play() → pause() → seek() → volume() → mute() → ... → 其他叶子方法。先验证最关键路径，建立信心后再翻转次要方法。

### Area 4: mdk 回调封送与竞态防护 (D12-D14)

- **D12 — 回调封送方式：** 所有 mdk 回调内的状态更新统一通过 `scheduleMicrotask` 封送到主 isolate。与 Phase 18 D9 错误封送同模式。统一策略，简单可靠。
- **D13 — 延迟范围：** 所有回调统一延迟（非仅触发 open 的回调）。避免判断哪些回调触发 open 的复杂性。scheduleMicrotask 开销极低。
- **D14 — 竞态测试场景：** 全覆盖 — open→open 快速连发、open→seek→open 交错、open→dispose 生命周期、open→play→pause→open 快速连发。断言最终状态仅匹配最后一次 open。STATE-07 字面满足。

### Carried Forward from Phase 15/16/17/18/19（承袭决策，不再问）

- **Phase 15 D1:** 契约权威在接口 `///` 双语注释
- **Phase 15 BASE-03:** 6 态状态机冻结基线 + v3.0 补 disposed/disposing/error-恢复（D6 落地）
- **Phase 16 D10:** DiagnosticsBundle 所有权 = PlayerServices 构造 + 必填注入（D2 同模式）
- **Phase 17 D1:** KernelLogger.I 静态访问器
- **Phase 17 D8:** error/fatal 扩展签名 `{Object? error, StackTrace? stackTrace}`
- **Phase 18 D9:** scheduleMicrotask 线程封送模式（D12 同模式）
- **Phase 18 D10:** 三步合一错误处理（构造 PlayerError → 赋值 lastError → logger 发射）
- **Phase 19 D4:** MemoryMonitor 由 DiagnosticsBundle 持有
- **Phase 19 D7:** 单例→实例迁移原子提交模式
- `ValueNotifier<PlayerError?>` 契约保留（EngineStateView.lastError 依赖不破坏）

### Claude's Discretion

用户在全部 4 区 13 问都选了具体选项（无 "You decide"）。以下属 planner / executor 实现裁量：

- `TransitionResult` 枚举的具体值命名（D4：`ok`/`illegal`/`staleGeneration`，planner 可调整）
- Helper 接口适配的具体签名变更（D3：planner 逐 helper 评估）
- 方法翻转的完整顺序列表（D11：核心优先已定，具体方法列表由 planner 从 MediaEngine 接口枚举）
- 竞态测试的具体 fakeAsync 实现（D14：planner 设计测试夹具）
- LifecyclePhase ValueNotifier 的 UI 消费点（D6：可能影响 dispose 时序，planner 评估）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 路线图与需求（phase 级权威）
- `.planning/ROADMAP.md` §Phase 20 — Goal/Depends on Phase 15-19/Requirements STATE-01..07/Success Criteria 1-5/Blocking Constraints #3（openGeneration 统一）+#4（静默忽略替换）
- `.planning/REQUIREMENTS.md` §STATE — STATE-01..07 原子需求 + Traceability 表
- `.planning/.continue-here.md` — 8 blocking constraints；Phase 20 直接相关 #3（openGeneration 与状态机分离）+#4（EngineStateMachine 静默忽略非法转换）

### Phase 15-19 诊断基础设施与契约
- `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md` — D1（契约在接口）/BASE-03（6 态 + lifecycle 态裁决）
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` — D10（bundle 所有权）/D5（KernelLogger 签名）
- `.planning/phases/17-kernellogger/17-CONTEXT.md` — D1（KernelLogger.I）/D8（error/fatal 扩展签名）
- `.planning/phases/18-sealed/18-CONTEXT.md` — D9（scheduleMicrotask 封送）/D10（三步合一错误处理）
- `.planning/phases/19-memorymonitor/19-CONTEXT.md` — D4（bundle 持有 monitor）/D7（原子迁移模式）

### LIVE code（重构对象）
- `lib/kernel/engine/fvp_engine.dart` — 现有引擎实现（P20 直接修改对象）
- `lib/kernel/engine/engine_state_machine.dart` — 现有 6 态状态机（P20 扩展 lifecycle + generation）
- `lib/kernel/engine/media_engine.dart` — 组合接口（P20 翻转目标）
- `lib/kernel/engine/fvp_callback_handler.dart` — mdk 回调处理（P20 封送改造）
- `lib/kernel/engine/media_opener.dart` — 文件打开逻辑（P20 open 路径重构）
- `lib/kernel/services/playback_navigator.dart` — openGeneration 持有者（P20 迁移到 tracker）
- `lib/kernel/diagnostics/diagnostics_bundle.dart` — Bundle 载体（P20 注入引擎）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **EngineStateMachine**（`engine_state_machine.dart`）：现有 6 态 switch expression 穷举，P20 扩展 lifecycle + generation + TransitionResult
- **FvpCallbackHandler**（`fvp_callback_handler.dart`）：mdk 回调注册/映射，P20 加 scheduleMicrotask 封送
- **PositionPoller/VolumeController/TrackManager**：现有 helper，P20 适配接口注入 logger
- **DiagnosticsBundle**（P16 交付）：4 slot 载体，P20 注入 FvpEngine 构造函数
- **sealed PlayerError + ErrorContext**（P18 交付）：错误模型，P20 新引擎复用三步合一模式

### Established Patterns
- **scheduleMicrotask 线程封送**（P18 D9）：错误封送已用此模式，P20 扩展到所有回调
- **工厂构造函数**（FvpEngine 现有）：消除 late 初始化风险，P20 保持此模式
- **ValueNotifier + ValueListenableBuilder**（不改）：state/lifecyclePhase 双 notifier
- **Phase 15 契约测试**：接口级前置/后置条件测试，P20 每次翻转后跑

### Integration Points
- **FvpEngine 构造函数**：P20 在此注入 DiagnosticsBundle
- **EngineStateMachine.transitionTo**：P20 返回 TransitionResult 替代 bool
- **PlaybackNavigator.openGeneration**：P20 迁移到 OpenGenerationTracker
- **FvpCallbackHandler 回调入口**：P20 加 scheduleMicrotask 封装
- **PlayerServices 装配点**：P20 传递 bundle 到引擎

</code_context>

<specifics>
## Specific Ideas

- **直接修改 fvp_engine.dart**（D1）：用户明确选择不新建文件。渐进式重构，DelegationPolicy 控制新旧路径。双轨期旧代码仍在同一文件，通过标志切换。
- **核心优先翻转**（D11）：open() 是最关键路径（generation 守卫、状态转换、错误处理全汇聚于此），先翻转 open 建立信心。
- **所有回调统一延迟**（D13）：避免判断哪些回调触发 open 的复杂性。scheduleMicrotask 开销极低，统一延迟无性能影响。
- **TransitionResult 枚举**（D4）：比 sealed Result<T> 简单，比 bool 丰富。staleGeneration 值直接关联 STATE-02 的 generation 守卫。

</specifics>

<deferred>
## Deferred Ideas

- **P21 适配层收拢** — DelegationPolicy 全部翻转后，适配层删除闸门清单（100% 调用方迁移、对等通过、守卫已移入）
- **P21 双轨回归验证** — all-old vs all-new 输出一致，fakeAsync 验证
- **P22 双语注释** — P20 新增/修改的公开符号需双语注释（中文意图 + 英文契约）
- **Helper 逐步改造** — D3 "先跑通再改造"，helper 接口适配可能延后到 P21 或独立阶段
- **ERR-F01 Future** — openGeneration 关联、RetryPolicy 枚举（P20 generation 守卫已部分实现）

None of the deferred items block Phase 20. 所有延后项均有明确归属阶段。

</deferred>

---

*Phase: 20-状态与生命周期重写*
*Context gathered: 2026-07-20*
*Decisions captured: 14 (D1-D14) across 4 gray areas*
