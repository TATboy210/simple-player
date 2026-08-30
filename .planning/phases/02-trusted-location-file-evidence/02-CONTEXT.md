# Phase 2: 可信定位与文件证据 - Context

**Gathered:** 2026-08-30
**Status:** Ready for planning

<domain>
## Phase Boundary

每份 ErrorReport 获得定位富化（LOC-01~03：项目帧提取、源码行读取、媒体路径快照冻结）与 error/fatal 独立文件落盘（LOG-01~05：FileSink、即时写、默认位置、稳定诊断包格式）。KernelLogger 保持门面；UI 卡片属 Phase 3，日志可配置路径属 Phase 4。

</domain>

<decisions>
## Implementation Decisions

### 源码行展示范围
- **D-01:** debug/profile 下随报告展示定位行 ±2 行（共 5 行）；前提 = 源码根信任校验通过（containment check）且源码可读；release / 越界 / 不可读时优雅降级为仅定位文本，不报错不闪退 — **Reversibility:** reversible — 常量调整

### 写盘节奏
- **D-02:** 即时写——每条 error/fatal 报告立即 UTF-8 追加落盘；洪流场景由上游有界 FIFO + 时间窗去重控制（Phase 1 已建），FileSink 不再叠加批量缓冲；掉电不丢已写记录 — **Reversibility:** reversible — 后续可加 flush 层不改契约

### 默认日志文件位置
- **D-03:** 默认落点 = `getApplicationSupportDirectory()/logs/error.log`（path_provider，不用 exe 目录/进程 cwd）；单文件 UTF-8 追加，跨会话累积（轮转已 Out of Scope）；用户可配置路径留待 Phase 4 接入 — **Reversibility:** reversible — 默认常量

### 诊断包文本格式
- **D-04:** 分段式纯文本——`==` 段标题 + 字段行（report ID / 来源 / 时序 / 媒体快照 / 定位 / 可选源码行 / 重复信息 / raw stack / 日志路径），人类直接可读可复制；卡片复制与文件记录使用同一 formatter 输出（Unix 原则 5） — **Reversibility:** reversible — formatter 单点

### 定位帧提取策略
- **D-05:** 定位字段 = 首个 `package:simple_player_flutter` 帧（文件:行:成员）+ 后续最多 2 个项目帧；raw stack 全文始终保留在诊断包尾部；提取失败时降级为「无项目帧，完整栈见 raw stack」定位文本，不产生新错误 — **Reversibility:** reversible — 提取函数参数

### 研究后修订决策（2026-08-30，用户拍板）
- **D-06:** FileSink 实现用 dart:io `File.writeAsString(mode: FileMode.append, flush: true)` + 单写者 Future 链队列，**不用** logger `FileOutput`——研究证实其 output() 不 flush 仅 destroy() 时刷（掉电丢尾，违背 D-02 即时写），且 kernel CI gate 禁止 lib/kernel/ 导入 package:logger；PROJECT.md 原 FileOutput 锁定方案已修订 — **Reversibility:** reversible
- **D-07:** 诊断包（文件记录与复制）中媒体快照与 failed-open 路径显示**完整路径**（开发者定位用途）；UI 卡片（Phase 3）显示 basename 脱敏——脱敏边界在 formatter 输出层区分，raw report 保持现状 — **Reversibility:** reversible
- **D-08:** FileSink 挂 **ErrorReporter 副作用链**（拿到富化后完整 ErrorReport，单写者语义干净），不走 KernelLogger CompositeSink 分流；KernelLogger 门面保持现状不动 — **Reversibility:** reversible

### Claude's Discretion
- 源码根路径的界定方式（编译时断言 vs 运行时探测，researcher 定）
- StackFrame.fromStackTrace 解析失败的具体兜底形态
- FileSink 挂入 CompositeSink 的组装细节与写失败限流节流参数
- 诊断包各段的确切标题文案与字段顺序

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划文档
- `.planning/REQUIREMENTS.md` — LOC-01~03 / LOG-01~05 需求全文与 Out of Scope
- `.planning/ROADMAP.md` — Phase 2 Goal 与 5 条成功标准
- `.planning/PROJECT.md` — 里程碑目标、Unix 九原则约束、Key Decisions（Phase 2 行已锁 FileOutput 方案）
- `.planning/phases/01-unified-capture-contract/01-CONTEXT.md` — Phase 1 契约决定（FIFO/去重/单例/媒体快照来源）
- `.planning/research/ARCHITECTURE.md` — FileSink 组件边界与 KernelLogger 整合序

### 代码事实源
- `lib/kernel/diagnostics/error_report.dart` — 不可变 ErrorReport 契约（定位富化的落点）
- `lib/kernel/diagnostics/error_reporter.dart` — ErrorReporter 单例（fan-out 到 FileSink 的位置）
- `lib/kernel/diagnostics/kernel_logger.dart` — LogSink 接口（:76）+ CompositeSink 组装（FileSink 挂入点）
- `lib/kernel/diagnostics/diagnostic_redactor.dart` — 路径脱敏（媒体路径进诊断包前沿用）
- `lib/kernel/services/playback_controller.dart` — currentPath 所有权（LOC-03 快照来源）

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LogSink` 接口（kernel_logger.dart:76）：FileSink 直接实现该接口，与 DevTools/DebugPrint/Null/Composite 同构
- `DiagnosticRedactor`：路径脱敏已建——媒体路径与日志路径写入诊断包时复用
- `ErrorReport` 不可变契约：定位字段（file:line / sourceLines / rawStack）以 copyWith 或新字段富化
- `ErrorReporterImpl.I` 单例 + 可注入依赖：测试注入 fake sink 先例已备

### Established Patterns
- ValueNotifier + ValueListenableBuilder（不引入新状态库）
- kernel 层禁 debugPrint（CI grep gate）——降级输出用 KernelLogger 限流 debugPrint 需核对 gate 范围
- 中文双语 doc comment、conventional commits、analyze 0 error / test 全绿红线

### Integration Points
- `error_reporter.dart`：fan-out 副作用链新增 FileSink 写盘（逐一隔离，CAP-03 惯例）
- `kernel_logger.dart` CompositeSink：error/fatal-only 分流
- `playback_controller.dart`：报告时 currentPath 快照注入

</code_context>

<specifics>
## Specific Ideas

无特殊引用——决策集中在实现参数（范围/节奏/落点/格式/帧数），技术形态沿用 Phase 1 研究结论

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 2-可信定位与文件证据*
*Context gathered: 2026-08-30*
