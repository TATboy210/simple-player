---
phase: 14-testability-data-flow
plan: 01
subsystem: testing
tags: [flutter-analyze, test-fix, shortcuts-tab, clean-baseline]

requires:
  - phase: 13
    provides: Widget API unified, FakeEngine complete
provides:
  - Clean test baseline (0 failures, 0 analysis issues)
affects: [14-02]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - lib/ui/dialogs/settings/shortcuts_tab.dart
    - test/engine/mixin_capability_test.dart
    - test/kernel/engine/fvp_callback_handler_test.dart
    - test/kernel/engine/fvp_engine_open_test.dart
    - test/kernel/models/export_data_test.dart
    - test/kernel/persistence/settings_import_export_test.dart
    - test/widget/player/player_screen_test.dart
    - test/widget/settings/general_equalizer_tab_test.dart

key-decisions:
  - "Removed Expanded from AnimatedSectionList children — FadeTransition wrapping makes Expanded incompatible"

patterns-established: []

requirements-completed: [TEST-01, TEST-02, TEST-04]

coverage:
  - id: D1
    description: "4 pre-existing test failures fixed in shortcuts_tab_test.dart"
    requirement: TEST-01
    verification:
      - kind: unit
        ref: "flutter test test/widget/settings/shortcuts_tab_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "17 flutter analyze warnings/infos reduced to 0"
    requirement: TEST-04
    verification:
      - kind: automated_ui
        ref: "flutter analyze"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-07-14
status: complete
---

# Phase 14 Plan 01: Clean Baseline Summary

**Fixed 4 test failures (ShortcutsTab Expanded/FadeTransition incompatibility) + 17 analysis warnings → 0 issues clean baseline**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-14T16:00:00Z
- **Completed:** 2026-07-14T16:15:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Fixed ShortcutsTab widget: removed Expanded from AnimatedSectionList children (FadeTransition wrapping makes Expanded incompatible with non-Flex parent)
- Fixed all 17 flutter analyze issues: dead_code, unnecessary_import, dangling_library_doc_comments, no_leading_underscores, prefer_const_constructors, strict_raw_type, unawaited_futures
- Clean baseline established: 0 test failures, 0 analysis issues

## Task Commits

1. **Task 1: Fix 4 test failures** - `fb93971` (fix)
2. **Task 2: Fix 17 analysis warnings** - `fb93971` (fix)

## Files Created/Modified
- `lib/ui/dialogs/settings/shortcuts_tab.dart` — Removed Expanded from AnimatedSectionList children
- `test/engine/mixin_capability_test.dart` — Removed 3 dead else branches
- `test/kernel/engine/fvp_callback_handler_test.dart` — Removed unnecessary import
- `test/kernel/engine/fvp_engine_open_test.dart` — Added library directive
- `test/kernel/models/export_data_test.dart` — Renamed _testSettings, added const
- `test/kernel/persistence/settings_import_export_test.dart` — Removed import, fixed raw types, added const
- `test/widget/player/player_screen_test.dart` — Wrapped futures with unawaited()
- `test/widget/settings/general_equalizer_tab_test.dart` — Added const constructors

## Decisions Made
- Removed Expanded from ShortcutsTab.build() return — AnimatedSectionList wraps children in FadeTransition which is not a Flex widget. The parent settings_panel.dart already provides Expanded > AnimatedSwitcher context.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
- Clean baseline ready for Plan 14-02 (widget interaction tests + error propagation integration test)

---
*Phase: 14-testability-data-flow*
*Completed: 2026-07-14*
