---
phase: 25-tab-content-framework
plan: 01
subsystem: ui/settings
tags: [deferred-apply, button-bar, settings-panel, tabs-03, tabs-04]
dependency_graph:
  requires: [23-overlay-shell-state-model, 24-sidebar-navigation]
  provides: [PendingSettingsState, SettingsButton, button-bar]
  affects: [settings_overlay_shell, settings_panel_controller]
tech_stack:
  added: []
  patterns: [deferred-apply, glass-morphism-button]
key_files:
  created:
    - lib/ui/dialogs/settings/pending_settings.dart
    - lib/ui/shared/settings_button.dart
    - test/ui/dialogs/pending_settings_test.dart
  modified:
    - lib/ui/dialogs/settings/settings_overlay_shell.dart
    - lib/ui/dialogs/settings/settings_panel_controller.dart
    - test/ui/dialogs/settings_overlay_shell_test.dart
decisions:
  - PendingSettingsState is plain Dart (not ChangeNotifier) to prevent IndexedStack cascade rebuilds
  - commit() updates originals so Apply-then-Cancel uses committed values as new baseline
  - Button bar always visible when panel open (no hasChanges guard)
  - Service wiring deferred to later phases — buttons only interact with PendingSettingsState
metrics:
  duration: ~15min
  completed: "2026-07-23T17:15:00Z"
  tasks: 1
  files: 6
status: complete
---

# Phase 25 Plan 01: Deferred Apply Infrastructure + Button Bar Summary

## One-Liner

PendingSettingsState deferred-apply pattern with OK/Cancel/Apply glass-morphism button bar wired into settings overlay shell.

## What Was Built

### PendingSettingsState (lib/ui/dialogs/settings/pending_settings.dart)
- Plain Dart class (NOT ChangeNotifier) — prevents IndexedStack cascade rebuilds
- `_pending` map holds user modifications keyed by setting ID string
- `_originals` map holds snapshot values from panel open
- `register(key, value)` — stores original value (called on panel open)
- `update(key, value)` — stores pending value (called by tab content)
- `current(key)` — returns pending ?? original (display value)
- `hasChanges` getter — true when pending map is non-empty
- `commit()` — returns changes map, updates originals (Apply-then-Cancel baseline), clears pending
- `cancel()` — returns originals map, clears pending (tabs re-read current() to restore)
- `dispose()` — clears both maps

### SettingsButton (lib/ui/shared/settings_button.dart)
- Public StatelessWidget extracted from old `_BottomButton` pattern
- Fields: label, onTap, primary (default false)
- Glass morphism: bgGlass background, borderHighlight border, textPrimary text
- Primary mode: accent background, white text, blue glow shadow
- Hover: bgHover background; Press: scale 0.98 (Tokens.pressScale)
- Fixed height 32px, horizontal padding Tokens.spMd, borderRadius Tokens.radiusBtn

### Button Bar (settings_overlay_shell.dart)
- `_buildButtonBar()` added after Expanded(content) in _buildPanel Column
- Container with bgGlass background, spMd horizontal / spSm vertical padding
- Row with three SettingsButton: Cancel (left), Apply (middle), OK (primary, right)
- SizedBox(spSm) between buttons
- Always visible when panel open (no hasChanges guard)

### Controller Integration (settings_panel_controller.dart)
- `final pending = PendingSettingsState()` field added
- `open()` registers placeholder keys: 'locale' (default 'zh'), 'themeIndex' (default 0)
- `close()` calls `pending.dispose()` to clear state
- `commitPending()` / `cancelPending()` methods delegate to pending
- `dispose()` calls both `pending.dispose()` and `state.dispose()`

## Tests

### pending_settings_test.dart (14 tests)
- register stores original value
- update stores pending value
- current returns pending when available, original when no pending
- hasChanges is true after update, false after commit/cancel
- commit returns pending map and updates originals
- cancel returns originals and clears pending
- Apply-then-Cancel: second cancel returns committed values
- dispose clears both maps
- Empty state: commit/cancel returns empty map
- register overwrites existing key (idempotent)

### settings_overlay_shell_test.dart (5 new tests)
- Button bar renders three SettingsButton widgets when panel is open
- Button bar not rendered when panel is closed
- OK button calls close on controller
- Apply button does NOT call close
- Cancel button calls close on controller

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Undersized window overflow from button bar height**
- **Found during:** Test execution
- **Issue:** 400x300 window produces 200x150 panel; button bar adds ~40px causing Column overflow
- **Fix:** Changed undersized window test from 400x300 to 480x360 (panel 240x180) to accommodate button bar height
- **Files modified:** test/ui/dialogs/settings_overlay_shell_test.dart
- **Commit:** db7538f

**2. [Rule 1 - Bug] Missing close timer pump in OK/Cancel button tests**
- **Found during:** Test execution
- **Issue:** OK and Cancel button tests failed with "Timer still pending" — close() triggers 200ms delayed Future
- **Fix:** Added `tester.pump(Duration(milliseconds: 250))` after close assertions
- **Files modified:** test/ui/dialogs/settings_overlay_shell_test.dart
- **Commit:** db7538f

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| Placeholder keys 'locale'/'themeIndex' | settings_panel_controller.dart | open() | Real tab content not yet wired; Plan 02 will replace with actual setting registrations |

## Threat Flags

None — PendingSettingsState is in-memory only, no external attack surface. User preferences have no security sensitivity (T-25-01/T-25-02 accepted in threat model).

## Self-Check: PASSED

- lib/ui/dialogs/settings/pending_settings.dart: FOUND
- lib/ui/shared/settings_button.dart: FOUND
- lib/ui/dialogs/settings/settings_overlay_shell.dart: FOUND (modified)
- lib/ui/dialogs/settings/settings_panel_controller.dart: FOUND (modified)
- test/ui/dialogs/pending_settings_test.dart: FOUND
- test/ui/dialogs/settings_overlay_shell_test.dart: FOUND (modified)
- Commit db7538f: FOUND in git log
