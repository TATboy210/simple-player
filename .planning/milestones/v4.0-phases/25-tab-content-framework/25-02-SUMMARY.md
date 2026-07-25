---
phase: 25-tab-content-framework
plan: 02
subsystem: ui/settings
tags: [skeleton-tabs, tab-content, overlay-shell, settings-panel]
dependency_graph:
  requires: [25-01]
  provides: [skeleton-tabs, tab-content-framework]
  affects: [settings_overlay_shell, settings_panel_controller]
tech_stack:
  added: []
  patterns: [deferred-apply, glass-morphism, animated-section-list]
key_files:
  created:
    - lib/ui/dialogs/settings/tabs/general_tab.dart
    - lib/ui/dialogs/settings/tabs/equalizer_tab.dart
    - lib/ui/dialogs/settings/tabs/audio_tab.dart
    - lib/ui/dialogs/settings/tabs/video_tab.dart
    - lib/ui/dialogs/settings/tabs/shortcuts_tab.dart
    - lib/ui/dialogs/settings/tabs/about_tab.dart
    - lib/ui/dialogs/settings/tabs/performance_tab.dart
    - test/ui/dialogs/settings_tab_content_test.dart
  modified:
    - lib/ui/dialogs/settings/settings_overlay_shell.dart
    - test/ui/dialogs/settings_overlay_shell_test.dart
decisions:
  - SingleChildScrollView wraps AnimatedSectionList in all tabs to prevent Column overflow in constrained panel height
  - Tabs use raw SettingRow with inline control widgets (Switch/Slider/DropdownButton) instead of SettingSwitchRow/SettingSliderRow for maximum flexibility
  - EqualizerTab exception: uses SettingSliderRow for 3 frequency band sliders (explicit plan directive)
  - Existing test finders made more specific (GlassContainer/IndexedStack) to handle multiple instances in tree
metrics:
  duration: ~13min
  completed: "2026-07-23T17:34:55Z"
  tasks: 2
  files: 10
status: complete
---

# Phase 25 Plan 02: Tab Content Framework Summary

## One-Liner

7 skeleton tab pages with SettingRow skeletons (Switch/Slider/Dropdown) wired into overlay shell IndexedStack with 18 widget tests.

## What Was Built

### 7 Skeleton Tab Pages (lib/ui/dialogs/settings/tabs/)

Each tab is a `StatelessWidget` receiving `PendingSettingsState`, using `AnimatedSectionList` + `GlassContainer` + `SectionHeader` + `SettingRow`:

1. **GeneralTab** — locale dropdown (zh/en) + dark mode Switch
2. **EqualizerTab** — EQ enable Switch + 3 frequency band SettingSliderRow (60Hz/1kHz/14kHz)
3. **AudioTab** — output device dropdown + auto-select track Switch + volume Slider
4. **VideoTab** — decoder dropdown (hardware/software/auto) + deinterlace Switch + brightness Slider
5. **ShortcutsTab** — 3 key binding display chips (Space, arrows, volume) with _KeyChip placeholder
6. **AboutTab** — version info (v1.8.0, MDK) + project link placeholder
7. **PerformanceTab** — frame stats overlay Switch + log level dropdown (debug/info/warn/error)

All controls persist to `PendingSettingsState` via `pending.update()`. No real service calls.

### Shell Wiring (settings_overlay_shell.dart)

- Added imports for 7 tab widgets from `tabs/` subdirectory
- Replaced `List.generate` placeholder content with explicit 7-entry list
- Each tab wrapped in `TweenAnimationBuilder<double>` for opacity fade (200ms)
- Passes `_controller.pending` to each tab
- IndexedStack logic unchanged — selectedIndex drives visibility

### Widget Tests (settings_tab_content_test.dart)

18 tests covering:
- Tab rendering: each of 7 tabs renders correct section headers and SettingRow labels
- Control types: Switch, Slider, DropdownButton present in correct tabs
- SettingRow usage: all tabs use SettingRow for layout
- Pending state: Switch initial value, DropdownButton selection updates pending
- AnimatedSectionList: used in tab content for staggered fade-in
- IndexedStack: keeps all 7 tabs alive after switching
- No regressions: nav items and button bar still render correctly

## Tests

### settings_tab_content_test.dart (18 tests — all pass)
- 7 tab rendering tests (one per tab)
- 4 control type tests (Switch, DropdownButton, Slider, SettingRow)
- 1 pending state initial value test
- 1 dropdown interaction test
- 1 AnimatedSectionList presence test
- 1 IndexedStack alive test
- 3 no-regression tests

### settings_overlay_shell_test.dart (36 tests — all pass, no regressions)
- 2 existing tests updated for finder specificity (GlassContainer/IndexedStack)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Column overflow in AnimatedSectionList**
- **Found during:** Task 2 (test execution)
- **Issue:** AnimatedSectionList uses Column (not ListView), causing overflow in constrained panel height (800x600 window, panel ~376x120 after title bar + tab bar + button bar)
- **Fix:** Wrapped AnimatedSectionList in SingleChildScrollView in all 7 tab files
- **Files modified:** all 7 tabs/* files
- **Commit:** 1c5bf5a

**2. [Rule 3 - Blocking] Multiple GlassContainer/IndexedStack in widget tree**
- **Found during:** Task 2 (existing test regression)
- **Issue:** Adding 7 tab widgets introduced multiple GlassContainer and IndexedStack instances, breaking existing tests using `find.byType()` which expected exactly one
- **Fix:** Updated 2 existing tests to use more specific finders (ancestor/descendant with panelKey, firstWhere with children.length == 7)
- **Files modified:** test/ui/dialogs/settings_overlay_shell_test.dart
- **Commit:** 1c5bf5a

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| Skeleton controls persist to PendingSettingsState only | tabs/*.dart | all | Real service wiring deferred to later phases |
| _KeyChip placeholder for key bindings | shortcuts_tab.dart | _KeyChip class | Real key recording is Phase 26 (NAV-03) |
| TODO: url_launcher for project link | about_tab.dart | removed onTap | Link action deferred to Phase 26+ |
| Dummy ValueNotifier for EQ sliders | equalizer_tab.dart | ValueNotifier(0.0) | Skeleton display only, not wired to real EQ |

## Threat Flags

None — skeleton tabs are pure renderers with no external attack surface. All user interactions persist to in-memory PendingSettingsState only.

## Self-Check: PASSED

- lib/ui/dialogs/settings/tabs/general_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/equalizer_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/audio_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/video_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/shortcuts_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/about_tab.dart: FOUND
- lib/ui/dialogs/settings/tabs/performance_tab.dart: FOUND
- lib/ui/dialogs/settings/settings_overlay_shell.dart: FOUND (modified)
- test/ui/dialogs/settings_tab_content_test.dart: FOUND
- Commit 4c437a8: FOUND in git log (Task 1)
- Commit 1c5bf5a: FOUND in git log (Task 2)
- flutter analyze: No issues found
- flutter test: 18/18 new + 36/36 existing = 54/54 pass
