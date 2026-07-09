---
phase: 02-command-queue-recovery
plan: 02
subsystem: bridge
tags: [fullscreen, adapter, driver, command-queue, state-readback, restore-strategy]

# Dependency graph
requires:
  - phase: 01-architecture-core-models
    provides: FullscreenAdapter abstract, FullscreenSnapshot, FullscreenError, FullscreenEvent, FullscreenRequest
  - phase: 02-command-queue-recovery
    plan: 01
    provides: FullscreenCommandQueue
provides:
  - FullscreenDriver abstract interface
  - DesktopFullscreenDriver (window_manager implementation)
  - DesktopFullscreenAdapter (core fullscreen adapter)
affects: [02-03-window-service-migration, player-screen, keyboard-handler]

# Tech tracking
tech-stack:
  added: []
  patterns: [three-level-state-confirmation, restore-snapshot-before-native, per-windowid-completer-isolation]

key-files:
  created:
    - lib/kernel/bridge/fullscreen_driver.dart
    - lib/kernel/bridge/desktop_fullscreen_driver.dart
    - lib/kernel/bridge/desktop_fullscreen_adapter.dart
    - test/kernel/bridge/desktop_fullscreen_adapter_test.dart
  modified: []

key-decisions:
  - "FullscreenDriver.isMaximized() is Future<bool> (not sync getter) — matches window_manager API"
  - "DesktopFullscreenDriver accepts injectable WindowManager for testing"
  - "_RestoreSnapshot uses WindowMode + bool isMaximized (P1-7), not FullscreenMode"
  - "_applyDesync is async Future<void> — awaits driver.queryFullscreen for real state"
  - "enterFullscreen/leaveFullscreen in mock don't auto-change state — tests control via callbacks"

patterns-established:
  - "Three-level state confirmation: native callback (500ms) → polling (100ms×20) → timeout"
  - "Per-windowId Completer<bool> isolation for multi-window concurrent confirmation"
  - "Restore snapshot captured before native call, restored after leave confirmed"

requirements-completed: [CMD-03, RST-01, RST-02, RST-03, RST-04]

coverage:
  - id: D1
    description: "FullscreenDriver abstract interface with 10 methods"
    requirement: CMD-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/fullscreen_driver.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "DesktopFullscreenDriver using window_manager, injectable WindowManager"
    requirement: CMD-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/desktop_fullscreen_driver.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "DesktopFullscreenAdapter with command queue, three-level confirmation, restore strategy"
    requirement: CMD-03
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T12
        status: pass
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T19
        status: pass
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T20
        status: pass
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T21
        status: pass
    human_judgment: false
  - id: D4
    description: "Maximized restore via maximize() call (D-23/RST-02)"
    requirement: RST-02
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T13
        status: pass
    human_judgment: false
  - id: D5
    description: "Windowed restore via setBounds(position, size) (D-22/RST-01)"
    requirement: RST-01
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T14
        status: pass
    human_judgment: false
  - id: D6
    description: "Secondary display restore via setBounds (D-24/RST-03)"
    requirement: RST-03
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T25
        status: pass
    human_judgment: false
  - id: D7
    description: "Minimized → restore before fullscreen (D-25/RST-04)"
    requirement: RST-04
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T24
        status: pass
    human_judgment: false
  - id: D8
    description: "StateDesync: snapshot updates to real state + error event (D-20)"
    requirement: CMD-03
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T15
        status: pass
    human_judgment: false
  - id: D9
    description: "Per-windowId Completer<bool> isolation (P0-1/P0-2)"
    requirement: CMD-03
    verification:
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T18
        status: pass
      - kind: unit
        ref: test/kernel/bridge/desktop_fullscreen_adapter_test.dart#T22
        status: pass
    human_judgment: false
  - id: D10
    description: "No direct windowManager/fullScreenWindow calls in adapter (P0-3)"
    requirement: CMD-03
    verification:
      - kind: grep
        ref: lib/kernel/bridge/desktop_fullscreen_adapter.dart
        status: pass
    human_judgment: false
  - id: D11
    description: "FullscreenDriver independent of WindowBridge (P0-4)"
    requirement: CMD-03
    verification:
      - kind: analysis
        ref: lib/kernel/bridge/fullscreen_driver.dart
        status: pass
      - kind: analysis
        ref: lib/kernel/bridge/desktop_fullscreen_driver.dart
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-07-09
status: complete
---

# Phase 2 Plan 02: DesktopFullscreenAdapter Summary

**FullscreenDriver abstraction + DesktopFullscreenDriver (window_manager) + DesktopFullscreenAdapter (command queue, three-level confirmation, restore strategy) — 18 tests passing**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-09T14:23:13Z
- **Completed:** 2026-07-09T14:48:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- FullscreenDriver: 10-method abstract interface for platform native fullscreen operations, independent of WindowBridge (P0-4)
- DesktopFullscreenDriver: window_manager implementation with injectable WindowManager for testing
- DesktopFullscreenAdapter: FullscreenAdapter implementation with:
  - FullscreenCommandQueue integration (D-15) for per-windowId command serialization
  - Three-level state confirmation: native callback (500ms) → polling (100ms×20) → timeout (D-19)
  - Restore strategy: maximized → maximize(), windowed → setBounds (D-22~D-25)
  - StateDesync handling: snapshot updates to real state + error event (D-20)
  - Per-windowId Completer<bool> isolation (P0-1/P0-2)
  - Error auto-clear on new operation (D-09)
- P0-3 verified: no direct windowManager/fullScreenWindow calls in adapter
- 18 tests covering T12-T26 from review checklist

## Task Commits

1. **Task 1: FullscreenDriver + DesktopFullscreenDriver** - `00aa6a7` (feat)
2. **Task 2: DesktopFullscreenAdapter + tests** - `bec8417` (feat)

## Files Created/Modified

- `lib/kernel/bridge/fullscreen_driver.dart` - FullscreenDriver abstract interface (57 lines)
- `lib/kernel/bridge/desktop_fullscreen_driver.dart` - DesktopFullscreenDriver using window_manager (80 lines)
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` - DesktopFullscreenAdapter implementation (400 lines)
- `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` - 18 tests covering T12-T26 (380 lines)

## Decisions Made

- **FullscreenDriver.isMaximized() is Future<bool>:** Matches window_manager API where isMaximized() returns Future<bool>, not sync bool
- **DesktopFullscreenDriver accepts injectable WindowManager:** Constructor parameter `wm` defaults to global `windowManager`, enables testing
- **Mock doesn't auto-change state:** enterFullscreen/leaveFullscreen in mock don't modify fullscreenState — tests control state via callbacks to simulate real native behavior
- **_applyDesync is async:** Awaits driver.queryFullscreen() to get real state before updating snapshot

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FullscreenDriver.isMaximized was sync getter, window_manager returns Future<bool>**
- **Found during:** Task 1 (API verification via Context7)
- **Issue:** Plan specified `bool get isMaximized` but window_manager's `isMaximized()` returns `Future<bool>`
- **Fix:** Changed to `Future<bool> isMaximized()` method in both abstract and implementation
- **Files modified:** fullscreen_driver.dart, desktop_fullscreen_driver.dart
- **Verification:** flutter analyze passes
- **Committed in:** 00aa6a7

**2. [Rule 1 - Bug] Future.delayed type inference warning**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `Future.delayed(const Duration(...))` triggers inference_failure_on_instance_creation warning
- **Fix:** Changed to `Future<void>.delayed(const Duration(...))`
- **Files modified:** desktop_fullscreen_adapter.dart
- **Verification:** flutter analyze zero warnings
- **Committed in:** bec8417

**3. [Rule 1 - Bug] _applyDesync void return on async function**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `_applyDesync` was `void` but async, triggering avoid_void_async warning
- **Fix:** Changed return type to `Future<void>`, callers now `await` it
- **Files modified:** desktop_fullscreen_adapter.dart
- **Verification:** flutter analyze zero warnings
- **Committed in:** bec8417

**4. [Rule 1 - Bug] Mock auto-changed state, preventing desync/polling tests**
- **Found during:** Task 2 (test failures T15, T21)
- **Issue:** Mock's enterFullscreen set fullscreenState=true, so polling always found matching state, preventing desync test scenarios
- **Fix:** Removed auto-state-change from mock enterFullscreen/leaveFullscreen; tests use explicit confirmEnter/confirmLeave helpers
- **Files modified:** test/kernel/bridge/desktop_fullscreen_adapter_test.dart
- **Verification:** All 18 tests pass
- **Committed in:** bec8417

---

**Total deviations:** 4 auto-fixed (4 bugs)
**Impact on plan:** All auto-fixes were correctness/quality fixes. No scope expansion.

## Issues Encountered

- **Mock design for polling tests:** Initial mock design where enterFullscreen auto-set state prevented testing the polling and desync paths. Required redesigning mock to not auto-change state.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None — DesktopFullscreenAdapter is fully functional with real command queue integration.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-02-02 mitigated | desktop_fullscreen_adapter.dart | onNativeFullScreenChanged callback isolated per windowId (P0-1), prevents cross-window spoofing |
| T-02-03 mitigated | desktop_fullscreen_driver.dart | Driver methods are thin wrappers, no internal state exposure |

## Review Checklist Verification

| ID | Check | Status |
|----|-------|--------|
| P0-1 | `_confirmByWindowId` Map isolation | ✅ Verified in T18, T22 |
| P0-2 | `Completer<bool>` replaces `Completer<void>` | ✅ Verified in T19 |
| P0-3 | No windowManager/fullScreenWindow in adapter | ✅ grep verified CLEAN |
| P0-4 | Driver independent of WindowBridge | ✅ No WindowBridge import in driver files |
| P1-7 | _RestoreSnapshot uses WindowMode + bool isMaximized | ✅ Verified in implementation |

## Self-Check: PASSED

- [x] `lib/kernel/bridge/fullscreen_driver.dart` exists
- [x] `lib/kernel/bridge/desktop_fullscreen_driver.dart` exists
- [x] `lib/kernel/bridge/desktop_fullscreen_adapter.dart` exists
- [x] `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` exists
- [x] Commit `00aa6a7` found in git log
- [x] Commit `bec8417` found in git log
- [x] 18 tests pass (`flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart`)
- [x] `flutter analyze` zero warnings on all new files
- [x] P0-3 grep check: no windowManager/fullScreenWindow in adapter

---

*Phase: 02-command-queue-recovery*
*Completed: 2026-07-09*
