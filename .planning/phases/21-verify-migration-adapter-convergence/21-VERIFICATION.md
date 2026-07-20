---
phase: 21-verify-migration-adapter-convergence
status: gaps_found
score: "4/6"
verified: "2026-07-20"
---

# Phase 21 Verification Report

## Verified (4/6)

| # | Gate | Requirement | Result |
|---|------|------------|--------|
| 1 | flutter analyze | VERIFY-05 | PASS — 0 errors, 13 info-level warnings |
| 2 | Dual-track regression exit 0 | VERIFY-02 | PASS — 26 tests gracefully skipped (mdk.dll) |
| 3 | Release gate | VERIFY-06 | PASS — build succeeded + zero debugPrint leaks |
| 4 | Guard + rollback paths | VERIFY-04 | PASS — 3/4 gates pass |

## Blockers (2)

### BLOCKER 1: DelegationPolicy not migrated (GATE 1 FAIL)

**File:** `lib/kernel/player_services.dart` line 126
**Current:** `policy: const DelegationPolicy.all(KernelMode.legacy)`
**Required:** All 7 capability fields must use `KernelMode.migrated`
**Requirement:** VERIFY-03, VERIFY-04

The adapter is still routing ALL capabilities (stateView, playback, track, subtitle, videoEffect, renderer, volume) through the legacy path. This means Phase 20's migration work is not activated.

### BLOCKER 2: kernel/ coverage below target

**Current:** 1664/3013 lines = 55%
**Target:** >= 80%
**Requirement:** VERIFY-05

Key uncovered modules:
- `kernel_adapter.dart` — 0% (adapter routing logic)
- `engine_state_machine.dart` — low coverage (state transitions)
- `media_engine.dart` contract — 0% (abstract interface)
- `playback_controller.dart` — partial (orchestration paths)

## Environment-Blocked (not actionable in CI)

- Contract tests (VERIFY-01): mdk.dll unavailable in headless env (~57 failures)
- Dual-track regression (VERIFY-02): mdk.dll probe skips all 26 tests

## Gap Closure Requirements

1. Flip `DelegationPolicy.all(KernelMode.legacy)` → `DelegationPolicy.all(KernelMode.migrated)` or per-field migration
2. Add kernel/ unit tests to reach 80% coverage (need ~750 more lines covered)
