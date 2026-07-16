# Pitfalls Research

**Domain:** Compatible-replacement kernel rewrite for a Flutter desktop media player (fvp / MDK-FFmpeg); static-singleton → injectable DI migration; zero-dependency logging facade + sealed error model across async/multi-thread (mdk) callback boundaries.
**Researched:** 2026-07-16
**Confidence:** HIGH (grounded in this codebase's actual files: `memory_monitor.dart`, `log.dart`, `media_engine.dart`, `fvp_engine.dart`, `engine_state_machine.dart`, `PROJECT.md`, plus the project's own documented anti-pattern memory).

> Build-order phase shorthand used below: **P1 baseline** → **P2 adapter** → **P3 state/lifecycle** → **P4 error/logger** → **P5 MemoryMonitor** → **P6 tests/migration** → **P7 bilingual docs**.

---

## Critical Pitfalls

### Pitfall 1: The "zero-dependency KernelLogger" constraint is already violated — `log.dart` imports `package:logger` and `package:path_provider`

**What goes wrong:**
`PROJECT.md` declares a "zero new dependency `KernelLogger` facade (`dart:developer` + controlled `debugPrint`)" as a v3.0 constraint. But `lib/kernel/utils/log.dart` already imports `package:logger` (Logger, PrettyPrinter, PrefixPrinter, ProductionFilter, MultiOutput, ConsoleOutput, JsonPrinter) and `package:path_provider` (`getApplicationSupportDirectory`). The team believes it is *introducing* a zero-dep facade; in reality it is *replacing* an existing third-party-dependent logger that 30 files and 121 call sites depend on (global mutable `log`, `logEngine`, `logBridge`, `logServices`, `logUi`). Treating this as "new greenfield facade" leads to under-scoping: the migration is a contract replacement, not an addition.

**Why it happens:**
The PROJECT.md framing ("introduce KernelLogger") obscures that a logger already exists and is load-bearing. The constraint was written against *new* dependencies, not against *removing* existing ones, so planners miss the 121-occurrence migration surface.

**How to avoid:**
- Treat P4 (error/logger) as a **replacement migration**, not a fresh write. Inventory every `import '../utils/log.dart'` and every `log*.i/w/e(...)` call before writing the facade.
- The KernelLogger facade must preserve the *call shape* callers use today (`logEngine.w('...')`, `log.i('...')`) — via a thin shim that delegates to `dart:developer.log` + gated `debugPrint` — so the 30 files migrate by changing only the import / global declaration, not every call site.
- Move file-rotation/release-sink behind the facade's `initLog()` equivalent so the zero-dep claim holds for `lib/kernel` proper; `path_provider` becomes a *host* (app.dart) concern, not a kernel concern. Document this boundary explicitly.
- Add a CI grep gate in P4: `lib/kernel/**` must not import `package:logger` or `package:path_provider`.

**Warning signs:**
- A PR that adds `KernelLogger` next to the old `log.dart` without removing `package:logger` from `pubspec.yaml`.
- 121 call-site edits proposed (signal you chose the wrong facade shape).
- `dart analyze` "unused_import" explosions after a partial swap.

**Phase to address:** P4 (error/logger) — with the inventory started in P1 (baseline) because the migration surface must be measured before the adapter phase sizes it.

---

### Pitfall 2: Double source-of-truth during dual-track coexistence (old `FvpEngine` + new kernel both live)

**What goes wrong:**
Compatible replacement means the old kernel and the new kernel coexist behind an adapter while migration proceeds screen-by-screen / service-by-service. Both kernels carry their own `MediaState` value, `position` ValueNotifier, `openGeneration` counter, and `MediaEngine` impl. A UI widget still bound to the old kernel's `ValueNotifier<MediaState>` and a widget migrated to the new kernel now observe two different "current state" streams. Auto-advance, seek-after-open, and "is this the current open?" logic split across two engines; the playlist advances on one, the texture renders the other, and the user sees seek/track/state desync that is invisible in unit tests (each engine is internally consistent).

**Why it happens:**
Dual-track is the explicit strategy (PROJECT.md: "适配器逐步替换内核，双轨并存"). The trap is treating "coexistence" as "both are authoritative" instead of "one is authoritative, the other is a shadow/shim". Without a single arbiter, every cross-cutting concern (state, position, generation, track selection) silently forks.

**How to avoid:**
- **One engine is canonical at any moment.** Define a `KernelMode { legacy, migrated }` flag owned by the composition root (app.dart), not by either kernel. The adapter reads it; UI never branches on it.
- The adapter is an **anti-corruption layer**, not a multiplexer: it forwards *to* the canonical engine and *translates back* from it. The legacy engine, when shadowed, must not emit state changes the UI listens to — disconnect its ValueNotifiers from UI or the shadow becomes a second source.
- Carry `openGeneration` as the **single** race guard: the adapter holds the generation counter and both engines must consult it. Do not let each engine keep its own `_openGeneration` (see `fvp_engine.dart:194` — the guard currently lives in the engine, which is fine for single-engine but forks under dual-track).
- P6 contract test: a "dual-track parity" test that drives the same command sequence through both the legacy path and the migrated path and asserts the resulting `MediaState` + `position` sequences are equivalent. This test is the only thing that catches desync early.

**Warning signs:**
- Two `ValueNotifier<MediaState>` reachable from the widget tree.
- A seek that lands visually on the previous track.
- `openGeneration` compared against an engine-local counter inside the adapter.
- "It works when I comment out one of the engines" — classic two-source symptom.

**Phase to address:** P2 (adapter) for the arbitration rule + generation handoff; P6 (tests/migration) for the parity test. P3 (state/lifecycle) must not ship before the adapter arbitrates generation.

---

### Pitfall 3: Adapter / anti-corruption layer leakage and contract drift

**What goes wrong:**
The adapter is meant to preserve the UI→Kernel contract (`MediaEngine` interface — `EngineStateView` + `PlaybackControl` + `TrackControl` + `SubtitleConfig` + `VideoEffectControl` + `RendererControl` + `VolumeControl`, per `media_engine.dart`). Drift appears as: the new kernel adds a method (e.g. `seekPrecise`, `setBufferingTarget`) that the adapter exposes, UI starts calling it, and the legacy path silently no-ops or throws `NoSuchMethodError` because the adapter didn't translate. Or worse: the adapter translates to a *different* legacy method (e.g. new `setSpeed(2.0)` → legacy `setPlaybackRate(2.0)` with different clamping semantics), so behavior diverges under the same UI call. The "contract preserved" claim becomes a lie the moment a method's *semantics* (not just signature) drift.

**Why it happens:**
The contract is specified at the *signature* level (the `MediaEngine` abstract interface) but compatibility is a *behavioral* property. Adapters are usually written to satisfy the compiler, not a behavioral parity spec. New capabilities leak through because the new kernel's interface is richer, and there is no spec saying "the adapter must not expose methods absent from the v2.1 baseline contract".

**How to avoid:**
- P1 (baseline) freezes a **Behavioral Contract Spec** (BCS) — not just the interface file. For each `MediaEngine` method: preconditions, postconditions, the exact `MediaState` transitions it may trigger, the error cases, and the ValueNotifiers it may mutate. This is the migration's source of truth.
- The adapter implements the *frozen* `MediaEngine` interface verbatim — no extra methods. New-kernel-only capabilities live on a separate `MediaEngineV3` interface that UI does *not* import until migration is complete and legacy is deleted.
- P6 contract tests assert the BCS for both legacy and migrated paths (this is the same parity test as Pitfall 2). Any behavioral diff fails CI.
- The adapter must not silently swallow exceptions to "make the call shape match". Sealed-error translation is mandatory (see Pitfall 7).

**Warning signs:**
- The adapter has methods not present on `MediaEngine` (line-count diff the interface vs the adapter).
- A UI call works on the migrated path but produces a different `MediaState` sequence on legacy.
- `dynamic` / `as` casts inside the adapter to paper over signature mismatches.
- A method's doc comment says "approximate" or "best-effort".

**Phase to address:** P1 (baseline) freezes the BCS; P2 (adapter) implements it; P6 (tests/migration) verifies parity. If P1 skips the BCS, P2 and P6 cannot recover the cost.

---

### Pitfall 4: Collapsing the adapter too early

**What goes wrong:**
Once most services are migrated and the parity tests pass, the team deletes the adapter and the legacy engine to "simplify". A remaining caller (a deferred widget, a platform-bridge path, a test helper, an OS-specific fallback) was still reaching through the adapter to legacy behavior. Deleting it produces `Null reference` / `NoSuchMethodError` at runtime on a path unit tests didn't cover (e.g. macOS subtitle path, or the `debug_exporter.dart` MemoryMonitor snapshot path). Worse, the adapter was also the *arbitration* layer (Pitfall 2); deleting it without moving the generation guard leaves the new engine unguarded against the race the adapter was silently absorbing.

**Why it happens:**
The adapter feels like dead weight once parity is green. But "parity tests pass" only covers the *sequences you tested*, and the adapter was also doing hidden duties (arbitration, legacy quirks, fallback behavior) that aren't visible as code. Collapsing is a delete, and deletes are where legacy bugs surface.

**How to avoid:**
- Define an **adapter-deletion gate** in P6 as a checklist, not a date: (1) 100% of `MediaEngine` callers migrated off legacy, verified by `codegraph`/grep showing zero references to the legacy engine class; (2) dual-track parity test passing for N consecutive regressions; (3) `openGeneration` guard moved into the new engine (or a shared `OpenGenerationTracker`), proven by a race test; (4) platform-specific fallback paths audited and migrated; (5) the adapter's arbitration responsibility explicitly reassigned, not just deleted.
- Collapse in a *dedicated* P6 sub-phase with its own commit and its own regression run — never as part of a feature commit.
- Keep the adapter in-tree, behind a kill switch, for one milestone after deletion is "done", so a late-surfacing legacy path can be revived without a revert.

**Warning signs:**
- "The adapter is just a pass-through now, let's delete it" — said before the generation guard is moved.
- A deferred widget (`deferred_player_feature.dart`) still imports legacy engine symbols.
- Test coverage of platform fallback paths < 100% at collapse time.
- Adapter deletion bundled with a feature commit.

**Phase to address:** P6 (tests/migration) — collapse is the last act of P6, gated by the checklist above; P3 (state/lifecycle) must have already relocated the generation guard.

---

### Pitfall 5: Singleton → injectable `MemoryMonitor` migration breaking static callers

**What goes wrong:**
`memory_monitor.dart` is a static singleton: `MemoryMonitor._()`, `static final _instance`, and static methods `start()`, `stop()`, `snapshot()`, `exportJson()`. Callers use it as `MemoryMonitor.start()` (`main.dart:16`) and `MemoryMonitor.snapshot()` (`debug_exporter.dart:57`). The v3.0 plan promotes it to an injectable, closable diagnostic component. The project's own memory documents the exact anti-pattern: "R2-5 删 `_instance` 但留静态方法 → 构建失败" — deleting the singleton while leaving static method shells causes a build break, and *partial* migration (instance API added, static API deleted, callers not updated in the same commit) breaks the build. Conversely, keeping the static API as a delegating shim *forever* defeats the injectability goal (the static path can't be closed/injected).

**Why it happens:**
Singleton→instance migration is a refactor with a wide fan-out (every static caller) and a narrow safe window: the static API and the instance API must coexist transiently, then the static API must be deleted in lockstep with the last caller update. Doing it in two non-atomic commits breaks the build; doing it half-way leaves a zombie static path.

**How to avoid:**
- **Atomic migration per call site.** Introduce the instance-based `MemoryMonitor` (constructor-injected, `start()`/`stop()` instance methods, a `MemoryMonitorProvider`/getter in the composition root). Keep the static `MemoryMonitor` as a *thin delegating shim* to the registered instance **only during P5**. Then, in the same P5 sub-phase, rewrite each static caller (`main.dart:16`, `debug_exporter.dart:57`) to use the injected instance, and delete the static shim in the final P5 commit.
- The injected `MemoryMonitor` must be **closable and disable-able** (an `enabled` flag / `noop` implementation) so tests and release builds can inject a no-op without the static `start()` having side effects.
- P5 CI gate: `grep -rn "MemoryMonitor\." lib/` returns zero static-style calls (only instance calls through the injected reference). And `grep -rn "static.*MemoryMonitor" lib/kernel/utils/memory_monitor.dart` returns nothing.
- Guard against the documented anti-pattern explicitly: never delete `_instance` while keeping static method signatures, and never keep static method signatures while deleting `_instance`. Do both in one commit.

**Warning signs:**
- A commit deletes `_instance` but leaves `static void start(...)`.
- `MemoryMonitor.start()` still called from `main.dart` after P5 claims injectable.
- Two `MemoryMonitor` instances alive (one injected, one `_instance`) — double sampling, double `Timer.periodic`.
- Release build still hits `debugPrint` via the static path because the shim wasn't deleted.

**Phase to address:** P5 (MemoryMonitor) — exclusively. P1 (baseline) records the static call-site inventory; P6 verifies zero static callers remain.

---

### Pitfall 6: `MemoryMonitor` interfering with playback business state

**What goes wrong:**
`MemoryMonitor._startImpl` runs `Timer.periodic` that calls `ProcessInfo.currentRss`, builds a `MemorySnapshot`, and writes to `snapshotNotifier.value` (a `ValueNotifier<MemorySnapshot?>`) and invokes `onTick`. During dual-track, a migrated widget or service accidentally binds `snapshotNotifier` into the *playback* reactive tree (e.g. a `ValueListenableBuilder` that rebuilds the video surface or control bar on every memory tick — 30s cadence forcing a player rebuild). Or the injected `MemoryMonitor` is constructed in the same `InheritedWidget` subtree as `PlaybackController`, so disposing the monitor disposes a notifier some playback widget still listens to → `A disposed ValueNotifier was used` after a hot reload / screen transition. The diagnostic component now *causes* the jank/state-bug it was meant to observe.

**Why it happens:**
`MemoryMonitor` exposes a `ValueNotifier<MemorySnapshot?>` — the same reactive primitive the whole UI is built on (`ValueNotifier + ValueListenableBuilder` is the project's state model). There is no type-level or structural barrier preventing a playback widget from listening to the memory notifier. Once injectable, the monitor instance travels through the widget tree more freely, increasing the chance it lands in a playback-sensitive subtree.

**How to avoid:**
- **Architectural rule, enforced in P5:** `MemoryMonitor` is a *diagnostic* component. Its `ValueNotifier` must never be consumed by a widget that also depends on `MediaEngine`/`PlaybackController` state. Isolate memory-display UI into a dedicated diagnostics surface (settings/debug panel), never the player overlay.
- Make the monitor **disable-able by default in the player subtree**: the composition root injects a `NoopMemoryMonitor` into the player's DI scope and the real `MemoryMonitor` only into the debug/diagnostics scope. The `MemoryMonitor` abstract interface (P5) is what makes this enforceable — callers depend on the interface, not the concrete notifier.
- Document the side-effect boundary: the monitor's `Timer` is a background tick; `onTick` callbacks must not call back into `PlaybackController` (no re-entrancy into the engine). P5 lint rule: `onTick` handlers must be pure (log/export only).
- Dispose discipline: the monitor owns its `Timer` and its `snapshotNotifier`; `stop()`/`dispose()` must cancel the timer and set `snapshotNotifier.value = null` *before* disposing the notifier, and listeners must be detached by the diagnostic UI before the monitor is disposed. Mirror the `fvp_engine.dart:594` "still has listeners" warning pattern.

**Warning signs:**
- Player overlay rebuilds every 30s (jank correlated with the monitor interval).
- `A disposed ValueNotifier was used` after exiting a diagnostics panel.
- `onTick` handler calls `playbackController.xxx`.
- The monitor's `ValueNotifier` appears in the same `build()` as `MediaEngine` notifiers.

**Phase to address:** P5 (MemoryMonitor) — the interface + DI scoping is defined here; P6 (tests/migration) verifies the player subtree has no `MemoryMonitor` listener.

---

### Pitfall 7: Sealed error model across async / mdk callback-thread boundaries

**What goes wrong:**
v3.0 introduces a sealed error model (per `coding-style.md`: `sealed class Result<T>` / `Ok` / `Err`). The engine's errors originate on the **mdk callback thread** (FvpCallbackHandler, see `fvp_callback_handler.dart`), then are marshalled to the main thread. Sealed classes are great on a single isolate, but: (a) a sealed `KernelError` constructed on the callback thread carries a `StackTrace` from that thread — if it's caught and re-thrown on the main thread the stack is misleading or truncated; (b) if the sealed error is passed through a `Zone`/`Isolate`/`MethodChannel` boundary, Dart's default crossing can strip type info; (c) `switch` exhaustiveness checks fail silently if the error is caught as `Object` (a bare `catch (e)` in legacy code swallows the sealed type and the exhaustiveness guarantee evaporates); (d) the UI expects a *string* or an *enum* error code today, not a sealed object — introducing the sealed type at the UI boundary without an adapter breaks the "UI→Kernel contract unchanged" promise.

**Why it happens:**
Sealed types are a *single-isolate, compile-time* guarantee. The mdk callback path is cross-thread. The team applies a Dart-3 language feature to a concurrency boundary and assumes the guarantees carry across. They don't fully.

**How to avoid:**
- The sealed `KernelError` hierarchy lives in `lib/kernel` (domain). It is **never** surfaced to UI as a raw sealed object. P4 defines an `ErrorView` (string code + localized message + severity) that the adapter translates `KernelError → ErrorView`. UI keeps depending on `ErrorView` (or whatever shape it uses today) — the sealed model is internal to the kernel.
- **Marshal errors explicitly across the callback boundary**: the callback handler converts the mdk error into a `KernelError` on the *main* thread (reconstruct the stack from the main-thread context, not the callback thread), or carries the callback-thread stack as a *field* (`callbackStackTrace`) rather than as the thrown stack.
- Stabilize **error codes** as an `enum` (or a const string set) frozen in P1/P4 — they are the stable contract; the sealed class is the *carrier*, not the contract. Versioning: never rename an error code, only add new ones.
- Ban bare `catch (e)` in kernel code (`coding-style.md` already requires specifying exception types in `on` clauses). P4 lint: no `catch (e)` without `on`. Sealed errors must be caught with `switch` (exhaustive) or `on KernelError`.
- For `Future`-returning kernel APIs, use `Result<T>` (Ok/Err) — *not* exceptions — so the async caller can't accidentally swallow a sealed error via a legacy `try/catch`. Sync callback handlers can throw; the handler converts to `Result` at the async boundary.

**Warning signs:**
- A sealed `KernelError` reaching a `Widget` (the contract is broken).
- `catch (e)` anywhere in `lib/kernel` that handles an engine-originated error.
- A `switch` over the sealed type with a `default` case (defeats exhaustiveness).
- Stack traces in error reports pointing at the mdk callback thread with no main-thread context.
- Error codes renamed between commits (stable-contract violation).

**Phase to address:** P4 (error/logger) — define the sealed model, the error-code enum, and the `ErrorView` translation; P3 (state/lifecycle) must route all state-machine error transitions *through* the sealed model so error and state are consistent; P6 verifies no sealed type leaks to UI.

---

### Pitfall 8: State machine edge cases and generation-guard races

**What goes wrong:**
The existing `EngineStateMachine` (9-state, ~40-edge per PROJECT.md) silently ignores illegal transitions in release builds (`assert`-only debug warning, `engine_state_machine.dart:52-58`). The `openGeneration` guard lives in `fvp_engine.dart:194`, not in the state machine. During the rewrite: (a) a new edge is added (e.g. `buffering → error`) but the state machine's `_canTransitionTo` switch isn't extended — exhaustiveness catches the missing case *only if* the switch is exhaustive; (b) the generation guard is checked in `open()` but a *seek* or *track switch* issued during the `await` window between `++_openGeneration` and the result check races a newer open — the old seek's result mutates state on the new track; (c) a state-machine transition fires a `ValueNotifier` notification while the engine is mid-`await` (re-entrant listener), causing a listener to issue another `open()` which increments generation and invalidates the in-flight one — a livelock; (d) the dual-track adapter runs two state machines that disagree on the current state (see Pitfall 2).

**Why it happens:**
The state machine and the generation guard were designed separately (v2.1 extracted the machine but left generation in the engine). They are two halves of one correctness property ("only the most recent open's results apply"). Splitting them means each new operation must remember to consult *both*, and async re-entrancy through `ValueNotifier` listeners is rarely tested.

**How to avoid:**
- **Unify state machine + generation guard.** P3 introduces an `OpenGenerationTracker` (or folds the counter into the state machine) so `transitionTo` can refuse a transition whose generation is stale: `if (gen != currentGeneration) return false;`. Every async op checks generation *and* state, atomically.
- Make the state machine's transition switch **exhaustive and compiler-checked** (Dart 3 sealed `MediaState` → `switch` with no `default`). Any new state/edge is a compile error until handled. The existing code already does this for `_canTransitionTo` — preserve it and extend the discipline to *every* transition site.
- **Stop silently ignoring** illegal/stale transitions in release. The current `assert`-only behavior is a silent-failure pattern the project memory explicitly flags. P3 replaces it with: log via `KernelLogger` (P4) at warning, and return a `Result.err(IllegalTransition(...))` so the caller can recover. Silent ignore is only acceptable for truly idempotent no-ops; document those explicitly.
- Guard against `ValueNotifier` re-entrancy: never issue an `open()` from a listener that fires during another `open()`'s `await` window. P3 rule: listeners that trigger opens must be deferred to the next microtask (`scheduleMicrotask`) so the in-flight open completes first. Add a P6 race test that issues open→seek→open rapidly and asserts the final state matches the last open only.
- P6 state-machine property tests: for every (state, event) pair, assert the transition is either legal-and-applied or illegal-and-`Result.err` — never silent.

**Warning signs:**
- A stale-seek result shows up as a position jump to a previous track.
- State-machine switch over `MediaState` has a `default`/wildcard case.
- Illegal transitions logged only in debug (release users get no diagnostic).
- A `ValueNotifier` listener calls `open()` synchronously inside another `open()`'s callback.
- Two `openGeneration` counters (one in the engine, one in the adapter).

**Phase to address:** P3 (state/lifecycle) — unify machine + guard, enforce exhaustive switches, replace silent ignore with `Result.err`; P6 (tests/migration) — race + property tests.

---

### Pitfall 9: Regression during incremental kernel swap (the swap itself introduces bugs the dual-track was meant to prevent)

**What goes wrong:**
The whole point of compatible replacement is to avoid a one-shot regression. But incremental swap has its own regression modes: (a) a service migrated to the new kernel still holds a stale reference to the legacy `PlaybackController` (mixin composition — `PlaybackController + 3 mixins` per project memory), so half its calls go to legacy; (b) the adapter translates a call but the new kernel's *timing* differs (e.g. `setSpeed` applies on the next frame vs. immediately), so a passing parity *sequence* test still has a timing regression users feel; (c) the order of migration matters — migrating `PlaybackStateManager` before `AutoAdvancePolicy` (or vice versa) crosses a dependency the adapter doesn't model, and the second migration breaks; (d) a test that mocks the legacy `MediaEngine` keeps passing while the real new kernel has a different shape, giving false green.

**Why it happens:**
"Incremental" is treated as "swap one file at a time" instead of "swap one *dependency edge* at a time, verified". The mixin-composition structure of `PlaybackController` means a service's dependencies are implicit; swapping the controller without swapping its mixins leaves a hybrid.

**How to avoid:**
- P6 defines an explicit **migration order** derived from the dependency graph (use `codegraph` to get callers/callees): migrate leaves first (track managers, volume, subtitle), then the orchestrator (`PlaybackController`), then the state managers, then UI bindings. Each step is gated by the parity test *and* a full `flutter test` run.
- **No partial service migration.** A service and all its mixins move together in one commit. The adapter exists *between* services, not *inside* a service.
- Parity tests must include **timing-sensitive** cases (seek-then-immediately-play, open-then-immediately-next). Use `fakeAsync` to control time and assert ordering, not just final state.
- Mocks must mock the *contract* (the frozen `MediaEngine` interface from P1), not the legacy implementation. If a test imports `FvpEngine` concretely, it is a legacy test and must be marked for migration.
- Every migration step commits behind a feature flag (`KernelMode.migrated` for that service), so a regression can be flipped back without a revert.

**Warning signs:**
- A migrated service imports both `playback_controller.dart` and a legacy helper.
- Parity tests green but users report "seek feels different".
- Migration order chosen by file convenience, not by the dependency graph.
- A test that constructs `FvpEngine` directly (not via the interface) still passing post-migration.

**Phase to address:** P6 (tests/migration) — defines order, parity, timing tests, feature flag; P2 (adapter) provides the seam each step uses.

---

### Pitfall 10: Over-engineering the adapter / facade (the project's documented nemesis)

**What goes wrong:**
The project memory is emphatic: prior refactors produced "27 files 3500 lines" of window/fullscreen over-engineering, "19 state vars managing 1 bool", "double source-of-truth", "over-abstraction". The compatible-replacement approach *invites* the same failure: an adapter layer with its own state, its own interface hierarchy (`MediaEngine`, `MediaEngineV3`, `LegacyMediaEngine`, `MediaEngineAdapter`, `MediaEngineShim`...), its own arbitration, its own error translation, its own logger. What was meant as a temporary migration seam becomes a permanent architectural layer that outlives the migration and ossifies. The adapter was supposed to be deleted (Pitfall 4); instead it becomes the new god layer.

**Why it happens:**
"Adapter" and "anti-corruption layer" sound like architecture, so the team architectures it. YAGNI is hard to enforce under a rewrite mandate.

**How to avoid:**
- **Size budget for the adapter, set in P2.** Rule of thumb: the adapter + facade + KernelLogger + sealed error + generation tracker together must be *smaller* than the legacy `FvpEngine` they replace. If the adapter alone exceeds ~30% of the legacy engine's line count, it is becoming a layer, not a seam. Track this in P2, P4, P5.
- The adapter has **no state of its own** except the `KernelMode` flag and the generation counter. All playback state stays in the engine. Any other field on the adapter is a smell.
- The facade (`KernelLogger`) is a **thin pass-through** to `dart:developer.log` + gated `debugPrint` — not a leveled logging framework. If `KernelLogger` grows appenders, formatters, or a plugin system, it has re-invented `package:logger` and violated the zero-dep constraint.
- No `MediaEngineV3` interface until *after* legacy deletion (Pitfall 4). The adapter speaks the frozen `MediaEngine` interface, full stop.
- P2 review checklist: "Can I describe what the adapter does in one sentence?" If not, it's over-engineered. "It forwards UI calls to the canonical engine and translates errors back" — that's the one sentence.
- The senior-architect / red-team skills (available in this environment) should be invoked on the adapter design in P2 specifically to challenge scope creep.

**Warning signs:**
- Adapter line count growing past the budget.
- Adapter holds a `Map` of playback state.
- `KernelLogger` grows its own output/printer hierarchy (it's re-importing `package:logger` concepts).
- A `MediaEngineV3` interface introduced before legacy deletion.
- The adapter survives the P6 collapse (it was supposed to be deleted — see Pitfall 4).

**Phase to address:** P2 (adapter) — set the size budget and the "no state" rule; P4 (error/logger) — keep the facade thin; P6 (tests/migration) — verify the adapter is gone after collapse.

---

### Pitfall 11: Logger leaking to release builds (`debugPrint` vs `dart:developer`)

**What goes wrong:**
The "controlled `debugPrint`" in the KernelLogger spec is a leak vector. `debugPrint` is *not* stripped in release — it's throttled, but it still calls `print` (or the platform print sink) in release builds. So a `KernelLogger.d('...')` that uses `debugPrint` ships log lines to release users' consoles / output sinks. The existing `log.dart` solves this with `ProductionFilter` (warning+ in release) — but the zero-dep facade is *removing* that filter. Without an equivalent gate, every `debug`/`info` log the kernel emits during playback goes to release. The result: release log noise, potential PII/path leakage in logs, and on Windows, debug output string overhead per frame.

**Why it happens:**
"debugPrint is for debug" is a common misconception — it's for *Flutter debug print semantics* (throttling), not for *debug builds only*. `kDebugMode` / `kReleaseMode` is the actual gate. The team writes `debugPrint(...)` thinking it's debug-only, ships it, and release users see it.

**How to avoid:**
- The KernelLogger facade gates by **level** *and* **build mode**: in release, only `warning`/`error` emit, and they emit via `dart:developer.log` (structured, capturable by DevTools / platform debug sinks), *not* `debugPrint`. `debugPrint` is reserved for debug builds and is wrapped in `if (kDebugMode)`.
- Explicit facade contract (P4):
  - `trace`/`debug`/`info` → debug builds only, via `debugPrint` (gated by `kDebugMode`).
  - `warning`/`error` → all builds, via `dart:developer.log` with structured fields (error code, context, stack).
  - Never log raw file paths / user content without a redaction step (path → basename, like `PathUtils.basename` already used in `fvp_engine.dart:260`).
- P6 release-build CI gate: build in `--release`, run a smoke test, assert no `debugPrint` output and no `info`/`debug` lines appear. (A grep for `debugPrint` in `lib/kernel` should return zero outside the facade.)
- The facade's release path is the future hook for file/remote sinks — but *that* is host (app.dart) concern, not kernel (see Pitfall 1). Don't put `path_provider` in `lib/kernel`.

**Warning signs:**
- `debugPrint(` appearing in `lib/kernel/**` outside `KernelLogger`'s implementation.
- Release users reporting log spam in the Windows debug output / a log file.
- File paths or media filenames appearing in release logs.
- `kDebugMode` not referenced anywhere in the logger facade.

**Phase to address:** P4 (error/logger) — the facade's level/mode gating is defined here; P6 verifies the release-build no-leak gate.

---

### Pitfall 12: Bilingual doc-comment drift (中文意图 vs 英文契约)

**What goes wrong:**
v3.0 mandates that new/refactored public APIs carry *both* a Chinese intent statement and an English contract statement (PROJECT.md target 7). Drift appears as: (a) the Chinese and English diverge over edits — a dev updates the Chinese "why" but not the English "contract" (or vice versa), so the two languages describe different behavior; (b) the English contract becomes stale relative to the signature (param renamed, error case added) while the Chinese stays correct — or the reverse; (c) the existing codebase already has Chinese-only doc comments (e.g. `media_engine.dart` lines 9-22 are Chinese-only), so the "bilingual" standard is inconsistently applied — some APIs bilingual, some Chinese-only, creating a maintenance lottery; (d) a sealed `KernelError` subclass has a Chinese doc but the English contract is missing, so an English-only contributor misreads the error semantics.

**Why it happens:**
Two languages doubles the maintenance surface; without enforcement, one rots. There is no tool that verifies bilingual *parity* (only presence), so drift is silent.

**How to avoid:**
- P7 defines a **doc-comment structure**, not just "both languages": first a `///` line with the intent (Chinese, per existing codebase convention), then a blank line, then a `///` block with the contract (English: params, returns, throws/states, invariants). Structure beats free-form bilingual prose for maintenance.
- A doc-comment lint (P7): for every public symbol in `lib/kernel/**` added/modified in v3.0, both the intent line (Chinese) and the contract block (English) must be present. Add a `dart analyze` custom lint or a P7 grep-based check.
- **Single source of truth within the comment:** the English contract is authoritative for behavior; the Chinese intent is authoritative for "why". When behavior changes, update the English first; the Chinese intent only changes if the *why* changed. This asymmetry prevents both-sides-stale.
- For the sealed error model (Pitfall 7), every `KernelError` subclass carries the error code + English contract in its doc; the Chinese intent explains *when* that error fires. Never put the error code in only one language.
- Migrate existing Chinese-only doc comments (e.g. `media_engine.dart`) to bilingual in P7 — but only for symbols the rewrite touches. Bulk-migrating untouched symbols is scope creep and risks introducing drift on stable APIs.

**Warning signs:**
- A PR changes a signature but only updates one language's doc.
- Public APIs in `lib/kernel` with a Chinese `///` but no English contract block.
- Bilingual standard applied to v3.0 files but not to the pre-existing `MediaEngine` interface (inconsistent).
- English contract says "throws X" but the code returns `Result.err` (contract drift, not just language drift).

**Phase to address:** P7 (bilingual docs) — structure + lint + migration of touched symbols. The structure must be agreed in P1 (baseline) so P2-P6 code is written bilingual from the start, not retrofitted.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping `MemoryMonitor` static API as a permanent shim | No build break during P5 | Injectability goal unmet; static path can't be closed in tests/release | Only during P5 transition; deleted in the final P5 commit |
| Adapter exposing new-kernel-only methods (richer `MediaEngineV3`) | Unlock new features early | Contract drift; UI depends on methods legacy can't satisfy; collapse blocked | Never before legacy deletion (Pitfall 4) |
| `debugPrint` for all kernel logging | Fast to write, familiar | Release-build log leak (Pitfall 11); no level/mode gating | Debug-build-only branches inside the facade; never as the facade's only output |
| `default`/wildcard in sealed-error/state `switch` | Quiets the analyzer | Loses exhaustiveness guarantee; new cases silently unhandled | Never — extend the switch explicitly |
| Silent ignore of illegal state transitions (current behavior) | No crash in release | Silent state corruption; the documented "silent failure" anti-pattern | Only for documented idempotent no-ops; else `Result.err` + log |
| Two `openGeneration` counters (engine + adapter) | Quick dual-track start | Race guard forks; stale results leak | Never — single tracker (Pitfall 8) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| mdk callback thread → main thread | Throwing a sealed `KernelError` on the callback thread and catching it on main, trusting the `StackTrace` | Reconstruct the error on main with main-thread context; carry callback stack as a field (Pitfall 7) |
| `MemoryMonitor` → `ValueNotifier` reactive tree | Letting a playback widget listen to the memory notifier | Diagnostic-only scope; inject `NoopMemoryMonitor` into the player subtree (Pitfall 6) |
| Adapter → legacy `FvpEngine` factory constructor | Calling `FvpEngine()` (factory) inside the adapter, creating a second mdk `Player` | The adapter receives the single canonical engine via DI; never instantiate a second player |
| KernelLogger → release sinks | Putting `path_provider` / file rotation in `lib/kernel` | Sinks are host (app.dart) concern; kernel facade emits to `dart:developer.log` only (Pitfall 1, 11) |
| `EngineStateMachine` → `FvpEngine` (circular) | Re-introducing the `late`-injected `onPlay`/`onPause` callback pattern in the new kernel | Resolve via DI composition root, not late callbacks; the existing pattern (`engine_state_machine.dart:28-33`) is a workaround to be retired, not a pattern to copy |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `MemoryMonitor` `Timer.periodic` at 30s in the player subtree | Periodic 30s jank spikes on the player overlay | Keep monitor out of player reactive tree (Pitfall 6) | Immediately — any player widget listening to the notifier |
| `ValueNotifier` rebuilds cascading across the dual-track adapter | One state change rebuilds both legacy and migrated widgets | Single canonical engine; shadowed engine's notifiers disconnected from UI (Pitfall 2) | During dual-track, worsens with each migrated widget |
| Adapter translating per-call (string error → sealed → ErrorView) on the hot path | Per-frame overhead on seek/volume hot paths | Translate errors only; keep state/position as pass-through `ValueNotifier` references | At 60fps UI with frequent position updates |
| `dart:developer.log` at `info` level on every position poll | Release-build log flood | Gate `info` to debug builds (Pitfall 11) | Release users with DevTools attached / log capture |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging raw file paths / media filenames in release | PII / local-file-path leakage to log sinks / crash reports | Redact via `PathUtils.basename` before logging (pattern already in `fvp_engine.dart:260`); facade redacts by default |
| `debugPrint` carrying user content in release | User media filenames / subtitles in release console output | `debugPrint` gated by `kDebugMode` in the facade (Pitfall 11) |
| Memory snapshot JSON export (`MemoryMonitor.exportJson()`) reaching unredacted sinks | RSS history + timestamps in shared logs | Export only via explicit diagnostics action; never auto-log the full snapshot |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| State desync during dual-track (Pitfall 2) | Seek lands on the wrong track; playlist advances but video doesn't | Single canonical engine; parity test gating each migration step |
| Silent illegal-transition ignore (Pitfall 8) | Press play and nothing happens (release); no diagnostic | `Result.err` + visible error state in UI; never silent |
| Release log noise (Pitfall 11) | On Windows, debug output overhead; on crash reports, log spam | Level + mode gating in the facade |
| Adapter collapse regression (Pitfall 4) | A previously-working platform path (macOS subtitle, debug export) breaks silently | Deletion gate checklist; collapse in a dedicated commit |

## "Looks Done But Isn't" Checklist

- [ ] **KernelLogger facade:** Often missing the release-mode gate (`kDebugMode`/level) — verify a `--release` smoke run produces zero `debug`/`info` lines (Pitfall 11).
- [ ] **MemoryMonitor injectable:** Often missing the static-shim deletion — verify `grep -rn "MemoryMonitor\." lib/` returns only instance calls (Pitfall 5).
- [ ] **Sealed error model:** Often missing the `ErrorView` translation at the UI boundary — verify no `KernelError` subclass is imported by any `lib/ui/**` file (Pitfall 7).
- [ ] **Generation guard:** Often missing the unify-with-state-machine step — verify only one `openGeneration` counter exists across engine + adapter (Pitfall 8).
- [ ] **Adapter collapse:** Often missing the generation-guard relocation — verify the new engine guards races *after* the adapter is deleted (Pitfall 4).
- [ ] **Bilingual docs:** Often missing the English contract block on sealed-error subclasses — verify every `KernelError` subclass has both intent (中) and contract (EN) (Pitfall 12).
- [ ] **Dual-track parity:** Often missing timing-sensitive tests — verify a `fakeAsync` open→seek→next sequence passes on both paths (Pitfall 9).
- [ ] **Zero-dep claim:** Often missing the `lib/kernel` import gate — verify `lib/kernel/**` imports neither `package:logger` nor `package:path_provider` (Pitfall 1).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| 1 (logger dep violation) | MEDIUM | Re-introduce the facade as a shim over existing `package:logger`; migrate call sites in batches; remove the dep last, after a green `flutter test` |
| 2 (double source-of-truth) | HIGH | Re-introduce the `KernelMode` arbiter in the composition root; disconnect the shadowed engine's UI notifiers; add the parity test; re-run migration steps |
| 3 (contract drift) | HIGH | Freeze the BCS (P1) retroactively; write contract tests against legacy behavior; fix adapter to match legacy, not the other way |
| 4 (adapter collapsed too early) | HIGH | Revert the collapse commit; move the generation guard; re-run the deletion gate checklist; collapse again in a dedicated commit |
| 5 (singleton static break) | LOW | One commit: re-add the static shim delegating to the instance; in the same commit update the remaining static callers; delete the shim |
| 6 (monitor in player subtree) | MEDIUM | Inject `NoopMemoryMonitor` into the player scope; move the real monitor to the diagnostics scope; remove the `ValueListenableBuilder` on `snapshotNotifier` from player widgets |
| 7 (sealed error crosses thread) | MEDIUM | Reconstruct the error on main; carry callback stack as a field; add `ErrorView` translation; verify no sealed type in `lib/ui` |
| 8 (generation race) | HIGH | Introduce `OpenGenerationTracker`; route all transitions through it; add race + property tests; replace silent ignore with `Result.err` |
| 9 (incremental regression) | MEDIUM | Flip the feature flag back to legacy for the affected service; re-run parity + timing tests; re-migrate in the graph-derived order |
| 10 (over-engineered adapter) | MEDIUM | Invoke senior-architect / red-team on the adapter; cut state; enforce the size budget; delete the `MediaEngineV3` interface |
| 11 (release log leak) | LOW | Add the `kDebugMode` + level gate to the facade; rerun the release smoke test |
| 12 (doc drift) | LOW | Re-apply the structure (intent 中 / contract EN); add the P7 lint; treat English as behavior-authoritative |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 — logger dep already violated | P1 inventory + P4 facade | CI grep: `lib/kernel/**` imports no `package:logger`/`package:path_provider` |
| 2 — double source-of-truth (dual-track) | P2 adapter arbitration | P6 dual-track parity test on state + position sequences |
| 3 — adapter contract drift | P1 BCS freeze + P2 adapter | P6 contract tests assert BCS for both paths |
| 4 — adapter collapsed too early | P6 deletion gate checklist | Zero legacy-engine references post-collapse; race test passes without adapter |
| 5 — singleton → DI build break | P5 atomic migration | `grep -rn "MemoryMonitor\." lib/` returns only instance calls |
| 6 — monitor interferes with playback | P5 interface + DI scoping | P6: player subtree has no `MemoryMonitor` listener |
| 7 — sealed error across threads | P4 sealed model + ErrorView | P6: no `KernelError` imported by `lib/ui/**`; error codes stable |
| 8 — state machine / generation races | P3 unify guard + machine | P6 race + property tests; no `default` in state switches |
| 9 — incremental swap regression | P6 migration order + flags | P6: `flutter test` green at each step; timing parity via `fakeAsync` |
| 10 — over-engineered adapter/facade | P2 size budget + "no state" rule | Line-count budget check at P2/P4/P5; adapter deleted at P6 collapse |
| 11 — release log leak | P4 level + mode gating | P6 release smoke test: zero `debug`/`info` lines in `--release` |
| 12 — bilingual doc drift | P7 structure + lint | P7 grep/lint: every touched public symbol has intent(中) + contract(EN) |

## Sources

- Project files (this codebase, HIGH confidence):
  - `D:\simple_player_flutter\.planning\PROJECT.md` — v3.0 milestone scope, constraints, key decisions
  - `D:\simple_player_flutter\lib\kernel\utils\memory_monitor.dart` — static singleton source (Pitfall 5, 6)
  - `D:\simple_player_flutter\lib\kernel\utils\log.dart` — existing `package:logger` + `path_provider` dependency (Pitfall 1, 11)
  - `D:\simple_player_flutter\lib\kernel\engine\media_engine.dart` — frozen UI→Kernel contract (Pitfall 3)
  - `D:\simple_player_flutter\lib\kernel\engine\fvp_engine.dart` — `openGeneration` guard location, factory pattern, `late` helpers (Pitfall 8, 2)
  - `D:\simple_player_flutter\lib\kernel\engine\engine_state_machine.dart` — silent illegal-transition ignore, `late`-injected callbacks (Pitfall 8, integration gotchas)
  - `D:\simple_player_flutter\lib\main.dart` — `MemoryMonitor.start()` static call site (Pitfall 5)
- Project memory (auto-memory, HIGH confidence, project's own documented lessons):
  - `feedback_singleton_refactoring.md` — delete `_instance` but leave static methods → build failure (Pitfall 5)
  - `anti_pattern_fullscreen_architecture.md` — 10 architecture anti-patterns: over-engineering, double source-of-truth, silent failures, dispose races, 19 vars for 1 bool (Pitfall 10, 2, 8)
  - `project_window_anti_patterns.md` — kernel coupling, god objects, over-abstraction lessons (Pitfall 10)
  - `project_fvp_engine_improvements.md` — openGeneration guard introduction (Pitfall 8)
  - `feedback_comment_while_coding.md` — bilingual doc-comment discipline (Pitfall 12)
- User global rules (`~/.claude/rules/`, HIGH confidence):
  - `dart/coding-style.md` — sealed types, exhaustive switch, no `catch (e)`, no `!`/`late`/`as` (Pitfall 7, 8)
  - `common/coding-style.md` — immutability, input validation at boundaries, KISS/YAGNI (Pitfall 10)
  - `common/security.md` — no secrets in logs, error messages don't leak sensitive data (Pitfall 11, security)
  - `dart/security.md` — log redaction, no sensitive data in `debugPrint` (Pitfall 11)

---
*Pitfalls research for: compatible-replacement kernel rewrite (v3.0) — fvp/MDK-FFmpeg Flutter desktop media player*
*Researched: 2026-07-16*
