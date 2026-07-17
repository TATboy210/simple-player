# Phase 16: 兼容适配层骨架 + DiagnosticsBundle - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

建立 Strangler Fig 接缝 —— `KernelAdapter implements MediaEngine` 100% 路由到旧 `FvpEngine` 且零行为变更（全测试绿，cutover 未发生仅 seam 就位），`DiagnosticsBundle` 载体骨架就位（4 slot noop 默认），让后续每个诊断能力（P17 logger / P18 error / P19 memory）与新引擎（P20 NewFvpEngine）都有地方住、有路由可用。

**本 phase 不交付**：新引擎（P20）、诊断实例接线（P17-19）、cutover（P20）、适配层收拢（P21）。P16 只交付**接缝 + 载体骨架**，是刻意 dead code 直到 P20。

**硬约束贯穿**：
- 约束 #6：适配层转发活动引擎持有的同一 `ValueNotifier` **实例**（不重新包装），否则 `ValueListenableBuilder` 监听器脱钩 → cutover 时 UI 静默冻结
- 约束 #8：过度工程化是项目宿敌（此前 27 文件 3500 行 / 19 变量管 1 bool / 双数据源）—— ADAPT-05 尺寸预算 + 适配层除 `KernelMode` + generation 计数器外无状态 + 须召 senior-architect/red-team 挑战范围蔓延
- 约束 #3：`openGeneration` 与状态机分离是同一正确性属性（"仅最新 open 的结果生效"）的两半，**P20 才统一**（STATE-02 OpenGenerationTracker），P16 不动旧引擎

</domain>

<decisions>
## Implementation Decisions

### Area 1: DiagnosticsBundle 形态 (D1-D11)

- **D1:** `DiagnosticsBundle` 载体形态 = `final class DiagnosticsBundle { 4 final slot 字段; const DiagnosticsBundle(...); const DiagnosticsBundle.noop() 工厂; void dispose() 级联释放 4 slot }`。class 支持 dispose、const noop 默认、final 防误继承。KISS + Dart 惯法。P17/P19 plug in 仅换 bundle 构造。
- **D2:** P16 bundle 4 slot 全 noop（纯骨架）。不碰 FvpEngine 内部 metrics/eventLog（留原处）；MemoryMonitor 静态单例不动（P19 才一等化）；KernelLogger noop。P20 NewFvpEngine 才真消费 bundle。核心理由 = branch-by-abstraction 标准节奏：先旁路建新路径（bundle），消费者迁移（P20），旧路径退役（P21）。
- **D3 (约束 from D2):** P16 bundle 是刻意 dead code —— 无消费者直到 P20。特性非浪费：接缝先于消费者落地，每 phase diff 单一职责；验收禁因没人用而顺手接现成实例。
- **D4 (约束 from D2):** 过渡期禁止新旧引擎共享诊断实例。P20 起 NewFvpEngine 用 bundle 内 metrics/eventLog，旧 FvpEngine 用自己的，两套并存至旧引擎退役。共享实例 = dispose 级联杀到对方仍在用的实例 = 所有权歧义。
- **D5:** P16 KernelLogger 骨架 = `abstract class KernelLogger { void trace/debug/info/warn/error/fatal(String msg, {Map<String,Object?>? context}); }` + `NullKernelLogger`（const、空方法体）。方法名对齐 `log*.w/i/e` 形状（LOG-04 P17 121 调用点迁移保留形状）。契约先于实现。核心理由：LOG-04 早已把自由收走 —— P16 定义签名不是发明契约是测绘已存在的隐式契约并显式化。错位在 P16 暴露好于在 121 调用点迁一半时暴露。
- **D6 (约束 from D5):** P16 交付物 = 契约 + 适配证明。签名定完后对 121 现有调用点做静态适配验证（不迁移，只验证每种调用形状能被新签名表达）。破例点：`error`/`fatal` 带 `error`/`stackTrace` 实参（`log*.e(msg,err,st)`）→ 若存在两方法签名扩展 `{Object? error, StackTrace? stackTrace}`，P16 基于调用点普查决定，不能留给 P17 迁移中途发现。
- **D7 (约束 from D5):** 契约边界到此为止 —— P16 只定义方法集 + 签名 + NullKernelLogger。不定义 LogLevel 枚举、sink 接口、脱敏 API、格式化（P17 实现内部，藏接口后）。抽象类里多一个成员 P17 实现自由就少一分。
- **D8 (约束 from D5):** 命名映射表锁定 `log*.t/d/i/w/e/f → trace/debug/info/warn/error/fatal` 写进规格，P17 迁移查表替换非逐点决策。
- **D9:** bundle 的 3 个现成组件 slot 类型策略 = 统一 4 新抽象接口。P16 为 4 组件各定义最小抽象接口（KernelLogger 已 D5，MemoryMonitor/Metrics/EventLog 同模式）+ 4 个 noop impl；现有 3 具体类不碰（P20 NewFvpEngine 才用 bundle 接口）；接口入 `lib/kernel/diagnostics/`，命名避开现有类名冲突。与 D2 不动现有 + D5 同构。
- **D10:** DiagnosticsBundle 所有权与装配 = `PlayerServices` 构造 + 必填注入 adapter。`PlayerServices.init()` 构造 `DiagnosticsBundle.noop()`，必填注入 `KernelAdapter`；`KernelAdapter` 持 bundle 字段（P16 unused，P20 用）；`bundle.dispose()` 由 `KernelAdapter.dispose()` 级联触发。单一拥有者 = adapter，与 Phase 15 D8 适配层 dispose 无条件转发一致。推论：P16 adapter 完全不碰 bundle（100% 路由旧引擎 logEngine/metrics/eventLog），bundle 字段存在但不读 —— 否则给 bundle 制造 P16 消费者违反 D3 dead code。P16 adapter 是纯路由层，P20 NewFvpEngine 才经 bundle 调诊断。
- **D11:** `lib/kernel/diagnostics/` 目录组织 = 按组件分组（5 文件）：`kernel_logger.dart`（abstract + NullKernelLogger）+ `memory_monitor_slot.dart` + `metrics_slot.dart` + `event_log_slot.dart` + `diagnostics_bundle.dart`。每文件接口 + 其 noop impl（约 40-60 行），平衡 #8 与内聚。

### Area 2: Adapter 构造签名 + DelegationPolicy 粒度 (D12-D19)

- **D12:** `KernelAdapter` 构造签名 = 两槽 `KernelAdapter({required MediaEngine legacy, required MediaEngine migrated, required DelegationPolicy policy})`。前瞻 P20 逐能力翻转，P16 两槽传同一 old 引用。匹配 sc2 `KernelAdapter(old, old, policyAllOld)` 字面。P20 仅改装配点一行换 migrated→NewFvpEngine，adapter 内部签名不变。附注：两 ref 是注入依赖（同 D10 bundle ref），非 #8 所禁的可变 state —— #8 禁可变运行时 state，不禁 final 注入依赖。
- **D13:** P16 migrated 槽 = 同一 old 实例。`KernelAdapter(old, old, policy: allOld)` 两参数传同一 FvpEngine 引用。零额外资源（无双 mdk.Player/texture/双 ValueNotifier 源）。P20 仅改一行把第二个 old 换 NewFvpEngine。鲁棒性红利：若 P16 policy 误路由到 migrated，仍调 old 无可观测 bug（比 null 抛错更安全）。语义诚实：P16 "将要被迁移的引擎" 本就是 old（NewFvpEngine 还不存在）。摒弃 null（冗余信号 + 永久 nullable 类型漂移）与第二 FvpEngine 实例（双资源 + D4 风险）。
- **D14:** `DelegationPolicy` 粒度 = per-capability struct。`final class DelegationPolicy { final KernelMode stateView/playback/tracks/subtitle/videoEffect/renderer/volume; const DelegationPolicy.all(KernelMode m): ... = m; }`，7 字段对齐 `MediaEngine` 7 接口复合体（`EngineStateView + PlaybackControl + TrackControl + SubtitleConfig + VideoEffectControl + RendererControl + VolumeControl`）。P16 持 `DelegationPolicy.all(KernelMode.legacy)`（7 字段全 legacy，dead shape 同 D3 接缝哲学）。P20 仅翻字段，adapter 内部签名 + 装配点不变。读 #8 "KernelMode" 为类型非计数（struct 全 KernelMode 类型字段，无其他 state 类型）。与 D2/D5/D9/D10 前瞻接缝哲学一致。#6 flag：stateView 字段翻面危险（notifier 脱钩），留 P20 planner 约束（D18 已锁不加额外 struct pin，D15 recreate 是 #6 结构保护）。
- **D15:** `DelegationPolicy` 字段可变性 = final + P20 cutover 重建 adapter。#8 合规（无运行时可变 state）。#6 合规：cutover = 装配点新建 adapter（新 final policy），新 adapter 转发新引擎 notifier，消费者 `ValueListenableBuilder` 随新 engine 引用重建重听（干净 notifier 交接，非脱钩）。P16 永不翻面（all-legacy，创建一次）。final 不阻止 P20 重建 adapter（新实例新 final policy）—— 不预导任何 P20 安全路径。代价：P20 cutover 须重注入消费者 engine 引用（`player_services.dart:55 late final MediaEngine engine` 须调为可重建）—— 但 P20 本就要重触装配点。摒弃 mutable（#8 state 张力 + #6 运行时翻面 notifier 脱钩 bug）。
- **D16:** P20 cutover 重建 adapter 时旧 adapter 处置 = 保留作 kill-switch。P20 cutover 新建 adapter，旧 all-legacy adapter 保留（不 dispose）作回退 kill-switch；`PlayerServices.engine` 指新 adapter，回退则指回旧 adapter；旧 adapter 持 legacy 引擎常活；P21 collapse（VERIFY-04 闸门满足）才 dispose 旧 adapter + legacy 引擎。与 VERIFY-04 "kill-switch 保留一个里程碑" 一致。细化 Phase 15 D8：`adapter.dispose()` 的"无条件转发"指 dispose 调用发生时无内部条件分支（D8 原意），而非"每次 cutover 都 dispose" —— cutover 期间旧 adapter 保留，dispose 仅在最终 collapse 触发。摒弃重建即 dispose（无回退路径 + 与 VERIFY-04 冲突）。
- **D17:** #8 "适配层除 KernelMode + generation 计数器外无状态" 的 state 口径 = 宽松读法。#8 "state" = 可变运行时状态；final 配置 + 注入依赖不计。`KernelMode` 字段（policy struct 7 final 字段）+ generation 计数器允许；engine/bundle refs 是注入依赖不计 state；adapter 无其他可变字段（无 `_isMigrating` bool、无缓存、无中间态）。读 "KernelMode" 为类型非计数。D12/D14/D10 全合规。#8 宿敌（19 变量管 1 bool / 双数据源）由可变运行时 state 产生，非 final 配置 + 依赖。此口径为 Area 4 尺寸测量奠基。摒弃严格读法（只允 1 KernelMode + 1 counter，与 D12/D14/D10 冲突须重审）。
- **D18:** stateView 字段是否需额外结构约束 = 不加约束，D15 recreate 已足。stateView 是普通 `KernelMode` 字段，D15 final+recreate 保证翻面只能经重建 adapter（消费者重听，#6 安全）。P20 可自由决定 partial cutover（stateView 留 legacy 翻控制能力）或 full cutover（stateView 同翻）。约束由 D15 结构保证（final 字段 → 不能原地翻 → 必重建 → #6 安全），非额外 struct pin。最简最灵活，与 STATE-06 逐能力翻需求兼容。摒弃 factory 约束 pin stateView（#8 过度工程化 + 限制 P20 partial cutover 灵活度 + 与 STATE-06 冲突；D15 已结构保护，额外 pin 冗余）。
- **D19:** adapter 文件组织 + 目录落点 = 单文件 `lib/kernel/adapter/kernel_adapter.dart`。新 `lib/kernel/adapter/` 目录，`KernelAdapter` + `DelegationPolicy` + `KernelMode` 三类型同文件。adapter 是 seam 非 engine，独立目录标示其临时性（迁移完收拢删除 per Out of Scope），区别于永久 `engine/` 层。三类型紧密相关单文件内聚，#8 KISS。与 D11（diagnostics 5 文件）对比：diagnostics 是 4 独立 slot + bundle 多组件载体故分文件；adapter 是单一路由概念故单文件。摒弃多文件分类型（仅 3 类型过度）与放 `engine/` 目录（模糊 seam 临时性）。

### Area 3: 统一 openGeneration P16 形态 (D20-D23)

- **D20:** P16 适配层对 openGeneration 持有形态 = 不持实例，读 ADAPT-04 "由适配层持有的统一计数器" 为前瞻契约占位（P20 才生效）。P16 适配层无 `_openGeneration` 字段、无 generation 代码；`open()` 100% 转发 `old.open()`，守卫全在旧引擎内部（`fvp_engine.dart:259 final gen = ++_openGeneration;` / `:267` / `:311` / `:320` 三处检查）。ADAPT-04 "由适配层持有" 的生效时机是 P20（migrated = NewFvpEngine + OpenGenerationTracker），P16 allOld 期是语义占位非运行时职责。与 D2/D3（bundle dead code）+ D5（签名先于实现）同构。无双活跃数据源（旧引擎是唯一活跃计数器）。#8 最小状态。P20 须把计数器从旧引擎移到 adapter（STATE-02 本就是 P20 职责）。摒弃持 noop 占位字段（字面双数据源 + 语义不诚实）与统一读 facade（须强转 FvpEngine 或改冻结接口，破坏约束）。
- **D21:** P16 adapter `open()` 转发的代码 + 注释形态 = 纯转发 + 类级集中 P20 迁移点清单。`Future<void> open(String path) => legacy.open(path);` + 通用契约注释（"转发至活动引擎，行为见 PlaybackControl.open 契约"），不提 generation（adapter 保持透明，不知道 legacy 内部 generation 机制）。但 adapter 类级 `///` 注释列"P20 待迁入适配层的职责"清单。契约占位集中（类级）非散落每方法，adapter.open() 保持透明，P20 planner 一处看全部迁移点，耦合面集中易删。摒弃方法级注释标 generation（adapter 耦合 legacy 实现细节）与只列 ROADMAP 指针（D21 集中清单价值空化）。
- **D22:** P16 "无双数据源"（ADAPT-04 sc4）验证口径 = 静态 grep 闸门（Area 4 闸门清单项）。`grep -r '_openGeneration' lib/kernel/adapter/` 须 0 命中（adapter 无计数器字段）+ `grep -r 'openGeneration' lib/kernel/adapter/` 仅类级注释命中（D21 迁移点清单）。结构属性验证，非运行时测试。与 Phase 17 LOG-01 "CI grep 闸门内核永不 import package:logger" 同模式（项目惯法）。轻量、CI 可自动化。摒弃靠审查不设闸门（ADAPT-04 sc4 是硬需求须有可重复验证手段）与契约测试跑 STATE-07 竞态（测错属性 + STATE-07 是 P20 职责）。
- **D23:** D21 类级迁移点清单内容范围 = 精确三项（均 adapter 类级职责）：(a) openGeneration 统一计数器从 legacy 迁入 adapter/tracker（STATE-02）、(b) DiagnosticsBundle 从 noop 激活（D3 dead code 转 live）、(c) DelegationPolicy 字段翻面（D14 allOld → 逐能力 migrated）。每项一行 + 引用 REQ-ID。最 KISS + 不耦合 P20 实现细节（STATE-02 怎么实现 tracker 是 P20 裁量，清单只说"要迁"不说"怎么迁"）+ D21 集中清单价值保 + P20 planner 一处看全部 adapter 迁移点。D16 dispose kill-switch / D15 engine 字段可重建不在清单（是装配点/PlayerServices 职责，非 adapter 类级）。摒弃五项扩展（含 D16/D15 混入非 adapter 职责，职责边界模糊）与只列 ROADMAP 指针（清单退化为指针）。

### Area 4: 验证 + 尺寸预算 + red-team (D24-D27)

- **D24:** P16 sc1 "既有全测试套件绿" 测试构成 = 三层。(1) 既有全测试套件绿（现有所有 `test/` 不动，验全链路隐含）；(2) Phase 15 契约测试对 adapter 跑（P15 D13 参数化 `accepts MediaEngine`，adapter 作为另一入参，验 7 接口转发保真显式）；(3) notifier 实例相等性 widget 测试（sc3 专项，验 #6 转发同一实例）。覆盖最全（隐含 + 显式 + 专项），P15 D13 参数化设计本就为多实现复用，adapter 是 P16 中间态实现。测试是验证手段非适配层状态，三层是 Phase 21 VERIFY 预演非过度（#8 不冲突）。摒弃两层无契约对 adapter（转发保真靠隐含，adapter 误路由某接口若该接口无 widget 测试调用则盲区）与一层既有绿即可（sc3 显式成功标准未满足）。
- **D25:** sc3 notifier 实例相等性 widget 测试形态 = 全 EngineStateView notifier + `same()` 身份验证。遍历 `EngineStateView` 所有 `ValueNotifier` 字段（state/position/duration/isSeeking/isBuffering/aspectRatio/lastError 等），每个 `expect(adapter.X, same(legacy.X))`。`same()` = identity 身份非值相等（sc3 字面"实例相等性"直译）。全字段避免遗漏（adapter 漏转发某 notifier `same()` 捕获），验 #6 对所有 notifier 成立，D15 结构保护下运行时验 P16 当前态转发保真。`EngineStateView` 仅 6-8 notifier，遍历成本极低。摒弃关键子集（state+position+lastError，其余漏转发盲区）与端到端验监听器不脱钩（偏离 sc3 字面 + 仅验监听器链路非实例身份，可作 same() 补充非替代）。
- **D26:** senior-architect/red-team 挑战时机 + 结论记哪 = PLAN 召 + VERIFY 比尺寸。PLAN 阶段（`gsd-plan-phase 16`）召 senior-architect/red-team 挑战 planner 产出的预测尺寸预算（预防，拦设计期过度）+ 结论记 `16-PLAN.md` "red-team 挑战"节；VERIFY 阶段（`gsd-verify 16`）不召 red-team，只比实现尺寸 vs 预算（偏差超阈才重召）。#8 精神（预防）对路，sc5 字面满足（PLAN 召一次并记录），VERIFY 轻量（比尺寸客观闸门，偏差超阈才升级重召）。实现期非尺寸范围蔓延（如多加无关方法）尺寸对比可能未捕获 → 靠预算明细约束（planner 预算须列文件级 LOC 估算，VERIFY 逐文件比）。摒弃两阶段都召（成本高，PLAN 预防已足 + VERIFY 尺寸对比是客观闸门）与只 VERIFY 跑（错过 PLAN 预防，#8 精神是设计期过度在实现前拦成本最低）。
- **D27:** ADAPT-05 尺寸预算 P16 口径 + 量法 + 闸门 = adapter（D19 单文件）+ diagnostics（D11 5 文件）6 文件合计 < 636 行 FvpEngine；量 `wc -l`（含注释空行，最简，CI 易自动化，与 D22 grep 闸门同轻量模式）；P18/P20 扩口径加 sealed 错误 + tracker，最终全口径仍 < 636。基线 `wc -l lib/kernel/engine/fvp_engine.dart = 636` 快照记 `16-PLAN.md`。闸门 = 静态脚本（wc 比较），偏差超阈 20% 重召 red-team（D26 衔接）。预算空间宽（636 上限，P16 估算 ~400 行：adapter ~150-250 + diagnostics ~230）。#8 KISS。DOC-01 双语注释含在行数但注释量可控 + planner 预算明细（每文件 LOC 估算）约束。摒弃 cloc 剔注释（工具复杂，P16 预算空间宽时 wc -l 足够）与分离 adapter vs diagnostics 双预算（维护复杂，#8 KISS 优先合并，adapter 单文件远 < 636 闸门不构成约束）。

### Carried Forward from Phase 15（承袭决策，不再问）

- **Phase 15 D1:** 契约权威落点 = 接口 `///` 双语注释（DOC-01 结构），不设独立 CONTRACT.md；adapter 实现冻结契约非猜测
- **Phase 15 D4:** 契约权威仅在接口 `///`；FvpEngine 旧 impl `///` 薄仅记实现特有副作用；NewFvpEngine（P20）继承同一契约
- **Phase 15 D8:** `dispose()` 任意态可达 + 终态不可逆 + double-dispose 幂等 no-op；适配层 `dispose()` 无条件转发 —— D16 细化："无条件转发"指 dispose 调用无内部条件分支，非每次 cutover 都 dispose；cutover 旧 adapter 保留作 kill-switch，dispose 仅最终 collapse
- **Phase 15 D9:** disposed 后 getter 返回安全默认（state→idle, position/duration→0, isSeeking/isBuffering→false）永不 throw；mutating 方法 no-op（P20 升级 Result.err）；旧 FvpEngine 已有 `if(_disposed) return` 守卫一致
- **Phase 15 D13:** 契约测试参数化 `accepts MediaEngine`，对真实 FvpEngine 跑（baseline 捕获），供 P21 NewFvpEngine 复用；FakeEngine 仅 widget 测试 —— D24 据此锁契约测试也对 adapter 跑
- **Phase 15 D14:** 契约测试按 ISP 接口分组（EngineStateView/PlaybackControl/TrackControl/SubtitleConfig/VideoEffectControl/RendererControl/VolumeControl）—— adapter implements MediaEngine 须全 7 组通过
- **Phase 15 D16:** Phase 15 契约测试 = baseline 捕获 FvpEngine 当前行为；lifecycle 新语义留 P20 清单不强测
- **Phase 15 D22:** codebase maps 是 v2.1 前陈旧快照，对 LIVE code + codegraph，不刷新；不扩 Phase 15 范围去刷新

### Claude's Discretion

用户在全部 4 区 27 问都选了具体选项（无 "Let Claude decide"）。以下属 planner / executor 实现裁量（非用户决策，Claude 按本 CONTEXT 约束自由实现）：

- adapter 内部 per-capability 路由实现风格（7 个 `_routeXxx` helper vs 通用 dispatch）—— 约束：须实现 MediaEngine 7 接口全成员，按 `DelegationPolicy` 字段路由 legacy/migrated
- 静态 grep 闸门脚本具体写法（D22）+ wc 比较脚本具体写法（D27）—— 约束：CI 可自动化，与 LOG-01 grep 闸门同模式
- red-team 挑战 checklist 具体内容（D26）—— 约束：挑战预测尺寸预算 + 范围蔓延，结论记 16-PLAN.md
- DiagnosticsBundle 4 slot 抽象接口的最小方法集（D9）—— 约束：对齐现有组件能力 + noop impl，命名避开现有类名冲突
- KernelLogger 签名是否扩展 `error`/`fatal` 带 `{Object? error, StackTrace? stackTrace}`（D6）—— 约束：基于 121 调用点普查决定，P16 须静态适配验证

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 路线图与需求（phase 级权威）
- `.planning/ROADMAP.md` §Phase 16 — Goal/Depends on Phase 15/Requirements ADAPT-01..05/Success Criteria 1-5/Blocking Constraints #6（转发 ValueNotifier 实例）+#8（过度工程化尺寸预算）
- `.planning/REQUIREMENTS.md` §ADAPT — ADAPT-01..05 原子需求 + Traceability 表；§STATE STATE-06（P20 逐能力翻转）约束 D14 per-capability struct；§VERIFY VERIFY-04（kill-switch 保留一个里程碑）约束 D16
- `.planning/.continue-here.md` — 8 blocking constraints；Phase 16 直接相关 #6（适配层转发 ValueNotifier 实例非重新包装）+#8（过度工程化是项目宿敌 → 须召 senior-architect/red-team 挑战范围蔓延）；#3（openGeneration P20 才统一）贯穿 Area 3
- `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md` — Phase 15 全部 23 决策（D1-D23）+ P20 Lifecycle-Gap 清单；承袭 D1/D4/D8/D9/D13/D14/D16/D22

### LIVE code（adapter 装配 + 接口契约 + 旧引擎基线）
- `lib/kernel/engine/media_engine.dart:24-32` — `MediaEngine` 是 7 接口复合体（`implements EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl`）；`KernelAdapter implements MediaEngine` 须实现全部 7 接口成员；per-capability 翻转机制 = adapter 对每个被提升方法按 policy 路由
- `lib/kernel/engine/fvp_engine.dart` — fvp 具体实现（adapter 包装对象；`_openGeneration@194` + dispose 守卫 `_disposed`；P16 不碰）；`FvpEngine implements MediaEngine, SubtitleConfig`（SubtitleConfig 冗余因 MediaEngine 已含）；FvpEngine 专属便利 getter（`trackControl`/`videoEffectControl`/`rendererControl`/`volumeControl`/`subtitleConfig` @ :206-218）不在 MediaEngine 上，活代码 0 处使用（见 Existing Code Insights.cast_audit）；**636 行 = ADAPT-05 尺寸预算基线上限（D27）**
- `lib/kernel/engine/playback_control.dart` — `PlaybackControl.open()` 已含完整 `requires:/ensures:/states:/modifies:/throws:` 标签（Phase 15 D2）；契约-实现落差（open from playing/paused, play from completed）已 inline 记为 P20 known gap
- `lib/kernel/player_services.dart:87` — `engine = FvpEngine()` 装配点（P16 在此原位装配 `KernelAdapter(old, old, policyAllOld)`）；字段 `late final MediaEngine engine`（:55，接口类型替换透明；D15 锁定 P20 须调为可重建）；engine 被 `PlaybackController`（:89）+ `VideoProcessingService`（:96）共享
- `lib/kernel/services/playback_controller.dart:62` — `final MediaEngine engine`（接口类型字段，adapter 替换无需改类型签名）；无 `as FvpEngine` 强转
- `lib/kernel/utils/memory_monitor.dart`（193 行）/ `lib/kernel/engine/engine_event_log.dart`（103 行）/ `lib/kernel/engine/engine_metrics.dart`（91 行）— v2.1 现有 diagnostics 候选，**P16 不碰**（D2 全 noop，P19/P20 才接现成）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **MediaEngine 7 接口复合体**（`media_engine.dart:24-32`）：adapter `implements MediaEngine` 须实现全 7 接口成员；per-capability 翻转机制机械可行（adapter 对每个被提升方法按 policy 路由 = STATE-06 逐能力翻转）
- **Phase 15 契约测试**（`test/contracts/playback_control_contract.dart` 等 7 组）：参数化 `accepts MediaEngine`，对真实 FvpEngine 跑（baseline 捕获）；P16 adapter 作为另一入参跑（D24 第二层），不需新建测试 harness
- **旧 FvpEngine generation 守卫闭环**（`fvp_engine.dart:259/267/311/320`）：`final gen = ++_openGeneration;` + 三处 `gen != _openGeneration` 检查 + finally 清 buffering —— P16 转发 `old.open()` 即继承此守卫，adapter 无需重写
- **PlaybackControl.open() 双语契约标签**（Phase 15 D2）：adapter `open()` override 继承契约，类级迁移清单（D21）引用此契约

### Established Patterns
- **ISP 接口分解**（v2.1 09）：EngineStateView + PlaybackControl + 4 能力接口 —— D14 per-capability struct 7 字段对齐此结构
- **ValueNotifier + ValueListenableBuilder 状态管理**：不改；#6 转发同一实例是此模式的生命线（D15 final+recreate 是结构保护）
- **openGeneration 计数器守卫**（v2.1）：替代 `_isOpening` bool，"仅最新 open 的结果生效" 正确性属性 —— D20 占位契约 + P20 STATE-02 OpenGenerationTracker 统一
- **静态 grep 闸门**（项目惯法，LOG-01 先例）：CI grep 验证结构属性 —— D22 双数据源闸门 + D27 wc 尺寸闸门同模式
- **sealed PlayerError**（v2.1）：`FileError`/`CodecError`/`PlaybackError`/`NetworkError`/`UnknownError` + 子枚举 code —— P18 扩展 ErrorContext，P16 不碰

### Integration Points
- **装配点 `player_services.dart:87`**：`engine = FvpEngine()` → P16 改为 `engine = KernelAdapter(old: fvp, migrated: fvp, policy: DelegationPolicy.all(KernelMode.legacy))`（D12/D13/D14）；`old`/`migrated` 传同一 FvpEngine 实例
- **消费者共享 `player_services.dart:89/96`**：`PlaybackController` + `VideoProcessingService` 须都收 adapter（路由到旧引擎）；接口类型 `MediaEngine` 替换透明（cast_audit 0 处强转）
- **bundle 注入 `PlayerServices.init()`**（D10）：构造 `DiagnosticsBundle.noop()` 必填注入 `KernelAdapter`；adapter 持 bundle 字段（P16 unused，P20 用）；`bundle.dispose()` 由 `adapter.dispose()` 级联
- **新目录 `lib/kernel/adapter/`**（D19）：标示 seam 临时性，迁移完收拢删除（P21 VERIFY-04 闸门）
- **新目录 `lib/kernel/diagnostics/`**（D11）：5 文件（kernel_logger + memory_monitor_slot + metrics_slot + event_log_slot + diagnostics_bundle），P17-19 逐步填充实现

### Cast Audit（关键 drop-in 透明性证据）
- `as FvpEngine` 强转 LIVE code **0 处**（grep 全仓）
- `engine.trackControl`/`videoEffectControl`/`rendererControl`/`volumeControl`/`subtitleConfig` 便利 getter 在 `lib/` 活代码 **0 处使用**（命中全在 `.planning/milestones/` v2.1 规划文档）
- 结论：`KernelAdapter implements MediaEngine` 是干净 drop-in 替换 —— 无强转会断、无便利 getter 调用会断，cutover 类型层面完全透明

</code_context>

<specifics>
## Specific Ideas

- **adapter 是 seam 非 layer**（D19 + Out of Scope）：独立 `lib/kernel/adapter/` 目录标示临时性，迁移完收拢删除（P21 VERIFY-04 闸门满足后）。勿化为常驻 god-adapter 层。
- **P16 全 noop 是 branch-by-abstraction 标准节奏**（D2/D3）：先旁路建新路径（bundle 载体），消费者迁移（P20 NewFvpEngine），旧路径退役（P21）。接缝先于消费者落地，每 phase diff 单一职责。验收禁因 bundle 没人用而顺手接现成实例（违反 D3）。
- **per-capability struct 读 #8 "KernelMode" 为类型非计数**（D14/D17）：struct 全 `KernelMode` 类型字段，无其他 state 类型；7 字段对齐 MediaEngine 7 接口复合体 = STATE-06 逐能力翻转的机械基础。
- **D15 final+recreate 是 #6 结构保护**：final 字段 → 不能原地翻 → 必重建 adapter → 新 notifier + 消费者重建重听 → #6 安全（非脱钩）。P16 永不翻面（all-legacy 创建一次），P20 cutover 才重建。
- **类级迁移点清单精确三项**（D21/D23）：openGeneration（STATE-02）+ bundle 激活（D3）+ policy 翻面（D14），每项一行 + REQ-ID 引用，不耦合 P20 实现细节。
- **尺寸预算基线 636 行**（D27）：旧 FvpEngine 实际 636 行（注意 v2.1 承袭锁定 <350 行，实际 636 行是 v2.1 遗留偏差，P16 用实际 636 做基线）；P16 6 文件估算 ~400 行，预算空间宽。

</specifics>

<deferred>
## Deferred Ideas

- **P20 partial cutover 一致性问题** — migrated 控制方法操作 migrated 内部 state，UI 听 legacy stateView notifier 的潜在不一致（open 路由 migrated 递增 migrated.gen，但 stateMachine 在 legacy → 守卫分裂）—— P20 STATE-06 planner 须解（STATE-06 锁定逐能力翻为迁移节奏，机械一致性留 P20）
- **P20 cutover 消费者重听触发机制** — `ValueNotifier<MediaEngine>` vs 重建 `PlayerServices` vs 显式 `swapEngine` —— P20 cutover 设计部分，P16 只锁 adapter final 不预导
- **`player_services.dart:55 late final MediaEngine engine` 调为可重建的具体形态** — P20 改（D15 已锁定 P20 须改，形态是 P20 裁量）
- **adapter 内部 per-capability 路由实现风格** — 7 个 `_routeXxx` helper vs 通用 dispatch —— planner 实现裁量
- **P18/P20 扩尺寸预算口径** — P16 口径 = adapter+diagnostics 6 文件 < 636（D27）；P18 加 sealed 错误、P20 加 tracker 后全口径仍须 < 636 —— P18/P20 planner 各自扩口径时核验
- **v2.1 遗留：FvpEngine 实际 636 行 vs 锁定 <350 行偏差** — v2.1 范围，P16 不展开（用实际 636 做基线）

### Reviewed Todos (not folded)

无 —— discuss-phase 起步时 `todo.match-phase 16` 无匹配，未审阅任何 todo。

</deferred>

---

*Phase: 16-兼容适配层骨架 + DiagnosticsBundle*
*Context gathered: 2026-07-17*
