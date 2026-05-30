---
phase: 11-performance-optimization
plan: 02
subsystem: engine
tags: [polling, timer, performance, position-poller, adaptive-interval]

# Dependency graph
requires: []
provides:
  - "Adaptive polling intervals in PositionPoller (100ms active / 250ms normal)"
  - "Auto-switch to fast polling after seek completes"
affects: [fvp-engine, progress-bar, playback-controller]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Adaptive timer interval switching", "No-op guard to avoid unnecessary timer recreation"]

key-files:
  created: []
  modified:
    - "lib/kernel/engine/position_poller.dart"
    - "test/kernel/engine/position_poller_test.dart"

key-decisions:
  - "100ms active / 250ms normal polling intervals — balances CPU savings with seek responsiveness"
  - "1-second active duration — enough for smooth progress bar updates after seek"
  - "seeking setter auto-triggers setActive — no caller changes needed in FvpEngine"

patterns-established:
  - "Adaptive timer: _updateInterval with no-op guard to avoid unnecessary timer recreation"
  - "Auto-revert: Timer-based reversion from active to normal interval"

requirements-completed: [PERF-04]

# Metrics
duration: 8min
completed: 2026-05-30
---

# Plan 11-02: Adaptive Polling Intervals Summary

**PositionPoller adaptive polling: 100ms after seek for 1s, 250ms steady playback, reducing CPU overhead**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-30
- **Completed:** 2026-05-30
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Replaced fixed 250ms polling with adaptive intervals (100ms active / 250ms normal)
- seeking setter auto-triggers setActive() on false — no caller changes needed
- _updateInterval() with no-op guard avoids unnecessary timer recreation
- stop() and dispose() properly clean up both _timer and _activeTimer

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement adaptive polling intervals** - `12147d1` (feat)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/kernel/engine/position_poller.dart` - Adaptive polling with _activePollMs/_normalPollMs, setActive(), _updateInterval()
- `test/kernel/engine/position_poller_test.dart` - Updated tests for adaptive polling API surface

## Decisions Made
- 100ms active / 250ms normal intervals — balances CPU savings with seek responsiveness
- 1-second active duration — enough for smooth progress bar updates after seek
- seeking setter auto-triggers setActive — no caller changes needed in FvpEngine
- No-op guard in _updateInterval — avoids unnecessary timer recreation when interval unchanged

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Adaptive polling complete, ready for next performance optimization plan
- All 623 tests passing, flutter analyze clean on modified files

---
*Phase: 11-performance-optimization*
*Completed: 2026-05-30*
