---
phase: 20-state-lifecycle
plan: 02
subsystem: engine
tags: [diagnostics-bundle, generation-unification, per-method-delegation, lifecycle]

# Dependency graph
requires:
  - phase: 20-state-lifecycle/20-01
    provides: EngineStateMachine with lifecycle + generation + TransitionResult + recover()
  - phase: 17-kernellogger
    provides: KernelLoggerImpl static I accessor
  - phase: 16-diagnosticsbundle
    provides: DiagnosticsBundle carrier with 4 slots
provides:
  - FvpEngine with DiagnosticsBundle injection (D2)
  - Generation tracking unified in EngineStateMachine (D5)
  - Per-method DelegationPolicy via Set<String> migratedMethods (D9)
affects: [20-state-lifecycle, 21-adapter-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: [bundle-injection, per-method-delegation, generation-unification]

key-files:
  modified:
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/services/playback_navigator.dart
    - lib/kernel/adapter/kernel_adapter.dart
    - lib/kernel/player_services.dart
    - lib/kernel/engine/engine_state_view.dart
    - test/helpers/fake_engine.dart
  created:
    - test/kernel/engine/fvp_engine_bundle_test.dart

key-decisions:
  - "DiagnosticsBundle injection (D2): FvpEngine factory accepts bundle parameter with noop default"
  - "Generation unification (D5): _openGeneration removed from FvpEngine and PlaybackNavigator, uses state machine"
  - "Per-method DelegationPolicy (D9): Set<String> migratedMethods enables method-by-method cutover"
  - "stateMachine accessor on EngineStateView: PlaybackNavigator accesses generation via engine.stateMachine"

patterns-established:
  - "Bundle injection pattern: factory constructor accepts DiagnosticsBundle, stores as _bundle field"
  - "Per-method routing: _targetFor(methodName) helper returns correct engine based on migratedMethods set"

requirements-completed: [STATE-01, STATE-02, STATE-04, STATE-06]

# Coverage metadata
coverage:
  - id: D2
    description: "FvpEngine accepts DiagnosticsBundle via constructor, uses _bundle.logger"
    requirement: STATE-01
    verification:
      - kind: unit
        ref: test/kernel/engine/fvp_engine_bundle_test.dart#DiagnosticsBundle injection
        status: pass
      - kind: other
        ref: flutter analyze lib/kernel/engine/fvp_engine.dart
        status: pass
    human_judgment: false
  - id: D5
    description: "Generation tracking unified in EngineStateMachine (no _openGeneration in FvpEngine/PlaybackNavigator)"
    requirement: STATE-02
    verification:
      - kind: unit
        ref: test/kernel/engine/fvp_engine_bundle_test.dart#generation tracking
        status: pass
      - kind: other
        ref: grep _openGeneration lib/kernel/engine/fvp_engine.dart
        status: pass (0 hits)
      - kind: other
        ref: grep _openGeneration lib/kernel/services/playback_navigator.dart
        status: pass (0 hits)
    human_judgment: false
  - id: D7
    description: "recover() method delegates to EngineStateMachine"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/fvp_engine_bundle_test.dart#recover
        status: pass
    human_judgment: false
  - id: D8
    description: "Double-dispose safety with early return guard"
    requirement: STATE-04
    verification:
      - kind: unit
        ref: test/kernel/engine/fvp_engine_bundle_test.dart#double-dispose
        status: pass
    human_judgment: false
  - id: D9
    description: "DelegationPolicy per-method routing via Set<String> migratedMethods"
    requirement: STATE-06
    verification:
      - kind: other
        ref: flutter analyze lib/kernel/adapter/kernel_adapter.dart
        status: pass
      - kind: other
        ref: grep migratedMethods lib/kernel/adapter/kernel_adapter.dart
        status: pass
    human_judgment: false

# Metrics
duration: 18min
completed: 2026-07-20
status: complete
---

# Phase 20 Plan 02: FvpEngine Integration + Per-Method Delegation Summary

**FvpEngine gains DiagnosticsBundle injection, generation tracking unified in state machine, PlaybackNavigator delegates generation to state machine, KernelAdapter gains per-method DelegationPolicy**

## Performance

- **Duration:** 18 min
- **Started:** 2026-07-20T00:27:55Z
- **Completed:** 2026-07-20T00:46:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- FvpEngine factory constructor accepts DiagnosticsBundle parameter with noop default (D2)
- Removed top-level `final log = KernelLogger.I` and `final logEngine = KernelLogger.I` variables
- All logger calls now use `_bundle.logger.e/w/i/d(...)` pattern
- Added `lifecyclePhase` getter delegating to state machine (D6)
- Added `recover()` method delegating to EngineStateMachine (D7)
- Added double-dispose safety with `if (_disposed) return;` early guard (D8)
- Removed `_openGeneration` from FvpEngine, uses `_stateMachine.nextGeneration()` and `_stateMachine.currentGeneration` (D5)
- Removed `_openGeneration` from PlaybackNavigator, uses `_controller.engine.stateMachine.nextGeneration()` and `.currentGeneration` (D5)
- Added `stateMachine` getter to EngineStateView interface
- Added `migratedMethods` field to DelegationPolicy for per-method routing (D9)
- Added `_targetFor(methodName)` helper to KernelAdapter
- Updated all 26 action methods to use `_targetFor()` routing
- PlayerServices passes bundle to FvpEngine constructor (D2)
- Updated FakeEngine with recover/lifecyclePhase/double-dispose/generation-via-stateMachine

## Task Commits

Each task was committed atomically:

1. **Task 1: FvpEngine DiagnosticsBundle injection + generation unification** - `4710cd0` (feat)
2. **Task 2: KernelAdapter per-method DelegationPolicy + PlayerServices wiring** - `0579c62` (feat)

## Files Created/Modified

- `lib/kernel/engine/fvp_engine.dart` - Bundle injection, logger migration, generation unification, lifecycle methods
- `lib/kernel/services/playback_navigator.dart` - _openGeneration removed, delegates to state machine
- `lib/kernel/adapter/kernel_adapter.dart` - Per-method DelegationPolicy with Set<String> migratedMethods
- `lib/kernel/player_services.dart` - Bundle-first creation, FvpEngine(bundle:) wiring
- `lib/kernel/engine/engine_state_view.dart` - Added stateMachine accessor
- `test/helpers/fake_engine.dart` - Updated with recover/lifecyclePhase/double-dispose
- `test/kernel/engine/fvp_engine_bundle_test.dart` - New test file for bundle injection contracts

## Decisions Made

- **DiagnosticsBundle injection (D2):** Factory constructor accepts named `bundle` parameter with `DiagnosticsBundle.noop()` default
- **Generation unification (D5):** `_openGeneration` removed from both FvpEngine and PlaybackNavigator, single source of truth in EngineStateMachine
- **Per-method DelegationPolicy (D9):** `Set<String> migratedMethods` field enables method-by-method cutover, `_targetFor()` helper routes action methods
- **stateMachine on interface:** Added `stateMachine` getter to EngineStateView so PlaybackNavigator can access generation counter through engine interface

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FvpEngine has DiagnosticsBundle injection + lifecycle methods + generation unification
- KernelAdapter has per-method DelegationPolicy ready for method-by-method cutover
- Ready for Plan 03: mdk callback marshalling + race condition tests (D12-D14)

---
*Phase: 20-state-lifecycle*
*Completed: 2026-07-20*
