---
phase: 21-verify-migration-adapter-convergence
verified: 2026-07-20T11:10:08Z
status: gaps_found
score: "3/6"
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: "5/6"
  gaps_closed:
    - "BLOCKER 1: DelegationPolicy flipped to all-migrated (Plan 07, commit 5ac51ad) — confirmed still all-migrated"
    - "Plan 09 added ~75 pure Dart test cases across 6 new + 8 extended test files"
  gaps_remaining:
    - "BLOCKER 2: kernel/ coverage 57.6% (stale lcov) vs target >= 80%. Plan 09 estimated ~61.4% but measurement blocked by disk space. mdk.dll bottleneck (~590 lines) makes 80% unreachable without DI refactor."
    - "Flutter 3.44.6 SDK star_border.dart Matrix4 bug blocks ALL test execution — VERIFY-01, VERIFY-02, VERIFY-04 GATE 2 cannot be verified"
  regressions: []
gaps:
  - truth: "kernel/ coverage >= 80% (VERIFY-05)"
    status: failed
    reason: "Coverage 57.6% (1734/3013 lines) per stale lcov.info. Plan 09 added ~75 test cases but disk space prevented re-measurement. Estimated ceiling ~70% due to mdk.dll bottleneck (590 lines in fvp_engine/media_opener/position_poller/win32_display_enumerator/network_configurator/track_manager/mdk_player_proxy). Even with 100% coverage of non-mdk code (~2423 lines), max reachable is ~80.4% — barely at target but requires zero gaps in all other modules."
    artifacts:
      - path: "lib/kernel/engine/fvp_engine.dart"
        issue: "303 lines at 0.7% coverage — requires mdk.Player mock"
      - path: "lib/kernel/engine/media_opener.dart"
        issue: "85 lines at 0% — requires mdk.Player mock"
      - path: "lib/kernel/engine/position_poller.dart"
        issue: "60 lines at 0% — requires mdk.Player mock"
      - path: "coverage/lcov.info"
        issue: "Stale data from before Plan 09 — actual coverage unknown"
    missing:
      - "Run flutter test --coverage when disk space available to get actual post-Plan-09 coverage"
      - "Consider mdk.Player DI in FvpEngine factory constructor for ~200 additional testable lines"
      - "Alternatively adjust target to 75% excluding mdk-dependent files from denominator"
  - truth: "Phase 15 contract tests pass against current FvpEngine (VERIFY-01)"
    status: failed
    reason: "Test file exists (test/engine/fvp_engine_contract_test.dart, 7 groups) but cannot compile — Flutter 3.44.6 SDK star_border.dart Matrix4 getter error affects ALL test compilation. This is a pre-existing Flutter SDK regression, not a code issue introduced by this phase."
    artifacts:
      - path: "test/engine/fvp_engine_contract_test.dart"
        issue: "Cannot compile due to Flutter SDK star_border.dart Matrix4 bug"
    missing:
      - "Flutter SDK fix for star_border.dart Matrix4 issue, or downgrade to a working SDK version"
  - truth: "Dual-track regression suite — all-legacy vs all-migrated produce identical output (VERIFY-02)"
    status: failed
    reason: "Test files exist (dual_track_regression_test.dart 339 lines/26 tests, regression_fixture.dart 114 lines, diff_report.dart 75 lines) but cannot compile — same Flutter SDK star_border.dart Matrix4 bug. Structure is sound but behavioral parity cannot be proven."
    artifacts:
      - path: "test/regression/dual_track_regression_test.dart"
        issue: "Cannot compile due to Flutter SDK star_border.dart Matrix4 bug"
      - path: "test/regression/diff_report_test.dart"
        issue: "Cannot compile due to Flutter SDK star_border.dart Matrix4 bug"
    missing:
      - "Flutter SDK fix for star_border.dart Matrix4 issue"
behavior_unverified_items:
  - truth: "Phase 15 contract tests pass against current FvpEngine (VERIFY-01)"
    test: "Run flutter test test/engine/fvp_engine_contract_test.dart"
    expected: "7 groups of contract tests pass against FvpEngine"
    why_human: "Flutter 3.44.6 SDK star_border.dart Matrix4 bug blocks all test compilation — cannot verify programmatically"
  - truth: "Dual-track regression suite produces zero diffs (VERIFY-02)"
    test: "Run flutter test test/regression/dual_track_regression_test.dart"
    expected: "26 tests pass, all-legacy vs all-migrated output identical"
    why_human: "Same Flutter SDK bug blocks compilation; even if fixed, tests may need mdk.dll on Windows desktop"
human_verification:
  - test: "Run flutter test on a machine with working Flutter SDK (not 3.44.6 or with star_border fix)"
    expected: "All kernel/ tests pass, coverage measured above 61%"
    why_human: "Flutter SDK regression blocks all test execution on current machine"
  - test: "Run flutter test --coverage and inspect lcov.info for kernel/ coverage percentage"
    expected: "Coverage percentage reflects Plan 09's ~75 new test cases"
    why_human: "Disk space exhaustion prevented coverage measurement; need fresh run"
---

# Phase 21: Test & Migration Verification + Adapter Convergence -- Verification Report

**Phase Goal:** Verify post-cutover new-kernel/old-kernel behavioral parity (zero dual-track diffs), derive migration order from dependency graph, guard adapter layer convergence with explicit deletion gate checklist (independent commit, never bundled with features), release build smoke passes.
**Verified:** 2026-07-20T11:10:08Z
**Status:** gaps_found
**Re-verification:** Yes -- gap closure after Plans 07+08+09

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Phase 15 contract tests pass against current FvpEngine (VERIFY-01) | PRESENT_BEHAVIOR_UNVERIFIED | Test file exists (`test/engine/fvp_engine_contract_test.dart`, 7 groups). Cannot compile -- Flutter 3.44.6 SDK `star_border.dart` Matrix4 getter error affects ALL test compilation. |
| 2 | Dual-track regression suite -- all-legacy vs all-migrated produce identical output (VERIFY-02) | PRESENT_BEHAVIOR_UNVERIFIED | Test files exist (339 lines, 26 tests). DiffReport unit test structure verified. Cannot compile -- same SDK bug. |
| 3 | Migration order derived from dependency graph: leaf -> orchestrator -> state manager -> UI binding (VERIFY-03) | VERIFIED | `docs/migration-order.md` exists (220 lines). Contains codegraph-derived 4-layer dependency graph with ASCII diagram, per-layer component lists, Phase 20 D11 comparison. |
| 4 | Adapter deletion gate checklist all executable (VERIFY-04) | VERIFIED (partial) | `tool/audit/phase21_gates.sh` runs 4 gates. GATE 1 PASS (DelegationPolicy all migrated), GATE 2 FAIL (SDK bug blocks dual_track test), GATE 3 PASS (OpenGenerationTracker in engine layer), GATE 4 PASS (rollback.sh+ROLLBACK.md exist). GATE 2 failure is SDK bug, not code issue. |
| 5 | Release build smoke script executable (VERIFY-06) | VERIFIED | `tool/audit/phase21_release_gate.sh` exists (executable). Summary 21-06 confirms zero debugPrint leaks in release build. |
| 6 | Rollback script executable, reverts DelegationPolicy to all-legacy | VERIFIED | `tool/audit/rollback.sh` exists (executable). `docs/ROLLBACK.md` exists (91 lines) with trigger conditions, rollback steps, recovery procedure. |
| 7 | Adapter tests deleted, contract tests preserved | VERIFIED | Adapter test files deleted. `test/contracts/contract_test_runner.dart` preserved. KernelAdapter routing tests (540 lines, 26 tests) and DelegationPolicy tests (240 lines, 14 tests) exist. |
| 8 | flutter analyze zero errors in lib/kernel/ | VERIFIED | `flutter analyze` shows 340 issues all in test files (DropTarget/window_manager/shared_preferences dependencies), zero errors in `lib/kernel/`. |
| 9 | lib/kernel/ zero debugPrint calls | VERIFIED | `grep -rn 'debugPrint(' lib/kernel/ | grep -v kernel_logger.dart` = 0 hits. All debugPrint replaced with KernelLoggerImpl. |
| 10 | DelegationPolicy all 7 fields are KernelMode.migrated | VERIFIED | `lib/kernel/player_services.dart`: explicit DelegationPolicy constructor with all 7 fields = KernelMode.migrated + 26 migratedMethods. |
| 11 | kernel/ coverage >= 80% (VERIFY-05) | FAILED | Coverage 57.6% (1734/3013 lines) per stale lcov.info. Plan 09 added ~75 test cases but disk space prevented re-measurement. mdk.dll bottleneck (~590 lines) makes 80% unreachable. |
| 12 | KernelAdapter routing logic has unit test coverage | VERIFIED | `test/kernel/adapter/kernel_adapter_routing_test.dart` (540 lines, 26 tests) covers per-method routing, capability field routing, dispose behavior. |
| 13 | DelegationPolicy construction behavior has unit test coverage | VERIFIED | `test/kernel/adapter/delegation_policy_test.dart` (240 lines, 14 tests) covers all() constructor, per-field constructor, migratedMethods behavior. |
| 14 | Plan 09 new test files exist and are substantive | VERIFIED | 6 new files (670 lines, 70 tests): breakpoint_saver(11), player_services(5), theme_service(13), debug_exporter(8), window_persistence(9), clock(24). All use FakeEngine + no mdk.dll dependency. |

**Score:** 3/6 must-haves verified (VERIFY-03, VERIFY-04, VERIFY-06); 2 behavior-unverified (VERIFY-01, VERIFY-02); 1 failed (VERIFY-05)

### Deferred Items

None -- the coverage gap (BLOCKER 2) is not addressed by any later phase in the milestone (Phase 22 is documentation only).

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `test/engine/fvp_engine_contract_test.dart` | 7 group contract test mount point | VERIFIED | Exists, 7 run*ContractTests calls present |
| `test/regression/dual_track_regression_test.dart` | Parameterized dual-track regression | VERIFIED | 339 lines, 26 tests in 2 groups |
| `test/regression/regression_fixture.dart` | Shared RegressionFixture class | VERIFIED | 114 lines, engine factory injection |
| `test/regression/diff_report.dart` | DiffEntry + DiffReport | VERIFIED | 75 lines, toString formatting + hasDiffs |
| `docs/migration-order.md` | Migration order from dependency graph | VERIFIED | 220 lines, 4-layer order with ASCII diagram |
| `tool/audit/phase21_gates.sh` | 4-item adapter deletion gate script | VERIFIED | Executable, 4 gates (3 PASS, 1 SDK-blocked) |
| `tool/audit/phase21_release_gate.sh` | Release build smoke script | VERIFIED | Executable, flutter build + grep artifacts |
| `tool/audit/rollback.sh` | Emergency rollback script | VERIFIED | Executable, --dry-run works |
| `docs/ROLLBACK.md` | Rollback documentation | VERIFIED | 91 lines, trigger conditions + steps |
| `lib/kernel/player_services.dart` | DelegationPolicy all-migrated | VERIFIED | 7 fields = KernelMode.migrated |
| `test/kernel/adapter/kernel_adapter_routing_test.dart` | KernelAdapter routing tests | VERIFIED | 540 lines, 26 tests |
| `test/kernel/adapter/delegation_policy_test.dart` | DelegationPolicy construction tests | VERIFIED | 240 lines, 14 tests |
| `test/kernel/services/breakpoint_saver_test.dart` | BreakpointSaver tests (Plan 09) | VERIFIED | 157 lines, 11 tests |
| `test/kernel/player_services_test.dart` | PlayerServices tests (Plan 09) | VERIFIED | 65 lines, 5 tests |
| `test/kernel/services/theme_service_test.dart` | ThemeService tests (Plan 09) | VERIFIED | 107 lines, 13 tests |
| `test/kernel/utils/debug_exporter_test.dart` | DebugExporter tests (Plan 09) | VERIFIED | 92 lines, 8 tests |
| `test/kernel/bridge/window_persistence_test.dart` | WindowPersistence tests (Plan 09) | VERIFIED | 96 lines, 9 tests |
| `test/kernel/diagnostics/clock_test.dart` | Clock/Rss/Metrics tests (Plan 09) | VERIFIED | 153 lines, 24 tests |
| `coverage/lcov.info` | Coverage data | STALE | 57.6% -- data from before Plan 09 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| FakeEngine | PlayerServices/BreakpointSaver tests | Constructor injection | VERIFIED | All Plan 09 tests use FakeEngine, no mdk.dll |
| fakeAsync | PositionPoller/AutoAdvancePolicy tests | Timer simulation | VERIFIED | Timer-based tests use fakeAsync pattern |
| KernelAdapter | DelegationPolicy | Per-method routing | VERIFIED | Routing tests verify delegation |
| DelegationPolicy | FvpEngine | KernelMode.migrated | VERIFIED | All 7 fields = migrated |
| phase21_gates.sh | player_services.dart | grep KernelMode.migrated | VERIFIED | GATE 1 reads live DelegationPolicy |
| rollback.sh | player_services.dart | sed replacement | VERIFIED | Script reverts DelegationPolicy |

### Data-Flow Trace (Level 4)

Not applicable -- Phase 21 produces test infrastructure and verification tools, not data-rendering components.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| flutter analyze on lib/kernel/ | `flutter analyze lib/kernel/` | 0 errors in kernel/ | PASS |
| debugPrint absence in kernel/ | `grep -rn 'debugPrint(' lib/kernel/` | 0 hits (excluding kernel_logger) | PASS |
| DelegationPolicy all-migrated | `grep 'KernelMode.migrated' lib/kernel/player_services.dart` | 7 fields confirmed | PASS |
| phase21_gates.sh execution | `bash tool/audit/phase21_gates.sh` | 3/4 PASS (GATE 2 SDK-blocked) | PARTIAL |
| Any flutter test execution | `flutter test test/kernel/services/breakpoint_saver_test.dart` | Matrix4 compilation error | FAIL (SDK bug) |

### Probe Execution

No probes declared in PLAN files. `tool/audit/phase21_gates.sh` and `tool/audit/phase21_release_gate.sh` serve as gate scripts but are not conventional `probe-*.sh` files.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| VERIFY-01 | 21-01, 21-03 | Contract tests pass against NewFvpEngine | UNCERTAIN | Test file exists, 7 groups. Cannot run -- Flutter SDK Matrix4 bug. |
| VERIFY-02 | 21-02, 21-04 | Dual-track regression suite, zero diffs | UNCERTAIN | Test files exist (26 tests). Cannot run -- same SDK bug. |
| VERIFY-03 | 21-05 | Migration order from dependency graph | SATISFIED | `docs/migration-order.md` (220 lines, codegraph-derived) |
| VERIFY-04 | 21-07, 21-08, 21-09 | Adapter deletion gate checklist | SATISFIED (partial) | Gates script runs. GATE 2 blocked by SDK bug. |
| VERIFY-05 | 21-06, 21-09 | flutter analyze clean + kernel/ >= 80% | PARTIALLY SATISFIED | analyze clean in kernel/. Coverage 57.6% vs 80% target. |
| VERIFY-06 | 21-06 | Release build smoke, zero debugPrint | SATISFIED | Release gate script confirmed zero leaks. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| coverage/lcov.info | N/A | Stale data | INFO | Coverage data predates Plan 09; actual improvement unknown |

### Human Verification Required

### 1. Flutter SDK Matrix4 Bug Resolution

**Test:** Run `flutter test test/kernel/services/breakpoint_saver_test.dart` on a machine with working Flutter SDK (not 3.44.6, or with star_border fix)
**Expected:** All tests compile and pass
**Why human:** Flutter 3.44.6 SDK has a regression in `star_border.dart` that breaks ALL test compilation. This is an external SDK issue, not a project code issue.

### 2. Coverage Measurement

**Test:** Run `flutter test --coverage` when disk space is available, then check `coverage/lcov.info` for kernel/ coverage percentage
**Expected:** Coverage reflects Plan 09's ~75 new test cases (estimated ~61.4%)
**Why human:** Disk space exhaustion prevented coverage measurement during Plan 09 execution.

### 3. Contract Tests Behavioral Verification

**Test:** Run `flutter test test/engine/fvp_engine_contract_test.dart` on a Windows machine with mdk.dll available
**Expected:** All 7 contract test groups pass against FvpEngine
**Why human:** Requires mdk.dll (native video decoder library) which is unavailable in headless CI.

### Gaps Summary

Two gaps block full verification:

1. **Coverage gap (VERIFY-05):** kernel/ coverage at 57.6% vs 80% target. Plan 09 added ~75 pure Dart test cases but the mdk.dll bottleneck (~590 lines in 7 files) makes 80% extremely difficult to reach. Estimated ceiling is ~70% without mdk.Player DI refactor. Coverage measurement itself was blocked by disk space exhaustion, so the actual post-Plan-09 number is unknown.

2. **Test execution blocked by Flutter SDK bug:** Flutter 3.44.6 has a regression in `star_border.dart` (Matrix4 getter undefined) that prevents ALL test compilation. This blocks verification of VERIFY-01 (contract tests), VERIFY-02 (dual-track regression), and VERIFY-04 GATE 2. The test files exist and are substantive, but behavioral verification requires a working Flutter SDK.

Both gaps are environmental/infrastructure issues (SDK bug, disk space, mdk.dll availability) rather than code quality issues. The code artifacts are all present, substantive, and correctly structured.

---

_Verified: 2026-07-20T11:10:08Z_
_Verifier: Claude (gsd-verifier)_
