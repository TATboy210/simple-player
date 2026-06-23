---
phase: 03-performance-optimization
plan: 02
subsystem: ui
tags: [performance, backdrofilter, valuenotifier, rebuild, profiling]

requires:
  - phase: 03-performance-optimization
    provides: D3D11 sync tuning from Plan 01
  - phase: 02-widget-unification
    provides: GlassContainer/GlassIconButton unified components
provides:
  - Control bar profiling test suite with rebuild count measurements
  - Static caching of ImageFilter.blur and BorderRadius in ControlBar
  - Deduplicated ValueListenableBuilder in ControlsOverlay
  - Phase 2 optimization verification (enableBlur, BackdropFilter skip, RepaintBoundary)
affects: [03-performance-optimization]

tech-stack:
  added: []
  patterns: [static-final-caching, vlb-dedup]

key-files:
  created:
    - test/perf/control_bar_perf_test.dart
  modified:
    - lib/ui/player/control_bar.dart
    - lib/ui/player/controls_overlay.dart

key-decisions:
  - "Cache ImageFilter.blur and BorderRadius as static final — avoids per-build allocation"
  - "Remove redundant inner ValueListenableBuilder<bool> in ControlsOverlay — single VLB passes isVisible to both IgnorePointer and ControlBar"
  - "No double-BackdropFilter issue — GlassIconButton uses Material+InkWell, not GlassContainer"

patterns-established:
  - "Static final caching for expensive immutable objects (ImageFilter, BorderRadius)"
  - "Single ValueListenableBuilder per notifier — avoid redundant listeners"

requirements-completed: [PERF-03]

duration: 15min
completed: 2026-05-29
---

# Phase 3 Plan 02: Control Bar Profiling + Optimization Summary

**Static caching of ImageFilter.blur/BorderRadius in ControlBar, deduplicated ValueListenableBuilder in ControlsOverlay, 8-widget profiling test suite**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-28T17:58:14Z
- **Completed:** 2026-05-29
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created profiling test suite (8 tests) measuring rebuild counts during playback/seek/hover
- Cached ImageFilter.blur and BorderRadius as static final in ControlBar — eliminates per-build allocation
- Removed redundant inner ValueListenableBuilder<bool> in ControlsOverlay — was listening to same _autoHide.visible as outer builder
- Verified Phase 2 optimizations working: enableBlur skip, BackdropFilter gating, RepaintBoundary wrapping
- Confirmed no double-BackdropFilter issue — GlassIconButton uses Material+InkWell (no blur layer)

## Task Commits

Each task was committed atomically:

1. **Task 1: DevTools Profiling Baseline + blurEnabled Isolation** - `6ed76b7` (test)
2. **Task 2: Control Bar Fix + Regression Tests** - `fcbbb1e` (perf)

## Files Created/Modified
- `test/perf/control_bar_perf_test.dart` - 8 widget tests: rebuild counts, blurEnabled isolation, Phase 2 verification, AutoHideController throttle
- `lib/ui/player/control_bar.dart` - Static final _borderRadius and _blurFilter, removed inline allocation in build()
- `lib/ui/player/controls_overlay.dart` - Single VLB replaces redundant double-listener pattern

## Decisions Made
- Cache ImageFilter.blur as static final — it's immutable and expensive to create per-build
- Cache BorderRadius as static final — created once with Tokens.controlBarRadius
- Remove inner VLB — outer builder already gets isVisible, can pass directly to ControlBar
- No RepaintBoundary addition needed — ControlBar already wraps content in RepaintBoundary (both paths)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test/widgets using test() instead of testWidgets()**
- **Found during:** Task 1
- **Issue:** Initial test file used `test()` with `(tester) async` callback — should be `testWidgets()`
- **Fix:** Changed all 8 test functions from `test(` to `testWidgets(`
- **Files modified:** test/perf/control_bar_perf_test.dart
- **Verification:** All 8 tests pass
- **Committed in:** 6ed76b7

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor test syntax fix. No scope creep.

## Issues Encountered
None — plan executed smoothly.

## User Setup Required
None — no external service configuration required.

## Known Stubs
None — no stubs introduced.

## Threat Flags
None — no new security surface introduced. Performance optimization only.

## Next Phase Readiness
- Control bar profiling baseline established for future regression detection
- Phase 2 BackdropFilter optimizations verified working
- Ready for Plan 03 (remaining performance work)

---
*Phase: 03-performance-optimization*
*Completed: 2026-05-29*

## Self-Check: PASSED

- [x] test/perf/control_bar_perf_test.dart exists (8 tests, 323 lines)
- [x] lib/ui/player/control_bar.dart exists (static final caching applied)
- [x] lib/ui/player/controls_overlay.dart exists (VLB dedup applied)
- [x] Commit 6ed76b7 exists (Task 1: profiling test suite)
- [x] Commit fcbbb1e exists (Task 2: control bar optimizations)
- [x] 30/30 relevant tests pass (8 perf + 12 control_bar + 10 controls_overlay)
- [x] dart analyze clean on all modified files
- [x] No modifications to STATE.md or ROADMAP.md
