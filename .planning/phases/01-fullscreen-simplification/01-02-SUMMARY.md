---
phase: 01-fullscreen-simplification
plan: 02
subsystem: bridge
tags: [fullscreen, state-consolidation, dead-code-removal, timer-simplification, confirmation-chain]

requires:
  - phase: 01-fullscreen-simplification
    provides: "WindowService with inlined _createDriver(), FullscreenResult sealed class"
provides:
  - WindowService.isFullscreen derived from mode.value.isFullscreen (single source of truth)
  - Single _resizeTimer replacing dual _resizeDebounce + _resizeEndTimer
  - Simplified confirmation chain (Completer + single query, no 20x polling)
  - Dead fullscreen persistence code removed from SettingsStore, WindowPersistence, AppSettings
affects: [01-03, fullscreen, window-service, settings]

tech-stack:
  added: []
  patterns: [single-source-of-truth, completer-based-confirmation]

key-files:
  created: []
  modified:
    - lib/kernel/bridge/window_service.dart
    - lib/kernel/bridge/window_bridge.dart
    - lib/kernel/persistence/settings_store.dart
    - lib/kernel/bridge/window_persistence.dart
    - lib/kernel/models/app_settings.dart
    - test/unit/kernel/bridge/window_service_test.dart
    - test/regression/smoke_suite_test.dart
    - test/regression/high_risk_suite_test.dart

key-decisions:
  - "isFullscreen changed from ValueNotifier<bool> to bool getter derived from mode"
  - "Single _resizeTimer replaces dual timer pattern (500ms debounce)"
  - "Confirmation chain uses Completer + single query fallback instead of 20x polling"
  - "Regression tests updated to match new API (fullscreenDriver -> driver, .value removal)"

patterns-established:
  - "mode.value.isFullscreen as single source of truth for fullscreen state"
  - "Completer-based async confirmation with timeout fallback"

requirements-completed: [FULL-03]

coverage:
  - id: D1
    description: "SettingsStore._keyIsFullscreen and saveIsFullscreen removed"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "grep -rn saveIsFullscreen lib/ returns 0 matches"
        status: pass
    human_judgment: false
  - id: D2
    description: "WindowPersistence.saveIsFullscreen removed"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/window_persistence.dart — no issues"
        status: pass
    human_judgment: false
  - id: D3
    description: "AppSettings.isFullscreen field removed from all locations"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/models/app_settings.dart — no issues"
        status: pass
    human_judgment: false
  - id: D4
    description: "WindowService._isFullscreen removed, isFullscreen derives from mode"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "test/unit/kernel/bridge/window_service_test.dart#isFullscreen derives from mode"
        status: pass
    human_judgment: false
  - id: D5
    description: "Single _resizeTimer replaces dual _resizeDebounce + _resizeEndTimer"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "flutter analyze lib/kernel/bridge/window_service.dart — no _resizeDebounce Timer field"
        status: pass
    human_judgment: false
  - id: D6
    description: "Confirmation chain simplified to Completer + single query"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "test/unit/kernel/bridge/window_service_test.dart#confirmation chain"
        status: pass
    human_judgment: false
  - id: D7
    description: "All existing tests pass after refactoring"
    requirement: FULL-03
    verification:
      - kind: unit
        ref: "flutter test test/unit/kernel/bridge/ — 18 tests pass"
        status: pass
      - kind: unit
        ref: "flutter test test/regression/smoke_suite_test.dart — 8 tests pass"
        status: pass
      - kind: unit
        ref: "flutter test test/regression/high_risk_suite_test.dart — 6 tests pass"
        status: pass
    human_judgment: false

duration: 23min
completed: 2026-07-12
status: complete
---

# Phase 1 Plan 02: Fullscreen State Consolidation Summary

**Removed dual-state desync risk by deriving isFullscreen from mode, eliminated dead persistence code, simplified resize debounce to single Timer, and replaced 20x polling confirmation with Completer + single query**

## Performance

- **Duration:** 23 min
- **Started:** 2026-07-12T15:42:01Z
- **Completed:** 2026-07-12T16:05:03Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Removed `_isFullscreen` ValueNotifier from WindowService — `isFullscreen` now derives from `mode.value.isFullscreen` (single source of truth, eliminates dual-state desync risk)
- Removed dead fullscreen persistence code: `SettingsStore.saveIsFullscreen`/`_keyIsFullscreen`, `WindowPersistence.saveIsFullscreen`, `AppSettings.isFullscreen` field (saved but never loaded)
- Simplified resize debounce from dual `_resizeDebounce` (100ms) + `_resizeEndTimer` (500ms) to single `_resizeTimer` (500ms)
- Simplified confirmation chain from `_confirmByWindowId` map + `_PendingConfirmation` class + 20x polling loop to single `Completer<bool>` + one `queryFullscreen()` fallback
- Added `bool get isFullscreen` to `WindowBridge` interface
- Updated regression tests (smoke + high risk) to match new API
- All 32 tests pass (18 unit + 8 smoke + 6 high risk)

## Task Commits

1. **Task 1: Remove dead fullscreen persistence code** - `5079b28` (refactor)
2. **Task 2: Consolidate fullscreen state + simplify timers and confirmation chain** - `9786955` (refactor)

## Files Created/Modified

- `lib/kernel/bridge/window_service.dart` - Removed `_isFullscreen` notifier, dual timers, map-based confirmation; added `bool get isFullscreen`, single `_resizeTimer`, `Completer`-based confirmation
- `lib/kernel/bridge/window_bridge.dart` - Added `bool get isFullscreen` to interface
- `lib/kernel/persistence/settings_store.dart` - Removed `_keyIsFullscreen` constant and `saveIsFullscreen` method
- `lib/kernel/bridge/window_persistence.dart` - Removed `saveIsFullscreen` method
- `lib/kernel/models/app_settings.dart` - Removed `isFullscreen` field from declaration, constructor, copyWith, ==, hashCode
- `test/unit/kernel/bridge/window_service_test.dart` - Added 3 tests for `isFullscreen` derivation from mode
- `test/regression/smoke_suite_test.dart` - Fixed `fullscreenDriver` -> `driver` param, `isFullscreen.value` -> `isFullscreen`
- `test/regression/high_risk_suite_test.dart` - Fixed `fullscreenDriver` -> `driver` param, `isFullscreen.value` -> `isFullscreen`

## Decisions Made

- **`isFullscreen` changed from `ValueNotifier<bool>` to `bool` getter**: All UI callers already read from `mode.value.isFullscreen` (player_screen.dart, custom_title_bar.dart). The only ValueNotifier consumers were regression tests, which were updated.
- **Single 500ms `_resizeTimer`**: The 100ms debounce and 500ms resize-end timer served overlapping purposes. A single 500ms timer handles both window size update and isResizing flag reset.
- **Completer + single query**: The 20x polling loop (2 seconds total) was overkill for a single-window app. A 500ms native callback timeout + single `queryFullscreen()` call is sufficient.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed regression tests using old constructor param name**
- **Found during:** Task 2 (test execution)
- **Issue:** `smoke_suite_test.dart` and `high_risk_suite_test.dart` used `WindowService(fullscreenDriver: driver)` but constructor param was renamed to `driver` in Plan 01-01
- **Fix:** Updated all `fullscreenDriver:` to `driver:` in both test files
- **Files modified:** test/regression/smoke_suite_test.dart, test/regression/high_risk_suite_test.dart
- **Verification:** All 14 regression tests pass
- **Committed in:** 9786955 (Task 2 commit)

**2. [Rule 3 - Blocking] Updated regression tests to use bool getter API**
- **Found during:** Task 2 (test execution)
- **Issue:** Regression tests used `service.isFullscreen.value` but `isFullscreen` is now a `bool` getter
- **Fix:** Replaced all `.isFullscreen.value` with `.isFullscreen` in both test files
- **Files modified:** test/regression/smoke_suite_test.dart, test/regression/high_risk_suite_test.dart
- **Verification:** All 14 regression tests pass
- **Committed in:** 9786955 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were necessary for test compilation after API change. No scope creep.

## Issues Encountered

None — plan executed smoothly after fixing test API mismatches.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- WindowService now has a single source of truth for fullscreen state (mode.value.isFullscreen)
- Dead persistence code eliminated — no more save-without-load pattern
- Timer and confirmation logic significantly simpler — easier to maintain and test
- Ready for Phase 01-03 (further simplification if needed)

---
*Phase: 01-fullscreen-simplification*
*Completed: 2026-07-12*

## Self-Check: PASSED

- All 9 files verified present on disk
- All 3 commits verified in git log (5079b28, 9786955, e0123bf)
- `flutter analyze lib/kernel/` — 1 issue (pre-existing unused_import in windows_fullscreen_driver.dart, not from this plan)
- `flutter test test/unit/kernel/bridge/` — 18/18 pass
- `flutter test test/regression/smoke_suite_test.dart` — 8/8 pass
- `flutter test test/regression/high_risk_suite_test.dart` — 6/6 pass
