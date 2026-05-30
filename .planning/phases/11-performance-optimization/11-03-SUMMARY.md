---
phase: 11-performance-optimization
plan: 03
subsystem: kernel/bridge + kernel/engine
tags: [performance, d3d11, ffi, win32, refresh-rate]
dependencies:
  requires: []
  provides: [DisplayConfig.d3d11SyncMode()]
  affects: [fvp_engine._applyD3d11Defaults]
tech_stack:
  added: []
  patterns: [win32-ffi, refresh-rate-detection]
key_files:
  created:
    - lib/kernel/bridge/display_config.dart
    - test/kernel/bridge/display_config_test.dart
  modified:
    - lib/kernel/bridge/win32_bindings.dart
    - lib/kernel/engine/fvp_engine.dart
decisions:
  - "Array<Uint16> for DEVMODE string fields (Utf16 not valid in Struct arrays)"
  - "120Hz threshold for async mode (covers 120/144/240Hz displays)"
  - "nullptr device name for primary display detection"
  - "calloc + try/finally for safe FFI allocation"
metrics:
  tasks_completed: 2
  duration: ~5m
  files_changed: 4
  tests_added: 7
---

# Phase 11 Plan 03: D3D11 Refresh-Rate-Aware Sync Mode Summary

One-liner: EnumDisplaySettings FFI detects display Hz, sets d3d11.sync.cpu=0 for 120Hz+ (async) vs =1 for 60Hz (sync).

## Tasks Completed

### Task 1: EnumDisplaySettings FFI + DisplayConfig
- Added DevMode struct (DEVMODEW layout, 188 bytes) to win32_bindings.dart
- Added EnumDisplaySettingsW FFI typedefs and binding
- Created DisplayConfig class: getRefreshRate(), d3d11SyncMode(), syncModeForHz()
- Created 7 unit tests for sync mode boundary cases
- Commit: 5339de1

### Task 2: FvpEngine Integration
- Modified _applyD3d11Defaults() to use DisplayConfig.d3d11SyncMode()
- Log message now includes detected refresh rate
- Commit: 7a9b138

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Array<Utf16> invalid in FFI struct**
- **Found during:** Task 1 test run
- **Issue:** `Array<Utf16>` is not a valid NativeType subtype in Dart FFI structs. Utf16 is only for pointer types.
- **Fix:** Changed to `Array<Uint16>` for dmDeviceName and dmFormName fields
- **Files modified:** lib/kernel/bridge/win32_bindings.dart
- **Commit:** 5339de1

## Threat Flags

None — EnumDisplaySettings is read-only (no state mutation), calloc + try/finally matches threat model T-11-01.

## Known Stubs

None.

## Verification

- [x] 7 unit tests pass (syncModeForHz boundary cases)
- [x] All 630 project tests pass
- [x] flutter analyze clean (4 pre-existing issues, none in modified files)
