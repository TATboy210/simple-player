---
phase: 32-navigation-interaction-polish
plan: 01
type: execute
wave: 1
status: complete
---

# 32-01 Summary — InputModeDetector + root arrow router + NAV-04/07 containment

Wave 1 establishes the sole new v4.5 infrastructure (`InputModeDetector` singleton) and the directional-arrow containment boundary that all subsequent Phase 32 plans build upon. NAV-04 (delete obsolete `gameButtonLeft1`/`gameButtonRight1` bindings) landed atomically with NAV-07 (root containment) in the same plan — deleting bindings without containment lets arrows escape to seek ±5s; containment without deletion leaves duplicate navigation routes (D-07).

## Task 0 — Pre-Phase-32 baseline failure snapshot (clean trust root)

- Ran full suite `D:/flutter/bin/flutter test` on the confirmed-clean Phase 31 tree (`input_mode_detector.dart` absent — clean-baseline precondition verified).
- Extracted 69 failing-test identities to `32-baseline-failures.txt` using the **fixed** extraction (`grep -aE '\[E\]' | sed -E 's/^[0-9]{2}:[0-9]{2} [+-][0-9]+( ~[0-9]+)?( -[0-9]+)?: //; s/ \[E\].*$//' | sort -u`). The plan's canonical extraction was broken for this project's test output (two bugs: `grep` binary-file detection on mdk.dll FFI NUL-byte output → false temp-name line; `sed` prefix regex missed the `~skipped` count → late failures kept un-stripped timestamps). Fixed symmetrically here and documented as a blocking constraint for the 32-03 gate.
- Pre-existing failures (out of scope): ~57 `fvp_engine_contract_test` (mdk.dll FFI headless, per memory `reference_mdk_dll_headless_test_failures`) + ~12 dialogs/widget headless + `settings_focus_navigation_test.dart` compile error (repaired by Task 2 → disappears after Task 2 = improvement, not regression).
- Commit `3716104d` — atomic, baseline file only.

## Task 1 — InputModeDetector + tokens + root arrow router (tracer TDD)

Created the `InputModeDetector` singleton (the sole new v4.5 infrastructure) and expanded the root key router so every directional arrow is handled at the panel root.

- `lib/kernel/services/input_mode_detector.dart` — `InputMode { keyboard, gamepad, auto }` + `ArrowDirection` enums; process-level singleton with injectable `idleTimeout` / `glowResetDuration` / `clock`; `recordPointerActivity` / `recordArrowKey` / `setArrowGlow` (sets glow + schedules cancellable null-reset) / `toggle` / `onPanelClosed` (cancels both timers + resets glow, singleton survives) / `dispose`; `@visibleForTesting forTest` / `resetInstance` seam. D-01 (manual toggle overrides heuristic), D-02 (5s idle + arrow → gamepad), D-03 (explicit keyboard/gamepad persist until user selects auto) all honored. Mouse-hover and idle-arrow timer mutate `effectiveMode` ONLY while preference is `auto`.
- `lib/ui/theme/tokens.dart` — added `static const int inputModeIdleTimeoutSec = 5;` (D-06) + `static const int arrowGlowDuration = 1200;` (NAV-06, ms; reuses `osdDefaultHoldMs` 1200 transient precedent).
- `lib/ui/dialogs/settings/panel_key_bindings.dart` — rewrote `handle()`: all four directional arrows (Left/Right/Up/Down) return `KeyEventResult.handled`; `recordArrowKey()` wired on all four; Up/Down call `setArrowGlow(ArrowDirection.up/.down)`; deleted `gameButtonLeft1`/`gameButtonRight1` from `_isLeftShoulder`/`_isRightShoulder` keeping only `gameButton13`/`gameButton12` (D-05 direct gamepad routing preserved).
- `test/kernel/services/input_mode_detector_test.dart` — 13 fakeAsync behaviors on isolated `forTest` instances with injected fakeAsync-backed clock (hover→keyboard; 5s idle+arrow→gamepad; toggle keyboard persists; toggle auto re-engages; dispose cancels gamepad timer; touch filter; D-03 gamepad persists across mouse; D-03 keyboard persists across timer; vertical-arrow refresh no stacking; glow successive-press replacement; glow auto-expiry to null; glow dispose cancels reset; `onPanelClosed` cancels both timers + resets glow).
- Verified: 13/13 tests pass; `flutter analyze` clean on the three production files.
- Commit `631f26c` — `feat(32-01): InputModeDetector + root arrow router`.

## Task 2 — NAV-04 grep gate + NAV-07 containment spy + stale Fake repair

Landed the NAV-04 source-grep gate and the NAV-07 containment spy, and — critically — discovered and fixed a **real production bug**: the settings panel root never reclaimed focus on open, so in production (where `SettingsOverlayShell` mounts inside `player_screen.dart`'s outer `KeyboardHandler(autofocus: true)` subtree) the directional arrows bubbled to `_handleKeyEvent` seek/volume callbacks instead of reaching `panel_key_bindings.handle`. NAV-01..06 were silently broken in production too, not just untested.

- `test/ui/dialogs/settings_focus_navigation_test.dart` — repaired stale fake: `FakePlaybackController(initiallyPlaying: true)` → `FakePlaybackController(initialState: MediaState.playing)` + added `media_state.dart` import; `FocusTraversalGroup >= 4` assertion intact.
- `test/ui/dialogs/settings_overlay_shell_test.dart` — deleted two obsolete `gameButtonRight1`/`Left1` `testWidgets` (kept `gameButton12`/`13`); added **NAV-04 grep gate** (`test`, not `testWidgets`): `git grep -hE gameButtonLeft1|Right1 -- lib/` + Dart comment filter (`where` non-empty + not `//`-prefixed) → `isEmpty` assertion; added **NAV-07 containment spy** (`testWidgets`): real `KeyboardHandler(onSeekBackward/Forward/onVolumeUp/Down: ()=>count++)` wrapping the shell, `controller.open()` + `pump×2` (let post-frame `requestFocus` execute + stabilize) + send 4 directional arrows → expect all 4 counters `0`; fixed 6 FakeTimer-leak sites (added `await tester.pump(250ms); InputModeDetector.instance.onPanelClosed();` at body end) — root cause: `flutter_test` `_verifyInvariants` checks `!timersPending` BEFORE `addTearDown`, so `addTearDown`'s `onPanelClosed` was too late.
- **Method A production fix** (`lib/ui/dialogs/settings/settings_overlay_shell.dart`): added `_panelFocusNode` field + `initState`/`_onIsOpenChanged` schedule post-frame `requestFocus` on open + `unfocus` on close + changed `_buildPanel` root `Focus` to `focusNode: _panelFocusNode, autofocus: false`. This mirrors the `PlaylistPanel` pattern. **The key correctness gap**: the `_panelFocusNode` field had to be wired into the `Focus` widget (not left as an orphan node) — otherwise `requestFocus()` hit an unmounted node and focus stayed on the outer `KeyboardHandler`. Once wired, focus moves to the panel root on open, arrows reach `panel_key_bindings.handle` (returns `handled` → contained), and NAV-01..07 all take effect on the production path.
- Verified: **53/53 tests pass** (both files, including NAV-07 containment spy); `flutter analyze` clean on `settings_overlay_shell.dart`.
- Commit `e38175f` — `fix(32-01): focus panel root on open (NAV-07)` (lib/ only, +39/-5).
- Commit `0d692ab` — `test(32-01): NAV-04 grep gate + NAV-07 containment spy` (2 test files, +150/-44).

## Artifacts

| Commit | Scope | Files |
|--------|-------|-------|
| `3716104d` | Task 0 baseline | `32-baseline-failures.txt` (69 entries) |
| `631f26c` | Task 1 feat | `input_mode_detector.dart` (new) + `tokens.dart` + `panel_key_bindings.dart` + `input_mode_detector_test.dart` (new) |
| `e38175f` | Task 2 fix (NAV-07 production bug) | `settings_overlay_shell.dart` (+39/-5) |
| `0d692ab` | Task 2 test (NAV-04 gate + NAV-07 spy + stale Fake) | `settings_overlay_shell_test.dart` + `settings_focus_navigation_test.dart` (+150/-44) |

## Rule 1 deviations

- **NAV-04 grep gate** — plan specified `exitCode == 1` assertion; implemented as source-grep + Dart comment filter instead, because comment text in `lib/` contains literal `gameButtonLeft1`/`gameButtonRight1` references (documentation), which a bare exit-code grep would false-positive. The filter (`where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))`) asserts zero non-comment references. Plan checker iter 8 already scoped criterion 213 to allow this source-grep form (`7e041211`).
- **Extraction fix (blocking constraint)** — both the Task 0 baseline AND the 32-03 gate deviate from the plan's canonical extraction to use `grep -aE` + the `~skipped`-aware `sed`. Justified by this project's test-output format (mdk.dll NUL bytes + `~skipped` prefix). Documented as a blocking constraint in `.continue-here.md`; the 32-03 executor (Wave 3) MUST apply the same extraction or it produces a false regression diff.
- **NAV-07 Method A** — not a deviation from plan intent (NAV-07 must_haves require "outer KeyboardHandler seek/volume callbacks NOT invoked when panel open"); Method A (production-expose `_panelFocusNode` + explicit `requestFocus`/`unfocus`) is the chosen implementation, mirroring `PlaylistPanel`. Recorded because the plan's `key_links` assumed the root `Focus` mount was unchanged (D-08); the `focusNode`/`autofocus:false` change is a behavior-preserving mount refinement that makes the existing `onKeyEvent: keyBindings.handle` actually receive focus on open.
- **Test-side `tester.focus` unavailable** — `WidgetTester` has no `focus()` method and `SettingsNavItem` (MouseRegion + GestureDetector) has no `Focus` child; resolved by Method A exposing `_panelFocusNode` through production rather than adding a test-only focus seam.

## Handoff to verifier

Phase 32 Wave 1 (32-01) complete — 4 commits. **Wave 2 (32-02) and Wave 3 (32-03) NOT started** → this is a partial-wave execution; phase verification is intentionally skipped per `handle_partial_wave_execution`.

Next steps (recommend):
- `/gsd-execute-phase 32 --wave 2 --interactive` (32-02).
- Then `/gsd-execute-phase 32 --wave 3` (32-03, human checkpoint). **When reaching 32-03, pass the extraction-fix blocking constraint to that executor** — the 32-03 regression gate MUST use the fixed `grep -aE '\[E\]' | sed -E 's/^[0-9]{2}:[0-9]{2} [+-][0-9]+( ~[0-9]+)?( -[0-9]+)?: //; s/ \[E\].*$//' | sort -u` extraction (same as the `3716104d` baseline), or the gate produces a false regression diff.

`gsd-verifier` runs only after all 3 waves complete.
