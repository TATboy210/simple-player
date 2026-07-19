---
phase: 17-kernellogger
plan: 01
subsystem: kernel-diagnostics
tags: [logging, dart-developer, debugprint, kdebugmode, singleton]

# Dependency graph
requires:
  - phase: 16-diagnosticsbundle
    provides: DiagnosticsBundle skeleton with logger slot, KernelLogger abstract interface, NullKernelLogger
provides:
  - Concrete KernelLoggerImpl with kDebugMode-gated sinks
  - LogLevel enum, LogSink interface, 4 sink implementations
  - Static I accessor for kernel-wide logging
  - PlayerServices composition root wiring
affects: [17-kernellogger-plan-02, 17-kernellogger-plan-03, 18-metrics, 19-eventlog, 20-migration]

# Tech tracking
tech-stack:
  added: []
  patterns: [singleton-with-state-error-guard, composite-sink-fanout, kdebugmode-compile-time-gate]

key-files:
  created:
    - lib/kernel/diagnostics/kernel_logger.dart
    - test/diagnostics/kernel_logger_impl_test.dart
  modified:
    - lib/kernel/player_services.dart

key-decisions:
  - "KernelLoggerImpl uses extends (not implements) to inherit shortcut methods from abstract KernelLogger"
  - "const KernelLogger() constructor added to abstract class to support const NullKernelLogger"
  - "this.error()/this.fatal() required in shortcut methods due to parameter name shadowing method name"

patterns-established:
  - "Singleton guard: nullable _instance + StateError (not late final) per RESEARCH anti-pattern"
  - "_redactPath strips directory prefixes from .dart:line paths to prevent local filesystem leakage"
  - "CompositeSink fans out to DevToolsSink + DebugPrintSink in debug mode"

requirements-completed: [LOG-01, LOG-02, LOG-03, LOG-05]

coverage:
  - id: D1
    description: "LogLevel enum with exactly 6 values (trace/debug/info/warn/error/fatal)"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#LogLevel has exactly 6 values in severity order
        status: pass
    human_judgment: false
  - id: D2
    description: "LogSink interface with single log() method accepting level/msg/context"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#CompositeSink delegates log() to all contained sinks
        status: pass
    human_judgment: false
  - id: D3
    description: "DevToolsSink calls dart:developer.log with name='Kernel' and severity mapping"
    requirement: LOG-02
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#DevToolsSink log() returns normally without throwing
        status: pass
    human_judgment: false
  - id: D4
    description: "DebugPrintSink calls debugPrint with level prefix and context suffix"
    requirement: LOG-02
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#DebugPrintSink formats message with level prefix
        status: pass
    human_judgment: false
  - id: D5
    description: "NullSink const no-op for release builds"
    requirement: LOG-03
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#NullSink log() is a no-op
        status: pass
    human_judgment: false
  - id: D6
    description: "CompositeSink fans out to multiple sinks"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#CompositeSink delegates log() to all contained sinks
        status: pass
    human_judgment: false
  - id: D7
    description: "KernelLoggerImpl with static I accessor (StateError guard) and init() factory"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#KernelLoggerImpl I throws StateError before init()
        status: pass
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#KernelLoggerImpl I returns same instance after init()
        status: pass
    human_judgment: false
  - id: D8
    description: "Shortcut methods (t/d/i/w/e/f) delegate to full methods with context forwarding"
    requirement: LOG-05
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#KernelLoggerImpl shortcut methods (t/d/i/w/e/f) delegate to full methods
        status: pass
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#KernelLoggerImpl shortcut methods pass context parameter through
        status: pass
    human_judgment: false
  - id: D9
    description: "_redactPath strips directory prefixes from .dart:line paths (D17)"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#_redactPath redacts directory prefixes from .dart file paths
        status: pass
      - kind: unit
        ref: test/diagnostics/kernel_logger_impl_test.dart#_redactPath redacts Windows-style paths
        status: pass
    human_judgment: false
  - id: D10
    description: "PlayerServices.init() wires KernelLoggerImpl into DiagnosticsBundle"
    requirement: LOG-01
    verification:
      - kind: unit
        ref: test/diagnostics/diagnostics_bundle_test.dart#all 4 slots are non-null and callable as no-ops
        status: pass
    human_judgment: false

# Metrics
duration: 20min
completed: 2026-07-19
status: complete
---

# Phase 17 Plan 01: KernelLogger Facade Summary

**Concrete KernelLogger facade with kDebugMode-gated DevTools+debugPrint sinks, wired into PlayerServices composition root**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-19T13:00:34Z
- **Completed:** 2026-07-19T13:20:55Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Implemented LogLevel enum (6 levels), LogSink interface, and 4 concrete sinks (DevToolsSink, DebugPrintSink, NullSink, CompositeSink)
- KernelLoggerImpl with static `I` accessor (StateError guard, nullable `_instance` pattern per RESEARCH anti-pattern)
- `_redactPath()` strips directory prefixes from `.dart:line` paths to prevent local filesystem leakage (D17)
- Shortcut methods (t/d/i/w/e/f) with context parameter forwarding
- PlayerServices.init() calls KernelLoggerImpl.init() before engine creation; DiagnosticsBundle activated with real logger
- All 26 tests pass (16 new + 10 existing), flutter analyze clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement LogLevel + LogSink + sinks + KernelLoggerImpl** - `a0b54dc` (test: RED) + `16671af` (feat: GREEN)
2. **Task 2: Wire KernelLogger in PlayerServices.init()** - `9996666` (feat)

## Files Created/Modified
- `lib/kernel/diagnostics/kernel_logger.dart` - Concrete KernelLogger facade (~310 lines): LogLevel, LogSink, 4 sinks, KernelLoggerImpl, NullKernelLogger updated
- `test/diagnostics/kernel_logger_impl_test.dart` - 16 behavioral tests for all new types
- `lib/kernel/player_services.dart` - Composition root wiring: KernelLoggerImpl.init() + DiagnosticsBundle with real logger

## Decisions Made
- `KernelLoggerImpl extends KernelLogger` (not `implements`) to inherit shortcut method implementations from the abstract class
- Added `const KernelLogger()` constructor to abstract class so `const NullKernelLogger()` can extend it
- `this.error()/this.fatal()` required in shortcut methods `e()/f()` because the `error` parameter name shadows the method name

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] NullKernelLogger must extend (not implement) to inherit shortcuts**
- **Found during:** Task 1 (GREEN phase test run)
- **Issue:** `NullKernelLogger implements KernelLogger` does not inherit concrete shortcut methods (t/d/i/w/e/f) from the abstract class
- **Fix:** Changed to `NullKernelLogger extends KernelLogger` and added `const KernelLogger()` constructor
- **Files modified:** `lib/kernel/diagnostics/kernel_logger.dart`
- **Verification:** All 26 tests pass
- **Committed in:** `16671af`

**2. [Rule 1 - Bug] Shortcut method parameter name shadows method name**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** In `e()` and `f()` shortcuts, the `Object? error` parameter shadows the `error()` method, causing `unchecked_use_of_nullable_value`
- **Fix:** Use `this.error(...)` and `this.fatal(...)` for disambiguation (analyzer correctly recognizes the necessity)
- **Files modified:** `lib/kernel/diagnostics/kernel_logger.dart`
- **Verification:** flutter analyze passes with zero issues
- **Committed in:** `16671af`

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all implemented types are functional.

## Threat Flags

No new threat surface beyond what the plan's threat_model already covers:
- T-17-01 (Information Disclosure): Mitigated by kDebugMode compile-time gate (NullSink in release)
- T-17-02 (DevTools): Accepted (dart:developer.log is no-op when DevTools not connected)
- T-17-03 (Tampering): Accepted (developer-controlled format strings, no injection surface)

## Next Phase Readiness
- Plan 02 (78-site migration) can now use `KernelLoggerImpl.I` at all existing `logEngine/logBridge/logServices/logUi` call sites
- Plan 03 (CI gate) can add `grep` check for `debugPrint` in `lib/kernel/`

---
*Phase: 17-kernellogger*
*Completed: 2026-07-19*

## Self-Check: PASSED

All created files exist:
- `lib/kernel/diagnostics/kernel_logger.dart` — FOUND
- `test/diagnostics/kernel_logger_impl_test.dart` — FOUND
- `lib/kernel/player_services.dart` — FOUND
- `.planning/phases/17-kernellogger/17-01-SUMMARY.md` — FOUND

All task commits exist:
- `a0b54dc` (test: RED phase) — FOUND
- `16671af` (feat: GREEN phase) — FOUND
- `9996666` (feat: wiring) — FOUND
