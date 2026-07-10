---
phase: 01-settings-panel-glass-redesign
plan: 01
subsystem: ui
tags: [glass, settings, refactor, shared-component]
requires: [STYLE-01, STYLE-02, STYLE-03, STYLE-04, COMP-04]
provides: [section_header, glass_panel_shell]
affects: [settings_panel, settings_card, settings_nav_item]
tech_stack:
  added: []
  patterns: [GlassContainer, SectionHeader, Tokens.*]
key_files:
  created:
    - lib/ui/shared/section_header.dart
    - test/widget/shared/section_header_test.dart
  modified:
    - lib/ui/shared/settings_card.dart
    - lib/ui/dialogs/settings_panel.dart
    - lib/ui/dialogs/settings/_settings_nav_item.dart
decisions:
  - "Extracted SectionHeader as public shared widget for all 7 tabs to import"
  - "Replaced Material(elevation: 8) panel shell with GlassContainer for glassmorphism"
  - "Preserved all interaction logic (drag, apply, cancel) unchanged"
  - "Used Tokens.fontOverline instead of hardcoded fontSize: 10 in nav items"
metrics:
  duration: 8m30s
  completed: "2026-07-08T14:51:26Z"
  tasks: 3
  files: 5
status: complete
---

# Phase 1 Plan 1: Foundation — SectionHeader + Glass Panel Shell Summary

Extracted SectionHeader to shared file, applied GlassContainer glassmorphism to settings panel shell, and aligned sidebar nav items with design tokens.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extract _SectionHeader to shared file | bc4a9e9 | section_header.dart, settings_card.dart, section_header_test.dart |
| 2 | Apply GlassContainer to settings panel shell | 7a381d2 | settings_panel.dart |
| 3 | Update sidebar nav item with glass hover styling | f7d2f3c | _settings_nav_item.dart |

## What Changed

### Task 1: SectionHeader Extraction (TDD)
- Created `lib/ui/shared/section_header.dart` with public `SectionHeader` widget
- Copied exact implementation from `settings_card.dart` lines 234-273
- Updated `settings_card.dart` to import and use `SectionHeader` instead of private `_SectionHeader`
- Removed private `_SectionHeader` class from `settings_card.dart`
- 5 widget tests: title rendering, icon, description, color token, font token

### Task 2: Glass Panel Shell
- Replaced `Material(elevation: 8, color: Tokens.bgElevated)` with `GlassContainer`
- GlassContainer provides its own ClipRRect and BackdropFilter
- Title bar background: `Tokens.bgElevated` → `Tokens.bgGlass`
- Bottom bar background: `Tokens.bgElevated` → `Tokens.bgGlass`
- All interaction logic preserved: drag, OK/Cancel/Apply, delayed apply

### Task 3: Nav Item Token Alignment
- Replaced hardcoded `fontSize: 10` with `Tokens.fontOverline`
- Verified existing patterns match control bar: bgHover, iconLg, accent/textSecondary colors
- Left border accent preserved for selected state
- No scale animation added (per user preference)

## Verification Results

- `flutter analyze` — No issues found (all 4 modified files)
- `flutter test test/widget/shared/section_header_test.dart` — 5/5 tests passed
- No new warnings introduced

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2] Hardcoded font size in nav item**
- **Found during:** Task 3
- **Issue:** `fontSize: 10` instead of `Tokens.fontOverline` in `_settings_nav_item.dart`
- **Fix:** Replaced with `Tokens.fontOverline` for design system consistency
- **Files modified:** `lib/ui/dialogs/settings/_settings_nav_item.dart`
- **Commit:** f7d2f3c

## Known Stubs

None — all extracted code is fully functional with real implementations.

## Threat Flags

None — pure UI visual refactor with no security-sensitive code changes.

## Dependencies for Next Plans

- `lib/ui/shared/section_header.dart` — importable by all 7 tab files
- `GlassContainer` panel shell — verified working in overlay context
- Sidebar nav items — visually consistent with control bar pattern

## Self-Check: PASSED

- All 6 created/modified files verified present
- All 3 task commits verified in git log (bc4a9e9, 7a381d2, f7d2f3c)
