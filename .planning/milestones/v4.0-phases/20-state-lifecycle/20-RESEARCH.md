# Phase 20: 状态与生命周期重写 - Research

**Researched:** 2026-07-20
**Domain:** Engine state machine rewrite, lifecycle management, delegation policy migration, mdk callback marshalling
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STATE-01 | `new_fvp_engine.dart` implements `MediaEngine`, depends on `DiagnosticsBundle`, emits `PlayerError`+context | D1 decision: modify `fvp_engine.dart` in-place (no new file). DiagnosticsBundle already exists (Phase 16). PlayerError+ErrorContext already exists (Phase 18). |
| STATE-02 | `openGeneration` unified via `OpenGenerationTracker` in state machine, `transitionTo` atomically rejects stale generation | Current: `fvp_engine.dart:198` has `_openGeneration`, `playback_navigator.dart:35` has separate `_openGeneration`. Two sources must merge. |
| STATE-03 | `EngineStateMachine` replaces assert-only with `TransitionResult` + `KernelLogger` warning; exhaustive `switch` (no `default`) | Current: `engine_state_machine.dart:51-58` uses assert-only (debugPrint in assert, silent in release). Returns `bool`. |
| STATE-04 | Lifecycle: `LifecyclePhase {alive, disposing, disposed}`, explicit `recover()`, double-dispose safety | Current: only `_disposed` bool flag in `fvp_engine.dart:132`. No LifecyclePhase enum. No recover(). |
| STATE-05 | mdk callback marshalling to main isolate; listener-triggered open deferred to `scheduleMicrotask` | Current: `fvp_callback_handler.dart:129` uses `SchedulerBinding.addPostFrameCallback`. Phase 18 D9 established `scheduleMicrotask` pattern. |
| STATE-06 | `DelegationPolicy` per-method flip to new engine; Phase 15 contract tests pass after each flip | `kernel_adapter.dart` already has per-capability DelegationPolicy. Phase 16 D14 established 7 ISP fields. |
| STATE-07 | Race condition tests (open->seek->open rapid fire) assert final state matches last open only | No existing race tests. Phase 15 D20 deferred timing/race to P20. |
</phase_requirements>

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1: NewFvpEngine Architecture (D1-D5)**
- **D1:** Modify `fvp_engine.dart` in-place (no new file). DelegationPolicy controls old/new path switching during dual-track period.
- **D2:** FvpEngine constructor accepts `DiagnosticsBundle`, extracts logger/metrics/eventLog/memoryMonitor from it.
- **D3:** Reuse existing helpers (FvpCallbackHandler, PositionPoller, etc.) but adapt their interfaces (inject logger, modify callback signatures). Two-step: get engine running first, then gradually adapt helpers.
- **D4:** New `TransitionResult` enum `{ok, illegal, staleGeneration}` (not sealed `Result<T>`). `EngineStateMachine.transitionTo` returns `TransitionResult` instead of `bool`.
- **D5:** `OpenGenerationTracker` embedded inside `EngineStateMachine`. State machine holds generation counter, `transitionTo` auto-checks generation. `openGeneration` migrates from PlaybackNavigator to tracker (single source of truth).

**Area 2: Lifecycle State Machine (D6-D8)**
- **D6:** New independent `LifecyclePhase {alive, disposing, disposed}`, orthogonal to `MediaState`. State machine holds two independent ValueNotifiers (`state` + `lifecyclePhase`).
- **D7:** `recover()` explicit method call: error -> idle. Resets state and clears lastError. Not auto-triggered, called by UI or service layer.
- **D8:** Double-dispose safety: `dispose()` checks `_disposed` bool flag, second call returns silently. LifecyclePhase syncs to `disposed`.

**Area 3: DelegationPolicy Flip Strategy (D9-D11)**
- **D9:** Per-method granularity flip (not per ISP interface, not per subsystem). Each MediaEngine method independently marked `legacy` or `migrated`.
- **D10:** After each method flip, run full test suite (contract tests + integration + widget tests). Green before proceeding. STATE-06 "Phase 15 contract tests pass" expanded to full suite.
- **D11:** Core-first flip order: open() -> play() -> pause() -> seek() -> volume() -> mute() -> ... -> other leaf methods.

**Area 4: mdk Callback Marshalling & Race Protection (D12-D14)**
- **D12:** All mdk callback state updates unified via `scheduleMicrotask` marshalling to main isolate. Same pattern as Phase 18 D9 error marshalling.
- **D13:** All callbacks uniformly delayed (not just open-triggering ones). Avoids complexity of determining which callbacks trigger open. scheduleMicrotask overhead is negligible.
- **D14:** Race test coverage: open->open rapid fire, open->seek->open interleaved, open->dispose lifecycle, open->play->pause->open rapid fire. Assert final state matches last open only.

### Claude's Discretion
- `TransitionResult` enum value naming (D4: `ok`/`illegal`/`staleGeneration`, planner may adjust)
- Helper interface adaptation specifics (D3: planner evaluates per-helper)
- Complete method flip order list (D11: core-first defined, full list from MediaEngine interface enumeration)
- Race test fakeAsync implementation details (D14: planner designs test fixtures)
- LifecyclePhase ValueNotifier UI consumption points (D6: may affect dispose timing)

### Deferred Ideas (OUT OF SCOPE)
- **P21 适配层收拢** — After all DelegationPolicy flips, adapter deletion gate checklist
- **P21 双轨回归验证** — all-old vs all-new output consistency, fakeAsync verification
- **P22 双语注释** — P20 new/modified public symbols need bilingual comments
- **Helper gradual adaptation** — D3 "get running first, adapt later", helper interface changes may defer to P21
- **ERR-F01 Future** — openGeneration association, RetryPolicy enum (P20 generation guard partially implements)
</user_constraints>

## Summary

Phase 20 is the core rewrite phase of the v3.0 kernel rewrite milestone. It transforms the existing `FvpEngine` from a monolithic 712-line class with assert-only state machine guards into a properly instrumented engine with lifecycle management, generation-aware state transitions, explicit error recovery, and method-level delegation for gradual migration.

The phase builds on 5 completed prerequisite phases (15-19) that established: frozen behavioral contracts (P15), a Strangler Fig adapter seam (P16), zero-dependency logging (P17), sealed error model with thread marshalling (P18), and instance-based memory monitoring (P19). Phase 20 consumes all of these — injecting DiagnosticsBundle into the engine, using KernelLogger for state transition warnings, leveraging the sealed PlayerError for structured error emission, and using the established scheduleMicrotask pattern for callback marshalling.

The key architectural insight is that this is NOT a greenfield rewrite — it modifies `fvp_engine.dart` in-place (D1) with DelegationPolicy controlling old/new path switching. The existing `KernelAdapter` already has per-capability routing infrastructure (7 ISP fields in DelegationPolicy). Phase 20 extends this to per-method granularity (D9) and flips methods one at a time (D11), running the full test suite after each flip (D10).

**Primary recommendation:** Execute as 4 waves: (1) state machine rewrite + TransitionResult + LifecyclePhase + OpenGenerationTracker, (2) FvpEngine constructor injection + lifecycle integration, (3) method-level DelegationPolicy flip with contract test gates, (4) race condition tests + callback marshalling verification.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| State machine transitions | EngineStateMachine (kernel/engine) | — | Owns MediaState + LifecyclePhase + generation counter |
| Lifecycle management | FvpEngine (kernel/engine) | EngineStateMachine | Engine owns dispose/recover, state machine owns LifecyclePhase notifier |
| DelegationPolicy routing | KernelAdapter (kernel/adapter) | — | Already has 7 ISP fields, extends to per-method |
| mdk callback marshalling | FvpCallbackHandler (kernel/engine) | — | Owns mdk stream subscriptions, scheduleMicrotask wrapping |
| Diagnostics injection | FvpEngine constructor | PlayerServices (composition root) | Bundle injected at construction, wired in PlayerServices.init() |
| Error emission | FvpEngine catch points | KernelLogger | Three-step pattern: construct PlayerError -> lastError -> logger.e |
| Race condition testing | test/contracts/ | test/engine/ | fakeAsync-based race tests in dedicated test files |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/foundation.dart | SDK | ValueNotifier, ValueListenableBuilder, debugPrint | Project state management convention |
| fvp/mdk | (locked) | Native MDK/FFmpeg player | Existing engine, not being replaced |
| dart:async | SDK | scheduleMicrotask, Timer, Future | Callback marshalling, async patterns |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | fakeAsync, test, expect | Race condition tests, contract tests |
| flutter/scheduler.dart | SDK | SchedulerBinding.addPostFrameCallback | Current callback scheduling (to be replaced by scheduleMicrotask) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `TransitionResult` enum | sealed `Result<T>` | D4 decision: enum is simpler, no generic type parameter needed |
| `scheduleMicrotask` | `SchedulerBinding.addPostFrameCallback` | D12 decision: uniform microtask avoids frame-phase complexity |
| New file `new_fvp_engine.dart` | In-place modification | D1 decision: DelegationPolicy enables gradual migration without file duplication |

## Package Legitimacy Audit

No new packages are installed in this phase. All dependencies are existing project dependencies or Dart/Flutter SDK.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| fvp | (existing) | OK | Already locked, not modified |
| flutter_test | SDK | OK | Already used |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
PlayerServices.init()
  |
  +-- FvpEngine(bundle: DiagnosticsBundle)
  |     |
  |     +-- EngineStateMachine
  |     |     +-- state: ValueNotifier<MediaState>
  |     |     +-- lifecyclePhase: ValueNotifier<LifecyclePhase>  [NEW]
  |     |     +-- OpenGenerationTracker  [NEW, embedded]
  |     |     +-- transitionTo() -> TransitionResult  [CHANGED from bool]
  |     |
  |     +-- FvpCallbackHandler
  |     |     +-- scheduleMicrotask marshalling  [CHANGED from addPostFrameCallback]
  |     |
  |     +-- PositionPoller, VolumeController, TrackManager, etc.
  |
  +-- KernelAdapter(legacy: fvp, migrated: fvp, policy: DelegationPolicy)
        |
        +-- per-method DelegationPolicy  [CHANGED from per-capability]
```

### Recommended Project Structure

```
lib/kernel/engine/
  ├── fvp_engine.dart              # MODIFY: inject bundle, lifecycle, generation
  ├── engine_state_machine.dart     # MODIFY: LifecyclePhase, TransitionResult, OpenGenerationTracker
  ├── fvp_callback_handler.dart     # MODIFY: scheduleMicrotask marshalling
  ├── media_state.dart              # UNCHANGED
  ├── lifecycle_phase.dart          # NEW: LifecyclePhase enum
  ├── transition_result.dart        # NEW: TransitionResult enum
  └── ...                           # UNCHANGED helpers

lib/kernel/adapter/
  └── kernel_adapter.dart           # MODIFY: per-method DelegationPolicy

test/engine/
  ├── fvp_engine_contract_test.dart # MODIFY: add lifecycle + race tests
  └── engine_state_machine_test.dart # NEW or MODIFY: state machine unit tests
```

### Pattern 1: TransitionResult Enum

**What:** Replace `bool` return from `EngineStateMachine.transitionTo()` with a 3-value enum.
**When to use:** Every state transition call site.
**Example:**
```dart
// Source: CONTEXT.md D4
enum TransitionResult { ok, illegal, staleGeneration }

// Usage in state machine:
TransitionResult transitionTo(MediaState next, String caller, {int? generation}) {
  if (generation != null && generation != _currentGeneration) {
    _logger.warn('Stale generation: $caller requested gen=$generation, current=$_currentGeneration');
    return TransitionResult.staleGeneration;
  }
  if (!_canTransitionTo(state.value, next)) {
    _logger.warn('Illegal transition: ${state.value} -> $next (caller: $caller)');
    return TransitionResult.illegal;
  }
  state.value = next;
  return TransitionResult.ok;
}
```

### Pattern 2: LifecyclePhase Orthogonal State

**What:** Independent `LifecyclePhase` enum alongside `MediaState`, both exposed as ValueNotifiers.
**When to use:** Engine lifecycle management (dispose, recover).
**Example:**
```dart
// Source: CONTEXT.md D6
enum LifecyclePhase { alive, disposing, disposed }

// In EngineStateMachine:
final ValueNotifier<LifecyclePhase> lifecyclePhase = ValueNotifier(LifecyclePhase.alive);

// In FvpEngine.dispose():
void dispose() {
  if (_disposed) return;  // D8: double-dispose safety
  _disposed = true;
  _stateMachine.lifecyclePhase.value = LifecyclePhase.disposing;
  // ... cleanup ...
  _stateMachine.lifecyclePhase.value = LifecyclePhase.disposed;
}
```

### Pattern 3: OpenGenerationTracker Embedded in State Machine

**What:** Generation counter moves from FvpEngine + PlaybackNavigator into EngineStateMachine.
**When to use:** All open() calls — generation check happens inside transitionTo().
**Example:**
```dart
// Source: CONTEXT.md D5
class EngineStateMachine {
  int _openGeneration = 0;

  /// Increment generation — called when open() begins
  int nextGeneration() => ++_openGeneration;

  /// transitionTo auto-checks generation
  TransitionResult transitionTo(MediaState next, String caller, {int? generation}) {
    if (generation != null && generation != _currentGeneration) {
      return TransitionResult.staleGeneration;
    }
    // ... existing logic with TransitionResult return
  }
}
```

### Pattern 4: scheduleMicrotask Callback Marshalling

**What:** All mdk callbacks wrapped in scheduleMicrotask instead of SchedulerBinding.addPostFrameCallback.
**When to use:** All callback state updates in FvpCallbackHandler.
**Example:**
```dart
// Source: Phase 18 D9 pattern, CONTEXT.md D12
void _scheduleOnMain(VoidCallback action) {
  scheduleMicrotask(() {
    if (_disposed) return;
    action();
  });
}
```

### Anti-Patterns to Avoid

- **Big-bang swap:** Never replace all methods at once. D9/D11 require per-method flipping with test gates.
- **Dual state sources:** OpenGenerationTracker must be the single source of truth. Remove `_openGeneration` from both FvpEngine and PlaybackNavigator.
- **Silent illegal transitions:** Current assert-only pattern (debugPrint in assert, silent in release) is the #4 blocking anti-pattern. Must use TransitionResult + KernelLogger warning in all modes.
- **Mixed callback scheduling:** Don't mix scheduleMicrotask and addPostFrameCallback in the same handler. D13: uniform delay for all callbacks.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State transition validation | Custom if/else chains | Exhaustive switch expression (existing `_canTransitionTo`) | Compile-time coverage guarantee |
| Error context construction | Manual map building | `ErrorContext` sealed class (Phase 18) | Structured, type-safe, serializable |
| Thread marshalling | Custom Isolate.spawn | `scheduleMicrotask` (D12) | Already proven in Phase 18, zero overhead |
| Test timing control | Real timers in tests | `fakeAsync` from flutter_test | Deterministic race condition testing |

**Key insight:** The existing infrastructure (Phase 15-19) provides all the building blocks. Phase 20 is primarily an integration and wiring phase, not a new-abstraction phase.

## Common Pitfalls

### Pitfall 1: CodecError Retry Recursion
**What goes wrong:** `open()` recurses infinitely when CodecError occurs on undecodable files (documented deviation in contract tests).
**Why it happens:** Retry condition `error is CodecError && !isUrl` is always true for local garbage files.
**How to avoid:** Add recursion guard (e.g., `_retryCount` or `generation` check). This is a pre-existing bug, not introduced by P20, but P20's generation tracking may help bound it.
**Warning signs:** Test hangs, stack overflow in open() tests with bad files.

### Pitfall 2: DelegationPolicy Per-Method Explosion
**What goes wrong:** 44 MediaEngine members × per-method policy = massive DelegationPolicy class.
**Why it happens:** D9 says per-method granularity, but MediaEngine has ~44 members across 7 ISP interfaces.
**How to avoid:** Start with per-ISP-interface granularity (7 fields, already exists), then split specific methods as needed. The "per-method" intent (D9) means "each method can be independently flipped", not "each method gets its own policy field". Use a `Set<String>` of migrated method names or a `Map<String, KernelMode>`.
**Warning signs:** DelegationPolicy growing beyond 50 fields.

### Pitfall 3: ValueNotifier Instance Identity During Flip
**What goes wrong:** When DelegationPolicy flips `stateView` from legacy to migrated, the ValueNotifier instance changes, breaking all existing ValueListenableBuilder listeners.
**Why it happens:** Legacy and migrated engines have separate ValueNotifier instances.
**How to avoid:** D1 modifies fvp_engine.dart in-place — the same FvpEngine instance serves both legacy and migrated roles. The KernelAdapter wraps the SAME instance. No identity break.
**Warning signs:** UI freezes after policy flip, listeners not firing.

### Pitfall 4: Dispose Ordering with LifecyclePhase
**What goes wrong:** Setting `lifecyclePhase.value = disposing` triggers UI rebuilds that access engine state, causing use-after-dispose.
**Why it happens:** ValueNotifier notifies listeners synchronously.
**How to avoid:** Set `_disposed = true` FIRST (guards all methods), then update lifecyclePhase. Or use `LifecyclePhase` only for test assertions, not UI consumption.
**Warning signs:** Exceptions in dispose(), UI rebuilds accessing disposed engine.

### Pitfall 5: Generation Counter Race in scheduleMicrotask
**What goes wrong:** Two rapid open() calls both increment generation, but scheduleMicrotask defers the state update — the first callback may see a stale generation.
**Why it happens:** scheduleMicrotask runs in microtask queue, not immediately.
**How to avoid:** Capture generation at call site, pass to scheduleMicrotask closure. Check generation inside the microtask callback before updating state. This is the same pattern as existing `fvp_engine.dart:285` (`if (_disposed || gen != _openGeneration) return`).
**Warning signs:** Wrong track plays after rapid switching.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Assert-only illegal transition guard | TransitionResult + KernelLogger warn | Phase 20 (this phase) | Illegal transitions visible in release builds |
| `_disposed` bool flag only | LifecyclePhase enum + `_disposed` bool | Phase 20 (this phase) | Observable lifecycle state for testing |
| `_openGeneration` in FvpEngine + PlaybackNavigator | OpenGenerationTracker in state machine | Phase 20 (this phase) | Single source of truth, atomic generation check |
| `SchedulerBinding.addPostFrameCallback` | `scheduleMicrotask` | Phase 20 (this phase) | Uniform callback scheduling, simpler |
| Per-capability DelegationPolicy (7 fields) | Per-method DelegationPolicy | Phase 20 (this phase) | Granular migration control |

**Deprecated/outdated:**
- `bool` return from `transitionTo()`: replaced by `TransitionResult` enum
- `SchedulerBinding.addPostFrameCallback` in FvpCallbackHandler: replaced by `scheduleMicrotask`
- Separate `_openGeneration` in PlaybackNavigator: merged into state machine tracker

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | `pubspec.yaml` dev_dependencies |
| Quick run command | `flutter test test/engine/engine_state_machine_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STATE-01 | FvpEngine accepts DiagnosticsBundle, emits PlayerError | unit | `flutter test test/engine/fvp_engine_contract_test.dart` | Yes (modify) |
| STATE-02 | OpenGenerationTracker rejects stale generation | unit | `flutter test test/engine/engine_state_machine_test.dart` | New |
| STATE-03 | TransitionResult returned for illegal/stale transitions | unit | `flutter test test/engine/engine_state_machine_test.dart` | New |
| STATE-04 | LifecyclePhase transitions, recover() works, double-dispose safe | unit | `flutter test test/engine/engine_state_machine_test.dart` | New |
| STATE-05 | mdk callbacks marshalled via scheduleMicrotask | unit | `flutter test test/engine/fvp_callback_handler_test.dart` | New |
| STATE-06 | DelegationPolicy per-method flip, contract tests pass | integration | `flutter test test/engine/fvp_engine_contract_test.dart` | Yes (modify) |
| STATE-07 | Race condition tests (open->seek->open) | integration | `flutter test test/engine/race_condition_test.dart` | New |

### Sampling Rate
- **Per task commit:** `flutter test test/engine/engine_state_machine_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/engine/engine_state_machine_test.dart` — covers STATE-02, STATE-03, STATE-04
- [ ] `test/engine/race_condition_test.dart` — covers STATE-07
- [ ] `test/engine/fvp_callback_handler_test.dart` — covers STATE-05
- [ ] `lib/kernel/engine/lifecycle_phase.dart` — new enum file
- [ ] `lib/kernel/engine/transition_result.dart` — new enum file

## Security Domain

Not applicable — this phase modifies internal engine state management, no user input handling, no authentication, no external API calls, no cryptographic operations. All changes are within `lib/kernel/engine/` boundary.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `scheduleMicrotask` is safe for ValueNotifier updates (no mid-frame assertion failures) | Pattern 4 | May need to keep addPostFrameCallback for some notifier updates; test in Phase 20 |
| A2 | Same FvpEngine instance for legacy+migrated avoids ValueNotifier identity break | Pitfall 3 | If separate instances needed, adapter forwarding must use same() check |
| A3 | Per-method DelegationPolicy can be implemented as `Map<String, KernelMode>` without performance impact | Pitfall 2 | Map lookup per method call is O(1) but may add measurable overhead in hot paths |
| A4 | PlaybackNavigator's `_openGeneration` can be fully replaced by state machine tracker | Pattern 3 | Navigator's generation is used for playlist index rollback on error; may need local copy |

## Open Questions (RESOLVED)

1. **Per-method DelegationPolicy implementation** (RESOLVED)
   - What we know: Current DelegationPolicy has 7 `KernelMode` fields (per ISP interface). D9 requires per-method granularity. MediaEngine has ~44 members.
   - What's unclear: Whether to use `Map<String, KernelMode>` or expand to 44 fields, or use a `Set<String>` of migrated method names.
   - Recommendation: Use `Set<String> _migratedMethods` in DelegationPolicy. Check `if (_migratedMethods.contains('open'))` for each method. Simple, extensible, no field explosion.
   - Resolution: Plan 02 Task 2 implements `Set<String> migratedMethods` in DelegationPolicy with `_targetFor(method)` helper routing.

2. **PlaybackNavigator openGeneration removal scope** (RESOLVED)
   - What we know: PlaybackNavigator has `_openGeneration` for playlist index rollback on error (`playIndex` line 49/66/96). State machine tracker handles engine-level generation.
   - What's unclear: Whether Navigator needs its own generation for playlist rollback, or can query the state machine's tracker.
   - Recommendation: Navigator queries `stateMachine.currentGeneration` for its rollback check. Single source of truth (D5). The Navigator's `if (gen == _openGeneration)` check at line 96 becomes `if (gen == _stateMachine.currentGeneration)`.
   - Resolution: Plan 02 Task 1 step 8 migrates PlaybackNavigator to use `_controller.engine.stateMachine.nextGeneration()` and `.currentGeneration`. Local `_openGeneration` field removed.

3. **FvpCallbackHandler scheduleMicrotask vs addPostFrameCallback** (RESOLVED)
   - What we know: Current uses `SchedulerBinding.addPostFrameCallback`. Phase 18 D9 established `scheduleMicrotask` for error marshalling. D12/D13 require uniform scheduleMicrotask.
   - What's unclear: Whether scheduleMicrotask can cause mid-frame ValueNotifier assertion failures (Flutter checks `!_debugBuilding` during rebuild).
   - Recommendation: Use scheduleMicrotask for all callbacks. Microtasks run between frames, not during build. If assertions occur, fall back to addPostFrameCallback. Test this in Wave 1.
   - Resolution: Plan 03 Task 1 replaces `SchedulerBinding.addPostFrameCallback` with `scheduleMicrotask` in FvpCallbackHandler. Race condition tests in Plan 03 Task 2 validate correctness.

## Sources

### Primary (HIGH confidence)
- Live codebase: `lib/kernel/engine/fvp_engine.dart` (712 lines, direct modification target)
- Live codebase: `lib/kernel/engine/engine_state_machine.dart` (119 lines, extension target)
- Live codebase: `lib/kernel/adapter/kernel_adapter.dart` (358 lines, policy extension target)
- Live codebase: `lib/kernel/engine/fvp_callback_handler.dart` (146 lines, marshalling change)
- CONTEXT.md: 14 locked decisions (D1-D14) across 4 areas

### Secondary (MEDIUM confidence)
- Phase 15 CONTEXT.md: 23 decisions (D1-D23) establishing contract freeze patterns
- Phase 18 CONTEXT.md: 11 decisions (D1-D11) establishing error model + callback marshalling
- Phase 19 CONTEXT.md: 10 decisions (D1-D10) establishing atomic migration pattern

### Tertiary (LOW confidence)
- None — all findings verified against live codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies are existing project dependencies or SDK
- Architecture: HIGH — patterns established in Phase 15-19, direct code analysis
- Pitfalls: HIGH — identified from live codebase analysis and documented deviations

**Research date:** 2026-07-20
**Valid until:** 2026-08-20 (30 days — stable, depends on Phase 15-19 which are complete)
