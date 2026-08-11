---
phase: 36-medium-grain-rebuild-boundary-refactor
plan: "02"
subsystem: ui
tags: [flutter, widget-test, player-screen, rebuild-boundary, source-replacement]

requires:
  - phase: 36-medium-grain-rebuild-boundary-refactor/01
    provides: "ControlBar notifier-boundary regression coverage"
provides:
  - "Headless PlayerScreen identity coverage across ordinary shell rebuilds, mode transitions, resize sessions, and WindowBridge replacement."
  - "PlayerScreen controller and engine replacement coverage proving stable video surface identity and old-source isolation."
  - "Stable PlayerActions dynamically delegate replacement-sensitive host callbacks at invocation time."
affects: [phase-37-render-boundaries, phase-38-verification, PlayerScreen]

key-files:
  created:
    - test/widget/player/player_screen_identity_source_replacement_test.dart
  modified:
    - lib/ui/player/player_screen.dart

requirements-completed: [REBUILD-03, REBUILD-04, REBUILD-05]
status: complete
completed: 2026-08-11
---

# Phase 36 Plan 02: Medium-Grain Rebuild Boundary Summary

**PlayerScreen now has injected-surface evidence that its title, surface, and controls Elements survive normal shell updates, window mode changes, and resize sessions, while replaced dependencies stop driving the current tree. Stable actions also dynamically delegate replacement-sensitive host callbacks.**

## RED / GREEN Evidence

- **Task 1 initial probe:** The identity test passed immediately for ordinary keyed shell rebuilds, mode changes, and three resize sessions. No production identity/cache repair was required.
- **Task 2 RED:** `flutter test test/widget/player/player_screen_identity_source_replacement_test.dart` initially failed with `Expected: <0> Actual: <1>` for the old controller's `togglePlayPauseCallCount`. Stable `_actions` had captured the original controller callback.
- **Task 2 GREEN:** `_actions` now reads `widget.controller` at invocation time, preserving its identity without dispatching commands to a replaced controller. The PlayerScreen listener pair for open-file availability now migrates from old engine/controller sources to new ones in `didUpdateWidget`.

## Follow-up: Stable Host Callback Replacement

- **RED:** Added a headless injected-surface regression that replaces `onSettingsSecondary`, `onFilesDropped`, and `onDragHoverChanged` on the same keyed `PlayerScreen` State. It initially called the old secondary-settings callback through stable `_actions`.
- **GREEN:** The stable `PlayerActions` now invokes all three callbacks through the current `widget` at call time, so the actions and controls Elements retain identity while only the newly supplied host callbacks run.
- The regression directly invokes the fake-backed controls actions and does not construct media_kit `Video` or load MDK/libmpv.

## Accomplishments

- Added headless integration coverage using `videoSurfaceBuilder` and `FakeVideoControlsPort`; no real `Video`, MDK, or native texture is constructed.
- Asserted title, surface, and `PlayerVideoControls` Element identity through a parent-equivalent rebuild, maximization, and three resize sessions.
- Asserted WindowBridge replacement leaves surface/controls mounted, ignores old bridge mode/resize state, and observes new bridge fullscreen state.
- Asserted engine/controller replacement preserves surface identity, hides an old controller title update, accepts a new title update, and routes Play to only the new controller/engine.
- Made the minimal verified production repair in `PlayerScreen`; `PlayerVideoControls` already had source migration logic and was not changed.

## Files Created/Modified

- `D:/simple_player_flutter/test/widget/player/player_screen_identity_source_replacement_test.dart` - PlayerScreen identity, bridge replacement, and controller/engine replacement regressions.
- `D:/simple_player_flutter/lib/ui/player/player_screen.dart` - Invoke-time controller and replacement-sensitive host callback resolution, plus source listener migration.
- `D:/simple_player_flutter/.planning/phases/36-medium-grain-rebuild-boundary-refactor/36-02-SUMMARY.md` - Execution record.

## Verification

- PASS: `flutter test test/widget/player/player_screen_identity_source_replacement_test.dart test/widget/player/player_screen_accessibility_resize_test.dart test/widget/player/player_screen_window_bridge_replacement_test.dart` — 6 tests passed.
- PASS: `flutter test test/widget/player/player_screen_identity_source_replacement_test.dart --plain-name "controller and engine replacement use only new sources"` — focused replacement regression passed.
- PASS follow-up: `flutter analyze` — no issues found after the callback-replacement regression addition.
- PASS follow-up: `git diff --check` — no whitespace errors; it emitted only pre-existing LF-to-CRLF warnings for `.planning/ROADMAP.md` and `.planning/STATE.md`.

## Protected Worktree Baseline

- `lib/ui/window/custom_title_bar.dart` was only read. Its diff hash before execution and after verification is unchanged: `26c331897532f87fe792f05b47ace3f12673962a`.
- The four pre-existing PNG porcelain entries remained exactly unchanged: `114514-upscaled.png`, `devtools-current.png`, `devtools-live-performance.png`, and `devtools-performance.png` are all untracked.
- No screenshot, media_kit source, or `ControlsOverlay` was modified or restored.

## Unresolved Issues

- None within this plan. Headless tests deliberately establish project-layer Element/source behavior only; native texture rendering remains a later visual/performance validation concern.
