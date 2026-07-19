# Phase 18: Sealed 错误模型稳化 - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

稳化并扩展现有 sealed `PlayerError`（非新建），让错误带结构化上下文端到端传播（引擎 catch → lastError → logger → service → UI），永不静默吞错、永不以原始 sealed 对象暴露给 UI。

**本 phase 不交付**：新引擎（P20）、MemoryMonitor 一等化（P19）、适配层收拢（P21）。P18 只交付 **错误模型扩展 + 传播链 + UI 翻译 + 线程封送**。

**硬约束贯穿**：
- ERR-01：扩展 sealed PlayerError + ErrorContext + ErrorCode 注册表，保留 ValueNotifier<PlayerError?> 契约
- ERR-02：可恢复 vs 致命分裂根植于层级顶端，错误码冻结永不重命名
- ERR-03：引擎 catch 点构造带上下文的 PlayerError、赋值 lastError、经 bundle.logger.e 发射
- ERR-04：UI 边界 ErrorView 翻译（字符串码 + 本地化消息 + 严重级），sealed KernelError 永不以原始对象暴露给 UI
- ERR-05：错误跨 mdk 回调线程封送（主线程重建，回调栈作为字段携带）

</domain>

<decisions>
## Implementation Decisions

### Area 1: ErrorContext 结构与挂载方式 (D1-D3)

- **D1 — ErrorContext 形态：** `PlayerError` sealed class 新增可选 `ErrorContext? context` 字段。所有子类继承。构造时可选传入（向后兼容现有 ~5 处 catch 点）。`ErrorContext` 包含 action/generation/path/timestamp/module/callbackStackTrace。不改 sealed 层级结构，最小侵入。
- **D2 — 注入层：** 引擎 catch 点注入（FvpEngine/MediaOpener ~5 处）。上下文最精确（知道当前 action、path、generation）。PlaybackController 不注入（信息有限，不知道 generation/path）。
- **D3 — timestamp 策略：** 默认 `DateTime.now()` + 可覆盖（工厂构造，测试可注入假时间）。const 构造函数不行（DateTime.now() 非 const）。

### Area 2: 可恢复 vs 致命分类与 ErrorCode 注册表 (D4-D6)

- **D4 — 可恢复/致命分类：** `bool get isFatal` 抽象 getter 在 sealed PlayerError 层声明。每个子类根据 code 返回 true/false。不改 sealed 层级结构，最小侵入。
- **D5 — ErrorCode 注册表：** 保持现有每子类独立枚举（FileErrorCode/CodecErrorCode/PlaybackErrorCode/NetworkErrorCode）。每个 code 内嵌 `recoverable` 标记。`PlayerError.isFatal` 委托给 `!code.recoverable`。ERR-01 "ErrorCode 注册表" = 这些枚举本身就是注册表。不引入统一 ErrorCode 枚举（避免过度抽象 + 破坏现有 switch）。
- **D6 — 错误码冻结：** 追加-only + doc comment 注明冻结。现有码永不重命名/删除，只追加新码。ERR-02 "错误码冻结永不重命名" 字面满足。

### Area 3: UI 边界翻译与错误传播链 (D7-D8)

- **D7 — UI 翻译层：** `PlayerError` 内嵌 `String get l10nKey`（如 `'error.file.notFound'`）。ErrorBanner 用 l10nKey 查 AppLocalizations，fallback 到原始 message。sealed 对象不直接暴露给 UI——UI 只看 l10nKey + message + isFatal。ERR-04 "sealed KernelError 永不以原始对象暴露给 UI" 通过 l10nKey 间接翻译满足。
- **D8 — 传播链签名：** `PlaybackController._onError(Object error)` → `_onError(PlayerError error)`。引擎 catch 点已构造 PlayerError，Controller 不需要再判断类型。若 mdk 回调传裸 Exception，封送层（D9）先转为 PlayerError。

### Area 4: mdk 回调线程封送与 logger 集成 (D9-D11)

- **D9 — 线程封送：** mdk 回调内捕获异常，构造 PlayerError + ErrorContext（含 callbackStackTrace），通过 `scheduleMicrotask` 封送到主线程赋值 lastError + logger 发射。回调栈作为 ErrorContext.callbackStackTrace 字段携带。ERR-05 "主线程重建，回调栈作为字段携带" 满足。
- **D10 — logger 集成：** 每个 catch 点三步合一——构造 PlayerError → 赋值 lastError.value → bundle.logger.e('msg', context: error.context?.toMap(), error: cause, stackTrace: st)。Logger 从 ErrorContext 读结构化上下文。ERR-03 "引擎 catch 点构造带上下文的 PlayerError 经 bundle.logger.e 发射" 满足。
- **D11 — callbackStackTrace 字段：** `ErrorContext` 新增 `StackTrace? callbackStackTrace` 字段。仅 mdk 回调封送时填充，主线程 catch 点不填（null）。`toMap()` 序列化时条件包含。

### Carried Forward from Phase 15/16/17（承袭决策，不再问）

- **Phase 15 D1:** 契约权威在接口 `///` 双语注释
- **Phase 16 D5:** KernelLogger 签名已锁（含 error/fatal 扩展命名参）
- **Phase 16 D10:** DiagnosticsBundle 所有权 = PlayerServices 构造 + 必填注入 adapter
- **Phase 17 D1:** KernelLogger.I 静态访问器
- **Phase 17 D8:** error/fatal 扩展签名 `{Object? error, StackTrace? stackTrace}`
- `ValueNotifier<PlayerError?>` 契约保留（EngineStateView.lastError + ErrorBanner 依赖不破坏）

### Claude's Discretion

用户在全部 4 区 11 问都选了具体选项（无 "Let Claude decide"）。以下属 planner / executor 实现裁量：

- ErrorContext.toMap() 的具体序列化字段（D1 已列 action/generation/path/timestamp/module/callbackStackTrace）
- ErrorBanner 的 l10nKey 查找失败 fallback 策略（D7 已定 fallback 到原始 message）
- mdk 回调中哪些 catch 点需要封送（D9：所有非主线程回调内的异常）
- 各子类 code 的 recoverable 标记具体值（D5：planner 逐枚举标记）
- l10nKey 的命名规范（D7：建议 `error.{type}.{code}` 格式，planner 可调整）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 路线图与需求（phase 级权威）
- `.planning/ROADMAP.md` §Phase 18 — Goal/Depends on Phase 17/Requirements ERR-01..05/Success Criteria 1-5
- `.planning/REQUIREMENTS.md` §ERR — ERR-01..05 原子需求 + Traceability 表
- `.planning/.continue-here.md` — 8 blocking constraints

### Phase 16/17 诊断基础设施
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` — D5（KernelLogger 签名）/D10（bundle 所有权）
- `.planning/phases/17-kernellogger/17-CONTEXT.md` — D1（KernelLogger.I）/D8（error/fatal 扩展签名）
- `lib/kernel/diagnostics/kernel_logger.dart` — P17 交付的 KernelLogger 实现（含 error/fatal 方法）
- `lib/kernel/diagnostics/diagnostics_bundle.dart` — P16 交付的 bundle 载体

### LIVE code（扩展对象 + 传播链）
- `lib/kernel/models/player_error.dart` — 现有 sealed PlayerError 5 子类（P18 扩展对象）
- `lib/kernel/engine/fvp_engine.dart` — ~5 处 catch 点（P18 改造目标：加 ErrorContext + logger 发射）
- `lib/kernel/engine/media_opener.dart` — 错误构造点（P18 改造目标：加 ErrorContext）
- `lib/kernel/engine/engine_state_view.dart:55` — `ValueNotifier<PlayerError?> get lastError`（契约保留）
- `lib/ui/player/error_banner.dart` — UI 错误消费方（P18 改为用 l10nKey 翻译）
- `lib/kernel/services/playback_controller.dart` — `_onError` 签名收窄目标

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **sealed PlayerError 5 子类**（`player_error.dart`）：现有结构完整，P18 只扩展字段（context/isFatal/l10nKey），不改子类分类
- **ErrorBanner**（`error_banner.dart`）：已用 ValueListenableBuilder2 监听 state + lastError，P18 只改翻译逻辑
- **KernelLogger.error()**（P17 交付）：已支持 `{Map? context, Object? error, StackTrace? stackTrace}` 命名参，P18 直接传 ErrorContext.toMap()

### Established Patterns
- **ValueNotifier + ValueListenableBuilder**（不改）：lastError 契约保留
- **sealed class 穷举模式匹配**（Dart 3）：ErrorBanner switch 保留，P18 只加 l10nKey 间接翻译
- **scheduleMicrotask 线程封送**（Flutter 标准）：ERR-05 封送机制

### Integration Points
- **FvpEngine catch 点**（~5 处）：`lastError.value = XxxError(...)` → P18 改为三步合一（构造+赋值+logger）
- **PlaybackController._onError**：签名收窄 Object → PlayerError
- **ErrorBanner**：switch sealed → 用 l10nKey 查 AppLocalizations

</code_context>

<specifics>
## Specific Ideas

- **ErrorContext 向后兼容**：可选字段，现有 catch 点不传 context 仍工作。渐进迁移：先加字段，再逐 catch 点补 context。
- **isFatal 委托给 code.recoverable**：单一真相源（code 枚举），isFatal 只是便捷访问器。ERR-02 "根植于层级顶端" = sealed 层声明 isFatal getter，子类实现委托给 code。
- **l10nKey 是 UI 解耦的关键**：ErrorBanner 不再直接依赖 sealed 类型 switch，只读 l10nKey。未来新增错误子类不需要改 ErrorBanner。
- **三步合一模式可提取为 P20 NewFvpEngine 的标准错误处理模板**。

</specifics>

<deferred>
## Deferred Ideas

- **P19 MemoryMonitor 错误集成** — MemoryMonitor 异常用 KernelLogger 发射，P18 只处理播放错误
- **P20 NewFvpEngine 错误处理** — P20 新引擎用同一三步合一模式 + ErrorContext
- **P20 Result.err 替换静默 assert** — D9 P15 已锁定"mutating 方法 no-op → P20 升级 Result.err"
- **P22 DOC-03 KernelError 子类错误码** — P18 冻结的错误码 + P22 双语注释配套
- **ERR-F01 Future** — openGeneration 关联、RetryPolicy 枚举、按码错误指标、用户面 l10n 码→键映射

None of the deferred items block Phase 18. 所有延后项均有明确归属阶段。

</deferred>

---

*Phase: 18-sealed*
*Context gathered: 2026-07-19*
*Decisions captured: 11 (D1-D11) across 4 gray areas*
