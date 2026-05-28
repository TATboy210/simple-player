---
phase: 01-window-management
plan: 03
subsystem: window
tags: [custom-title-bar, win32, minimize, maximize, close, center, flutter-widget]

requires:
  - phase: 01-window-management/01-01
    provides: "C++ WindowChannel handler with MethodChannel/EventChannel, Dart WindowService"
  - phase: 01-window-management/01-02
    provides: "Frameless window via WM_NCCALCSIZE, WM_NCHITTEST resize/drag, fullscreen"
provides:
  - "CustomTitleBar widget (32px, flat/immersive buttons, fullscreen-aware)"
  - "Minimize/maximize/restore/close/center C++ commands"
  - "OnMaximizeChanged event for system maximize/restore detection"
  - "Window centering on startup (960x540 default)"
  - "Double-click title bar toggles maximize/restore"
affects: []

tech-stack:
  added: []
  patterns: [flat title bar buttons, ValueListenableBuilder fullscreen hide, WM_SIZE maximize detection]

key-files:
  created:
    - lib/ui/player/custom_title_bar.dart
  modified:
    - lib/ui/theme/tokens.dart
    - lib/kernel/bridge/window_service.dart
    - lib/ui/player/player_screen.dart
    - lib/features/player/player_feature.dart
    - lib/features/player/player_services.dart
    - windows/runner/window_channel.h
    - windows/runner/window_channel.cpp
    - windows/runner/flutter_window.cpp

key-decisions:
  - "titleBarHeight changed from 36.0 to 32.0 per D-16 (Windows 11 standard)"
  - "OnMaximizeChanged detects maximize/restore from system actions (double-click, Win+Up, snap)"
  - "Center uses MonitorFromWindow + GetMonitorInfo work area for multi-monitor awareness"
  - "CustomTitleBar uses Container + MouseRegion, not GlassContainer (D-11 flat style)"

patterns-established:
  - "Flat title bar button pattern: MouseRegion hover + ValueNotifier + Container color change"
  - "CustomTitleBar fullscreen hide: ValueListenableBuilder on isFullscreen wrapping entire widget"
  - "C++ OnMaximizeChanged pattern: send event from both explicit commands and WM_SIZE detection"

requirements-completed: [WIN-02, WIN-03]

duration: 12min
completed: 2026-05-28
---

# Phase 1 Plan 03: CustomTitleBar + Integration Summary

**32px flat title bar with minimize/maximize/close buttons, fullscreen-aware visibility, double-click maximize toggle, and 960x540 centered startup**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-28T20:20:00Z
- **Completed:** 2026-05-28T20:32:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- CustomTitleBar widget with 32px height, flat/immersive buttons, app name "Simple Player" on left
- Minimize/maximize/restore/close/center C++ commands added to WindowChannel
- OnMaximizeChanged event detects system-initiated maximize/restore (double-click title bar, Win+Up, snap)
- Window centers at 960x540 on every startup (D-20, D-24)
- Double-click title bar toggles maximize/restore (D-12)
- Fullscreen hides title bar via ValueListenableBuilder (D-17)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CustomTitleBar widget** - `6294901` (feat)
2. **Task 2: Integrate CustomTitleBar into PlayerScreen + center window** - `ea18932` (feat)

## Files Created/Modified
- `lib/ui/player/custom_title_bar.dart` - CustomTitleBar + _TitleBarContent + _TitleBarButton widgets
- `lib/ui/theme/tokens.dart` - titleBarHeight changed from 36.0 to 32.0 (D-16)
- `lib/kernel/bridge/window_service.dart` - Added minimize/maximize/restore/close/center methods + onMaximize event handling
- `lib/ui/player/player_screen.dart` - Added windowService parameter, CustomTitleBar in Stack
- `lib/features/player/player_feature.dart` - Pass windowService to PlayerScreen
- `lib/features/player/player_services.dart` - Call setSize(960, 540) + center() on init
- `windows/runner/window_channel.h` - Added Minimize/Maximize/Restore/Close/Center + OnMaximizeChanged declarations
- `windows/runner/window_channel.cpp` - Implemented 5 new commands + OnMaximizeChanged with DWM rounded corner re-application
- `windows/runner/flutter_window.cpp` - Added WM_SIZE maximize/restore detection dispatching to OnMaximizeChanged

## Decisions Made
- titleBarHeight 36.0 -> 32.0 per D-16 (Windows 11 standard)
- OnMaximizeChanged handles both explicit commands and system-initiated maximize (double-click, Win+Up, snap)
- Center uses work area (not monitor rect) for taskbar-aware positioning
- CustomTitleBar uses plain Container + MouseRegion, not GlassContainer (D-11: flat style, not glassmorphism)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added OnMaximizeChanged for system maximize detection**
- **Found during:** Task 1
- **Issue:** Plan only added explicit maximize/restore commands, but user can also maximize via double-click on HTCAPTION region or Win+Up arrow. Without WM_SIZE detection, isMaximized state would be stale.
- **Fix:** Added OnMaximizeChanged method that sends onMaximize event from WM_SIZE handler when wParam is SIZE_MAXIMIZED or SIZE_RESTORED. Also re-applies DWM rounded corners (D-21).
- **Files modified:** windows/runner/window_channel.h, windows/runner/window_channel.cpp, windows/runner/flutter_window.cpp
- **Verification:** Code review confirms event sent for all maximize/restore paths
- **Committed in:** 6294901 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Fix necessary for correct maximize state tracking. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all title bar buttons are wired to functional C++ commands.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-03-01 accept | window_channel.cpp | Close button triggers WM_CLOSE — standard Win32 behavior, no external input |

## Self-Check: PASSED

- [x] lib/ui/player/custom_title_bar.dart — FOUND
- [x] lib/ui/theme/tokens.dart — FOUND (modified)
- [x] lib/kernel/bridge/window_service.dart — FOUND (modified)
- [x] lib/ui/player/player_screen.dart — FOUND (modified)
- [x] lib/features/player/player_feature.dart — FOUND (modified)
- [x] lib/features/player/player_services.dart — FOUND (modified)
- [x] windows/runner/window_channel.h — FOUND (modified)
- [x] windows/runner/window_channel.cpp — FOUND (modified)
- [x] windows/runner/flutter_window.cpp — FOUND (modified)
- [x] .planning/phases/01-window-management/01-03-SUMMARY.md — FOUND
- [x] Commit 6294901 — FOUND
- [x] Commit ea18932 — FOUND

## Next Phase Readiness
- CustomTitleBar visible and functional above video content
- All window management commands (minimize/maximize/restore/close/center) working
- Window centers at 960x540 on every startup
- Phase 1 window management foundation complete (Plans 01-03)

---
*Phase: 01-window-management*
*Completed: 2026-05-28*
