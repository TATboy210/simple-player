# Phase 19: MemoryMonitor 一等化 - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

将 `MemoryMonitor` 从静态单例重构为可注入、可关闭、不干扰播放业务状态的实例化诊断组件，纳入 `DiagnosticsBundle`。单例→实例迁移在一个原子提交内完成。

**本 phase 不交付**: 新引擎（P20）、其他诊断组件迁移（P17 logger 已完成）、适配层收拢（P21）。
</domain>

<decisions>
## Implementation Decisions

### Area 1: 依赖注入策略 (D1-D3)

- **D1:** RssProvider 抽象 = `abstract class RssProvider { int get currentRss; }` + `ProcessInfoRssProvider` 默认实现（包装 `ProcessInfo.currentRss`）+ `FakeRssProvider`（可控返回值，~10 行，无 mocktail）。注入点为 `MemoryMonitor` 构造函数。
- **D2:** Clock 抽象 = `abstract class Clock { DateTime now(); }` + `SystemClock` 默认实现 + `FakeClock`。与 RssProvider 同模式。注入点同为构造函数。用于 `MetricSample.timestamp` 和 `MemorySnapshot.timestamp`。
- **D3:** 两个抽象接口放 `lib/kernel/diagnostics/` 目录（与 KernelLogger 同位置），实现类放同文件或相邻文件。

### Area 2: 生命周期管理 (D4-D6)

- **D4:** MemoryMonitor 实例由 `DiagnosticsBundle` 持有（bundle 的 `memoryMonitorSlot` 字段）。`DiagnosticsBundle.dispose()` 级联调用 `monitor.dispose()`。单一拥有者。与 Phase 16 D10 一致。
- **D5:** 构造即启动 — Timer 在构造函数中自动创建，无需显式 `start()`。`dispose()` 停止 Timer 并清理状态。Bundle 构造后立即开始监控。
- **D6:** `MemoryMonitor` 实现 `Disposable` 接口（或等效的 `dispose()` 方法），`DiagnosticsBundle.dispose()` 级联调用。与 Phase 16 D1 bundle 4 slot dispose 级联一致。

### Area 3: 单例→实例迁移策略 (D7-D8)

- **D7:** 直接替换 — 删除静态 `_instance` + `MemoryMonitor._()` 私有构造，改为公开构造函数 `MemoryMonitor({required RssProvider rssProvider, required Clock clock, ...})`。所有调用点从 `MemoryMonitor.start()` → `monitor.start()`（实例方法）。一个原子提交完成，永不跨提交拆分。
- **D8:** 调用点迁移范围：`main.dart`（start/stop）、`debug_exporter.dart`（exportJson/snapshot）、`diagnostics_bundle.dart`（slot 类型）、`player_services.dart`（装配）。全局搜索确认无遗漏。

### Area 4: 配置参数化 (D9-D10)

- **D9:** 配置项作为构造参数带默认值：`thresholdBytes`（默认 50MB）、`maxHistory`（默认 200）、`interval`（默认 30s）。简洁、灵活、可测试。
- **D10:** 保留 `ValueNotifier<MemorySnapshot?> snapshotNotifier` 作为响应式更新通道，外部可通过 `ValueListenableBuilder` 监听。保留 `onTick` 回调。

</decisions>

<canonical_refs>
- `.planning/phases/16-diagnosticsbundle/16-CONTEXT.md` — DiagnosticsBundle 形态决策 (D1-D11)
- `.planning/phases/17-kernellogger/17-CONTEXT.md` — KernelLogger 接口模式参考
- `lib/kernel/utils/memory_monitor.dart` — 现有静态单例实现
- `lib/kernel/diagnostics/diagnostics_bundle.dart` — Bundle 骨架 + memoryMonitorSlot
- `lib/kernel/diagnostics/memory_monitor_slot.dart` — MemoryMonitor 抽象接口 + NullMemoryMonitor
</canonical_refs>

<code_context>
## Reusable Assets

- `MetricSample` / `MemorySnapshot` 数据类 — 保留，仅注入 Clock 替换 `DateTime.now()`
- `ValueNotifier<MemorySnapshot?>` — 保留，Bundle 通过此监听
- `lib/kernel/diagnostics/memory_monitor_slot.dart` — 已有抽象接口，P19 用真实实现替换 NullMemoryMonitor

## Patterns to Follow

- Phase 17 KernelLogger 模式：abstract 接口 + 持有实现 + 静态 I 访问器 → 实例注入
- Phase 16 DiagnosticsBundle 模式：slot 字段 + noop 默认 + dispose 级联
</code_context>
