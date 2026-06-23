# Summary: Plan 18-01 — PlayerActions Record

**Completed:** 2026-06-22
**Requirement:** ARCH-04, ARCH-05

## What Changed

Created `PlayerActions` class (`lib/ui/player/player_actions.dart`) with 17 fields (14 callbacks + 3 data), replacing scattered callback parameters across the PlayerScreen → ControlsOverlay → ControlBar chain.

### Files Modified

| File | Change |
|------|--------|
| `lib/ui/player/player_actions.dart` | **NEW** — PlayerActions class |
| `lib/ui/player/control_bar.dart` | 12 params → 7 (engine, actions, isFullscreen, enableBlur, isIdle, opacity, resizing) |
| `lib/ui/player/controls_overlay.dart` | 14 params → 5 (engine, actions, isFullscreen, emptyStatePresent, resizing) |
| `lib/ui/player/player_screen.dart` | Constructs PlayerActions in build(), passes to ControlsOverlay |
| `test/widget/player/control_bar_test.dart` | Updated buildSubject to use PlayerActions |
| `test/widget/player/controls_overlay_test.dart` | Updated buildSubject to use PlayerActions |
| `test/perf/control_bar_perf_test.dart` | Updated helpers to use PlayerActions |

### Parameter Reduction

| Widget | Before | After |
|--------|--------|-------|
| ControlBar | 16 params | 7 params |
| ControlsOverlay | 14 params | 5 params |

## Verification

- 658 tests pass, 0 failures
- All callback behavior preserved
- PlayerActions is const-constructible
