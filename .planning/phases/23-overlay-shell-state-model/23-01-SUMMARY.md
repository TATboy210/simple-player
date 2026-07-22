---
phase: 23-overlay-shell-state-model
plan: 01
subsystem: ui
tags: [settings-panel, state-model, tdd, facade, value-notifier]

# Dependency graph
requires:
  - phase: 22-bilingual-api-docs
    provides: bilingual doc comment conventions applied to kernel/services APIs
provides:
  - AppleCurves animation curve utility tracked in git (fullscreenEnter/fullscreenExit locked per D-08)
  - SettingsPanelPlayback narrow service-boundary contract on PlaybackController (D-03)
  - SettingsPanelState pure state model (exactly 3 ValueNotifiers — PANEL-01)
  - SettingsPanelController open/close/toggle lifecycle with wasPlaying snapshot semantics (PANEL-02)
affects: [23-02-overlay-shell-widget, 25-tabs-settings-shell]

# Tech tracking
tech-stack:
  added: []
  patterns: [narrow-service-interface-boundary, fakes-over-mocks, strangler-fig-extraction]

key-files:
  created:
    - lib/ui/dialogs/settings/settings_panel_state.dart
    - lib/ui/dialogs/settings/settings_panel_controller.dart
    - test/ui/dialogs/settings_panel_state_test.dart
    - test/ui/dialogs/settings_panel_controller_test.dart
  modified:
    - lib/kernel/services/playback_controller.dart
    - lib/ui/shared/apple_curves.dart (tracked, no code change)

key-decisions:
  - "D-08 (advisory, auto-recorded): fullscreenEnter uses AppleCurves.fullscreenEnter (open curve), fullscreenExit uses AppleCurves.fullscreenExit (close curve)"
  - "D-03: SettingsPanelController never touches MediaEngine directly — routes through SettingsPanelPlayback interface implemented by PlaybackController, avoiding races with the openGeneration open guard"
  - "Fakes over mocks: FakePlaybackController implements SettingsPanelPlayback hand-written test double, avoiding real MediaEngine/mdk.dll headless FFI dependency"

patterns-established:
  - "Pattern: narrow service-boundary interface (SettingsPanelPlayback) — UI-facing controllers depend on a minimal abstract interface implemented by the facade, not the facade's full surface or the underlying engine"

requirements-completed: [PANEL-01, PANEL-02]

coverage:
  - id: D1
    description: "AppleCurves fullscreen open/close curves tracked in git (untracked file risk closed)"
    verification:
      - kind: other
        ref: "git ls-files --error-unmatch lib/ui/shared/apple_curves.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "SettingsPanelPlayback contract added to PlaybackController (D-03 service boundary)"
    requirement: "PANEL-02"
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/services/playback_controller.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "SettingsPanelState — exactly 3 ValueNotifiers (isOpen/selectedTab/dragOffset), correct init + dispose"
    requirement: "PANEL-01"
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_state_test.dart#SettingsPanelState"
        status: pass
    human_judgment: false
  - id: D4
    description: "SettingsPanelController open/close/toggle lifecycle with wasPlaying snapshot, idempotent open/close, dragOffset reset on close"
    requirement: "PANEL-02"
    verification:
      - kind: unit
        ref: "test/ui/dialogs/settings_panel_controller_test.dart#SettingsPanelController"
        status: pass
    human_judgment: false

# Metrics
duration: 45min
completed: 2026-07-23
status: complete
---

# Phase 23 Plan 01: Settings Panel State Model Summary

**SettingsPanelState (3 ValueNotifiers) + SettingsPanelController (open/close/toggle with wasPlaying pause/resume) built on a new SettingsPanelPlayback narrow-interface boundary added to PlaybackController, via strict TDD RED→GREEN.**

## Performance

- **Duration:** 45 min
- **Started:** 2026-07-23T00:00:00Z (approx, prior context window)
- **Completed:** 2026-07-23T01:05:00Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Tracked previously-untracked `AppleCurves` utility in git, locking the D-08 advisory decision (fullscreenEnter/fullscreenExit curve assignment) into the execution record without pausing for user input
- Added `SettingsPanelPlayback` abstract interface to `PlaybackController` (D-03 service boundary), implemented via thin forwarders to `MediaEngine.pause()`/`play()`/`state` — no new engine-level code required, existing `MediaState.playing` enum and `PlaybackControl` members were sufficient
- Implemented `SettingsPanelState` (PANEL-01) and `SettingsPanelController` (PANEL-02) via full TDD RED→GREEN cycle: 8 tests written and confirmed failing first, then minimal implementation made all 8 pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Advisory checkpoint — D-08 curve decision** - _(no commit; advisory decision recorded in execution record only, auto-continued per plan instruction)_
2. **Task 2a: Track AppleCurves file** - `8469d12` (chore)
2. **Task 2b: Add SettingsPanelPlayback contract to PlaybackController** - `dafd2ba` (feat)
3. **Task 3a: RED — failing tests for state and controller** - `382c6e6` (test)
3. **Task 3b: GREEN — implement SettingsPanelState and SettingsPanelController** - `6d453b5` (feat)

**Plan metadata:** _(pending — this commit)_

_Note: TDD task (Task 3) has 2 commits (test → feat); no refactor commit was needed since the GREEN implementation was already minimal and clean on first pass._

## Files Created/Modified
- `lib/ui/shared/apple_curves.dart` - Tracked in git (no code change); provides `AppleCurves.fullscreenEnter`/`fullscreenExit` and other animation curves used by the future overlay shell widget
- `lib/kernel/services/playback_controller.dart` - Added `SettingsPanelPlayback` abstract interface + `PlaybackController implements SettingsPanelPlayback` with `pause()`/`play()`/`isPlaying` forwarders
- `lib/ui/dialogs/settings/settings_panel_state.dart` - New pure state model: exactly 3 `ValueNotifier`s (`isOpen`, `selectedTab`, `dragOffset`) + `dispose()`
- `lib/ui/dialogs/settings/settings_panel_controller.dart` - New lifecycle controller: `open()`/`close()`/`toggle()`/`dispose()`, coordinating pause/resume via `SettingsPanelPlayback` and resetting `dragOffset` to `Offset.zero` on close
- `test/ui/dialogs/settings_panel_state_test.dart` - New test file: init values + dispose behavior (2 tests)
- `test/ui/dialogs/settings_panel_controller_test.dart` - New test file: `FakePlaybackController implements SettingsPanelPlayback` hand-written fake + 6 lifecycle tests (open-while-playing, open-while-paused, close-resumes, idempotent open, idempotent close, toggle)

## Decisions Made
- **D-08 (advisory, locked)**: `fullscreenEnter` uses `AppleCurves.fullscreenEnter` (open curve), `fullscreenExit` uses `AppleCurves.fullscreenExit` (close curve). Recorded per plan instruction without halting for user input (advisory gate, single locked option).
- **D-03 (service boundary)**: `SettingsPanelController` never touches `MediaEngine` directly. It depends only on the narrow `SettingsPanelPlayback` interface (`isPlaying`/`pause()`/`play()`), which `PlaybackController` implements as thin forwarders. This avoids races with the `openGeneration` open guard inside `PlaybackNavigator`.
- **Fakes over mocks**: Used a hand-written `FakePlaybackController implements SettingsPanelPlayback` test double instead of a mocking framework, per CLAUDE.md convention — avoids depending on the real `MediaEngine`/mdk.dll, sidestepping the ~57 pre-existing headless FFI test failures documented in project memory.
- **wasPlaying snapshot ordering**: `open()` reads `_playback.isPlaying` *before* calling `_playback.pause()` (pause mutates the fake's/engine's playing state), ensuring the snapshot reflects the state prior to the pause call — verified explicitly in the controller test suite.

## Deviations from Plan

None — plan executed exactly as written. Two minor environment/tooling adjustments were made, neither of which altered the plan's designed behavior or scope:

1. **Tooling discovery (not a deviation)**: The plan's `<verify>` blocks assumed `flutter test ... -x` as a bare exclusion flag; this Flutter version requires `-x` to take a tag argument. Ran `flutter test -h` to confirm, then ran the equivalent verification commands without `-x`. No test logic or scope was changed.
2. **[Rule 3 - Blocking] Missing `dart:ui` import in `settings_panel_state.dart`**
   - **Found during:** Task 3 (GREEN implementation)
   - **Issue:** `Offset` type used in `SettingsPanelState` but only `package:flutter/foundation.dart` was imported, which does not re-export `dart:ui`'s `Offset` — `flutter analyze` reported `non_type_as_type_argument` / `undefined_identifier` errors.
   - **Fix:** Added `import 'dart:ui';` to the top of the file.
   - **Files modified:** `lib/ui/dialogs/settings/settings_panel_state.dart` (included in the same GREEN commit, not a separate commit)
   - **Verification:** `flutter analyze lib/ui/dialogs/settings/` → "No issues found!"
   - **Committed in:** `6d453b5` (part of Task 3 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — missing import), plus 1 tooling-only discovery (no code impact).
**Impact on plan:** No scope creep. Both adjustments were necessary corrections to make the plan's own verification steps executable/correct; the plan's designed architecture, files, and tests are unchanged.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `SettingsPanelState`/`SettingsPanelController` are ready for the overlay shell widget (Plan 23-02) to consume — construction requires only a `SettingsPanelPlayback` implementation (satisfied by the existing `PlaybackController` instance already wired in the composition root).
- `AppleCurves.fullscreenEnter`/`fullscreenExit` are tracked and available for the shell's open/close transition animations per the locked D-08 decision.
- No blockers identified for Plan 23-02.

---
*Phase: 23-overlay-shell-state-model*
*Completed: 2026-07-23*
