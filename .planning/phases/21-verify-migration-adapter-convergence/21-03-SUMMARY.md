---
phase: 21-verify-migration-adapter-convergence
plan: 03
subsystem: kernel
tags: [diagnostics, lint, debugPrint-cleanup, analyze-fix]
dependency_graph:
  requires: [21-01]
  provides: [VERIFY-05, VERIFY-06]
  affects: [lib/kernel/, analysis_options.yaml]
tech_stack:
  added: []
  patterns: [KernelLogger migration, ambiguous-import resolution]
key_files:
  created: []
  modified:
    - lib/app.dart
    - lib/features/player/deferred_player_feature.dart
    - lib/features/player/player_feature.dart
    - lib/ui/dialogs/settings_panel.dart
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/scanner/folder_scanner.dart
    - lib/kernel/services/global_hotkey_service.dart
    - lib/kernel/utils/log.dart
    - lib/kernel/diagnostics/kernel_logger.dart
    - analysis_options.yaml
    - test/kernel/engine/media_opener_test.dart
decisions:
  - "Migrated 4 files from kernel/utils/log.dart to KernelLogger.I to resolve ambiguous import"
  - "Replaced 11 debugPrint calls in lib/kernel/ with KernelLoggerImpl.I structured logging"
  - "Removed const from error class constructors in test (FileError/CodecError/NetworkError/PlaybackError lack const)"
  - "Documented D14 lint policy as comment in analysis_options.yaml (Flutter analyzer lacks directory-scoped rules)"
metrics:
  duration: ~15min
  completed: "2026-07-20"
  tasks: 2
  files: 11
status: complete
---

# Phase 21 Plan 03: Analyze Cleanup + debugPrint Purge Summary

Fix pre-existing analyze errors and eliminate all debugPrint calls from lib/kernel/, replacing them with KernelLogger structured logging. Add D14 lint policy documentation.

## Tasks Completed

### Task 1: Fix pre-existing analyze errors

**Commit:** `3bdea62`

- Replaced `import kernel/utils/log.dart` with `import kernel/diagnostics/kernel_logger.dart` in 4 files (app.dart, deferred_player_feature.dart, player_feature.dart, settings_panel.dart)
- Migrated `log.w/e/d(...)` calls to `KernelLogger.I.w/e/d(...)` — same API surface
- Removed `const` from `OpenError(FileError(...))` etc. in media_opener_test.dart (error classes lack const constructors)
- Result: 0 errors in lib/ and project test/ (remaining 72 errors are external packages/fullscreen_window/)

### Task 2: Clean debugPrint from lib/kernel/ + lint policy

**Commit:** `dc36e83`

- fvp_engine.dart: 4 debugPrint calls replaced
  - `debugPrint('open() result...')` → `_bundle.logger.d(...)`
  - `debugPrint('play() — state...')` → `_bundle.logger.d(...)`
  - `debugPrint('play() failed...')` → removed (redundant with existing `_bundle.logger.e` above)
  - `debugPrint('dispose: ... listeners')` → `_bundle.logger.w(...)`
- folder_scanner.dart: 1 debugPrint → `KernelLoggerImpl.I.e(...)` + added import
- global_hotkey_service.dart: 5 debugPrint → `KernelLoggerImpl.I.d/i/e(...)` + added import, removed `foundation.dart` import
- log.dart: 1 debugPrint → `KernelLoggerImpl.I.e(...)` + added import
- analysis_options.yaml: Added D14 policy comment documenting lib/kernel/ debugPrint prohibition

## Verification

- `grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart | grep -v '//'` = **0 hits**
- `flutter analyze` lib/ errors = **0** (remaining errors are external packages/fullscreen_window/)
- Contract test (fvp_engine_contract_test.dart): 57 failures are pre-existing mdk.dll FFI loading issue in headless environment (documented in MEMORY.md)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Ambiguous import errors in 4 lib/ files**
- **Found during:** Task 1 execution
- **Issue:** `lib/app.dart`, `lib/features/player/deferred_player_feature.dart`, `lib/features/player/player_feature.dart`, `lib/ui/dialogs/settings_panel.dart` imported both `kernel/utils/log.dart` (exports `Logger log`) and kernel files that export `final log = KernelLogger.I`, causing ambiguous `log` symbol
- **Fix:** Replaced `import kernel/utils/log.dart` with `import kernel/diagnostics/kernel_logger.dart` and migrated `log.w/e/d(...)` to `KernelLogger.I.w/e/d(...)`
- **Files modified:** 4 lib/ files
- **Commit:** `3bdea62`

**2. [Rule 1 - Bug] Const constructor errors in test**
- **Found during:** Task 1 execution
- **Issue:** `test/kernel/engine/media_opener_test.dart` used `const OpenError(FileError(...))` but FileError/CodecError/NetworkError/PlaybackError lack const constructors
- **Fix:** Changed `const` to `final` for 4 error instantiation lines
- **Files modified:** test/kernel/engine/media_opener_test.dart
- **Commit:** `3bdea62`

## Known Stubs

None — all debugPrint calls replaced with working KernelLogger calls.

## Threat Flags

None — no new attack surface introduced. Logging migration uses existing KernelLogger infrastructure.
