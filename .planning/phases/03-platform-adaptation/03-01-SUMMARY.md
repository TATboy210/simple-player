---
phase: 03-platform-adaptation
plan: 01
subsystem: bridge
tags: [win32, ffi, fullscreen, user32, dart-ffi]

requires:
  - phase: 02-command-queue-recovery
    provides: FullscreenDriver interface, DesktopFullscreenDriver pattern
  - phase: 01-architecture-core-models
    provides: FullscreenCapability model
provides:
  - Win32FullscreenApi static FFI bindings (20+ user32.dll functions)
  - WindowsFullscreenDriver implementing FullscreenDriver interface
  - Win32FullscreenApiWrapper for testability
  - 26 unit tests covering all driver paths
affects: [03-02, 03-03, 03-04]

tech-stack:
  added: []
  patterns: [Win32 FFI static utility class, injectable API wrapper for mock testing]

key-files:
  created:
    - lib/kernel/bridge/win32/win32_fullscreen_ffi.dart
    - lib/kernel/bridge/platform/windows_fullscreen_driver.dart
    - test/platform/windows_fullscreen_driver_test.dart
  modified: []

key-decisions:
  - "Win32 constants exported as public (not private) so WindowsFullscreenDriver can reference them"
  - "Win32FullscreenApiWrapper pattern: instance wrapper over static FFI for testability"
  - "Focus recovery only when window visible AND not iconic (D-P07 safety guard)"

patterns-established:
  - "FFI static utility class + instance adapter wrapper for testability"
  - "Mock API injection via constructor for Win32 FFI drivers"

requirements-completed: [PLAT-01]

coverage:
  - id: D1
    description: "Win32FullscreenApi FFI bindings — 20+ user32.dll function wrappers"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/win32/win32_fullscreen_ffi.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "WindowsFullscreenDriver — enterFullscreen with WS_THICKFRAME stripping"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "test/platform/windows_fullscreen_driver_test.dart#strips WS_THICKFRAME and WS_CAPTION"
        status: pass
    human_judgment: false
  - id: D3
    description: "WindowsFullscreenDriver — leaveFullscreen with TopMost cleanup and focus recovery"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "test/platform/windows_fullscreen_driver_test.dart#clears TopMost via HWND_NOTOPMOST"
        status: pass
    human_judgment: false
  - id: D4
    description: "WindowsFullscreenDriver — queryFullscreen based on IsZoomed"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "test/platform/windows_fullscreen_driver_test.dart#uses IsZoomed for real state query"
        status: pass
    human_judgment: false
  - id: D5
    description: "WindowsFullscreenDriver — focus recovery safety guard (visible + not iconic)"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "test/platform/windows_fullscreen_driver_test.dart#skips focus recovery when window is not visible"
        status: pass
    human_judgment: false
  - id: D6
    description: "FullscreenCapability with multi-display support and platform notes"
    requirement: PLAT-01
    verification:
      - kind: unit
        ref: "test/platform/windows_fullscreen_driver_test.dart#returns Windows-specific capability"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-07-10
status: complete
---

# Phase 03 Plan 01: Windows Fullscreen Driver Summary

**Win32 FFI fullscreen driver with WS_THICKFRAME stripping, focus recovery, TopMost cleanup, and 26 unit tests**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-10
- **Completed:** 2026-07-10
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Win32FullscreenApi: 20+ user32.dll FFI bindings as static utility class
- WindowsFullscreenDriver: FullscreenDriver implementation with WS_THICKFRAME removal (D-P06), focus recovery (D-P07), TopMost cleanup (D-P08)
- Win32FullscreenApiWrapper: injectable mock pattern for testability
- 26 unit tests covering enter/leave/query/capabilities/window-management paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Win32 FFI bindings** - `56d05df` (feat)
2. **Task 2: WindowsFullscreenDriver** - `749c86f` (feat)
3. **Task 3: Unit tests** - `0dfdb1c` (test)

## Files Created/Modified
- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` - Win32FullscreenApi static FFI bindings (20+ functions, public structs and constants)
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` - WindowsFullscreenDriver + Win32FullscreenApiWrapper
- `test/platform/windows_fullscreen_driver_test.dart` - 26 unit tests with MockWin32Api

## Decisions Made
- Win32 constants exported as public (not private) so WindowsFullscreenDriver can reference them without re-declaring
- Win32FullscreenApiWrapper instance wrapper over static FFI methods enables mock injection for testing
- Focus recovery safety guard: only execute when window is visible AND not iconic (D-P07)
- Window placement memory management: driver owns allocation/free lifecycle for _savedPlacement pointer

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] dart:ffi Size type conflicts with dart:ui Size**
- **Found during:** Task 2 (WindowsFullscreenDriver)
- **Issue:** Both dart:ffi and dart:ui export `Size` type, causing ambiguous import
- **Fix:** `import 'dart:ffi' hide Size` to resolve ambiguity
- **Files modified:** lib/kernel/bridge/platform/windows_fullscreen_driver.dart
- **Verification:** flutter analyze passes with no issues
- **Committed in:** 749c86f

**2. [Rule 3 - Blocking] debugPrint requires flutter/foundation.dart import**
- **Found during:** Task 2 (WindowsFullscreenDriver)
- **Issue:** debugPrint is from package:flutter/foundation.dart, not dart:ui
- **Fix:** Added `import 'package:flutter/foundation.dart'`
- **Files modified:** lib/kernel/bridge/platform/windows_fullscreen_driver.dart
- **Verification:** flutter analyze passes
- **Committed in:** 749c86f

**3. [Rule 1 - Bug] MockWin32Api double-free in setWindowPlacement**
- **Found during:** Task 3 (Unit tests)
- **Issue:** Mock freed pointer in setWindowPlacement, but driver also frees via _freeSavedPlacement()
- **Fix:** Removed calloc.free from mock's setWindowPlacement — driver owns memory lifecycle
- **Files modified:** test/platform/windows_fullscreen_driver_test.dart
- **Verification:** All 26 tests pass
- **Committed in:** 0dfdb1c

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 bug)
**Impact on plan:** All auto-fixes necessary for correctness. No scope creep.

## Issues Encountered
- Win32 constants initially declared as private (underscore prefix) — analyzer flagged unused_element warnings since the driver didn't exist yet. Resolved by making constants public for driver consumption.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- WindowsFullscreenDriver complete, ready for factory integration (03-04)
- macOS and Linux drivers can follow the same injectable-wrapper pattern
- Win32FullscreenApi FFI bindings shared across all Windows bridge code

---
*Phase: 03-platform-adaptation*
*Completed: 2026-07-10*
