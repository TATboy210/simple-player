# Phase 15: 契约固化与基线盘点 - Context

**Gathered:** 2026-07-16
**Status:** Ready for planning

<domain>
## Phase Boundary

为 v3.0 兼容式重写固化**冻结的行为契约**与**迁移基线**：冻结 `MediaEngine`/`EngineStateView` 每个成员的行为契约规约（前置/后置/允许的 MediaState 转换/错误情形/被修改的 ValueNotifier），盘点静态调用点（`package:logger` 121 处/30 文件、`MemoryMonitor.start/snapshot` 2 处、`openGeneration` 引用）并以**可复现**形态产出，核对 9 态（PROJECT.md 陈旧）vs 6 态（`engine_state_machine.dart`）差异并裁决冻结基线 + v3.0 须补的 lifecycle 态，编写**针对接口（非实现）**的契约测试作为后续每次 capability 翻转的迁移闸门。

**本阶段产出的是契约与闸门，不重写引擎、不建适配层、不碰 UI。** Phase 15 是 v3.0 迁移链的闸门：契约冻结使 Phase 16 适配层"实现冻结契约而非猜测"，契约测试使 Phase 20 能按 DelegationPolicy 逐能力翻转并每次跑测试——无此先导，引擎替换退化为禁断的 big-bang swap（阻塞反模式）。

**成功标准映射**（ROADMAP sc1-4）：BASE-01（sc1 契约）、BASE-02（sc2 可复现盘点）、BASE-03（sc3 9v6 裁决 + lifecycle 清单）、BASE-04（sc4 契约测试通过旧引擎）。

</domain>

<decisions>
## Implementation Decisions

### 契约文档落点（BASE-01，4 项决策）
- **D1 — 契约权威落点：** 接口 `///` 双语注释（DOC-01 结构）为契约唯一权威落点；**不设独立 CONTRACT.md**。契约随接口冻结而自动冻结（v3.0 UI→Kernel 契约冻结），零漂移 SSOT；BASE-04 契约测试编码同一契约作可执行闸门，二者合满足"独立审查"；与 #8（过度工程化是项目宿敌）一致。
- **D2 — 契约标签集：** 扩展 DOC-01 标签集——新增 `requires:`（前置条件）/ `ensures:`（后置条件）/ `modifies:`（被修改的 ValueNotifier 列表）；`states:` 承载允许的 MediaState 转换；`throws:` 承载错误情形。BASE-01 第 4 要素"被修改的 ValueNotifier"在 DOC-01 原标签无自然归处；显式标签可 grep、Phase 22 lint 可校验 `modifies:` 存在；`requires`/`ensures` 直接对应 BASE-04 契约测试断言。
- **D3 — getter 契约粒度：** `EngineStateView` 12 个只读 getter **按组共享轻量契约**——接口顶部组契约（只读快照/幂等/永不 throw/永不改 state/Notifier），各 getter 一行 `///` 中文意图指回组契约。只读 getter 共享不变量类，逐个写完整契约为 #8 过度工程化；Dart 惯用法（Flutter List getter 同模式）；每个成员仍有书面契约（其指向的组契约）满足 BASE-01。
- **D4 — 实现契约策略：** 契约权威**仅在接口 `///`**；`FvpEngine`（旧实现）`///` 薄，仅记录实现特有副作用（mdk 回调时序、generation 守卫），**不重复契约**；冲突以接口为准。契约在接口是 Strangler Fig 闸门结构要求（`NewFvpEngine` 须继承同一契约）；实现 `///` 职责分流为"为什么这样做"；Phase 15 审计核对 `FvpEngine` 当前行为符合接口契约即可，无需在 impl 复述。

### 9v6 裁决 + 生命周期态（BASE-03 + 阻塞约束#2，8 项决策）
- **D5 — 生命周期态建模：** 独立 `LifecyclePhase { alive, disposing, disposed }` 枚举，与 6 态 `MediaState` 正交；disposed/disposing 走资源语义枚举；error-恢复 = error 态内 `recover()` 转换路径；双重 dispose 由 `LifecyclePhase=disposed` 守卫。播放语义（MediaState）与资源语义（lifecycle）正交分离，避免 UI 监听 MediaState 受 dispose 干扰；STATE-04 已锁 recover()；保持 6 态纯净。
- **D6 — 冻结范围：** 冻结**高层转换语义**——lifecycle 态清单 + D5 形状 + 每态声明式进入/退出语义（`disposed`=终态经 `dispose()` 进入、double-dispose 幂等 no-op；`recover()`=error→{idle,opening} 显式冻结）；**完整转换表留 Phase 20** 实现时定并回写契约。防分叉（满足 #2）且尊重 P15/P20 边界（P15 冻结契约，P20 设计转换表）；recover() 跨 error 边界且适配层 P16 需知，故显式冻结。
- **D7 — states 标签表示：** 每方法 `states:` 标签显式列入态/出态（`requires state ∈ {...}; transitions to {...}`）；与 `EngineStateMachine` 转换表的重复为**故意交叉校验**。契约自包含、BASE-04 测试可直接镜像断言；契约（调用方可依赖）vs 转换表（机器强制）两视图分叉即 bug 应捕获，DRY 反而消灭交叉校验。
- **D8 — dispose 契约：** `dispose()` 任意态可达 + 终态不可逆——可从 6 态 MediaState 任一 + 任意 LifecyclePhase 调用，转至 `disposed`；double-dispose 幂等 no-op；过渡 `alive→disposing→disposed`；调用者无需先 `stop()`/`pause()`。"双重 dispose 安全"最自然实现；调用者（窗口关闭/热重启）无需编排 stop→dispose，编排收回引擎内部；适配层 `dispose()` 无条件转发，最小化适配层复杂度。
- **D9 — disposed 后行为：** `disposed` 后 getter 返回**安全默认**（state→idle, position/duration→0, isSeeking/isBuffering→false）永不 throw；mutating 方法 **no-op**（P20 STATE-03 升级为 `Result.err`+KernelLogger 警告）；UI 收到最终 idle 后不再变。use-after-dispose 是 Flutter 常见 bug，getter 抛错会传染 UI 监听器；安全默认把"已销毁"变可安全观察稳态；state→idle 诚实（已不播放）；no-op 静默失败由 P20 加错误信号（与 #4 反模式锁定一致）。
- **D10 — error 陷阱态：** error 是陷阱态——引擎进入 error 后**不自动转出**，仅显式 `recover()` 或重新 `open()` 可出。可预测、可测；与 STATE-07 竞态测试"最终状态仅匹配最后一次 open"一致；自动恢复注入不可预测状态变化；适配层透传 error 无需预测自动恢复时序。
- **D11 — disposing 可见性：** disposing 对调用者**不可见**（同步瞬态）——`dispose()` 同步完成 alive→disposed，调用者只观察 disposed；LifecyclePhase 对外实质二稳态 {alive, disposed}；disposing 供状态机内部/测试断言。契约最简，调用者无中间态处理；同步 dispose 期间重入 double-dispose 直接命中幂等 no-op；异步 dispose 会使调用者须处理"正在销毁"中间态，复杂度外溢。
- **D12 — recover 可达性：** `recover()` 仅可从 error 调用，他态被拒（no-op，P20 升级 `Result.err`）；`transitions to {idle, opening}`（目标态 P20 定）。recover() 作为 error 专属出口与 D10 陷阱态协同（error 仅有 recover()/open() 两出口，recover 专管复位/重试，open 专管换媒体）；专一化=可测；任意态可调会与 stop() 重叠语义模糊。

### 契约测试策略（BASE-04，8 项决策）
- **D13 — 契约测试执行对象：** 对**真实 FvpEngine** 跑契约测试（验证旧实现符合冻结契约，满足 sc4）；测试**参数化 accepts MediaEngine** 供 Phase 21 对 NewFvpEngine 复用（VERIFY-01 闸门前提）；FakeEngine 保留 widget 测试用，**不扩展为契约驱动**。契约测试作为迁移闸门须验证"实现符合冻结契约"；FakeEngine 行为是测试自定义的，测 fake=测 mock，闸门弱；对真实行为跑才有闸门意义；参数化使 P21 同一套测试对 NewFvpEngine 跑即 VERIFY-01。
- **D14 — 契约测试组织：** **按 ISP 接口分组**——`EngineStateView`/`PlaybackControl`/`TrackControl`/`SubtitleConfig`/`VideoEffectControl`/`RendererControl` 各一组测试；与 D3 组契约同构；每组测试可独立审查（BASE-01 sc1）；迁移时按接口逐个验证。契约结构在哪组就测哪组；按方法分组与 D3 组契约脱节且 getter 单方法测试会与组契约重复；按契约要素分组跨方法难一眼审查单方法契约完整性。
- **D15 — 契约测试覆盖深度：** 首版覆盖优先 `states:` 入/出态断言 + `throws:` 错误情形（最高回归风险）；`ensures`/`modifies` 后置条件**次轮补**；与 D7 `states:` 标签镜像交叉校验；先立闸门骨架供 P20 capability 翻转时捕获回归。states+throws 覆盖最高回归风险先立骨架；全要素每方法工作量大且 modifies 须 D2 标签先落地才能断言；先 states 镜像跑通再扩，首版闸门偏窄。
- **D16 — 契约测试覆盖范围：** Phase 15 契约测试 = **baseline 捕获 FvpEngine 当前行为**（6 态转换 + 现有错误情形 + 现有 dispose），满足 sc4"通过旧引擎"；D5-D12 lifecycle 新语义记为 **P20 NewFvpEngine 须补清单**（BASE-03 sc3"须补生命周期态已列出"），Phase 15 不强测；与 D6"完整转换表留 P20"边界一致。lifecycle 新语义旧 FvpEngine 可能不符合（LifecyclePhase 是 v3.0 新增）；断言目标行为会让 FvpEngine fail 违反 sc4 且每次翻转一直红致闸门失效；baseline 捕获现有行为 + lifecycle 留 P20 清单尊重 P15/P20 边界。
- **D17 — 契约测试错误注入：** 错误注入 = **真实坏文件 fixture**（`test/fixtures/` 放损坏/不存在/不支持编码视频），真实触发 FvpEngine 错误路径；与 D13"真实 FvpEngine"一致、闸门强；需维护 fixture 集（坏文件、空文件、非视频文件、损坏 header）。真实坏文件最真实触发 FvpEngine 错误路径且与 D13 一致；FakeEngine 仅注入错误则 throws 闸门弱（测 mock）；混合两套注入机制须维护。
- **D18 — known gap 清单落点：** lifecycle 新语义 known gap 作为 **P20 衍生项记在 CONTEXT.md decisions/deferred**（或专门 lifecycle-gap 子节）；D5-D12 决策已在 decisions；SSOT，下游 gsd-planner 直接读 CONTEXT.md，无额外文件。CONTEXT.md SSOT 下游直接读；契约 `///` 就地标注分散难汇总审查且 P22 lint 须额外校验 TODO 闭环；独立 KNOWN-GAPS.md 与 CONTEXT.md 双源可能漂移。
- **D19 — 契约测试断言形式：** 断言 = **行为断言**（expect 方法调用后状态/错误）+ 从 `states:` 标签/转换表**派生参数化测试覆盖每条边**；三视图（契约标签→转换表→测试）分叉即 bug 捕获，与 D7 交叉校验机制化。行为断言+派生交叉使三视图分叉可捕获与 D7 机制化；仅直接断言行为与转换表/标签是两套表达交叉校验靠人工分叉风险高；转换表镜像生成纯副本无独立断言同源错误传播。
- **D20 — 契约测试时序边界：** Phase 15 契约测试**只测静态行为契约**（前置/后置/状态/错误）；时序/竞态（generation 守卫、open→seek→open、mdk 回调封送）**留 P20 STATE-05/07**；时序依赖 P20 `OpenGenerationTracker`，旧 FvpEngine 无此守卫测无意义。Phase 15 闸门=行为正确性；STATE-05/07 是 P20 REQ 依赖 NewFvpEngine `OpenGenerationTracker`（P20 才有）；对旧 FvpEngine 跑竞态测试无对应实现测不动；含基础时序对真实 FvpEngine mdk 回调时序敏感 flaky 风险高。

### 盘点工件 + 陈旧 maps（BASE-02，3 项决策）
- **D21 — 盘点产物形态：** 盘点 = **可重跑 grep 脚本 + 提交输出快照**。脚本读 LIVE code 满足 sc2"并可复现"；输出快照供下游 gsd-planner 直读 + 人类审查；数量漂移可在 P17 CI 闸门捕获。与 D1"避免第二真相源"同构（脚本读 LIVE code，非静态文档）。一次性人工 AUDIT.md 会随重构漂移、不满足"可复现"、与 LIVE code 形成双真相源。
- **D22 — 陈旧 codebase maps 处理：** `.planning/codebase/` 7 份 maps（2026-07-12 v2.1 重构前快照）每份**顶部加"v2.1 前快照"水印**；Phase 15+ 一律**对 LIVE code + codegraph**；**不扩 Phase 15 范围去刷新**（map 刷新是独立 `/gsd-map-codebase` 任务）；保留 v2.0/v2.1 演进历史。BASE-02 不含 map 刷新，故只标注不刷新；codegraph MCP 实时提供调用图/影响分析，削弱刷新静态 maps 的必要性。
- **D23 — 脚本生命周期与落点：** 脚本入仓库 **`tool/audit/`**（长期资产，设计为可演进成 P17 CI 闸门——同脚本加 `--enforce` flag 即变闸门，避免双脚本漂移）；输出快照入 **`.planning/phases/15-.../`**（阶段产物供下游读）。与 D1/D21"避免第二真相源"同构——脚本即工具进 `tool/` 可被多阶段复用，文档进 `.planning/` 随阶段归档。

### Claude's Discretion
本阶段无用户授权"You decide"项。全部 23 项决策均由用户在 4 区域单问题轮次中显式选定推荐项。下游 gsd-planner 在以下点有实现裁量空间（非本讨论范围）：契约测试 fixture 集具体文件清单、grep 脚本具体语法（ripgrep vs dart script）、`tool/audit/` 目录组织、CONTEXT.md 中 lifecycle-gap 子节是否独立。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 15 范围与契约（本阶段权威）
- `.planning/ROADMAP.md` §"Phase 15: 契约固化与基线盘点" — Goal/Depends on/Requirements BASE-01..04/Success Criteria 1-4/Blocking Constraint #2（9v6 矛盾）
- `.planning/REQUIREMENTS.md` §"BASE — 契约固化与基线盘点" — BASE-01..04 原子需求定义 + Traceability 表（40 REQ-ID 映射 Phase 15-22）
- `.planning/PROJECT.md` — Current Milestone v3.0、Constraints、Key Decisions、**注意含陈旧"9 态~40 边"描述须按 D5-D12 修正为"6 态正交 + LifecyclePhase"**
- `.planning/.continue-here.md` — 8 项 blocking constraints（Phase 15+ 须复核；**不可覆盖**）；Phase 15 直接相关：#2（9v6 矛盾）、#4（静默失败→P20）、#8（过度工程化）
- `.planning/phases/15-contract-freeze-baseline-audit/.continue-here.md` — Phase 15 专属 blocking 反模式三答（一次性 big-bang 替换内核的结构机制=Phase 15 契约冻结+契约测试）

### v2.1 已锁决策（承袭，不再问）
- `.planning/milestones/v3.0-phases/09-interface-decomposition/09-CONTEXT.md` — D-01..D-19（ISP 接口分解：EngineStateView + PlaybackControl + 4 能力接口；MediaState 正交拆分；PlayerError sealed + ValueNotifier<PlayerError?>；双语注释结构）
- `.planning/milestones/v3.0-phases/10-state-machine-extraction/10-CONTEXT.md` — D-01..D-12（状态机提取：6 态 MediaState 锁定、EngineStateMachine.transitionTo→bool、FvpEngine<350 行）

### 代码基线参考（注意陈旧性）
- `.planning/codebase/TESTING.md` — FakeEngine/手写 fake 模式（契约测试参考；**注意：codebase maps 是 v2.1 重构前陈旧快照，须对 LIVE code 验证**，按 D22 标注水印后使用）
- `.planning/codebase/CONCERNS.md` — 旧路径关注点（**陈旧 v2.1 前快照，谨慎**；按 D22 标注水印）

### LIVE code（契约冻结与盘点对象，须对实际文件做）
- `lib/kernel/engine/media_engine.dart` — 抽象引擎接口（D1-D4 契约权威落点；D3 EngineStateView 12 getter 组契约落点）
- `lib/kernel/engine/fvp_engine.dart` — fvp 具体实现（D4 实现 `///` 薄策略；含 openGeneration 引用 fvp_engine.dart:194 属 BASE-02 盘点对象）
- `lib/kernel/engine/engine_state_machine.dart` — 状态机（6 态锁定来源；transitionTo assert-only 忽略即 #4 反模式→P20 修）
- `lib/kernel/utils/memory_monitor.dart` — MemoryMonitor（BASE-02 盘点 2 处 start/snapshot 调用点之一，P19 一等化）
- `log.dart`（app 级，import package:logger + path_provider）— BASE-02 盘点 package:logger 121 处调用点之源；LOG-04 保留调用形状的迁移对象

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kernel/engine/open_result.dart` — sealed class 模式（复用于 PlayerError 结构化上下文，ERR-01 扩展参考）
- `lib/kernel/engine/media_state.dart` — `MediaStateTransition` switch expression（可迁移到 EngineStateMachine；6 态锁定基线）
- `FakeEngine`（`test/helpers/fake_engine.dart`）— call tracking + controllable failure（openCallCount/playCallCount/failNextOpenWith）；**保留 widget 测试用，不扩展为契约驱动**（D13）；契约测试对真实 FvpEngine 跑

### Established Patterns
- **Flutter Test + 手写 Fakes**（无 mockito/mocktail）— `createTestController()` wire FakeEngine；80% 覆盖率门槛；契约测试沿用此模式（D13/D17 真实 fixture 而非 mock）
- **ISP 接口分解**（09 D-01..D-06）— EngineStateView(12 只读 getter) + PlaybackControl + TrackControl/SubtitleConfig/VideoEffectControl/RendererControl；D3 组契约与 D14 测试分组均按此分解同构
- **双语注释结构**（DOC-01）— `///` 中文意图行 + 空行 + `///` 英文契约块；D1-D2 扩展标签集 `requires:/ensures:/modifies:/states:/throws:` 于此结构内
- **ValueNotifier + ValueListenableBuilder**（不改）— D9 安全默认契约须保证 disposed 后 notifier 不再变；P16 ADAPT-03 转发同一 notifier 实例依赖此

### Integration Points
- `app.dart` 组合根 — Phase 16 KernelAdapter 将在 FvpEngine 原位装配（Phase 15 不改，但契约须兼容此装配点）
- `lib/features/player/player_feature.dart` — PlayerServices 创建点（Phase 15 不改，盘点 openGeneration/logger 引用时触及）
- `lib/ui/player/player_screen.dart` — 通过 EngineStateView 读状态（Phase 15 不改；契约冻结须保证 UI 读取面不破坏）

### Critical Caveat（陈旧性）
`.planning/codebase/` 7 份 maps 是 **2026-07-12 v2.1 重构前快照**，描述已重构结构（EngineState god-mixin、features/player/services/）。Phase 15 基线盘点**必须对 LIVE code 做**，不能信这些 maps。按 D22 在每份顶部加"v2.1 前快照"水印后保留作历史参考。结构信息实时源 = codegraph MCP（CLAUDE.md 配置，调用图/影响分析）。

</code_context>

<specifics>
## Specific Ideas

- **契约标签 grep 化**：D2 的 `requires:/ensures:/modifies:/states:/throws:` 标签设计为可 grep，Phase 22 lint 可校验 `modifies:` 存在——契约既是人读文档也是机读契约，同一套标签同时服务审查与自动化闸门。
- **三视图交叉校验机制**：D7（states 标签）+ D6（转换表，P20）+ D19（契约测试）构成契约-转换表-测试三视图，分叉即 bug。DRY 在此是反模式——重复是故意的交叉校验。
- **baseline 闸门偏窄是特性**：D15/D16 首版只测 states+throws + baseline 捕获现有行为，lifecycle 新语义与时序留 P20——先立闸门骨架供 P20 capability 翻转时捕获回归，而非一次性写全覆盖测试拖慢闸门落地。
- **避免第二真相源主题三回响**：D1（契约在接口非 CONTRACT.md）、D21（盘点脚本读 LIVE 非静态文档）、D23（脚本演进成闸门避免双脚本漂移）——同一反模式意识在三个不同决策点一致应用。

</specifics>

<deferred>
## Deferred Ideas

- **recover() 目标态 idle vs opening** — Phase 20 STATE-04 定（D6/D12 已限定为 {idle, opening} 集合，P20 在集合内选最终态并回写契约）
- **lifecycle 完整转换表** — Phase 20 STATE-04 实现时定并回写契约（D6 边界：P15 只冻结高层语义）
- **PROJECT.md "9 态~40 边" 陈旧描述修正为"6 态正交 + LifecyclePhase"** — Phase 15 派生任务（文档修正，属 Phase 15 产物收尾）
- **`.planning/codebase/` maps 刷新** — 独立 `/gsd-map-codebase` 任务，**不在 Phase 15 范围**（D22：Phase 15 只标注水印不刷新）
- **契约测试 fixture 集完整清单** — gsd-planner 在实现时定具体坏文件/空文件/非视频/损坏 header 的 fixture 清单（D17 锁定形态=真实坏文件 fixture，清单是实现裁量）
- **Phase 17 LOG-01 CI grep 闸门与 Phase 15 盘点脚本的 `--enforce` 演进** — Phase 17 实现时定（D23 锁定同脚本演进策略，flag 具体语义是 P17 裁量）

None of the deferred items block Phase 15. 所有延后项均有明确归属阶段，已记录供对应阶段 gsd-planner/gsd-executor 直接消费。

</deferred>

---

## P20 Lifecycle-Gap 清单（D18）

Phase 15-02 执行时冻结的 9-vs-6 态裁决与 Phase 20 待补生命周期清单，记录于此供 Phase 20 gsd-planner/gsd-executor 直接消费。

**冻结裁决：** 冻结基线 = 6 态正交 MediaState + 正交 LifecyclePhase；9 态模型（PROJECT.md 陈旧）已退休（promote 非 add-alongside）。

**6 态正交 MediaState**（`engine_state_machine.dart` 现状，已冻结）：
- `idle` / `opening` / `playing` / `paused` / `completed` / `error`
- 转换表（`_canTransitionTo`）：
  - `idle → {opening, playing, error}`
  - `opening → {idle, playing, error}`
  - `playing → {paused, completed, error, idle}`
  - `paused → {playing, error, idle}`
  - `completed → {opening, error, idle}`
  - `error → {opening, idle}`（recover() 唯一出口，D6/D12 已限定，Phase 20 不可关闭此边）

**正交 LifecyclePhase（D5，尚未实现，Phase 20 待补）：**
- 目标形状：`LifecyclePhase { alive, disposing, disposed }`，与 6 态 MediaState 正交（D5）
- 当前基线现状：`FvpEngine` 仅用 `bool _disposed` 标志守卫（无枚举），`dispose()` 首行设 `_disposed = true`；`disposing` 中间态在当前实现中不可观察（同步完成，符合 D11 冻结的"disposing 对调用者不可见"语义，尽管尚未有显式枚举值）
- Phase 20 待补：
  1. 引入 `LifecyclePhase` 枚举替换 `bool _disposed`
  2. 完整转换表（`alive→disposing→disposed`，D6 留待 P20 定并回写契约）
  3. `recover()` 目标态在 `{idle, opening}` 集合内选定最终态（D6/D12 已限定集合）
  4. `dispose()` 契约的 double-dispose 幂等验证需覆盖枚举实现后的行为（D8 冻结的"double-dispose 幂等 no-op"语义不变，仅实现载体升级）
  5. disposed 后 mutating 方法从当前"静默 no-op"升级为 `Result.err` + KernelLogger 警告（D9 已冻结此升级路径）
  6. `recover()` 他态调用被拒的行为从当前实现（如有）升级为 `Result.err`（D12 已冻结此升级路径）

**本计划（15-02）执行时观察到的契约-实现落差**（非本计划修复范围，供 Phase 20/22 参考）：
- `open()` 从 `playing`/`paused` 源态调用时，`_canTransitionTo` 表未收录 `→opening` 边，`transitionTo` 静默失败但 `open()` 方法主体仍继续执行（详见 `playback_control.dart` open() 的 `states:` 标签注）
- `play()` 从 `completed` 源态调用时，`_canTransitionTo` 表未收录 `→playing` 边，同上静默失败模式（详见 `playback_control.dart` play() 的 `states:` 标签注）
- `VideoEffectControl.setAspectRatio()` 不写回 `EngineStateView.aspectRatio` ValueNotifier — 该 notifier 仅由 `open()` 成功时自动计算写入，调用方手动设置的宽高比对状态视图不可见（详见 `video_effect_control.dart` 的 `modifies:` 标签注）

---

*Phase: 15-contract-freeze-baseline-audit*
*Context gathered: 2026-07-16*
*Decisions captured: 23 (D1-D23) across 4 gray areas, resumed from checkpoint (20 decisions) + completed area 4 (3 decisions)*
*P20 Lifecycle-Gap 清单 appended: 15-02 execution (D18)*
