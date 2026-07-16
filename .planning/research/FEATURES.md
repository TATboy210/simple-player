# Feature Research

**Domain:** Flutter desktop media player — v3.0 kernel rewrite (compatible replacement + diagnostics-first kernel)
**Researched:** 2026-07-16
**Confidence:** MEDIUM (web verification unavailable in this environment; findings rest on established SE patterns — Strangler Fig / Anti-Corruption Layer, sealed error hierarchies, logging facade, media FSM — plus direct review of the project's `MemoryMonitor`, `MediaEngine`, and `PROJECT.md` constraints)

> Scope note: This is a **behavior** research file, not a stack file. Each of the 5 v3.0 capabilities is categorized into Table Stakes / Differentiators / Anti-Features with complexity, dependencies on the existing kernel, and explicit warnings on anti-features. Replaces the prior v2.x feature landscape (EngineState mixin slimming, FvpEngine split, etc. — those are now the baseline, not the target). Feeds requirement categorization for the v3.0 kernel rewrite milestone.

---

## Feature Landscape

For each capability: **Table Stakes** = missing it, the capability feels broken or regresses the existing player; **Differentiators** = not expected but valuable for a media kernel; **Anti-Features** = commonly attempted but harmful — each carries an explicit warning.

---

### Capability 1 — Zero-Dependency Logging Facade (`KernelLogger`)

Project constraint (PROJECT.md): **no `logger` package**, kernel keeps minimal dependency boundary. Facade = `dart:developer` (primary) + controlled `debugPrint` (secondary). Future file/remote sinks swap behind the facade without touching call sites.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Level hierarchy (trace/debug/info/warn/error/fatal) | Log levels are the universal vocabulary; without them operators can't filter noise | LOW | Enum-based; `fatal` distinct from `error` because media-engine fatal = process-teardown decision |
| Compile-time level gating via `kReleaseMode` | Release builds must not pay for logging; `debugPrint` is already no-op'd in release — extend the same idea to the facade | LOW | Branch on `kReleaseMode`; dead-code elimination removes trace/debug bodies in release |
| Structured context (key-value) | String interpolation loses fields; structured context enables a later sink to emit JSON without re-parsing | MEDIUM | `LogRecord` carries `Map<String, Object?> context`; callers pass `Logger.info('engine.open', {'gen': gen, 'path': redacted})` |
| Stable call-site API (`Logger.x(msg, {context})`) | Call sites must not change when sinks swap — that's the whole point of a facade | LOW | Static facade methods delegating to a configurable `LogSink` interface |
| Redaction at the boundary | Paths, user file names, and engine-internal buffers must never leak into logs verbatim | MEDIUM | Redactor applied in the facade before forwarding to sink; project already validates paths (`PathValidator`) — reuse |
| No-op by default in release | Release users never see kernel logs; devs opt in via `--dart-define` | LOW | Default sink = `NullSink` in release; `DeveloperLogSink` in debug |
| Isolate-safe writes | `dart:developer.log` is isolate-aware; `debugPrint` is throttled/serialized by Flutter — safe. Custom sinks must preserve this | LOW | Document in `LogSink` contract: implementations must be isolate-safe |
| Named/child loggers per module | Kernel has 5+ subsystems (engine, services, playlist, diagnostics); flat logs are untraceable | LOW | `Logger('kernel.engine')`, `Logger('kernel.playback')`; hierarchical name, dot-separated |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Correlation via `openGeneration` on every log | Ties a log line to the exact `open()` attempt that produced it — invaluable for race diagnosis (the bug class v3.0 explicitly targets) | MEDIUM | `openGeneration` guard already exists in v2.1; surface it as a context key in the facade |
| Lazy message construction | Avoid `toString()` on expensive objects when the level is gated off (e.g. full `MediaInfo` dump at trace) | LOW | Pass `String Function()` lazy builder; only invoked if level passes the gate |
| In-memory ring buffer + crash export | Last N records kept; on fatal, flushed to a sink or attached to an error report | MEDIUM | Ring buffer of `LogRecord`; cap configurable; differentiator because the project already has `EngineEventLog` — unify under the facade |
| Bilingual messages (zh intent + en contract) | Matches PROJECT.md doc standard; log *sites* tag code with both, but *messages* stay English for grep-ability | LOW | Pattern: `// 中文意图` comment + English log string (never log Chinese — breaks log tooling) |
| Per-sink level filter | Devs turn engine to trace but keep UI at info; one global level is too coarse | LOW | `LogSink.attach(minLevel: ...)` |

#### Anti-Features (with explicit warnings)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ⚠️ Pull in `logger` / `logging` package | "Battle-tested, why hand-roll" | Violates PROJECT.md hard constraint; adds a runtime dep to the kernel — the one layer that must stay minimal; future sinks do not require a package | Hand-roll a ~150-line facade; the `LogSink` interface is the extensibility seam |
| ⚠️ Async file/remote sinks in the kernel | "Log to file for support tickets" | Kernel must not own I/O lifecycle or isolate plumbing; async file writes on the playback thread cause jank; scope creep outside v3.0 | Define `LogSink` interface in kernel; implement file/remote sinks in a future out-of-kernel module. v3.0 ships `DeveloperLogSink` + `NullSink` only |
| ⚠️ Logging on the position-poller hot path (200ms tick) | "Full observability" | 5 log lines/sec × hours = multi-MB ring-buffer churn + GC pressure on the exact timer that drives the progress bar | Log position *transitions* (state changes, seek completion) not every poll tick; poller emits a trace only on drift/recovery |
| ⚠️ `print()` / `debugPrint()` directly at call sites | "Quicker than the facade" | Bypasses redaction, level gating, and context; can't be redirected to a sink; `print` is not stripped in release | All kernel logging goes through `KernelLogger`; `debugPrint` is a *sink implementation detail*, never a call-site API |
| ⚠️ Mutable global logger configuration after init | "Tune levels at runtime from a settings panel" | Runtime reconfig of a kernel singleton reintroduces the exact global-state coupling v3.0 is removing (see MemoryMonitor anti-pattern below) | Config resolved once at kernel boot; if runtime tuning is needed later, expose via a controlled `LogConfig` value object, not direct singleton mutation |
| ⚠️ Logging user file paths/URIs verbatim | "Need to see what file failed" | PII / privacy; paths are load-bearing for a media player | Redact path to basename + length, or a stable hash; keep full path only behind an explicit `--dart-define=KERNEL_LOG_PII=true` dev flag |

---

### Capability 2 — Structured Error Model

`PlaybackController` today mixes error recovery into business flow with no stable codes (PROJECT.md known issue). Goal: sealed hierarchy, stable codes, recoverable vs fatal split, propagation kernel→service→UI. Note: a prior v2.x research item (T3 "状态模型统一") proposed unifying `MediaErrorType` + `PlayerErrorCode` — v3.0 subsumes that into a proper sealed hierarchy.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sealed error hierarchy (Dart 3) | Enables exhaustive `switch` in handlers; compiler enforces every error is handled — no silent fall-through | MEDIUM | `sealed class KernelError` with `RecoverableError` and `FatalError` sub-hierarchies; project coding-style already mandates sealed types for errors |
| Stable error codes (string/enum, not message text) | Messages are i18n'd and change; codes are the stable contract for metrics, tests, and UI branching | MEDIUM | e.g. `engine.open.codec-unsupported`, `engine.open.file-not-found`, `playback.seek.out-of-range`; namespaced by subsystem |
| Recoverable vs fatal split | Media kernels must distinguish "skip this track" from "tear down the engine"; collapsing them causes either stuck playback or silent crashes | HIGH | Fatal = engine can't continue (init fail, texture lost); Recoverable = retry/skip/dismiss (decode error, missing subtitle track). Rooted at the `KernelError` level, not per-leaf |
| Error carries structural context | An error with only a message is useless for diagnosis; need the `openGeneration`, path, state-at-failure, engine error code | MEDIUM | `KernelError({required String code, required String message, Map<String,Object?> context, KernelError? cause})` |
| No silent swallow (`catch (_) {}` forbidden) | Project coding-style + CLAUDE.md already forbid this; the error model must make it structurally hard | LOW | Use typed `on` clauses; catch `Exception` subtypes, never `Error` subtypes (those are programming bugs) |
| Error propagation path kernel→service→UI | UI must receive a typed error (or a user-facing message derived from the code), never a raw `PlatformException` or fvp error object | HIGH | Service layer catches kernel errors, maps to `RecoverableError`/`FatalError` or a `Result<T>`; UI maps code → l10n string |
| Exhaustive handling at every boundary | A new error leaf added later must force every handler to decide — compiler-guaranteed | MEDIUM | Sealed type + `switch` expression without default; lint rule (no `default` on sealed switch) |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Error correlated with `openGeneration` | "Was this decode error from the file I'm playing now, or the one I just switched away from?" — the #1 race-class diagnosis question | MEDIUM | Every `KernelError` carries `openGeneration` in context; stale-generation errors are downgraded to trace, not surfaced |
| Retry policy attached to error type | `RecoverableError.retryPolicy` tells the service how many times / how long to wait before giving up — instead of ad-hoc `retry++` counters | MEDIUM | Enum policy: `none`, `once`, `backoff`, `skipTrack`; media-specific (skip-track is common) |
| Error metrics (count per code) | "Decode error spiked after this codec" — operational signal | MEDIUM | Hook the facade: every emitted error increments a counter by code; reuse `EngineMetrics` plumbing |
| User-facing message mapping table (code → l10n key) | Decouples error source from user language; one code, many localizations | LOW | Map in a single `KernelErrorL10n` lookup; UI never switches on message text |
| `Result<T>` for non-exception control flow | `open()` returns `Result<MediaSession>`; callers `switch` on `Ok`/`Err` — no try/catch for expected outcomes | MEDIUM | Matches project coding-style (`sealed class Result<T>` example); reserve exceptions for truly unexpected |

#### Anti-Features (with explicit warnings)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ⚠️ Using exceptions for control flow | "Simpler than Result types" | Stack-trace cost on hot paths; hides expected-ness; project coding-style explicitly forbids exceptions for control flow | `Result<T>` for expected outcomes; exceptions only for programmer bugs |
| ⚠️ Catching `Error` subtypes (`StateError`, `TypeError`) | "Catch everything to be safe" | `Error` subtypes indicate programming bugs; catching them masks bugs and the project style guide forbids it | Let `Error` propagate; catch only `Exception` subtypes; log + crash on `Error` |
| ⚠️ A giant flat error union (50+ leaves) | "Cover every fvp error code" | Unmaintainable switch; most fvp codes map to a small number of *kernel* behaviors | Categorize fvp codes into ~10-15 kernel error leaves via a mapping table at the engine boundary (this is itself part of the anti-corruption layer) |
| ⚠️ Propagating raw fvp/MDK error objects to UI | "UI needs the full info" | Couples UI to engine internals; violates the kernel boundary v3.0 is enforcing; fvp types may change | Map at engine boundary into `KernelError`; UI only ever sees `KernelError` or its `Result` wrapper |
| ⚠️ Embedding user-facing strings in the error object | "Convenient" | Forces re-translation when the error is thrown; breaks i18n; message becomes the contract | Error carries `code` + `context`; strings live in a separate l10n map keyed by code |
| ⚠️ Retry-without-generation-guard | "Just retry on error" | Retries against a stale `openGeneration` resurrect a dead playback — exactly the race v2.1 `openGeneration` was added to prevent | Retry policy checks `openGeneration` before re-attempting; stale → discard |

---

### Capability 3 — Injectable / Toggleable Diagnostic Monitor (`MemoryMonitor` first-class)

Current state (`lib/kernel/utils/memory_monitor.dart`): a **private singleton** with static `start/stop/snapshot/exportJson`, a hardcoded 50MB threshold, no clock injection, no toggle (you either call `start` or you don't), and it couples sampling + logging + notification in one class. This is the textbook "non-first-class" shape v3.0 is replacing.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Instance-based, not static singleton | A static singleton can't be scoped per-engine (future multi-instance), can't be swapped in tests, and re-introduces the global coupling v3.0 removes | LOW | `class MemoryMonitor { MemoryMonitor({required clock, required config}); }`; inject into kernel like any other dependency |
| Clock injection | Timer-based sampling must be testable without `fakeAsync` boilerplate at every call site; threshold logic needs deterministic time | MEDIUM | Inject a `Clock` (`DateTime now()` + `Timer Function(duration, callback)`); tests pass a fake clock; project testing rules already favor `fake_async` |
| Threshold + interval config | 50MB hardcoded + 30s hardcoded is wrong for every deployment except the one it was tuned in; must be configurable | LOW | `MemoryMonitorConfig({interval, growthThresholdBytes, maxHistory, peakTracking: bool})`; defaults match current behavior for parity |
| Start/stop lifecycle | Monitor must be pausable (during fullscreen transition, during seek storms) and cleanly disposable | LOW | `start()` / `stop()` / `dispose()`; `dispose` cancels timer + clears listeners; no static state to manually reset |
| Non-interference with playback business state | THE defining property: the monitor must never call into `PlaybackController`, never pause playback, never mutate `MediaState`. Diagnostics observe; they do not act. | MEDIUM | Enforce structurally: monitor depends on nothing in `services/`; it only reads `ProcessInfo` and emits `ValueNotifier<MemorySnapshot>` |
| Toggleable (can be fully disabled) | Some users/dev builds want zero monitoring overhead; must be a clean opt-out, not "just don't call start" | LOW | `MemoryMonitor.disabled` factory returns a no-op instance; kernel injects the disabled one when configured off |
| Snapshot/export | Existing behavior (`snapshot()`, `exportJson()`) must survive the refactor | LOW | Keep API; now instance methods; `MemorySnapshot`/`MetricSample` data classes unchanged (they're already immutable) |
| ValueNotifier output (preserve existing) | UI/widgets already listen via `snapshotNotifier`; breaking this regresses any diagnostics UI | LOW | Keep `ValueNotifier<MemorySnapshot?> snapshotNotifier`; now per-instance |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Pluggable metric sources | Tomorrow: GPU memory, frame timing, isolate count — same monitor, different probe | MEDIUM | `abstract class MetricProbe { MetricSample sample(); }`; `RssProbe` is the v3.0 impl; others added without touching monitor logic |
| Ring buffer with configurable cap + eviction policy | Current `_maxHistory=200` is hardcoded; a 1hr session at 1s interval blows past it silently | LOW | `RingBuffer<T>(capacity)`; configurable; report `droppedCount` in snapshot so consumers know data was lost |
| Per-monitor scope (per-engine) | Multi-instance (future) wants per-engine monitors; an instance-based monitor gives this for free | LOW | Direct consequence of instance-based design; document as the multi-instance on-ramp |
| Snapshot diff / windowed stats | "min/max/avg over last N samples" — cheap to compute, useful for trend diagnosis | LOW | Compute lazily in `MemorySnapshot`; only when `exportJson` or UI requests |
| Integration with `KernelLogger` (Capability 1) | Today the monitor calls `debugPrint` directly; should log through the facade with structured context | LOW | Replace `_logCurrent` `debugPrint` with `Logger.debug('memory.rss', {'rssMB': ..., 'deltaMB': ...})` |

#### Anti-Features (with explicit warnings)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ⚠️ Auto-acting on thresholds (auto-pause / auto-recover) | "If memory is high, pause playback to recover" | Violates non-interference (the defining property); couples diagnostics to business logic; a monitor bug now affects playback; untestable without a playback harness | Monitor emits a `MemorySnapshot` + a `thresholdExceeded` event; a *separate* policy (outside the monitor, in services) decides whether to act. v3.0 ships the monitor only, no auto-act policy |
| ⚠️ Sampling on the position-poller timer | "One timer is simpler" | Couples monitor cadence to playback cadence; can't disable monitor without affecting playback; can't tune intervals independently | Dedicated `Timer.periodic` owned by the monitor; never share the position poller's timer |
| ⚠️ Logging every sample | "Full observability" | At 1s interval over a 2hr movie = 7200 log lines of `RSS: 240.0 MB`; drowns signal, churns ring buffer, adds GC | Log only on threshold crossing or significant delta; otherwise the snapshot is available via `ValueNotifier` on demand |
| ⚠️ Static singleton "for convenience" | "It's just one monitor" | This is the exact current anti-pattern; prevents injection, per-engine scoping, and test doubles — all stated v3.0 goals | Instance, injected at kernel composition root |
| ⚠️ Synchronous heavy computation in the sample callback | "Compute stats inline" | Blocks the timer task; on Windows, timer coalescing can stutter the poller | Sample reads `ProcessInfo.currentRss` (cheap, sync); stats computed lazily on snapshot request |
| ⚠️ Exposing monitor internals to UI as raw types | "Let the widget read `_history`" | Couples UI to internal buffer; breaks when buffer impl changes | Expose only `MemorySnapshot` (immutable, already does this); UI never touches the monitor's internals |

---

### Capability 4 — Compatible-Replacement / Anti-Corruption Adapter Layer

PROJECT.md hard constraint: **no one-shot full kernel swap**. UI→Kernel call contract preserved; adapter swaps implementation underneath; dual-track coexistence; each migration step verifiable. This is the Strangler Fig / Anti-Corruption Layer pattern applied to an in-process kernel.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Preserve the external contract (`MediaEngine` + service surface) | UI and upper service layers must compile + run unchanged against the adapter; this is the definition of "compatible replacement" | HIGH | Adapter `implements MediaEngine` (the v2.1 ISP-composed interface); UI keeps depending on the interface, not the impl |
| Adapter implements old contract, delegates to new kernel | The seam: old callers keep calling the contract; adapter routes to old OR new impl per subsystem | HIGH | `KernelAdapter implements MediaEngine { final OldEngine _old; final NewEngine _new; ... method-by-method delegation }` |
| Dual-track coexistence (old + new both live) | Lets one subsystem migrate while others still use old impl; the only safe way to swap a working kernel incrementally | HIGH | Both engines instantiated; adapter chooses per-method (or per-feature-flag) which to call; old path stays the proven fallback |
| Per-interface seam points (not one god-adapter) | Wrapping all 6 ISP interfaces in one adapter = an unmaintainable 1:1 proxy; split by ISP interface | MEDIUM | One adapter per ISP interface (`EngineStateViewAdapter`, `PlaybackControlAdapter`, …) composed; matches the v2.1 ISP split exactly |
| Feature flag / config to switch tracks | Operators/devs must flip a subsystem from old→new without code changes, to A/B in real sessions | MEDIUM | `KernelSwitch(interface, target: {old, new, shadow})` resolved from `--dart-define` or a config object; never a runtime-mutable singleton |
| Contract tests (adapter preserves behavior) | Without tests proving the adapter == old impl for the contract, "compatible replacement" is a claim, not a guarantee | HIGH | One contract test suite per interface, run against both `OldEngine` and `Adapter→NewEngine`; failures block migration |
| Collapse plan with explicit exit criteria | An adapter that lives forever is technical debt; you must know when to delete it | MEDIUM | Document per-subsystem: "collapse when new impl passes contract tests for N consecutive phases AND old impl has zero callers"; delete adapter + old impl together |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Shadow mode (call new impl, discard result, compare) | Exercises new kernel with real inputs before trusting it; surfaces divergence before it reaches users | MEDIUM | Adapter calls old (returns to caller) and new (compares, logs diff via `KernelLogger`); off by default, on per-subsystem |
| Per-subsystem gradual rollout | Migrate `PlaybackControl` first (low blast radius), `EngineStateView` last (read-heavy, risky to get wrong) | LOW | Consequence of per-interface seams + per-interface switch |
| Anti-corruption: new kernel imports nothing from old | The new kernel must not be polluted by old types; the adapter translates at the boundary | HIGH | New kernel defines its own types; adapter maps old↔new at the seam; this is the "anti-corruption" in ACL |
| Telemetry comparing old vs new results | "New seek position differs from old by Xms" — quantifies behavioral drift | MEDIUM | Comparison results flow to `EngineMetrics`; diffs above threshold raise a warning via `KernelLogger` |
| Adapter-level generation guard parity | Old and new impls may handle `openGeneration` differently; adapter must normalize | MEDIUM | Adapter forwards the generation token uniformly; new impl must honor it (ties to Capability 5) |

#### Anti-Features (with explicit warnings)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ⚠️ Collapsing the adapter before the new kernel is proven | "It works in dev, delete the old code" | Removes the fallback; the first real-world bug now has no rollback; the whole point of compatible replacement is reversible migration | Collapse only when exit criteria met (contract tests green for N phases, old impl has zero callers); keep old impl + adapter until that gate passes |
| ⚠️ Leaking old kernel types into the new kernel | "Just pass the old `MediaInfo` through" | Defeats the anti-corruption layer; new kernel now depends on old types and can never be cleanly separated | Adapter maps old↔new types at the seam; new kernel declares its own types |
| ⚠️ One god-adapter wrapping everything | "One class, easier to follow" | 1:1 proxy of 6 interfaces in one file; unmaintainable; every change touches the adapter; can't migrate per-subsystem | Per-interface adapters composed; matches the v2.1 ISP split |
| ⚠️ Runtime-mutable switch (toggle from UI) | "Let users pick old/new" | Global mutable config = the coupling v3.0 is removing; a UI toggle for kernel impl is absurd and untestable | Switch resolved once at kernel boot from `--dart-define`/config; shadow mode is a dev flag, not a user feature |
| ⚠️ Keeping the adapter forever "just in case" | "It's not hurting anything" | Permanent indirection, permanent double-maintenance, permanent test burden; the adapter is scaffolding, not architecture | Exit criteria + delete; adapter is single-use scaffolding by design |
| ⚠️ Migrating state machine + error model + monitor all behind one adapter | "One big swap" | One regression rolls back all three; violates "each step verifiable" (PROJECT.md requirement) | Migrate per ISP interface, one subsystem per phase; adapter is the mechanism that makes this possible |
| ⚠️ Adapter performing business logic | "The adapter knows when to retry" | Adapter must be a pure translation layer; logic in the adapter is untestable in both old and new contexts | Logic lives in the new (or old) kernel; adapter only delegates + translates |

---

### Capability 5 — Engine Abstraction + State Machine for Flutter Media Player Kernel

v2.1 already split `MediaEngine` into 6 ISP interfaces and enumerated a 9-state ~40-edge machine, plus `openGeneration` guard and `PlaybackStateManager`/`AutoAdvancePolicy` split. v3.0 rewrites the implementation behind the preserved contract.

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sealed state enum, exhaustive | Implicit states (`_isOpening && _isPlaying`) are the root of the current bugs; a sealed enum + exhaustive switch makes invalid states unrepresentable | MEDIUM | `sealed class PlaybackState` or enum; every transition goes through one function; no direct field writes elsewhere |
| All transitions enumerated (transition table) | Undocumented transitions = race conditions; the transition set must be data, inspectable and testable | HIGH | `Transition.from(state).on(event) → state?` table; unknown (state,event) pairs are explicit rejects, not silent no-ops |
| `openGeneration` guard for async races | v2.1 added this; v3.0 must keep it. Media engines are racy: open(A) → open(B) → A's late callback fires → B's state corrupted | HIGH | Every async callback compares its captured `gen` against current `openGeneration`; stale → discard + trace log |
| Full lifecycle (init/open/play/pause/seek/stop/dispose) with terminal state | A `disposed` engine that still accepts calls is a use-after-free; lifecycle must be closed | MEDIUM | States include `disposed`; calls after dispose throw `StateError` (a programmer bug — allowed to propagate) |
| Callback thread-safety | fvp/MDK callbacks arrive on the platform thread, not the Dart isolate that called `open()`; without marshalling, state mutation races | HIGH | Marshal callbacks to the main isolate (SchedulerBinding / a single StateStore lock); document that engine callbacks are never reentrant |
| Idempotent transitions | `play()` when already playing, `pause()` when paused — must be no-ops, not errors, not double-fires | LOW | Transition table returns same-state for idempotent (state,event) pairs |
| Reject invalid transitions explicitly | `seek()` in `disposed`, `open()` in `disposed` — must raise a typed `KernelError`, not silently no-op | LOW | Transition table yields `FatalError` for invalid terminal-state transitions; matches Capability 2 |
| Generation + state co-located | State and generation must change together atomically; splitting them across classes reintroduces the race | MEDIUM | A single `PlaybackStateManager` owns `(state, openGeneration)` as one atomic update; v2.1 already split this correctly — preserve |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| State machine as data (transition table), not code (switch sprawl) | Table is auditable, testable per-cell, and extensible without touching transition logic | MEDIUM | `const Map<(State,Event), State>` or `Transition` records; exhaustive test covers every cell |
| Event log of all transitions (unify with `EngineEventLog`) | "State went A→B→C at these timestamps with these gens" — the first thing you want in a bug report | MEDIUM | `EngineEventLog` (v2.1 初版) records `{from, to, event, gen, ts}`; surface via `KernelLogger` (Capability 1) |
| Transition metrics (frequency, dwell time) | "Stuck oscillating between buffering/playing" is a visible symptom in metrics before it's visible to the user | MEDIUM | Counters per `(from,to)`; dwell time per state; reuse `EngineMetrics` |
| Capability negotiation per state | Some operations are only valid in some states (seek while seeking = cancel + reseek); make this table-driven | MEDIUM | `canSeek(state)`, `canSwitchTrack(state)` derived from the same table — single source of truth |
| Hot-reload-safe state preservation | Dev experience: hot reload must not corrupt engine state | LOW | State stored outside widget tree (already true via `ValueNotifier`); verify no widget-held state duplicates kernel state |

#### Anti-Features (with explicit warnings)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| ⚠️ Bool flags alongside the state machine | "Just add `_isSeeking` for one special case" | Bool flags re-introduce the implicit-state bug class the state machine exists to kill; v2.1 already replaced `_isOpening` with `openGeneration` — don't regress | Everything goes through the transition table; if you need a sub-state, add it to the enum, not a bool |
| ⚠️ Transitions from `disposed` | "Be lenient on shutdown" | Use-after-free; silent corruption; the project coding-style says `Error` subtypes (like `StateError`) indicate programmer bugs — let them crash | `disposed` is terminal; any event in `disposed` → `FatalError` (or `StateError` for programmer call-sites) |
| ⚠️ Firing callbacks synchronously from the platform thread without marshalling | "Lower latency" | Reentrant state mutation; the #1 source of media-engine races; undoable to debug | Marshal to main isolate; the latency cost is sub-frame and irrelevant for a media player |
| ⚠️ A generic FSM framework | "Reusable across engines" | YAGNI; a media-specific table is 40 cells; a generic FSM is a library, adds abstraction tax, and hides media-specific invariants | Media-specific transition table in the kernel; do not generalize |
| ⚠️ State duplicated in widgets | "The widget tracks its own `isPlaying`" | Dual sources of truth drift; UI must reflect kernel state, never shadow it | Widgets read `ValueListenableBuilder` on kernel state only; no widget-side playback state |
| ⚠️ Silent no-op on invalid (state, event) | "Be forgiving" | Hides bugs; the transition is wrong, the caller is wrong, or the engine is in a state it shouldn't be — all need surfacing | Explicit reject → typed `KernelError` (Capability 2) + log (Capability 1); idempotent transitions are the only allowed "same-state" returns |

---

## Feature Dependencies

```
[Capability 1: KernelLogger facade]
    └──requires──> [stable LogSink interface] (internal)
    └──enhances──>  [Capability 2: Error model]   (errors carry context, logged via facade)
    └──enhances──>  [Capability 3: MemoryMonitor] (monitor logs via facade, not debugPrint)
    └──enhances──>  [Capability 5: State machine] (transition log goes through facade)

[Capability 2: Structured error model]
    └──requires──> [Capability 5: State machine]  (errors reference state + openGeneration)
    └──requires──> [Capability 1: KernelLogger]   (errors must be loggable with context)
    └──required-by─> [Capability 4: Adapter]      (adapter surfaces new-impl errors as KernelError)

[Capability 3: MemoryMonitor first-class]
    └──requires──> [Clock injection abstraction] (internal)
    └──enhances──>  [Capability 1: KernelLogger] (monitor logs via facade)
    └──independent── [Capability 5: State machine] (defining property: non-interference)

[Capability 4: Anti-corruption adapter]
    └──requires──> [Preserved MediaEngine contract] (existing, v2.1)
    └──requires──> [Contract test suite per ISP interface] (new)
    └──requires──> [Capability 2: Error model] (new impl errors map to KernelError at seam)
    └──enables──>   [Per-subsystem incremental migration of 1, 2, 3, 5]

[Capability 5: Engine abstraction + state machine]
    └──requires──> [openGeneration guard] (existing v2.1, preserved)
    └──requires──> [Callback marshalling to main isolate] (new)
    └──enhances──>  [Capability 2: Error model] (state-at-failure in error context)
    └──enables──>   [Capability 4: Adapter] (new impl behind same contract)
```

### Dependency Notes

- **KernelLogger (1) is the foundation:** Capabilities 2, 3, and 5 all log through it. Build it first or in parallel with 5; do not build 2/3/5's logging ad-hoc and retrofit later.
- **State machine (5) is the contract backbone:** The adapter (4) preserves the *external* contract, but the state machine is the *internal* contract that the error model (2) references (`state-at-failure`, `openGeneration`). 5 must be at least co-designed with 2.
- **Adapter (4) requires the error model (2):** New-impl errors must cross the seam as `KernelError`, otherwise the adapter leaks new-kernel types into the UI — violating anti-corruption.
- **MemoryMonitor (3) is independent by design:** Its defining property is non-interference with playback state (Capability 5). This independence is the feature, not an accident.
- **Contract tests are a first-class dependency of the adapter (4):** without them, "compatible replacement" is unverified. Budget test-writing as part of the adapter phase, not an afterthought.

---

## MVP Definition

### Launch With (v3.0 — must)

- [ ] **KernelLogger facade** (Capability 1) — table stakes only (levels, gating, context, redaction, named loggers, `DeveloperLogSink` + `NullSink`). Differentiators (ring buffer, lazy) defer unless free.
- [ ] **Structured error model** (Capability 2) — sealed hierarchy, stable codes, recoverable/fatal split, propagation kernel→service→UI. `Result<T>` for expected outcomes.
- [ ] **MemoryMonitor first-class** (Capability 3) — instance-based, clock-injected, config, start/stop/dispose, non-interference, toggleable, snapshot/export. Preserve `ValueNotifier` output.
- [ ] **Anti-corruption adapter** (Capability 4) — per-ISP-interface adapters, dual-track coexistence, switch from config, contract tests per interface, documented collapse criteria.
- [ ] **Engine abstraction + state machine rewrite** (Capability 5) — sealed states, transition table, `openGeneration` guard, callback marshalling, idempotent + reject-invalid transitions, `disposed` terminal.

### Add After Validation (v3.x)

- [ ] **KernelLogger differentiators** — in-memory ring buffer + crash export, lazy message construction, per-sink level filter (trigger: first hard-to-diagnose bug report)
- [ ] **Error model differentiators** — retry policy enum, error metrics by code, user-facing l10n map (trigger: first user-facing error message ambiguity)
- [ ] **MemoryMonitor differentiators** — pluggable metric probes (GPU, frame), per-engine scoping (trigger: multi-instance work begins)
- [ ] **Adapter differentiators** — shadow mode, old-vs-new diff telemetry (trigger: first migration subsystem shows behavioral drift)

### Future Consideration (v4+)

- [ ] **File/remote log sinks** outside the kernel (trigger: support-ticket workflow needs persistent logs)
- [ ] **Generic FSM extraction** (trigger: a second engine type actually lands — until then YAGNI)
- [ ] **Auto-act policy on memory thresholds** (trigger: a concrete incident where pausing playback is the right call AND a separate policy layer can be tested)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| KernelLogger facade (table stakes) | MEDIUM (devs/operators, not end users) | MEDIUM | P1 |
| Structured error model (table stakes) | HIGH (reliability = user-visible) | HIGH | P1 |
| MemoryMonitor first-class (table stakes) | MEDIUM (diagnostics, not playback) | MEDIUM | P1 |
| Anti-corruption adapter (table stakes) | HIGH (enables safe migration) | HIGH | P1 |
| State machine rewrite (table stakes) | HIGH (fixes current bug class) | HIGH | P1 |
| Logger ring buffer + crash export | MEDIUM | MEDIUM | P2 |
| Error retry policy + metrics | MEDIUM | MEDIUM | P2 |
| MemoryMonitor pluggable probes | LOW (YAGNI today) | MEDIUM | P3 |
| Adapter shadow mode | MEDIUM | MEDIUM | P2 |
| State machine transition metrics | MEDIUM | MEDIUM | P2 |
| Auto-act on memory threshold | LOW | HIGH | P3 (anti-feature today) |

**Priority key:**
- P1: Must have for v3.0 launch (the rewrite is incomplete without these)
- P2: Should have during v3.0 if cost allows, else v3.x
- P3: Defer — YAGNI or anti-feature until a concrete trigger

---

## Competitor / Reference Analysis

| Capability | How established media kernels do it | Our approach |
|------------|--------------------------------------|--------------|
| Logging | mpv: `mp_msg` with levels (MSGL_*) + module tags; ExoPlayer: `EventLogger` + `AnalyticsCollector` | `KernelLogger` facade with levels + named loggers; zero dep; `dart:developer` + `debugPrint` sinks |
| Error model | mpv: error codes (`MPV_ERROR_*`); ExoPlayer: `PlaybackException` + `ErrorCode` enum; both split recoverable/fatal | Sealed `KernelError` → `RecoverableError`/`FatalError`; stable string codes; `Result<T>` for expected outcomes |
| Diagnostics monitor | ExoPlayer: `AnalyticsCollector` (injectable, per-player); mpv: observed properties (observer pattern, no auto-act) | Instance-based `MemoryMonitor`, clock-injected, non-interfering, `ValueNotifier` output |
| Adapter / migration | Strangler Fig (Fowler): facade preserves contract, new impl grows behind it, old impl strangulated; ACL (DDD): translate types at boundary | Per-ISP-interface `KernelAdapter`, dual-track, contract tests, documented collapse criteria |
| State machine | mpv: `mpctx->state` + explicit transitions; ExoPlayer: `Player` state model (BUFFERING/READY/ENDED/IDLE) + `playWhenReady`; both enumerate transitions | Sealed `PlaybackState`, transition table as data, `openGeneration` guard, callback marshalling |

---

## Sources

- **Project code (direct review):** `lib/kernel/utils/memory_monitor.dart` (current singleton — the non-first-class shape being replaced); `lib/kernel/engine/media_engine.dart` (the v2.1 ISP-composed contract to preserve); `.planning/PROJECT.md` (v3.0 constraints: zero-dep, compatible replacement, no UI change, no `logger` package).
- **Established patterns:** Strangler Fig Application (Martin Fowler) — incremental migration behind a preserved facade; Anti-Corruption Layer (Domain-Driven Design) — translate types at the boundary so the new kernel isn't polluted by old types; Sealed error hierarchies + `Result<T>` (Dart 3 idioms, project coding-style mandates both); Logging facade pattern (slf4j / `dart:developer` tradition) — levels + sink abstraction, no runtime dep.
- **Media kernel references:** mpv `MPContext` state + `mp_msg` level/module logging; AndroidX Media3 `Player` state model + `AnalyticsCollector` (injectable diagnostics); both split recoverable/fatal and enumerate transitions.
- **Confidence limitation:** Web search/fetch tools were unavailable in this research environment (queries returned no results; martinfowler.com blocked). Confidence is MEDIUM: findings rest on well-established SE patterns and direct review of the project's actual code and stated constraints, not on freshly-fetched primary sources. Recommend a follow-up verification pass for the Strangler Fig collapse criteria and media-FSM thread-safety specifics before phase planning locks.

---
*Feature research for: Flutter desktop media player kernel rewrite (v3.0 — compatible replacement + diagnostics-first kernel)*
*Researched: 2026-07-16*
