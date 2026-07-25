# Diagnostics API

## DiagnosticsBundle (final class)

**File:** `lib/kernel/diagnostics/diagnostics_bundle.dart`

诊断能力载体 — 4 个插槽的构造注入容器。

### Constructor

```dart
const DiagnosticsBundle({
  required KernelLogger logger,
  required MemoryMonitorSlot memoryMonitor,
  required MetricsSlot metrics,
  required EventLogSlot eventLog,
})

// No-op factory (default)
const DiagnosticsBundle.noop()
```

### Slots

| Slot | Type | Description |
|------|------|-------------|
| `logger` | `KernelLogger` | 日志插槽 |
| `memoryMonitor` | `MemoryMonitorSlot` | 内存监控插槽 |
| `metrics` | `MetricsSlot` | 指标插槽 |
| `eventLog` | `EventLogSlot` | 事件日志插槽 |

### Methods

```dart
void dispose()  // 级联释放（logger 不参与）
```

---

## KernelLogger

**File:** `lib/kernel/diagnostics/kernel_logger.dart`

日志接口。

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `d` | `void d(String message, {Map? context})` | Debug |
| `i` | `void i(String message, {Map? context})` | Info |
| `w` | `void w(String message, {Map? context})` | Warning |
| `e` | `void e(String message, {Map? context, Object? error, StackTrace? stackTrace})` | Error |

---

## EngineMetrics

**File:** `lib/kernel/engine/engine_metrics.dart`

引擎健康指标 — 计数器在 open/play/seek/error 路径自动更新。

---

## EngineEventLog

**File:** `lib/kernel/engine/engine_event_log.dart`

引擎事件日志 — 最近 100 条操作记录（环形缓冲，不持久化）。

---

## MemoryMonitor

**File:** `lib/kernel/diagnostics/memory_monitor.dart`

内存监控 — RSS 追踪。
