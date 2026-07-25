# Phase 15: 契约固化与基线盘点 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-16
**Phase:** 15-contract-freeze-baseline-audit
**Areas discussed:** 契约文档落点, 9v6裁决+生命周期态, 契约测试策略, 盘点工件+陈旧maps
**Decisions captured:** 23 (D1-D23)
**Mode:** default (每区单问题轮次 → Next area 检查)

---

## Pre-discussion: Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| 契约文档落点 | BASE-01 行为契约写在哪：接口 /// 双语文档 vs 独立 CONTRACT.md/规约文档 | ✓ |
| 9v6裁决+生命周期态 | BASE-03 + 阻塞约束#2：6 态已锁但 PROJECT.md 仍写 9 态（陈旧）；disposed/disposing/error-恢复 建模；只列还是连转换语义冻结 | ✓ |
| 契约测试策略 | BASE-04：复用 FakeEngine vs 新 harness；按方法 vs 按接口；是否参数化供 Phase 21 复用 | ✓ |
| 盘点工件+陈旧maps | BASE-02：121 logger/MemoryMonitor 2 处/openGeneration 盘点产物形态；codebase maps 刷新还是标注 | ✓ |

**User's choice:** 全部 4 区
**Notes:** 用户选全部 4 区。已由 v2.1 锁定的决策不再问（6 态正交、ISP 接口分解、PlayerError sealed、transitionTo→bool、FvpEngine<350 行、双语注释结构）。会话跨 8 个上下文窗口续作完成（checkpoint 机制保障零损失恢复）。

---

## 契约文档落点 (BASE-01, 4 项决策 D1-D4)

### D1 — 契约权威落点

| Option | Description | Selected |
|--------|-------------|----------|
| 接口 /// 双语注释 (推荐) | DOC-01 结构：/// 中文意图 + 空行 + /// 英文契约块；契约随接口冻结而冻结 | ✓ |
| 独立 CONTRACT.md 规约 | 单独规约文档承载契约 | |
| 混合：/// 权威+汇总文档 | 接口 /// 为权威 + 独立汇总文档 | |

**User's choice:** 接口 /// 双语注释
**Notes:** 契约随接口冻结而自动冻结（v3.0 UI→Kernel 契约冻结）；零漂移 SSOT；BASE-04 契约测试编码同一契约作可执行闸门，二者合满足"独立审查"；与 #8（过度工程化）一致——不设第二真相源。

### D2 — 契约标签集

| Option | Description | Selected |
|--------|-------------|----------|
| 扩展标签集 (推荐) | 新增 requires:/ensures:/modifies:；states: 转换；throws: 错误 | ✓ |
| 复用现有标签 | DOC-01 原 params/returns/throws 不扩展 | |
| Claude 决定 | 延后至实现 | |

**User's choice:** 扩展标签集
**Notes:** BASE-01 第 4 要素"被修改的 ValueNotifier"在 DOC-01 原标签无自然归处；显式标签可 grep、Phase 22 lint 可校验 `modifies:` 存在；`requires`/`ensures` 直接对应 BASE-04 契约测试断言。

### D3 — getter 契约粒度

| Option | Description | Selected |
|--------|-------------|----------|
| 按组共享轻量契约 (推荐) | 接口顶部组契约 + 每 getter 一行中文意图指回组契约 | ✓ |
| 每个 getter 完整契约 | 12 只读 getter 各写完整 requires/ensures/states | |
| Claude 决定 | 延后 | |

**User's choice:** 按组共享轻量契约
**Notes:** 只读 getter 共享不变量类（只读快照/幂等/永不 throw/永不改 state/Notifier），逐个写完整契约为 #8 过度工程化；Dart 惯用法（Flutter List getter 同模式）；每个成员仍有书面契约（其指向的组契约）满足 BASE-01。

### D4 — 实现契约策略

| Option | Description | Selected |
|--------|-------------|----------|
| 仅接口契约；实现 /// 薄 (推荐) | FvpEngine /// 仅记实现特有副作用，不重复契约 | ✓ |
| 接口+实现双契约 | 实现也复述完整契约 | |
| Claude 决定 | 延后 | |

**User's choice:** 仅接口契约；实现 /// 薄
**Notes:** 契约在接口是 Strangler Fig 闸门结构要求（NewFvpEngine 须继承同一契约，否则迁移闸门失效）；实现 /// 职责分流为"为什么这样做"（mdk 回调时序、generation 守卫）；Phase 15 审计核对 FvpEngine 当前行为符合接口契约即可，无需在 impl 复述。

---

## 9v6裁决+生命周期态 (BASE-03 + 阻塞约束#2, 8 项决策 D5-D12)

### D5 — 生命周期态建模

| Option | Description | Selected |
|--------|-------------|----------|
| 独立 LifecyclePhase 枚举 (推荐) | {alive, disposing, disposed} 与 6 态 MediaState 正交 | ✓ |
| 扩展 MediaState 枚举 | 把 disposed/disposing 加进 MediaState | |
| 独立枚举+独立 RecoveryStatus | LifecyclePhase + RecoveryStatus 双枚举 | |

**User's choice:** 独立 LifecyclePhase 枚举
**Notes:** 播放语义（MediaState）与资源语义（lifecycle）正交分离，避免 UI 监听 MediaState 受 dispose 干扰；STATE-04 已锁 recover()；双重 dispose 由 LifecyclePhase=disposed 守卫；保持 6 态纯净。

### D6 — 冻结范围

| Option | Description | Selected |
|--------|-------------|----------|
| 冻结高层转换语义 (推荐) | 态清单+形状+声明式进入/退出+recover() 显式；完整转换表留 P20 | ✓ |
| 只列态清单+形状 | 仅列 lifecycle 态，不冻结转换语义 | |
| 冻结完整转换表 | P15 即定全部转换边 | |

**User's choice:** 冻结高层转换语义
**Notes:** 防分叉（满足 #2）且尊重 P15/P20 边界（P15 冻结契约，P20 设计转换表）；recover() 跨 error 边界且适配层 P16 需知，故显式冻结；完整转换表留 Phase 20 实现时定并回写契约。

### D7 — states 标签表示

| Option | Description | Selected |
|--------|-------------|----------|
| 每方法列入态/出态 (推荐) | `requires state ∈ {...}; transitions to {...}` | ✓ |
| 引用中央转换表 | states: 标签引用转换表条目 | |
| Claude 决定 | 延后 | |

**User's choice:** 每方法列入态/出态
**Notes:** 契约自包含、BASE-04 测试可直接镜像断言；与 EngineStateMachine 转换表的重复为**故意交叉校验**——契约（调用方可依赖）vs 转换表（机器强制）两视图分叉即 bug 应捕获，DRY 在此反会消灭交叉校验。

### D8 — dispose 契约

| Option | Description | Selected |
|--------|-------------|----------|
| 任意态可达+终态 (推荐) | 6 态任一 + 任意 LifecyclePhase 可调；double-dispose 幂等 no-op | ✓ |
| 仅 idle/error 可达 | dispose 前须先 stop/pause | |
| Claude 决定 | 延后 | |

**User's choice:** 任意态可达 + 终态
**Notes:** "双重 dispose 安全"最自然实现；过渡 alive→disposing→disposed；调用者（窗口关闭/热重启）无需编排 stop→dispose，编排收回引擎内部；适配层 dispose() 无条件转发，最小化适配层复杂度。

### D9 — disposed 后行为

| Option | Description | Selected |
|--------|-------------|----------|
| 安全默认+no-op (推荐) | getter 返回安全默认永不 throw；mutating no-op（P20 升级 Result.err） | ✓ |
| getter 抛 StateError | use-after-dispose 显式抛错 | |
| 返回最后快照 | getter 返回最后有效值 | |

**User's choice:** 安全默认 + no-op
**Notes:** use-after-dispose 是 Flutter 常见 bug，getter 抛错会传染 UI 监听器；安全默认（state→idle, pos/dur→0, isSeeking/isBuffering→false）把"已销毁"变可安全观察稳态；state→idle 诚实（已不播放）；no-op 静默失败由 P20 STATE-03 加错误信号（与 #4 反模式锁定一致）。

### D10 — error 陷阱态

| Option | Description | Selected |
|--------|-------------|----------|
| 陷阱态：仅显式可出 (推荐) | 进入 error 后不自动转出，仅 recover()/open() 可出 | ✓ |
| 允许自动恢复 | 引擎自动从 error 恢复 | |
| Claude 决定 | 延后 | |

**User's choice:** 陷阱态：仅显式可出
**Notes:** 可预测、可测；与 STATE-07 竞态测试"最终状态仅匹配最后一次 open"一致；自动恢复注入不可预测状态变化；适配层透传 error 无需预测自动恢复时序。

### D11 — disposing 可见性

| Option | Description | Selected |
|--------|-------------|----------|
| 不可见（同步瞬态） (推荐) | dispose() 同步完成 alive→disposed；对外实质二稳态 {alive, disposed} | ✓ |
| 可见（异步 dispose） | 调用者可观察 disposing 中间态 | |
| Claude 决定 | 延后 | |

**User's choice:** 不可见（同步瞬态）
**Notes:** 契约最简，调用者无中间态处理；同步 dispose 期间重入 double-dispose 直接命中幂等 no-op；异步 dispose 会使调用者须处理"正在销毁"中间态，复杂度外溢；disposing 供状态机内部/测试断言。

### D12 — recover 可达性

| Option | Description | Selected |
|--------|-------------|----------|
| 仅 error 可调 (推荐) | 他态被拒 no-op（P20 升级 Result.err）；transitions to {idle, opening} | ✓ |
| 任意态可调 no-op | recover() 任意态可调 | |
| Claude 决定 | 延后 | |

**User's choice:** 仅 error 可调
**Notes:** recover() 作为 error 专属出口与 D10 陷阱态协同（error 仅有 recover()/open() 两出口，recover 专管复位/重试，open 专管换媒体）；专一化=可测；任意态可调会与 stop() 重叠语义模糊；目标态 {idle, opening} 由 P20 STATE-04 最终选定。

---

## 契约测试策略 (BASE-04, 8 项决策 D13-D20)

### D13 — 契约测试执行对象

| Option | Description | Selected |
|--------|-------------|----------|
| 真实 FvpEngine (推荐) | 对真实实现跑契约测试；参数化 accepts MediaEngine 供 P21 复用 | ✓ |
| FakeEngine 扩展 | 扩展 FakeEngine 为契约驱动 | |
| 两者混合 | 真实主 + fake 补 | |

**User's choice:** 真实 FvpEngine
**Notes:** 契约测试作为迁移闸门须验证"实现符合冻结契约"；FakeEngine 行为是测试自定义的，测 fake = 测 mock，闸门弱；对真实行为跑才有闸门意义；参数化使 P21 同一套测试对 NewFvpEngine 跑即 VERIFY-01 闸门前提；FakeEngine 保留 widget 测试用，不扩展为契约驱动。

### D14 — 契约测试组织

| Option | Description | Selected |
|--------|-------------|----------|
| 按 ISP 接口分组 (推荐) | EngineStateView/PlaybackControl/TrackControl/SubtitleConfig/VideoEffectControl/RendererControl 各一组 | ✓ |
| 按方法分组 | 每方法一组测试 | |
| 按契约要素分组 | 按 requires/ensures/states/throws 要素分组 | |

**User's choice:** 按 ISP 接口分组
**Notes:** 与 D3 组契约同构；每组测试可独立审查（BASE-01 sc1）；迁移时按接口逐个验证；按方法分组与 D3 组契约脱节且 getter 单方法测试会与组契约重复；按契约要素分组跨方法难一眼审查单方法契约完整性。

### D15 — 契约测试覆盖深度

| Option | Description | Selected |
|--------|-------------|----------|
| 优先 states+throws (推荐) | 首版覆盖 states: 入/出态 + throws: 错误情形（最高回归风险） | ✓ |
| 全契约要素每方法 | 首版即覆盖 requires/ensures/modifies/states/throws 全要素 | |
| 先 states 镜像跑通再扩 | 最小骨架 | |

**User's choice:** 优先 states+throws
**Notes:** states+throws 覆盖最高回归风险先立闸门骨架；ensures/modifies 后置条件次轮补；与 D7 states: 标签镜像交叉校验；全要素每方法工作量大且 modifies 须 D2 标签先落地才能断言；先立骨架供 P20 capability 翻转时捕获回归，首版闸门偏窄是特性。

### D16 — 契约测试覆盖范围

| Option | Description | Selected |
|--------|-------------|----------|
| baseline 捕获现有行为 (推荐) | 捕获 FvpEngine 现有 6 态转换+错误+dispose 满足 sc4；lifecycle 新语义留 P20 清单 | ✓ |
| 目标契约 forward-looking | 断言 D5-D12 lifecycle 新语义（旧 FvpEngine 会 fail） | |
| baseline + lifecycle 分层 | 分层断言 | |

**User's choice:** baseline 捕获现有行为
**Notes:** lifecycle 新语义旧 FvpEngine 可能不符合（LifecyclePhase 是 v3.0 新增）；断言目标行为会让 FvpEngine fail 违反 sc4 且每次翻转一直红致闸门失效；baseline 捕获现有行为 + lifecycle 留 P20 NewFvpEngine 须补清单（BASE-03 sc3）尊重 P15/P20 边界，与 D6"完整转换表留 P20"一致。

### D17 — 契约测试错误注入

| Option | Description | Selected |
|--------|-------------|----------|
| 真实坏文件 fixture (推荐) | test/fixtures/ 放损坏/不存在/不支持编码视频，真实触发错误路径 | ✓ |
| FakeEngine 仅注入错误 | 用 FakeEngine 注入错误 | |
| 混合：真实主+fake 补 | 两套注入机制 | |

**User's choice:** 真实坏文件 fixture
**Notes:** 真实坏文件最真实触发 FvpEngine 错误路径且与 D13"真实 FvpEngine"一致、闸门强；FakeEngine 仅注入错误则 throws 闸门弱（测 mock）；混合两套注入机制须维护；需维护 fixture 集（坏文件、空文件、非视频文件、损坏 header）。

### D18 — known gap 清单落点

| Option | Description | Selected |
|--------|-------------|----------|
| CONTEXT.md decisions/deferred (推荐) | lifecycle gap 作为 P20 衍生项记 CONTEXT.md | ✓ |
| 契约 /// 就地标注 | 在接口 /// 标 TODO | |
| 独立 KNOWN-GAPS.md | 单独文件 | |

**User's choice:** CONTEXT.md decisions/deferred
**Notes:** CONTEXT.md SSOT 下游 gsd-planner 直接读，无额外文件；契约 /// 就地标注分散难汇总审查且 P22 lint 须额外校验 TODO 闭环；独立 KNOWN-GAPS.md 与 CONTEXT.md 双源可能漂移。

### D19 — 契约测试断言形式

| Option | Description | Selected |
|--------|-------------|----------|
| 行为断言+派生交叉 (推荐) | expect 方法调用后状态/错误 + 从 states: 标签/转换表派生参数化测试覆盖每条边 | ✓ |
| 仅直接断言行为 | 仅 expect 行为 | |
| 转换表镜像生成 | 从转换表生成测试副本 | |

**User's choice:** 行为断言+派生交叉
**Notes:** 行为断言+派生交叉使三视图（契约标签→转换表→测试）分叉可捕获，与 D7 交叉校验机制化；仅直接断言行为与转换表/标签是两套表达交叉校验靠人工分叉风险高；转换表镜像生成纯副本无独立断言同源错误传播。

### D20 — 契约测试时序边界

| Option | Description | Selected |
|--------|-------------|----------|
| 不含，留 P20 (推荐) | Phase 15 只测静态行为契约；时序/竞态留 P20 STATE-05/07 | ✓ |
| 含基础时序 | 含基础时序断言 | |
| 含完整竞态 | 含完整竞态测试 | |

**User's choice:** 不含，留 P20
**Notes:** Phase 15 闸门=行为正确性；STATE-05/07 是 P20 REQ 依赖 NewFvpEngine OpenGenerationTracker（P20 才有）；对旧 FvpEngine 跑竞态测试无对应实现测不动；含基础时序对真实 FvpEngine mdk 回调时序敏感 flaky 风险高。

---

## 盘点工件+陈旧maps (BASE-02, 3 项决策 D21-D23)

> **审计说明：** 本区域 3 轮讨论完成于第 8 个上下文窗口，决策直接落入 CONTEXT.md，未回写 checkpoint（checkpoint 末态停在 area 3 的 turn 20）。下方选项矩阵据 CONTEXT.md 决策 rationale（显式列出被否决的替代方案）+ `.continue-here.md` remaining_work 子问题列表忠实重建，非臆造。

### D21 — 盘点产物形态

| Option | Description | Selected |
|--------|-------------|----------|
| 可重跑 grep 脚本 + 输出快照 (推荐) | 脚本读 LIVE code 产出快照；可复现；快照供下游直读 | ✓ |
| 独立 AUDIT.md 静态文档 | 一次性人工盘点写入静态文档 | |
| 嵌入 CONTEXT.md | 盘点结果直接写入 CONTEXT.md | |

**User's choice:** 可重跑 grep 脚本 + 输出快照
**Notes:** 脚本读 LIVE code 满足 sc2"并可复现"；输出快照供下游 gsd-planner 直读 + 人类审查；数量漂移可在 P17 CI 闸门捕获；与 D1"避免第二真相源"同构（脚本读 LIVE code，非静态文档）；一次性人工 AUDIT.md 会随重构漂移、不满足"可复现"、与 LIVE code 形成双真相源。

### D22 — 陈旧 codebase maps 处理

| Option | Description | Selected |
|--------|-------------|----------|
| 标注陈旧+依赖 LIVE (推荐) | 7 份 maps 顶部加"v2.1 前快照"水印；Phase 15+ 对 LIVE code + codegraph | ✓ |
| 刷新对 LIVE code 重新生成 | 在 Phase 15 范围内刷新 maps | |

**User's choice:** 标注陈旧 + 依赖 LIVE
**Notes:** `.planning/codebase/` 7 份 maps（2026-07-12 v2.1 重构前快照）每份顶部加"v2.1 前快照"水印；Phase 15+ 一律对 LIVE code + codegraph；**不扩 Phase 15 范围去刷新**（map 刷新是独立 `/gsd-map-codebase` 任务，不在 BASE-02）；保留 v2.0/v2.1 演进历史；codegraph MCP 实时提供调用图/影响分析，削弱刷新静态 maps 的必要性。

### D23 — 脚本生命周期与落点

| Option | Description | Selected |
|--------|-------------|----------|
| tool/audit/ 长期资产 + phase 目录快照 (推荐) | 脚本入 tool/audit/ 演进成 P17 闸门；输出快照入 phase 目录 | ✓ |
| 脚本入 phase 目录一次性产物 | 脚本随阶段归档，不复用 | |
| Claude 决定 | 延后 | |

**User's choice:** tool/audit/ 长期资产 + phase 目录快照
**Notes:** 脚本入仓库 `tool/audit/`（长期资产，设计为可演进成 P17 CI 闸门——同脚本加 `--enforce` flag 即变闸门，避免双脚本漂移）；输出快照入 `.planning/phases/15-.../`（阶段产物供下游读）；与 D1/D21"避免第二真相源"同构——脚本即工具进 `tool/` 可被多阶段复用，文档进 `.planning/` 随阶段归档。

---

## Claude's Discretion

本阶段无用户授权"You decide"项。全部 23 项决策均由用户在 4 区域单问题轮次中显式选定推荐项。下游 gsd-planner 在以下点有实现裁量空间（非本讨论范围，记录于 CONTEXT.md specifics）：
- 契约测试 fixture 集具体文件清单
- grep 脚本具体语法（ripgrep vs dart script）
- `tool/audit/` 目录组织
- CONTEXT.md 中 lifecycle-gap 子节是否独立

---

## Deferred Ideas

讨论中提及但延后至后续阶段的想法（与 CONTEXT.md `<deferred>` 节一致）：

- **recover() 目标态 idle vs opening** — Phase 20 STATE-04 定（D6/D12 已限定为 {idle, opening} 集合，P20 在集合内选最终态并回写契约）
- **lifecycle 完整转换表** — Phase 20 STATE-04 实现时定并回写契约（D6 边界：P15 只冻结高层语义）
- **PROJECT.md "9 态~40 边" 陈旧描述修正为"6 态正交 + LifecyclePhase"** — Phase 15 派生任务（文档修正，属 Phase 15 产物收尾）
- **`.planning/codebase/` maps 刷新** — 独立 `/gsd-map-codebase` 任务，**不在 Phase 15 范围**（D22：Phase 15 只标注水印不刷新）
- **契约测试 fixture 集完整清单** — gsd-planner 在实现时定具体坏文件/空文件/非视频/损坏 header 的 fixture 清单（D17 锁定形态=真实坏文件 fixture，清单是实现裁量）
- **Phase 17 LOG-01 CI grep 闸门与 Phase 15 盘点脚本的 `--enforce` 演进** — Phase 17 实现时定（D23 锁定同脚本演进策略，flag 具体语义是 P17 裁量）

None of the deferred items block Phase 15. 所有延后项均有明确归属阶段，已记录供对应阶段 gsd-planner/gsd-executor 直接消费。

---

*Phase: 15-contract-freeze-baseline-audit*
*Discussion logged: 2026-07-16*
*Turns: 23 (turn 0 gray-area selection + turns 1-23 area discussions)*
*Sessions: 8 (cross-window continuation via checkpoint mechanism)*
