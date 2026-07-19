# Phase 19: MemoryMonitor 一等化 - Research

**Researched:** 2026-07-20
**Domain:** Diagnostics component refactoring (static singleton → injectable instance)
**Confidence:** HIGH

## Summary

`MemoryMonitor` is a 193-line static singleton in `lib/kernel/utils/memory_monitor.dart` that wraps `ProcessInfo.currentRss` with periodic sampling, history buffering, and snapshot/export capabilities. Phase 19 refactors it into an injectable, disposable instance owned by `DiagnosticsBundle`, with `RssProvider` and `Clock` abstractions for testability.

The migration touches exactly 2 static call sites (`main.dart:22` and `debug_exporter.dart:59`) plus the `DiagnosticsBundle` wiring in `player_services.dart:107`. The existing `MemoryMonitorSlot` abstract interface (Phase 16) already defines the contract — Phase 19 provides the real implementation behind it.

The critical risk is the atomic singleton→instance migration (R2-5 lesson: delete `_instance` but leave static methods = build failure). The ROADMAP mandates a transient static bridge shim within a single commit.

**Primary recommendation:** Follow the Phase 17 KernelLogger pattern — real implementation class behind existing abstract slot, constructor-injected dependencies, wired in `PlayerServices.init()`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RSS sampling | Kernel (diagnostics) | — | ProcessInfo access is kernel-level, no UI involvement |
| Snapshot/export | Kernel (diagnostics) | — | Pure data transformation, no UI dependency |
| Timer lifecycle | Kernel (diagnostics) | — | Owned by DiagnosticsBundle.dispose() cascade |
| UI display (future) | UI | Kernel | snapshotNotifier enables ValueListenableBuilder, but P19 doesn't build UI |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dart:async | SDK | Timer.periodic for sampling | Already used in current implementation |
| dart:io | SDK | ProcessInfo.currentRss | Only source of RSS data on desktop |
| flutter/foundation | SDK | ValueNotifier, kDebugMode | Project standard state management |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:convert | SDK | jsonEncode for exportJson | Snapshot JSON serialization |

**No external packages needed.** All dependencies are SDK-provided. This phase adds zero new pub dependencies.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| RssProvider abstraction | Direct ProcessInfo.currentRss | Untestable without real process; abstraction enables FakeRssProvider (~10 lines) |
| Clock abstraction | DateTime.now() directly | Untestable timestamps; abstraction enables FakeClock |

## Package Legitimacy Audit

No new packages installed in this phase. All dependencies are Dart/Flutter SDK.

## Architecture Patterns

### System Architecture Diagram

```
PlayerServices.init()
  ├── KernelLoggerImpl.init()          (P17)
  ├── DiagnosticsBundle(
  │     logger: KernelLoggerImpl.I,
  │     memoryMonitor: MemoryMonitor(  ← P19 replaces NullMemoryMonitorSlot
  │       rssProvider: ProcessInfoRssProvider(),
  │       clock: SystemClock(),
  │     ),
  │     metrics: NullMetricsSlot,
  │     eventLog: NullEventLogSlot,
  │   )
  └── KernelAdapter(bundle: bundle, ...)

MemoryMonitor (instance)
  ├── RssProvider (injected) → ProcessInfo.currentRss
  ├── Clock (injected) → DateTime.now()
  ├── Timer.periodic → _tick()
  │     ├── reads RssProvider.currentRss
  │     ├── updates _history (ring buffer)
  │     ├── updates snapshotNotifier (ValueNotifier)
  │     ├── calls onTick callback
  │     └── logs via KernelLogger (replaces debugPrint)
  ├── snapshot() → MemorySnapshot?
  ├── exportJson() → String
  └── dispose() → cancels Timer, clears state
```

### Recommended Project Structure

```
lib/kernel/diagnostics/
├── diagnostics_bundle.dart      (exists, modify memoryMonitor slot type)
├── kernel_logger.dart           (exists, P17 deliverable)
├── memory_monitor_slot.dart     (exists, abstract interface — keep as-is)
├── memory_monitor.dart          (NEW: real implementation)
├── memory_snapshot.dart         (NEW: MetricSample + MemorySnapshot data classes)
├── rss_provider.dart            (NEW: RssProvider + ProcessInfoRssProvider + FakeRssProvider)
├── clock.dart                   (NEW: Clock + SystemClock + FakeClock)
├── metrics_slot.dart            (exists, no change)
└── event_log_slot.dart          (exists, no change)
```

### Pattern 1: Abstract Provider + Default Implementation (D1/D2)

**What:** Inject `RssProvider` and `Clock` abstractions into `MemoryMonitor` constructor for testability.

**When to use:** When a dependency on external state (process memory, system time) makes unit testing impossible without abstraction.

**Example:**
```dart
// lib/kernel/diagnostics/rss_provider.dart
/// RSS 内存读取抽象 — 解耦 ProcessInfo 依赖, 支持测试注入 (D1).
abstract class RssProvider {
  /// 当前进程 RSS 字节数.
  int get currentRss;
}

/// 默认实现 — 包装 ProcessInfo.currentRss (D1).
final class ProcessInfoRssProvider implements RssProvider {
  const ProcessInfoRssProvider();

  @override
  int get currentRss => ProcessInfo.currentRss;
}

/// 测试用 fake — 可控返回值, ~10 行, 无 mocktail (D1).
final class FakeRssProvider implements RssProvider {
  FakeRssProvider(this._value);
  int _value;

  @override
  int get currentRss => _value;
}

// lib/kernel/diagnostics/clock.dart
/// 时钟抽象 — 解耦 DateTime.now() 依赖, 支持测试注入 (D2).
abstract class Clock {
  DateTime now();
}

/// 默认实现 (D2).
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// 测试用 fake (D2).
final class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;
}
```

### Pattern 2: Slot Implementation Behind Existing Interface (Phase 16/17 pattern)

**What:** `MemoryMonitor` implements `MemoryMonitorSlot` (existing abstract interface from Phase 16), replacing `NullMemoryMonitorSlot` in the bundle.

**When to use:** When an existing abstract slot contract exists and needs a real implementation.

**Example:**
```dart
// lib/kernel/diagnostics/memory_monitor.dart
/// 周期性内存监控 — 实例化诊断组件 (Phase 19).
///
/// 构造注入 [RssProvider] + [Clock], 配置参数带默认值.
/// 实现 [MemoryMonitorSlot] 接口, 纳入 [DiagnosticsBundle].
final class MemoryMonitor implements MemoryMonitorSlot {
  MemoryMonitor({
    required this.rssProvider,
    required this.clock,
    this.thresholdBytes = 50 * 1024 * 1024,  // 50MB (D9)
    this.maxHistory = 200,                     // (D9)
    this.interval = const Duration(seconds: 30), // (D9)
    KernelLogger? logger,
    this.onTick,
  }) : _logger = logger {
    // 构造即启动 (D5)
    _startImpl();
  }

  final RssProvider rssProvider;
  final Clock clock;
  final int thresholdBytes;
  final int maxHistory;
  final Duration interval;
  final KernelLogger? _logger;
  final void Function(MemorySnapshot snapshot)? onTick;

  Timer? _timer;
  int _lastRss = 0;
  int _peakRss = 0;
  final List<MetricSample> _history = [];
  bool _disposed = false;

  final ValueNotifier<MemorySnapshot?> snapshotNotifier =
      ValueNotifier<MemorySnapshot?>(null);

  // ... lifecycle + sampling logic (same as current, but using injected deps)
}
```

### Pattern 3: Atomic Singleton→Instance Migration (MEM-04, R2-5 lesson)

**What:** In a single commit, (1) add transient static bridge shim, (2) rewrite 2 call sites to instance API, (3) delete shim.

**Why atomic:** R2-5 lesson — deleting `_instance` but leaving static methods causes build failure. The shim keeps the old static API working while call sites are migrated, then both are removed together.

**Example (within single commit):**
```dart
// Step 1: In memory_monitor.dart — add transient shim (deleted same commit)
class MemoryMonitor {
  // ... new instance-based constructor ...

  // TRANSIENT SHIM — deleted after call sites migrate
  static MemoryMonitor? _bridgeInstance;
  static void _bridgeStart({...}) => _bridgeInstance?.start();
  static MemorySnapshot? _bridgeSnapshot() => _bridgeInstance?.snapshot();
}

// Step 2: main.dart — rewrite to instance
final memoryMonitor = MemoryMonitor(
  rssProvider: const ProcessInfoRssProvider(),
  clock: const SystemClock(),
);

// Step 3: debug_exporter.dart — rewrite to instance
// (pass instance via constructor or static accessor)

// Step 4: Delete shim (same commit)
```

### Anti-Patterns to Avoid

- **R2-5 partial migration:** Never delete `_instance` without also removing all static method call sites in the same commit.
- **Constructor-start + explicit start():** D5 says constructor starts timer. Don't also expose a `start()` method that conflicts — either auto-start (D5) or explicit start, not both. The `MemoryMonitorSlot` interface has `start({Duration? interval})` — the real implementation should make this a no-op (already started) or remove it from the concrete class.
- **DebugExporter static coupling:** `DebugExporter` is a static class that calls `MemoryMonitor.snapshot()` statically. After migration, it needs an instance reference. Options: (a) pass instance to `DebugExporter.exportAll(MemoryMonitor monitor)`, or (b) keep a static accessor on MemoryMonitor for backward compat.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test doubles for ProcessInfo | Complex mock framework | `FakeRssProvider` (~10 lines) | D1 mandates no mocktail |
| Test doubles for DateTime | Mock clock libraries | `FakeClock` (~5 lines) | D2 mandates simple fake |
| Ring buffer | Custom list management | `List` + `removeAt(0)` while loop | Already works, KISS |

## Common Pitfalls

### Pitfall 1: D5 Constructor-Start vs MemoryMonitorSlot.start() Interface Conflict

**What goes wrong:** `MemoryMonitorSlot` defines `start({Duration? interval})` but D5 says "constructor starts timer automatically." If the concrete `MemoryMonitor` auto-starts in constructor, calling `start()` again creates a second timer.

**Why it happens:** The Phase 16 slot interface was designed before D5's "constructor-start" decision.

**How to avoid:** Two options — (a) make `start()` a no-op if already running (idempotent), or (b) the concrete class doesn't implement `start()` from the slot and instead the bundle wiring skips calling it. Option (a) is safer since `DiagnosticsBundle` tests call `memoryMonitor.start()`.

**Warning signs:** Timer leak (multiple periodic timers), double sampling in history.

### Pitfall 2: DebugExporter Static Access After Migration

**What goes wrong:** `DebugExporter._memorySnapshot()` calls `MemoryMonitor.snapshot()` statically. After removing static methods, this breaks.

**Why it happens:** DebugExporter is a static utility class with no instance injection.

**How to avoid:** Pass `MemoryMonitor` instance to `DebugExporter.exportAll()` or add a `MemoryMonitor? monitor` parameter. Since `DebugExporter` is only called from `keyboard_handler.dart` (Ctrl+Shift+D), the instance can be threaded through.

**Warning signs:** Build failure on `MemoryMonitor.snapshot()` static call.

### Pitfall 3: dispose() Idempotency

**What goes wrong:** `DiagnosticsBundle.dispose()` calls `memoryMonitor.dispose()`. If called twice (e.g., app restart), double-dispose crashes.

**Why it happens:** Timer.cancel() on already-cancelled timer is safe, but ValueNotifier.dispose() is not idempotent.

**How to avoid:** Guard with `_disposed` flag. `dispose()` is idempotent per Phase 15 D8.

**Warning signs:** "A ValueNotifier was used after being disposed" exception.

## Code Examples

### Real Implementation (memory_monitor.dart)

```dart
// Source: Phase 19 CONTEXT D1-D10, following Phase 17 KernelLogger pattern
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'clock.dart';
import 'kernel_logger.dart';
import 'memory_snapshot.dart';
import 'memory_monitor_slot.dart';
import 'rss_provider.dart';

/// 周期性内存监控 — 实例化诊断组件 (Phase 19, MEM-01).
///
/// 构造注入 [RssProvider] + [Clock], 配置参数带默认值 (D9).
/// 实现 [MemoryMonitorSlot], 纳入 [DiagnosticsBundle] (D4).
/// 构造即启动, Timer 在构造函数中自动创建 (D5).
final class MemoryMonitor implements MemoryMonitorSlot {
  MemoryMonitor({
    required this.rssProvider,
    required this.clock,
    this.thresholdBytes = 50 * 1024 * 1024,
    this.maxHistory = 200,
    this.interval = const Duration(seconds: 30),
    KernelLogger? logger,
    this.onTick,
  }) : _logger = logger {
    _startImpl();
  }

  final RssProvider rssProvider;
  final Clock clock;
  final int thresholdBytes;
  final int maxHistory;
  final Duration interval;
  final KernelLogger? _logger;
  final void Function(MemorySnapshot snapshot)? onTick;

  Timer? _timer;
  int _lastRss = 0;
  int _peakRss = 0;
  final List<MetricSample> _history = [];
  bool _disposed = false;

  final ValueNotifier<MemorySnapshot?> snapshotNotifier =
      ValueNotifier<MemorySnapshot?>(null);

  @override
  void start({Duration? interval}) {
    // D5: 构造即启动, start() 为幂等 no-op (防 Pitfall 1)
    if (_timer != null || _disposed) return;
    _startImpl(interval: interval);
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastRss = 0;
    _peakRss = 0;
    _history.clear();
    snapshotNotifier.value = null;
  }

  @override
  MemorySnapshot? snapshot() {
    if (_lastRss == 0 && _history.isEmpty) return null;
    return MemorySnapshot(
      rssBytes: _lastRss,
      maxRssBytes: _peakRss,
      deltaBytes: 0,
      history: List.unmodifiable(_history),
      timestamp: clock.now(),
    );
  }

  /// 导出 JSON 字符串.
  String exportJson() {
    final snap = snapshot();
    if (snap == null) return '{}';
    return jsonEncode(snap.toJson());
  }

  @override
  void dispose() {
    if (_disposed) return; // 幂等 (Pitfall 3)
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    snapshotNotifier.dispose();
  }

  void _startImpl({Duration? interval}) {
    final effectiveInterval = interval ?? this.interval;
    _lastRss = rssProvider.currentRss;
    _peakRss = _lastRss;
    _recordSample(_lastRss);
    _logCurrent(_lastRss);

    _timer?.cancel();
    _timer = Timer.periodic(effectiveInterval, (_) {
      final current = rssProvider.currentRss;
      final delta = current - _lastRss;

      if (current > _peakRss) _peakRss = current;

      _recordSample(current);
      _logCurrent(current);

      if (delta > thresholdBytes) {
        final deltaMB = (delta / (1024 * 1024)).toStringAsFixed(1);
        _logger?.warn('[MemoryMonitor] RSS growth +$deltaMB MB exceeds threshold');
      }

      _lastRss = current;

      final snap = MemorySnapshot(
        rssBytes: current,
        maxRssBytes: _peakRss,
        deltaBytes: delta,
        history: List.unmodifiable(_history),
        timestamp: clock.now(),
      );
      snapshotNotifier.value = snap;
      onTick?.call(snap);
    });
  }

  void _recordSample(int rssBytes) {
    _history.add(MetricSample(rssBytes: rssBytes, timestamp: clock.now()));
    while (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  void _logCurrent(int rssBytes) {
    final mb = (rssBytes / (1024 * 1024)).toStringAsFixed(1);
    _logger?.info('[MemoryMonitor] RSS: $mb MB');
  }
}
```

### Wiring in PlayerServices (player_services.dart)

```dart
// Phase 19: Replace NullMemoryMonitorSlot with real MemoryMonitor
final memoryMonitor = MemoryMonitor(
  rssProvider: const ProcessInfoRssProvider(),
  clock: const SystemClock(),
  logger: KernelLoggerImpl.I,
);
final bundle = DiagnosticsBundle(
  logger: KernelLoggerImpl.I,
  memoryMonitor: memoryMonitor,  // was: const NullMemoryMonitorSlot()
  metrics: const NullMetricsSlot(),
  eventLog: const NullEventLogSlot(),
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static singleton `MemoryMonitor._()` | Injected instance with `RssProvider`/`Clock` | Phase 19 | Testable, disposable, bundle-integrated |
| `debugPrint` for logging | `KernelLogger` integration | Phase 19 (MEM-05) | Consistent with P17 kernel logging |
| Hardcoded constants | Constructor params with defaults | Phase 19 (D9) | Configurable threshold/interval/history |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Disposable` interface does not exist — D6 means just having a `dispose()` method, consistent with all other kernel classes | Architecture | Low — codebase grep confirms no Disposable interface |
| A2 | `DebugExporter` can accept `MemoryMonitor` instance as parameter (no circular dependency) | Pitfall 2 | Low — DebugExporter is a static utility, parameter change is safe |
| A3 | `MemoryMonitorSlot.start({Duration? interval})` can be made idempotent without breaking existing `NullMemoryMonitorSlot` consumers | Pitfall 1 | Low — NullMemoryMonitorSlot is no-op, real impl can be idempotent |

## Open Questions

1. **DebugExporter migration strategy**
   - What we know: `DebugExporter._memorySnapshot()` calls `MemoryMonitor.snapshot()` statically. `DebugExporter` is called from `keyboard_handler.dart:199`.
   - What's unclear: Whether to (a) add `MemoryMonitor` param to `DebugExporter.exportAll()`, or (b) keep a static reference for backward compat.
   - Recommendation: Option (a) — add parameter. `keyboard_handler` has access to the app's services via callback chain. Cleaner than static bridge.

2. **MemoryMonitorSlot.start() interface alignment with D5 constructor-start**
   - What we know: `MemoryMonitorSlot` has `start({Duration? interval})`. D5 says constructor auto-starts.
   - What's unclear: Whether to modify the slot interface or make `start()` idempotent.
   - Recommendation: Make `start()` idempotent on the concrete class (no-op if already running). Don't modify the abstract interface — it's Phase 16 frozen contract.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | Yes | — | — |
| dart:async | Timer | SDK | — | — |
| dart:io | ProcessInfo | SDK (desktop only) | — | — |

**No external dependencies.** This phase is purely SDK-based.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | `test/` directory |
| Quick run command | `flutter test test/diagnostics/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MEM-01 | Instance construction with injected RssProvider + Clock | unit | `flutter test test/diagnostics/memory_monitor_test.dart` | Wave 0 |
| MEM-02 | start/stop/dispose lifecycle, zero PlaybackController/MediaState interaction | unit | `flutter test test/diagnostics/memory_monitor_test.dart` | Wave 0 |
| MEM-03 | ValueNotifier + snapshot() + exportJson() preserved, data classes in memory_snapshot.dart | unit | `flutter test test/diagnostics/memory_snapshot_test.dart` | Wave 0 |
| MEM-04 | Atomic migration — no cross-commit split | static | `grep -r 'MemoryMonitor\._' lib/` returns 0 | N/A (commit discipline) |
| MEM-05 | DiagnosticsBundle integration + KernelLogger replaces debugPrint | unit | `flutter test test/diagnostics/diagnostics_bundle_test.dart` | exists |

### Sampling Rate

- **Per task commit:** `flutter test test/diagnostics/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/diagnostics/memory_monitor_test.dart` — covers MEM-01, MEM-02 (FakeRssProvider/FakeClock based)
- [ ] `test/diagnostics/memory_snapshot_test.dart` — covers MEM-03 (data class tests, move from existing test/unit/kernel/utils/)
- [ ] Update existing `test/unit/kernel/utils/memory_monitor_test.dart` — migrate to instance-based tests or delete if replaced

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all SDK dependencies, zero new packages
- Architecture: HIGH — follows Phase 16/17 established patterns exactly
- Pitfalls: HIGH — R2-5 lesson well-documented, atomic migration strategy clear

**Research date:** 2026-07-20
**Valid until:** 2026-08-20 (stable — patterns established in P16/P17)
