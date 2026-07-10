---
phase: 03-platform-adaptation
plan: 03
subsystem: linux-fullscreen
tags: [fullscreen, linux, gtk, platform-driver, wm-detection]
depends_on:
  requires: [03-01, 03-02]
  provides: [linux-fullscreen-driver]
  affects: [fullscreen-adapter, desktop-fullscreen-adapter]
tech_stack:
  added: []
  patterns: [methodchannel-callback-bridge, gdk-signal-listening, xdg-wm-detection]
key_files:
  created:
    - lib/kernel/bridge/platform/linux_fullscreen_driver.dart
    - test/platform/linux_fullscreen_driver_test.dart
  modified:
    - packages/fullscreen_window/linux/fullscreen_window_plugin.cc
decisions:
  - "D-P12: Use GDK window-state-event signal for fullscreen confirmation, with three-tier fallback"
  - "D-P13: WM detection via XDG environment variables, recorded to platformNotes + debug log"
metrics:
  duration_minutes: ~15
  completed_date: "2026-07-10"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
  tests_added: 17
status: complete
---

# Phase 03 Plan 03: Linux Fullscreen Driver Summary

GTK fullscreen driver with window-state-event signal confirmation and WM environment detection.

## What Was Built

### Task 1: Extended fullscreen_window Linux plugin

Modified `packages/fullscreen_window/linux/fullscreen_window_plugin.cc`:

- **window-state-event signal listener** (D-P12): Added `on_window_state_changed` callback that monitors `GDK_WINDOW_STATE_FULLSCREEN` changes and sends `onFullScreenChanged` to Dart via MethodChannel
- **FlMethodChannel reference**: Stored on the plugin struct for sending native callbacks
- **getFullScreenState method**: Queries real `GdkWindow` state via `gdk_window_get_state()` for accurate state reads
- **getPlatformNotes method** (D-P13): Reads `XDG_SESSION_TYPE`, `XDG_CURRENT_DESKTOP`, `GDMSESSION` environment variables for WM diagnostics
- **Proper cleanup**: Channel reference released in `dispose` via `g_clear_object`

### Task 2: LinuxFullscreenDriver implementation

Created `lib/kernel/bridge/platform/linux_fullscreen_driver.dart`:

- **Implements FullscreenDriver** via fullscreen_window plugin for GTK fullscreen/unfullscreen
- **Native callback bridge** (D-P12): Subscribes to `_plugin.onFullScreenChanged` stream, forwards to `onNativeStateChanged` callback for DesktopFullscreenAdapter confirmation chain
- **WM detection** (D-P13): `_detectWindowManager()` reads XDG environment variables, recorded to `platformNotes` and logged via `debugPrint`
- **queryFullscreen**: Prioritizes plugin's `isFullScreen()` (real GDK state), falls back to window_manager
- **capabilities()**: Returns Linux-specific values with WM info, three-tier confirmation note, and tiling WM warning

### Tests: 17 test cases

Created `test/platform/linux_fullscreen_driver_test.dart`:

- enterFullscreen: calls plugin, returns immediately
- leaveFullscreen: calls plugin with false
- queryFullscreen: delegates to plugin, falls back on exception
- Native callback bridge: forwards callbacks, handles multiple, no crash without callback, stops after dispose
- capabilities: correct Linux values, GTK/WM/three-tier info in platformNotes
- dispose: cancels subscription, clears callback
- WM detection: no crash with missing environment variables

## Verification Results

- `flutter analyze lib/kernel/bridge/platform/linux_fullscreen_driver.dart` -- No issues found
- `flutter test test/platform/` -- 58/58 passed (17 Linux + 4 Windows + 37 macOS)
- No regressions in existing platform tests

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all functionality is wired and tested.

## Self-Check: PASSED

- [x] `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` exists
- [x] `test/platform/linux_fullscreen_driver_test.dart` exists
- [x] `packages/fullscreen_window/linux/fullscreen_window_plugin.cc` modified
- [x] Commit a7c401c (Task 1) exists
- [x] Commit c35a9ae (Task 2) exists
