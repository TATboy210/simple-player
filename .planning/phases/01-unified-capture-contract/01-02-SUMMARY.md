---
phase: 01-unified-capture-contract
plan: 02
subsystem: global diagnostics bootstrap
tags: [flutter, dart, global-error-hooks, zones]
requires:
  - phase: 01-01
    provides: immutable ErrorReporter contract
provides:
  - contained Flutter and dispatcher global hook adapters
  - same-zone guarded diagnostic bootstrap
  - composition-root logger initialization ownership
affects: [error-file-sink, error-card, player-error-bridge]
actuals:
  tokens: 18294
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [setter-injected global hooks, static bootstrap containment fallback]
key-files:
  created: [lib/kernel/diagnostics/global_error_hooks.dart, test/diagnostics/global_error_hooks_test.dart]
  modified: [lib/main.dart, lib/kernel/player_services.dart]
key-decisions:
  - "Install hooks only after main initializes ErrorReporterImpl inside runZonedGuarded."
  - "Use a static lifecycle-probed fallback so bootstrap reporting cannot cause a second crash."
requirements-completed: [CAP-01, CAP-02, CAP-03]
coverage:
  - id: D1
    description: Framework and dispatcher hooks preserve presentation, exact forwarding, and containment.
    requirement: CAP-02
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/global_error_hooks_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: Guarded same-zone bootstrap, reporter initialization order, and static fallback.
    requirement: CAP-01
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: Windows debug startup smoke check.
    requirement: CAP-02
    verification: []
    human_judgment: true
    rationale: "flutter run -d windows exceeded the automated 30-second startup observation window; human visual confirmation remains required."
duration: 37min
completed: 2026-08-28
status: complete
---

# Phase 1 Plan 2: Global Hook and Guarded Bootstrap Summary

**Shipped synchronous, failure-contained Flutter framework and root-isolate hooks plus a single guarded startup zone that initializes diagnostics before application services.**

## Performance
- **Duration:** 37 min
- **Started:** 2026-08-28T11:04:00Z
- **Completed:** 2026-08-28T11:41:00Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments
- Added setter-injected global error-hook seams that preserve `FlutterError.presentError`, forward exact dispatcher inputs, and always acknowledge dispatcher failures.
- Moved all startup bindings, diagnostics, hooks, window initialization, and `runApp` under one `runZonedGuarded` closure.
- Added a non-recursive static bootstrap fallback that lifecycle-checks reporter access and contains its own terminal output.
- Kept local WindowService recovery UI state and logging while forwarding one bootstrap report.
- Removed duplicate `KernelLoggerImpl.init()` ownership from PlayerServices while preserving MemoryMonitor lifecycle ownership.

## Verification
- `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart test/diagnostics/global_error_hooks_test.dart` — passed (20 tests).
- `D:/flutter/bin/flutter test test/kernel/player_services_test.dart` — passed (2 tests).
- `D:/flutter/bin/flutter analyze` — passed with no issues.
- `D:/flutter/bin/flutter test` — passed (1244 tests).
- `D:/flutter/bin/flutter run -d windows` — launched for smoke validation but did not complete inside the 30-second automated observation window; requires a developer visual check.

## Task Commits
1. **Task 1: Prove framework and dispatcher hooks reach the production reporter** - `f26f3aa` (test), `9797d1e` (feat), `a17e60c` (fix)
2. **Task 2: Put all startup work in one guarded zone and establish main as diagnostics initializer** - `897ec78` (test), `cec4df0` (feat)

## Files Created/Modified
- `lib/kernel/diagnostics/global_error_hooks.dart` - contained production/test global callback adapter.
- `lib/main.dart` - guarded bootstrap composition root and fallback.
- `lib/kernel/player_services.dart` - main-owned logger initialization contract.
- `test/diagnostics/global_error_hooks_test.dart` - hook and bootstrap containment contracts.

## Decisions Made
- Global callback failures terminate through `dart:developer.log`, never reporter or KernelLogger recursion.
- Bootstrap fallback accesses the reporter singleton only after a non-throwing initialization probe.

## Deviations from Plan

### Auto-fixed Issues
**1. [Rule 1 - Bug] Corrected initial hook type and non-const production constructor details**
- **Found during:** Task 1
- **Fix:** Replaced unavailable dispatcher typedef use with a project typedef and removed invalid const construction around `FlutterError.presentError`.
- **Verification:** Focused hooks test and analyzer passed.
- **Commit:** `a17e60c`

**Total deviations:** 1 auto-fixed. **Impact:** No scope increase.

## Issues Encountered
- Existing generated plugin registrant changes remained uncommitted and untouched.
- Windows debug smoke remains a human-observed follow-up because its process exceeded the automated observation timeout.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
The reporter now receives the framework, root-isolate, guarded-bootstrap, and existing handled-window startup paths without UI, file, or player-listener scope expansion.

## Self-Check: PASSED
- Confirmed global hook adapter, bootstrap source, service ownership update, and test artifact exist.
- Confirmed task commits `f26f3aa`, `9797d1e`, `a17e60c`, `897ec78`, and `cec4df0` exist in git history.

---
*Phase: 01-unified-capture-contract*
*Completed: 2026-08-28*
