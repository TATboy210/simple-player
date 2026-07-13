# Quality Pipeline Assessment — Simple Player Flutter

**Scope:** Test coverage tools + performance benchmarks evaluation
**Date:** 2026-07-13
**Status:** Evaluation only — no code changes, no CI/CD configuration

> This document assesses the project's current quality monitoring capabilities, compares them against Flutter ecosystem tools, identifies gaps, and provides integration recommendations. Static analysis (flutter analyze + strict-casts/strict-inference) is already complete and out of scope for this evaluation.

---

## 1. Current Capabilities Matrix

### 1.1 Frame Timing & Jank Detection — `PerfMonitor`

**File:** `lib/kernel/utils/perf_monitor.dart` (162 lines)

| Capability | Detail | Status |
|-----------|--------|--------|
| Build time tracking | Per-frame build duration via `FrameTiming.buildDuration` | Implemented |
| Raster time tracking | Per-frame raster duration via `FrameTiming.rasterDuration` | Implemented |
| Jank detection threshold | 16ms (60fps budget: 1000/60 ≈ 16.67ms) | Implemented |
| Slow frame logging | `developer.log` with build/raster breakdown | Implemented |
| Statistical summary | avg/max for build and raster, every 100 frames | Implemented |
| JSON export | `exportStats()` returns frameCount, build.avgMs, build.maxMs, raster.avgMs, raster.maxMs | Implemented |
| Ring buffer | 300-frame fixed capacity, no memory leak | Implemented |
| Enable/disable toggle | `enable()` / `disable()` with `SchedulerBinding.addTimingsCallback` | Implemented |
| FPS calculation | Not implemented | Gap |
| Jank percentage | Not implemented | Gap |
| Timeline event export | Not implemented (only `developer.log`) | Gap |

**Summary:** PerfMonitor provides solid build/raster timing with jank detection at 16ms threshold. It tracks avg/max stats and exports JSON. Missing: FPS calculation, jank percentage, and structured timeline export for DevTools.

### 1.2 Memory Tracking — `MemoryMonitor`

**File:** `lib/kernel/utils/memory_monitor.dart` (193 lines)

| Capability | Detail | Status |
|-----------|--------|--------|
| RSS tracking | `ProcessInfo.currentRss` sampled periodically | Implemented |
| Peak RSS | Tracks max RSS across sampling history | Implemented |
| Growth threshold alert | 50MB delta triggers `debugPrint` warning | Implemented |
| Sampling interval | Configurable (default 30s) | Implemented |
| History buffer | 200-sample ring buffer | Implemented |
| ValueNotifier exposure | `snapshotNotifier` for reactive UI binding | Implemented |
| JSON export | `exportJson()` with RSS, peak, history | Implemented |
| Dart heap tracking | Not implemented (RSS only) | Gap |
| Allocation profiling | Not implemented | Gap |
| GC event tracking | Not implemented | Gap |
| Memory leak detection | Not implemented (only growth alert) | Gap |

**Summary:** MemoryMonitor tracks RSS with peak detection and growth alerts. It provides a reactive ValueNotifier for UI binding. Missing: Dart heap details, allocation profiling, GC tracking, and leak detection.

### 1.3 Engine Metrics — `EngineMetrics`

**File:** `lib/kernel/engine/engine_metrics.dart` (91 lines)

| Capability | Detail | Status |
|-----------|--------|--------|
| Frame drops | `framesDropped` counter from D3D11 pipeline | Implemented |
| Decode errors | `decodeErrors` counter | Implemented |
| Buffer underruns | `bufferUnderruns` counter | Implemented |
| Seek latency | Cumulative + average seek time | Implemented |
| Open success rate | Attempts/failures/rate calculation | Implemented |
| JSON export | `toJson()` for UI display | Implemented |
| Trend analysis | Not implemented (counters only) | Gap |
| Percentile latency | Not implemented (only average) | Gap |

**Summary:** EngineMetrics tracks playback health counters (drops, errors, underruns) and operation stats (seek latency, open rate). Missing: trend analysis over time and percentile-based latency (p50/p95/p99).

### 1.4 Static Analysis

**File:** `analysis_options.yaml`

| Rule | Status |
|------|--------|
| `strict-casts: true` | Enabled |
| `strict-inference: true` | Enabled |
| `strict-raw-types: true` | Enabled |
| `missing_required_param: error` | Enabled |
| `missing_return: error` | Enabled |
| `dead_code: warning` | Enabled |
| Lint rules (prefer_const, avoid_print, etc.) | 12 rules enabled |

**Summary:** Static analysis is complete. Strict mode is fully enabled with 12 additional lint rules. No gap.

### 1.5 Test Coverage

| Metric | Value |
|--------|-------|
| Test files in `test/` | 95 files |
| Test files in `lib/` | 0 (no co-located tests) |
| Coverage collection | `flutter test --coverage` produces `coverage/lcov.info` |
| Coverage threshold | Not enforced |
| Coverage reporting | Not configured (no HTML report, no CI integration) |

**Summary:** 95 test files exist across unit, widget, integration, golden, perf, and regression categories. Coverage data is collectible but not enforced or reported.

---

## 2. Flutter Ecosystem Tool Comparison

### 2.1 Test Coverage Tools

| Tool | What It Does | Current Status | Gap |
|------|-------------|----------------|-----|
| `flutter test --coverage` | Generates `lcov.info` coverage data | Available (Flutter 3.44.6) | No threshold enforcement, no reporting |
| `genhtml` (lcov) | Converts lcov.info to HTML report | Not installed | Need to install lcov tools |
| `coverage` package | lcov parsing, badge generation | Not used | Could generate coverage badges |
| `test_coverage` package | Continuous coverage with thresholds | Not used | Could enforce minimum coverage % |
| Codecov / Coveralls | Cloud coverage tracking with PR integration | Not used | Requires CI setup (out of scope) |

### 2.2 Performance Benchmark Tools

| Tool | What It Measures | Current Status | Gap |
|------|-----------------|----------------|-----|
| `PerfMonitor` (existing) | Build/raster frame timing, jank at 16ms | Implemented | No FPS calc, no formal benchmark suite |
| `flutter run --profile` | Profile-mode runtime with DevTools connection | Available | Not used for benchmarking |
| DevTools Performance tab | Visual timeline, frame-by-frame analysis | Available (Flutter SDK) | Not integrated into workflow |
| `flutter benchmark` | Official benchmark runner (if available) | Not verified | May need custom harness |
| `benchmark_harness` package | Micro-benchmark framework | Not used | Could wrap PerfMonitor for formal benchmarks |
| Custom benchmark harness | Startup time, seek latency, memory peak | Not created | Recommended for project-specific metrics |

### 2.3 Memory Profiling Tools

| Tool | What It Provides | Current Status | Gap |
|------|-----------------|----------------|-----|
| `MemoryMonitor` (existing) | RSS tracking, peak detection, growth alerts | Implemented | No Dart heap, no allocation profiling |
| DevTools Memory tab | Heap snapshots, allocation tracking, GC events | Available (Flutter SDK) | Not integrated into workflow |
| `flutter run --profile` + DevTools | Full memory timeline with snapshots | Available | Not used for profiling |
| `ProcessInfo.currentRss` | OS-level RSS (what MemoryMonitor uses) | Implemented | No Dart VM heap details |

---

## 3. Gap Analysis

### 3.1 Test Coverage Gaps

| What We Have | What We Need | Priority |
|-------------|-------------|----------|
| 95 test files, `flutter test --coverage` works | Coverage threshold enforcement (e.g., 80% minimum) | P1 — Immediate |
| lcov.info generated | HTML coverage report for visual inspection | P2 — Short-term |
| No coverage tracking over time | Coverage trend tracking (regression detection) | P3 — Long-term |

### 3.2 Performance Benchmark Gaps

| What We Have | What We Need | Priority |
|-------------|-------------|----------|
| PerfMonitor tracks frame timing | Formal benchmark suite with baseline values | P2 — Short-term |
| EngineMetrics tracks seek/open latency | Percentile latency (p50/p95/p99) | P2 — Short-term |
| No startup time measurement | Startup time benchmark (cold/warm start) | P1 — Immediate |
| No memory peak benchmark | Memory peak benchmark under load | P2 — Short-term |

### 3.3 Memory Profiling Gaps

| What We Have | What We Need | Priority |
|-------------|-------------|----------|
| RSS tracking via MemoryMonitor | Dart heap size tracking | P2 — Short-term |
| Growth threshold alerts | Allocation rate profiling | P3 — Long-term |
| No leak detection | Leak detection heuristics | P3 — Long-term |

### 3.4 No Gap (Complete)

| Dimension | Status |
|-----------|--------|
| Static analysis | Complete — strict-casts, strict-inference, strict-raw-types, 12 lint rules |
| Code review hooks | Complete — code-review-graph PostToolUse + SessionStart hooks configured |

---

## 4. Recommendations

### Priority 1 — Immediate

**R1: Add coverage threshold to test workflow**

| Detail | Value |
|--------|-------|
| Tool | `flutter test --coverage` + custom threshold check |
| Why | 95 tests exist but no minimum enforced; coverage can silently regress |
| Integration steps | See Section 5.1 |
| Effort | ~30 minutes |

**R2: Add startup time measurement**

| Detail | Value |
|--------|-------|
| Tool | Custom stopwatch in `main.dart` + `PerfMonitor` |
| Why | Startup time is a key user experience metric with no current tracking |
| Integration steps | See Section 5.2 |
| Effort | ~1 hour |

### Priority 2 — Short-term

**R3: Create benchmark suite**

| Detail | Value |
|--------|-------|
| Tool | Custom harness using `benchmark_harness` or manual timer |
| Why | PerfMonitor tracks runtime performance but no formal benchmarks with baselines |
| Integration steps | See Section 5.3 |
| Effort | ~2-3 hours |

**R4: Add percentile latency to EngineMetrics**

| Detail | Value |
|--------|-------|
| Tool | Extension to existing `EngineMetrics` |
| Why | Average latency hides outliers; p95/p99 reveal real user experience |
| Integration steps | See Section 5.4 |
| Effort | ~1 hour |

**R5: Generate HTML coverage report**

| Detail | Value |
|--------|-------|
| Tool | `genhtml` (lcov tools) or `coverage` package |
| Why | Visual coverage report makes gaps obvious at a glance |
| Integration steps | See Section 5.5 |
| Effort | ~30 minutes |

### Priority 3 — Long-term

**R6: DevTools integration for deeper profiling**

| Detail | Value |
|--------|-------|
| Tool | Flutter DevTools (Memory, Performance tabs) |
| Why | RSS tracking is coarse; DevTools provides heap snapshots, allocation tracking, GC events |
| Integration steps | See Section 5.6 |
| Effort | ~1 hour setup + ongoing usage |

**R7: Dart heap tracking in MemoryMonitor**

| Detail | Value |
|--------|-------|
| Tool | `dart:developer` `Service` API or DevTools protocol |
| Why | RSS includes non-Dart memory; Dart heap is more relevant for leak detection |
| Integration steps | See Section 5.7 |
| Effort | ~2 hours |

---

## 5. Integration Steps

### 5.1 Coverage Threshold (R1)

```bash
# Run tests with coverage
flutter test --coverage

# Check coverage percentage (requires lcov or custom script)
# Option A: Using lcov
lcov --summary coverage/lcov.info

# Option B: Custom Dart script (recommended for CLAUDE.md)
dart run tool/check_coverage.dart --min 80
```

**CLAUDE.md addition:**
```markdown
## Coverage
- Run: `flutter test --coverage`
- Threshold: 80% minimum (enforced by `tool/check_coverage.dart`)
- Report: `coverage/lcov.info` (generate HTML with `genhtml`)
```

### 5.2 Startup Time Benchmark (R2)

```dart
// In main.dart, before runApp():
final sw = Stopwatch()..start();
// ... after first frame:
sw.stop();
debugPrint('[Startup] Cold start: ${sw.elapsedMilliseconds}ms');
```

**CLAUDE.md addition:**
```markdown
## Startup Benchmark
- Cold start target: < 2000ms
- Measure: Stopwatch in main.dart from init to first frame
```

### 5.3 Benchmark Suite (R3)

```
benchmarks/
├── startup_benchmark.dart    # Cold/warm start time
├── seek_benchmark.dart       # Seek latency p50/p95/p99
├── memory_benchmark.dart     # Memory peak under load
└── README.md                 # How to run benchmarks
```

**Run command:** `dart run benchmarks/startup_benchmark.dart`

### 5.4 Percentile Latency (R4)

Add to `EngineMetrics`:
```dart
final List<int> _seekLatenciesMs = [];

Duration get p50SeekTime => _percentile(50);
Duration get p95SeekTime => _percentile(95);
Duration get p99SeekTime => _percentile(99);

Duration _percentile(int p) {
  if (_seekLatenciesMs.isEmpty) return Duration.zero;
  final sorted = List<int>.from(_seekLatenciesMs)..sort();
  final idx = (p / 100 * sorted.length).ceil() - 1;
  return Duration(milliseconds: sorted[idx.clamp(0, sorted.length - 1)]);
}
```

### 5.5 HTML Coverage Report (R5)

```bash
# Install lcov (Windows: via scoop or chocolatey)
scoop install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
start coverage/html/index.html
```

### 5.6 DevTools Integration (R6)

```bash
# Run in profile mode
flutter run --profile -d windows

# In another terminal, open DevTools
flutter devtools
```

**Workflow:**
1. Run app in profile mode
2. Open DevTools → Performance tab → record timeline
3. Open DevTools → Memory tab → take heap snapshot
4. Compare snapshots before/after operations

### 5.7 Dart Heap Tracking (R7)

```dart
// Use dart:developer Service API
import 'dart:developer';

final vm = await Service.getInfo();
// Access VM heap info via service protocol
```

**Note:** This requires running in profile/debug mode and accessing the VM service protocol. More complex than RSS tracking — recommend using DevTools Memory tab directly for heap analysis.

---

## 6. Notes

- This document is evaluation only. No CI/CD configuration is included.
- Current project is a local desktop app — CI integration recommended for future when applicable.
- Reference existing code: `lib/kernel/utils/perf_monitor.dart`, `lib/kernel/utils/memory_monitor.dart`, `lib/kernel/engine/engine_metrics.dart`
- Static analysis is complete (strict mode enabled in `analysis_options.yaml`) — no further evaluation needed.
- All recommendations are local-first (no cloud services required) except R3's optional Codecov/Coveralls integration.
