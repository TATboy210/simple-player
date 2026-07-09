---
phase: 02-command-queue-recovery
plan: 03
subsystem: bridge
tags: [fullscreen, window-service, migration, feature-flag, adapter-injection]

# Dependency graph
requires:
  - phase: 01-architecture-core-models
    provides: FullscreenAdapter abstract, FullscreenSnapshot, FullscreenEvent
  - phase: 02-command-queue-recovery
    plan: 02
    provides: DesktopFullscreenAdapter, DesktopFullscreenDriver
provides:
  - WindowService delegates fullscreen to FullscreenAdapter
  - Compile-time USE_NEW_FULLSCREEN feature flag
  - FullscreenAdapter event → WindowService.mode synchronization
affects: [player-screen, keyboard-handler]

# Tech tracking
tech-stack:
  added: []
  patterns: [adapter-event-to-mode-sync, compile-time-feature-flag]

key-files:
  created: []
  modified:
    - lib/kernel/bridge/window_service.dart
    - lib/main.dart

key-decisions:
  - "FullscreenAdapter event subscription in WindowService constructor (not init) — ensures binding before any setMode call"
  - "Feature flag in main.dart (not app.dart) — matches actual WindowService construction site"
  - "P0-4 init order preserved: Driver → Adapter → WindowService"

patterns-established:
  - "Adapter event → service mode sync: Entered/Left/ForcedChange events map to WindowMode values"
  - "Compile-time --dart-define feature flag: defaultValue=false, explicit opt-in for new implementation"

requirements-completed: [ARCH-03]

coverage:
  - id: D1
    description: "WindowService.setMode(fullscreen) delegates to FullscreenAdapter.setFullscreen(true)"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/window_service.dart#setMode
        status: pass
    human_judgment: false
  - id: D2
    description: "WindowService.setMode(windowed) during fullscreen delegates to FullscreenAdapter.setFullscreen(false)"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/window_service.dart#setMode
        status: pass
    human_judgment: false
  - id: D3
    description: "Fallback to legacy fullScreenWindow when _fullscreenAdapter is null"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/window_service.dart#setMode
        status: pass
    human_judgment: false
  - id: D4
    description: "FullscreenAdapter events sync to WindowService.mode (Entered→fullscreen, Left→windowed)"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/window_service.dart#_onFullscreenEvent
        status: pass
    human_judgment: false
  - id: D5
    description: "Compile-time --dart-define=USE_NEW_FULLSCREEN=true feature flag (D-27)"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/main.dart#_useNewFullscreen
        status: pass
    human_judgment: false
  - id: D6
    description: "P0-4 init order: Driver → Adapter → WindowService (no circular deps)"
    requirement: ARCH-03
    verification:
      - kind: analysis
        ref: lib/main.dart#main
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-09
status: complete
---

# Phase 2 Plan 03: WindowService Migration Summary

**WindowService fullscreen logic migrated to FullscreenAdapter with compile-time feature flag — 7 existing tests passing**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-09T22:48:00Z
- **Completed:** 2026-07-09T22:56:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- WindowService.setMode(fullscreen) delegates to FullscreenAdapter.setFullscreen(true) when adapter is available (D-28)
- WindowService.setMode(windowed) during fullscreen delegates to FullscreenAdapter.setFullscreen(false)
- Legacy fullscreen_window path preserved as fallback when _fullscreenAdapter is null
- FullscreenAdapter events (Entered/Left/ForcedChange) sync to WindowService.mode via _onFullscreenEvent handler
- Compile-time `--dart-define=USE_NEW_FULLSCREEN=true` feature flag controls adapter injection (D-27)
- P0-4 initialization order: DesktopFullscreenDriver → DesktopFullscreenAdapter → WindowService (no circular deps)
- Feature flag in main.dart matches actual WindowService construction site (D-31: flag only at adapter level)
- FullscreenAdapter disposed in WindowService.dispose()

## Task Commits

1. **Task 1: WindowService fullscreen migration** - `c6ac289` (feat)
2. **Task 2: FullscreenAdapter injection + feature flag** - `14c4bd2` (feat)

## Files Created/Modified

- `lib/kernel/bridge/window_service.dart` — FullscreenAdapter field, constructor param, event sync, setMode delegation (62 lines added)
- `lib/main.dart` — USE_NEW_FULLSCREEN flag, DesktopFullscreenDriver/Adapter creation, injection into WindowService (25 lines added)

## Decisions Made

- **Event subscription in constructor:** FullscreenAdapter.events.listen in constructor body, not init(). Ensures subscription exists before any setMode call could fire events.
- **Feature flag in main.dart:** WindowService is constructed in main.dart, not app.dart. Flag lives where construction happens.
- **ForcedChange handling:** OS external fullscreen changes (e.g., system hotkey) sync ForcedChange events to mode, mapping actualMode to WindowMode.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

---

**Total deviations:** 0
**Impact on plan:** None.

## Issues Encountered

None — implementation was straightforward with no blocking issues.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None — both paths (new adapter and legacy fallback) are fully functional.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-02-04 accepted | main.dart | Feature flag is compile-time only, runtime bypass not possible. Security depends on build pipeline. |

## Self-Check: PASSED

- [x] `lib/kernel/bridge/window_service.dart` modified (FullscreenAdapter integration)
- [x] `lib/main.dart` modified (feature flag + injection)
- [x] Commit `c6ac289` found in git log
- [x] Commit `14c4bd2` found in git log
- [x] `flutter analyze` zero warnings on both modified files
- [x] 7 existing WindowService tests pass (no regressions)
- [x] FullscreenAdapter event → mode sync code present
- [x] Legacy fallback path preserved when adapter is null

---

*Phase: 02-command-queue-recovery*
*Completed: 2026-07-09*
