# Phase 31 Verification — visual-design-alignment

status: **passed-with-note** (pending user confirmation of by-design interpretation)
date: 2026-07-28
verifier: gsd-verifier (sonnet) + orchestrator analysis

## Requirements Coverage

| ID | Requirement | Verdict | Evidence |
|----|-------------|---------|----------|
| VISUAL-01 | ControlBarDecoration shared chrome API | **COVERED** | `lib/ui/shared/control_bar_decoration.dart` (`playing({BorderRadius?})` / `idle({BorderRadius?})` factories); title-bar + button-bar + tab-strip routed; `panel_color_test` re-baselined. Commits `e0e1bd00`/`c1b023ac`/`28b92bca`. |
| VISUAL-02 | Option rows three-state (default/hover/focused/pressed) | **PARTIAL-by-design** | Interactive (`onTap`) rows: COVERED — `FocusableSettingRow` + `InkWell canRequestFocus:false` + `bgHover` hover + 1px `controlBarBorderWhite` focused border + `accent` active value (`settings_card_test`). Container rows (switch/spin/slider, no row `onTap`): **EXEMPT per D-15** — `FocusableSettingRow enabled:false` → `ExcludeFocus`+`IgnorePointer`, controls own focus/interaction. Test-coverage gap: no test asserts D-15 exempt behavior on shipped General/Equalizer container rows. |
| VISUAL-03 | 40px density + spXs padding + InkWell no-scale | **COVERED** | `settings_card.dart:65-70` (`SizedBox height:38` + `Padding spXs`; `FocusableSettingRow` border slot preserves 40px outer); tests assert geometry; no `Transform.scale`. |
| VISUAL-04 | Accent active-value | **COVERED-code / human_review-pending** | `settings_card.dart:113-127` (`_buildControl` applies `Tokens.accent` to `Text` when focused). Test asserts token. Perceptual readability on glass NOT verified (Task 2 user-approved, no recorded profile evidence). |
| VISUAL-05 | Single focus owner | **COVERED-code** | `FocusableSettingRow` is sole focus owner; `InkWell canRequestFocus:false`. Test asserts one focus route. Keyboard traversal to Phase 32 not yet exercised. |

## Rule 1 Deviation Audit

- **Wave 1 (31-01)**: BackdropFilter gate narrowed to panel-ancestor chain (not literal entire subtree == 1 filter). **COMPLIANT** — assertion strength preserved (panel-level blur uniqueness); cards have own `GlassContainer` since Phase 25, so subtree-wide single-filter was never the intent. Recorded in `31-01-SUMMARY`.
- **Wave 1 (31-01)**: 30-03 group re-baseline (chrome color path contract post-split). **COMPLIANT** — re-aligned to new chrome/content split, no assertion weakened.
- **Wave 2 (31-02)**: disabled-row geometry preservation + stale General/Equalizer test API rebase. **COMPLIANT** — geometry preserved, coverage retained.

## Human Review Limitations

- **Task 2 (31-03) human-verify checkpoint**: user approved via `继续`. Profile-mode A/B raster comparison NOT recorded as measurable evidence (pre baseline raster avg 1.8547ms, threshold 2.85471ms). Perceptual checks (chrome seams, accent readability, ripple behavior, 40px usability) delegated to user discretion.
- **F12 profile-export tooling** (commit `4304aee4`) remains in `keyboard_handler.dart` — debug/profile-only, does not alter release visual rendering. Scheduled for removal post-phase per user instruction.

## Pre-existing Baseline (out of scope)

- ~57 `mdk.dll` FFI headless test failures (memory: `reference_mdk_dll_headless_test_failures.md`)
- `settings_focus_navigation_test.dart` compile error (`FakePlaybackController(initiallyPlaying:)` — stash-introduced)
- 4 Phase 25 settings-dialog headless failures
- 114 kernel bridge/stash analyze diagnostics
- Phase 31 module boundary (`lib/ui/shared` + `lib/ui/dialogs/settings` + `lib/ui/player/control_bar` + `lib/ui/player/keyboard_handler`): **0 new failures, 0 new diagnostics**.

## Status

**passed-with-note**: Code layer complete across 9 commits (3 waves). VISUAL-02 partial-by-design (container rows exempt per D-15); test-coverage gap on exempt behavior is non-blocking. VISUAL-04/05 perceptual dimensions pending human review (user-approved checkpoint).

**Recommendation**: accept by-design interpretation + complete phase + remove F12 tool + pop stash; optionally add D-15 exempt-row test in a Phase 32/follow-up.

## Verifier note

gsd-verifier returned `gaps_found` based on a strict reading of "option rows" as "all settings rows". Orchestrator analysis: container rows are exempt per D-15 (controls own focus/interaction), so the gap is a test-coverage gap (no test asserts exempt behavior on shipped paths), not a code defect. User decision pending.
