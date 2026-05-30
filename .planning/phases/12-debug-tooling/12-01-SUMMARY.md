---
phase: 12-debug-tooling
plan: 01
subsystem: logging
tags: [logger, structured-logging, prefix-printer, module-loggers]

requires:
  - phase: none
    provides: standalone
provides:
  - "Module-scoped loggers (logEngine, logBridge, logServices, logUi)"
  - "PrefixPrinter for module name prefixing"
  - "JsonPrinter for optional structured JSON output"
  - "initLog() configures all 5 loggers with shared ProductionFilter"
affects: [12-02, 12-03]

tech-stack:
  added: []
  patterns: ["PrefixPrinter decorator pattern wrapping LogPrinter", "Module logger globals with initLog() reassignment"]

key-files:
  created:
    - test/unit/kernel/utils/log_test.dart
  modified:
    - lib/kernel/utils/log.dart

key-decisions:
  - "Used hide PrefixPrinter on logger import to avoid name conflict with logger package's own PrefixPrinter"
  - "Created custom JsonPrinter since logger 2.7.0 has no built-in JsonPrinter"
  - "ProductionFilter uses Logger level parameter (Level.warning) instead of constructor arg"
  - "jsonPrinter is final (not const) because LogPrinter lacks const constructor"

patterns-established:
  - "PrefixPrinter wraps inner LogPrinter, prepends '[moduleName]' to each line"
  - "Module loggers initialized with debug defaults, overwritten by initLog() in release"

requirements-completed: [DBG-01]

duration: 19min
completed: 2026-05-30
---

# Phase 12 Plan 01: Module Loggers Summary

**PrefixPrinter + 4 module-scoped loggers (engine/bridge/services/ui) with shared ProductionFilter(Level.warning) config in initLog()**

## Performance

- **Duration:** 19 min
- **Started:** 2026-05-30T14:31:29Z
- **Completed:** 2026-05-30T14:50:25Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- PrefixPrinter decorator prepends '[moduleName]' to each log output line
- 4 module loggers (logEngine, logBridge, logServices, logUi) alongside existing global log
- JsonPrinter for optional structured JSON output by log aggregation tools
- initLog() reassigns all 5 loggers with shared PrettyPrinter + ProductionFilter + MultiOutput in release mode
- 11 unit tests covering PrefixPrinter, module loggers, jsonPrinter, and ProductionFilter behavior

## Task Commits

Each task was committed atomically:

1. **Task 1: Add PrefixPrinter + module loggers + update initLog** - `75f4afd` (feat)
2. **Task 2: Unit tests** - completed within Task 1 TDD cycle (test file committed in Task 1)

## Files Created/Modified
- `lib/kernel/utils/log.dart` - PrefixPrinter class, JsonPrinter class, 4 module logger globals, updated initLog() with shared config for all 5 loggers
- `test/unit/kernel/utils/log_test.dart` - 11 tests: PrefixPrinter prefix behavior, module logger existence, jsonPrinter type, ProductionFilter threshold behavior

## Decisions Made
- **Logger PrefixPrinter conflict:** logger 2.7.0 exports its own `PrefixPrinter` (level-based, not module-based). Used `import 'package:logger/logger.dart' hide PrefixPrinter` to avoid name collision while exporting our custom module-name PrefixPrinter.
- **No built-in JsonPrinter:** Research assumed logger 2.7.0 had `JsonPrinter` — it does not. Created a simple custom `JsonPrinter` class producing `{"level","message","time","error","stackTrace"}` JSON lines.
- **ProductionFilter threshold:** `ProductionFilter()` takes no constructor args. Level threshold is set via `Logger(level: Level.warning)` parameter instead of `ProductionFilter(Level.warning)`.
- **const vs final:** `LogPrinter` has no const constructor, so `jsonPrinter` is `final` not `const`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Logger package PrefixPrinter name conflict**
- **Found during:** Task 1 implementation
- **Issue:** Logger 2.7.0 exports `PrefixPrinter` (level-based: DEBUG/INFO/etc), conflicting with our module-name PrefixPrinter
- **Fix:** Added `hide PrefixPrinter` to logger import, keeping our custom PrefixPrinter as the exported version
- **Files modified:** lib/kernel/utils/log.dart
- **Verification:** flutter analyze passes, tests import both without conflict

**2. [Rule 3 - Blocking] JsonPrinter does not exist in logger 2.7.0**
- **Found during:** Task 1 implementation
- **Issue:** Plan assumed `const jsonPrinter = JsonPrinter()` using logger's built-in JsonPrinter — it doesn't exist
- **Fix:** Created custom `JsonPrinter extends LogPrinter` with JSON line output (level, message, time, error, stackTrace)
- **Files modified:** lib/kernel/utils/log.dart
- **Verification:** flutter analyze passes, test verifies it's a LogPrinter instance

**3. [Rule 3 - Blocking] ProductionFilter constructor takes no args**
- **Found during:** Task 1 test writing
- **Issue:** Plan specified `ProductionFilter(Level.warning)` but constructor is no-arg
- **Fix:** Use `ProductionFilter()` with `Logger(level: Level.warning)` to set threshold
- **Files modified:** lib/kernel/utils/log.dart, test/unit/kernel/utils/log_test.dart
- **Verification:** Test confirms debug messages blocked, warning messages pass

**4. [Rule 3 - Blocking] const constructor impossible for JsonPrinter**
- **Found during:** Task 1 flutter analyze
- **Issue:** `const JsonPrinter()` fails because `LogPrinter` has no const super constructor
- **Fix:** Changed to `final jsonPrinter = JsonPrinter()` and removed const from constructor
- **Files modified:** lib/kernel/utils/log.dart
- **Verification:** flutter analyze passes

---

**Total deviations:** 4 auto-fixed (4 blocking)
**Impact on plan:** All deviations were API mismatches between plan assumptions and actual logger 2.7.0 API. Core behavior unchanged. No scope creep.

## Issues Encountered
- PrettyPrinter adds box border lines even with methodCount:0 — test assertions adjusted to check any line for message content rather than first line

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all loggers are fully functional with debug defaults and release-mode reassignment.

## Next Phase Readiness
- Module loggers available for gradual migration from global `log` to `logEngine`/`logBridge`/`logServices`/`logUi`
- JsonPrinter exported for optional use by log aggregation tools
- Ready for Phase 12 Plan 02 (Timeline events) and Plan 03 (migration)

---
*Phase: 12-debug-tooling*
*Completed: 2026-05-30*
