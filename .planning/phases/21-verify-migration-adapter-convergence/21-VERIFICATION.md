---
phase: 21-verify-migration-adapter-convergence
verified: 2026-07-20T15:15:00Z
status: gaps_found
score: "5/6"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "4/6"
  gaps_closed:
    - "BLOCKER 1: DelegationPolicy flipped to all-migrated (Plan 07, commit 5ac51ad)"
  gaps_remaining:
    - "BLOCKER 2: kernel/ coverage 57.6% vs target >= 80% (Plan 08 added 40 tests, +2.6pp only)"
  regressions: []
gaps:
  - truth: "kernel/ coverage >= 80% (VERIFY-05)"
    status: failed
    reason: "Coverage 57.6% (1734/3013 lines). Plan 08 added 40 tests (kernel_adapter_routing_test 26 + delegation_policy_test 14) but only raised from 55% to 57.6%. Key uncovered modules: playback_controller.dart orchestration paths, engine_state_machine.dart edge cases, media_engine.dart abstract interface, fvp_engine.dart error recovery paths. Needs ~670 additional lines covered (~22% of 3013)."
    artifacts:
      - path: "lib/kernel/services/playback_controller.dart"
        issue: "Orchestration paths partially covered -- many edge cases untested"
      - path: "lib/kernel/engine/engine_state_machine.dart"
        issue: "State transition edge cases untested (error recovery, disposed transitions)"
      - path: "lib/kernel/engine/fvp_engine.dart"
        issue: "Error recovery paths and mdk callback marshalling untested (requires mdk.dll or extensive mocking)"
    missing:
      - "More unit tests for playback_controller.dart uncovered paths"
      - "EngineStateMachine edge case tests (error recovery, disposed state transitions)"
      - "Consider that many kernel/ files require mdk.dll for meaningful testing, making 80% extremely difficult in headless CI"
---

# Phase 21: Test & Migration Verification + Adapter Convergence -- Verification Report

**Phase Goal:** Verify post-cutover new-kernel/old-kernel behavioral parity (zero dual-track diffs), derive migration order from dependency graph, guard adapter layer convergence with explicit deletion gate checklist (independent commit, never bundled with features), release build smoke passes.
**Verified:** 2026-07-20T15:15:00Z
**Status:** gaps_found
**Re-verification:** Yes -- gap closure after Plans 07+08

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Phase 15 contract tests pass against current FvpEngine (VERIFY-01) | UNCERTAIN | Tests exist at `test/engine/fvp_engine_contract_test.dart` (7 groups). Cannot run in headless CI -- mdk.dll FFI load fails at `Player()` construction. Pre-existing environment limitation documented in MEMORY.md. On real Windows desktop with mdk.dll, tests would execute. |
| 2 | Dual-track regression suite -- all-legacy vs all-migrated produce identical output (VERIFY-02) | UNCERTAIN | Test files exist: `test/regression/dual_track_regression_test.dart` (339 lines, 26 tests in 2 groups), `test/regression/regression_fixture.dart` (114 lines), `test/regression/diff_report.dart` (75 lines). DiffReport unit tests pass (6/6). Regression tests skip gracefully when mdk.dll unavailable. Structure is sound but behavioral parity cannot be proven in headless CI. |
| 3 | Migration order derived from dependency graph: leaf -> orchestrator -> state manager -> UI binding (VERIFY-03) | VERIFIED | `docs/migration-order.md` exists (220 lines). Contains codegraph-derived 4-layer dependency graph with ASCII diagram, per-layer component lists, Phase 20 D11 comparison, and risk assessment. Generated via codegraph MCP tools. |
| 4 | Adapter deletion gate checklist all executable (VERIFY-04, D9) | VERIFIED | `tool/audit/phase21_gates.sh` exists and executable. All 4 gates PASS: GATE 1 (DelegationPolicy all migrated), GATE 2 (dual-track exit 0), GATE 3 (OpenGenerationTracker in engine layer), GATE 4 (rollback path audited). |
| 5 | Release build smoke script executable (VERIFY-06, D15) | VERIFIED | `tool/audit/phase21_release_gate.sh` exists (executable, 3357 bytes). Runs `flutter build windows --release` then scans build artifacts for debugPrint leaks. Summary 21-06 confirms zero leaks found. |
| 6 | Rollback script executable, reverts DelegationPolicy to all-legacy (D16, D19) | VERIFIED | `tool/audit/rollback.sh` exists (executable, `--dry-run` mode works). `docs/ROLLBACK.md` exists (91 lines) with trigger conditions (D17), rollback steps, recovery procedure. |
| 7 | Adapter tests deleted, contract tests preserved (D8) | VERIFIED | `test/adapter/kernel_adapter_contract_test.dart` deleted. `test/adapter/kernel_adapter_identity_test.dart` deleted. `test/contracts/contract_test_runner.dart` preserved (1029 bytes). |
| 8 | flutter analyze zero errors (VERIFY-05) | VERIFIED | `flutter analyze` output: 15 issues (all info/warning level), zero errors. |
| 9 | lib/kernel/ zero debugPrint calls (VERIFY-06 prerequisite) | VERIFIED | `grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart | grep -v '//'` = 0 hits. All 11 debugPrint calls replaced with KernelLoggerImpl structured logging. D14 lint policy documented in analysis_options.yaml. |
| 10 | DelegationPolicy all 7 per-capability fields are KernelMode.migrated | VERIFIED | `lib/kernel/player_services.dart` lines 133-157: explicit `DelegationPolicy` constructor with all 7 fields = `KernelMode.migrated` + 26 migratedMethods. Plan 07 closed previous BLOCKER 1. |
| 11 | kernel/ coverage >= 80% (VERIFY-05) | FAILED | Coverage 57.6% (1734/3013 lines). Plan 08 added 40 test cases but only raised from 55% to 57.6%. Key uncovered: playback_controller orchestration, engine_state_machine edge cases, fvp_engine error recovery. Many kernel modules require mdk.dll for meaningful testing. |
| 12 | KernelAdapter routing logic has unit test coverage | VERIFIED | `test/kernel/adapter/kernel_adapter_routing_test.dart` (478 lines, 26 tests) covers per-method routing, capability field routing, dispose behavior, DiagnosticsBundle forwarding. All 26 tests pass. |
| 13 | DelegationPolicy construction behavior has unit test coverage | VERIFIED | `test/kernel/adapter/delegation_policy_test.dart` (240 lines, 14 tests) covers all() constructor, per-field constructor, migratedMethods behavior, const constructibility. All 14 tests pass. |

**Score:** 5/6 must-haves verified (VERIFY-01, VERIFY-02 environment-blocked; VERIFY-05 coverage FAILED)

### Deferred Items

None -- the coverage gap (BLOCKER 2) is not addressed by any later phase in the milestone.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `test/engine/fvp_engine_contract_test.dart` | 7 group contract test mount point | VERIFIED | Exists, 7 run*ContractTests calls present |
| `test/regression/dual_track_regression_test.dart` | Parameterized dual-track regression | VERIFIED | 339 lines, 26 tests in 2 groups (all-legacy / all-migrated) |
| `test/regression/regression_fixture.dart` | Shared RegressionFixture class | VERIFIED | 114 lines, engine factory injection + assertState + assertNoDiffs |
| `test/regression/diff_report.dart` | DiffEntry + DiffReport | VERIFIED | 75 lines, toString formatting + hasDiffs |
| `docs/migration-order.md` | Migration order from dependency graph | VERIFIED | 220 lines, 4-layer order with ASCII diagram |
| `tool/audit/phase21_gates.sh` | 4-item adapter deletion gate script | VERIFIED | Executable, 4 gates all PASS |
| `tool/audit/phase21_release_gate.sh` | Release build smoke script | VERIFIED | Executable, flutter build + grep artifacts |
| `tool/audit/rollback.sh` | Emergency rollback script | VERIFIED | Executable, --dry-run works, sed-based DelegationPolicy revert |
| `docs/ROLLBACK.md` | Rollback documentation | VERIFIED | 91 lines, trigger conditions + steps + recovery |
| `lib/kernel/player_services.dart` | DelegationPolicy all-migrated | VERIFIED | 7 fields = KernelMode.migrated, 26 migratedMethods |
| `test/kernel/adapter/kernel_adapter_routing_test.dart` | KernelAdapter routing tests | VERIFIED | 478 lines, 26 tests, all pass |
| `test/kernel/adapter/delegation_policy_test.dart` | DelegationPolicy tests | VERIFIED | 240 lines, 14 tests, all pass |
| `analysis_options.yaml` | D14 lint policy comment | VERIFIED | Policy comment documents lib/kernel/ debugPrint prohibition |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `phase21_gates.sh` | DelegationPolicy migratedMethods check | GATE 1 grep | VERIFIED | GATE 1 PASS: all 7 fields = KernelMode.migrated |
| `phase21_gates.sh` | dual_track_regression_test green check | GATE 2 flutter test | VERIFIED | GATE 2 PASS: exit 0 (26 skipped, mdk.dll) |
| `phase21_gates.sh` | OpenGenerationTracker in engine check | GATE 3 grep | VERIFIED | GATE 3 PASS: found in engine_state_machine.dart |
| `phase21_gates.sh` | rollback.sh + ROLLBACK.md check | GATE 4 test -f | VERIFIED | GATE 4 PASS: both exist |
| `rollback.sh` | player_services.dart DelegationPolicy revert | sed replacement | VERIFIED | --dry-run shows correct diff |
| `KernelAdapter` routing tests | FakeEngine call tracking | migratedMethods set | VERIFIED | 26 tests verify per-method routing to correct engine |

### Data-Flow Trace (Level 4)

Not applicable -- Phase 21 produces test infrastructure, gate scripts, and documentation, not UI components or data-rendering artifacts.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Gate script all 4 pass | `bash tool/audit/phase21_gates.sh` | "ALL 4 GATES PASSED" | PASS |
| Rollback dry-run works | `bash tool/audit/rollback.sh --dry-run` | Shows correct DelegationPolicy revert diff | PASS |
| KernelAdapter routing tests | `flutter test test/kernel/adapter/kernel_adapter_routing_test.dart` | 26/26 pass | PASS |
| DelegationPolicy tests | `flutter test test/kernel/adapter/delegation_policy_test.dart` | 14/14 pass | PASS |
| DiffReport unit tests | `flutter test test/regression/diff_report_test.dart` | 6/6 pass | PASS |
| flutter analyze clean | `flutter analyze` | 0 errors, 15 info/warning | PASS |
| debugPrint zero in kernel/ | `grep -rn 'debugPrint(' lib/kernel/` | 0 hits | PASS |
| kernel/ coverage | `flutter test --coverage` + parse lcov.info | 57.6% (target >= 80%) | FAIL |

### Probe Execution

Not applicable -- no probes declared in Phase 21 plans.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| VERIFY-01 | 21-01 | Contract tests pass against NewFvpEngine | UNCERTAIN | Tests exist, mdk.dll blocks execution in headless env |
| VERIFY-02 | 21-02 | Dual-track regression suite zero diff | UNCERTAIN | Tests exist (26 tests, 2 groups), mdk.dll blocks execution in headless env |
| VERIFY-03 | 21-05 | Migration order from dependency graph | SATISFIED | docs/migration-order.md (220 lines, codegraph-derived) |
| VERIFY-04 | 21-04, 21-07 | Adapter deletion gate checklist | SATISFIED | phase21_gates.sh 4/4 PASS, rollback.sh + ROLLBACK.md exist |
| VERIFY-05 | 21-03, 21-06, 21-08 | flutter analyze clean + kernel/ >= 80% | PARTIAL | analyze clean (0 errors), coverage 57.6% (BLOCKED) |
| VERIFY-06 | 21-03, 21-04, 21-06 | Release build zero debugPrint | SATISFIED | 0 debugPrint in kernel/, release gate script exists, summary confirms zero leaks |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | | | | |

No debt markers (TBD/FIXME/XXX), no stub patterns, no placeholder text found in Phase 21 artifacts.

### Human Verification Required

#### 1. Contract tests on real Windows desktop

**Test:** Run `flutter test test/engine/fvp_engine_contract_test.dart` on a Windows machine with mdk.dll on PATH
**Expected:** All 7 contract test groups (EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl) PASS
**Why human:** mdk.dll FFI load fails in headless CI; requires native MDK runtime on PATH

#### 2. Dual-track regression on real Windows desktop

**Test:** Run `flutter test test/regression/dual_track_regression_test.dart` on a Windows machine with mdk.dll on PATH
**Expected:** All 26 tests pass in both all-legacy and all-migrated groups, DiffReport shows zero differences
**Why human:** Tests skip gracefully in headless env; behavioral parity requires real engine execution

### Gaps Summary

**1 gap blocks goal achievement:**

**BLOCKER 2: kernel/ coverage 57.6% vs target >= 80% (VERIFY-05)**

Plan 08 added 40 pure-Dart unit tests (26 for KernelAdapter routing, 14 for DelegationPolicy construction) but coverage only increased from 55% to 57.6% (+2.6 percentage points). The target requires covering approximately 670 additional lines (22% of 3013 total).

Key uncovered areas:
- `playback_controller.dart` -- orchestration paths (open/seek/auto-advance edge cases)
- `engine_state_machine.dart` -- state transition edge cases (error recovery, disposed transitions)
- `fvp_engine.dart` -- error recovery paths, mdk callback marshalling (requires mdk.dll or extensive FFI mocking)
- `media_engine.dart` -- abstract interface (0% by definition)

**Consideration:** Many kernel/ modules deeply depend on mdk.dll FFI. Reaching 80% coverage in headless CI may require either (a) extensive FFI mocking infrastructure or (b) running coverage on a real Windows desktop with mdk.dll available. The 80% target may need to be re-evaluated for feasibility in CI-only environments.

---

_Verified: 2026-07-20T15:15:00Z_
_Verifier: Claude (gsd-verifier)_
