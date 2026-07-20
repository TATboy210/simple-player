---
phase: 20-state-lifecycle
verified: 2026-07-20T12:00:00Z
status: gaps_found
score: 6/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "new_fvp_engine.dart implements MediaEngine, depends on DiagnosticsBundle, emits PlayerError+context"
    status: partial
    reason: "Requirement STATE-01 specifies new_fvp_engine.dart as a new file. CONTEXT.md D1 decided to modify fvp_engine.dart in-place instead. The behavioral goals (DiagnosticsBundle injection, PlayerError+context emission) ARE achieved, but the requirement text references a file that does not exist. Phase 21 VERIFY-01 (contract tests for NewFvpEngine) may depend on a distinct file identity."
    artifacts:
      - path: "lib/kernel/engine/fvp_engine.dart"
        issue: "In-place modification satisfies behavioral intent but not the file-name requirement text in STATE-01"
    missing:
      - "Clarify whether STATE-01's 'new_fvp_engine.dart' is a hard file requirement or whether in-place modification via D1 satisfies it. If hard, create new_fvp_engine.dart or update REQUIREMENTS.md to reflect D1 decision."
---

# Phase 20: State Lifecycle Rewrite Verification Report

**Phase Goal:** 在已就位的适配层与诊断能力之上，落地 NewFvpEngine 实现 MediaEngine，重写状态机（lifecycle 加固 + openGeneration 统一 + 显式拒绝非法转换），按能力逐个翻转 DelegationPolicy 并每次跑契约测试，让新引擎生于一等公民诊断内核而非重写两遍
**Verified:** 2026-07-20T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | FvpEngine implements MediaEngine, depends on DiagnosticsBundle, emits PlayerError+context; DelegationPolicy per-method routing infrastructure | PRESENT_BEHAVIOR_UNVERIFIED (partial) | FvpEngine accepts DiagnosticsBundle via factory constructor (line 47), uses `_bundle.logger` at 13 call sites, emits PlayerError with ErrorContext (three-step pattern). DelegationPolicy has `migratedMethods: Set<String>` field and `_targetFor()` helper. BUT: STATE-01 requirement text specifies `new_fvp_engine.dart` which does not exist — D1 chose in-place modification. No methods actually flipped yet (all legacy). |
| SC2 | openGeneration unified via OpenGenerationTracker in state machine — transitionTo atomically rejects stale generation | VERIFIED | `_openGeneration`, `nextGeneration()`, `currentGeneration` in `engine_state_machine.dart` (lines 68-79). `transitionTo` checks `generation != _openGeneration` atomically (line 98). No `_openGeneration` in `fvp_engine.dart` or `playback_navigator.dart` — both delegate to `_stateMachine.nextGeneration()` / `.currentGeneration`. |
| SC3 | EngineStateMachine replaces assert-only with TransitionResult + KernelLogger warn; exhaustive switch (no default) | VERIFIED | `transitionTo` returns `TransitionResult` enum (line 89). Illegal transitions logged via `KernelLoggerImpl.I.warn()` (line 109). `_canTransitionTo` uses switch expression with no `default:` clause — compile-time exhaustive (line 120). No `debugPrint` in assert pattern remains. |
| SC4 | Lifecycle: LifecyclePhase {alive, disposing, disposed}, recover(), double-dispose safety | VERIFIED | `LifecyclePhase` enum in `lifecycle_phase.dart` with 3 values. `lifecyclePhase` ValueNotifier on EngineStateMachine (line 53). `recover()` transitions error->idle, clears lastError (line 173). `dispose()` has `_disposed` guard, second call returns early (line 186). `lifecyclePhase` set to `disposed` on dispose (line 188). Tests: `double-dispose` group (line 409), `recover()` group (line 375). |
| SC5 | mdk callbacks marshalled via scheduleMicrotask; listener-triggered open deferred to scheduleMicrotask | VERIFIED | `_scheduleOnMain` uses `scheduleMicrotask(action)` (line 133). No `SchedulerBinding` import — only doc comments reference old pattern. All callbacks go through `_scheduleOnMain` uniformly (D12/D13). |
| SC6 | DelegationPolicy per-method flip infrastructure; contract tests pass after each flip | PRESENT_BEHAVIOR_UNVERIFIED | `migratedMethods: Set<String>` field in DelegationPolicy (line 56). `_targetFor(method)` helper in KernelAdapter (line 120). All 26 action methods use `_targetFor()` routing. BUT: migratedMethods is `const {}` in PlayerServices (line 126) — no methods actually flipped. No evidence of per-flip contract test runs. |
| SC7 | Race condition tests cover open->open, open->seek->open, open->dispose, open->play->pause->open; assert final state matches last open | VERIFIED | `race_condition_test.dart` has 8 tests across 5 groups: generation tracking (2), open-seek-open (1), open-dispose (2), open-play-pause-open (1), recover during rapid ops (2). All use real EngineStateMachine, verify TransitionResult and final state. |

**Score:** 6/7 truths verified (SC1 and SC6 have partial PRESENT_BEHAVIOR_UNVERIFIED issues)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Per-method DelegationPolicy flip execution (actual method-by-method cutover with contract tests) | Phase 21 | Phase 21 VERIFY-01: "contract tests pass against NewFvpEngine"; VERIFY-02: "dual-track regression suite" |
| 2 | Helper interface adaptation (FvpCallbackHandler, PositionPoller, VolumeController, TrackManager logger injection) | Phase 21 / later | CONTEXT.md D3: "two-step: get engine running first, adapt helpers later" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/kernel/engine/lifecycle_phase.dart` | LifecyclePhase enum {alive, disposing, disposed} | VERIFIED | 26 lines, bilingual doc comments, 3 enum values |
| `lib/kernel/engine/transition_result.dart` | TransitionResult enum {ok, illegal, staleGeneration} | VERIFIED | 32 lines, bilingual doc comments, 3 enum values |
| `lib/kernel/engine/engine_state_machine.dart` | Expanded with lifecycle, generation, TransitionResult, recover() | VERIFIED | 197 lines, all features present |
| `lib/kernel/engine/fvp_engine.dart` | Modified: bundle injection, generation unification, lifecycle methods | VERIFIED | 734 lines, DiagnosticsBundle accepted, _bundle.logger used, generation via stateMachine |
| `lib/kernel/engine/fvp_callback_handler.dart` | Modified: scheduleMicrotask replaces SchedulerBinding | VERIFIED | 149 lines, scheduleMicrotask at line 133, no SchedulerBinding import |
| `lib/kernel/adapter/kernel_adapter.dart` | Modified: per-method DelegationPolicy with migratedMethods | VERIFIED | 328 lines, migratedMethods field, _targetFor() helper, all action methods use per-method routing |
| `lib/kernel/player_services.dart` | Modified: bundle-first creation, FvpEngine(bundle:) wiring | VERIFIED | 151 lines, bundle created before FvpEngine (line 116-121), FvpEngine(bundle:) at line 122 |
| `lib/kernel/services/playback_navigator.dart` | Modified: _openGeneration removed, delegates to state machine | VERIFIED | 124 lines, no _openGeneration field, uses stateMachine.nextGeneration/currentGeneration |
| `test/kernel/engine/engine_state_machine_test.dart` | Updated + new test groups | VERIFIED | 438 lines, TransitionResult checks, 5 new test groups (generation, lifecycle, recover, double-dispose, TransitionResult) |
| `test/kernel/engine/fvp_engine_bundle_test.dart` | New: bundle injection contract tests | VERIFIED | 100 lines, 4 test groups (bundle injection, recover, double-dispose, generation tracking) |
| `test/kernel/engine/fvp_callback_handler_test.dart` | New: mapMdkState unit tests | VERIFIED | 99 lines, 4 mapMdkState tests + constructor + ErrorContext tests |
| `test/kernel/engine/race_condition_test.dart` | New: 8 race condition tests | VERIFIED | 282 lines, 8 tests across 5 groups covering all D14 scenarios |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| FvpEngine(bundle) | DiagnosticsBundle injection | factory constructor parameter | WIRED | `factory FvpEngine({DiagnosticsBundle bundle = const DiagnosticsBundle.noop()})` (line 47) |
| KernelAdapter._targetFor | DelegationPolicy.migratedMethods | per-method routing | WIRED | `_policy.migratedMethods.contains(method) ? _migrated : _legacy` (line 121) |
| PlayerServices.init() | FvpEngine(bundle:) | bundle-first creation | WIRED | bundle created line 116, FvpEngine(bundle:) line 122 |
| EngineStateMachine.recover() | FvpEngine.recover() | delegation | WIRED | `FvpEngine.recover()` calls `_stateMachine.recover(lastError: lastError)` (line 222) |
| PlaybackNavigator._openGeneration | EngineStateMachine.currentGeneration | delegation | WIRED | `stateMachine.currentGeneration` at lines 37, 65, 95; `stateMachine.nextGeneration()` at line 48 |
| EngineStateMachine.stateMachine | EngineStateView interface | accessor | WIRED | `stateMachine` getter in engine_state_view.dart line 67, implemented in FvpEngine line 214 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| FvpEngine | _bundle.logger | DiagnosticsBundle constructor injection | Yes — all 13 logger calls use _bundle.logger | FLOWING |
| EngineStateMachine | _openGeneration | nextGeneration() increments | Yes — used in transitionTo generation check | FLOWING |
| PlaybackNavigator | currentGeneration | _controller.engine.stateMachine.currentGeneration | Yes — real state machine delegation | FLOWING |
| KernelAdapter | _policy.migratedMethods | DelegationPolicy constructor injection | Yes — but const {} in PlayerServices (no flips yet) | FLOWING (infrastructure) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| EngineStateMachine.transitionTo returns TransitionResult | grep `return TransitionResult.` in engine_state_machine.dart | 3 return statements found (ok, illegal, staleGeneration) | PASS |
| No assert-only debugPrint for illegal transitions | grep `assert.*debugPrint` in engine_state_machine.dart | 0 matches | PASS |
| No _openGeneration in FvpEngine | grep `_openGeneration` in fvp_engine.dart | 0 matches | PASS |
| No _openGeneration in PlaybackNavigator | grep `_openGeneration` in playback_navigator.dart | 0 matches (only doc comment) | PASS |
| scheduleMicrotask in FvpCallbackHandler | grep `scheduleMicrotask` in fvp_callback_handler.dart | 1 match (line 133) | PASS |
| No SchedulerBinding import in FvpCallbackHandler | grep `SchedulerBinding` import in fvp_callback_handler.dart | 0 matches (only doc comments) | PASS |
| _canTransitionTo has no default clause | grep `default:` in engine_state_machine.dart | 0 matches | PASS |
| DelegationPolicy has migratedMethods field | grep `migratedMethods` in kernel_adapter.dart | 6 matches (field, constructor, helper, routing) | PASS |

### Probe Execution

No probes declared in PLAN/SUMMARY files. Step 7c: SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| STATE-01 | 20-02 | `new_fvp_engine.dart` implements MediaEngine, depends on DiagnosticsBundle, emits PlayerError+context | PARTIAL | Behavioral goals achieved (DiagnosticsBundle injection, PlayerError+context emission). File-name requirement not met — D1 chose in-place modification of fvp_engine.dart. No contract tests for "NewFvpEngine" as distinct entity. |
| STATE-02 | 20-01, 20-02 | openGeneration unified via OpenGenerationTracker in state machine | SATISFIED | Embedded in EngineStateMachine, removed from FvpEngine and PlaybackNavigator, transitionTo atomically rejects stale generation |
| STATE-03 | 20-01 | EngineStateMachine replaces assert-only with Result.err + KernelLogger warn; exhaustive switch | SATISFIED | TransitionResult + KernelLoggerImpl.I.warn, no default clause in switch expression |
| STATE-04 | 20-01, 20-02 | Lifecycle: disposed/disposing/error-recovery, recover(), double-dispose safety | SATISFIED | LifecyclePhase enum, recover() method, _disposed guard |
| STATE-05 | 20-03 | mdk callback marshalling to main isolate via scheduleMicrotask | SATISFIED | FvpCallbackHandler._scheduleOnMain uses scheduleMicrotask uniformly |
| STATE-06 | 20-02 | DelegationPolicy per-method flip; contract tests pass after each flip | PARTIAL | Infrastructure exists (migratedMethods + _targetFor), but no methods actually flipped; no per-flip contract test evidence |
| STATE-07 | 20-03 | Race condition tests: final state matches last open | SATISFIED | 8 tests in race_condition_test.dart covering all D14 scenarios |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/kernel/engine/fvp_engine.dart` | 309 | `debugPrint('open() result: ...')` | Info | Pre-existing debug logging, not a debt marker or stub. Production noise but not blocking. |
| `lib/kernel/engine/fvp_engine.dart` | 397-401 | `debugPrint('play() — ...')` | Info | Pre-existing debug logging in play() method. |
| `lib/kernel/engine/fvp_engine.dart` | 418 | `debugPrint('play() failed: ...')` | Info | Pre-existing debug logging in play() error path. |
| `lib/kernel/services/playback_navigator.dart` | 18 | `final log = KernelLoggerImpl.I;` | Info | Top-level logger assignment — not a stub, but uses static accessor directly instead of bundle injection pattern. Pre-existing. |

No TBD, FIXME, or XXX markers found in any modified file. No stubs or placeholders found.

### Human Verification Required

No items require human verification for this phase. All truths are either VERIFIED by code evidence or flagged as gaps.

### Gaps Summary

**1 gap blocking goal achievement:**

**STATE-01 file-name mismatch:** The requirement text specifies `new_fvp_engine.dart implements MediaEngine` but CONTEXT.md D1 explicitly decided to modify `fvp_engine.dart` in-place (no new file). The behavioral goals are achieved — FvpEngine accepts DiagnosticsBundle, emits PlayerError+context, and uses `_bundle.logger`. However, Phase 21's VERIFY-01 ("contract tests for NewFvpEngine") may expect a distinct file identity. This needs resolution: either update STATE-01 requirement text to reflect D1's in-place modification decision, or create `new_fvp_engine.dart` as the requirement specifies.

**Supporting detail for SC6 partial:** The DelegationPolicy per-method routing infrastructure is fully built (`migratedMethods` Set<String>, `_targetFor()` helper, all 26 action methods wired), but `migratedMethods` is `const {}` in PlayerServices — zero methods have been actually flipped. The per-flip contract test verification (D10) is not evidenced in this phase. This is deferred to Phase 21 per CONTEXT.md D10.

---

_Verified: 2026-07-20T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
