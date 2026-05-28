---
phase: 03-performance-optimization
plan: 01
subsystem: engine
tags: [performance, d3d11, settings, l10n]
dependency_graph:
  requires: []
  provides: [d3d11-params, performance-settings-tab]
  affects: [fvp-engine, settings-panel, perf-monitor]
tech_stack:
  added: []
  patterns: [circular-buffer, bridge-notifier]
key_files:
  created:
    - lib/ui/dialogs/settings/settings_tab_performance.dart
    - scripts/apply_queryfence_patch.dart
  modified:
    - lib/kernel/utils/perf_monitor.dart
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/engine/media_engine.dart
    - lib/ui/dialogs/settings_panel.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_zh.arb
    - lib/window/window_service.dart
    - test/helpers/fake_engine.dart
decisions:
  - "D3D11 sync default: synchronous (d3d11.sync.cpu=1) for safety, user-tunable"
  - "Decoder priority: D3D11 > NVDEC > FFmpeg (hardware-first)"
  - "PerfMonitor: ring buffer capacity 300 frames (not 1000) for memory efficiency"
  - "mark/markEnd: removed wrapper, window_service uses developer.Timeline directly"
metrics:
  duration_seconds: 895
  completed_date: "2026-05-29"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 10
  tests_passing: 349
---

# Phase 3 Plan 01: D3D11 Performance Parameters Summary

D3D11 rendering defaults + runtime-tunable performance settings + PerfMonitor circular buffer cleanup

## Tasks Completed

### Task 1: PerfMonitor Cleanup + queryFence Automation (541269d)

**PerfMonitor circular buffer:**
- Replaced unbounded `_buildTimes`/`_rasterTimes` lists with fixed-capacity ring buffer (`_maxFrames = 300`)
- Ring buffer uses `_writeIndex % _maxFrames` for overwrite semantics
- `_printStats()` reads valid entries without calling `.clear()` (no memory spikes)
- `exportStats()` reads up to `_maxFrames` entries from circular buffer

**Dead code removal:**
- Removed `mark(String label)` and `markEnd(String label)` wrapper methods
- Updated `window_service.dart` to use `developer.Timeline.startSync/finishSync` directly
- Removed `import '../kernel/utils/perf_monitor.dart'` from window_service.dart

**queryFence automation:**
- Created `scripts/apply_queryfence_patch.dart` — Dart script for automated patch detection
- Script locates fvp package via `.dart_tool/package_config.json`
- Checks for patch marker in `fvp_plugin.cpp`
- Non-fatal if patch file missing (exits 0 with warning)

### Task 2: D3D11 Parameters + Performance Settings Tab + l10n (3f12877)

**FvpEngine D3D11 parameters:**
- Added `_applyD3d11Defaults()` called in `_createPlayer()` after init
- Sets `d3d11.sync.cpu=1` (synchronous mode, safe default)
- Sets `video.decoders=D3D11,NVDEC,FFmpeg` (hardware-first priority)
- Added `setD3d11SyncEnabled(bool)` — toggles `d3d11.sync.cpu` (0=async, 1=sync)
- Added `setHardwareDecoding(bool)` — toggles between hardware+software vs software-only

**MediaEngine interface:**
- Added abstract `setD3d11SyncEnabled(bool enabled)` method
- Added abstract `setHardwareDecoding(bool enabled)` method

**Performance settings tab:**
- Created `lib/ui/dialogs/settings/settings_tab_performance.dart`
- `PerformanceTab` widget with two `SettingSwitchRow` toggles
- `_D3d11SyncNotifier` bridge pattern (same as `_BoolNotifier` in VideoTab)
- `_HardwareDecodingNotifier` bridge pattern
- Both default to `true` (safe defaults matching engine)

**Settings panel integration:**
- Added case `6 => PerformanceTab(...)` in `_buildTab()`
- Added 7th `SettingsNavItem` with `Icons.speed` icon and `l10n.performanceTab` label
- Imported `settings_tab_performance.dart`

**Localization:**
- Added 8 keys to `app_en.arb`: performanceTab, d3d11Rendering, d3d11Sync, d3d11SyncDesc, decoderSettings, hardwareDecoding, hardwareDecodingDesc, performanceHint
- Added 8 matching keys to `app_zh.arb`
- Ran `flutter gen-l10n` successfully

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] mark/markEnd had callers (not dead code)**
- **Found during:** Task 1
- **Issue:** Plan stated mark/markEnd had "zero callers" but `window_service.dart:98-100` uses them for window resize/move timeline events
- **Fix:** Updated `window_service.dart` to use `developer.Timeline.startSync/finishSync` directly, removing the PerfMonitor wrapper dependency
- **Files modified:** `lib/window/window_service.dart`
- **Commit:** 541269d

**2. [Rule 1 - Bug] FakeEngine missing new MediaEngine methods**
- **Found during:** Task 2
- **Issue:** Adding abstract methods to MediaEngine broke FakeEngine compilation (10 test files)
- **Fix:** Added concrete implementations with call tracking to FakeEngine
- **Files modified:** `test/helpers/fake_engine.dart`
- **Commit:** 3f12877

## Verification Results

| Check | Result |
|-------|--------|
| `dart analyze lib/kernel/utils/perf_monitor.dart` | Clean |
| `dart analyze lib/kernel/engine/fvp_engine.dart` | Clean |
| `dart analyze lib/kernel/engine/media_engine.dart` | Clean |
| `dart analyze lib/ui/dialogs/settings_panel.dart` | Clean |
| `dart analyze lib/ui/dialogs/settings/settings_tab_performance.dart` | Clean |
| `flutter test` | 349/349 passed |
| `flutter gen-l10n` | Success |
| `dart run scripts/apply_queryfence_patch.dart` | Exit 0 (patch file not yet created) |

## Known Stubs

None — all functionality is wired and operational.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-03-02 | lib/kernel/engine/fvp_engine.dart | User-controlled D3D11 parameters affect GPU rendering pipeline. Mitigated: values clamped to valid ranges (0/1 for sync, predefined decoder list) |

## Self-Check

- [x] lib/kernel/utils/perf_monitor.dart exists and contains `_maxFrames = 300`
- [x] lib/kernel/engine/fvp_engine.dart contains `setD3d11SyncEnabled` implementation
- [x] lib/kernel/engine/media_engine.dart contains `void setD3d11SyncEnabled(bool enabled)` abstract method
- [x] lib/ui/dialogs/settings/settings_tab_performance.dart exists with `PerformanceTab` class
- [x] lib/ui/dialogs/settings_panel.dart has case 6 for PerformanceTab
- [x] app_en.arb contains "performanceTab" key
- [x] app_zh.arb contains "performanceTab" key
- [x] scripts/apply_queryfence_patch.dart exists and is valid Dart
- [x] All 349 tests pass
- [x] Commit 541269d exists (Task 1)
- [x] Commit 3f12877 exists (Task 2)

## Self-Check: PASSED
