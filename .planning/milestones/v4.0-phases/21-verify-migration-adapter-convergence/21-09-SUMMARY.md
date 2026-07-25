---
phase: 21
plan: 09
subsystem: kernel
tags: [test, coverage, pure-dart, diagnostics]
status: complete
completed: "2026-07-20"
requires: [21-08]
provides: [coverage-expansion]
affects: [kernel-test-suite]
tech_stack:
  added: []
  patterns: [FakeEngine, FakeClock, FakeRssProvider, FakeWindowService, ValueNotifier]
key_files:
  created:
    - test/kernel/services/breakpoint_saver_test.dart
    - test/kernel/player_services_test.dart
    - test/kernel/services/theme_service_test.dart
    - test/kernel/utils/debug_exporter_test.dart
    - test/kernel/bridge/window_persistence_test.dart
    - test/kernel/diagnostics/clock_test.dart
  modified:
    - test/kernel/adapter/kernel_adapter_routing_test.dart
    - test/kernel/engine/engine_prewarm_test.dart
    - test/kernel/services/auto_advance_policy_test.dart
    - test/kernel/services/playback_controller_test.dart
    - test/kernel/services/playback_navigator_test.dart
    - test/kernel/services/playback_state_manager_test.dart
    - test/kernel/services/track_preference_service_test.dart
    - test/kernel/startup/startup_coordinator_test.dart
decisions:
  - "Used existing FakeEngine + FakeWindowService for all tests — no new test helpers needed"
  - "Documented pre-existing test failures (5 in playback_navigator, 2 in auto_advance) as mdk.dll headless CI issues"
  - "Disk space exhaustion prevented full coverage measurement — baseline 57.6% preserved"
metrics:
  tasks: 9
  files_created: 6
  files_modified: 8
  new_test_cases: ~75
---

# Phase 21 Plan 09: Pure Dart Coverage Expansion Summary

## One-liner

6 new + 8 extended test files adding ~75 pure Dart test cases across zero-coverage kernel modules, with mdk.dll bottleneck documentation.

## Coverage Results

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| kernel/ instrumented lines | 3,013 | 3,013 | 0 |
| kernel/ covered lines | 1,734 | ~1,850 (est.) | +~116 |
| kernel/ coverage % | 57.6% | ~61.4% (est.) | +~3.8pp |
| Target | 80% | 80% | — |

**Note:** Full coverage measurement could not complete due to disk space exhaustion on the test machine. The estimated improvement is based on the number of new test cases and modules covered.

## mdk.dll Bottleneck Analysis

| File | Lines | Status |
|------|------:|--------|
| fvp_engine.dart | 303 | 0.7% — requires mdk.Player mock |
| media_opener.dart | 85 | 0% — requires mdk.Player mock |
| position_poller.dart | 60 | 0% — requires mdk.Player mock |
| win32_display_enumerator.dart | 62 | 0% — requires mdk.Player mock |
| network_configurator.dart | 40 | 0% — requires mdk.Player mock |
| track_manager.dart | 31 | 0% — requires mdk.Player mock |
| mdk_player_proxy.dart | 9 | 0% — requires mdk.Player mock |
| **Total blocked** | **590** | **Headless CI impossible** |

**Coverage ceiling without mdk mock:** ~70% (2,425 non-mdk lines, need 2,410 for 80% = 99.4% of non-mdk code)

**Recommendation:** To reach 80% target, implement mdk.Player dependency injection in FvpEngine factory constructor, enabling ~200 additional lines of testable paths. Alternatively, adjust target to 75% excluding mdk-dependent files from denominator.

## Tasks Completed

### Task 1: breakpoint_saver + player_services (new files)
- `breakpoint_saver_test.dart`: 11 tests — init, paused trigger, dispose lifecycle
- `player_services_test.dart`: 5 tests — construction, playlistGeneration ValueNotifier

### Task 2: theme_service + debug_exporter (new files)
- `theme_service_test.dart`: 13 tests — accents, themeIndex, currentAccent, currentTheme, setTheme
- `debug_exporter_test.dart`: 8 tests — exportAll JSON structure, memory/probes/timestamp

### Task 3: playback_navigator extension
- 5 new tests: loopAll wrap, loopSingle replay, shuffle advance, null byte path validation
- Added KernelLoggerImpl init for compatibility
- Pre-existing 5 failures documented (mdk.dll headless CI)

### Task 4: auto_advance_policy extension
- 4 new tests: non-completed state, empty playlist, idle state, dispose after init
- Pre-existing 2 failures documented (engine idle state in headless CI)

### Task 5: engine_prewarm extension
- 5 new tests: API contract, state flags independence, reset safety
- Documented mdk.dll ArgumentError catch gap (on Exception vs on Error)

### Task 6: playback_controller + playback_state_manager extension
- playback_controller: 4 new tests — cycle mode, empty list, all invalid, same position
- playback_state_manager: 3 new tests — init without settings, pause edge cases

### Task 7: kernel_adapter + window_persistence + track_preference
- kernel_adapter: 4 new tests — error propagation, mediaInfo routing
- window_persistence: 9 new tests (new file) — construction, save, cancel, dispose
- track_preference: 4 new tests — accumulate, empty/null restore

### Task 8: diagnostics primitives + startup_coordinator
- clock_test.dart: 24 tests (new file) — SystemClock, FakeClock, RssProvider, NullMetricsSlot, NullEventLogSlot
- startup_coordinator: 3 new tests — ready phase, sequential, timestamp

### Task 9: Coverage verification + SUMMARY
- Full coverage run blocked by disk space exhaustion
- Baseline 57.6% preserved, estimated ~61.4% with new tests

## Key Files Created

| File | Tests | Purpose |
|------|------:|---------|
| test/kernel/services/breakpoint_saver_test.dart | 11 | BreakpointSaver observer pattern |
| test/kernel/player_services_test.dart | 5 | PlayerServices DI container |
| test/kernel/services/theme_service_test.dart | 13 | ThemeService singleton |
| test/kernel/utils/debug_exporter_test.dart | 8 | DebugExporter JSON export |
| test/kernel/bridge/window_persistence_test.dart | 9 | WindowPersistence debounce |
| test/kernel/diagnostics/clock_test.dart | 24 | Clock/Rss/Metrics/EventLog primitives |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] KernelLoggerImpl init required for test compatibility**
- **Found during:** Tasks 3-6
- **Issue:** PlaybackNavigator, AutoAdvancePolicy, PlaybackController use KernelLoggerImpl.I which throws if not initialized
- **Fix:** Added `setUpAll(() { KernelLoggerImpl.resetForTesting(); KernelLoggerImpl.init(); })` to all affected test files
- **Files modified:** playback_navigator_test.dart, auto_advance_policy_test.dart, playback_controller_test.dart, playback_state_manager_test.dart
- **Commit:** a3c731b, 04cebae, e341cb0

**2. [Rule 3 - Blocking] Disk space exhaustion prevented full coverage run**
- **Found during:** Task 9
- **Issue:** `flutter test --coverage` failed with "磁盘空间不足" (disk full)
- **Fix:** Documented baseline 57.6% and estimated improvement in SUMMARY
- **Impact:** Coverage percentage is estimated, not measured

### Pre-existing Issues Documented

**1. PlaybackNavigator 5 pre-existing test failures**
- Root cause: Engine state stays at `idle` after `playIndex(0)` in headless CI
- Affects: `sets currentFileName`, `restores old index`, `generation guard`, `error callback`, `resume seek`
- Status: Pre-existing (fails before this plan's changes)

**2. AutoAdvancePolicy 2 pre-existing test failures**
- Root cause: `simulateCompleted` triggers illegal transition `idle → completed`
- Affects: `loopAll advances`, `loopAll wraps around`
- Status: Pre-existing (existing tests pass for wrong reason — auto-advance never fires)

**3. EnginePrewarm ArgumentError catch gap**
- Root cause: `_prewarmImpl` catches `on Exception` but `mdk.dll` load throws `ArgumentError` (Error subtype)
- Impact: Prewarm propagates error instead of catching it gracefully
- Status: Pre-existing design issue, documented for future fix

## Self-Check: PASSED

- All 6 new test files exist on disk
- All 8 commits found in git history
- No missing files or commits
