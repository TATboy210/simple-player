---
phase: 29-auto-pause-always
plan: 01
subsystem: ui
tags: [flutter, value-notifier, state-machine, settings, playback, controller]

# Dependency graph
requires:
  - phase: 28-settings-shell-split-legacy-deletion
    provides: "split settings-panel edit surface at lib/ui/dialogs/settings/settings_panel_controller.dart"
provides:
  - "deterministic auto-pause policy: open always pauses through SettingsPanelPlayback seam, close resumes only from playing pre-open snapshot"
  - "MediaState _preOpenState snapshot field replacing bool _wasPlaying"
  - "four race regression tests (opening/completed/manual-paused/playing) proving the safe-resume matrix"
affects: [settings-panel redesign phases 30-34, playback-controller pause/resume callers]

# Tech tracking
tech-stack:
  added: []
  patterns: ["semantic projection through narrow seam — derive richer enum snapshot from binary isPlaying signal without widening interface"]

key-files:
  created: []
  modified:
    - "lib/ui/dialogs/settings/settings_panel_controller.dart"
    - "test/ui/dialogs/settings_panel_controller_test.dart"

key-decisions:
  - "Snapshot projected through narrow isPlaying seam as playing vs paused (binary), not full MediaState — seam stays unchanged, no MediaEngine dep"
  - "Non-playing snapshots (opening/completed/manual-paused) all collapse to paused in _preOpenState — safe-resume rule only trusts MediaState.playing"
  - "Unconditional pause on open regardless of pre-open state — safety policy preventing race during later settings-panel phases"

patterns-established:
  - "Semantic projection through narrow seam: derive a richer enum snapshot from a binary signal (isPlaying) without widening the interface — the seam supplies active/not-active, the controller projects it to playing/non-playing for resume decisions"
  - "Always-pause-on-open safety policy: panel open always issues pause() exactly once through the seam, decoupled from the resume decision — non-playing source states also pause to guarantee no playback races during panel-open"

requirements-completed: [PAUSE-01, PAUSE-02, PAUSE-03, PAUSE-04]

# Coverage metadata (#1602) — per-deliverable traceability matrix.
coverage:
  - id: D1
    description: "open() always invokes pause() exactly once through the SettingsPanelPlayback seam, including from a non-playing source state"
    requirement: PAUSE-01
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#open() while playing snapshots wasPlaying=true, pauses once, opens"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#open() while paused still pauses once (always-pause policy) and never resumes on close()"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#open() while already open is a no-op (idempotent)"
        status: pass
    human_judgment: false
  - id: D2
    description: "MediaState _preOpenState snapshot field replacing the bool _wasPlaying field, captured before the pause side effect"
    requirement: PAUSE-02
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: playing snapshot → open → close issues pause once, resumes once (proves snapshot captured before pause, since resume sees playing)"
        status: pass
    human_judgment: false
  - id: D3
    description: "close() resumes only when _preOpenState == MediaState.playing; opening/loading, completed/EOF, and manual-pause snapshots do not issue play()"
    requirement: PAUSE-03
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: opening snapshot → open → close issues pause once, no resume"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: completed snapshot → open → close issues pause once, no resume"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: manually paused snapshot → open → close issues pause once, no resume"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: playing snapshot → open → close issues pause once, resumes once"
        status: pass
    human_judgment: false
  - id: D4
    description: "Four named AAA race regression tests proving loading/opening, EOF, manual-pause, and playing open-close paths through the hand-written SettingsPanelPlayback fake"
    requirement: PAUSE-04
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: opening snapshot"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: completed snapshot"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: manually paused snapshot"
        status: pass
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#PAUSE-04: playing snapshot"
        status: pass
    human_judgment: false

# Metrics
duration: ~30min (across two sessions — context compact mid-implementation)
completed: 2026-07-26
status: complete
---

# Phase 29: auto-pause-always Summary

**Deterministic settings-panel auto-pause: open always pauses through the unchanged seam, close resumes only from a playing pre-open snapshot**

## Performance

- **Duration:** ~30 min (spanned two sessions due to context compact mid Task 3)
- **Tasks:** 4 (all tdd, in-place)
- **Files modified:** 2
- **Tests:** 10 (6 existing updated + 4 new), all passing

## Accomplishments
- Replaced `bool _wasPlaying` with `MediaState _preOpenState` snapshot, captured before the pause side effect (PAUSE-02)
- Made `open()` always invoke `_playback.pause()` unconditionally — non-playing source states also pause (PAUSE-01)
- Made `close()` resume only when `_preOpenState == MediaState.playing`; opening, completed/EOF, and manual-pause paths do not resume (PAUSE-03)
- Added four AAA race regression tests proving the safe-resume matrix through the hand-written fake (PAUSE-04)
- Preserved the narrow `SettingsPanelPlayback` seam (`isPlaying`/`pause()`/`play()`) — zero kernel interface expansion, no direct `MediaEngine` dependency

## Task Commits

Each task was committed atomically:

1. **Task 1: Snapshot pre-open playback as MediaState (tracer, tdd)** — `39bb649` (refactor)
2. **Task 2: open() always pauses through seam (tdd)** — `4cc4eb2` (feat)
3. **Task 3: close() resumes only from playing snapshot (tdd)** — `7524d22` (refactor)
4. **Task 4: Add four race regression tests (tdd)** — `8e88577` (test)

**Plan metadata:** `d8aeb58` (docs: complete plan)

## Files Created/Modified
- `lib/ui/dialogs/settings/settings_panel_controller.dart` — `MediaState _preOpenState` field; `open()` snapshots via `isPlaying` projection then unconditionally pauses; `close()` resumes only for `MediaState.playing` snapshot
- `test/ui/dialogs/settings_panel_controller_test.dart` — evolved `FakePlaybackController` to drive `isPlaying` from a `MediaState _state` field; 4 new AAA regression tests; 6 existing constructors updated to `initialState: MediaState.*`

## Decisions Made
- **Semantic projection over seam widening:** the narrow `isPlaying` seam exposes active/not-active rather than every engine state, so `_preOpenState` is projected as `MediaState.playing` (resumable) vs `MediaState.paused` (non-playing safe representative). This avoids adding a state getter to `SettingsPanelPlayback` or importing `MediaEngine`.
- **Non-playing collapse is intentional:** `opening`/`completed`/`paused` source states all project to `MediaState.paused` in `_preOpenState`. The safe-resume rule only trusts `playing`, so the collapse is safe — none of those states resume. The four call-count tests enforce this externally rather than asserting internal snapshot equality.
- **Snapshot-before-pause ordering:** `_preOpenState` is read before `_playback.pause()` because `pause()` mutates engine state; reading after would lose the pre-open signal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Code Quality - Low] Dropped unnecessary `material.dart` import in test file**
- **Found during:** Task 4 (verify)
- **Issue:** `flutter analyze` reported `unnecessary_import` for `package:flutter/material.dart` — `flutter_test` already re-exports `Offset` (the only symbol used from material). Pre-existing from Phase 23, surfaced by Task 4 verify.
- **Fix:** Removed the import line.
- **Files modified:** `test/ui/dialogs/settings_panel_controller_test.dart`
- **Verification:** `flutter analyze` reports "No issues found!" on both files.
- **Committed in:** `8e88577` (part of Task 4 commit)

**2. [Code Quality - Low] Fixed duplicate doc-comment line in `close()`**
- **Found during:** Task 3 (pre-commit review of own edit)
- **Issue:** Task 3's `close()` doc-comment edit left a duplicate `/// 关闭面板 — 已关闭时 no-op（幂等）。` line (the original line plus a re-typed copy).
- **Fix:** Collapsed to a single line.
- **Files modified:** `lib/ui/dialogs/settings/settings_panel_controller.dart`
- **Verification:** `flutter test` 6 tests still pass; `flutter analyze` clean.
- **Committed in:** `7524d22` (part of Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 low code-quality)
**Impact on plan:** Both are cosmetic cleanups with no scope creep. Plan executed exactly as written for all four PAUSE requirements.

## Issues Encountered
- Context compact mid-implementation (after Task 3 edit applied but before verify/commit). Resumed cleanly from compact summary — Task 3 edit was on disk, TaskList persisted, plan was on disk. No work lost.

## User Setup Required
None — in-process state machine, no external service configuration required.

## Next Phase Readiness
- Auto-pause policy is now deterministic; later settings-panel phases (30-34: sidebar nav, draggable, OK/Cancel/Apply deferred apply, self-built mask) can rely on `open()` always pausing and `close()` resuming only from playing.
- `SettingsPanelPlayback` seam unchanged — future phases that need richer state must widen the seam deliberately, not via controller internals.
- No blockers.

## Commits

```
8e88577 test(29-01): add four race regression tests (PAUSE-04)
7524d22 refactor(29-01): close() resumes only from playing snapshot (PAUSE-03)
4cc4eb2 feat(29-01): open() always pauses through seam (PAUSE-01)
39bb649 refactor(29-01): replace bool _wasPlaying with MediaState _preOpenState (PAUSE-02)
d8aeb58 docs(29): create phase plan
```

---
*Phase: 29-auto-pause-always*
*Completed: 2026-07-26*
