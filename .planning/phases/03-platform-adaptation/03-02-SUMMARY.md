---
phase: 03-platform-adaptation
plan: 02
subsystem: platform
tags: [macos, nswindow, fullscreen, delegate, method-channel, plugin]

# Dependency graph
requires:
  - phase: 03-platform-adaptation
    provides: FullscreenDriver interface, DesktopFullscreenAdapter three-tier confirmation
  - phase: 02-command-queue-recovery
    provides: FullscreenDriver interface, DesktopFullscreenAdapter, command queue
provides:
  - fullscreen_window macOS plugin NSWindowDelegate callback support
  - MacosFullscreenDriver implementation using native macOS fullscreen animation
  - onFullScreenChanged stream for native callback bridging
  - isFullScreen() query via NSWindow styleMask check
affects: [03-platform-adaptation, 03-03-linux-fullscreen-driver, 03-04-driver-factory]

# Tech tracking
tech-stack:
  added: [NSWindowDelegate, MethodChannel callback handler, StreamController broadcast]
  patterns: [plugin delegate callback pattern, native callback to Dart stream bridging]

key-files:
  created:
    - lib/kernel/bridge/platform/macos_fullscreen_driver.dart
    - test/platform/macos_fullscreen_driver_test.dart
  modified:
    - packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.h
    - packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.m
    - packages/fullscreen_window/lib/fullscreen_window_method_channel.dart
    - packages/fullscreen_window/lib/fullscreen_window_platform_interface.dart

key-decisions:
  - "MethodChannel callback pattern: ObjC delegate -> MethodChannel invokeMethod -> Dart MethodCallHandler -> StreamController -> onFullScreenChanged stream"
  - "Double exception protection on queryFullscreen: plugin.isFullScreen() fallback to wm.isFullScreen() with both wrapped in try/catch"
  - "Delegate set in registerWithRegistrar with lazy fallback: if mainWindow is nil at registration time, re-set delegate on first setFullScreen call"

patterns-established:
  - "Plugin delegate callback pattern: ObjC NSWindowDelegate -> MethodChannel -> Dart StreamController.broadcast -> consumer stream"
  - "Driver callback bridge: driver subscribes to plugin stream, forwards to onNativeStateChanged callback for Adapter"

requirements-completed: [PLAT-02]

# Coverage metadata
coverage:
  - id: D1
    description: "fullscreen_window macOS plugin NSWindowDelegate support (windowDidEnterFullScreen/windowDidExitFullScreen callbacks)"
    requirement: PLAT-02
    verification:
      - kind: unit
        ref: "packages/fullscreen_window (flutter analyze — no issues)"
        status: pass
    human_judgment: false
  - id: D2
    description: "MacosFullscreenDriver implementation with native macOS fullscreen animation"
    requirement: PLAT-02
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/platform/macos_fullscreen_driver.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "MacosFullscreenDriver unit tests covering plugin interaction, callback bridge, capabilities, and lifecycle"
    requirement: PLAT-02
    verification:
      - kind: unit
        ref: "flutter test test/platform/macos_fullscreen_driver_test.dart — 15 tests passed"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-07-10
status: complete
---

# Phase 3 Plan 2: macOS Native Fullscreen Driver Summary

**macOS native fullscreen driver with NSWindowDelegate callback confirmation — fullscreen_window plugin extended with delegate callbacks, MacosFullscreenDriver implemented with 15 unit tests**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-10
- **Completed:** 2026-07-10
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Extended fullscreen_window macOS plugin with NSWindowDelegate protocol for fullscreen animation completion callbacks
- Implemented MacosFullscreenDriver using plugin's native toggleFullScreen animation with delegate callback confirmation
- Added onFullScreenChanged stream and isFullScreen() query to platform interface
- 15 unit tests covering plugin interaction, callback bridge, capabilities, and lifecycle

## Task Commits

Each task was committed atomically:

1. **Task 1: fullscreen_window macOS plugin NSWindowDelegate callback support** - `0b22e28` (feat)
2. **Task 2: MacosFullscreenDriver implementation + tests** - `554e711` (feat)

## Files Created/Modified
- `packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.h` - Added NSWindowDelegate protocol, channel property
- `packages/fullscreen_window/macos/Classes/FullscreenWindowPlugin.m` - Delegate callbacks (windowDidEnterFullScreen/ExitFullScreen), getFullScreenState method, lazy delegate setup
- `packages/fullscreen_window/lib/fullscreen_window_platform_interface.dart` - Added onFullScreenChanged stream, isFullScreen() query
- `packages/fullscreen_window/lib/fullscreen_window_method_channel.dart` - MethodCallHandler for native callbacks, StreamController broadcast
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` - FullscreenDriver implementation using fullscreen_window plugin + window_manager
- `test/platform/macos_fullscreen_driver_test.dart` - 15 unit tests

## Decisions Made
- **MethodChannel callback pattern:** ObjC delegate -> MethodChannel invokeMethod -> Dart MethodCallHandler -> StreamController.broadcast -> onFullScreenChanged stream. This is the standard Flutter plugin callback pattern, no EventChannel needed.
- **Double exception protection:** queryFullscreen catches plugin.isFullScreen() failure and falls back to wm.isFullScreen(), which is also wrapped in try/catch returning false. Both plugin and window_manager can fail in edge cases.
- **Lazy delegate setup:** NSWindow.delegate is set in registerWithRegistrar, but mainWindow may be nil at that time. Delegate is re-set on first setFullScreen call as fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Double exception protection on queryFullscreen fallback**
- **Found during:** Task 2 (MacosFullscreenDriver test)
- **Issue:** When plugin.isFullScreen() throws, fallback to wm.isFullScreen() also throws MissingPluginException in test environment
- **Fix:** Added try/catch around the window_manager fallback in queryFullscreen(), returning false if both fail
- **Files modified:** lib/kernel/bridge/platform/macos_fullscreen_driver.dart
- **Verification:** All 15 tests pass including "falls back to window_manager when plugin throws"
- **Committed in:** 554e711 (Task 2 commit)

**2. [Rule 3 - Blocking] TestWidgetsFlutterBinding.ensureInitialized() needed for windowManager singleton**
- **Found during:** Task 2 (MacosFullscreenDriver test)
- **Issue:** windowManager singleton initialization requires binary messenger, which isn't set up in test without explicit binding init
- **Fix:** Added TestWidgetsFlutterBinding.ensureInitialized() at test main() top level
- **Files modified:** test/platform/macos_fullscreen_driver_test.dart
- **Verification:** All 15 tests pass
- **Committed in:** 554e711 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for test correctness. No scope creep.

## Issues Encountered
- WindowManager has private constructor (WindowManager._()) — cannot subclass for mocking. Solved by testing plugin interaction thoroughly and accepting WindowManager delegation is compiler-validated.
- Golden test failures (control_layouts_golden_test.dart) are pre-existing platform mismatches, unrelated to this plan's changes.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- macOS driver complete, ready for Linux driver (03-03) and driver factory (03-04)
- Plugin callback pattern established, can be reused for Linux state-changed signal bridging

## Self-Check: PASSED

- All 7 files verified present on disk
- Both task commits (0b22e28, 554e711) verified in git log
- 15 unit tests passing
- fullscreen_window package analysis: zero issues
- macos_fullscreen_driver.dart analysis: zero issues

---
*Phase: 03-platform-adaptation*
*Completed: 2026-07-10*
