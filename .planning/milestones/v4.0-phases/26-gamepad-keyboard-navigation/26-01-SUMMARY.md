---
phase: 26-gamepad-keyboard-navigation
plan: 01
status: complete
completed: "2026-07-24"
requirements_verified:
  - NAV-01  # FocusTraversalGroup partitioning
  - NAV-02  # FocusableActionDetector on every row
  - NAV-04  # D-pad Left/Right on controls (partial — Switch via shell)
  - NAV-05  # A key triggers focused control
  - NAV-06  # B key two-step close
---

# Plan 01 Summary: FocusableSettingRow + FocusTraversalGroup + D-pad/A/B Keys

## What Changed

### New Files
- **`lib/ui/shared/focusable_setting_row.dart`** — Reusable focus+hover+press wrapper widget using `FocusableActionDetector`. Handles D-11 (borderHighlight 2px border), D-12 (bgHover hover), D-13 (instant border, Container not AnimatedContainer), D-15 (disabled → ExcludeFocus + IgnorePointer).

- **`test/ui/shared/focusable_setting_row_test.dart`** — 9 unit tests: renders child, focus border, disabled behavior, enabled behavior, Container vs AnimatedContainer, onFocusChange callback, focusKey, autofocus.

- **`test/ui/dialogs/settings_focus_navigation_test.dart`** — 11 integration tests: autofocus, ArrowUp/Down, ArrowLeft/Right tab switching, B/Escape close, Enter key safety, LB/RB, FocusTraversalGroup hierarchy, panel/buttonBar keys, KeyUp ignored, D-pad navigation.

### Modified Files
- **`lib/ui/shared/settings_card.dart`** — SettingRow wrapped with FocusableSettingRow (enabled = `widget.onTap != null`).

- **`lib/ui/dialogs/settings/_settings_nav_item.dart`** — SettingsNavItem wrapped with FocusableSettingRow (always enabled).

- **`lib/ui/dialogs/settings/settings_overlay_shell.dart`** — Three changes:
  1. Added 3 GlobalKeys for FocusTraversalGroup hierarchy (`_sidebarFocusKey`, `_contentFocusKey`, `_buttonBarFocusKey`)
  2. Restructured `_buildPanel` with 3-tier FocusTraversalGroup (sidebar, content, button bar)
  3. Extended `_handleKeyEvent` with priority-based routing: LB/RB > B/Escape (two-step close) > ArrowUp/Down (focus movement) > ArrowLeft/Right (tab switch if sidebar, pass-through if content) > Enter/A (trigger control)

## Test Results
- **9** FocusableSettingRow unit tests — all pass
- **11** Focus navigation integration tests — all pass
- **54** Existing settings_overlay_shell_test — no regressions
- `flutter analyze` — no new errors

## Key Design Decisions
- FocusableSettingRow is a **pure decoration wrapper** — doesn't intercept child gestures
- ArrowLeft/Right only switch tabs when focus is NOT in the content area (controls like SpinControl handle their own Left/Right)
- B key two-step close: content area → sidebar first item, sidebar/button bar → close panel (NAV-06)
- Enter key uses `Actions.handler` (not `Actions.invoke`) to safely check for action handlers without throwing
- Focus border uses Container (not AnimatedContainer) for instant appearance (D-13)

## Requirements Coverage
| Requirement | Status | Evidence |
|-------------|--------|----------|
| NAV-01 | complete | 3 FocusTraversalGroups: sidebar, content, button bar |
| NAV-02 | complete | FocusableActionDetector on SettingRow and SettingsNavItem |
| NAV-04 | partial | ArrowLeft/Right pass-through for controls; Switch toggle via shell |
| NAV-05 | partial | Enter/A triggers focused control via Actions.handler |
| NAV-06 | complete | B key two-step close: content→sidebar, sidebar→close |
