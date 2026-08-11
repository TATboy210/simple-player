---
phase: 36-medium-grain-rebuild-boundary-refactor
plan: "01"
subsystem: ui
tags: [flutter, widget-test, value-notifier, control-bar, rebuild-boundary]

requires:
  - phase: 35-widget-tree-baseline-behavior-recovery
    provides: "Direct ControlBar architecture and fake-port widget-test infrastructure"
provides:
  - "Real-ControlBar rebuild-boundary regression tests for title, idle, playing, volume/mute, and progress notifiers"
  - "Static title compatibility regression coverage"
affects: [phase-37-render-boundaries, phase-38-verification, ControlBar]

actuals:
  tokens: 2000
  tasks: 2
  commits: 0

tech-stack:
  added: []
  patterns:
    - "Exercise notifier isolation through a real ControlBar backed by independent ValueNotifier sources."
    - "Use Element identity plus an outer build probe to prove non-target ControlBar regions remain stable."

key-files:
  created:
    - test/widget/player/control_bar_rebuild_boundary_test.dart
  modified: []

key-decisions:
  - "No production change was made: every planned RED probe passed against the existing local ValueListenableBuilder boundaries."
  - "Tests use test-owned ValueNotifier sources only, so they do not initialize media_kit or add production instrumentation."

patterns-established:
  - "A state-specific update must assert both the target's observable change and stable identities for at least two unrelated slices."

requirements-completed: [REBUILD-01, REBUILD-02, REBUILD-05]

coverage:
  - id: D1
    description: "A titleListenable update displays the new title while the ControlBar shell, layout, timeline, actions, and progress elements remain stable; a static title remains supported."
    requirement: REBUILD-02
    verification:
      - kind: unit
        ref: "test/widget/player/control_bar_rebuild_boundary_test.dart#title change rebuilds only title slice"
        status: pass
      - kind: unit
        ref: "test/widget/player/control_bar_rebuild_boundary_test.dart#static title remains available without a listenable"
        status: pass
    human_judgment: false
  - id: D2
    description: "Idle, playing, volume/mute, and position/duration updates remain in their direct ControlBar consumer regions without replacing unrelated slice elements or rebuilding the ControlBar shell."
    requirement: REBUILD-01
    verification:
      - kind: unit
        ref: "test/widget/player/control_bar_rebuild_boundary_test.dart"
        status: pass
      - kind: other
        ref: "flutter test test/widget/player/control_bar_rebuild_boundary_test.dart test/widget/player/control_bar_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "The rebuild-boundary regression suite preserves the direct ControlBar architecture without introducing a new monolith or state-management dependency."
    requirement: REBUILD-05
    verification:
      - kind: other
        ref: "flutter analyze && git diff --check"
        status: pass
    human_judgment: false

duration: "0 min"
completed: 2026-08-11
status: complete
---

# Phase 36 Plan 01: Medium-Grain Rebuild Boundary Summary

**ControlBar now has end-to-end notifier-isolation regression coverage proving title, idle, playback, volume/mute, and progress updates leave unrelated ControlBar slices stable.**

## Performance

- **Tasks:** 2
- **Files created by this plan:** 1 widget test and this summary
- **Production fixes:** None required; the planned RED probes were green against the existing local listeners.
- **Commits:** None. Existing user worktree changes were preserved.

## RED / GREEN Evidence

- **RED attempt:** Added the title-boundary test first and ran `flutter test test/widget/player/control_bar_rebuild_boundary_test.dart --plain-name "title change rebuilds only title slice"`. It passed immediately, showing `ControlBarTitle` already owns the dynamic title listener and the rest of the ControlBar does not rebuild.
- **GREEN verification:** Added independent idle, playing, volume/mute, and progress boundary cases. All passed without production edits, so the plan's red-light-only repair rule prohibited unnecessary refactoring.

## Accomplishments

- Added a real-ControlBar harness with independent `ValueNotifier` sources; it avoids media_kit and records an outer build boundary.
- Locked title updates to the title slice through new text visibility plus stable ControlBar/layout/timeline/actions/progress element identities, and retained the static `title` API path.
- Locked idle to `CenterGroup`, playing to the play/pause leaf, volume/mute to the volume area, and progress to the timeline consumers while checking unrelated slices and the ControlBar shell remain stable.
- Confirmed the existing behavior suite and analyzer remain clean.

## Files Created/Modified

- `D:/simple_player_flutter/test/widget/player/control_bar_rebuild_boundary_test.dart` - End-to-end local rebuild-boundary and static-title compatibility regressions.
- `D:/simple_player_flutter/.planning/phases/36-medium-grain-rebuild-boundary-refactor/36-01-SUMMARY.md` - Plan execution, RED/GREEN, and verification record.

## Decisions Made

- Preserved the existing direct `ControlBar` architecture because tests confirmed it already satisfies the planned medium-grain listener boundaries.
- Did not modify `control_bar.dart`, `control_bar_layout.dart`, `control_bar_title.dart`, `control_bar_actions.dart`, or `control_bar_test.dart`; no verified RED failure authorized a production change.

## Deviations from Plan

None - the plan explicitly permits retaining only tests when current production behavior satisfies the new assertions.

## Issues Encountered

- The initial title test did not become RED: current production already consumes `titleListenable` inside `ControlBarTitle`. This is expected proof that no production repair is needed, not an unresolved failure.
- `git diff --check` reported only pre-existing LF-to-CRLF warnings for `.planning/ROADMAP.md` and `.planning/STATE.md`; it reported no whitespace errors.

## User Setup Required

None - no external service configuration required.

## Verification

- PASS: `flutter test test/widget/player/control_bar_rebuild_boundary_test.dart --plain-name "title change rebuilds only title slice"` — focused title boundary test passed.
- PASS: `flutter test test/widget/player/control_bar_rebuild_boundary_test.dart test/widget/player/control_bar_test.dart` — 27 tests passed.
- PASS: `flutter analyze` — no issues found.
- PASS: `git diff --check` — no whitespace errors (only existing line-ending warnings).

## Next Phase Readiness

Phase 37 can rely on automated ControlBar notifier-isolation coverage. No unresolved Phase 36 production issue remains; visual resize/profile validation remains a later-phase responsibility.
