---
phase: 31
fixed_at: 2026-07-28T10:23:58Z
review_path: D:/simple_player_flutter/.planning/phases/31-visual-design-alignment/31-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 5
skipped: 1
status: partial
---

# Phase 31: Code Review Fix Report

**Fixed at:** 2026-07-28T10:23:58Z  
**Source review:** `D:/simple_player_flutter/.planning/phases/31-visual-design-alignment/31-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 5
- Skipped: 1

| Finding | Status | Commit | Notes |
|---|---|---|---|
| CR-01 | fixed: requires human verification | `f7a71e75` | Decoupled row-level tap handling from embedded-control interaction; added switch and spin pointer regression tests. |
| WR-01 | fixed | `5aa1f0f3` | Focus tests now supply a focus node and assert both callback transition and focus-border color. |
| WR-02 | fixed | `67ae43d9` | Tab test now taps non-default Video index 2 and verifies the state transition. |
| WR-03 | fixed | `2e62edb6` | Added semantic chrome tokens and replaced reviewed literals. |
| WR-04 | fixed | `d6723e55` | Recovery paths now handle only `Exception`; programming errors propagate. |
| WR-05 | skipped | — | A safe extraction would touch overlay lifecycle, drag, geometry, and widget composition in a 548-line integration-tested shell. Deferred to avoid destabilizing the focused functional fixes in this pass. |

## Fixed Issues

### CR-01: Embedded setting controls are disabled whenever the row itself has no `onTap`

**Files modified:** `lib/ui/shared/settings_card.dart`, `test/ui/shared/settings_card_test.dart`  
**Commit:** f7a71e75  
**Applied fix:** Added an explicit `focusable` interaction property independent of `onTap`, preserving embedded `Switch` and `SpinControl` pointer handling. Added assertions for notifier and callback changes.

### WR-01: Two `FocusableSettingRow` tests are no-op assertions and never focus the row under test

**Files modified:** `test/ui/shared/focusable_setting_row_test.dart`  
**Commit:** 5aa1f0f3  
**Applied fix:** Connected test focus nodes to the widget, requested focus, and asserted the focus callback and tokenized border state.

### WR-02: The tab-selection regression test taps the already-selected default tab and asserts the unchanged value

**Files modified:** `test/ui/dialogs/settings_overlay_shell_test.dart`  
**Commit:** 67ae43d9  
**Applied fix:** Updated the test to select Video at index 2 from the default General index 3 and assert the new value.

### WR-03: The settings chrome introduces hardcoded visual values instead of design tokens

**Files modified:** `lib/ui/theme/tokens.dart`, `lib/ui/dialogs/settings/settings_overlay_shell.dart`, `lib/ui/dialogs/settings/tab_strip.dart`, `lib/ui/player/control_bar.dart`  
**Commit:** 2e62edb6  
**Applied fix:** Introduced named mask, title/tab dimension, and control-bar spacing tokens, then routed the reviewed values through them.

### WR-04: The display enumerator recovery path catches all thrown objects, including programming errors

**Files modified:** `lib/ui/dialogs/settings/settings_overlay_shell.dart`, `test/ui/dialogs/settings_overlay_shell_test.dart`  
**Commit:** d6723e55  
**Applied fix:** Restricted synchronous and asynchronous platform recovery to `on Exception catch`, retaining logging and fallback behavior.

## Skipped Issues

### WR-05: `settings_overlay_shell.dart` exceeds the project's 500-line source-file limit

**File:** `lib/ui/dialogs/settings/settings_overlay_shell.dart:1-548`  
**Reason:** A multi-component extraction is outside the safe scope of this targeted review-fix pass and could destabilize the drag/geometry lifecycle.  
**Original issue:** The shell combines overlay lifecycle, animation, composition, title chrome, drag session management, geometry calculation, display recovery, and clamping in a file above the project limit.

---

_Fixed: 2026-07-28T10:23:58Z_  
_Fixer: Claude (gsd-code-fixer)_  
_Iteration: 1_
