---
phase: 19-memorymonitor
plan: 01
subsystem: diagnostics
tags: [memory, rss, clock, dependency-injection, diagnostics, value-notifier]

# Dependency graph
requires:
  - phase: 16-diagnosticsbundle
    provides: MemoryMonitorSlot interface, DiagnosticsBundle, NullMemoryMonitorSlot
  - phase: 17-kernellogger
    provides: KernelLogger abstract class, KernelLoggerImpl, LogLevel, LogSink
provides:
  - RssProvider abstraction (ProcessInfoRssProvider + FakeRssProvider)
  - Clock abstraction (SystemClock + FakeClock)
  - MetricSample + MemorySnapshot data classes (extracted from legacy)
  - Instance-based MemoryMonitor implementing MemoryMonitorSlot
affects: [19-02, 20-newfvpengine]

# Tech tracking
tech-stack:
  added: []
  patterns: [dependency-injection, abstract-class-with-fake, ring-buffer, idempotent-lifecycle]

key-files:
  created:
    - lib/kernel/diagnostics/rss_provider.dart
    - lib/kernel/diagnostics/clock.dart
    - lib/kernel/diagnostics/memory_snapshot.dart
    - lib/kernel/diagnostics/memory_monitor.dart
    - test/diagnostics/memory_snapshot_test.dart
    - test/diagnostics/memory_monitor_test.dart
  modified:
    - lib/kernel/diagnostics/clock.dart (FakeClock setter renamed to currentTime)

key-decisions:
  - "FakeClock setter renamed from `now` to `currentTime` to avoid Dart name collision with abstract method"
  - "MemoryMonitor constructor auto-starts timer (D5) — no separate start() call needed"
  - "KernelLogger used for all logging (replaces debugPrint) for MEM-05 readiness"

patterns-established:
  - "Abstract+Fake pattern: RssProvider/Clock with production + fake implementations, no mocktail"
  - "Idempotent lifecycle: start() guarded by _timer!=null, dispose() guarded by _disposed flag"
  - "Ring buffer: while (_history.length > maxHistory) _history.removeAt(0)"

requirements-completed: [MEM-01, MEM-02, MEM-03]

# Coverage metadata
coverage:
  - id: D1
    description: "RssProvider abstract + ProcessInfoRssProvider + FakeRssProvider in rss_provider.dart"
    requirement: MEM-01
    verification:
      - kind: unit
        ref: "test/diagnostics/memory_snapshot_test.dart (compilation validates imports)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Clock abstract + SystemClock + FakeClock in clock.dart"
    requirement: MEM-01
    verification:
      - kind: unit
        ref: "test/diagnostics/memory_monitor_test.dart (FakeClock used in all tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "MetricSample + MemorySnapshot data classes extracted to memory_snapshot.dart with toJson()"
    requirement: MEM-02
    verification:
      - kind: unit
        ref: "test/diagnostics/memory_snapshot_test.dart (5 tests: stores, toJson, history)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MemoryMonitor implements MemoryMonitorSlot, injectable, testable, zero playback interference"
    requirement: MEM-03
    verification:
      - kind: unit
        ref: "test/diagnostics/memory_monitor_test.dart (13 tests: lifecycle, idempotent, threshold, onTick, ring buffer)"
        status: pass
    human_judgment: false
  - id: D5
    description: "KernelLogger replaces debugPrint for all logging (warn for threshold, info for RSS)"
    requirement: MEM-03
    verification:
      - kind: unit
        ref: "test/diagnostics/memory_monitor_test.dart#threshold warning triggers KernelLogger.warn"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-07-20
status: complete
---

# Plan 19-01: MemoryMonitor Abstraction Layer Summary

**Instance-based MemoryMonitor with RssProvider/Clock injection, 18 passing tests, zero playback interference**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-20
- **Completed:** 2026-07-20
- **Tasks:** 2
- **Files created:** 6

## Accomplishments
- RssProvider/Clock abstractions with production and fake implementations (no mocktail)
- MetricSample/MemorySnapshot data classes extracted from legacy singleton
- Instance-based MemoryMonitor implementing Phase 16's MemoryMonitorSlot interface
- Constructor auto-starts timer (D5), idempotent start/dispose lifecycle
- KernelLogger replaces debugPrint for all logging (MEM-05 readiness)
- 18 tests total: 5 data class + 13 monitor (lifecycle, threshold, onTick, ring buffer, clock injection)

## Task Commits

Each task was committed atomically:

1. **Task 1: RssProvider + Clock abstractions and data class extraction** - `b8b5218` (feat)
2. **Task 2: Instance-based MemoryMonitor implementation** - `eb9c123` (feat)

## Files Created/Modified
- `lib/kernel/diagnostics/rss_provider.dart` - RssProvider abstract + ProcessInfoRssProvider + FakeRssProvider
- `lib/kernel/diagnostics/clock.dart` - Clock abstract + SystemClock + FakeClock
- `lib/kernel/diagnostics/memory_snapshot.dart` - MetricSample + MemorySnapshot data classes (extracted)
- `lib/kernel/diagnostics/memory_monitor.dart` - Instance-based MemoryMonitor implementing MemoryMonitorSlot
- `test/diagnostics/memory_snapshot_test.dart` - Data class tests (5 tests)
- `test/diagnostics/memory_monitor_test.dart` - MemoryMonitor tests (13 tests)

## Decisions Made
- FakeClock setter renamed from `now` to `currentTime` to avoid Dart name collision with abstract `now()` method
- MemoryMonitor constructor auto-starts timer per D5 (no separate start() call needed)
- KernelLogger used for all logging instead of debugPrint for MEM-05 readiness

## Deviations from Plan

### Auto-fixed Issues

**1. FakeClock setter name collision**
- **Found during:** Task 1 (clock.dart compilation)
- **Issue:** Dart doesn't allow `set now()` alongside abstract `DateTime now()` in the same class hierarchy
- **Fix:** Renamed setter to `currentTime`
- **Files modified:** `lib/kernel/diagnostics/clock.dart`
- **Verification:** All 18 tests pass
- **Committed in:** Task 2 commit (eb9c123)

**2. Dangling library doc comments**
- **Found during:** flutter analyze after Task 1
- **Issue:** Library doc comments without `library;` directive
- **Fix:** Added `library;` directive to all 4 new files
- **Files modified:** All 4 new source files
- **Verification:** flutter analyze shows 0 issues in new files
- **Committed in:** Task 2 commit (eb9c123)

**3. Non-overriding @override annotation**
- **Found during:** flutter analyze after Task 1
- **Issue:** `@override` on `snapshotNotifier` field which doesn't override MemoryMonitorSlot
- **Fix:** Removed `@override` annotation
- **Files modified:** `lib/kernel/diagnostics/memory_monitor.dart`
- **Verification:** flutter analyze clean
- **Committed in:** Task 2 commit (eb9c123)

---

**Total deviations:** 3 auto-fixed (1 naming collision, 2 lint issues)
**Impact on plan:** Minor lint/naming fixes, no scope creep. All fixes committed with Task 2.

## Issues Encountered
None beyond the auto-fixed deviations above.

## Next Phase Readiness
- All abstraction + implementation files ready for Plan 02 (atomic singleton-to-instance migration)
- Old `lib/kernel/utils/memory_monitor.dart` preserved (Plan 02 handles deletion + call site migration)
- DiagnosticsBundle can now accept real MemoryMonitor instance instead of NullMemoryMonitorSlot

---
*Phase: 19-memorymonitor*
*Completed: 2026-07-20*
