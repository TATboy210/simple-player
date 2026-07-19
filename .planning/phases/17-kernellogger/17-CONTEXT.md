# Phase 17: 零依赖 KernelLogger 门面（替换迁移） - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

在 `lib/kernel/diagnostics/kernel_logger.dart` 填充 Phase 16 留下的 KernelLogger 骨架（abstract + NullKernelLogger），落地零依赖 Logger 门面实现（DevToolsSink/DebugPrintSink/NullSink + kDebugMode 门控），替换 `lib/kernel/**` 对 `package:logger` 的依赖（保留 `log*.w()` 调用形状），一次性批量迁移 84 处调用点（30 文件仅改 import + 声明），激活 DiagnosticsBundle 的 logger slot，在 `player_services.dart` 组合根接线，CI grep 闸门立即启用。

**本 phase 不交付**：错误模型扩展（P18）、MemoryMonitor 一等化（P19）、NewFvpEngine（P20）、适配层收拢（P21）。P17 只交付 **Logger 实现 + 调用点迁移 + CI 闸门**。

**硬约束贯穿**：
- 约束 #1（logger 决策语义校正）：零依赖 = 内核解耦对 `package:logger` 的依赖（保留调用形状的替换迁移），非"app 无 logger 包"
- 约束 #7（debugPrint 发布不剥离）：`kDebugMode` 门控，release 构建零 debugPrint 泄漏

</domain>

<decisions>
## Implementation Decisions

### Area 1: LogSink 注入与接线时机 (D1-D6)

- **D1 — Logger 访问模式：** 静态注册 — `KernelLogger.I` 静态访问器。84 处调用点迁移只改 import + 声明类型，不改函数签名。与旧 `log.dart` 的 `Logger('...')` 静态模式一致，迁移最简。
- **D2 — DiagnosticsBundle 激活时机：** P17 激活 bundle 的 logger slot（替换 `NullKernelLogger` → 真实 `KernelLogger` 实例）。bundle 其他 3 slot（memory/metrics/eventLog）仍 noop。P16 D2 "dead code until P20" 指的是 metrics/eventLog/memory，logger 除外 — LOG-04 "可插拔 LogSink" 需要 P17 即激活。
- **D3 — 组合根接线时机：** P17 在 `player_services.dart` 接线 — 创建 `KernelLogger` 实例 → 注入 `DiagnosticsBundle` → bundle 注入 `KernelAdapter`。P17 范围内闭环。
- **D4 — LogSink 接口形态：** 单方法 — `void log(LogLevel level, String msg, {Map<String, Object?>? context})`。`KernelLogger` 内部做 level→sink.log 路由（6 方法 → 1 sink 调用）。加新 sink 只实现 1 方法，最简洁。
- **D5 — LogSink 位置：** 全在 `kernel_logger.dart` 内 — `LogLevel` 枚举 + `LogSink` 接口 + `DevToolsSink` + `DebugPrintSink` + `NullSink` + `KernelLogger` 实现类。P16 D7 说"不定义 LogLevel 枚举、sink 接口"（留 P17），现在 P17 全部落地在同一文件。KISS。
- **D6 — KernelLogger 静态生命周期：** `KernelLogger.I` 在 app 启动时设置一次，永不替换（static final-like 语义）。P20 通过重建 adapter 间接替换（新 bundle + 新 logger 在新 PlayerServices 初始化时设置）。

### Area 2: 迁移策略与 error/fatal 签名扩展 (D7-D11)

- **D7 — 迁移节奏：** 一次性批量替换 84 处。grep 确认零残留后 CI 闸门生效。最简单，一次性闭环。
- **D8 — error()/fatal() 签名扩展：** 扩展命名参 — `error(String msg, {Map<String, Object?>? context, Object? error, StackTrace? stackTrace})` + `fatal` 同签名。Phase 16 发现 3 处 `.e(msg, err, st)` 用命名参，LOG-04 "保留调用形状" 通过命名参映射实现。
- **D9 — 替换方式：** 脚本自动替换。Phase 16 D8 映射表机械化：`log*.w→KernelLogger.I.warn`，`log*.e→error` 等。脚本可复现、可审计，入 `tool/audit/`（与 Phase 15 D23 盘点脚本同目录）。
- **D10 — logger 变量处理：** 保留每文件顶部的 `final log = Logger('...')` 声明，改为 `final log = KernelLogger.I`。84 处调用点不需要改（log.w() 仍然有效，只是类型变了）。最简迁移。
- **D11 — 快捷方法保留：** `KernelLogger` 同时提供全称方法（`warn/error/info/debug/trace/fatal`）和快捷方法（`w/e/i/d/t/f`）。84 处调用点零方法名改动 — 只改 import + 声明。LOG-04 "保留调用形状" 字面满足。

### Area 3: sink 分级与 release 门控策略 (D12-D14)

- **D12 — debug 模式输出：** 全走 `debugPrint`（trace→debug→info→warn→error→fatal 全输出）。简单，一行代码。Flutter 的 `debugPrint` 自带 throttling。
- **D13 — release 门控：** `NullSink` + `kDebugMode` 编译时分支。debug→`DebugPrintSink`，release→`NullSink`。LOG-03 + Phase 21 VERIFY-06 闸门配套。
- **D14 — LogLevel 枚举：** 6 级 — `enum LogLevel { trace, debug, info, warn, error, fatal }`。与 KernelLogger 6 方法 1:1。P16 D8 映射表已锁。

### Area 4: dart:developer 配置与 path 脱敏 (D15-D17)

- **D15 — dart:developer.log name 参数：** `'Kernel'`。DevTools 中按 'Kernel' 过滤即可看到所有内核日志。应用级日志（非内核）用不同 name。
- **D16 — context 格式化：** Map context 追加到消息末尾 — `warn('msg', context: {'key': 'val'})` → 输出 `WARN: msg {key: val}`。简单直接，debugPrint 可读。
- **D17 — path 脱敏：** 只保留文件名 — `lib/kernel/engine/fvp_engine.dart:259` → `fvp_engine.dart:259`。防泄露本地路径，DevTools 够用。

### Carried Forward from Phase 15/16（承袭决策，不再问）

- **Phase 16 D5:** KernelLogger 签名已锁 — `trace/debug/info/warn/error/fatal(String msg, {Map<String,Object?>? context})` + `NullKernelLogger`。D8/D11 扩展了 error/fatal + 快捷方法。
- **Phase 16 D6:** 基于 84 调用点普查（非 121），`.e()` 有 3 处用命名参。D8 据此扩展签名。
- **Phase 16 D8:** 命名映射表 `log*.t/d/i/w/e/f → trace/debug/info/warn/error/fatal` 写进规格。D11 同时保留快捷方法。
- **Phase 16 D10:** DiagnosticsBundle 所有权 = `PlayerServices` 构造 + 必填注入 adapter。D2/D3 据此锁 P17 激活 logger slot + player_services 接线。
- **Phase 16 D11:** `lib/kernel/diagnostics/` 目录 5 文件。D5 把 logger 相关全合入 `kernel_logger.dart`（P16 的 5 文件中 kernel_logger.dart 扩展，其余 4 文件 P19/P20 才动）。
- **Phase 15 D1:** 契约权威落点 = 接口 `///` 双语注释。
- **Phase 15 D23:** 盘点脚本入 `tool/audit/`，可演进为 `--enforce` 闸门。D9 脚本自动替换同目录。

### Claude's Discretion

用户在全部 4 区 17 问都选了具体选项（无 "Let Claude decide"）。以下属 planner / executor 实现裁量：

- `tool/audit/` 下替换脚本的具体语法（sed vs dart script vs ripgrep + xargs）— 约束：CI 可自动化，与 Phase 15 D23 脚本同模式
- `DebugPrintSink` 内部实现（直接调 `debugPrint` vs 带 level prefix 格式化）— 约束：D16 context 追加到消息
- `DevToolsSink` 内部实现（`dart:developer.log` 参数：name='Kernel' per D15，level 映射 severity）— 约束：kDebugMode 门控
- `NullSink` 实现（const 空方法体，与 P16 NullKernelLogger 同模式）
- `KernelLogger.I` 静态字段的具体 Dart 实现（static late final vs static + init guard）
- logger slot 激活的具体代码变更（player_services.dart 构造 KernelLogger + 注入 bundle）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 路线图与需求（phase 级权威）
- `.planning/ROADMAP.md` §Phase 17 — Goal/Depends on Phase 16/Requirements LOG-01..05/Success Criteria 1-5/Blocking Constraints #1（logger 语义校正）+#7（debugPrint 发布不剥离）
- `.planning/REQUIREMENTS.md` §LOG — LOG-01..05 原子需求 + Traceability 表
- `.planning/.continue-here.md` — 8 blocking constraints；Phase 17 直接相关 #1（零依赖语义）+#7（debugPrint release 门控）

### Phase 16 骨架（P17 填充对象）
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` — D5（KernelLogger 骨架签名）/D6（error/fatal 命名参普查）/D7（契约边界）/D8（命名映射表）/D10（bundle 所有权）/D11（diagnostics 目录 5 文件）
- `lib/kernel/diagnostics/kernel_logger.dart` — P16 交付的 abstract KernelLogger + NullKernelLogger（P17 在此文件扩展实现）
- `lib/kernel/diagnostics/diagnostics_bundle.dart` — P16 交付的 bundle 载体（P17 替换 logger slot）

### Phase 15 契约与闸门
- `.planning/phases/15-contract-freeze-baseline-audit/15-CONTEXT.md` — D1（契约在接口）/D23（盘点脚本入 tool/audit/）
- `tool/audit/` — Phase 15 盘点脚本（P17 替换脚本同目录，可复用 grep 模式）

### LIVE code（迁移对象 + 装配点）
- `lib/kernel/utils/log.dart` — 旧 logger（import package:logger + path_provider），P17 内核 84 处替换目标；app 级保留不删
- `lib/kernel/engine/fvp_engine.dart` — 最大迁移对象（含最多 log 调用点）
- `lib/kernel/player_services.dart:87` — 装配点（P17 在此接线 KernelLogger → bundle → adapter）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase 16 DiagnosticsBundle 骨架**（`diagnostics_bundle.dart`）：`const DiagnosticsBundle.noop()` 工厂 + 4 slot 字段。P17 替换 logger slot 即激活，不改 bundle 结构
- **Phase 16 KernelLogger 抽象**（`kernel_logger.dart`）：`abstract class KernelLogger` 6 方法 + `NullKernelLogger`。P17 在此文件添加实现类 + LogSink + LogLevel
- **Phase 15 盘点脚本**（`tool/audit/`）：grep 模式可复用于 P17 CI 闸门（`lib/kernel/**` 永不 import package:logger）
- **旧 log.dart 模式**（`lib/kernel/utils/log.dart`）：`final log = Logger('...')` 静态声明模式 — P17 迁移保持同一模式（`final log = KernelLogger.I`）

### Established Patterns
- **静态单例访问**（旧 log.dart）：`Logger('name')` 全局声明 — P17 改为 `KernelLogger.I` 静态访问器，同一模式
- **kDebugMode 门控**（Flutter 标准）：`if (kDebugMode)` 编译时分支 — release 零 debugPrint
- **静态 grep 闸门**（Phase 15 D23 + Phase 16 D22）：CI grep 验证结构属性 — P17 LOG-01 闸门同模式
- **ValueNotifier + ValueListenableBuilder**（不改）：P17 不涉及 UI 层

### Integration Points
- **装配点 `player_services.dart:87`**：P17 在此创建 KernelLogger 实例 → 注入 bundle → bundle 注入 adapter
- **旧 logger `lib/kernel/utils/log.dart`**：P17 内核 84 处替换，app 级保留；最终 `lib/kernel/**` 零 import `package:logger`
- **DiagnosticsBundle.logger slot**（`diagnostics_bundle.dart`）：P17 替换 NullKernelLogger → 真实 KernelLogger

</code_context>

<specifics>
## Specific Ideas

- **84 调用点非 121**（Phase 16 复核）：ROADMAP 写 121 是 Phase 15 基线，Phase 16 researcher 独立 grep 确认为 84（48 .e / 7 .w / 12 .i / 17 .d）。planner 须用 84。
- **"保留调用形状"字面满足**（D11）：84 处 `log.w(msg)` 保持不变（KernelLogger 提供 w() 快捷方法），只改 import + 声明。LOG-04 最严格解读。
- **logger slot 激活是 P16 D2 的合理例外**：P16 说 bundle "dead code until P20"，但 LOG-04 可插拔 LogSink 需要 P17 即激活。其他 3 slot（memory/metrics/eventLog）仍 noop 至 P20。
- **脚本自动替换可复现**（D9）：入 `tool/audit/`，Phase 15 D23 同目录同模式。替换脚本 + CI grep 闸门可合为同一脚本的 `--migrate` / `--enforce` 双模式。

</specifics>

<deferred>
## Deferred Ideas

- **P20 NewFvpEngine Logger 集成** — P20 新引擎通过 DiagnosticsBundle.logger 发射日志，P17 只迁移旧引擎调用点
- **P18 ErrorContext + Logger 联动** — P18 扩展 sealed PlayerError 时，错误通过 Logger 发射结构化日志（P17 提供 Logger 基础设施，P18 消费）
- **P19 MemoryMonitor Logger 集成** — P19 一等化 MemoryMonitor 时，用 KernelLogger 替换直接 debugPrint
- **P21 VERIFY-06 release 冒烟闸门** — P17 LOG-03 kDebugMode 门控 + P21 VERIFY-06 `--release` 冒烟验证配套

None of the deferred items block Phase 17. 所有延后项均有明确归属阶段。

</deferred>

---

*Phase: 17-零依赖 KernelLogger 门面（替换迁移）*
*Context gathered: 2026-07-19*
*Decisions captured: 17 (D1-D17) across 4 gray areas*
