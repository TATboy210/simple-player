# Phase 16: 兼容适配层骨架 + DiagnosticsBundle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 16-兼容适配层骨架 + DiagnosticsBundle
**Areas discussed:** Area 1 (DiagnosticsBundle 形态), Area 2 (Adapter 构造签名 + DelegationPolicy 粒度), Area 3 (统一 openGeneration P16 形态), Area 4 (验证 + 尺寸预算 + red-team)

**Mode:** default（单问题轮次，每区 4-8 问 → Next area 检查）
**Discussion rhythm:** Area 1 6 轮 / Area 2 8 轮 / Area 3 4 轮 / Area 4 4 轮 = 27 项决策（D1-D27）

---

## Area 1: DiagnosticsBundle 形态 (D1-D11, 6 问)

### Q1.1 → D1: DiagnosticsBundle 载体形态

| Option | Description | Selected |
|--------|-------------|----------|
| class + const noop 工厂 | `final class DiagnosticsBundle { 4 final slot; const noop(); dispose() 级联 }` | ✓ |
| named record | Dart 3 record 形态 | |
| Let Claude decide | | |

**User's choice:** class + const noop 工厂
**Notes:** KISS + Dart 惯法 + D1 SSOT 一致。P17/P19 plug in 仅换 bundle 构造。

### Q1.2 → D2 (+D3, D4 约束): P16 bundle 4 slot 哪些接现成、哪些 noop

| Option | Description | Selected |
|--------|-------------|----------|
| 全 4 slot noop（纯骨架） | 不碰 FvpEngine 内部 metrics/eventLog；MemoryMonitor 静态单例不动；KernelLogger noop | ✓ |
| 抽 metrics+eventLog 接现成 | P16 同时建载体+抽实例 | |
| 接 3 现成 + 桥 MemoryMonitor | | |

**User's choice:** 全 4 slot noop
**Notes:** branch-by-abstraction 标准节奏：先旁路建新路径(bundle)，消费者迁移(P20)，旧路径退役(P21)。
- **D3 (约束①):** P16 bundle 刻意 dead code —— 无消费者直到 P20。验收禁因没人用而顺手接现成实例。
- **D4 (约束②):** 过渡期禁止新旧引擎共享诊断实例。dispose 级联杀到对方仍在用 = 所有权歧义。

### Q1.3 → D5 (+D6, D7, D8 约束): P16 KernelLogger 骨架定义到什么程度

| Option | Description | Selected |
|--------|-------------|----------|
| 6 级方法签名对齐 log*.w | `abstract class KernelLogger { trace/debug/info/warn/error/fatal }` + NullKernelLogger | ✓ |
| 裸标记接口（无方法） | | |
| Let Claude decide | | |

**User's choice:** 6 级方法签名对齐 log*.w
**Notes:** LOG-04 早已把自由收走 —— P16 定义签名是测绘已存在的隐式契约并显式化。错位在 P16 暴露好于在 121 调用点迁一半时暴露。
- **D6 (约束①):** P16 交付物=契约+适配证明。对 121 调用点静态适配验证。破例点：error/fatal 带 error/stackTrace 实参 → 签名扩展 `{Object? error, StackTrace? stackTrace}` 基于调用点普查决定。
- **D7 (约束②):** 契约边界到此为止 —— 不定义 LogLevel/sink/脱敏/格式化（P17 实现内部）。
- **D8 (约束③):** 命名映射表 `log*.t/d/i/w/e/f → trace/debug/info/warn/error/fatal` 锁定写进规格。

### Q1.4 → D9: bundle 的 3 个现成组件 slot 用什么类型策略

| Option | Description | Selected |
|--------|-------------|----------|
| 统一 4 新抽象接口 | P16 为 4 组件各定义最小抽象接口 + 4 noop impl；现有具体类不碰 | ✓ |
| 混合：新接口 + 现有类型 | | |
| Let Claude decide | | |

**User's choice:** 统一 4 新抽象接口
**Notes:** 与 D2 不动现有 + D5 同构。接口入 `lib/kernel/diagnostics/`，命名避开现有类名冲突。

### Q1.5 → D10: DiagnosticsBundle 所有权与装配

| Option | Description | Selected |
|--------|-------------|----------|
| PlayerServices 构造 + 必填注入 adapter | PlayerServices.init() 构造 DiagnosticsBundle.noop()，必填注入 KernelAdapter；adapter 持 bundle 字段 | ✓ |
| Adapter 内部默认 noop（可选注入） | | |
| PlayerServices 持有（与 adapter 平级） | | |

**User's choice:** PlayerServices 构造 + 必填注入 adapter
**Notes:** 单一拥有者=adapter，与 Phase 15 D8 适配层 dispose 无条件转发一致。P16 adapter 完全不碰 bundle（100% 路由旧引擎），bundle 字段存在但不读 —— 否则违反 D3 dead code。

### Q1.6 → D11: lib/kernel/diagnostics/ 目录怎么组织

| Option | Description | Selected |
|--------|-------------|----------|
| 一文件一接口+impl（9 文件） | | |
| 按组件分组（5 文件） | kernel_logger + memory_monitor_slot + metrics_slot + event_log_slot + diagnostics_bundle | ✓ |
| 集中（1-2 文件） | | |
| Let Claude decide | | |

**User's choice:** 按组件分组（5 文件）
**Notes:** 每文件接口+其 noop impl（约 40-60 行），平衡 #8 与内聚。

---

## Area 2: Adapter 构造签名 + DelegationPolicy 粒度 (D12-D19, 8 问)

### Q2.1 → D12: KernelAdapter 构造签名 — 两引擎槽还是单槽

| Option | Description | Selected |
|--------|-------------|----------|
| 两槽 legacy+migrated | `KernelAdapter({required legacy, required migrated, required policy})` | ✓ |
| 单槽 engine+mode | | |
| Let Claude decide | | |

**User's choice:** 两槽 legacy+migrated
**Notes:** P20 仅改装配点一行换 migrated→NewFvpEngine，adapter 内部签名不变。两 ref 是注入依赖，非 #8 所禁的可变 state。

### Q2.2 → D13: P16 时 migrated 槽填什么

| Option | Description | Selected |
|--------|-------------|----------|
| 同一 old 实例 | `KernelAdapter(old, old, allOld)` 两参数传同一 FvpEngine 引用 | ✓ |
| null (nullable 槽) | | |
| 第二个 FvpEngine 实例 | | |
| Let Claude decide | | |

**User's choice:** 同一 old 实例
**Notes:** 零额外资源。鲁棒性红利：误路由仍调 old 无 bug。语义诚实：P16 "将要被迁移的引擎" 本就是 old。

### Q2.3 → D14: DelegationPolicy 粒度 — 整机 KernelMode 枚举还是 per-capability struct

| Option | Description | Selected |
|--------|-------------|----------|
| 整机 KernelMode 枚举 | | |
| per-capability struct | 7 字段对齐 MediaEngine 7 接口复合体；P16 `DelegationPolicy.all(KernelMode.legacy)` | ✓ |
| Let Claude decide | | |

**User's choice:** per-capability struct
**Notes:** 读 #8 "KernelMode" 为类型非计数。#6 flag：stateView 字段翻面危险（notifier 脱钩），留 P20 planner 约束（D18/D15）。

### Q2.4 → D15: DelegationPolicy 字段可变性 — final 还是 mutable

| Option | Description | Selected |
|--------|-------------|----------|
| final + 重建 adapter | 构造注入不可变 + P20 cutover 重建 adapter | ✓ |
| mutable + 运行时翻 | | |
| Let Claude decide | | |

**User's choice:** final + 重建 adapter
**Notes:** #6 合规：recreate = 新 notifier + 消费者重建重听（干净交接非脱钩）。P16 永不翻面。P20 须调 `player_services.dart:55 late final` 为可重建。

### Q2.5 → D16: P20 cutover 重建 adapter 时旧 adapter 如何处置

| Option | Description | Selected |
|--------|-------------|----------|
| 保留旧 adapter 作 kill-switch | 旧 all-legacy adapter 保留不 dispose；P21 collapse 才 dispose | ✓ |
| 重建即 dispose 旧 adapter | | |
| Let Claude decide | | |

**User's choice:** 保留旧 adapter 作 kill-switch
**Notes:** 与 VERIFY-04 "kill-switch 保留一个里程碑" 一致。细化 Phase 15 D8："无条件转发"指 dispose 调用无内部条件分支，非每次 cutover 都 dispose。

### Q2.6 → D17: #8 "适配层除 KernelMode + generation 计数器外无状态" 的 state 口径

| Option | Description | Selected |
|--------|-------------|----------|
| 宽松：禁可变 state，配置/依赖不计 | state = 可变运行时状态；final 配置 + 注入依赖不计 | ✓ |
| 严格：禁所有字段除 1 KernelMode+1 counter | | |
| Let Claude decide | | |

**User's choice:** 宽松：禁可变 state，配置/依赖不计
**Notes:** 为 Area 4 尺寸测量奠基。读 "KernelMode" 为类型非计数。#8 宿敌由可变运行时 state 产生，非 final 配置 + 依赖。

### Q2.7 → D18: stateView 字段是否需额外结构约束

| Option | Description | Selected |
|--------|-------------|----------|
| 不加约束，D15 recreate 已足 | final 字段 → 不能原地翻 → 必重建 → #6 安全 | ✓ |
| 加 factory 约束 pin stateView | | |
| Let Claude decide | | |

**User's choice:** 不加约束，D15 recreate 已足
**Notes:** 最简最灵活，与 STATE-06 逐能力翻需求兼容。额外 pin 冗余 + 限制 P20 partial cutover 灵活度。

### Q2.8 → D19: adapter 文件组织 + 目录落点

| Option | Description | Selected |
|--------|-------------|----------|
| 单文件 adapter/kernel_adapter.dart | KernelAdapter + DelegationPolicy + KernelMode 三类型同文件 | ✓ |
| 多文件 adapter/ 分类型 | | |
| 单文件 engine/kernel_adapter.dart | | |
| Let Claude decide | | |

**User's choice:** 单文件 adapter/kernel_adapter.dart
**Notes:** 新 `adapter/` 目录标示 seam 临时性（迁移完收拢删除），区别于永久 `engine/` 层。三类型紧密相关单文件内聚。

---

## Area 3: 统一 openGeneration P16 形态 (D20-D23, 4 问)

### Q3.1 → D20: P16 时适配层对 openGeneration 持有什么形态

| Option | Description | Selected |
|--------|-------------|----------|
| 不持实例,读为前瞻契约占位(P20 才生效) | P16 无 _openGeneration 字段；open() 转发 old.open()，守卫全在旧引擎内部 | ✓ |
| 持计数器字段但 noop(占位字段,P20 激活) | | |
| 适配层做统一读 facade,现在指向 old 计数器 | 须强转 FvpEngine 或改冻结接口，破坏约束 | |

**User's choice:** 不持实例,读为前瞻契约占位
**Notes:** 与 D2/D3（bundle dead code）+ D5（签名先于实现）同构。无双活跃数据源。#8 最小状态。P20 须把计数器从旧引擎移到 adapter（STATE-02 职责）。

### Q3.2 → D21: P16 adapter open() 转发的代码 + 注释形态

| Option | Description | Selected |
|--------|-------------|----------|
| 纯转发 + 方法级注释标 generation 守卫归属 | | |
| 纯转发,无 generation 注释(adapter 全透明) | | |
| 纯转发 + 类级集中 P20 迁移点清单 | adapter.open() 透明 + 类级 /// 列 P20 待迁入职责 | ✓ |

**User's choice:** 纯转发 + 类级集中 P20 迁移点清单
**Notes:** 契约合占位集中（类级）非散落每方法，adapter.open() 保持透明，P20 planner 一处看全部迁移点，耦合面集中易删。

### Q3.3 → D22: P16 "无双数据源"(ADAPT-04 sc4) 的验证口径

| Option | Description | Selected |
|--------|-------------|----------|
| 静态 grep 闸门(Area 4 闸门清单项) | `grep _openGeneration lib/kernel/adapter/` 须 0 命中 + openGeneration 仅类级注释命中 | ✓ |
| 不额外验证,靠 D20+Area 4 red-team 审查 | | |
| 契约测试对 adapter 跑 STATE-07 竞态场景 | 测错属性 + STATE-07 是 P20 职责 | |

**User's choice:** 静态 grep 闸门
**Notes:** 与 Phase 17 LOG-01 "CI grep 闸门"同模式（项目惯法）。结构属性验证，非运行时测试。轻量、CI 可自动化。

### Q3.4 → D23: D21 类级迁移点清单的具体内容范围

| Option | Description | Selected |
|--------|-------------|----------|
| 精确三项(generation+bundle+policy) | (a) openGeneration STATE-02 (b) bundle 激活 D3 (c) policy 翻面 D14 | ✓ |
| 含五项扩展(三硬+D16 dispose+D15 engine 字段) | | |
| 只列 ROADMAP 指针,不重复迁移点内容 | | |

**User's choice:** 精确三项(generation+bundle+policy)
**Notes:** 每项一行 + 引用 REQ-ID。不耦合 P20 实现细节（清单只说"要迁"不说"怎么迁"）。D16/D15 非类级职责不入清单。

---

## Area 4: 验证 + 尺寸预算 + red-team (D24-D27, 4 问)

### Q4.1 → D24: sc1 "既有全测试套件绿" 的测试构成

| Option | Description | Selected |
|--------|-------------|----------|
| 三层全(既有绿+契约对 adapter+notifier 相等性) | 隐含+显式+专项 | ✓ |
| 两层(既有绿+notifier 相等性,契约不跑 adapter) | | |
| 一层(既有全测试绿即可) | sc3 显式成功标准未满足 | |

**User's choice:** 三层全
**Notes:** P15 D13 参数化设计本就为多实现复用，adapter 是 P16 中间态实现。测试是验证手段非适配层状态，三层是 Phase 21 VERIFY 预演非过度。

### Q4.2 → D25: sc3 notifier 实例相等性 widget 测试的具体形态

| Option | Description | Selected |
|--------|-------------|----------|
| 全 EngineStateView notifier + same() 身份验证 | 遍历所有 ValueNotifier 字段，每个 expect(adapter.X, same(legacy.X)) | ✓ |
| 关键子集(state+position+lastError) + same() | 其余漏转发盲区 | |
| 端到端验监听器不脱钩(非 same()) | 偏离 sc3 字面 | |

**User's choice:** 全 EngineStateView notifier + same() 身份验证
**Notes:** same() = identity 身份非值相等（sc3 字面"实例相等性"直译）。全字段避免遗漏。EngineStateView 仅 6-8 notifier 遍历成本极低。

### Q4.3 → D26: senior-architect/red-team 挑战何时跑 + 结论记哪

| Option | Description | Selected |
|--------|-------------|----------|
| 两阶段都跑(PLAN 挑战预测+VERIFY 挑战实现) | | |
| PLAN 召+VERIFY 比尺寸(不召,偏差超阈才重召) | PLAN 召挑战预测尺寸(预防)+VERIFY 比实现尺寸 vs 预算 | ✓ |
| 只 VERIFY 阶段跑(实现后一次性挑战) | 错过 PLAN 预防 | |

**User's choice:** PLAN 召+VERIFY 比尺寸
**Notes:** #8 精神（预防）对路。sc5 字面满足（PLAN 召一次并记录）。结论记 16-PLAN.md "red-team 挑战"节。VERIFY 偏差超阈 20% 才重召。

### Q4.4 → D27: ADAPT-05 尺寸预算的 P16 口径 + 量法 + 闸门形态

| Option | Description | Selected |
|--------|-------------|----------|
| adapter+diagnostics 6 文件 < 636, wc -l 含注释 | 最简，CI 易自动化，与 D22 grep 闸门同模式 | ✓ |
| adapter+diagnostics 6 文件, cloc 剔注释 | 公平对待双语注释但工具复杂 | |
| 仅 adapter < 636, diagnostics 单独子预算 | 双预算维护复杂 | |

**User's choice:** adapter+diagnostics 6 文件 < 636, wc -l 含注释
**Notes:** 基线 `wc -l fvp_engine.dart = 636` 快照记 16-PLAN.md。P18/P20 扩口径加 sealed 错误+tracker。预算空间宽（636 上限，P16 估算 ~400 行）。偏差超阈 20% 重召 red-team（D26 衔接）。

---

## Claude's Discretion

用户在全部 4 区 27 问都选了具体选项（无 "Let Claude decide"）。以下属 planner / executor 实现裁量（非用户决策）：

- adapter 内部 per-capability 路由实现风格（7 个 `_routeXxx` helper vs 通用 dispatch）
- 静态 grep 闸门脚本具体写法（D22）+ wc 比较脚本具体写法（D27）
- red-team 挑战 checklist 具体内容（D26）
- DiagnosticsBundle 4 slot 抽象接口的最小方法集（D9）
- KernelLogger 签名是否扩展 `error`/`fatal` 带 `{Object? error, StackTrace? stackTrace}`（D6）

## Deferred Ideas

- **P20 partial cutover 一致性问题** — migrated 控制方法操作 migrated 内部 state，UI 听 legacy stateView notifier 的潜在不一致（open 路由 migrated 递增 migrated.gen，但 stateMachine 在 legacy → 守卫分裂）—— P20 STATE-06 planner 须解
- **P20 cutover 消费者重听触发机制** — `ValueNotifier<MediaEngine>` vs 重建 `PlayerServices` vs 显式 `swapEngine` —— P20 cutover 设计部分，P16 只锁 adapter final 不预导
- **`player_services.dart:55 late final MediaEngine engine` 调为可重建的具体形态** — P20 改（D15 已锁定 P20 须改，形态是 P20 裁量）
- **adapter 内部 per-capability 路由实现风格** — 7 个 `_routeXxx` helper vs 通用 dispatch —— planner 实现裁量
- **P18/P20 扩尺寸预算口径** — P16 口径 = adapter+diagnostics 6 文件 < 636（D27）；P18 加 sealed 错误、P20 加 tracker 后全口径仍须 < 636 —— P18/P20 planner 各自扩口径时核验
- **v2.1 遗留：FvpEngine 实际 636 行 vs 锁定 <350 行偏差** — v2.1 范围，P16 不展开（用实际 636 做基线）
