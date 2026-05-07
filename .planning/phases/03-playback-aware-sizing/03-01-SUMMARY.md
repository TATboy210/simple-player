---
phase: 03-playback-aware-sizing
plan: 01
subsystem: playback
tags: [aspect-ratio, method-channel, state-management, value-notifier]

# Dependency graph
requires:
  - phase: 02-resize-persistence
    provides: "AspectRatioService with native WM_SIZING handler, WindowManagerService"
provides:
  - "StateMonitor wired to AspectRatioService for automatic aspect ratio lock/unlock on playback state changes"
  - "Integration tests verifying aspect ratio behavior across all MediaState transitions"
affects: [03-playback-aware-sizing]

# Tech tracking
tech-stack:
  added: []
  patterns: ["ValueNotifier listener pattern for cross-cutting concerns", "MethodChannel mocking in unit tests"]

key-files:
  created: []
  modified:
    - "lib/kernel/services/state_monitor.dart"
    - "test/kernel/services/state_monitor_test.dart"

key-decisions:
  - "Aspect ratio lock fires on playing state (not loading) because engine.aspectRatio.value is set during open() before play()"
  - "Paused does NOT unlock - pausing is transient, user expects window to stay locked"
  - "matchVideo() is fire-and-forget (not awaited) matching existing pattern for non-critical side effects"

patterns-established:
  - "Cross-cutting concerns in _onStateChanged: aspect ratio lock/unlock alongside existing pause breakpoint and auto-advance logic"

requirements-completed: [WP-01, WP-02, WP-03, WP-04]

# Metrics
duration: 8min
completed: 2026-05-07
---

# Phase 3 Plan 01: Wire StateMonitor to AspectRatioService Summary

**StateMonitor wired to AspectRatioService: lock to video aspect ratio on play, unlock on stop/idle/completed/error, persist through pause**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-07T07:10:00Z
- **Completed:** 2026-05-07T07:18:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- StateMonitor._onStateChanged() now calls AspectRatioService.I.matchVideo() when engine state becomes playing
- StateMonitor._onStateChanged() now calls AspectRatioService.I.unlock() when state is stopped/idle/completed/error
- Pause state does NOT unlock aspect ratio (lock persists through pause)
- 8 new integration tests covering all aspect ratio state transitions via mocked MethodChannel

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire StateMonitor to AspectRatioService** - `41d1a63` (feat)
2. **Task 2: Add rapid state change test** - `fa53be2` (test)

## Files Created/Modified
- `lib/kernel/services/state_monitor.dart` - Added AspectRatioService import and lock/unlock logic in _onStateChanged()
- `test/kernel/services/state_monitor_test.dart` - Added 8 aspect ratio integration tests with MethodChannel mocking

## Decisions Made
- Aspect ratio lock fires on `playing` state (not `loading`) because `engine.aspectRatio.value` is set during `open()` before `play()` is called
- `paused` does NOT unlock - pausing is a transient state, user expects window to stay locked
- `AspectRatioService.I.matchVideo()` is fire-and-forget (not awaited) matching existing pattern for non-critical side effects
- `seeking` and `buffering` are transient states that don't affect the lock

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Aspect ratio lock/unlock integration complete, ready for Plan 03-02 (custom title bar with resize-aware rendering)
- No blockers or concerns

## Self-Check: PASSED

- [x] `lib/kernel/services/state_monitor.dart` exists
- [x] `test/kernel/services/state_monitor_test.dart` exists
- [x] `.planning/phases/03-playback-aware-sizing/03-01-SUMMARY.md` exists
- [x] Commit `41d1a63` (Task 1) exists in git log
- [x] Commit `fa53be2` (Task 2) exists in git log

---
*Phase: 03-playback-aware-sizing*
*Completed: 2026-05-07*
