---
phase: 02-widget-unification
plan: 02
subsystem: ui
tags: [flutter, glass-morphism, backdrop-filter, performance, value-notifier, audit]

# Dependency graph
requires: [02-01]
provides:
  - "GlassContainer conditional BackdropFilter skip (opacity < 0.01)"
  - "GlassContainer degradation mode (blurEnabled=false)"
  - "GlassTier 3-tier evaluation documented"
  - "ValueNotifier rebuild audit across all ui/ (7 files, 4 dimensions)"
affects: [02-widget-unification, ui, glass, performance]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Conditional BackdropFilter skip via ValueListenable<double>", "Degradation mode via blurEnabled flag"]

key-files:
  created: []
  modified:
    - "lib/ui/shared/glass_container.dart"
    - "lib/ui/player/controls_overlay.dart"

key-decisions:
  - "GlassContainer opacity parameter uses AnimatedBuilder to skip BackdropFilter when value < 0.01 (D-13)"
  - "GlassContainer blurEnabled=false renders only Container with BoxDecoration, no BackdropFilter (D-14)"
  - "GlassTier keeps 3 tiers (thin=8, normal=10, thick=24) — thin/normal gap is visually distinguishable on 4K (D-15)"
  - "All ValueListenableBuilder instances in ui/ already optimal — zero changes needed"

patterns-established:
  - "Conditional BackdropFilter skip: AnimatedBuilder on opacity ValueListenable, threshold 0.01"
  - "Degradation mode: blurEnabled flag gates BackdropFilter rendering path"

requirements-completed: [WIDGET-02]

# Metrics
duration: 6min
completed: 2026-05-28
---

# Phase 2 Plan 02: Glass Performance + ValueNotifier Audit Summary

**Conditional BackdropFilter skip, degradation mode, GlassTier evaluation, and full ValueNotifier rebuild audit**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-28T15:00:04Z
- **Completed:** 2026-05-28T15:06:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `opacity` parameter to GlassContainer — AnimatedBuilder skips BackdropFilter GPU readback when value < 0.01 (D-13)
- Added `blurEnabled` parameter to GlassContainer — no-blur fallback renders only Container with BoxDecoration (D-14)
- Documented GlassTier 3-tier decision in enum comment — thin/normal gap is visually distinguishable on 4K displays (D-15)
- Completed ValueNotifier rebuild audit across all 7 ui/ files on 4 dimensions (D-10, D-11, D-12)
- All 304 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Glass Performance Optimizations** - `c925dc8` (perf)
2. **Task 2: ValueNotifier Rebuild Audit** - `7d2bba4` (docs)

## Files Created/Modified

- `lib/ui/shared/glass_container.dart` — Added `opacity` (ValueListenable<double>?) and `blurEnabled` (bool) parameters with conditional BackdropFilter skip logic
- `lib/ui/player/controls_overlay.dart` — Added audit reference comment documenting findings across all 7 files

## Decisions Made

- GlassContainer opacity uses AnimatedBuilder (matching control_bar.dart existing pattern) — consistent approach across codebase
- GlassContainer blurEnabled defaults to true — all existing call sites unaffected
- GlassTier keeps 3 tiers — maintenance cost of one extra enum value is negligible vs visual benefit on 4K
- Audit result: all ValueListenableBuilder instances already use child caching, MergedListenable, or correctly cannot cache (output depends on value)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing flutter/foundation.dart import**
- **Found during:** Task 1
- **Issue:** `ValueListenable` type requires explicit `flutter/foundation.dart` import
- **Fix:** Added `import 'package:flutter/foundation.dart'` to glass_container.dart
- **Files modified:** lib/ui/shared/glass_container.dart
- **Verification:** `dart analyze` passes with zero errors
- **Committed in:** c925dc8 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking issue)
**Impact on plan:** Single import addition. No scope creep.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - all functionality fully wired. GlassContainer opacity and blurEnabled parameters are ready for use by callers (ControlBar, PlaylistPanel, etc.) but no call sites were changed in this plan — they will wire up when needed.

## Threat Flags

No new security-relevant surface introduced. All changes are UI performance optimization and documentation.

## Self-Check

- [x] `c925dc8` exists in git log (Task 1)
- [x] `7d2bba4` exists in git log (Task 2)
- [x] `lib/ui/shared/glass_container.dart` has `opacity` parameter
- [x] `lib/ui/shared/glass_container.dart` has `blurEnabled` parameter
- [x] `lib/ui/shared/glass_container.dart` has GlassTier 3-tier comment
- [x] `lib/ui/player/controls_overlay.dart` has audit reference comment
- [x] 304 tests pass
- [x] `dart analyze` clean

---
*Phase: 02-widget-unification*
*Completed: 2026-05-28*
