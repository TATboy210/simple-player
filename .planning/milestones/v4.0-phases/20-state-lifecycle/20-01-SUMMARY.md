---
phase: 20-state-lifecycle
plan: 01
subsystem: engine
tags: [state-machine, lifecycle, generation-tracker, transition-result, recover]

# Dependency graph
requires:
  - phase: 17-kernellogger
    provides: KernelLoggerImpl static I accessor + warn method
  - phase: 15-contract-freeze-baseline-audit
    provides: 6-state MediaState frozen baseline + lifecycle phase decision (BASE-03)
provides:
  - LifecyclePhase enum {alive, disposing, disposed}
  - TransitionResult enum {ok, illegal, staleGeneration}
  - EngineStateMachine with lifecycle + generation + TransitionResult + recover()
  - OpenGenerationTracker embedded in state machine
affects: [20-state-lifecycle, 21-adapter-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: [transition-result-enum, lifecycle-phase-orthogonal, embedded-generation-tracker, kernellogger-warn-for-illegal-transitions]

key-files:
  created:
    - lib/kernel/engine/lifecycle_phase.dart
    - lib/kernel/engine/transition_result.dart
  modified:
    - lib/kernel/engine/engine_state_machine.dart
    - test/kernel/engine/engine_state_machine_test.dart

key-decisions:
  - "TransitionResult enum (D4): ok/illegal/staleGeneration — replaces bool return type for explicit 3-state semantics"
  - "LifecyclePhase orthogonal (D6): alive/disposing/disposed — independent ValueNotifier coexisting with MediaState"
  - "OpenGenerationTracker embedded (D5): generation counter inside state machine, single source of truth"
  - "KernelLogger.warn for illegal transitions: replaces assert-only debugPrint, logs in all build modes"
  - "Double-dispose safety (D8): _disposed guard flag, second dispose() is silent no-op"

patterns-established:
  - "TransitionResult enum pattern: 3-value enum for state machine transition outcomes (ok/illegal/staleGeneration)"
  - "Embedded generation tracker: counter + nextGeneration() + currentGeneration inside state machine"
  - "KernelLogger.warn for runtime guards: replaces assert-only pattern for production-visible warnings"

requirements-completed: [STATE-02, STATE-03, STATE-04]

# Coverage metadata
coverage:
  - id: D1
    description: "TransitionResult enum {ok, illegal, staleGeneration} with doc comments"
    requirement: STATE-03
    verification:
      - kind: unit
        ref: test/kernel/engine/transition_result_test.dart#TransitionResult
        status: pass
      - kind: other
        ref: flutter analyze lib/kernel/engine/transition_result.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "LifecyclePhase enum {alive, disposing, disposed} with doc comments"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/lifecycle_phase_test.dart#LifecyclePhase
        status: pass
      - kind: other
        ref: flutter analyze lib/kernel/engine/lifecycle_phase.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "EngineStateMachine.transitionTo returns TransitionResult (not bool)"
    requirement: STATE-03
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#transitionTo
        status: pass
      - kind: other
        ref: flutter analyze lib/kernel/engine/engine_state_machine.dart
        status: pass
    human_judgment: false
  - id: D4
    description: "LifecyclePhase ValueNotifier on EngineStateMachine, initial alive"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#LifecyclePhase
        status: pass
    human_judgment: false
  - id: D5
    description: "OpenGenerationTracker: nextGeneration()/currentGeneration + stale generation rejection"
    requirement: STATE-02
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#OpenGenerationTracker
        status: pass
    human_judgment: false
  - id: D6
    description: "recover() method: error->idle transition, no-op in non-error states"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#recover
        status: pass
    human_judgment: false
  - id: D7
    description: "Double-dispose safety: _disposed guard, second dispose() is safe no-op"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#double-dispose
        status: pass
    human_judgment: false
  - id: D8
    description: "Illegal transitions logged via KernelLogger.warn (not assert-only debugPrint)"
    requirement: STATE-03
    verification:
      - kind: unit
        ref: test/kernel/engine/engine_state_machine_test.dart#transitionTo — illegal transitions
        status: pass
      - kind: other
        ref: grep KernelLoggerImpl.I.warn lib/kernel/engine/engine_state_machine.dart
        status: pass
    human_judgment: false

# Metrics
duration: 13min
completed: 2026-07-20
status: complete
---

# Phase 20 Plan 01: EngineStateMachine Rewrite Summary

**EngineStateMachine rewritten with LifecyclePhase orthogonal state, embedded OpenGenerationTracker, TransitionResult 3-value return type, recover() method, and KernelLogger.warn for illegal transitions**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-20T00:04:19Z
- **Completed:** 2026-07-20T00:17:51Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created LifecyclePhase enum {alive, disposing, disposed} — orthogonal to MediaState, tracks engine object liveness
- Created TransitionResult enum {ok, illegal, staleGeneration} — replaces bool return type with explicit 3-state semantics
- Rewrote EngineStateMachine: lifecyclePhase ValueNotifier, embedded OpenGenerationTracker, TransitionResult return type, recover() method, double-dispose safety
- Updated all 60 tests: return type checks migrated from bool to TransitionResult, 5 new test groups added (generation tracking, lifecycle phase, recover, double-dispose, TransitionResult)
- Illegal transitions now logged via KernelLogger.warn in all build modes (replaces assert-only debugPrint anti-pattern)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create LifecyclePhase and TransitionResult enums** - `6090d98` (test)
2. **Task 2: Rewrite EngineStateMachine with lifecycle, generation, TransitionResult, recover()** - `e6c3e27` (feat)

## Files Created/Modified
- `lib/kernel/engine/lifecycle_phase.dart` - LifecyclePhase enum {alive, disposing, disposed} with bilingual doc comments
- `lib/kernel/engine/transition_result.dart` - TransitionResult enum {ok, illegal, staleGeneration} with bilingual doc comments
- `lib/kernel/engine/engine_state_machine.dart` - Expanded: lifecyclePhase notifier, OpenGenerationTracker, TransitionResult return type, recover(), double-dispose safety
- `test/kernel/engine/engine_state_machine_test.dart` - Updated: TransitionResult checks + 5 new test groups (60 tests total)
- `test/kernel/engine/lifecycle_phase_test.dart` - LifecyclePhase enum value/index tests (4 tests)
- `test/kernel/engine/transition_result_test.dart` - TransitionResult enum value/index tests (4 tests)

## Decisions Made
- **TransitionResult enum (D4):** ok/illegal/staleGeneration — simpler than sealed Result<T>, richer than bool, directly maps to generation guard semantics
- **LifecyclePhase orthogonal (D6):** Independent ValueNotifier coexisting with MediaState — state tracks playback behavior, lifecyclePhase tracks engine object liveness
- **OpenGenerationTracker embedded (D5):** Generation counter inside state machine (single source of truth) — transitionTo auto-checks generation if provided
- **KernelLoggerImpl.I for logging:** Used concrete KernelLoggerImpl.I (not abstract KernelLogger.I) because static accessor lives on the impl class per Phase 17 design
- **Double-dispose safety (D8):** _disposed guard flag with lifecyclePhase set to disposed before disposing notifiers

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] KernelLoggerImpl initialization for tests**
- **Found during:** Task 2 (EngineStateMachine rewrite)
- **Issue:** Plan stated "KernelLogger.I returns a NullKernelLogger by default — no mock needed" but actual code requires `KernelLoggerImpl.init()` to be called first (static accessor throws StateError without init)
- **Fix:** Added `KernelLoggerImpl.init()` call at test file top level; used `KernelLoggerImpl.I` import (concrete class) instead of abstract `KernelLogger.I`
- **Files modified:** test/kernel/engine/engine_state_machine_test.dart, lib/kernel/engine/engine_state_machine.dart
- **Verification:** All 60 tests pass
- **Committed in:** e6c3e27 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minor import path correction. No scope creep — all planned functionality delivered.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- EngineStateMachine foundation complete with lifecycle, generation tracking, and explicit transition results
- Ready for Phase 20 Plans 02-03: FvpEngine DiagnosticsBundle injection + DelegationPolicy method-by-method flip + mdk callback marshalling
- Embedded OpenGenerationTracker enables PlaybackNavigator migration (generation from tracker, not navigator)

---
*Phase: 20-state-lifecycle*
*Completed: 2026-07-20*
