---
phase: 01-window-management
plan: 02
subsystem: window
tags: [win32, frameless, wm-nccalcsize, wm-nchittest, fullscreen, snap-layouts]

requires:
  - phase: 01-window-management/01-01
    provides: "C++ WindowChannel handler with MethodChannel/EventChannel, Dart WindowService"
provides:
  - "Frameless window via WM_NCCALCSIZE with 1px top inset for resize cursor"
  - "8-direction resize edges (8px) and title bar drag (32px) via WM_NCHITTEST"
  - "Fullscreen covering entire monitor with save/restore rect and style"
  - "WM_GETMINMAXINFO minimum window size enforcement (640x360)"
  - "WS_THICKFRAME preserved for Windows snap layout support"
  - "Rounded corners re-applied after fullscreen transitions (D-21)"
affects: [01-03]

tech-stack:
  added: []
  patterns: [WM_NCCALCSIZE frameless, WM_NCHITTEST 8-direction resize, MINMAXINFO min size]

key-files:
  created: []
  modified:
    - windows/runner/window_channel.h
    - windows/runner/window_channel.cpp
    - windows/runner/flutter_window.cpp

key-decisions:
  - "HandleNcCalcSize returns -1 when not handled, 0 when handled (matches Win32 convention)"
  - "WM_GETMINMAXINFO always active (not just frameless) to enforce min size from any mode"
  - "Fullscreen re-applies DWMWCP_ROUND directly via DwmSetWindowAttribute (not via ApplyRoundedCorners helper)"

patterns-established:
  - "HandleNcCalcSize pattern: return -1 for not-handled, 0 for handled"
  - "OnGetMinMaxInfo pattern: use stored min_width_/min_height_ with fallback to defaults"

requirements-completed: [WIN-01, WIN-03, PLATFORM-01]

duration: 8min
completed: 2026-05-28
---

# Phase 1 Plan 02: Frameless Window + WM_NCHITTEST Summary

**WM_NCCALCSIZE frameless with 8-direction resize edges, title bar drag, fullscreen with save/restore, and minimum size enforcement via WM_GETMINMAXINFO**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-28T20:07:00Z
- **Completed:** 2026-05-28T20:15:44Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Frameless window via WM_NCCALCSIZE with 1px top inset preserving WS_THICKFRAME for snap layouts
- 8-direction resize edges (8px) and title bar drag region (32px) via WM_NCHITTEST
- Fullscreen covering entire monitor with save/restore of window rect and style
- Minimum window size enforcement (640x360) via WM_GETMINMAXINFO
- Rounded corners re-applied after fullscreen transitions (D-21)
- SetFrameless properly removes WS_CAPTION when entering frameless mode

## Task Commits

Each task was committed atomically:

1. **Task 1: WM_NCCALCSIZE/WM_NCHITTEST/WM_GETMINMAXINFO in WindowChannel** - `8b9df1c` (feat)
2. **Task 2: Wire message handlers into FlutterWindow** - `2a5b1b0` (feat)

## Files Created/Modified
- `windows/runner/window_channel.h` - Added HandleNcCalcSize and OnGetMinMaxInfo declarations
- `windows/runner/window_channel.cpp` - Added HandleNcCalcSize, OnGetMinMaxInfo methods; fixed SetFrameless WS_CAPTION removal; added DWM rounded corner re-application after fullscreen
- `windows/runner/flutter_window.cpp` - Replaced inline WM_NCCALCSIZE with HandleNcCalcSize delegate; added WM_GETMINMAXINFO case

## Decisions Made
- HandleNcCalcSize returns -1 when not handled (not frameless or wParam != TRUE), 0 when handled — matches Win32 convention for NCCALCSIZE
- WM_GETMINMAXINFO always active (not gated by is_frameless) to enforce minimum size from any window mode
- Fullscreen re-applies DWMWCP_ROUND directly via DwmSetWindowAttribute since ApplyRoundedCorners is a file-static function in win32_window.cpp

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added DWM macros to window_channel.cpp**
- **Found during:** Task 1
- **Issue:** DWMWA_WINDOW_CORNER_PREFERENCE and DWMWCP_ROUND macros only defined in win32_window.cpp, not available in window_channel.cpp for fullscreen rounded corner re-application
- **Fix:** Added #ifndef guarded macro definitions to window_channel.cpp
- **Files modified:** windows/runner/window_channel.cpp
- **Verification:** Macros present in file
- **Committed in:** 8b9df1c (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix necessary for compilation. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all frameless, resize, fullscreen, and min size behaviors are fully implemented.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-02-01 accept | window_channel.cpp | WM_NCHITTEST coordinate manipulation — Win32 messages are OS-level, not user-input |
| threat_flag: T-02-02 accept | window_channel.cpp | SetWindowLongPtr style changes — only the running process modifies its own window style |

## Next Phase Readiness
- Frameless window with resize/drag ready for CustomTitleBar integration (Plan 03)
- Fullscreen toggle works from both frameless and normal modes
- Snap layouts preserved via WS_THICKFRAME

## Self-Check: PASSED

- [x] windows/runner/window_channel.h — FOUND
- [x] windows/runner/window_channel.cpp — FOUND
- [x] windows/runner/flutter_window.cpp — FOUND (modified, not new)
- [x] .planning/phases/01-window-management/01-02-SUMMARY.md — FOUND
- [x] Commit 8b9df1c — FOUND
- [x] Commit 2a5b1b0 — FOUND

---
*Phase: 01-window-management*
*Completed: 2026-05-28*
