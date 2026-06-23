---
phase: 01-window-management
plan: 01
subsystem: window
tags: [win32, method-channel, event-channel, window-management, value-notifier]

requires: []
provides:
  - "C++ WindowChannel handler for 7 window commands via MethodChannel"
  - "EventChannel streaming 5 event types from C++ to Dart"
  - "Dart WindowService with ValueNotifier state (isFullscreen, isAlwaysOnTop, isMaximized, windowSize)"
  - "PlayerServices integration with WindowService lifecycle"
affects: [01-02, 01-03]

tech-stack:
  added: []
  patterns: [MethodChannel command dispatch, EventChannel event streaming, ValueNotifier window state]

key-files:
  created:
    - windows/runner/window_channel.h
    - windows/runner/window_channel.cpp
    - lib/kernel/bridge/window_service.dart
  modified:
    - windows/runner/flutter_window.h
    - windows/runner/flutter_window.cpp
    - windows/runner/CMakeLists.txt
    - lib/features/player/player_services.dart

key-decisions:
  - "WindowChannel owns MethodChannel/EventChannel as unique_ptr members (not local variables)"
  - "FlutterWindow stores PluginRegistrarWindows to keep messenger alive"
  - "Fullscreen saves/restores window rect and style for clean transitions"

patterns-established:
  - "C++ MethodChannel handler pattern: Register + HandleMethodCall + SendEvent"
  - "Dart WindowService _guardedCall pattern for disposed-safe async calls"
  - "FlutterWindow MessageHandler dispatch: frameless handling, then EventChannel events, then base class"

requirements-completed: [WIN-01, PLATFORM-01]

duration: 10min
completed: 2026-05-28
---

# Phase 1 Plan 01: C++ WindowChannel + Dart WindowService Summary

**Win32 MethodChannel bridge with 7 window commands and EventChannel event streaming, Dart WindowService with ValueNotifier state**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-28T19:56:07Z
- **Completed:** 2026-05-28T20:05:36Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- C++ WindowChannel handles 7 commands: setFullscreen, setAlwaysOnTop, setSize, setPosition, setMinSize, setFrameless, getTitleBarBounds
- EventChannel streams 5 event types from C++ to Dart: onResize, onFullscreenChange, onClose, onMinimize, onMove
- Dart WindowService with 4 ValueNotifier fields for reactive UI binding
- Fullscreen implementation saves/restores window rect and style
- FlutterWindow dispatches WM_NCCALCSIZE, WM_NCHITTEST, WM_SIZE, WM_CLOSE to WindowChannel

## Task Commits

Each task was committed atomically:

1. **Task 1: C++ WindowChannel with MethodChannel + EventChannel** - `42de53e` (feat)
2. **Task 2: Dart WindowService with ValueNotifier state** - `c3a70da` (feat)

## Files Created/Modified
- `windows/runner/window_channel.h` - WindowChannel class declaration with 7 command handlers and event delegates
- `windows/runner/window_channel.cpp` - MethodChannel/EventChannel registration, Win32 API calls, hit-testing
- `windows/runner/flutter_window.h` - Added WindowChannel member and PluginRegistrarWindows storage
- `windows/runner/flutter_window.cpp` - Register handler in OnCreate, dispatch messages in MessageHandler
- `windows/runner/CMakeLists.txt` - Added window_channel.cpp to build sources
- `lib/kernel/bridge/window_service.dart` - WindowService with ValueNotifier state and _guardedCall pattern
- `lib/features/player/player_services.dart` - WindowService lifecycle integration

## Decisions Made
- WindowChannel owns MethodChannel/EventChannel as unique_ptr members to prevent destruction after Register returns
- FlutterWindow stores PluginRegistrarWindows to keep the BinaryMessenger alive for channel lifetime
- Fullscreen uses save/restore pattern (save rect + style before covering monitor, restore on exit)
- WM_NCHITTEST delegates to WindowChannel::HitTest for 8-direction resize + title bar drag

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed MethodChannel/EventChannel lifetime**
- **Found during:** Task 1
- **Issue:** MethodChannel and EventChannel were created as local variables in Register() and destroyed at scope exit
- **Fix:** Stored as unique_ptr members of WindowChannel class
- **Files modified:** windows/runner/window_channel.h, windows/runner/window_channel.cpp
- **Verification:** Code review confirms channels outlive the handler
- **Committed in:** 42de53e

**2. [Rule 3 - Blocking] Fixed PluginRegistrarWindows lifetime**
- **Found during:** Task 1
- **Issue:** flutter_controller_->engine() returns FlutterEngine*, not PluginRegistrarWindows*. Registrar created as temporary would destroy messenger.
- **Fix:** FlutterWindow stores PluginRegistrarWindows as member, initialized via GetRegistrarForPlugin in OnCreate
- **Files modified:** windows/runner/flutter_window.h, windows/runner/flutter_window.cpp
- **Verification:** Code review confirms registrar outlives WindowChannel
- **Committed in:** 42de53e

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes necessary for correct channel lifetime. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all commands and events are fully implemented.

## Next Phase Readiness
- WindowChannel and WindowService provide the platform bridge for all window operations
- Plan 02 (frameless window + WM_NCHITTEST) can build on the is_frameless() state and HitTest delegate
- Plan 03 (CustomTitleBar) can bind to WindowService ValueNotifiers

---
*Phase: 01-window-management*
*Completed: 2026-05-28*
