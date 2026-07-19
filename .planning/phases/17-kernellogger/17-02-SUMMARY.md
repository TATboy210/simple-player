---
phase: 17-kernellogger
plan: 02
subsystem: kernel-diagnostics
tags: [migration, kernel-logger, ci-gate, mechanical-refactor]

# Dependency graph
requires:
  - phase: 17-kernellogger
    plan: 01
    provides: KernelLoggerImpl with static I accessor, LogLevel/LogSink/sinks
provides:
  - 24 kernel files migrated from log.dart to KernelLogger
  - CI grep gate script enforcing zero residual imports
affects: [17-kernellogger-plan-03, 18-metrics, 19-eventlog]

# Tech tracking
tech-stack:
  added: []
  patterns: [mechanical-import-swap, file-local-logger-variable, rg-grep-compat-gate]

key-files:
  created:
    - tool/audit/kernel_logger_gate.sh
  modified:
    - lib/kernel/bridge/display_config.dart
    - lib/kernel/bridge/win32/win32_display_enumerator.dart
    - lib/kernel/bridge/window_service.dart
    - lib/kernel/engine/d3d11_configurator.dart
    - lib/kernel/engine/engine_prewarm.dart
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/engine/position_poller.dart
    - lib/kernel/engine/subtitle_configurator.dart
    - lib/kernel/engine/track_manager.dart
    - lib/kernel/engine/video_effect_controller.dart
    - lib/kernel/persistence/playlist_store.dart
    - lib/kernel/persistence/settings_store.dart
    - lib/kernel/playlist/playlist.dart
    - lib/kernel/services/auto_advance_policy.dart
    - lib/kernel/services/file_operations.dart
    - lib/kernel/services/playback_controller.dart
    - lib/kernel/services/playback_navigator.dart
    - lib/kernel/services/playback_state_manager.dart
    - lib/kernel/services/subtitle_service.dart
    - lib/kernel/services/track_preference_service.dart
    - lib/kernel/startup/startup_coordinator.dart
    - lib/kernel/utils/debug_exporter.dart
    - lib/kernel/utils/path_utils.dart
    - lib/kernel/utils/screen_utils.dart

key-decisions:
  - "Each migrated file declares 'final log = KernelLogger.I' (and logEngine/logBridge where needed) as file-local variables to replace the top-level imports from log.dart"
  - "Call sites (log.e(), logEngine.d(), logBridge.w()) remain completely unchanged — only import + declaration lines modified"
  - "Non-kernel files (app.dart, main.dart, player_feature.dart, deferred_player_feature.dart) keep their old log.dart imports unchanged"

patterns-established:
  - "File-local KernelLogger.I variable pattern: each kernel file declares its own 'final log = KernelLogger.I' instead of importing a shared top-level variable"

requirements-completed: [LOG-01, LOG-04]

coverage:
  - id: D11
    description: "All 78 call sites compile unchanged with KernelLogger (log.w(), log.e(), logEngine.d() etc.)"
    requirement: LOG-01
    verification:
      - kind: automated
        ref: flutter analyze — zero kernel errors
        status: pass
    human_judgment: false
  - id: D12
    description: "lib/kernel/** has zero imports of package:logger (excluding utils/log.dart)"
    requirement: LOG-01
    verification:
      - kind: automated
        ref: tool/audit/kernel_logger_gate.sh GATE 1
        status: pass
    human_judgment: false
  - id: D13
    description: "lib/kernel/** has zero imports of utils/log.dart"
    requirement: LOG-04
    verification:
      - kind: automated
        ref: tool/audit/kernel_logger_gate.sh GATE 2
        status: pass
    human_judgment: false
  - id: D14
    description: "CI grep gate script enforces structural property"
    requirement: LOG-04
    verification:
      - kind: automated
        ref: bash tool/audit/kernel_logger_gate.sh exits 0
        status: pass
    human_judgment: false

# Metrics
duration: 37min
completed: 2026-07-19
status: complete
---

# Phase 17 Plan 02: 78-Site Migration Summary

**Batch-migrated 24 kernel files from old log.dart to new KernelLogger with zero call site changes, plus CI grep gate script**

## Performance

- **Duration:** 37 min
- **Started:** 2026-07-19T13:30:07Z
- **Completed:** 2026-07-19T14:07:22Z
- **Tasks:** 2
- **Files modified:** 25 (24 migrated + 1 created)

## Accomplishments

- Migrated all 24 kernel files from `import '../utils/log.dart'` to `import '../diagnostics/kernel_logger.dart'`
- Added file-local `final log = KernelLogger.I` (and `logEngine`/`logBridge` where needed) declarations in each file
- Zero call site changes: all `log.e()`, `logEngine.d()`, `logBridge.w()` etc. remain exactly as before
- Import path correctness: 3 utils/ files use `../diagnostics/`, 1 win32/ file uses `../../diagnostics/`, 20 files use `../diagnostics/`
- Created `tool/audit/kernel_logger_gate.sh` CI grep gate with rg/grep compatibility
- Both gates PASS: zero `package:logger` imports, zero `utils/log.dart` imports in lib/kernel/
- `flutter analyze` passes with zero kernel errors
- All 16 kernel logger tests pass (Plan 01 tests unaffected)
- Non-kernel files (app.dart, main.dart, etc.) unchanged

## Task Commits

1. **Task 1: Batch-migrate 24 kernel files** - `204bedf` (feat)
2. **Task 2: Add CI grep gate script** - `f6502dd` (chore)

## Files Created/Modified

- `tool/audit/kernel_logger_gate.sh` — CI grep gate: GATE 1 (LOG-01) + GATE 2 (LOG-04)
- 24 `lib/kernel/**/*.dart` files — import + declaration changes only

## Decisions Made

- File-local `KernelLogger.I` variable pattern: each kernel file declares its own logger variable rather than importing a shared top-level variable, preserving the same call-site ergonomics
- Non-kernel files retain old log.dart imports — migration scope limited to lib/kernel/ only

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None.

## Known Stubs

None — all 78 call sites compile and function with KernelLogger.

## Threat Flags

No new threat surface. T-17-04 (Migration script tampering): accepted — mechanical find-replace verified by CI gate and flutter analyze.

## Next Phase Readiness

- Plan 03 (CI gate in CI pipeline) can integrate `kernel_logger_gate.sh` into CI
- All kernel files now use KernelLogger; lib/kernel/ is fully decoupled from package:logger

---

*Phase: 17-kernellogger*
*Completed: 2026-07-19*

## Self-Check: PASSED

All created files exist:
- `tool/audit/kernel_logger_gate.sh` — FOUND

All task commits exist:
- `204bedf` (feat: migration) — FOUND
- `f6502dd` (chore: gate script) — FOUND

Gate script verification:
- `bash tool/audit/kernel_logger_gate.sh` — PASS (both gates)
