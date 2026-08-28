# Phase 1: 统一捕获与报告契约 - Context

**Gathered:** 2026-08-28
**Status:** Ready for planning

<domain>
## Phase Boundary

四类错误源（FlutterError.onError / PlatformDispatcher.onError / runZonedGuarded 启动兜底 / PlayerError 显式汇入点）安全归一化为同一不可变 ErrorReport 契约；ErrorReporter（kernel 单例）承担唯一 fan-in/fan-out，入口不抛、reentrancy-safe；有界 FIFO（容量 5）+ 时间窗指纹去重；同 zone 启动组装（全包 main 体）。不含定位富化、文件落盘、UI 卡片（Phase 2/3 范围）。PlayerError 桥的完整接线在 Phase 3，本 phase 只留显式汇入点。

</domain>

<decisions>
## Implementation Decisions

### 启动组装
- **D-01:** runZonedGuarded 全包 main 体——binding 初始化（含 debug 的 MarionetteBinding 分支与 release 的 WidgetsFlutterBinding 分支，两分支同 zone）、MediaKit/KernelLogger/窗口服务初始化、钩子安装、runApp 全部在 guarded 闭包内 — **Reversibility:** reversible — 仅启动函数内的包裹结构调整
- **D-02:** ErrorReporter 用 kernel 静态单例模式（ErrorReporterImpl.I，与 KernelLoggerImpl.I 同款项目惯例），main 最早初始化；player_services 中重复的 KernelLoggerImpl.init() 调用点收敛到 main 一处 — **Reversibility:** costly — 调用方遍布各层（scanner/utils/services），改持有模式需触碰所有 KernelLoggerImpl.I 消费点同款数量的调用方

### 启动期错误补显
- **D-03:** pre-runApp 错误由 reporter 记录，UI 挂载后自动补显卡片（flush 语义）；补显内容同样走 FIFO 与去重 — **Reversibility:** reversible — reporter 增加一个 pending-flush 列表

### 队列与去重参数
- **D-04:** FIFO 容量 5 条，超出丢最旧（已落盘证据不丢）；去重为时间窗合并（同指纹错误在窗口内合并计数，超窗视为新错误）——具体窗口时长由 planner 依研究结论定（研究建议"短窗"，产品语义已锁定为时间窗合并而非永久合并） — **Reversibility:** reversible — 常量调整

### Claude's Discretion
- 指纹字段构成（类型/消息/来源/顶部应用帧——研究已建议，planner 细化）
- 严重级枚举命名（warning/error/fatal 文本语义已定）
- 重复 init 收敛的具体实现方式
- reporter 呈现状态的 notifier 具体形态（ValueNotifier<ErrorPresentationState> 不可变状态，研究已建议）

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目规划文档
- `.planning/PROJECT.md` — 里程碑目标、Unix 九原则约束、Key Decisions
- `.planning/REQUIREMENTS.md` — CAP-01~04 需求全文与 Out of Scope
- `.planning/ROADMAP.md` — Phase 1 Goal 与 4 条成功标准
- `.planning/research/SUMMARY.md` — 5-phase 建议、架构组件清单、7 大 pitfall（zone-only/递归/build 期发布/洪流）
- `.planning/research/ARCHITECTURE.md` — ErrorReporter 组件边界与数据流、与 kernel_logger 整合序
- `.planning/research/STACK.md` — 三钩子正确接线、PlatformDispatcher 返回 true 契约、same-zone 要求
- `.planning/research/PITFALLS.md` — reentrancy 防护、post-frame 发布、洪流抑制的预防策略

### 代码事实源
- `lib/main.dart` — 当前启动顺序（binding→MediaKit→KernelLogger→窗口→runApp）、双 binding 分支、无 zone 守卫现状
- `lib/kernel/diagnostics/kernel_logger.dart` — 门面 + 三 sink 架构（ErrorReporterImpl.I 仿此模式）
- `lib/kernel/player_services.dart` — 服务装配点（含重复 init 调用 :119）
- `lib/kernel/engine/media_kit_engine.dart` — PlayerError 发布点（lastError notifier）
- `lib/kernel/services/playback_controller.dart` — currentPath 所有权（媒体路径快照来源）、onError 回调通道

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KernelLoggerImpl.I` 静态单例 + 可注入 sink 架构（lib/kernel/diagnostics/kernel_logger.dart）：ErrorReporterImpl.I 直接仿此模式，测试注入 fake sink/reporter
- `StartupTimeline`（lib/kernel/diagnostics/startup_timeline.dart）：启动打点先例——Phase 1 启动组装可复用其"早初始化、纯逻辑、可测"风格
- `PlayerError` 契约（lib/kernel/models/player_error.dart）：已含 ErrorContext（action/generation/path/module）——ErrorReport 媒体上下文来源
- 测试惯例：FakeEngine 手写 fake + AAA 结构 + 行为命名（test/helpers/fake_engine.dart 先例）

### Established Patterns
- ValueNotifier + ValueListenableBuilder 惯例（研究锁定，不引入新状态库）
- Conventional commits + 中文注释惯例
- flutter analyze 0 error / 测试全绿红线

### Integration Points
- `main.dart`：zone 包裹改造点（保留既有 try/catch 窗口初始化逻辑）
- `player_services.dart:119`：重复 init 收敛点
- `media_kit_engine.dart`：PlayerError 显式汇入点的添加位置（完整桥在 Phase 3）
- `playback_controller.dart`：onError 回调（已有通道）与 currentPath（媒体快照 provider 注入点）

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches（研究已给出充分技术形态，用户决策集中在产品参数与装配位置）

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-统一捕获与报告契约*
*Context gathered: 2026-08-28*
