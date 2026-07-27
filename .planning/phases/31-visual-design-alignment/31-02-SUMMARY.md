---
phase: 31-visual-design-alignment
plan: 02
subsystem: ui/settings-row-interaction
tags: [flutter, settings, inkwell, focus, widget-tests]
requires:
  - phase: 31-01
    provides: ControlBarDecoration chrome route and visual token baseline
provides:
  - Compact 40px SettingRow default/hover/focused/pressed behavior
  - Single-owner row focus with focusedBuilder state delivery
  - General and Equalizer settings consumer coverage
  - InkWell pointer feedback without custom scale animation
affects:
  - Phase 31 Plan 03 profile and visual validation
  - Phase 32 focus traversal and navigation polish
tech-stack:
  added: []
  patterns:
    - FocusableSettingRow owns keyboard focus while embedded InkWell is pointer-only
    - FocusedBuilder delivers local focus state without polling Focus.of
    - Permanent transparent one-pixel border slot prevents focus geometry changes
key-files:
  created:
    - test/ui/shared/settings_card_test.dart
  modified:
    - lib/ui/shared/settings_card.dart
    - lib/ui/shared/focusable_setting_row.dart
    - test/widget/settings/general_equalizer_tab_test.dart
    - test/ui/shared/focusable_setting_row_test.dart
key-decisions:
  - "Keep FocusableSettingRow as the only row focus owner; InkWell sets canRequestFocus and autofocus false."
  - "Use Tokens.accentLight splash and Tokens.bgHover highlight on transparent Material for visible glass feedback."
  - "Preserve a transparent one-pixel border for disabled rows so every SettingRow retains the 40px outer geometry."
patterns-established:
  - "Settings rows use focusedBuilder for focus-driven active-value styling."
  - "Pointer ink feedback is separate from keyboard focus traversal."
requirements-completed: [VISUAL-02, VISUAL-03]
coverage:
  - id: D1
    description: SettingRow renders transparent default, bgHover pointer state, focused controlBarBorderWhite border, accent active text, InkWell feedback, and locked density.
    requirement: VISUAL-02
    verification:
      - kind: automated_ui
        ref: D:/flutter/bin/flutter test test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: General and Equalizer settings consumers retain compact row geometry and the one-owner row focus contract.
    requirement: VISUAL-03
    verification:
      - kind: automated_ui
        ref: D:/flutter/bin/flutter test test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart test/widget/settings/general_equalizer_tab_test.dart
        status: pass
    human_judgment: false
  - id: D3
    description: Glass ripple visibility, focused accent contrast, and compact-density readability on Windows remain subject to profile and visual review.
    verification: []
    human_judgment: true
    rationale: Visual perception and profile-mode interaction performance require the Plan 03 Windows A/B check.
metrics:
  duration: 34 min
  completed: 2026-07-27
  tasks: 2/2
  files: 4
status: complete
---

# Phase 31 Plan 02: SettingRow Three-State TDD Summary

Compact settings rows now use a transparent Material-hosted InkWell for visible glass ripple feedback, one FocusableSettingRow focus route, a one-pixel control-bar focus border, and an accent active text route at the locked 40px density.

## Performance

- **Duration:** 34 min
- **Started:** 2026-07-27T17:04:14Z
- **Completed:** 2026-07-27T17:38:00Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Replaced SettingRow's MouseRegion/GestureDetector/AnimatedContainer/Transform-scale path with transparent Material plus non-focusable InkWell, `Tokens.bgHover`, `Tokens.accentLight`, and token-only geometry.
- Extended FocusableSettingRow with backward-compatible optional `focusedBuilder` and optional focus node, keeping it as the sole keyboard focus owner and delivering focus state to active values.
- Added widget coverage for default, hover, focus, pressed, no-layout-shift, active-value accent, 40px height, and `Tokens.spXs` horizontal padding.
- Exercised GeneralTab and EqualizerTab consumers, retaining their current glass/header regression coverage while proving compact settings-row geometry.

## Task Commits

Each TDD stage was committed atomically:

1. **Task 1 RED: add failing SettingRow state contract tests** — `8d4a1a08` (`test`)
2. **Task 1 GREEN: implement three-state SettingRow interaction** — `cd6848af` (`feat`)
3. **Task 2: cover settings-tab row focus contract** — `d2496aaf` (`test`)
4. **Task 2 deviation follow-up: retain tab rendering regression coverage** — `2737d537` (`test`)

## Files Created/Modified

- `lib/ui/shared/settings_card.dart` — Material/InkWell settings-row interaction, compact geometry, focused text-control accent route.
- `lib/ui/shared/focusable_setting_row.dart` — one-pixel control-bar border, optional focusedBuilder/focusNode, and stable disabled-row border geometry.
- `test/ui/shared/settings_card_test.dart` — dedicated three-state and geometry contract tests.
- `test/widget/settings/general_equalizer_tab_test.dart` — current General/Equalizer consumer, focus, density, glass, and header regression coverage.

## Decisions Made

- `FocusableSettingRow` retains exclusive focus ownership; setting-row InkWells cannot request focus, preventing an extra focus stop.
- `focusedBuilder` carries focus state to active controls rather than polling `Focus.of(context)`, so focus changes rebuild the affected value reliably.
- The 1px transparent border is painted even for disabled display rows, preserving the plan's 40px outer-height contract for all row consumers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved disabled-row outer geometry after adding the permanent focus-border slot**
- **Found during:** Task 2 consumer verification
- **Issue:** The original disabled path returned `ExcludeFocus > IgnorePointer > child` without the new one-pixel border wrapper. Consumer tests found disabled EqualizerTab SettingRow measured 38px instead of the locked 40px outer height.
- **Fix:** Routed disabled rows through the same transparent one-pixel decoration helper while retaining `ExcludeFocus` and `IgnorePointer` behavior.
- **Files modified:** `lib/ui/shared/focusable_setting_row.dart`
- **Verification:** Focused three-file suite exits 0; target-file Flutter analysis has no issues.
- **Committed in:** `d2496aaf`

**2. [Rule 1 - Bug] Rebased stale General/Equalizer regression tests to current tab APIs instead of dropping their coverage**
- **Found during:** Task 2 RED setup
- **Issue:** `general_equalizer_tab_test.dart` still targeted pre-Phase-28 constructors and imports. Replacing it solely with focus assertions would have removed existing glass and header coverage.
- **Fix:** Updated the test harness to current `tabs/` APIs and `PendingSettingsState`, then retained equivalent glass-section/header checks alongside the new row focus and geometry coverage.
- **Files modified:** `test/widget/settings/general_equalizer_tab_test.dart`
- **Verification:** Final focused suite exits 0 with all tests passing.
- **Committed in:** `2737d537`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs).
**Impact on plan:** Both changes preserve required visual and regression contracts without expanding production scope.

## Test Evidence

- **Task 1 mandated suite (exit 0):** `D:/flutter/bin/flutter test test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart` — **14 tests passed**.
- **Task 2 and final acceptance suite (exit 0):** `D:/flutter/bin/flutter test test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart test/widget/settings/general_equalizer_tab_test.dart` — **19 tests passed**.
- **Target-file analysis (exit 0):** `D:/flutter/bin/flutter analyze lib/ui/shared/settings_card.dart lib/ui/shared/focusable_setting_row.dart test/ui/shared/settings_card_test.dart test/ui/shared/focusable_setting_row_test.dart test/widget/settings/general_equalizer_tab_test.dart` — **No issues found**.
- **Full `flutter analyze` (exit 1):** **114 pre-existing issues** outside this plan's module boundary, including missing fullscreen bridge files in `lib/kernel/bridge/platform/windows_fullscreen_driver.dart`, the known `FakePlaybackController(initiallyPlaying:)` error in `test/ui/dialogs/settings_focus_navigation_test.dart`, and unrelated kernel/stash diagnostics. No errors or warnings appear in this plan's changed files.

## Known Stubs

None.

## Threat Flags

None — this plan adds no network endpoint, authentication path, file access, persistence, schema, or package dependency. T-31-04 is mitigated by making InkWell non-focusable and preserving FocusableSettingRow as the only focus owner.

## Issues Encountered

- Full-project static analysis is not clean because of documented, pre-existing kernel bridge and stash-related failures outside the Phase 31-02 paths. Targeted analysis for every changed source and test file is clean.

## Next Phase Readiness

- Ready for **31-03** Windows visual/profile validation.
- Wave 3 should inspect hover, focused-border, accent active-value readability, and pressed ripple behavior on actual glass; confirm the pre/post raster average remains within the recorded baseline +1ms threshold (≤2.85ms).
- The contrast backstop remains: `Tokens.accent` is locked by D-07 and automated tests verify its route, but on-device readability should be assessed before considering any brighter-token change.

## Self-Check: PASSED

- FOUND: `lib/ui/shared/settings_card.dart`
- FOUND: `lib/ui/shared/focusable_setting_row.dart`
- FOUND: `test/ui/shared/settings_card_test.dart`
- FOUND: `test/widget/settings/general_equalizer_tab_test.dart`
- FOUND: commits `8d4a1a08`, `cd6848af`, `d2496aaf`, and `2737d537` in git log.
- Final focused acceptance suite exits 0.

---
*Phase: 31-visual-design-alignment*
*Completed: 2026-07-27*
