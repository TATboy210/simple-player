# Project Research Summary

**Project:** Simple Player Flutter — v3.0 Kernel Rewrite (Compatible Replacement + Diagnostics-First Kernel)
**Domain:** Flutter desktop media player kernel rewrite (fvp/MDK-FFmpeg) — in-process kernel migration via Strangler Fig + Anti-Corruption Layer
**Researched:** 2026-07-16
**Confidence:** HIGH (architecture + pitfalls grounded in live code at `D:\simple_player_flutter`; stack verified against Dart 3 + Flutter foundation docs via Context7)

---

## Executive Summary

This is **not a greenfield kernel**. It is a **compatible-replacement rewrite** of an existing, working fvp/MDK-FFmpeg Flutter desktop media player kernel, executed behind a **Strangler Fig / Anti-Corruption Layer adapter** so the UI never changes shape and behavior never regresses during a long, per-capability cutover. Experts build this exact pattern (Fowler's Strangler Fig + DDD's ACL) when rewriting a load-bearing subsystem whose consumers must stay live; the alternative — a one-shot big-bang swap — is explicitly forbidden by the milestone constraint. The five new v3.0 capabilities (zero-dep `KernelLogger` facade, sealed error model, injectable `MemoryMonitor`, anti-corruption adapter, hardened state machine) are all built from **Dart 3 stdlib + `package:flutter/foundation.dart` only** — the kernel adds **zero** new third-party runtime dependencies.

The recommended approach is a **code-grounded build order**: freeze the behavioral contract first, stand up the adapter seam + `DiagnosticsBundle` skeleton second, then land diagnostics (logger -> error model -> memory monitor) so the eventual state/lifecycle rewrite (the largest, riskiest change) is born into a first-class instrumented kernel rather than rewritten twice. This ordering is forced by two facts the code-grounded researchers (ARCHITECTURE + PITFALLS) surfaced and the web-blocked researchers (STACK + FEATURES) missed: (a) `lib/kernel/utils/log.dart` **already imports `package:logger` + `package:path_provider`** with **121 call sites across 30 files** — `KernelLogger` is a **replacement migration**, not a new facade; (b) a sealed `PlayerError` hierarchy **already exists** at `lib/kernel/models/player_error.dart` — the error model is **stabilize/extend**, not invent. Treating either as greenfield under-scopes the migration surface.

The key risks are: **(1) double source-of-truth during dual-track coexistence** (two `MediaState`/`position`/`openGeneration` streams silently fork), mitigated by a single `KernelMode` arbiter + the adapter forwarding the active engine's `ValueNotifier` **instances** (never re-wrapping); **(2) the project's documented over-engineering nemesis** ("27 files 3500 lines", "19 state vars for 1 bool"), mitigated by an explicit **size budget** — adapter + facade + sealed error + generation tracker together must be smaller than legacy `FvpEngine`, and the adapter holds no state except `KernelMode` + the generation counter; **(3) `debugPrint` is NOT stripped in release** — the facade must gate by `kDebugMode` and route warn/error through `dart:developer.log`; **(4) the state machine + `openGeneration` guard were designed separately** (guard at `fvp_engine.dart:194`, machine at `engine_state_machine.dart`) and must be **unified** via an `OpenGenerationTracker`, with silent assert-only illegal transitions replaced by `Result.err` + `KernelLogger` warning.

---

## Key Findings

### Recommended Stack (from STACK.md)

**Zero new dependencies.** Every v3.0 capability is built from `dart:*` stdlib + `package:flutter/foundation.dart` (already a transitive via fvp + window_manager). No `pubspec.yaml` change required.

**Core technologies:**
- **`dart:developer` (`log`, `Timeline`, `Flow`)** — primary structured logging surface; carries `level`/`name`/`error`/`stackTrace` natively; emits to DevTools; zero cost when no client attached. Replaces `package:logger`.
- **`dart:async` (`Timer.periodic`, `StreamController.broadcast`, `Completer`)** — diagnostic polling, event fan-out, async race guards (`openGeneration` cancellation). Already used in the kernel.
- **`dart:io` (`ProcessInfo.currentRss` / `maxRss`)** — sync RSS sampling for `MemoryMonitor`. Desktop-only (matches project scope). Already proven in `memory_monitor.dart`.
- **`dart:convert` (`jsonEncode`)** — structured-context serialization for error context + log payloads. Replaces any structured-logging dep.
- **Dart 3 `sealed` classes + exhaustive `switch`** — closed error hierarchy, state-machine states, compiler-enforced transitions. No `freezed`, no codegen, no FSM lib — sealed exhaustiveness is **stronger** (compile-time) than runtime FSM packages.
- **`package:flutter/foundation.dart` (`ValueNotifier`, `ChangeNotifier`, `debugPrint`, `kDebugMode`/`kReleaseMode`, `assert`)** — diagnostic state exposure, controlled console logging, compile-time release stripping. Already the project's reactive contract (no Provider/Riverpod/Bloc).

**Critical version note:** Dart 3.0+ required (sealed classes). Project already on Dart 3. `debugPrint` is a swappable `DebugPrintCallback` — **not auto-stripped in release**; `kDebugMode` is the compile-time `const bool` that tree-shakes the false branch.

### Cross-Cutting Refinements (synthesized across all 4 researchers)

These nine refinements emerged from reconciling the code-grounded researchers (ARCHITECTURE + PITFALLS, who read live files) against the web-blocked researchers (STACK + FEATURES). They **override** the less-grounded findings and must be honored by the roadmap:

1. **`KernelLogger` is a REPLACEMENT migration, not a greenfield facade.** `lib/kernel/utils/log.dart` already imports `package:logger` + `package:path_provider`; **121 call sites across 30 files** use `log`, `logEngine`, `logBridge`, `logServices`, `logUi`. The facade MUST preserve the `log*.w(...)` / `log.i(...)` **call shape** so the 30 files migrate by import/declaration change, not by editing 121 call sites. (Pitfall 1)

2. **The sealed `PlayerError` hierarchy ALREADY EXISTS** at `lib/kernel/models/player_error.dart` (File/Codec/Playback/Network/Unknown + enum codes). The error model is **STABILIZE/EXTEND**: add `ErrorContext` (action, generation, path, timestamp, module) + an `ErrorCode` registry; preserve the `ValueNotifier<PlayerError?>` contract that `FvpEngine.lastError` and `error_banner.dart` already depend on. Re-inventing it is out-of-scope churn. (Architecture Anti-Pattern 5)

3. **`openGeneration` lives at `fvp_engine.dart:194`, separate from `EngineStateMachine`.** They are two halves of one correctness property ("only the most recent open's results apply") designed separately. v3.0 MUST unify them via an `OpenGenerationTracker` (or fold the counter into the state machine) so `transitionTo` refuses stale-generation transitions atomically. (Pitfall 8)

4. **`EngineStateMachine` silently ignores illegal transitions** (`assert`-only debug warning, `engine_state_machine.dart:52-58`). This is the project's documented "silent failure" anti-pattern. v3.0 replaces it with `Result.err(IllegalTransition(...))` + a `KernelLogger` warning; silent ignore is only acceptable for documented idempotent no-ops. (Pitfall 8)

5. **`MemoryMonitor` has only 2 static callers** (`main.dart:16` `MemoryMonitor.start()`, `debug_exporter.dart:57` `MemoryMonitor.snapshot()`). Promote to an injectable instance via a **transient static-bridge shim** that delegates to a held `_default` instance; rewrite the 2 callers + **delete the shim in ONE atomic commit** (the project memory explicitly documents the "R2-5 deleted `_instance` but kept static methods -> build failure" anti-pattern). Never split this across commits. (Pitfall 5)

6. **The adapter must forward the active engine's `ValueNotifier` INSTANCES, not re-wrap them.** `KernelAdapter.state` returns `_policy.useStateV2 ? _new.state : _old.state` — the SAME notifier object the engine owns. Re-wrapping in a fresh `ValueNotifier` detaches every `ValueListenableBuilder` listener -> silent UI freeze on cutover. (Architecture Anti-Pattern 1, Pitfall 2)

7. **`debugPrint` is NOT stripped in release.** It is a normal throttled `print` to stdout that ships in the binary and executes. The facade MUST gate the `DebugPrintSink` with `if (kDebugMode)` (compile-time tree-shake) and route `warning`/`error` through `dart:developer.log` (structured, capturable, low-cost-when-no-client). Three independent knobs: (a) compile-time strip via `kDebugMode`, (b) runtime min-level filter, (c) per-sink enable flag. (Pitfall 11, STACK critical pitfall)

8. **9-state (PROJECT.md) vs 6-state (`engine_state_machine.dart`) discrepancy.** PROJECT.md documents a 9-state ~40-edge machine; the live `engine_state_machine.dart` implements 6 `MediaState` values. Phase 1 baseline MUST reconcile this — either PROJECT.md is aspirational and 6 is the frozen baseline, or the machine is missing 3 states (e.g. `disposed`, `disposing`, `error` lifecycle states) that v3.0 must add. Unresolved, this forks the adapter contract. (Architecture Phase 1, Pitfall 8)

9. **Set a size budget — the project's documented over-engineering nemesis.** The project memory is emphatic about prior refactors producing "27 files 3500 lines", "19 state vars for 1 bool", "double source-of-truth", "over-abstraction". Rule: **adapter + facade + sealed error + generation tracker together must be SMALLER than legacy `FvpEngine`**. The adapter holds **no state** except `KernelMode` + the generation counter; all playback state stays in the engine. If the adapter alone exceeds ~30% of legacy engine line count, it is becoming a layer, not a seam. (Pitfall 10)

### Expected Features (from FEATURES.md)

All 5 capabilities are **P1 must-have** for v3.0 launch — the rewrite is incomplete without any of them.

**Must have (table stakes):**
- **KernelLogger facade** — level hierarchy (trace/debug/info/warn/error/fatal), compile-time `kReleaseMode` gating, structured `Map<String,Object?>` context, stable `Logger.x(msg, {context})` call-site API, path redaction at the boundary, `NullSink` (release default) + `DeveloperLogSink` (debug), isolate-safe writes, named/child loggers per module.
- **Sealed error model** — sealed `KernelError`/`PlayerError` hierarchy (EXTEND existing), stable string/enum codes, recoverable vs fatal split (rooted at the hierarchy top), structural context (`code` + `message` + `Map<String,Object?> context` + `cause`), no silent swallow (typed `on` clauses, never catch `Error` subtypes), propagation kernel->service->UI, exhaustive handling at every boundary.
- **MemoryMonitor first-class** — instance-based (not static singleton), `Clock` injection, configurable threshold/interval/maxHistory, `start()`/`stop()`/`dispose()`, **non-interference with playback state** (the defining property — never calls into `PlaybackController`, never mutates `MediaState`), toggleable (`MemoryMonitor.disabled` factory / `NoopMemoryMonitor`), preserve `ValueNotifier<MemorySnapshot?>` + `snapshot()`/`exportJson()`.
- **Anti-corruption adapter** — per-ISP-interface adapters (NOT one god-adapter), dual-track coexistence (old + new both live), config-driven switch (`KernelSwitch` from `--dart-define`, never runtime-mutable), contract tests per interface, documented collapse criteria with exit gates.
- **State machine rewrite** — sealed `PlaybackState`, transition table as data (not switch sprawl), `openGeneration` guard preserved + unified, callback thread-safety (marshal mdk callbacks to main isolate), idempotent transitions (same-state no-ops), reject invalid transitions explicitly (`KernelError`/`Result.err`), `disposed` terminal state, generation + state co-located atomically.

**Should have (differentiators — defer to v3.x unless free):**
- `KernelLogger`: correlation via `openGeneration` on every log, lazy message construction, in-memory ring buffer + crash export (unify with existing `EngineEventLog`), per-sink level filter.
- Error model: `openGeneration` correlation in context, `RetryPolicy` enum attached to `RecoverableError`, error metrics by code (reuse `EngineMetrics`), `Result<T>` for non-exception control flow, user-facing l10n code->key map.
- `MemoryMonitor`: pluggable `MetricProbe` sources (GPU, frame timing), ring buffer with eviction policy + `droppedCount`, per-engine scope, windowed stats, `KernelLogger` integration (replace direct `debugPrint`).
- Adapter: **shadow mode** (call new, discard result, compare + log diff), per-subsystem gradual rollout, anti-corruption (new kernel imports nothing old), old-vs-new diff telemetry, generation guard parity.
- State machine: transition table as `const Map`, event log unified with `EngineEventLog`, transition metrics (frequency, dwell time), capability negotiation per state (`canSeek(state)` derived from table), hot-reload-safe state preservation.

**Defer (v3.x / v4+):**
- File/remote log sinks outside the kernel (trigger: support-ticket workflow needs persistent logs).
- Error retry policy + metrics (trigger: first user-facing error ambiguity).
- `MemoryMonitor` pluggable probes / per-engine scope (trigger: multi-instance work begins).
- Adapter shadow mode + diff telemetry (trigger: first migration subsystem shows behavioral drift).
- Generic FSM extraction (trigger: a second engine type lands — until then YAGNI).
- Auto-act policy on memory thresholds (trigger: a concrete incident + a testable separate policy layer).

**Explicit anti-features (do NOT build):**
- Pulling `package:logger`/`logging` into the kernel; async file/remote sinks owned by the kernel; logging on the position-poller 200ms hot path; raw `print()`/`debugPrint()` at call sites; mutable global logger config after init; logging user paths verbatim.
- Exceptions for control flow; catching `Error` subtypes; a giant flat error union; propagating raw fvp/MDK error objects to UI; embedding user-facing strings in error objects; retry-without-generation-guard.
- Auto-acting on memory thresholds (violates non-interference); sampling on the position-poller timer; logging every sample; static singleton "for convenience"; sync heavy computation in the sample callback; exposing monitor internals to UI as raw types.
- Collapsing the adapter before new kernel is proven; leaking old kernel types into new; one god-adapter; runtime-mutable switch; keeping the adapter forever; migrating state+error+monitor behind one adapter; adapter performing business logic.
- Bool flags alongside the state machine; transitions from `disposed`; firing callbacks synchronously from the platform thread without marshalling; a generic FSM framework; state duplicated in widgets; silent no-op on invalid (state, event).

### Architecture Approach (from ARCHITECTURE.md)

The v3.0 rewrite does **not** greenfield a new kernel. It wraps the existing v2.1 kernel behind a **compatible-replacement adapter seam**, then swaps implementations under it one capability at a time. The UI->Kernel contract (`MediaEngine` / `EngineStateView` / `PlaybackController` facade) is **frozen** and never changes shape during migration — only the backing implementation moves from `OldFvpEngine` to `NewFvpEngine` behind the adapter. Two new first-class folders: `lib/kernel/diagnostics/` (elevates `KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog` into one cohesive subsystem with a `DiagnosticsBundle` carrier) and `lib/kernel/errors/` (the sealed `PlayerError` becomes a cross-cutting domain type, not a generic model).

**Major components:**
1. **`EngineStateView` / `MediaEngine` (frozen interfaces)** — the 7-ISP composite contract UI binds to via `ValueListenableBuilder`. ~12 `ValueNotifier` getters. The adapter implements this verbatim — no extra methods.
2. **`PlaybackController` (frozen facade shape)** — UI's single entry point; delegates to `PlaybackNavigator` / `FileOperations` / `PlaybackStateManager` / `AutoAdvancePolicy`. v3.0 keeps the facade shape; `PlaybackControllerV2` decomposes internals.
3. **`KernelAdapter` (NEW, the spine)** — implements `MediaEngine`; holds old + new engine refs + a `DelegationPolicy`; routes per-call to one of them. Constructed in `app.dart`, handed to UI exactly where `MediaEngine` used to go. **No state except `KernelMode` + generation counter.**
4. **`DiagnosticsBundle` (NEW)** — one immutable carrier: `KernelLogger` + `MemoryMonitor` (instance) + `EngineMetrics` + `EngineEventLog`; single ctor param to any kernel component needing diagnostics. `DiagnosticsBundle.noop` for tests/release. Replaces global singletons + `static` access.
5. **`KernelLogger` (NEW, zero-dep facade)** — `lib/kernel/**` depends ONLY on this abstraction, never on `package:logger`. `KernelLoggerImpl` wraps `dart:developer.log` + gated `debugPrint`. App-level `log.dart` keeps `package:logger` for file rotation but registers as a `LogSink` via `app.dart` (wiring outside kernel).
6. **`SealedErrorModel` (EXTEND existing `player_error.dart`)** — stable codes + `ErrorContext` bag; `engine error -> PlayerError+context -> lastError.value + logger.e() -> service enriches -> UI exhaustive switch`. Never surfaced to UI as raw sealed object — `ErrorView` translation at the boundary (string code + localized message + severity).
7. **`MemoryMonitor` (REFACTOR singleton -> instance + static bridge)** — moved to `diagnostics/`, split data classes to `memory_snapshot.dart`; ctor-injected `RssProvider` interface + `Clock`; static bridge delegates to held `_default` during migration, deleted in verification phase.
8. **`EngineStateMachine` v2 (harden existing)** — lifecycle states (`disposed`/`disposing`/`error`-recovery), `openGeneration` guard moved IN (unified with `OpenGenerationTracker`), explicit `recover()` transition, double-dispose safety; unit-testable without an mdk.Player.

**Key data-flow changes:**
- Diagnostics injection replaces global access (`DiagnosticsBundle` built in `app.dart`, threaded via ctor).
- Error flow becomes typed end-to-end (one error -> one notifier assignment + one structured log record).
- Log calls decouple from `package:logger` (kernel calls `bundle.logger.x(...)`; `package:logger` reachable only via app-level sink registration).
- Adapter introduces a fan-out point with `ValueNotifier` identity preserved (forward the same instance, never re-wrap).
- `openGeneration` guard becomes a first-class lifecycle concept owned by the state machine.

### Critical Pitfalls (top 5 from PITFALLS.md — 12 total)

1. **`log.dart` already violates the zero-dep claim** — `package:logger` + `path_provider` are EXISTING deps with 121 call sites / 30 files. Treating `KernelLogger` as greenfield under-scopes a contract replacement migration. **Avoid:** preserve `log*.w(...)` call shape via a thin shim; move file rotation to the app layer; add a CI grep gate (`lib/kernel/**` must not import `package:logger`/`path_provider`).

2. **Double source-of-truth during dual-track** — two `MediaState`/`position`/`openGeneration` streams silently fork; seek lands on the wrong track. **Avoid:** one `KernelMode { legacy, migrated }` arbiter owned by the composition root (never UI); the adapter is an anti-corruption layer, not a multiplexer — the shadowed engine's notifiers are disconnected from UI; `openGeneration` is a single counter held by the adapter; a dual-track parity test gates each migration step.

3. **Adapter contract drift** — the contract is signature-level but compatibility is behavioral; new-kernel-only methods leak through (`seekPrecise`, `setBufferingTarget`) and legacy silently no-ops; `setSpeed` vs `setPlaybackRate` semantics diverge under the same UI call. **Avoid:** Phase 1 freezes a **Behavioral Contract Spec** (preconditions/postconditions/state-transitions/error-cases/ValueNotifiers-mutated per method); the adapter implements the frozen interface verbatim — no `MediaEngineV3` until legacy is deleted; P6 contract tests assert the BCS for both paths.

4. **State machine + generation-guard races** — the guard at `fvp_engine.dart:194` and the machine at `engine_state_machine.dart` were designed separately; a seek issued during the `await` window between `++_openGeneration` and the result check races a newer open; `ValueNotifier` re-entrancy causes livelock; silent assert-only ignore hides corruption in release. **Avoid:** unify via `OpenGenerationTracker`; exhaustive compiler-checked `switch` (no `default`); replace silent ignore with `Result.err` + `KernelLogger` warning; defer listener-triggered opens to `scheduleMicrotask`; add a P6 race test (open->seek->open rapidly, assert final state matches last open only).

5. **Over-engineering the adapter/facade (the project's documented nemesis)** — prior refactors produced "27 files 3500 lines", "19 state vars for 1 bool", "double source-of-truth". The compatible-replacement approach *invites* the same failure: a permanent god adapter layer with its own state/interface hierarchy/arbitration. **Avoid:** size budget (adapter + facade + sealed error + tracker < legacy `FvpEngine`); adapter holds no state except `KernelMode` + generation counter; no `MediaEngineV3` interface before legacy deletion; `KernelLogger` is a thin pass-through (if it grows appenders/formatters/plugin system it has re-invented `package:logger`); invoke senior-architect / red-team skills on the adapter design in Phase 2 to challenge scope creep.

*(See PITFALLS.md for the remaining 7: collapsing adapter too early, singleton->DI build break, MemoryMonitor interfering with playback, sealed error across mdk callback thread, regression during incremental swap, release log leak, bilingual doc-comment drift.)*

---

## Implications for Roadmap

The 4 researchers **converged on findings but diverged on build order**. The STACK + FEATURES researchers (web-blocked, less code-grounded) put `KernelLogger` FIRST and the adapter LATER. The ARCHITECTURE + PITFALLS researchers (code-grounded, read live files) put the **anti-corruption adapter EARLY (phase 2)** and **Phase 1 = Contract Freeze**.

**The recommended build order ADOPTS THE CODE-GROUNDED ORDERING.** Rationale: the adapter MUST exist before the state/lifecycle rewrite, or replacing the engine becomes a forbidden big-bang swap (the milestone explicitly forbids one-shot full replacement). `KernelLogger`-first sounds appealing but lands a facade with nowhere to route it through, and — critically — misses that `log.dart` already imports `package:logger` (121 call sites): the logger migration is a **replacement**, and its call-shape preservation matters more than landing it first. Contract freeze first means the adapter implements a frozen, audited behavioral spec, not a signature-level guess.

### Phase 1: Contract Freeze + Baseline Inventory
**Risk: LOW | Research needed: LOW (standard interface capture)**
**Rationale:** The adapter and every later phase depend on a stable contract. Freezing it first prevents accidental contract drift during rewrite. This is also the only phase that can cheaply reconcile the 9-state-vs-6-state discrepancy before it forks the adapter.
**Delivers:** (a) Behavioral Contract Spec (BCS) — for each `MediaEngine`/`EngineStateView` member: preconditions, postconditions, `MediaState` transitions allowed, error cases, `ValueNotifier`s mutated. (b) Static call-site inventory: `package:logger` usage (121 sites / 30 files), `MemoryMonitor.start()`/`.snapshot()` (2 sites), `openGeneration` references. (c) Reconciliation of the 9-state (PROJECT.md) vs 6-state (`engine_state_machine.dart`) discrepancy — decide which is the frozen baseline and which states v3.0 must add. (d) Contract tests written against the interface (not the implementation) — these become the migration gate.
**Addresses:** FEATURES Capability 4 (contract tests), 5 (state reconciliation).
**Avoids:** Pitfall 3 (contract drift), Pitfall 8 (state discrepancy), Pitfall 1 (under-scoping the logger migration).

### Phase 2: Adapter Seam + DiagnosticsBundle Skeleton
**Risk: MEDIUM | Research needed: MEDIUM (ValueNotifier identity forwarding semantics)**
**Rationale:** The adapter must exist before any new capability can be routed through it; the `DiagnosticsBundle` shell must exist so Capabilities A/B/C have a carrier. Building the skeleton now with 100% routing to old engine means zero behavior change and a green test suite — a safe foundation for every subsequent phase.
**Delivers:** (a) Rename `fvp_engine.dart` -> `old_fvp_engine.dart`. (b) `KernelAdapter implements MediaEngine` forwarding everything to old. (c) `DiagnosticsBundle` with `noop` default. (d) `DelegationPolicy` (all-old). (e) `app.dart` composition root wires `KernelAdapter(old, old, policyAllOld)` where `FvpEngine` used to go. (f) Full test suite 100% green.
**Uses:** Dart 3 `abstract interface class`, `final class ... implements`, `package:flutter/foundation` `ValueListenable`/`ChangeNotifier`.
**Implements:** Architecture Pattern 1 (Compatible-Replacement Adapter) + Pattern 2 (DiagnosticsBundle).
**Addresses:** FEATURES Capability 4 (adapter skeleton, dual-track coexistence, switch from config).
**Avoids:** Architecture Anti-Pattern 1 (adapter wraps ValueNotifiers — forward instances instead), Pitfall 2 (double source-of-truth — single `KernelMode` arbiter), Pitfall 10 (over-engineering — set the size budget here, enforce "no state except KernelMode + generation counter").

### Phase 3: KernelLogger Facade (Replacement Migration)
**Risk: LOW (pattern) / MEDIUM (migration surface) | Research needed: LOW**
**Rationale:** `KernelLogger` is a prerequisite for the sealed error model (errors and logs must share a vocabulary). It is independent of the state rewrite, so it can land before it. Doing it after the adapter means the facade has a carrier (`DiagnosticsBundle.logger`) and a routing seam. The migration is a **replacement** of 121 call sites, so the facade MUST preserve `log*.w(...)` call shape.
**Delivers:** (a) `diagnostics/kernel_logger.dart` + `log_level.dart` + `log_sink.dart` (`DevToolsSink` over `dart:developer.log` + `DebugPrintSink` gated by `kDebugMode`). (b) `logger` added to `DiagnosticsBundle`. (c) Sweep `lib/kernel/**` replacing `import '../utils/log.dart'` + `logEngine.x`/`logServices.x`/`debugPrint(...)` with `bundle.logger.x(...)` — preserving call shape so the 30 files migrate by import/declaration change. (d) App-level `log.dart` optionally registers as a `LogSink` in `app.dart` (wiring outside kernel). (e) CI grep gate: `lib/kernel/**` imports no `package:logger`/`path_provider`.
**Uses:** `dart:developer.log`, `dart:convert` (jsonEncode), `flutter/foundation` (`debugPrint`, `kDebugMode`).
**Addresses:** FEATURES Capability 1 (table stakes: levels, gating, context, redaction, named loggers, sinks).
**Avoids:** Pitfall 1 (preserve call shape, 121-site migration not 121-site rewrite), Pitfall 11 (release log leak — `kDebugMode` gate + `dart:developer.log` for warn/error), Architecture Anti-Pattern 3 (KernelLogger re-introduces `package:logger` — kernel never imports it).

### Phase 4: Sealed Error Model Stabilization
**Risk: MEDIUM | Research needed: MEDIUM (sealed error crossing mdk callback thread)**
**Rationale:** Depends on `KernelLogger` (Phase 3) for structured emission. The error model touches engine catch sites (Capability E's domain) but can be applied to the OLD engine first (it still runs behind the adapter), so it does NOT block on the state rewrite. The sealed `PlayerError` ALREADY EXISTS — this is stabilize/extend, not invent.
**Delivers:** (a) Move `player_error.dart` to `errors/`; add `ErrorContext` (action, generation, path, timestamp, module) + `ErrorCode` registry. (b) Audit every `FvpEngine` `on Exception catch` site — construct `PlayerError` with `ErrorContext`, assign `lastError.value`, emit via `bundle.logger.e(...)`. (c) `PlaybackController._onError` signature: `void Function(Object)` -> `void Function(PlayerError)`. (d) UI `error_banner` renders via exhaustive `switch`. (e) `ErrorView` (string code + localized message + severity) translation at the UI boundary — the sealed `KernelError` is NEVER surfaced to UI as a raw sealed object. (f) Marshal errors across the mdk callback boundary: reconstruct on main thread, carry callback stack as a `callbackStackTrace` field.
**Uses:** Dart 3 `sealed class` + `final class` subclasses, `StackTrace.current`, exhaustive `switch`.
**Addresses:** FEATURES Capability 2 (sealed hierarchy, stable codes, recoverable/fatal split, propagation, exhaustive handling).
**Avoids:** Pitfall 7 (sealed error across threads — reconstruct on main, `ErrorView` at UI boundary, ban bare `catch (e)`, error codes frozen never renamed), Architecture Anti-Pattern 5 (treating the error model as new — EXTEND in place, preserve `ValueNotifier<PlayerError?>`).

### Phase 5: MemoryMonitor First-Class
**Risk: LOW | Research needed: LOW (standard singleton->instance bridge)**
**Rationale:** Depends on `DiagnosticsBundle` (Phase 2) and benefits from `KernelLogger` (Phase 3) for threshold emission. The most self-contained capability and the lowest risk, so it lands after the cross-cutting logger/error work to avoid churning on two fronts.
**Delivers:** (a) Move `memory_monitor.dart` to `diagnostics/`, split data classes to `memory_snapshot.dart`. (b) Instance class with ctor params (threshold/maxHistory/interval) — current values as defaults. (c) Constructor-injected `RssProvider` interface (default wraps `ProcessInfo`; `FakeRssProvider` ~10 lines for tests — no `mocktail`). (d) `Clock` injection. (e) **Transient static bridge** delegates to held `_default` instance — `main.dart`'s `MemoryMonitor.start()` keeps working. (f) `memoryMonitor` added to `DiagnosticsBundle`; one instance constructed in `app.dart` — the SAME one the bridge delegates to. (g) **In ONE atomic commit**: rewrite the 2 static callers AND delete the static shim.
**Uses:** `dart:async` (`Timer.periodic`), `dart:io` (`ProcessInfo.currentRss`), `flutter/foundation` (`ValueNotifier<MemorySnapshot?>`).
**Addresses:** FEATURES Capability 3 (instance-based, clock-injected, config, non-interference, toggleable, snapshot/export).
**Avoids:** Pitfall 5 (atomic commit, never delete `_instance` while keeping statics), Pitfall 6 (`NoopMemoryMonitor` in player subtree, real monitor only in diagnostics scope), Architecture Anti-Pattern 4 (delete bridge in Phase 7).

### Phase 6: State & Lifecycle Rewrite
**Risk: HIGH | Research needed: HIGH (lifecycle hardening, generation unification, race testing)**
**Rationale:** The largest and riskiest change. Benefits from ALL prior capabilities being in place. Building it earlier means rewriting the engine twice. The adapter (Phase 2) makes this possible without a forbidden big-bang swap.
**Delivers:** (a) `new_fvp_engine.dart` implementing `MediaEngine` against `DiagnosticsBundle` and emitting `PlayerError+context`. (b) `EngineStateMachine v2`: lifecycle states (`disposed`/`disposing`/`error`-recovery), `openGeneration` guard moved IN (unified with `OpenGenerationTracker`), explicit `recover()`, double-dispose safety. (c) Flip `DelegationPolicy` one-by-one to `new`; run Phase 1 contract tests after each flip. (d) Replace silent assert-only illegal-transition ignore with `Result.err` + `KernelLogger` warning. (e) Marshal mdk callbacks to main isolate; defer listener-triggered opens to `scheduleMicrotask`. (f) Race test: open->seek->open rapidly, assert final state matches last open only.
**Uses:** Dart 3 `sealed class PlaybackState`, exhaustive `switch`, `dart:async` (`Timer`, `Completer`), `OpenGenerationTracker`.
**Addresses:** FEATURES Capability 5 (sealed states, transition table, openGeneration guard, callback marshalling, idempotent + reject-invalid, disposed terminal).
**Avoids:** Pitfall 8 (unify guard + machine, `Result.err` not silent ignore, `scheduleMicrotask` for re-entrancy), Pitfall 2 (single canonical engine per cutover step), Architecture Anti-Pattern 2 (flip policy per-capability with contract tests after each).

### Phase 7: Test, Migration Verification & Adapter Collapse
**Risk: MEDIUM | Research needed: MEDIUM (dual-track differential testing)**
**Rationale:** Verification is only meaningful once the cutover is complete. Collapse is the riskiest delete and must be gated by an explicit checklist, never bundled with a feature commit.
**Delivers:** (a) Contract tests (Phase 1) pass against `NewFvpEngine`. (b) Dual-track regression suite: same UI widget tests against `KernelAdapter` with policy all-old vs all-new — outputs must match, including timing-sensitive cases via `fakeAsync`. (c) Migration order derived from dependency graph (`codegraph`): leaves first, then orchestrator, then state managers, then UI bindings. (d) **Adapter-deletion gate checklist**: 100% callers migrated, dual-track parity passing for N regressions, `openGeneration` guard moved into new engine, platform fallback paths audited. (e) Collapse in a DEDICATED commit. (f) Keep adapter behind a kill switch for one milestone. (g) Delete `old_fvp_engine.dart` + static `MemoryMonitor` bridge. (h) `flutter analyze` strict-clean, coverage >= 80% on `kernel/`. (i) Release-build CI gate: `--release` smoke test produces zero `debugPrint`/`debug`/`info` lines.
**Addresses:** FEATURES Capabilities 4 (collapse plan), 5 (property tests).
**Avoids:** Pitfall 4 (deletion gate checklist, dedicated commit), Pitfall 9 (graph-derived order, timing tests, feature flag per service, no partial service migration), Pitfall 11 (`--release` smoke gate).

### Phase 8: Bilingual API Doc Standard
**Risk: LOW | Research needed: LOW (parallel with Phases 3-6)**
**Rationale:** A final pass guarantees no API missed. The structure must be agreed in Phase 1 so Phase 2-6 code is written bilingual from the start.
**Delivers:** (a) Doc-comment structure: `///` intent line (Chinese), blank line, `///` contract block (English: params, returns, throws/states, invariants). English is behavior-authoritative; Chinese is "why"-authoritative. (b) Sweep `diagnostics/`, `errors/`, `kernel_adapter.dart`, `new_fvp_engine.dart`, `engine_state_machine.dart` v2. (c) Lint/grep: every public symbol in `lib/kernel/**` modified in v3.0 has both intent (CN) + contract (EN); every `KernelError` subclass carries error code + English contract. (d) Migrate existing Chinese-only doc comments — only for symbols the rewrite touches (scope creep otherwise).
**Addresses:** PROJECT.md target 7 (bilingual API).
**Avoids:** Pitfall 12 (structure beats free-form prose, English authoritative, lint for presence).

### Phase Ordering Rationale

- **Contract freeze before everything (P1->P2+):** the adapter implements the frozen contract; without freeze, contract drift breaks the migration gate. Freezing first is the only phase that can cheaply reconcile the 9-vs-6 state discrepancy.
- **Adapter before state rewrite (P2 before P6):** the new engine only has somewhere to live because the adapter routes to it; without the adapter, replacing the engine means a big-bang swap (forbidden). The adapter MUST exist before the state/lifecycle rewrite.
- **Logger before error model (P3->P4):** the error model emits structured logs through the logger; they must share a vocabulary, so `KernelLogger` must exist before error sites are rewritten.
- **Bundle before A/B/C (P2->P3/4/5):** all three diagnostics capabilities need the `DiagnosticsBundle` carrier built in P2.
- **State rewrite last among capabilities (P6 after P3/4/5):** E consumes A, B, C, D — building it earlier forces rework; doing it last means the new engine is born first-class.
- **Verify + collapse after cutover (P7 after P6):** verification is only meaningful once cutover is complete; collapse is a gated delete.
- **Code-grounded ordering over web-blocked ordering:** the STACK + FEATURES researchers put `KernelLogger` FIRST and the adapter LATER — this misses that `log.dart` already imports `package:logger` (121 call sites, a replacement not an addition) and that the adapter must precede the engine rewrite to avoid a forbidden big-bang swap. The code-grounded ordering (ARCHITECTURE + PITFALLS) is adopted because it is anchored in live files.

### Research Flags

**Phases likely needing deeper research during planning (`/gsd-plan-phase --research-phase <N>`):**
- **Phase 2 (Adapter):** ValueNotifier identity forwarding semantics — the adapter must forward the active engine's notifier **instances** (not re-wrap) or `ValueListenableBuilder` listeners detach. This is the subtlest part of the adapter and deserves a focused research pass on Dart's `ValueListenable` identity/reactivity rules.
- **Phase 4 (Error Model):** Sealed error crossing the mdk callback thread boundary — reconstruct on main thread vs carry callback stack as a field; `ErrorView` translation shape; how `dart:developer` stack traces behave across isolates. Research the mdk `FvpCallbackHandler` threading model.
- **Phase 6 (State Rewrite):** Lifecycle hardening + `openGeneration` unification — the 9-vs-6 state reconciliation (P1) feeds directly into which lifecycle states v3.0 adds; race testing patterns for `open->seek->open`; `scheduleMicrotask` re-entrancy discipline. This is the highest-risk phase and warrants the deepest research.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Contract Freeze):** standard interface-capture + contract-test authoring; the 9-vs-6 reconciliation is a decision, not a research question.
- **Phase 3 (KernelLogger):** facade + sink is well-trodden; the migration is mechanical once call shape is preserved.
- **Phase 5 (MemoryMonitor):** singleton-to-instance bridge is a standard refactor with a documented anti-pattern to avoid.
- **Phase 7 (Verify + Collapse):** dual-track differential testing is non-trivial but pattern-established; the deletion-gate checklist is a review exercise.
- **Phase 8 (Bilingual docs):** doc-comment structure + lint; standard.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against Dart 3 + Flutter foundation docs via Context7; all primitives are stdlib or already-present transitives; zero-dep claim holds. The single critical gotcha (debugPrint not stripped in release) is explicitly documented. |
| Features | MEDIUM | Web verification unavailable; findings rest on established SE patterns (Strangler Fig / ACL, sealed hierarchies, logging facade, media FSM) plus direct review of MemoryMonitor, MediaEngine, PROJECT.md. The feature landscape is well-grounded but the competitor/reference analysis (mpv, ExoPlayer) is from memory, not freshly fetched. |
| Architecture | HIGH | Grounded in the live v2.1 codebase; read media_engine.dart, engine_state_view.dart, fvp_engine.dart, engine_state_machine.dart, player_error.dart, memory_monitor.dart, log.dart, playback_controller.dart, main.dart, pubspec.yaml. Component boundaries, data flow, and the adapter seam are anchored in actual files. |
| Pitfalls | HIGH | Grounded in this codebase actual files + the project own documented anti-pattern memory (feedback_singleton_refactoring.md, anti_pattern_fullscreen_architecture.md, project_window_anti_patterns.md, project_fvp_engine_improvements.md, feedback_comment_while_coding.md). 12 pitfalls each with warning signs + phase mapping + recovery strategies. |

**Overall confidence:** HIGH — the architecture and pitfalls research are code-grounded and mutually reinforcing; the stack is verified against primary docs; only the features research carries a MEDIUM caveat from the web-blocked environment (mitigated by direct code review).

### Gaps to Address

- **9-state vs 6-state reconciliation (Phase 1 must resolve):** PROJECT.md documents 9 states ~40 edges; engine_state_machine.dart implements 6 MediaState values. Phase 1 must decide: is 6 the frozen baseline and 9 aspirational, or is the machine missing disposed/disposing/error-recovery states that v3.0 must add? Unresolved, this forks the adapter contract.
- **PlaybackController mixin-composition migration order (Phase 7):** PlaybackController + 3 mixins means a service dependencies are implicit; swapping the controller without swapping its mixins leaves a hybrid. The migration order must be derived from the dependency graph (codegraph) — not yet computed. Flag for Phase 7 planning.
- **FvpCallbackHandler threading model (Phase 4 research):** sealed errors crossing the mdk callback thread need the exact marshalling semantics (which thread, re-entrancy, Zone boundaries). Phase 4 research-phase should inspect fvp_callback_handler.dart directly.
- **Strangler Fig collapse criteria specifics (Phase 7):** N consecutive regressions and zero legacy references need concrete N + a codegraph query plan. The general checklist is solid; the specifics are a Phase 7 planning input.
- **Media-FSM thread-safety specifics (Phase 6 research):** the general pattern (marshal to main isolate) is clear; the specific SchedulerBinding / single-StateStore-lock mechanism for this codebase is a Phase 6 research-phase input.
- **Existing EngineEventLog / EngineMetrics ownership (Phase 2):** ARCHITECTURE.md moves these to diagnostics/; confirm they are currently fields on FvpEngine (v2.1) and that the DiagnosticsBundle migration does not break their existing consumers before Phase 2 lands.

---

## Sources

### Primary (HIGH confidence — code-grounded)
- D:\simple_player_flutter\.planning\PROJECT.md — v3.0 milestone scope, hard constraints (zero new dep, compatible replacement, no UI change, no logger package in kernel), key decisions.
- D:\simple_player_flutter\lib\kernel\engine\media_engine.dart — frozen 7-ISP composite MediaEngine interface (the preserved UI->Kernel contract).
- D:\simple_player_flutter\lib\kernel\engine\engine_state_view.dart — frozen read-only state surface (~12 ValueNotifiers).
- D:\simple_player_flutter\lib\kernel\engine\fvp_engine.dart — current FvpEngine (becomes OldFvpEngine): factory ctor, EngineStateMachine, openGeneration guard at line 194, EngineMetrics, EngineEventLog, on Exception catch sites, lastError assignments, PathUtils.basename redaction at line 260.
- D:\simple_player_flutter\lib\kernel\engine\engine_state_machine.dart — 6-state exhaustive machine, _canTransitionTo switch, togglePlayPause via injected callbacks, silent assert-only illegal-transition ignore at lines 52-58, late-injected onPlay/onPause (lines 28-33, a workaround to retire).
- D:\simple_player_flutter\lib\kernel\models\player_error.dart — EXISTING sealed PlayerError hierarchy (File/Codec/Playback/Network/Unknown + enum codes) — v3.0 EXTENDS, does not replace.
- D:\simple_player_flutter\lib\kernel\utils\memory_monitor.dart — static-singleton MemoryMonitor (50MB/200/30s hardcoded, DateTime.now(), direct debugPrint at line 158, _instance + static start/stop/snapshot/exportJson).
- D:\simple_player_flutter\lib\kernel\utils\log.dart — existing package:logger + package:path_provider dependency; module loggers log, logEngine, logBridge, logServices, logUi + initLog() file rotation; 121 call sites across 30 files.
- D:\simple_player_flutter\lib\kernel\services\playback_controller.dart — PlaybackController facade (4 sub-modules via PlaybackContract), DebugProbe, currentFileName, _onError callback.
- D:\simple_player_flutter\lib\main.dart — composition root: initLog(), MemoryMonitor.start() at line 16, EnginePrewarm, StartupCoordinator.
- D:\simple_player_flutter\pubspec.yaml — confirms logger ^2.5.0 and path_provider ^2.1.5 are EXISTING deps (the zero NEW dependency constraint is about not adding more + decoupling kernel from them).
- D:\simple_player_flutter\lib\ui\** audit — 18 widgets take MediaEngine/EngineStateView (the frozen contract surface).

### Secondary (HIGH confidence — project memory, documented lessons)
- feedback_singleton_refactoring.md — delete _instance but keep static methods -> build failure (Pitfall 5 root).
- anti_pattern_fullscreen_architecture.md — 10 architecture anti-patterns: over-engineering, double source-of-truth, silent failures, dispose races, 19 vars for 1 bool (Pitfall 10, 2, 8 root).
- project_window_anti_patterns.md — kernel coupling, god objects, over-abstraction lessons.
- project_fvp_engine_improvements.md — openGeneration guard introduction (Pitfall 8 root).
- feedback_comment_while_coding.md — bilingual doc-comment discipline (Pitfall 12 root).

### Tertiary (HIGH confidence — external docs via Context7)
- Context7 /dart-lang/site-www — Dart 3 sealed classes + exhaustive switch with compiler-enforced error on non-exhaustive branches; bool.fromEnvironment compile-time strip pattern; dart:developer logging surface.
- Context7 /websites/api_flutter_dev — debugPrint is a DebugPrintCallback getter/setter (swappable, NOT auto-stripped); debugPrintSynchronously is the unthrottled variant; kDebugMode/kReleaseMode are the compile-time strip constants.
- Context7 /websites/dart_dev — --enable-asserts/--observe run flags; DevTools Logging + Performance tabs as the consumer for dart:developer.log + Timeline.

### Reference patterns (MEDIUM confidence — from memory, not freshly fetched)
- Strangler Fig Application (Martin Fowler) — incremental migration behind a preserved facade.
- Anti-Corruption Layer (Domain-Driven Design) — translate types at the boundary so the new kernel is not polluted by old types.
- mpv MPContext state + mp_msg level/module logging; AndroidX Media3 Player state model + AnalyticsCollector (injectable diagnostics) — media kernel references for state machine + logging + diagnostics patterns.

---
*Research completed: 2026-07-16*
*Ready for roadmap: yes*
