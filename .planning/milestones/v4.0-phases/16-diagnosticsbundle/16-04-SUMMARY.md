---
phase: 16-diagnosticsbundle
plan: 04
subsystem: testing
tags: [flutter_test, contract-tests, strangler-fig, kernel-adapter, diagnostics]

# Dependency graph
requires:
  - phase: 16-diagnosticsbundle (16-01)
    provides: KernelAdapter, KernelMode, DelegationPolicy (Strangler Fig seam)
  - phase: 16-diagnosticsbundle (16-02)
    provides: DiagnosticsBundle, KernelLogger, MetricsSlot, EventLogSlot, MemoryMonitorSlot (noop skeleton)
provides:
  - D24 layer 2 — 7 Phase-15 ISP contract test groups mounted against KernelAdapter via factory swap
  - D24 layer 3 / D25 — same() reference-identity test for all 13 EngineStateView ValueNotifier fields
  - D24 layer 1 — full-suite regression gate confirmation (existing baseline stays green)
  - ADAPT-02 diagnostics unit tests — DiagnosticsBundle.noop() construction/dispose + KernelLogger 3-shape signature acceptance
affects: [16-05, 16-03, phase-20-migration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Contract-test factory swap: mount Phase-15 run*ContractTests against a new engine implementation by changing only the factory closure, never the test bodies"
    - "same() reference-identity assertion (package:matcher via flutter_test) as the structural gate against notifier rewrapping"

key-files:
  created:
    - test/adapter/kernel_adapter_contract_test.dart
    - test/adapter/kernel_adapter_identity_test.dart
    - test/diagnostics/diagnostics_bundle_test.dart
    - test/diagnostics/kernel_logger_test.dart
  modified: []

key-decisions:
  - "No adapter-layer openGeneration test created — D20 rules P16 adapter transparent (guards live in old engine fvp_engine.dart:259/267/311/320); ADAPT-04 satisfied by 16-01 KernelMode arbiter + 16-05 D22 grep gate, not by testing nothing here (#8 KISS)"
  - "Texture-channel mock (CreateRT/ReleaseRT on MethodChannel('fvp')) copied verbatim from test/engine/fvp_engine_contract_test.dart into the new contract mount, since KernelAdapter wraps a real FvpEngine and hits the identical headless native-texture gap"
  - "Native DLLs (mdk.dll, fvp.dll, ffmpeg-9.dll, etc.) copied from build/windows/x64/runner/Debug/ into the worktree root to unblock local flutter test runs — matches the documented Phase 15 precedent (15-03-SUMMARY.md), left untracked/unstaged, not part of this plan's files_modified"

patterns-established:
  - "Pattern: contract test reuse via factory-only swap — proven twice now (FvpEngine direct mount, KernelAdapter mount); Phase 20's eventual NewFvpEngine mount can reuse the same run*ContractTests functions unchanged"

requirements-completed: [ADAPT-01, ADAPT-02, ADAPT-03, ADAPT-04]

coverage:
  - id: D1
    description: "7 Phase-15 ISP contract test groups (EngineStateView/PlaybackControl/TrackControl/SubtitleConfig/VideoEffectControl/RendererControl/VolumeControl) pass mounted against KernelAdapter via factory swap only"
    requirement: "ADAPT-01"
    verification:
      - kind: unit
        ref: "test/adapter/kernel_adapter_contract_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 13 EngineStateView ValueNotifier fields forward by reference identity (same()), never rewrapped, through KernelAdapter"
    requirement: "ADAPT-03"
    verification:
      - kind: unit
        ref: "test/adapter/kernel_adapter_identity_test.dart#KernelAdapter forwards EngineStateView notifiers by identity"
        status: pass
    human_judgment: false
  - id: D3
    description: "DiagnosticsBundle.noop() constructs, all 4 slots are non-null callable no-ops, dispose() cascades without throwing"
    requirement: "ADAPT-02"
    verification:
      - kind: unit
        ref: "test/diagnostics/diagnostics_bundle_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "NullKernelLogger accepts all 3 live call shapes for error()/fatal() (both named, stackTrace-only, neither) plus single-positional trace/debug/info/warn"
    requirement: "ADAPT-02"
    verification:
      - kind: unit
        ref: "test/diagnostics/kernel_logger_test.dart"
        status: pass
    human_judgment: false
  - id: D5
    description: "Existing full test suite (1400 tests) stays green after this plan's additions, confirming zero behavior change through the composition seam"
    requirement: "ADAPT-01"
    verification:
      - kind: unit
        ref: "flutter test (full suite)"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-07-18
status: complete
---

# Phase 16 Plan 04: D24 Three-Layer Adapter Tests + Diagnostics Unit Tests Summary

**7 Phase-15 ISP contract groups re-mounted against KernelAdapter via factory swap, a 13-field same() notifier-identity gate, and DiagnosticsBundle/KernelLogger unit tests — all green with zero changes to production code**

## Performance

- **Duration:** 45 min
- **Started:** 2026-07-18T09:27:00Z (approx, first file read)
- **Completed:** 2026-07-18T10:12:13Z
- **Tasks:** 4/4
- **Files modified:** 4 created, 0 production files touched

## Accomplishments

- Mounted all 7 Phase-15 `run*ContractTests` groups against `KernelAdapter` by swapping only the factory closure (`FvpEngine()` → `KernelAdapter(legacy: fvp, migrated: fvp, policy: DelegationPolicy.all(KernelMode.legacy))`) — proves the Strangler Fig seam forwards every ISP sub-interface with zero behavior change (D24 layer 2, ADAPT-01).
- Added the `same()` reference-identity test asserting all 13 `EngineStateView` `ValueNotifier` fields are forwarded by the adapter, never rewrapped — the structural gate against Blocking Constraint #6 (D24 layer 3 / D25, ADAPT-03).
- Added `DiagnosticsBundle` unit tests (noop construction, 4 callable no-op slots, cascading dispose) and `KernelLogger` signature-acceptance tests (all 3 live call shapes for `error()`/`fatal()` from the 84-site D6 census) — ADAPT-02.
- Confirmed the full existing suite (1400 tests) stays green as the baseline regression gate (D24 layer 1) — this worktree does not include 16-03's composition-root swap, so this is the pre-swap baseline confirmation; the orchestrator runs the true post-swap regression after merging 16-03+16-04.
- Deliberately did NOT create an adapter-layer `openGeneration` test file, per explicit plan instruction (D20: P16 adapter is transparent, guards live in the old engine; #8 KISS forbids testing nothing) — ADAPT-04 is satisfied elsewhere (16-01 KernelMode arbiter, 16-05 D22 grep gate).

## Task Commits

All 4 tasks were authored and verified together as a tightly-coupled batch of test-file creations (each task adds test coverage for the same `KernelAdapter`/`DiagnosticsBundle` units produced by 16-01/16-02, and Task 4 is a verification-only gate with no new file), then committed atomically per plan scope:

1. **Tasks 1-4: D24 three-layer adapter tests + diagnostics unit tests** - `99ea128` (test)

**Plan metadata:** (this commit, produced below)

_Note: Tasks 1-3 each produce one or two test files verified independently before the single commit; Task 4 is the full-suite regression verification gate (no new file) confirming the batch introduces no regression._

## Files Created/Modified

- `test/adapter/kernel_adapter_contract_test.dart` - Mounts all 7 Phase-15 ISP contract test groups against `KernelAdapter` via factory swap; copies the `fvp` MethodChannel texture-registration mock verbatim from the FvpEngine analog
- `test/adapter/kernel_adapter_identity_test.dart` - Asserts `same()` reference identity for all 13 `EngineStateView` `ValueNotifier` fields between a wrapped `FvpEngine` and the `KernelAdapter` forwarding it
- `test/diagnostics/diagnostics_bundle_test.dart` - Asserts `DiagnosticsBundle.noop()` constructs, all 4 slots (logger/metrics/eventLog/memoryMonitor) are callable no-ops, and `dispose()` cascades safely
- `test/diagnostics/kernel_logger_test.dart` - Asserts `NullKernelLogger` accepts all 3 live call shapes for `error()`/`fatal()` (both named params, stackTrace-only, neither) plus single-positional `trace`/`debug`/`info`/`warn`

## Decisions Made

- **No adapter-layer `openGeneration` test.** Followed the plan's explicit instruction: D20 rules the Phase 16 adapter transparent (no counter, no guard — `open()` forwards 100%; the real guard lives in the old engine at `fvp_engine.dart:259/267/311/320`). Adding such a test in this plan would test nothing per #8 KISS. ADAPT-04 ("single arbiter, no dual source") is satisfied by 16-01's `KernelMode` arbiter, the D21 class-level P20 migration placeholder, and 16-05's D22 grep gate (0 hits) — not by an adapter-layer test here.
- **Texture-channel mock copied verbatim.** `KernelAdapter` wraps a real `FvpEngine`, so the new contract mount hits the identical headless-native-texture gap (`MissingPluginException` on `CreateRT`/`ReleaseRT`) as the pre-existing `test/engine/fvp_engine_contract_test.dart` mount. Copied the mock function, channel constant, and fake-texture-id counter unchanged to preserve D13 (contract tests gate the real `FvpEngine`, never a fake).
- **Native DLLs copied into the worktree root (environment setup, not a code change).** Running the new tests initially failed with `Failed to load dynamic library 'mdk.dll'` — traced through `package:fvp` to the `FvpEngine()` constructor. Confirmed via the pre-existing baseline test (identical failure in both the worktree and the main repo checkout) that this is not caused by the new test files, and found the exact documented precedent in Phase 15 (`15-03-SUMMARY.md`, `15-VERIFICATION.md`): headless `flutter test` needs the native DLLs from `build/windows/x64/runner/Debug/` present in the working directory root. Copied 13 DLL files accordingly; they remain untracked (`git status --short` shows `??`) and were not staged in the commit — a pure local dev-environment fix matching prior precedent, not a production code change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, environment setup] Native DLL dependency missing for headless `flutter test`**
- **Found during:** Task 1 (running the new contract-test mount for the first time)
- **Issue:** All 4 new test files (and the pre-existing `fvp_engine_contract_test.dart` baseline) failed with `Invalid argument(s): Failed to load dynamic library 'mdk.dll': The specified module could not be found.` inside `package:fvp/src/lib.dart` → `FvpEngine()` constructor. Confirmed via baseline comparison (same failure in the untouched worktree AND the main repo) that this was a pre-existing environment gap, not introduced by the new tests.
- **Fix:** Copied 13 native DLLs (`mdk.dll`, `fvp.dll`, `ffmpeg-9.dll`, `libass.dll`, `mdk-braw.dll`, `mdk-nvjp2k.dll`, `mdk-r3d.dll`, `flutter_windows.dll`, + 5 plugin DLLs) from `build/windows/x64/runner/Debug/` into the worktree root, matching the exact Phase 15 precedent (`15-03-SUMMARY.md`).
- **Files modified:** None (DLLs copied, left untracked/unstaged — not part of `files_modified`, not covered by `.gitignore`, a pre-existing gap left unfixed per scope boundary, consistent with Phase 15's handling)
- **Verification:** Baseline `fvp_engine_contract_test.dart` → 57/57 pass; the 4 new files → 68/68 pass; full suite → 1400/1400 pass, all after the DLL copy.
- **Committed in:** N/A (DLLs intentionally not staged/committed — untracked local build artifacts)

---

**Total deviations:** 1 auto-fixed (1 blocking/environment)
**Impact on plan:** The DLL copy is a local dev-environment step required to run any `flutter test` involving `FvpEngine` construction on this machine — it does not touch production code, test code, or the plan's `files_modified` list. No scope creep.

## Issues Encountered

- **Isolation boundary confirmed working as designed:** This worktree does not contain 16-03's composition-root swap (`lib/kernel/player_services.dart` untouched, as instructed). Task 4's `flutter test` full-suite run is therefore the pre-swap baseline regression (1400/1400 green), not the true post-swap regression. The orchestrator will run the true composition-root-swap regression after ff-merging 16-03 and 16-04 together. This is expected isolation behavior, not a deviation or gap.
- No other issues — `flutter analyze test/adapter/ test/diagnostics/` was clean both before and after `dart format`; no compile errors; no logic errors.

## User Setup Required

None - no external service configuration required. (The native-DLL local dev-environment step above is a pre-existing, previously-documented machine-local setup gap from Phase 15, not a new external service dependency introduced by this plan.)

## Next Phase Readiness

- D24's three-layer test composition is now fully in place for the `KernelAdapter` seam: layer 1 (baseline regression), layer 2 (7 ISP contract groups via factory swap), layer 3/D25 (13-field notifier identity). Phase 20's eventual `NewFvpEngine` mount can reuse the identical `run*ContractTests` functions with only a factory swap, following the pattern now proven twice.
- ADAPT-02 diagnostics skeleton is unit-tested and ready for Phase 17 to wire a real sink-backed `KernelLogger` implementation behind the same interface.
- No blockers. Ready for the orchestrator to ff-merge 16-03 + 16-04 and run the true post-swap full-suite regression.

---
*Phase: 16-diagnosticsbundle*
*Completed: 2026-07-18*

## Self-Check: PASSED

- FOUND: test/adapter/kernel_adapter_contract_test.dart
- FOUND: test/adapter/kernel_adapter_identity_test.dart
- FOUND: test/diagnostics/diagnostics_bundle_test.dart
- FOUND: test/diagnostics/kernel_logger_test.dart
- FOUND: commit 99ea128 in git log
