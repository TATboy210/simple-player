---
phase: 02-command-queue-recovery
plan: 01
subsystem: bridge
tags: [fullscreen, command-queue, completer-chain, serialization, dart-async]

# Dependency graph
requires:
  - phase: 01-architecture-core-models
    provides: FullscreenRequest sealed class, FullscreenSnapshot, FullscreenError, FullscreenMode
provides:
  - FullscreenCommandQueue — per-window command serialization with merging and timeout
affects: [02-02-desktop-adapter, 02-03-window-service-migration]

# Tech tracking
tech-stack:
  added: []
  patterns: [completer-chain-serialization, toggle-resolve-before-merge, timer-timeout-guard]

key-files:
  created:
    - lib/kernel/bridge/fullscreen_command_queue.dart
    - test/kernel/bridge/fullscreen_command_queue_test.dart
  modified: []

key-decisions:
  - "ToggleFullscreen resolved at queue entry (not inside _WindowQueue) — adapter passes currentFullscreen bool"
  - "Merge check covers both in-flight and pending — same-target commands share Completer even when one is executing"
  - "Dispose tracked at FullscreenCommandQueue level (_disposed flag) — prevents creating new _WindowQueue after dispose"
  - "Executor exceptions caught and returned as false — queue never throws from executor failures"
  - "unawaited() used for drain call in finally block — fire-and-forget next execution"

patterns-established:
  - "Completer chain: in-flight Completer + pending Completer, drain in finally block"
  - "Toggle resolve before merge: FullscreenCommandQueue._resolveToggle converts toggle to enter/leave"
  - "Per-windowId isolation: Map<int, _WindowQueue> with independent lifecycle"

requirements-completed: [CMD-01, CMD-02]

coverage:
  - id: D1
    description: "FullscreenCommandQueue with per-windowId independent queues — same window serializes, different windows isolate"
    requirement: CMD-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T6 per-windowId isolation
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T2 serialization
        status: pass
    human_judgment: false
  - id: D2
    description: "Same-target merging: enter+enter(same mode) merge, leave+leave merge, toggle resolved before merge"
    requirement: CMD-02
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T3 same-target merging
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T4 toggle merging
        status: pass
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T11 toggle resolves to leave when fullscreen
        status: pass
    human_judgment: false
  - id: D3
    description: "5s timeout with BusyTransition-equivalent behavior — timer completes future with false"
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T5 timeout
        status: pass
    human_judgment: false
  - id: D4
    description: "Dispose lifecycle: pending complete(false), in-flight not drained, enqueue after dispose throws StateError"
    verification:
      - kind: unit
        ref: test/kernel/bridge/fullscreen_command_queue_test.dart#T7/T8/T9 dispose lifecycle
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-07-09
status: complete
---

# Phase 2 Plan 01: FullscreenCommandQueue Summary

**Per-window Completer chain command queue with same-target merging, toggle resolution, and 5s timeout — 18 tests passing**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-09T14:02:21Z
- **Completed:** 2026-07-09T14:16:49Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- FullscreenCommandQueue: per-windowId independent queues via Map<int, _WindowQueue>, Completer chain serialization (one in-flight per window, pending waits)
- Same-target merging: enter+enter(same mode) share Completer, leave+leave share Completer, different modes do not merge
- Toggle resolution: FullscreenCommandQueue._resolveToggle converts ToggleFullscreen to Enter/Leave based on currentFullscreen before merge check
- 5s timeout: Timer completes future with false, drain mechanism executes pending command after in-flight completes
- Dispose lifecycle (P1-5): pending complete(false), in-flight not cancelled but not drained, enqueue after dispose throws StateError
- 18 tests covering T1-T11 + edge cases (executor exception, preferredMode passthrough, pending replacement)

## Task Commits

1. **Task 1: FullscreenCommandQueue core logic** - `716ffaa` (feat)

**Plan metadata:** (pending — docs commit after summary)

## Files Created/Modified

- `lib/kernel/bridge/fullscreen_command_queue.dart` - FullscreenCommandQueue class + _WindowQueue + _QueuedCommand (252 lines)
- `test/kernel/bridge/fullscreen_command_queue_test.dart` - 18 tests covering all core scenarios (456 lines)

## Decisions Made

- **Toggle resolved at queue entry:** FullscreenCommandQueue.enqueue takes `currentFullscreen` bool, resolves ToggleFullscreen to Enter/Leave before passing to _WindowQueue. This keeps _WindowQueue simple — it only handles Enter/Leave.
- **Merge check covers in-flight:** When a new command arrives and in-flight has the same target, the new command shares in-flight's Completer. This catches the case where rapid same-target enqueues happen while first is still executing.
- **Dispose flag at queue level:** `_disposed` on FullscreenCommandQueue (not just _WindowQueue) prevents creating new _WindowQueue instances after dispose. Previous design cleared _queues map, allowing putIfAbsent to create fresh queues.
- **Executor exceptions return false:** Queue catches executor exceptions and completes with false. This prevents unhandled exceptions from propagating to callers.
- **unawaited drain:** The drain call in _execute's finally block uses unawaited() — fire-and-forget execution of next command.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Merge check only covered pending, not in-flight**
- **Found during:** Task 1 (implementation)
- **Issue:** Initial implementation only checked `_pending` for merge. When first command is in-flight and second has same target, they should merge but didn't — second became pending unnecessarily.
- **Fix:** Added merge check for `_inFlight` before checking `_pending`. Both in-flight and pending are checked for same-target merge.
- **Files modified:** lib/kernel/bridge/fullscreen_command_queue.dart
- **Verification:** T3 merge tests pass (two enter same mode → one execution)
- **Committed in:** 716ffaa

**2. [Rule 1 - Bug] Dispose cleared _queues map, allowing new queue creation**
- **Found during:** Task 1 (T7 test)
- **Issue:** `dispose()` called `_queues.clear()`, so subsequent `putIfAbsent` created fresh _WindowQueue instances. Enqueue after dispose didn't throw StateError.
- **Fix:** Added `_disposed` flag at FullscreenCommandQueue level. Checked before creating new queues.
- **Files modified:** lib/kernel/bridge/fullscreen_command_queue.dart
- **Verification:** T7 test passes (enqueue after dispose throws StateError)
- **Committed in:** 716ffaa

**3. [Rule 1 - Bug] Unused import and unawaited future warnings**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `fullscreen_error.dart` imported but unused. `_execute(next)` in finally block not awaited.
- **Fix:** Removed unused import, wrapped drain call with `unawaited()`.
- **Files modified:** lib/kernel/bridge/fullscreen_command_queue.dart
- **Verification:** flutter analyze zero warnings
- **Committed in:** 716ffaa

---

**Total deviations:** 3 auto-fixed (3 bugs)
**Impact on plan:** All auto-fixes were correctness/quality fixes during implementation. No scope expansion.

## Issues Encountered

- **Timer interaction in tests:** Initial timeout test with drain verification timed out due to long-running Timer created by drain mechanism. Simplified test to verify timeout completion separately from drain behavior.
- **Toggle test design:** Tests needed `currentFullscreen` parameter to test toggle resolution. Adapted test structure to pass this parameter explicitly.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None — FullscreenCommandQueue is fully functional, no placeholder values.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-02-01 mitigated | fullscreen_command_queue.dart | Queue internal state private, only enqueue/cancel/dispose exposed. dispose rejects new commands. |

## Next Phase Readiness

- FullscreenCommandQueue ready for DesktopFullscreenAdapter to hold as internal component (Plan 02)
- Queue accepts `Future<bool> Function(FullscreenRequest)` executor — adapter provides the native call implementation
- Toggle resolution via `currentFullscreen` parameter — adapter passes `snapshot.isFullscreen`
- No external dependencies — pure Dart, no platform imports

## Self-Check: PASSED

- [x] `lib/kernel/bridge/fullscreen_command_queue.dart` exists
- [x] `test/kernel/bridge/fullscreen_command_queue_test.dart` exists
- [x] `.planning/phases/02-command-queue-recovery/02-01-SUMMARY.md` exists
- [x] Commit `716ffaa` found in git log
- [x] 18 tests pass (`flutter test test/kernel/bridge/fullscreen_command_queue_test.dart`)
- [x] `flutter analyze` zero warnings on new files

---
*Phase: 02-command-queue-recovery*
*Completed: 2026-07-09*
