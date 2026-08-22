---
phase: 39-progress-bar-three-symptoms-root-cause
plan: 02
subsystem: ui
tags: [flutter, windows, media-kit, progress-bar, control-bar, diagnostics]
requires:
  - phase: 39-progress-bar-three-symptoms-root-cause
    provides: "Evidence-backed first broken production edge at ControlBarLayout._buildLayout"
provides:
  - "Production ControlBar timeline composition driven by stable controls-state notifiers"
  - "Disposable merged-listener ownership across PlayerPort replacement and seek hold"
  - "Strict Windows raw-to-widget post-repair diagnostic evidence"
affects: [progress-bar, control-bar, Windows-smoke]
actuals:
  tokens: 13300
  tasks: 3
  commits: 3
tech-stack:
  added: []
  patterns:
    - "Explicitly owned merged listenables for replaceable ValueListenable sources"
    - "Strict runtime trace kept separate from pre-repair root-cause evidence"
key-files:
  created: []
  modified:
    - lib/ui/player/control_bar_layout.dart
    - lib/ui/player/progress_bar.dart
    - test/widget/player/progress_bar_data_chain_diagnosis_test.dart
    - test/widget/player/progress_bar_source_replacement_test.dart
    - test/widget/player/progress_bar_test.dart
    - integration_test/progress_bar_real_runtime_diagnosis_test.dart
    - .planning/milestones/v1.8-phases/39-progress-bar-three-symptoms-root-cause/39-DIAGNOSIS.md
key-decisions:
  - "Repair the diagnosed production composition edge by inserting the existing ControlBarTimeline into ControlBarLayout."
  - "Own merged listenable registrations so source replacement cannot retain old-port callbacks."
  - "Keep pre-repair diagnosis immutable and append an independently labeled post-repair runtime trace."
requirements-completed: [PROG-01, PROG-02, PROG-03]
coverage:
  - id: D1
    description: "Production ControlBar composes the timeline and exposes stream-driven progress semantics."
    requirement: PROG-01
    verification:
      - kind: automated_ui
        ref: "test/widget/player/progress_bar_data_chain_diagnosis_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Seek hold and listeners migrate safely when PlayerPort sources are replaced."
    requirement: PROG-02
    verification:
      - kind: unit
        ref: "test/widget/player/progress_bar_source_replacement_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Hover preview updates formatted time and geometry from 25% to 75%, while Windows runtime proves the repaired data chain."
    requirement: PROG-03
    verification:
      - kind: automated_ui
        ref: "test/widget/player/progress_bar_test.dart#hover preview updates text and geometry across the bar"
        status: pass
      - kind: integration
        ref: "P39_POST_REPAIR=true D:/flutter/bin/flutter test integration_test/progress_bar_real_runtime_diagnosis_test.dart -d windows"
        status: pass
    human_judgment: true
    rationale: "Phase 41 Windows smoke remains the visual backstop for real pointer appearance and bubble rendering."
duration: 54 min
completed: 2026-08-22
status: complete
---

# Phase 39 Plan 02: Progress Bar Three Symptoms Root Cause Summary

**Restored the production ControlBar timeline, safe notifier replacement ownership, and strict Windows runtime evidence from raw media_kit streams through the visible progress widget.**

## Performance

- **Duration:** 54 min
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Inserted the existing `ControlBarTimeline` at the diagnosis-confirmed `ControlBarLayout._buildLayout` boundary, restoring ProgressBar composition in the production shell.
- Made slider semantics follow duration/position streams and made merged listeners disposable, so source replacement releases old PlayerPort callbacks while seek hold attaches to the active source.
- Added hover preview assertions for formatted time and position, and upgraded the Windows gate to emit strict post-repair raw-to-widget progression and Player-disposal evidence.

## Task Commits

1. **Task 1: restore production duration/position chain** - `ccaae0b` (fix)
2. **Task 2: lock seek-hold and source replacement ownership** - `a2f41cc` (fix)
3. **Task 3: verify hover and Windows runtime repair** - `c9d9aa1` (test)

## Verification

- Passed focused widget suite: `progress_bar_data_chain_diagnosis_test.dart`, `progress_bar_test.dart`, `progress_bar_source_replacement_test.dart`, `player_video_controls_test.dart`, and `player_video_controls_lifecycle_test.dart`.
- Passed Windows runtime gate with `P39_POST_REPAIR=true`; trace recorded non-zero raw/port/state/widget duration, position advancement, timeline insertion, and `postRepair.playerDisposed=true`.
- Passed `D:/flutter/bin/flutter analyze` and `git diff --check`.
- Protected-path review found no `media_kit` or `.pub-cache` changes.

## Decisions Made

- Compose the existing timeline rather than create a parallel controls tree or new mirrored state.
- Use a disposable forwarding-listenable wrapper because `Listenable.merge` itself does not expose lifecycle cleanup.
- Retain the pre-repair diagnosis verbatim and append a distinct post-repair trace for auditability.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Lifecycle bug] Released obsolete merged-listener callbacks during source replacement.**
- **Found during:** Task 2
- **Issue:** Replacing a `ProgressBar` source retained callbacks registered by abandoned `Listenable.merge` instances.
- **Fix:** Added explicit owned merged-listenable disposal and migrated the seek-hold listener from the old position source to the active source.
- **Files modified:** `lib/ui/player/progress_bar.dart`, `test/widget/player/progress_bar_source_replacement_test.dart`
- **Verification:** Focused progress widget suite passed.
- **Committed in:** `a2f41cc`

---

**Total deviations:** 1 auto-fixed (Rule 1 lifecycle bug).
**Impact on plan:** Required for correct source isolation and timer/listener cleanup; no scope expansion beyond the task's lifecycle contract.

## Issues Encountered

- Flutter test invocations regenerated CRLF-only Windows/macOS plugin registrants. They were deliberately left unstaged and excluded from every commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 41 Windows smoke should visually confirm hover bubble appearance and pointer tracking on a live desktop session.
- The post-repair trace is recorded in `39-DIAGNOSIS.md`; no media_kit package or pub-cache changes were made.

## Self-Check: PASSED

- Confirmed task commits `ccaae0b`, `a2f41cc`, and `c9d9aa1` exist in worktree history.
- Confirmed all seven key modified files exist and the Windows strict runtime gate passed.
