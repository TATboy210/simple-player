---
phase: 11-engine-decoupling-defense
plan: 01
subsystem: engine, services
tags: [fvp, state-machine, generation-counter, playback-controller, auto-advance]

requires:
  - phase: 10-state-machine-extraction
    provides: EngineStateMachine, ISP interfaces, _openGeneration in FvpEngine
provides:
  - PlaybackStateManager (settings restore + breakpoint save + dispose persist)
  - AutoAdvancePolicy (completed → loopSingle/next strategy)
  - PlaybackController refactored to compose new sub-modules
  - StateMonitor fully removed
affects: [12-track-unification]

tech-stack:
  added: []
  patterns: [generation-counter-guard, strategy-pattern-auto-advance, composition-over-inheritance]

key-files:
  created:
    - lib/kernel/services/playback_state_manager.dart
    - lib/kernel/services/auto_advance_policy.dart
    - test/kernel/services/playback_state_manager_test.dart
    - test/kernel/services/auto_advance_policy_test.dart
  modified:
    - lib/kernel/services/playback_controller.dart
    - lib/kernel/services/playback_navigator.dart
    - lib/kernel/engine/engine_state.dart
    - lib/kernel/engine/media_engine.dart
    - lib/kernel/persistence/settings_store.dart
    - lib/kernel/engine/video_effect_control.dart
    - lib/kernel/engine/video_effect_controller.dart
  deleted:
    - lib/kernel/services/state_monitor.dart
    - test/kernel/services/state_monitor_test.dart

key-decisions:
  - "PlaybackStateManager handles settings restore + breakpoint + dispose persist (3 of StateMonitor's 5 responsibilities)"
  - "AutoAdvancePolicy isolates completed→next/loop logic as a standalone strategy (cleaner testability)"
  - "PlaybackController composes stateManager + autoAdvance alongside existing navigator + fileOps"

patterns-established:
  - "Sub-module composition: PlaybackController delegates to focused sub-modules via late final fields"
  - "Strategy isolation: auto-advance logic separated from state persistence for independent testing"

requirements-completed: [ENG-04, SVC-03]

coverage:
  - id: D1
    description: "FvpEngine.open() generation counter — stale open() results discarded on fast track switch"
    requirement: ENG-04
    verification:
      - kind: unit
        ref: test/kernel/engine/fvp_engine_open_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "PlaybackStateManager — settings restore, breakpoint save, dispose persist"
    requirement: SVC-03
    verification:
      - kind: unit
        ref: test/kernel/services/playback_state_manager_test.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "AutoAdvancePolicy — completed state → loopSingle replay or auto-advance to next track"
    requirement: SVC-03
    verification:
      - kind: unit
        ref: test/kernel/services/auto_advance_policy_test.dart
        status: pass
    human_judgment: false
  - id: D4
    description: "StateMonitor fully removed — no references remain in codebase"
    requirement: SVC-03
    verification:
      - kind: unit
        ref: "grep 'class StateMonitor' lib/ returns 0 results"
        status: pass
    human_judgment: false

duration: 0min
completed: 2026-07-15
status: complete
---

# Phase 11-01: 引擎解耦 + 防御增强 Summary

**FvpEngine generation guard + StateMonitor split into PlaybackStateManager/AutoAdvancePolicy — 163-line god class eliminated, auto-advance logic independently testable**

## Performance

- **Duration:** 0 min (pre-implemented, verification only)
- **Started:** 2026-07-15
- **Completed:** 2026-07-15
- **Tasks:** 7
- **Files modified:** 11 (7 modified, 2 created, 2 deleted)

## Accomplishments
- FvpEngine.open() uses `_openGeneration` counter — fast track switches discard stale results (ENG-04)
- StateMonitor (163 lines) split into PlaybackStateManager + AutoAdvancePolicy with clear responsibility boundaries (SVC-03)
- PlaybackController composes 4 sub-modules: navigator, fileOps, stateManager, autoAdvance
- All 1159 tests passing, flutter analyze clean

## Files Created/Modified
- `lib/kernel/services/playback_state_manager.dart` — Settings restore, breakpoint save, dispose persist
- `lib/kernel/services/auto_advance_policy.dart` — Completed→loopSingle/next strategy
- `lib/kernel/services/playback_controller.dart` — Refactored to compose new sub-modules
- `lib/kernel/services/playback_navigator.dart` — Minor integration updates
- `lib/kernel/engine/engine_state.dart` — State enum additions
- `lib/kernel/engine/media_engine.dart` — Interface updates
- `lib/kernel/persistence/settings_store.dart` — New persistence keys
- `lib/kernel/engine/video_effect_control.dart` — Interface alignment
- `lib/kernel/engine/video_effect_controller.dart` — Interface alignment
- `lib/kernel/services/state_monitor.dart` — DELETED
- `test/kernel/services/state_monitor_test.dart` — DELETED
- `test/kernel/services/playback_state_manager_test.dart` — NEW
- `test/kernel/services/auto_advance_policy_test.dart` — NEW

## Decisions Made
- PlaybackStateManager owns settings restore + breakpoint + dispose (3 of StateMonitor's 5 responsibilities)
- AutoAdvancePolicy isolates completed→next/loop logic as standalone strategy
- PlaybackController uses `late final` composition for sub-modules

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- StateMonitor fully eliminated, ready for Phase 12 track unification
- Auto-advance logic independently testable for future strategy variations

---
*Phase: 11-engine-decoupling-defense*
*Completed: 2026-07-15*
