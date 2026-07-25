---
phase: 19-memorymonitor
plan: 02
subsystem: diagnostics
tags: [memory, singleton-removal, dependency-injection, atomic-migration, memory-monitor]

# Dependency graph
requires:
  - phase: 16-diagnosticsbundle
    provides: MemoryMonitorSlot interface, DiagnosticsBundle, NullMemoryMonitorSlot
  - phase: 17-kernellogger
    provides: KernelLoggerImpl static I accessor pattern
  - phase: 19-memorymonitor
    plan: 01
    provides: Instance-based MemoryMonitor, RssProvider, Clock, MemorySnapshot data classes
provides:
  - Static MemoryMonitor.I accessor (KernelLoggerImpl.I pattern)
  - MemoryMonitor wired into DiagnosticsBundle via PlayerServices.init()
  - Old singleton deleted, all call sites migrated
affects: [20-newfvpengine]

# Tech tracking
tech-stack:
  added: []
  patterns: [static-i-accessor, atomic-singleton-migration]

key-files:
  created: []
  modified:
    - lib/kernel/diagnostics/memory_monitor.dart (static I accessor added)
    - lib/kernel/player_services.dart (wires MemoryMonitor into DiagnosticsBundle)
    - lib/main.dart (removed old MemoryMonitor.start() call)
    - lib/kernel/utils/debug_exporter.dart (uses MemoryMonitor.I.snapshot())
    - lib/kernel/diagnostics/memory_snapshot.dart (library directive added)
    - test/diagnostics/memory_snapshot_test.dart (library directive added)
  deleted:
    - lib/kernel/utils/memory_monitor.dart (old static singleton)
    - test/kernel/utils/memory_monitor_test.dart (old singleton tests)
    - test/unit/kernel/utils/memory_monitor_test.dart (old unit tests)

key-decisions:
  - "Static I accessor follows KernelLoggerImpl.I pattern from Phase 17 (nullable + StateError guard)"
  - "MemoryMonitor.init() called in PlayerServices.init() before DiagnosticsBundle construction"
  - "DebugExporter uses MemoryMonitor.I static accessor (not parameter-passing) for consistency with KernelLoggerImpl.I"
  - "Fixed pre-existing KernelLogger.I → KernelLoggerImpl.I bug in debug_exporter.dart"

patterns-established:
  - "Atomic singleton-to-instance migration: all changes in ONE commit (R2-5 lesson)"
  - "Static I accessor pattern: _instance nullable + StateError guard + init() + resetForTesting()"

requirements-completed: [MEM-04, MEM-05]

# Coverage metadata
coverage:
  - id: D1
    description: "Static MemoryMonitor.I accessor added (KernelLoggerImpl.I pattern)"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/diagnostics/memory_monitor.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "MemoryMonitor wired into DiagnosticsBundle via PlayerServices.init()"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/player_services.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Old singleton deleted, all call sites migrated (main.dart, debug_exporter.dart)"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "grep -r 'utils/memory_monitor' lib/ test/ returns 0 dart import results"
        status: pass
    human_judgment: false
  - id: D4
    description: "Zero references to old utils/memory_monitor.dart in lib/ and test/"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "grep -r 'utils/memory_monitor' lib/ returns 0 results"
        status: pass
    human_judgment: false
  - id: D5
    description: "Zero MemoryMonitor._ private access in lib/"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "grep -r 'MemoryMonitor\\._' lib/ returns 0 results"
        status: pass
    human_judgment: false
  - id: D6
    description: "Zero debugPrint in MemoryMonitor (KernelLogger replaces debugPrint)"
    requirement: MEM-05
    verification:
      - kind: unit
        ref: "grep -r 'debugPrint.*MemoryMonitor' lib/kernel/ returns 0 results"
        status: pass
    human_judgment: false
  - id: D7
    description: "diagnostics_bundle_test passes with noop bundle"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "test/diagnostics/diagnostics_bundle_test.dart (3 tests pass)"
        status: pass
    human_judgment: false
  - id: D8
    description: "All 63 diagnostics tests pass"
    requirement: MEM-04
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/ (63 tests)"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-07-20
status: complete
---

# Phase 19 Plan 02: Atomic Singleton-to-Instance MemoryMonitor Migration Summary

**Static MemoryMonitor singleton removed, instance wired into DiagnosticsBundle via PlayerServices, all call sites migrated in one atomic commit**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-20
- **Completed:** 2026-07-20
- **Tasks:** 2 (executed as 1 atomic commit per MEM-04/R2-5)
- **Files modified:** 6
- **Files deleted:** 3

## Accomplishments
- Added static `MemoryMonitor.I` accessor following KernelLoggerImpl.I pattern (nullable + StateError guard)
- Wired real MemoryMonitor into DiagnosticsBundle via PlayerServices.init() (replaces NullMemoryMonitorSlot)
- Migrated main.dart: removed `MemoryMonitor.start()` call (bundle auto-starts via constructor)
- Migrated debug_exporter.dart: `MemoryMonitor.I.snapshot()` replaces old static call
- Deleted old `lib/kernel/utils/memory_monitor.dart` singleton (data classes already in diagnostics/memory_snapshot.dart)
- Deleted 2 old test files that tested the static API
- Fixed pre-existing `KernelLogger.I` bug in debug_exporter.dart (should be `KernelLoggerImpl.I`)

## Task Commits

Both tasks committed atomically as ONE commit per MEM-04 (R2-5 lesson: never split singleton removal):

1. **Task 1+2: Atomic singleton-to-instance migration** - `0f73d26` (refactor)

## Files Created/Modified
- `lib/kernel/diagnostics/memory_monitor.dart` - Static I accessor + init() + resetForTesting()
- `lib/kernel/player_services.dart` - Creates MemoryMonitor instance, calls MemoryMonitor.init(), wires into bundle
- `lib/main.dart` - Removed old import and MemoryMonitor.start() call
- `lib/kernel/utils/debug_exporter.dart` - New import path, MemoryMonitor.I.snapshot(), KernelLoggerImpl.I fix
- `lib/kernel/diagnostics/memory_snapshot.dart` - Added library directive
- `test/diagnostics/memory_snapshot_test.dart` - Added library directive

## Files Deleted
- `lib/kernel/utils/memory_monitor.dart` - Old static singleton (replaced by diagnostics/memory_monitor.dart)
- `test/kernel/utils/memory_monitor_test.dart` - Old singleton tests
- `test/unit/kernel/utils/memory_monitor_test.dart` - Old unit tests (duplicate of above)

## Decisions Made
- Static I accessor follows KernelLoggerImpl.I pattern (nullable + StateError, not late final)
- MemoryMonitor.init() called in PlayerServices.init() before DiagnosticsBundle construction
- DebugExporter uses static I accessor (not parameter-passing) for consistency with Phase 17 pattern
- All migration in ONE atomic commit per R2-5 lesson (never split singleton removal)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing KernelLogger.I error in debug_exporter.dart**
- **Found during:** Task 2 (debug_exporter.dart migration)
- **Issue:** `KernelLogger.I` used on abstract class; `I` is only on `KernelLoggerImpl`
- **Fix:** Changed to `KernelLoggerImpl.I`
- **Files modified:** `lib/kernel/utils/debug_exporter.dart`
- **Verification:** flutter analyze passes on the file
- **Committed in:** `0f73d26` (atomic commit)

**2. [Rule 3 - Missing Critical] Additional old test file discovered**
- **Found during:** Task 2 (grep verification)
- **Issue:** `test/unit/kernel/utils/memory_monitor_test.dart` also imports old singleton path (not listed in plan)
- **Fix:** Deleted the file
- **Files modified:** `test/unit/kernel/utils/memory_monitor_test.dart` (deleted)
- **Verification:** grep returns 0 results for utils/memory_monitor in dart files
- **Committed in:** `0f73d26` (atomic commit)

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 missing deletion)
**Impact on plan:** Both fixes essential for clean migration. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MemoryMonitor fully migrated: injectable, testable, bundle-integrated
- All code uses new instance-based MemoryMonitor from lib/kernel/diagnostics/
- Old singleton completely removed, zero dangling references
- Ready for Phase 20 (NewFvpEngine) which will consume DiagnosticsBundle with real MemoryMonitor

---
*Phase: 19-memorymonitor*
*Completed: 2026-07-20*
