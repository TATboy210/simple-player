---
phase: 03-platform-adaptation
plan: 04
subsystem: bridge
tags: [factory, fullscreen, driver, platform-selection, compile-time-flag, callback-bridge]

requires:
  - phase: 03-platform-adaptation
    plan: 01
    provides: WindowsFullscreenDriver, Win32FullscreenApi FFI bindings
  - phase: 03-platform-adaptation
    plan: 02
    provides: MacosFullscreenDriver, NSWindowDelegate callback pattern
  - phase: 03-platform-adaptation
    plan: 03
    provides: LinuxFullscreenDriver, window-state-event signal pattern
  - phase: 02-command-queue-recovery
    provides: FullscreenDriver interface, DesktopFullscreenAdapter, command queue
  - phase: 01-architecture-core-models
    provides: FullscreenCapability model
provides:
  - DesktopFullscreenDriverFactory with Platform.isXXX selection
  - FullscreenDriver.onNativeStateChanged setter (D-P11 unified callback chain)
  - FullscreenDriver.capabilities() method (PLAT-04)
  - DesktopFullscreenAdapter callback forwarding (D-P11)
  - main.dart factory wiring with compile-time flag control
affects: [fullscreen-adapter, window-service, platform-drivers]

tech-stack:
  added: []
  patterns: [compile-time factory pattern, driver interface extension with defaults, callback bridge in adapter constructor]

key-files:
  created:
    - lib/kernel/bridge/desktop_fullscreen_driver_factory.dart
    - test/platform/fullscreen_driver_factory_test.dart
  modified:
    - lib/kernel/bridge/fullscreen_driver.dart
    - lib/kernel/bridge/desktop_fullscreen_adapter.dart
    - lib/kernel/bridge/desktop_fullscreen_driver.dart
    - lib/kernel/bridge/platform/windows_fullscreen_driver.dart
    - lib/kernel/bridge/platform/macos_fullscreen_driver.dart
    - lib/kernel/bridge/platform/linux_fullscreen_driver.dart
    - lib/main.dart
    - test/kernel/bridge/desktop_fullscreen_adapter_test.dart

key-decisions:
  - "FullscreenDriver uses default implementations (not abstract) to avoid breaking DesktopFullscreenDriver"
  - "capabilities() is sync (not async) — platform drivers return sync values, adapter wraps in Future"
  - "USE_WINDOWS_NATIVE_FULLSCREEN flag documented in main.dart as comment (not const) to avoid unused_element warning"
  - "Adapter sets driver.onNativeStateChanged in constructor for automatic callback forwarding"

patterns-established:
  - "Factory pattern with compile-time flag for platform driver selection"
  - "Interface extension with default implementations for backward compatibility"

requirements-completed: [PLAT-04]

coverage:
  - id: D1
    description: "FullscreenDriver interface extension — onNativeStateChanged setter + capabilities() method with default implementations"
    requirement: PLAT-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/fullscreen_driver.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "DesktopFullscreenDriverFactory — Platform.isXXX selection with USE_WINDOWS_NATIVE_FULLSCREEN compile-time flag"
    requirement: PLAT-04
    verification:
      - kind: unit
        ref: "test/platform/fullscreen_driver_factory_test.dart — 7 tests"
        status: pass
    human_judgment: false
  - id: D3
    description: "DesktopFullscreenAdapter callback forwarding — constructor sets driver.onNativeStateChanged = onNativeFullScreenChanged"
    requirement: PLAT-04
    verification:
      - kind: unit
        ref: "test/kernel/bridge/desktop_fullscreen_adapter_test.dart — 18 tests"
        status: pass
    human_judgment: false
  - id: D4
    description: "main.dart factory wiring — DesktopFullscreenDriverFactory.create() replaces hardcoded DesktopFullscreenDriver()"
    requirement: PLAT-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/main.dart"
        status: pass
    human_judgment: false
  - id: D5
    description: "Platform driver capabilities — each driver returns platform-specific FullscreenCapability via @override"
    requirement: PLAT-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/platform/ — all 3 drivers"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-07-10
status: complete
---

# Phase 03 Plan 04: Driver Factory + Integration Summary

**Platform driver factory with compile-time flag control, unified callback forwarding chain, and FullscreenDriver interface extensions for capabilities and native callbacks**

## Performance

- **Duration:** 19 min
- **Started:** 2026-07-10T04:44:33Z
- **Completed:** 2026-07-10T05:03:39Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- FullscreenDriver interface extended with `onNativeStateChanged` setter (D-P11 callback chain) and `capabilities()` method (PLAT-04)
- DesktopFullscreenDriverFactory selects platform driver via `Platform.isXXX` with `USE_WINDOWS_NATIVE_FULLSCREEN` compile-time flag (D-P02/D-P03)
- DesktopFullscreenAdapter constructor automatically forwards driver's native callback to its confirmation signal (D-P11)
- main.dart uses factory instead of hardcoded DesktopFullscreenDriver, with documented compile-time flags
- All 5 `implements FullscreenDriver` classes updated with `@override` annotations
- 7 new factory tests + all 65 platform tests + 18 adapter tests pass (90 total)

## Task Commits

Each task was committed atomically:

1. **Task 1: FullscreenDriver interface extension + DesktopFullscreenDriverFactory** - `d68d2a4` (feat)
2. **Task 2: Adapter callback forwarding + main.dart factory wiring** - `0c2b011` (feat)

## Files Created/Modified

- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` - Platform driver factory with compile-time flag
- `test/platform/fullscreen_driver_factory_test.dart` - 7 unit tests for factory and interface extensions
- `lib/kernel/bridge/fullscreen_driver.dart` - Added `onNativeStateChanged` setter + `capabilities()` with defaults
- `lib/kernel/bridge/desktop_fullscreen_adapter.dart` - Constructor sets callback forwarding, capabilities delegates to driver
- `lib/kernel/bridge/desktop_fullscreen_driver.dart` - Added `@override` for new interface members
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` - Added `onNativeStateChanged` setter + `@override` on capabilities
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` - Added `@override` on setter + capabilities
- `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` - Added `@override` on setter + capabilities
- `lib/main.dart` - Factory import, documented USE_WINDOWS_NATIVE_FULLSCREEN flag, factory-based initialization
- `test/kernel/bridge/desktop_fullscreen_adapter_test.dart` - MockFullscreenDriver updated with new interface members

## Decisions Made

- **Default implementations over abstract:** Used default implementations for `onNativeStateChanged` and `capabilities()` in `FullscreenDriver` to avoid breaking existing `DesktopFullscreenDriver` and all mock implementations
- **Sync capabilities():** `capabilities()` returns `FullscreenCapability` (not `Future`) since all platform drivers return synchronous values. `DesktopFullscreenAdapter.capabilities()` wraps in `async`
- **Comment over const for docs:** `USE_WINDOWS_NATIVE_FULLSCREEN` documented in main.dart as a comment (not `const`) to avoid `unused_element` analyzer warning, since the factory reads it internally via `bool.fromEnvironment`
- **Constructor callback wiring:** Adapter sets `driver.onNativeStateChanged = onNativeFullScreenChanged` in constructor for automatic forwarding — no manual wiring needed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DesktopFullscreenDriver missing new interface members**
- **Found during:** Task 1 (test run)
- **Issue:** `DesktopFullscreenDriver implements FullscreenDriver` needed `onNativeStateChanged` setter and `capabilities()` method
- **Fix:** Added both members with `@override` annotations to `desktop_fullscreen_driver.dart`
- **Files modified:** lib/kernel/bridge/desktop_fullscreen_driver.dart
- **Verification:** flutter analyze passes, all 65 platform tests pass
- **Committed in:** d68d2a4 (Task 1 commit)

**2. [Rule 1 - Bug] MockFullscreenDriver in adapter test missing new members**
- **Found during:** Task 2 (full test suite)
- **Issue:** `MockFullscreenDriver implements FullscreenDriver` in `desktop_fullscreen_adapter_test.dart` needed the two new interface members
- **Fix:** Added `onNativeStateChanged` setter (records callback) and `capabilities()` to MockFullscreenDriver, added FullscreenCapability import
- **Files modified:** test/kernel/bridge/desktop_fullscreen_adapter_test.dart
- **Verification:** All 18 adapter tests pass
- **Committed in:** 0c2b011 (Task 2 commit)

**3. [Rule 3 - Blocking] TestWidgetsFlutterBinding.ensureInitialized() needed**
- **Found during:** Task 1 (test run)
- **Issue:** `DesktopFullscreenDriver()` accesses `windowManager` singleton which needs `binaryMessenger`
- **Fix:** Added `TestWidgetsFlutterBinding.ensureInitialized()` at test main() top
- **Files modified:** test/platform/fullscreen_driver_factory_test.dart
- **Verification:** All 7 factory tests pass
- **Committed in:** d68d2a4 (Task 1 commit)

**4. [Rule 1 - Bug] unused_element warning for _useWindowsNativeFullscreen**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `const _useWindowsNativeFullscreen` declared but never referenced in main.dart
- **Fix:** Replaced `const` declaration with a comment block for documentation
- **Files modified:** lib/main.dart
- **Verification:** flutter analyze passes with zero issues
- **Committed in:** 0c2b011 (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (2 bugs, 1 blocking, 1 warning)
**Impact on plan:** All auto-fixes necessary for correctness. No scope creep.

## Issues Encountered

- Dart `implements` keyword requires all interface members to be explicitly implemented (no default inheritance), so every `implements FullscreenDriver` class needed updating when new members were added

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three platform drivers (Windows/macOS/Linux) + factory + adapter fully integrated
- Phase D (quality polish and E2E testing) can begin
- Factory pattern enables easy addition of new platform drivers

## Self-Check: PASSED

- [x] `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` exists
- [x] `test/platform/fullscreen_driver_factory_test.dart` exists
- [x] `lib/kernel/bridge/fullscreen_driver.dart` modified (onNativeStateChanged + capabilities)
- [x] `lib/kernel/bridge/desktop_fullscreen_adapter.dart` modified (callback forwarding + capabilities delegation)
- [x] `lib/main.dart` modified (factory wiring)
- [x] Commit d68d2a4 (Task 1) exists
- [x] Commit 0c2b011 (Task 2) exists
- [x] 65 platform tests pass (7 factory + 17 Linux + 15 macOS + 26 Windows)
- [x] 18 adapter tests pass

---

## Self-Check: PASSED

- [x] `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` exists
- [x] `test/platform/fullscreen_driver_factory_test.dart` exists
- [x] `lib/kernel/bridge/fullscreen_driver.dart` modified (onNativeStateChanged + capabilities)
- [x] `lib/kernel/bridge/desktop_fullscreen_adapter.dart` modified (callback forwarding + capabilities delegation)
- [x] `lib/main.dart` modified (factory wiring)
- [x] Commit d68d2a4 (Task 1) exists
- [x] Commit 0c2b011 (Task 2) exists
- [x] 65 platform tests pass (7 factory + 17 Linux + 15 macOS + 26 Windows)
- [x] 18 adapter tests pass

---

*Phase: 03-platform-adaptation*
*Completed: 2026-07-10*
