---
phase: 17-adaptive-control-bar
plan: 01
status: complete
completed: "2026-07-03"
---

# Summary: Phase 17 Plan 01 — Adaptive Control Bar

## What Was Built

1. **AnimatedContainer transition**: `Container` → `AnimatedContainer` with 150ms `easeInOut` curve for color + border interpolation between idle/playing states
2. **Decoration getters**: `_decorationPlaying` and `_decorationIdle` converted from `static final` to getters so AnimatedContainer receives new `BoxDecoration` each build
3. **EdgeGlow sync**: `glowIntensity: isIdle ? 0.3 : null` — instant switch appears coordinated with 150ms background transition
4. **Animation tests**: 4 new tests verifying AnimatedContainer presence, idle/playing decorations, state transitions, and curve type
5. **Golden tests updated**: `control_bar_idle.png` and `control_bar_playing.png` reflect new decorations

## Files Modified

| File | Change |
|------|--------|
| `lib/ui/player/control_bar.dart` | static final → getters, Container → AnimatedContainer |
| `lib/ui/player/center_controls.dart` | idle token wiring for title text |
| `test/widget/player/control_bar_test.dart` | +4 animation tests |
| `test/golden/goldens/control_bar_idle.png` | Updated golden |
| `test/golden/goldens/control_bar_playing.png` | Updated golden |

## Key Decisions

- D-01: AnimatedContainer over manual Tween (minimal code change)
- D-02: 150ms duration (Tokens.durationNormal) — fast but perceptible
- D-06: boxShadow stays static final, not interpolated
- D-07: Getters instead of methods for decoration

## Self-Check: PASSED

- [x] AnimatedContainer present with 150ms easeInOut
- [x] Idle decoration uses lighter colors (controlBarBgIdle)
- [x] Playing decoration unchanged
- [x] 18 control bar tests pass (14 existing + 4 animation)
- [x] 14 golden tests pass
- [x] flutter analyze: no issues
- [x] Zero constructor changes — backward compatible
