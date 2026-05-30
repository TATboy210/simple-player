---
phase: 10-window-optimization
plan: 03
subsystem: window
tags: [window-bootstrap, startup, singleton-injection, geometry-restore]

requires:
  - phase: 10-window-optimization/10-01
    provides: WindowBootstrap design (created in this plan since worktree not merged)
  - phase: 10-window-optimization/10-02
    provides: WindowPersistenceService (worktree not merged, adapted to existing architecture)
provides:
  - WindowBootstrap class for startup geometry restore with multi-monitor bounds check
  - Double WindowService instantiation eliminated via constructor injection
  - Fullscreen flag cleared on startup (D-02 crash safety)
  - Saved window geometry restored before show()
affects: [10-window-optimization, window-management]

tech-stack:
  added: []
  patterns: [constructor-injection for WindowService, PlatformDispatcher for display bounds]

key-files:
  created:
    - lib/kernel/bridge/window_bootstrap.dart
  modified:
    - lib/main.dart
    - lib/app.dart
    - lib/features/player/player_services.dart
    - lib/features/player/player_feature.dart
    - lib/features/player/deferred_player_feature.dart

key-decisions:
  - "WindowBootstrap placed at lib/kernel/bridge/ (not lib/window/) to match existing architecture"
  - "Used PlatformDispatcher.instance.views for display bounds instead of screen_retriever"
  - "windowManager.maximize() for startup maximize restore (simpler than FFI, acceptable at startup)"
  - "SettingsStore.prewarm moved before waitUntilReadyToShow so cached prefs available for load()"

patterns-established:
  - "Constructor injection for WindowService through widget tree (App -> DeferredPlayerFeature -> PlayerFeature -> PlayerServices)"
  - "WindowBootstrap static class for startup-only window operations"

requirements-completed: [WIN-04]

duration: 15min
completed: 2026-05-30
---

# Plan 10-03: Window Startup Wiring Summary

**WindowBootstrap geometry restore on startup + singleton WindowService injection eliminating double instantiation**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-30T10:00:00Z
- **Completed:** 2026-05-30T10:15:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created WindowBootstrap with restoreOrCenter() and clearFullscreenIfSaved() for startup geometry restore
- Wired WindowBootstrap into main.dart waitUntilReadyToShow callback with proper ordering
- Eliminated double WindowService instantiation via constructor injection through widget tree
- All 608 tests passing, dart analyze clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire WindowBootstrap into main.dart startup flow** - `91fde04` (feat)
2. **Task 2: Fix double WindowService — inject singleton through widget tree** - `19d3eca` (fix)

## Files Created/Modified
- `lib/kernel/bridge/window_bootstrap.dart` - Startup geometry restore with multi-monitor bounds check using PlatformDispatcher
- `lib/main.dart` - Restructured startup: prewarm before callback, WindowBootstrap calls before show(), maximize restore after show()
- `lib/app.dart` - Pass _windowService to DeferredPlayerFeature
- `lib/features/player/deferred_player_feature.dart` - Added windowService field, passes to PlayerFeature
- `lib/features/player/player_feature.dart` - Added windowService field, passes to PlayerServices constructor
- `lib/features/player/player_services.dart` - Constructor injection for WindowService, removed internal creation

## Decisions Made
- WindowBootstrap placed at lib/kernel/bridge/ to match existing architecture (worktree's lib/window/ not available on this branch)
- Used PlatformDispatcher.instance.views for display bounds (no screen_retriever dependency)
- windowManager.maximize() for startup maximize restore (simpler than custom FFI, acceptable at startup since custom maximize is mainly for runtime toggle)
- SettingsStore.prewarm moved before waitUntilReadyToShow so load() uses cached prefs

## Deviations from Plan

### Auto-fixed Issues

**1. WindowBootstrap did not exist on branch (wave 1 worktree not merged)**
- **Found during:** Task 1 preparation
- **Issue:** Plan assumed WindowBootstrap was created by 10-01 in a worktree, but worktree changes not merged to fix/window-startup
- **Fix:** Created WindowBootstrap as part of Task 1 based on plan interface specification
- **Files modified:** lib/kernel/bridge/window_bootstrap.dart (created)
- **Verification:** dart analyze clean, 608 tests pass
- **Committed in:** 91fde04 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (missing prerequisite artifact)
**Impact on plan:** WindowBootstrap created inline rather than depending on worktree merge. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Window startup flow complete: geometry restore, fullscreen clear, maximize restore, singleton injection
- Ready for remaining phase 10 plans (if any) or phase transition

---
*Phase: 10-window-optimization*
*Completed: 2026-05-30*
