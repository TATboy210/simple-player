---
phase: 01-fullscreen-simplification
plan: 01
subsystem: bridge
tags: [fullscreen, win32-ffi, sealed-class, platform-detection, refactor]

requires: []
provides:
  - WindowService._createDriver() inlined platform detection
  - FullscreenResult sealed class for type-safe error handling
  - Dead DesktopFullscreenDriver + DesktopFullscreenDriverFactory removed
  - main.dart simplified (no factory, no driver injection)
affects: [01-02, 01-03, fullscreen, window-service]

tech-stack:
  added: []
  patterns: [static-factory-method, sealed-class-error-handling]

key-files:
  created: []
  modified:
    - lib/kernel/bridge/window_service.dart
    - lib/kernel/bridge/fullscreen_driver.dart
    - lib/main.dart
    - test/unit/kernel/bridge/window_service_test.dart

key-decisions:
  - "Renamed constructor param fullscreenDriver -> driver for brevity"
  - "HWND invalid on Windows returns null (no window_manager fallback)"
  - "Constructor param renamed to driver (not fullscreenDriver) for consistency with test injection pattern"

patterns-established:
  - "Static _createDriver() for platform-specific driver creation (no factory class)"
  - "FullscreenResult sealed class for type-safe fullscreen operation results"

requirements-completed: [FULL-01, FULL-02]

coverage:
  - id: D1
    description: "DesktopFullscreenDriver and DesktopFullscreenDriverFactory files deleted"
    requirement: FULL-01
    verification:
      - kind: unit
        ref: "grep -r desktop_fullscreen_driver lib/ returns no matches"
        status: pass
    human_judgment: false
  - id: D2
    description: "WindowService._createDriver() inlines platform detection"
    requirement: FULL-01
    verification:
      - kind: unit
        ref: "test/unit/kernel/bridge/window_service_test.dart#driver creation"
        status: pass
    human_judgment: false
  - id: D3
    description: "FullscreenResult sealed class added for type-safe error handling"
    requirement: FULL-01
    verification:
      - kind: unit
        ref: "test/unit/kernel/bridge/window_service_test.dart#FullscreenResult sealed class"
        status: pass
    human_judgment: false
  - id: D4
    description: "main.dart simplified — no factory import, no driver injection"
    requirement: FULL-01
    verification:
      - kind: unit
        ref: "flutter analyze lib/main.dart — no issues"
        status: pass
    human_judgment: false
  - id: D5
    description: "flutter_fullscreen evaluation document exists"
    requirement: FULL-02
    verification:
      - kind: other
        ref: ".planning/research/flutter-fullscreen-evaluation.md exists"
        status: pass
    human_judgment: false

duration: 13min
completed: 2026-07-12
status: complete
---

# Phase 1 Plan 01: Fullscreen Code Simplification Summary

**Deleted dead DesktopFullscreenDriver + factory, inlined platform detection into WindowService._createDriver(), added FullscreenResult sealed class for type-safe error handling**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-12T15:18:43Z
- **Completed:** 2026-07-12T15:31:46Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Deleted `DesktopFullscreenDriver` (window_manager fallback) and `DesktopFullscreenDriverFactory` (platform detection factory) — 2 unnecessary abstraction layers removed
- `WindowService._createDriver()` now inlines platform detection: Windows uses Win32 FFI with HWND validation, macOS/Linux use fullscreen_window plugins
- Added `FullscreenResult` sealed class (`FullscreenSuccess`/`FullscreenFailure`) for type-safe error handling in `_handleEnter`/`_handleLeave`
- `main.dart` simplified: no factory import, no driver injection — `WindowService()` handles everything internally
- All existing tests pass (15 WindowService tests, 76 platform tests)

## Task Commits

1. **Task 1: Delete dead driver files + inline platform detection** - `a0cd70f` (refactor)
2. **Task 2: Update factory tests + add WindowService init tests** - `b72f823` (test)

## Files Created/Modified

- `lib/kernel/bridge/desktop_fullscreen_driver.dart` - DELETED (window_manager fallback driver)
- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` - DELETED (platform detection factory)
- `lib/kernel/bridge/window_service.dart` - Inlined `_createDriver()`, renamed constructor param, `FullscreenResult` return types
- `lib/kernel/bridge/fullscreen_driver.dart` - Added `FullscreenResult` sealed class with `FullscreenSuccess`/`FullscreenFailure`
- `lib/main.dart` - Removed factory import and driver injection, simplified to `WindowService()`
- `test/platform/fullscreen_driver_factory_test.dart` - DELETED (tested deleted factory)
- `test/unit/kernel/bridge/window_service_test.dart` - Added 8 new tests (driver creation, FullscreenResult, confirmation chain)

## Decisions Made

- **Renamed constructor param `fullscreenDriver` -> `driver`**: Shorter, matches test injection pattern
- **HWND invalid returns null (no fallback)**: WindowsFullscreenDriver creation fails gracefully when HWND is 0 or invalid, rather than falling back to window_manager
- **`_createDriver()` is static**: Enables test environment detection (HWND=0 returns null) without instance state

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed unnecessary `foundation.dart` import**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `package:flutter/foundation.dart` import in window_service.dart was unnecessary — `material.dart` already provides `debugPrint`
- **Fix:** Removed the redundant import
- **Files modified:** lib/kernel/bridge/window_service.dart
- **Verification:** `flutter analyze` passes with no issues
- **Committed in:** a0cd70f (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minor cleanup — no scope creep.

## Issues Encountered

None — plan executed smoothly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- WindowService is now a direct driver owner with no intermediate layers
- FullscreenResult sealed class provides type-safe error handling foundation for future phases
- Ready for Phase 01-02 (further fullscreen simplification if needed)

---
*Phase: 01-fullscreen-simplification*
*Completed: 2026-07-12*
