---
phase: 03-reset-to-defaults
plan: 01
subsystem: ui/settings
tags: [settings, reset, l10n, glass-dialog]
requires: []
provides: [SUI-02]
affects: [settings_panel, general_tab, equalizer_tab, video_tab, shortcuts_tab, performance_tab]
tech_stack:
  added: []
  patterns: [glass-confirmation-dialog, reset-counter-valuekey, deferred-apply-reset]
key_files:
  created: []
  modified:
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/ui/dialogs/settings_panel.dart
    - lib/ui/dialogs/settings/general_tab.dart
    - lib/ui/dialogs/settings/equalizer_tab.dart
    - lib/ui/dialogs/settings/video_tab.dart
    - lib/ui/dialogs/settings/shortcuts_tab.dart
    - lib/ui/dialogs/settings/settings_tab_performance.dart
decisions:
  - "Used Tokens.danger instead of Tokens.error (token does not exist in design system)"
  - "Reset counter + ValueKey pattern to force StatefulWidget rebuild after reset"
  - "Centralized reset logic in SettingsPanel._resetTab for consistency"
metrics:
  duration: ~10min
  completed: "2026-07-13T07:35:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 8
status: complete
---

# Phase 3 Plan 01: Reset to Defaults Summary

Per-tab "restore defaults" functionality for 5 settings tabs with glass-styled confirmation dialog and correct reset logic per tab.

## What Was Built

- **Localization keys** (en + zh): `resetToDefaults`, `resetConfirmTitle`, `resetConfirmMessage`, `confirmReset`
- **Glass-styled confirmation dialog** (`_showResetConfirmDialog`): AlertDialog + BackdropFilter with `GlassTier.normal.blurFilter`, `Tokens.danger` confirm button
- **Per-tab reset dispatch** (`_resetTab`): General deferred, EQ engine clear, Video service reset, Shortcuts persist empty map, Performance persist defaults
- **Reset counter pattern**: `_eqResetCounter`, `_shortcutsResetCounter`, `_perfResetCounter` with `ValueKey` to force StatefulWidget rebuild
- **Bottom-bar reset button**: Left-aligned TextButton, conditional on `_resettableTabIndices = {0, 1, 3, 4, 6}`
- **5 tab onReset callbacks**: All tabs accept `VoidCallback? onReset`, show standard TextButton at bottom-left

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Tokens.danger for confirm button | Tokens.error does not exist in design system; danger is the red warning color |
| Reset counter + ValueKey | StatefulWidget state persists across parent rebuilds; ValueKey forces initState re-execution |
| Centralized _resetTab in SettingsPanel | Locale/theme deferred apply requires panel-level state management |
| SettingsStore.saveShortcuts({}) in _resetTab(4) | ShortcutsTab._resetAll did not persist; must save empty map explicitly |
| _loading guard on PerformanceTab reset | Pitfall 3: async loading race if reset before _loadSettings completes |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used Tokens.danger instead of Tokens.error**
- **Found during:** Task 1 implementation
- **Issue:** Plan references `Tokens.error` but token does not exist in `tokens.dart`. Only `Tokens.danger` exists.
- **Fix:** Used `Tokens.danger` for confirm button foreground color
- **Files modified:** `lib/ui/dialogs/settings_panel.dart`
- **Commit:** 3d50377

**2. [Rule 2 - Missing] Added SettingsStore.saveShortcuts({}) in _resetTab(4)**
- **Found during:** Task 1 implementation
- **Issue:** ShortcutsTab._resetAll only cleared in-memory state and called onShortcutsChanged, but did not persist to SettingsStore. Reset would revert on next app launch.
- **Fix:** Added `SettingsStore.saveShortcuts({})` in `_resetTab(4)` after clearing bindings
- **Files modified:** `lib/ui/dialogs/settings_panel.dart`
- **Commit:** 3d50377

## Known Stubs

None — all reset logic is wired to real services/persistence.

## Self-Check: PASSED

- [x] `lib/l10n/app_en.arb` contains `resetToDefaults`, `resetConfirmTitle`, `resetConfirmMessage`, `confirmReset`
- [x] `lib/l10n/app_zh.arb` contains Chinese translations for same keys
- [x] `settings_panel.dart` contains `_showResetConfirmDialog` with BackdropFilter + GlassTier.normal.blurFilter
- [x] `settings_panel.dart` contains `_resetTab` with switch cases for indices 0, 1, 3, 4, 6
- [x] `_resetTab(0)` sets `_pendingLocale = 'zh'` and `_pendingThemeIndex = 0`
- [x] `_resetTab(1)` calls `widget.engine.setEqualizer('')`
- [x] `_resetTab(4)` calls `widget.onShortcutsChanged?.call({})` and `SettingsStore.saveShortcuts({})`
- [x] `_buildBottomBar` includes TextButton with `l10n.resetToDefaults` on left side
- [x] Confirm button uses `Tokens.danger` foreground color
- [x] `_resettableTabIndices` = `{0, 1, 3, 4, 6}` (excludes 2, 5)
- [x] `general_tab.dart` has `this.onReset` parameter + reset button
- [x] `equalizer_tab.dart` has `this.onReset` parameter + reset button
- [x] `video_tab.dart` has `this.onReset` parameter, old inline InkWell removed
- [x] `shortcuts_tab.dart` has `this.onReset` parameter, `_resetAll` method removed
- [x] `settings_tab_performance.dart` has `this.onReset` parameter + loading guard
- [x] `flutter analyze` passes with no issues
