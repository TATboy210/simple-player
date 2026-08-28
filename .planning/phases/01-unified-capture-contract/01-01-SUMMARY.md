---
phase: 01-unified-capture-contract
plan: 01
subsystem: kernel diagnostics
tags: [flutter, dart, diagnostics, error-reporting, fifo, value-notifier]

requires: []
provides:
  - "Immutable ErrorReport and ErrorPresentationState contracts for all four capture boundaries"
  - "Bounded five-entry FIFO reporter with 10-second in-queue deduplication"
  - "Failure-isolated effects, notifier publication, and reentrant intake containment"
affects: [global-error-hooks, error-file-sink, error-card, player-error-bridge]

actuals:
  tokens: 8545
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Primitive snapshot normalization before local queue insertion"
    - "Queue-local fingerprint dedupe with immutable in-slot replacement"
    - "ValueNotifier presentation readiness handoff without UI coupling"

key-files:
  created:
    - lib/kernel/diagnostics/error_report.dart
    - lib/kernel/diagnostics/error_reporting_dependencies.dart
    - lib/kernel/diagnostics/error_reporter.dart
    - test/diagnostics/error_report_test.dart
    - test/diagnostics/error_reporter_test.dart
  modified: []

key-decisions:
  - "Use a five-entry local presentation FIFO with a 10-second queue-local dedupe window."
  - "Use one explicit unavailable-original-stack marker instead of inventing reporter throw-site stacks."
  - "Snapshot PlayerError primitives at intake so later ErrorContext mutation cannot alter accepted reports."

patterns-established:
  - "Error effects receive a ReportAcceptance disposition for every accepted new or merged capture."
  - "Last-resort containment never re-enters the reporter, logger, or UI."

requirements-completed: [CAP-01, CAP-03, CAP-04]

coverage:
  - id: D1
    description: "Immutable report values, event IDs, timestamps, stack snapshots, and presentation state"
    requirement: "CAP-01"
    verification:
      - kind: unit
        ref: "flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "All four reporter adapters preserve bounded primitive snapshots and PlayerError source precedence"
    requirement: "CAP-01"
    verification:
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#ErrorReporterImpl adapters"
        status: pass
    human_judgment: false
  - id: D3
    description: "Failure-isolated effects, notifier listeners, collaborators, and reentrant reporting"
    requirement: "CAP-03"
    verification:
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#ErrorReporterImpl fault isolation"
        status: pass
    human_judgment: false
  - id: D4
    description: "Five-entry FIFO, 10-second dedupe, dismissal, idempotent flush, and 100/1000-event bounds"
    requirement: "CAP-04"
    verification:
      - kind: unit
        ref: "test/diagnostics/error_reporter_test.dart#ErrorReporterImpl queue policy"
        status: pass
    human_judgment: false
  - id: D5
    description: "Strict static analysis and full Flutter test suite"
    verification:
      - kind: other
        ref: "flutter analyze && flutter test"
        status: pass
    human_judgment: false

duration: 34min
completed: 2026-08-28
status: complete
---

# Phase 1 Plan 1: Unified Capture Contract Summary

**Shipped a local, immutable four-source error reporter that snapshots unsafe diagnostic inputs, retains a five-item FIFO, merges immediate repeats, and prevents reporting failures from cascading into the player.**

## Performance
- **Duration:** 34 min
- **Started:** 2026-08-28T10:16:00Z
- **Completed:** 2026-08-28T10:49:46Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments
- Created immutable report and presentation contracts with injected clock, ID, media-path, effect, and fallback seams.
- Implemented Flutter framework, platform dispatcher, guarded-bootstrap, and explicit PlayerError adapters through one bounded normalization pipeline.
- Added safe absent-stack handling, PlayerError context/path precedence, primitive snapshot isolation, and fatal severity mapping.
- Enforced queue-local 10-second dedupe, five-entry FIFO eviction, FIFO dismissal, readiness-gated idempotent flush, and per-acceptance effect dispatch.
- Tested malformed collaborators, throwing effects and listeners, reentrant intake, and 100/1000-event duplicate storms.

## Verification
- `D:/flutter/bin/flutter test test/diagnostics/error_report_test.dart test/diagnostics/error_reporter_test.dart` — passed (11 tests).
- `D:/flutter/bin/flutter analyze` — passed with no issues.
- `D:/flutter/bin/flutter test` — passed (1235 tests).

## Task Commits
1. **Task 1: Prove one platform-error path through immutable report, FIFO head, notifier, and isolated effect** - `be5e9d4` (test), `981ec33` (feat)
2. **Task 2: Expand reporter adapters, bounded dedupe, FIFO lifecycle, and fault isolation to the full capture contract** - `8bffb5c` (feat)

## Files Created/Modified
- `lib/kernel/diagnostics/error_report.dart` - immutable diagnostic report and presentation-state values.
- `lib/kernel/diagnostics/error_reporting_dependencies.dart` - injectable clock-adjacent reporter seams and effect disposition enum.
- `lib/kernel/diagnostics/error_reporter.dart` - singleton fan-in, normalization, bounded FIFO/dedupe policy, and containment boundaries.
- `test/diagnostics/error_report_test.dart` - immutable replacement contract test.
- `test/diagnostics/error_reporter_test.dart` - adapter, queue policy, burst, and fault-isolation behavior tests.

## Decisions Made
- A matching report is compared only against the five retained FIFO items, avoiding an unbounded fingerprint cache.
- `unavailableOriginalStackMarker` explicitly records absent source stacks without claiming a synthetic original throw site.
- Accepted captures and merges notify effects; evicted heads and reentrant suppression do not.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Pre-existing generated plugin registrant modifications were left untouched and excluded from every commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 01-02. The global-hook assembly can depend on the reporter singleton and four safe adapters; CAP-01 and CAP-03 remain shared requirements until all declaring plans finish.

## Self-Check: PASSED
- Confirmed all five diagnostic source/test artifacts exist in the worktree.
- Confirmed Task 1 commits `be5e9d4` and `981ec33`, plus Task 2 commit `8bffb5c`, exist in git history.

---
*Phase: 01-unified-capture-contract*
*Completed: 2026-08-28*
