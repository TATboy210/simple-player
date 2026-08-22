---
phase: 39-progress-bar-three-symptoms-root-cause
plan: 01
subsystem: testing
tags: [flutter, media_kit, windows, integration-test, progress-bar, diagnostics]
requires:
  - phase: 36-medium-grain-rebuild-boundary-refactor
    provides: PlayerVideoControls, ControlBarViewModel, and ControlBarTimeline composition path
provides:
  - Fake-only data-chain tracer for duration, replacement, seek, and hover evidence
  - Real Windows media_kit trace from raw Player streams through the controls state and widgets
  - Evidence-backed first broken production boundary and Plan 02 repair contract
affects: [39-progress-bar-three-symptoms-root-cause, progress-bar, control-bar-layout]
actuals:
  tokens: 7000
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns:
    - Ordered adjacent-layer runtime diagnostics with raw upstream control evidence
    - Fixture-basename-only native test logging
key-files:
  created:
    - test/widget/player/progress_bar_data_chain_diagnosis_test.dart
    - integration_test/progress_bar_real_runtime_diagnosis_test.dart
    - .planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/39-DIAGNOSIS.md
  modified: []
key-decisions:
  - "Treat raw Player.stream duration as harness validity and preserve downstream absence as diagnostic evidence."
  - "Name ControlBarLayout._buildLayout as the first broken production boundary because it omits ControlBarTimeline."
patterns-established:
  - "P39 diagnostics emit monotonic observed/missing records and retain a strict post-repair environment gate."
requirements-completed: [PROG-01, PROG-02, PROG-03]
coverage:
  - id: D1
    description: "Fake-only tracer isolates delayed duration, replacement, seek, hover, and pointer-hit behavior."
    requirement: PROG-01
    verification:
      - kind: unit
        ref: "test/widget/player/progress_bar_data_chain_diagnosis_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Windows integration diagnostic records real media_kit duration/position transport and evaluates the production composition boundary."
    requirement: PROG-02
    verification:
      - kind: integration
        ref: "integration_test/progress_bar_real_runtime_diagnosis_test.dart -d windows"
        status: pass
    human_judgment: false
  - id: D3
    description: "Evidence artifact states the hover/pointer boundary and protected behavior for the follow-up repair."
    requirement: PROG-03
    verification:
      - kind: other
        ref: ".planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/39-DIAGNOSIS.md"
        status: pass
    human_judgment: false
duration: 18 min
completed: 2026-08-22
status: complete
---

# Phase 39 Plan 01: Progress Bar Three Symptoms Root Cause Summary

**Real Windows media_kit tracing proves duration and position reach the port, controls state, and intended ProgressBar, while the production ControlBar layout omits the timeline entirely.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-22T15:36:14Z
- **Completed:** 2026-08-22T15:54:14Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added a fake-only widget tracer that separates transport, source replacement, seek, hover, and pointer-hit candidates without loading MDK.
- Added a Windows integration diagnostic that opens `tiny_valid.mp4`, independently observes raw `Player.stream` events, and records a monotonic `[P39]` trace through project layers.
- Recorded the unique first production break: `ControlBarLayout._buildLayout` omits `ControlBarTimeline`; documented the precise Plan 02 repair constraints.

## Task Commits

Each task was committed atomically:

1. **Task 1: establish duration/position tracer** - `b08a87bf` (test)
2. **Task 2: collect real Windows PlayerPort timing and lock Plan 02 entry** - `51e55edc` (test)

## Files Created/Modified

- `test/widget/player/progress_bar_data_chain_diagnosis_test.dart` - Fake-only regression tracer from controls state through progress interactions.
- `integration_test/progress_bar_real_runtime_diagnosis_test.dart` - Real Windows fixture diagnostic with raw stream control evidence and `P39_POST_REPAIR` strict mode.
- `.planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/39-DIAGNOSIS.md` - Sanitized real trace, evidence matrix, first boundary, and repair contract.

## Decisions Made

- Use raw `Player.stream.duration` as a separate harness-validity gate; do not let missing downstream values erase the trace.
- Diagnose the production composition edge separately from the intended direct timeline path, which proves the data notifiers and `ProgressBar` are capable of receiving values.
- Preserve the event-driven v2 seek-hold and its timeout backstop during the follow-up repair.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test diagnostic] Reduced raw position trace noise to a single monotonic observed record per layer.**
- **Found during:** Task 2
- **Issue:** Native playback emitted position updates frequently enough to obscure the adjacent-layer evidence.
- **Fix:** Kept each layer's first position observation as the ordered proof while retaining all duration and boundary records.
- **Files modified:** `integration_test/progress_bar_real_runtime_diagnosis_test.dart`
- **Verification:** Windows integration test, analyzer, and fake tracer pass.
- **Committed in:** `51e55edc`

---

**Total deviations:** 1 auto-fixed (1 test diagnostic)
**Impact on plan:** The reduced trace remains complete for required layers and makes the adjacent evidence reproducible without changing production behavior.

## Issues Encountered

- Running Flutter regenerated Windows and macOS plugin registrants; these generated, out-of-scope files were restored before staging.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can insert `ControlBarTimeline` in `ControlBarLayout._buildLayout` and run this diagnostic with `P39_POST_REPAIR=true`.
- No production files changed in this diagnostic plan; `git diff --exit-code` passed for the protected port, controls-state, and ProgressBar files.

## Self-Check: PASSED

- Confirmed both diagnostic artifacts exist and task commits `b08a87bf` and `51e55edc` exist in git history.
- Confirmed the temporary runtime logs were removed and no tracked file deletion is present.

---
*Phase: 39-progress-bar-three-symptoms-root-cause*
*Completed: 2026-08-22*
