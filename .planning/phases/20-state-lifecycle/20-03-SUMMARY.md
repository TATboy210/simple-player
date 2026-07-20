---
phase: 20-state-lifecycle
plan: 03
subsystem: engine
tags: [scheduleMicrotask, callback-marshalling, race-condition, generation-guard, D12, D13, D14]

# Dependency graph
requires:
  - phase: 20-state-lifecycle/20-01
    provides: EngineStateMachine with LifecyclePhase + OpenGenerationTracker + TransitionResult + recover()
provides:
  - FvpCallbackHandler using scheduleMicrotask (uniform callback marshalling)
  - Race condition test suite (8 tests covering D14 scenarios)
affects: [20-state-lifecycle, 21-adapter-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: [scheduleMicrotask-callback-marshalling, generation-guard-race-tests]

key-files:
  modified:
    - lib/kernel/engine/fvp_callback_handler.dart
  created:
    - test/kernel/engine/race_condition_test.dart

key-decisions:
  - "scheduleMicrotask replaces SchedulerBinding.addPostFrameCallback (D12): uniform callback marshalling eliminates frame-phase complexity"
  - "All callbacks uniformly delayed (D13): avoids selective scheduling complexity, scheduleMicrotask overhead negligible"
  - "Race tests use real EngineStateMachine (no mocks): direct nextGeneration()+transitionTo(generation:) for isolation"
  - "State matrix constrains race scenarios: opening→opening illegal, tests must go through idle between opens"

patterns-established:
  - "scheduleMicrotask callback marshalling pattern: replaces SchedulerBinding for ValueNotifier updates"
  - "Generation-aware race test pattern: nextGeneration() + transitionTo(generation:) + TransitionResult assertions"

requirements-completed: [STATE-05, STATE-07]

# Coverage metadata
coverage:
  - id: D12
    description: "All mdk callbacks use scheduleMicrotask instead of SchedulerBinding.addPostFrameCallback"
    requirement: STATE-05
    verification:
      - kind: other
        ref: grep SchedulerBinding lib/kernel/engine/fvp_callback_handler.dart
        status: pass (0 matches — only doc comments reference old pattern)
      - kind: other
        ref: grep scheduleMicrotask lib/kernel/engine/fvp_callback_handler.dart
        status: pass
      - kind: other
        ref: flutter analyze lib/kernel/engine/fvp_callback_handler.dart
        status: pass
    human_judgment: false
  - id: D13
    description: "All callbacks uniformly delayed — no mixed scheduling strategies"
    requirement: STATE-05
    verification:
      - kind: other
        ref: single _scheduleOnMain method using scheduleMicrotask
        status: pass
    human_judgment: false
  - id: D14
    description: "Race condition tests cover open→open, open→seek→open, open→dispose, open→play→pause→open"
    requirement: STATE-07
    verification:
      - kind: unit
        ref: test/kernel/engine/race_condition_test.dart
        status: pass (8 tests)
    human_judgment: false

# Metrics
duration: 11min
completed: 2026-07-20
status: complete
---

# Phase 20 Plan 03: FvpCallbackHandler scheduleMicrotask + Race Condition Tests Summary

**Switched FvpCallbackHandler from SchedulerBinding.addPostFrameCallback to scheduleMicrotask for uniform callback marshalling, and added 8 race condition tests validating generation guard correctness under rapid-fire scenarios**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-20T00:26:52Z
- **Completed:** 2026-07-20T00:37:47Z
- **Tasks:** 2
- **Files modified:** 1
- **Files created:** 1

## Accomplishments
- Replaced `SchedulerBinding.addPostFrameCallback` with `scheduleMicrotask` in FvpCallbackHandler._scheduleOnMain (D12/D13)
- Removed `import 'package:flutter/scheduler.dart'` — only `dart:async` needed for scheduleMicrotask
- Updated doc comments to reflect new scheduling strategy
- Created comprehensive race condition test suite with 8 tests covering all D14 scenarios
- All tests use real EngineStateMachine (no mocks) — validates generation tracking, lifecycle transitions, and recovery

## Task Commits

Each task was committed atomically:

1. **Task 1: Switch FvpCallbackHandler to scheduleMicrotask + unit tests** - `f1d35ad` (refactor)
2. **Task 2: Race condition tests with fakeAsync** - `28d08e5` (test)

## Files Created/Modified
- `lib/kernel/engine/fvp_callback_handler.dart` - Modified: `_scheduleOnMain` uses `scheduleMicrotask(action)`, removed SchedulerBinding import, updated doc comments
- `test/kernel/engine/race_condition_test.dart` - Created: 8 race condition tests (generation tracking, open-seek-open, open-dispose lifecycle, open-play-pause-open rapid fire, recover during rapid operations)

## Decisions Made
- **scheduleMicrotask (D12):** Uniform callback marshalling eliminates frame-phase complexity, aligns with Phase 18 D9 error marshalling pattern
- **Uniform delay (D13):** All callbacks go through scheduleMicrotask — avoids selective scheduling complexity, overhead is negligible
- **Real EngineStateMachine in tests:** No mocks needed — direct nextGeneration()+transitionTo(generation:) provides clean isolation
- **State matrix constrains test scenarios:** opening→opening is illegal, tests must route through idle between consecutive opens — matches real engine behavior

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test scenarios violated state matrix**
- **Found during:** Task 2 (race condition tests)
- **Issue:** Plan's test scenarios assumed `opening → opening` was a valid transition for rapid open-open and open-seek-open tests. Actual state matrix makes this illegal.
- **Fix:** Adjusted tests to route through `idle` between consecutive opens — `idle → opening → idle → opening`. This matches real engine behavior where a new open request first cancels the current open.
- **Files modified:** test/kernel/engine/race_condition_test.dart
- **Verification:** All 8 tests pass
- **Committed in:** 28d08e5 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Test scenarios adjusted to match actual state matrix. No scope creep — all planned functionality delivered.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- FvpCallbackHandler now uses scheduleMicrotask uniformly — ready for Phase 20 Plan 04+ (DelegationPolicy flip)
- Race condition tests validate generation guard correctness — foundation for future engine integration tests
- All D12/D13/D14 coverage verified

---
*Phase: 20-state-lifecycle*
*Completed: 2026-07-20*
