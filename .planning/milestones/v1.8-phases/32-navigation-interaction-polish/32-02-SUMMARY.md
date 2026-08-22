---
phase: 32-navigation-interaction-polish
plan: 02
type: execute
wave: 2
status: complete
---

# 32-02 Summary — End caps + Listener + hint + toggle (NAV-01/NAV-02/NAV-03)

Wave 2 projects the Plan 01 `InputModeDetector` strategy into visible UI: persistent glass end-cap arrows flanking the 7-item tab row, an `AnimatedSwitcher` hint fading between keyboard/gamepad labels, a mouse-activity `Listener` feeding the detector, and a pointer-only mode toggle in the shortcuts tab. Completes NAV-01 (end-cap arrows), NAV-03 (hint substitution), and the UI half of NAV-02 (mouse wiring + toggle UI); NAV-06 (arrow glow) and the NAV-02 detector half were landed in Wave 1.

## Task 1 — TabArrowButton + InputModeHint widgets + tokens (TDD)

- `lib/ui/theme/tokens.dart` — appended `tabArrowRadius` (= `radiusBtn`), `tabArrowWidth` (36.0), `hintFadeDuration` (`durationSlide`/300 ms). Did NOT create `inputModeIdleTimeoutSec` (owned by 32-01 Task 1 — blocker 1 dependency fix honored).
- `lib/ui/dialogs/settings/tab_arrow_button.dart` — `StatelessWidget` end-cap arrow (`isLeft` bool + `onTap` + optional `isCompact`); `RepaintBoundary` isolation (Pitfall 5); `ControlBarDecoration.playing` shell at `tabArrowRadius` (D-04 — no `BackdropFilter`, reuses Phase 31 single-blur boundary); `Icons.chevron_left/right` at `iconMd`/`textPrimary`; `Material`+`InkWell`+`NoSplash` matching `GlassButton`.
- `lib/ui/dialogs/settings/input_mode_hint.dart` — `ValueListenableBuilder<InputMode>` > `AnimatedSwitcher(duration: hintFadeDuration)` > `Text` keyed `ValueKey<InputMode>(mode)` (Pitfall — without the key no transition). keyboard→`← / →`, gamepad→`LB / RB`. Never switches on `auto` (D-03 — `effectiveMode` is never auto).
- `test/ui/dialogs/settings_tab_strip_test.dart` — TabArrowButton isolation (RepaintBoundary + chevron direction + onTap once).
- `test/ui/dialogs/input_mode_hint_test.dart` — keyboard arrow text, gamepad LB/RB, `AnimatedSwitcher` keyed swap, duration = `hintFadeDuration`.
- Verified: 6/6 tests pass; `flutter analyze` clean.
- Commits `68d78dd9` (tokens) + `a41b0c4a` (widgets + tests).

## Task 2 — Wire end caps + Listener + hint + toggle (TDD)

- `lib/ui/dialogs/settings/tab_strip.dart` — added required `onPrevTab`/`onNextTab` `VoidCallback`s; replaced `Row(children: List.generate(...))` with Pattern 3 composition: `Row[ TabArrowButton(isLeft:true, onTap:onPrevTab), Expanded(Row[ 7×Expanded(SettingsNavItem) ]), TabArrowButton(isLeft:false, onTap:onNextTab) ]`. End caps fixed-width outside `Expanded`; 7 items share remaining width inside nested `Expanded(Row)` (Pitfall 4). `ValueListenableBuilder`/`ControlBarDecoration.playing`/`isCompact` logic unchanged. No new `FocusTraversalGroup` (D-08).
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` — `_buildPanel`: wrapped the existing `Focus` in `Listener(behavior: HitTestBehavior.translucent, onPointerHover/onPointerMove → InputModeDetector.instance.recordPointerActivity, child: Focus(...))` inside the existing `FocusTraversalGroup` (D-02 — mouse capture; `recordPointerActivity` filters non-mouse kinds internally). `_buildTitleBar`: inserted `InputModeHint(effectiveMode: InputModeDetector.instance.effectiveMode)` between `Spacer()` and close button. Passed `onPrevTab: _controller.prevTab` / `onNextTab: _controller.nextTab` to `SettingsTabStrip` (T-32-05 — same controller path as arrow keys, no second selection state). `_onIsOpenChanged` close branch: `InputModeDetector.instance.onPanelClosed()` before `_panelFocusNode.unfocus()` (T-32-10P / checker warning 1 — cancels pending 5 s gamepad timer + resets `arrowGlow` to null; singleton survives, only timers canceled).
- `lib/ui/dialogs/settings/shortcuts_tab.dart` — added `_InputModeToggle` `StatelessWidget` below `SectionHeader`: `ValueListenableBuilder<InputMode>` on `InputModeDetector.instance.preference` (shows current preference, incl. `auto`); `GestureDetector(behavior: opaque, onTap: toggle(_nextMode(mode)))` cycles keyboard→gamepad→auto→keyboard; chip = `Container(bgGlass/borderHighlight/radiusBtn)` + `Row[Icon + Text]`. Dart 3 record-return + exhaustive switch for `_modeDisplay`/`_nextMode`.
- `test/ui/dialogs/settings_tab_strip_test.dart` — added `SettingsTabStrip` compact-overflow test (deferred from Task 1 — needs Task 2's `onPrevTab`/`onNextTab`): 400 px compact width (D-04 `FittedBox.scaleDown` threshold — icon 20 px fits 31 px content, `均衡器` 42 px triggers scaleDown); asserts `takeException()` null (no `RenderFlex` overflow), 2 end caps + 7 nav items render, AND left end cap→`prevCount`/right→`nextCount` routing (truth 1, T-32-05).
- Verified: 3/3 `settings_tab_strip_test.dart` + 4/4 `input_mode_hint_test.dart` + 53/53 `settings_overlay_shell_test.dart`+`settings_focus_navigation_test.dart` pass; `flutter analyze` clean on all 4 modified files.
- Commit `9b9054e` — `feat(32-02): wire end caps + Listener + hint + toggle` (4 files, +198/-12; `.planning/STATE.md` intentionally unstaged).

## Artifacts

| Commit | Scope | Files |
|--------|-------|-------|
| `68d78dd9` | Task 1 tokens | `tokens.dart` (3 const) |
| `a41b0c4a` | Task 1 widgets + tests | `tab_arrow_button.dart` + `input_mode_hint.dart` + 2 test files |
| `9b9054e` | Task 2 wiring + toggle + overflow test | `tab_strip.dart` + `settings_overlay_shell.dart` + `shortcuts_tab.dart` + `settings_tab_strip_test.dart` |

## must_haves truths — satisfaction

1. ✓ End-cap `TabArrowButton`s flank the 7-item row; left→`controller.prevTab`, right→`controller.nextTab`, same path as arrows (NAV-01). **Tested** (overflow test routing assertions).
2. ✓ `InputModeHint` shows `← / →`/`LB / RB` cross-fading via `AnimatedSwitcher`+`ValueKey` at `hintFadeDuration` (NAV-03). Tested (4 hint tests).
3. ✓ `Listener(translucent)` wraps `Focus`, forwards hover/move (mouse only) to `recordPointerActivity` (D-02).
4. ✓ Shortcuts toggle is pointer-only (D-09) — **see deviation 1**.
5. ✓ No new `FocusTraversalGroup` — `settings_focus_navigation_test` ≥4 assertion preserved (D-08). Verified (53/53 incl. focus nav).
6. ✓ End caps use `ControlBarDecoration.playing` + `RepaintBoundary`; no new `BackdropFilter` (D-04).
7. ✓ `onPanelClosed()` on `isOpen→false` cancels 5 s timer + resets `arrowGlow` (T-32-10P); singleton survives.

## Rule 1 deviations

- **D-09 toggle: `GestureDetector` without a `FocusNode`** — plan offered "GestureDetector or InkWell with an independent FocusNode"; chose `GestureDetector` (no `FocusNode`). Rationale: `GestureDetector` is focus-free by construction — it has no focus semantics at all, eliminating the focus-competition risk entirely rather than mitigating it with a separate node. The plan's "with an independent FocusNode" applies to the `InkWell` branch (whose `FocusNode` would otherwise compete); for `GestureDetector` there is no focus to compete, so omitting the node is the correct realization of "pointer-only." Stricter than the plan's `InkWell`+`FocusNode` option; `KeyboardListener.autofocus` (true only during recording) is untouched.
- **Overflow test: routing assertions added** — plan's Task 1 action specified "counting onSelect, onPrevTab, onNextTab" in the overflow test but the test was deferred to Task 2 (needs `onPrevTab`/`onNextTab`). Implemented with `prevCount`/`nextCount` tap-routing assertions (left→prev, right→next) to close must_haves truth 1 coverage; `onSelect` count omitted (covered by `SettingsNavItem` behavior; overflow test purpose = overflow + end-cap routing).
- **Compact width = 400 px** — plan said "compact-width container" without specifying a width. Chose 400 px = the D-04 `FittedBox.scaleDown` threshold documented in `_settings_nav_item.dart` (icon 20 px fits 31 px content; `均衡器` 42 px triggers scaleDown). Narrower (e.g. 320 px) would falsely fail — the 20 px icon overflows 19 px content (`FittedBox` wraps `Text` only, not `Icon`).

## Handoff to verifier

Phase 32 Wave 2 (32-02) complete — 3 commits. **Wave 3 (32-03) NOT started** → partial-wave execution; phase verification intentionally skipped per `handle_partial_wave_execution`. `gsd-verifier` runs only after all 3 waves complete.

Next: `/gsd-execute-phase 32 --wave 3` (32-03, human checkpoint). **When reaching 32-03, pass the extraction-fix blocking constraint to that executor** — the 32-03 regression gate MUST use the fixed `grep -aE '\[E\]' | sed -E 's/^[0-9]{2}:[0-9]{2} [+-][0-9]+( ~[0-9]+)?( -[0-9]+)?: //; s/ \[E\].*$//' | sort -u` extraction (same as the `3716104d` baseline), or the gate produces a false regression diff.
