---
phase: 36-medium-grain-rebuild-boundary-refactor
plan: "03"
subsystem: ui
status: complete
completed: 2026-08-11
requirements-completed: [REBUILD-01, REBUILD-04, REBUILD-05]
key-files:
  created:
    - test/widget/player/progress_bar_source_replacement_test.dart
    - test/widget/player/player_video_controls_lifecycle_test.dart
  modified: []
---

# Phase 36 Plan 03: Lifecycle and Source-Replacement Summary

**Wave 3 added headless regressions for ProgressBar seek-hold ownership and PlayerVideoControls/ControlBar source lifecycles. The existing production lifecycle code already satisfied every new assertion, so the RED-only rule resulted in no production modifications.**

## RED / GREEN Evidence

- **ProgressBar initial RED probe:** `flutter test test/widget/player/progress_bar_source_replacement_test.dart` passed immediately. The strengthened probe used tracking notifiers and confirmed a replacement removes the old seek-hold listener while the replacement owns it; old and new position events have opposite asserted outcomes.
- **PlayerVideoControls lifecycle initial RED probe:** `flutter test test/widget/player/player_video_controls_lifecycle_test.dart` passed immediately. Replacement/reparent/dispose behavior already migrated stream and lifecycle listeners correctly.
- **ControlBar blur initial RED probe:** The same lifecycle suite passed immediately. Replacing opacity/resizing sources causes only the new resize notifier to disable blur; the old notifier is isolated.
- **Production fixes:** None. No genuine RED result authorized changes to `progress_bar.dart`, `player_video_controls.dart`, or `control_bar.dart`.

## Added Coverage

- ProgressBar drag-end seek-hold source replacement with same-key retained State:
  - old position listener ownership falls back to the retained paint listener only;
  - new position source receives the seek-hold listener;
  - old target arrival cannot complete the hold;
  - new target arrival completes it;
  - a second drag followed by unmount leaves no observable callback/error or pending timer.
- PlayerVideoControls replacement and two GlobalKey reparent cycles:
  - old port streams are unsubscribed; new port owns exactly one round of eight subscriptions;
  - old title/resize/engine/player events cannot mutate the retained UI/padding;
  - new title/resize source remains active;
  - unmount silences active sources and removes stream subscriptions.
- ControlBar blur merged-signal replacement:
  - replacing opacity/resizing sources leaves the old resize notifier unable to change blur;
  - the replacement resize notifier continues to disable blur.

## Verification

- PASS: `flutter test test/widget/player/progress_bar_source_replacement_test.dart` — focused initial probe passed.
- PASS: `flutter test test/widget/player/player_video_controls_lifecycle_test.dart` — focused initial lifecycle probe passed.
- PASS: `flutter test test/widget/player/progress_bar_source_replacement_test.dart test/widget/player/player_video_controls_lifecycle_test.dart test/widget/player/player_video_controls_test.dart test/widget/player/control_bar_rebuild_boundary_test.dart` — 41 tests passed.
- PASS: `flutter analyze` — no issues found.
- PASS: `git diff --check` — no whitespace errors; only pre-existing LF-to-CRLF warnings for `.planning/ROADMAP.md` and `.planning/STATE.md`.

## Protected File Check

- `lib/ui/window/custom_title_bar.dart` diff hash was unchanged before and after execution: `26c331897532f87fe792f05b47ace3f12673962a`.
- Existing untracked screenshots remained unchanged: `114514-upscaled.png`, `devtools-current.png`, `devtools-live-performance.png`, and `devtools-performance.png`.
- No media_kit source changed, and `ControlsOverlay` was not restored.
- The only Wave 3 code artifacts are the two planned test files; no plan-listed production file required a verified repair.

## Unresolved Issues

- None within Plan 36-03. The automated evidence is intentionally headless and project-layer scoped; native texture/profile behavior remains for later render/performance validation.
