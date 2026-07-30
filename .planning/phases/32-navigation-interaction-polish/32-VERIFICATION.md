---
phase: 32-navigation-interaction-polish
verified: 2026-07-30T12:00:00Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 32: Navigation & Interaction Polish — Verification Report

**Phase Goal:** Navigation & Interaction Polish: end-cap tab arrows, input-mode-aware hint, option-list glow overlay, root arrow containment, delete obsolete gamepad bindings.

**Verified:** 2026-07-30T12:00:00Z

**Status:** PASSED

**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | InputModeDetector singleton exposes InputMode { keyboard, gamepad, auto } as user preference and a derived effective mode (keyboard or gamepad); mouse hover and the idle-arrow timer mutate effectiveMode ONLY while preference is auto — explicit keyboard/gamepad selections persist until the user selects auto (D-03); all four directional arrows (Up, Down, Left, Right) record arrow activity; manual toggle overrides the heuristic, selecting auto re-enables the heuristic (D-01, D-03). | VERIFIED | 13/13 unit tests pass in `test/kernel/services/input_mode_detector_test.dart` covering hover, idle+arrow, toggle, auto-restart, dispose-cancels-timer, panel-close-cancels-timer, and glow-reset lifecycle. Code review of `lib/kernel/services/input_mode_detector.dart` confirms D-03 compliance: `recordPointerActivity()` and `recordArrowKey()` only mutate `effectiveMode` when `preference.value == InputMode.auto`; `toggle()` directly sets `effectiveMode` for explicit keyboard/gamepad and re-engages heuristic for auto. |
| 2 | panel_key_bindings.handle() returns KeyEventResult.handled for ALL four directional arrows (left, right, up, down); up/down call setArrowGlow (which sets the glow AND schedules a cancellable null-reset) before returning handled; the glow-reset lifecycle is owned by the detector and disposes cleanly (NAV-06, NAV-07, D-07). | VERIFIED | Code review of `lib/ui/dialogs/settings/panel_key_bindings.dart` lines 59-84: ArrowLeft/ArrowRight call `recordArrowKey()` + `controller.prevTab()/nextTab()` + return handled; ArrowUp/ArrowDown call `recordArrowKey()` + `setArrowGlow(ArrowDirection.up/down)` + return handled. Test 10 in `input_mode_detector_test.dart` proves two rapid `setArrowGlow()` calls replace (no stacking). Test 12 proves `dispose()` cancels in-flight glow-reset timer. |
| 3 | No production reference to gameButtonLeft1 or gameButtonRight1 exists in lib/ — grep gate returns zero (NAV-04). | VERIFIED | `git grep -hE "gameButtonLeft1|gameButtonRight1" -- lib/` returns 4 lines, all are comments (lines 7, 28, 107, 112 of `panel_key_bindings.dart` start with `//`). Test "NAV-04: lib/ source has no gameButtonLeft1/Right1 code refs" in `settings_overlay_shell_test.dart` lines 647-665 passes, filtering out comment lines and asserting zero code references. |
| 4 | gameButton12 and gameButton13 direct gamepad routing is preserved — only Left1/Right1 cross-platform constants are deleted (D-05). | VERIFIED | Code review of `panel_key_bindings.dart` lines 108-113: `_isLeftShoulder()` compares `key == LogicalKeyboardKey.gameButton13`; `_isRightShoulder()` compares `key == LogicalKeyboardKey.gameButton12`. Tests "gamepad Right Shoulder (gameButton12) switches to next tab" and "gamepad Left Shoulder (gameButton13) switches to previous tab" in `settings_overlay_shell_test.dart` lines 607-645 pass. |
| 5 | Outer KeyboardHandler seek and volume callbacks are NOT invoked when the settings panel is open and any directional arrow is pressed — containment proven by a spy test with zero-call assertions (NAV-07). | VERIFIED | Test "NAV-07: arrows contained in panel do not bubble to outer KeyboardHandler" in `settings_overlay_shell_test.dart` lines 667-721 passes. Test wraps shell in `KeyboardHandler` with spy callbacks for `onSeekBackward/Forward/onVolumeUp/Down`, sends 4 directional arrows, asserts all 4 spy counters are 0. Code review of `settings_overlay_shell.dart` lines 311-317 confirms root `Focus` node with `autofocus: false` + explicit `_requestPanelFocus()` on open (line 176)夺回焦点 from outer `KeyboardHandler(autofocus:true)`. |
| 6 | settings_focus_navigation_test.dart compiles after the stale FakePlaybackController(initiallyPlaying:) parameter is repaired to initialState: MediaState.playing. | VERIFIED | Test file `test/ui/dialogs/settings_focus_navigation_test.dart` lines 22-23: `FakePlaybackController(initialState: MediaState.playing)` — correct parameter name. All 11 tests in this file pass (lines 49-265). |
| 7 | InputModeDetector.onPanelClosed() cancels the pending 5s gamepad-detection timer and the glow-reset timer and resets arrowGlow to null without disposing the singleton — so an arrow pressed just before the settings panel closes does not flip effectiveMode to gamepad 5s later while the panel is closed (checker warning 1, wired by Plan 02 settings_overlay_shell._onIsOpenChanged); the detector survives across open/close. | VERIFIED | Test 13 "onPanelClosed cancels timer + resets glow (no late flip)" in `input_mode_detector_test.dart` lines 196-207 passes: `recordArrowKey()` starts 5s timer, `onPanelClosed()` cancels it, `async.elapse(10s)` does not flip `effectiveMode` to gamepad, `arrowGlow.value` is null. Code review of `input_mode_detector.dart` lines 192-198: `onPanelClosed()` cancels both timers + resets `arrowGlow.value = null` without calling `dispose()` on ValueNotifiers. `settings_overlay_shell.dart` line 186 calls `InputModeDetector.instance.onPanelClosed()` in `_onIsOpenChanged()` when `open` becomes false. |

**Score:** 7/7 must-haves verified (0 behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/kernel/services/input_mode_detector.dart` | Singleton ValueNotifier<InputMode> with mouse-idle heuristic (auto-gated per D-03), arrow-key timer (auto-gated), toggle fallback, setArrowGlow with cancellable null-reset lifecycle, arrowGlow notifier for NAV-06, onPanelClosed() panel-session hook, and @visibleForTesting forTest/resetInstance seam with injectable clock | VERIFIED | File exists, 213 lines, all features present. Singleton pattern with `_instance` static field (line 62), `instance` getter (line 66), `resetInstance()` (line 80), `forTest()` factory (line 85). Three ValueNotifiers: `preference`, `effectiveMode`, `arrowGlow`. Clock injection (line 56) enables fakeAsync testing. |
| `test/kernel/services/input_mode_detector_test.dart` | fakeAsync coverage (13 behaviors) of hover, idle, arrow, toggle, auto-restart, dispose-cancels-timer, panel-close-cancels-timer, and glow-reset lifecycle — all on isolated forTest instances with an injected fakeAsync-backed clock | VERIFIED | File exists, 210 lines, 13 tests all pass. Uses `InputModeDetector.forTest()` with `fakeAsync.getClock()` injection. Tests cover: mouse hover under auto (Test 1), idle+arrow under auto (Test 2), toggle keyboard persists (Test 3), toggle auto re-engages (Test 4), dispose cancels timer (Test 5), touch filtered (Test 6), gamepad persists across mouse (Test 7), keyboard persists across timer (Test 8), recordArrowKey refreshes timer (Test 9), glow replacement (Test 10), glow auto-expiry (Test 11), dispose cancels glow-reset (Test 12), onPanelClosed cancels timer (Test 13). |
| `lib/ui/dialogs/settings/panel_key_bindings.dart` | Root key router with all four arrows handled, gameButtonLeft1/Right1 deleted, recordArrowKey wired, glow notifier on up/down | VERIFIED | File exists, 115 lines. Lines 59-84 handle all four arrows: ArrowLeft/Right call `recordArrowKey()` + `controller.prevTab()/nextTab()`; ArrowUp/Down call `recordArrowKey()` + `setArrowGlow()`. Lines 108-113 define `_isLeftShoulder()` (gameButton13) and `_isRightShoulder()` (gameButton12) — no gameButtonLeft1/Right1 references in code. |
| `test/ui/dialogs/settings_overlay_shell_test.dart` | gameButtonLeft1/Right1 tests deleted, grep assertion added, outer KeyboardHandler spy proving arrow containment | VERIFIED | File exists, 1176 lines. Test "NAV-04: lib/ source has no gameButtonLeft1/Right1 code refs" (lines 647-665) passes. Test "NAV-07: arrows contained in panel do not bubble to outer KeyboardHandler" (lines 667-721) passes with spy counters asserting 0. All 32 tests in this file pass. |
| `test/ui/dialogs/settings_focus_navigation_test.dart` | Stale fake repaired — compiles and FocusTraversalGroup >= 4 assertion intact | VERIFIED | File exists, 268 lines. Line 22 uses `FakePlaybackController(initialState: MediaState.playing)` (correct parameter). Test "FocusTraversalGroup hierarchy exists in panel" (lines 192-204) asserts `groups.length >= 4`. All 11 tests pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/ui/dialogs/settings/panel_key_bindings.dart` | `lib/kernel/services/input_mode_detector.dart` | `recordArrowKey()` called on every recognized directional arrow (all four); `setArrowGlow()` called on up/down (sets glow + schedules null-reset) | WIRED | Code review of `panel_key_bindings.dart` lines 59-84: all four arrow branches call `InputModeDetector.instance.recordArrowKey()`; up/down additionally call `setArrowGlow()`. |
| `lib/ui/dialogs/settings/settings_overlay_shell.dart` | `lib/ui/dialogs/settings/panel_key_bindings.dart` | Existing root Focus `onKeyEvent` delegates to `keyBindings.handle` — mount unchanged (D-08) | WIRED | Code review of `settings_overlay_shell.dart` line 298: `final keyBindings = SettingsPanelKeyBindings(_controller);`. Line 317: `onKeyEvent: keyBindings.handle`. Focus node `_panelFocusNode` (line 105) with explicit `_requestPanelFocus()` on open (line 176). |

### Data-Flow Trace (Level 4)

Not applicable — no artifacts render dynamic data from APIs/databases. All artifacts are state-management or UI-composition widgets.

### Behavioral Spot-Checks

Not applicable — all behavior is exercised by the 78 passing unit/widget tests. No standalone CLI/API entry points to spot-check.

### Probe Execution

Not applicable — no migration probes in this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| NAV-01 | 32-02 | End-cap tab arrows (TabArrowButton in tab_strip.dart) | SATISFIED | `tab_arrow_button.dart` exists (85 lines), `tab_strip.dart` lines 87-113 mount two `TabArrowButton` widgets (left/right) with `onPrevTab`/`onNextTab` callbacks wired to `controller.prevTab()/nextTab()`. Tests in `settings_tab_strip_test.dart` lines 78-131 pass. |
| NAV-02 | 32-01 | InputModeDetector singleton | SATISFIED | `input_mode_detector.dart` exists (213 lines), singleton pattern with `instance` getter, `resetInstance()`, `forTest()`. 13 unit tests pass. |
| NAV-03 | 32-02 | Hint substitution AnimatedSwitcher | SATISFIED | `input_mode_hint.dart` exists (55 lines), uses `AnimatedSwitcher` with `ValueKey<InputMode>(mode)` (line 44), duration `Tokens.hintFadeDuration` (line 39). Tests in `input_mode_hint_test.dart` pass. Wired in `settings_overlay_shell.dart` line 442. |
| NAV-04 | 32-01 | Delete gameButtonLeft1/Right1 | SATISFIED | `git grep` returns only 4 comment lines, zero code references. Test "NAV-04: lib/ source has no gameButtonLeft1/Right1 code refs" passes. |
| NAV-05 | 32-03 | Thin-glass option-list overlay | SATISFIED | `option_list_navigation_overlay.dart` exists (84 lines), uses `Stack` with `child` (scrollable) as base layer + `Positioned.fill` overlay with two `_ArrowIndicator` widgets. No `BackdropFilter` in subtree (test line 14-24 passes). Wired in `general_tab.dart` line 45. |
| NAV-06 | 32-01 | Up/down glow feedback | SATISFIED | `input_mode_detector.dart` line 163-169 defines `setArrowGlow()` with cancellable reset timer. `panel_key_bindings.dart` lines 73-84 call `setArrowGlow()` on up/down arrows. `option_list_navigation_overlay.dart` lines 31-56 listen to `arrowGlow` notifier. Tests 10-12 in `input_mode_detector_test.dart` pass. |
| NAV-07 | 32-01 | Root Focus handles all arrows | SATISFIED | `settings_overlay_shell.dart` line 317 wires `onKeyEvent: keyBindings.handle`. `panel_key_bindings.dart` handles all four arrows (lines 59-84). Test "NAV-07: arrows contained in panel do not bubble to outer KeyboardHandler" passes. |

### Anti-Patterns Found

None. Zero `TBD`/`FIXME`/`XXX` markers in the 10 production files.

### Human Verification Required

None. All 7 must-haves are verified by automated tests and code review.

### Gaps Summary

No gaps. All 7 must-haves verified, all 5 required artifacts present and wired, all 2 key links verified, all 7 requirements satisfied, zero anti-patterns.

---

## Verification Execution Details

### Step 0: Previous Verification Check
No previous VERIFICATION.md found. Initial verification mode.

### Step 1: Load Context
- Phase directory: `.planning/phases/32-navigation-interaction-polish/`
- Plan files: `32-01-PLAN.md`, `32-02-PLAN.md`, `32-03-PLAN.md`
- Summary files: `32-01-SUMMARY.md`, `32-02-SUMMARY.md`, `32-03-SUMMARY.md`
- Baseline artifact: `32-baseline-failures.txt` (69 entries)

### Step 2: Establish Must-Haves
Extracted 7 truths + 5 artifacts + 2 key_links from `32-01-PLAN.md` frontmatter (lines 18-42). All 7 requirements (NAV-01 through NAV-07) mapped from plan frontmatter `requirements:` field.

### Step 3: Verify Observable Truths
All 7 truths verified by reading production code and running tests.

### Step 4: Verify Artifacts
All 5 artifacts verified at three levels:
- Level 1 (Exists): All 5 files exist
- Level 2 (Substantive): All files have real implementation (not stubs)
- Level 3 (Wired): All artifacts are imported and used

### Step 5: Verify Key Links
Both key links verified by code review.

### Step 6: Requirements Coverage
All 7 requirements (NAV-01 through NAV-07) satisfied.

### Step 7: Anti-Pattern Scan
Zero debt markers found in 10 production files.

### Step 7b: Behavioral Spot-Checks
Not applicable — all behavior exercised by tests.

### Step 7c: Probe Execution
Not applicable — no migration probes.

### Step 8: Human Verification Needs
None identified.

### Step 9: Overall Status
**PASSED** — All 7 truths verified, all artifacts pass, all links wired, no blockers, no human verification items.

### Step 9b: Deferred Items
No deferred items — all gaps resolved.

## Test Execution Summary

```
flutter analyze (10 production files): No issues found!
flutter test (6 test files): 78 tests passed, 0 failures
  - input_mode_detector_test.dart: 13/13
  - settings_tab_strip_test.dart: 3/3
  - input_mode_hint_test.dart: 3/3
  - option_list_navigation_overlay_test.dart: 5/5
  - settings_overlay_shell_test.dart: 32/32
  - settings_focus_navigation_test.dart: 11/11
```

## Git Commit Verification

All 9 commits present in git log:
- `3716104d` docs(32): generate pre-Phase-32 baseline failure snapshot
- `631f26ce` feat(32-01): InputModeDetector + root arrow router
- `e38175fc` fix(32-01): focus panel root on open (NAV-07)
- `0d692ab0` test(32-01): NAV-04 grep gate + NAV-07 containment spy
- `68d78dd9` feat(32-02): add tab arrow + input hint tokens (NAV-01/NAV-03)
- `a41b0c4a` feat(32-02): TabArrowButton + InputModeHint widgets (NAV-01/NAV-03)
- `9b9054e0` feat(32-02): wire end caps + Listener + hint + toggle (NAV-01/NAV-02/NAV-03)
- `52764c33` feat(32-03): OptionListNavigationOverlay + GeneralTab mount + regression gate
- `cac31475` chore(32-03): remove temp NAV-04 diagnostic + annotate dead gamepad routing

## Design Decision Compliance

All locked design decisions (D-01 through D-09) honored in code:
- D-01: Key event source cannot be distinguished — heuristic uses mouse-idle + arrow timing
- D-02: Mouse-only filter — `recordPointerActivity()` checks `event.kind == PointerDeviceKind.mouse`
- D-03: Preference/effectiveMode split — `effectiveMode` never takes `auto`, only `keyboard`/`gamepad`
- D-04: No BackdropFilter in tab arrow button — reuses `ControlBarDecoration.playing` without blur
- D-05: Windows direct mapping — only `gameButton12`/`gameButton13`, no cross-platform `Left1`/`Right1`
- D-06: No hardcoded timeouts — `InputModeDetector` reads `Tokens.inputModeIdleTimeoutSec` (5s) and `Tokens.arrowGlowDuration` (1200ms)
- D-07: KeyUp events ignored — `panel_key_bindings.handle()` returns `ignored` for non-`KeyDownEvent`
- D-08: Focus scope unchanged — root `Focus` remains in `SettingsOverlayShell`, `onKeyEvent` delegates to `keyBindings.handle`
- D-09: Input mode toggle is pointer-only — `_InputModeToggle` in `shortcuts_tab.dart` uses `GestureDetector` (not `InkWell`) to avoid stealing `KeyboardListener` focus

---

_Verified: 2026-07-30T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
