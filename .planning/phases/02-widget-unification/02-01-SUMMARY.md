---
phase: 02-widget-unification
plan: 01
subsystem: ui
tags: [flutter, glass-morphism, barrel-file, widget-merge, inkwell]

# Dependency graph
requires: []
provides:
  - "Unified GlassButton widget with icon-only (lightweight) and label (blur) constructors"
  - "glass_widgets.dart barrel file exporting all 4 glass types"
  - "Zero GlassIconButton references — full migration complete"
  - "Widget tests for merged GlassButton (8 test cases)"
affects: [02-widget-unification, ui, glass]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Dual-mode StatelessWidget (icon-only vs label)", "InkWell-only interaction (no scale animation)", "Barrel file export pattern"]

key-files:
  created:
    - "lib/ui/shared/glass_widgets.dart"
    - "test/widget/shared/glass_button_test.dart"
  modified:
    - "lib/ui/shared/glass_container.dart"
    - "lib/ui/player/control_bar.dart"
    - "lib/ui/player/center_controls.dart"
    - "lib/ui/player/volume_controls.dart"

key-decisions:
  - "GlassButton.iconOnly uses SizedBox(36x36) + Material + InkWell (no BackdropFilter) — preserves lightweight rendering for 14 control bar buttons"
  - "GlassButton label mode uses GlassContainer wrapped in Material + InkWell — no GestureDetector, no scale animation"
  - "Both paths use InkWell with hoverColor: Tokens.bgHover, splashFactory: NoSplash.splashFactory"

patterns-established:
  - "Dual-mode StatelessWidget: icon-only (lightweight, no blur) and label (GlassContainer + blur) via named constructors"
  - "InkWell-only interaction: no GestureDetector/MouseRegion/AnimatedBuilder/scale animation"
  - "Barrel file: glass_widgets.dart re-exports glass_container.dart and glass_chip.dart"

requirements-completed: [WIDGET-01]

# Metrics
duration: 8min
completed: 2026-05-28
---

# Phase 2 Plan 01: Glass Component Merge Summary

**Dual-mode GlassButton (icon-only + label) replacing GlassIconButton, with barrel file and 8 widget tests**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-28T22:46:06Z
- **Completed:** 2026-05-28T22:54:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Merged GlassIconButton into GlassButton as dual-mode StatelessWidget with icon-only and label constructors
- Created glass_widgets.dart barrel file exporting GlassContainer, GlassButton, GlassTier, GlassChip
- Migrated all 14 GlassIconButton call sites across 3 files (control_bar, center_controls, volume_controls)
- Deleted glass_icon_button.dart — zero remaining references in lib/
- Added 8 widget tests covering icon-only render, label render, tap callback, disabled state, and secondary tap

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor GlassButton + Create Barrel File** - `f0e9f73` (feat)
2. **Task 2: Migrate Call Sites + Delete Old File + Widget Tests** - `b1d6ec4` (feat)

## Files Created/Modified

- `lib/ui/shared/glass_container.dart` — Refactored GlassButton to StatelessWidget with dual-mode rendering (icon-only: SizedBox+Material+InkWell, label: GlassContainer+Material+InkWell)
- `lib/ui/shared/glass_widgets.dart` — NEW: barrel file exporting GlassContainer, GlassButton, GlassTier, GlassChip
- `lib/ui/player/control_bar.dart` — Migrated 6 GlassIconButton calls to GlassButton.iconOnly
- `lib/ui/player/center_controls.dart` — Migrated 7 GlassIconButton calls to GlassButton.iconOnly
- `lib/ui/player/volume_controls.dart` — Migrated 1 GlassIconButton call to GlassButton.iconOnly
- `lib/ui/shared/glass_icon_button.dart` — DELETED
- `test/widget/shared/glass_button_test.dart` — NEW: 8 widget tests for merged GlassButton

## Decisions Made

- GlassButton.iconOnly uses SizedBox(36x36) + Material + InkWell with NO BackdropFilter — preserves lightweight rendering for control bar buttons (per RESEARCH.md Pitfall 1)
- GlassButton label mode uses GlassContainer wrapped in Material + InkWell — no GestureDetector, no AnimatedBuilder, no scale animation (per D-06/D-07)
- Both paths share InkWell behavior: hoverColor: Tokens.bgHover, splashFactory: NoSplash.splashFactory
- Tokens.hoverScale and Tokens.pressScale kept in tokens.dart — settings_card.dart still uses them (per PATTERNS.md migration checklist)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed kSecondaryButton import in tests**
- **Found during:** Task 2 (Widget Tests)
- **Issue:** kSecondaryButton requires `import 'package:flutter/gestures.dart'` — not available from flutter_test alone
- **Fix:** Added explicit gestures.dart import to test file
- **Files modified:** test/widget/shared/glass_button_test.dart
- **Verification:** All 8 tests pass
- **Committed in:** b1d6ec4 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor test import fix. No scope creep.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - all functionality fully wired.

## Threat Flags

No new security-relevant surface introduced. All changes are UI widget consolidation.

## Next Phase Readiness

- glass_widgets.dart barrel file ready for use by Phase 2 Plan 02 (ValueNotifier audit)
- Unified GlassButton API stable — icon-only and label modes fully tested
- 304 tests pass (full suite green)

---
*Phase: 02-widget-unification*
*Completed: 2026-05-28*
