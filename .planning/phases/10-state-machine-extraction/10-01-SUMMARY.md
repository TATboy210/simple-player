---
phase: 10-state-machine-extraction
plan: 01
subsystem: engine
tags: [state-machine, switch-expression, mixin, playback-control, fvp]

# Dependency graph
requires:
  - phase: 09-interface-decomposition
    provides: ISP interfaces (PlaybackControl, EngineStateView, MediaState enum with 6 states)
provides:
  - EngineStateMachine standalone class with 3 ValueNotifiers
  - PlaybackSkipMixin with skipForward/skipBack defaults
  - MediaStateTransition extension removed (switch expression replaces runtime check)
affects: [10-02-fvp-engine-slimming, fvp_engine, fvp_callback_handler]

# Tech tracking
tech-stack:
  added: []
  patterns: [switch-expression-exhaustive-guard, callback-injection-decoupling, mixin-default-implementation]

key-files:
  created:
    - lib/kernel/engine/engine_state_machine.dart
    - lib/kernel/engine/playback_skip_mixin.dart
    - test/kernel/engine/engine_state_machine_test.dart
    - test/kernel/engine/playback_skip_mixin_test.dart
  modified:
    - lib/kernel/engine/media_state.dart
    - lib/kernel/engine/engine_state.dart
    - lib/kernel/engine/fvp_engine.dart

key-decisions:
  - "Illegal transitions always return false in both debug and release modes (stricter than original _safeSetState)"
  - "Inlined switch expression guard in FvpEngine._safeSetState as temporary bridge until Plan 10-02"
  - "setRange stays in FvpEngine (needs _player + _guardedAction), not in PlaybackSkipMixin"

patterns-established:
  - "EngineStateMachine: standalone state machine with ValueNotifier composition + callback injection for play/pause"
  - "PlaybackSkipMixin: mixin on PlaybackControl with abstract position/duration getters for dependency access"

requirements-completed: [SVC-02, ENG-02]

coverage:
  - id: D1
    description: "EngineStateMachine class with 3 ValueNotifiers and switch expression exhaustive guard"
    requirement: SVC-02
    verification:
      - kind: unit
        ref: "test/kernel/engine/engine_state_machine_test.dart#transitionTo legal/illegal"
        status: pass
    human_judgment: false
  - id: D2
    description: "togglePlayPause via onPlay/onPause callbacks (decoupled from engine)"
    requirement: SVC-02
    verification:
      - kind: unit
        ref: "test/kernel/engine/engine_state_machine_test.dart#togglePlayPause"
        status: pass
    human_judgment: false
  - id: D3
    description: "PlaybackSkipMixin with skipForward/skipBack default implementations"
    requirement: ENG-02
    verification:
      - kind: unit
        ref: "test/kernel/engine/playback_skip_mixin_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "MediaStateTransition extension removed from media_state.dart"
    requirement: SVC-02
    verification:
      - kind: other
        ref: "grep MediaStateTransition lib/ — zero matches in lib/"
        status: pass
    human_judgment: false

# Metrics
duration: 9min
completed: 2026-07-14
status: complete
---

# Phase 10 Plan 01: EngineStateMachine + PlaybackSkipMixin Summary

**EngineStateMachine standalone class with switch expression exhaustive guard, PlaybackSkipMixin for skipForward/skipBack, and MediaStateTransition extension removal**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-14T12:10:19Z
- **Completed:** 2026-07-14T12:19:18Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- EngineStateMachine class with 3 ValueNotifiers (state/isSeeking/isBuffering) and switch expression exhaustive guard for 6 states
- togglePlayPause via callback injection (onPlay/onPause) — no engine reference held, avoiding circular dependency
- PlaybackSkipMixin provides skipForward/skipBack with automatic clamp to [0, duration]
- MediaStateTransition extension deleted — switch expression in EngineStateMachine replaces runtime canTransitionTo check
- 52 new tests (44 state machine + 8 skip mixin), all 134 engine tests passing

## Task Commits

Each task was committed atomically:

1. **Task 1: EngineStateMachine (RED)** - `5cea904` (test)
2. **Task 1: EngineStateMachine (GREEN)** - `62363ac` (feat)
3. **Task 2: PlaybackSkipMixin + extension removal** - `3b52567` (feat)

## Files Created/Modified
- `lib/kernel/engine/engine_state_machine.dart` - Standalone state machine with 3 ValueNotifiers, transitionTo with switch expression guard, togglePlayPause via callbacks
- `lib/kernel/engine/playback_skip_mixin.dart` - Mixin on PlaybackControl providing skipForward/skipBack with clamp
- `lib/kernel/engine/media_state.dart` - Removed MediaStateTransition extension (44 lines removed)
- `lib/kernel/engine/engine_state.dart` - Added barrel exports for engine_state_machine.dart and playback_skip_mixin.dart
- `lib/kernel/engine/fvp_engine.dart` - Inlined switch expression guard in _safeSetState as temporary bridge
- `test/kernel/engine/engine_state_machine_test.dart` - 44 tests: legal/illegal transitions, toggle routing, flags, dispose
- `test/kernel/engine/playback_skip_mixin_test.dart` - 8 tests: skipForward/skipBack with normal and clamped ranges

## Decisions Made
- **Illegal transitions return false in all modes:** Stricter than original _safeSetState which allowed debug-mode illegal transitions to proceed. The bool return value makes the contract clear: false always means the transition was rejected.
- **Temporary duplication in FvpEngine:** Inlined the switch expression guard in FvpEngine._safeSetState to avoid breaking the build. This will be removed in Plan 10-02 when FvpEngine uses EngineStateMachine directly.
- **setRange stays in FvpEngine:** Per D-10 decision and Open Question #3 resolution — setRange needs _player.setRange + _guardedAction which mixin cannot access.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Inlined switch expression guard in FvpEngine._safeSetState**
- **Found during:** Task 2 (MediaStateTransition extension deletion)
- **Issue:** Plan assumed deleting MediaStateTransition extension would leave no references in lib/, but FvpEngine._safeSetState still called `current.canTransitionTo(next)` via the extension
- **Fix:** Inlined the switch expression logic as a static `_canTransitionTo` method in FvpEngine, with a doc comment noting it will be removed in Plan 10-02
- **Files modified:** lib/kernel/engine/fvp_engine.dart
- **Verification:** `flutter analyze` passes, `grep MediaStateTransition lib/` returns zero matches
- **Committed in:** 3b52567 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical step)
**Impact on plan:** Necessary for correctness — extension deletion would have broken FvpEngine without this bridge. No scope creep.

## Issues Encountered
- RED phase initially passed for illegal transitions because debug-mode implementation fell through and set state. Fixed by making illegal transitions always return false regardless of debug/release mode.

## Known Stubs
None — all code is functional with no placeholder values.

## Threat Flags
None — pure internal architecture refactoring, no new security surface.

## Self-Check: PASSED

## Next Phase Readiness
- EngineStateMachine ready for injection into FvpEngine (Plan 10-02)
- PlaybackSkipMixin ready for use in FvpEngine (Plan 10-02)
- FvpEngine._safeSetState bridge code to be replaced in Plan 10-02

---
*Phase: 10-state-machine-extraction*
*Completed: 2026-07-14*
