---
phase: 31-visual-design-alignment
reviewed: 2026-07-28T09:47:55Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/ui/dialogs/settings/settings_overlay_shell.dart
  - lib/ui/dialogs/settings/tab_strip.dart
  - lib/ui/player/control_bar.dart
  - lib/ui/shared/control_bar_decoration.dart
  - lib/ui/shared/focusable_setting_row.dart
  - lib/ui/shared/settings_card.dart
  - test/ui/dialogs/settings_overlay_shell_test.dart
  - test/ui/shared/control_bar_decoration_test.dart
  - test/ui/shared/focusable_setting_row_test.dart
  - test/ui/shared/settings_card_test.dart
  - test/widget/settings/general_equalizer_tab_test.dart
  - test/widgets/panel_color_test.dart
findings:
  critical: 1
  warning: 5
  info: 0
  total: 6
status: issues_found
---

# Phase 31: Code Review Report

**Reviewed:** 2026-07-28T09:47:55Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 31 ("visual-design-alignment") extracted a shared `ControlBarDecoration` factory, refactored the settings overlay shell + tab strip, and introduced a three-state `SettingRow` interaction plus a panel color contract. `flutter analyze` is clean for the reviewed files and the six requested test suites pass — but the passing tests do not exercise the affected switch/spin controls, so they cannot detect the critical regression below.

The central concern: `SettingRow` conflates "the row has no row-level `onTap`" with "the row's embedded controls are non-interactive," wrapping the entire row — including its `Switch`/`SpinControl` — in `IgnorePointer`. Rows that embed interactive controls but pass no `onTap` therefore render enabled controls that cannot receive pointer input. Two test-quality findings show the existing tests would still pass if the feature were entirely removed, masking regressions.

## Critical Issues

### CR-01: Embedded setting controls are disabled whenever the row itself has no `onTap`

**File:** `lib/ui/shared/settings_card.dart:45-49, 56-58, 160-169, 225-235`
**Issue:** `SettingRow` sets `FocusableSettingRow.enabled` from `widget.onTap != null`. When `onTap` is null, `FocusableSettingRow` wraps the entire row — including its `Switch` or `SpinControl` — in `IgnorePointer`. Both `SettingSwitchRow` and `SettingSpinRow` construct `SettingRow` without `onTap`, so their embedded controls cannot receive pointer input. The controls render as enabled but are unresponsive to taps, so users cannot toggle switches or operate spin controls.

**Fix:** Separate "the row is focusable/tappable" from "the child controls are interactive." Do not place the whole row under `IgnorePointer` merely because the row-level `onTap` is null. Keep the focus wrapper enabled when it contains interactive controls and only set `InkWell.onTap` to null for the row background:

```dart
return FocusableSettingRow(
  enabled: true,
  focusNode: widget.focusNode,
  focusedBuilder: (context, focused) => _buildInteractiveRow(focused),
);
```

Then ensure non-interactive display-only rows opt out explicitly through a dedicated `enabled`/`focusable` property. Add widget tests that tap `SettingSwitchRow` and operate `SettingSpinRow`, asserting their notifier/callback changes.

## Warnings

### WR-01: Two `FocusableSettingRow` tests are no-op assertions and never focus the row under test

**File:** `test/ui/shared/focusable_setting_row_test.dart:46-70, 134-158`
**Issue:** In the focus-border test, `focusNode` is created and focused but is never passed to `FocusableSettingRow`; the assertion only verifies that its text still exists. In the callback test, the same omission occurs, and `expect(focusChanges, isA<List<bool>>())` always passes because `focusChanges` was created as a list. These tests would pass even if focus handling, border updates, and callbacks were entirely removed — they provide no regression protection.

**Fix:** Pass `focusNode: focusNode` to the tested widget, request focus, and assert a real state transition:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FocusableSettingRow(
        focusNode: focusNode,
        onFocusChange: focusChanges.add,
        child: const Text('Focusable'),
      ),
    ),
  ),
);

focusNode.requestFocus();
await tester.pump();

expect(focusChanges, contains(true));
final decoration = tester.widget<Container>(
  find.descendant(
    of: find.byType(FocusableSettingRow),
    matching: find.byType(Container),
  ),
).decoration! as BoxDecoration;
expect((decoration.border! as Border).top.color, Tokens.controlBarBorderWhite);
```

### WR-02: The tab-selection regression test taps the already-selected default tab and asserts the unchanged value

**File:** `test/ui/dialogs/settings_overlay_shell_test.dart:403-418`
**Issue:** The test claims to tap "视频," but tab index 3 is "通用" according to the actual strip. Index 3 is also the default selected tab. Therefore, the test passes even if `SettingsNavItem.onTap` no longer invokes `onSelect` or the selected-tab notifier is disconnected — it never observes a transition.

**Fix:** Tap a non-default index and assert that value. For example, tap index 2 and expect `selectedTab.value == 2`, while also correcting the test description to match the tab ordering.

### WR-03: The settings chrome introduces hardcoded visual values instead of design tokens

**Files:**
- `lib/ui/dialogs/settings/settings_overlay_shell.dart:197, 204, 368`
- `lib/ui/dialogs/settings/tab_strip.dart:73`
- `lib/ui/player/control_bar.dart:88, 97, 199`

**Issue:** The project requires every visual value to use `Tokens.*`, but these files use literals such as `Colors.black54`, title-bar height `44`, tab heights `56`/`64`, control-bar bottom padding `6`, gradient-strip height `1`, and button-row padding `4`. This makes visual changes inconsistent and prevents the design system from being a single source of truth.

**Fix:** Add semantically named tokens — for example `settingsOverlayMask`, `settingsTitleBarHeight`, `tabStripHeightCompact`, `tabStripHeightNormal`, `controlBarContentBottomPadding`, `controlBarGradientHeight`, and `controlBarButtonRowPadding` — then replace the literals with those tokens.

### WR-04: The display enumerator recovery path catches all thrown objects, including programming errors

**File:** `lib/ui/dialogs/settings/settings_overlay_shell.dart:452-459`
**Issue:** The bare `catch (e, st)` catches `Error` subclasses as well as recoverable platform failures. This conflicts with the project error-handling rules (never catch `Error` subtypes — they indicate programming bugs) and can conceal implementation errors as a geometry fallback, making genuine defects harder to diagnose in production.

**Fix:** Restrict recovery to the expected recoverable exception hierarchy and allow programming errors to surface:

```dart
try {
  info = widget.displayEnumerator?.getCurrentDisplay();
} on Exception catch (error, stackTrace) {
  debugPrint(
    '[SettingsOverlayShell] getCurrentDisplay failed: '
    '$error\n$stackTrace',
  );
  return _symmetricClamp(next, mediaSize, panelSize);
}
```

Apply the same restriction to the asynchronous `windowPositionReader` failure handling if that reader is expected to expose only recoverable platform exceptions.

### WR-05: `settings_overlay_shell.dart` exceeds the project's 500-line source-file limit

**File:** `lib/ui/dialogs/settings/settings_overlay_shell.dart:1-548`
**Issue:** The file is 548 lines and combines overlay lifecycle, animation, panel composition, title chrome, drag session management, geometry calculation, display lookup recovery, and coordinate clamping. This has already made behavioral regressions difficult to isolate, as demonstrated by the large integration-style test file needed to exercise it.

**Fix:** Extract drag/clamp coordination into a dedicated, testable helper or controller (for example `SettingsOverlayDragController`) and move panel chrome builders into focused widgets. Keep `SettingsOverlayShell` responsible only for overlay lifecycle and composition.

---

_Reviewed: 2026-07-28T09:47:55Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
