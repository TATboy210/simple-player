# Architecture Research

**Domain:** Flutter desktop media player — kernel rewrite via compatible replacement (v3.0)
**Researched:** 2026-07-16
**Confidence:** HIGH (grounded in the live v2.1 codebase at `D:\simple_player_flutter`)

## Standard Architecture

### System Overview

The v3.0 rewrite does NOT greenfield a new kernel. It wraps the existing v2.1 kernel behind a **compatible-replacement adapter seam**, then swaps implementations under it one capability at a time. The UI→Kernel contract (`MediaEngine` / `EngineStateView` / `PlaybackController` facade) is frozen and never changes shape during the migration — only the backing implementation moves from `OldFvpEngine` to `NewFvpEngine` behind the adapter.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        UI Layer (UNCHANGED)                          │
│  player_screen · control_bar · progress_bar · video_surface · ...    │
│  Widgets hold `MediaEngine` / `EngineStateView` / `PlaybackController`│
└───────────────────────────────┬──────────────────────────────────────┘
                                │ frozen contract (EngineStateView read,
                                │  MediaEngine control, PlaybackController facade)
┌───────────────────────────────▼──────────────────────────────────────┐
│              COMPATIBLE-REPLACEMENT ADAPTER SEAM (NEW)                 │
│  KernelAdapter implements MediaEngine+EngineStateView                 │
│  routes → OldFvpEngine (baseline) | NewFvpEngine (incremental)        │
│  + DelegationPolicy / feature flags per capability                   │
└───────────┬───────────────────────────────┬──────────────────────────┘
            │                               │
┌───────────▼───────────────┐   ┌───────────▼──────────────────────────┐
│   OLD kernel (v2.1 baseline)│   │   NEW kernel (v3.0, built incrementally)│
│  FvpEngine (current)        │   │  NewFvpEngine + EngineStateMachine v2  │
│  PlaybackController (god)  │   │  PlaybackControllerV2 (decomposed)     │
│  MemoryMonitor (singleton) │   │  DiagnosticsBundle: KernelLogger,      │
│                            │   │    SealedErrorModel, MemoryMonitorInstance │
└────────────────────────────┘   └────────────────────────────────────────┘
            ▲ dual-track coexistence: adapter picks winner per call until cutover
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `EngineStateView` (interface, frozen) | Read-only playback state surface for UI (`state`, `position`, `volume`, `lastError`, …) | abstract class, ~12 `ValueNotifier` getters; UI binds via `ValueListenableBuilder` |
| `MediaEngine` (interface, frozen) | Composite ISP interface: `EngineStateView` + 6 control mixins (`PlaybackControl`, `TrackControl`, `SubtitleConfig`, `VideoEffectControl`, `RendererControl`, `VolumeControl`) | abstract class, barrel export via `engine_state.dart` |
| `PlaybackController` (facade, frozen shape) | UI's single entry point: delegates to `PlaybackNavigator` / `FileOperations` / `PlaybackStateManager` / `AutoAdvancePolicy` | Facade pattern; `player_screen.dart` holds the instance |
| `KernelAdapter` (NEW) | Implements `MediaEngine`; internally forwards to old or new engine per `DelegationPolicy`; the single place where cutover happens | Adapter + Strategy; constructed in `app.dart`, handed to UI exactly where `MediaEngine` used to be |
| `KernelLogger` (NEW) | Zero-dependency structured logging facade for `lib/kernel/**` — levels, module scope, `dart:developer` sink + controlled `debugPrint` | Facade; concrete `KernelLoggerImpl` wraps `dart:developer.log`; app-level `log.dart` (package:logger) becomes the outer sink, NOT a kernel dep |
| `SealedErrorModel` (EXTEND existing) | Stable error codes + structured context; `sealed class PlayerError` with `FileError`/`CodecError`/`PlaybackError`/`NetworkError`/`UnknownError` | Already exists at `lib/kernel/models/player_error.dart`; v3.0 adds context bag + propagates consistently engine→service→UI |
| `MemoryMonitor` (REFACTOR) | Promoted from static singleton to injectable, toggleable instance; static methods become thin delegates for backward compat | Instance class + `MemoryMonitor.instance` static bridge during migration; injected via `DiagnosticsBundle` |
| `DiagnosticsBundle` (NEW) | First-class carrier of all diagnostics: `KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog`; single ctor param to `NewFvpEngine` / `PlaybackControllerV2` | Composition root in `app.dart` builds one bundle, injects everywhere |
| `EngineStateMachine` (v2.1 → v2) | Exhaustive state machine + `openGeneration` guard; v3.0 hardens lifecycle (dispose ordering, double-dispose safety, error-state recovery) | Already extracted; rewrite tightens transitions + adds lifecycle states |

## Recommended Project Structure

```
lib/kernel/
├── engine/
│   ├── media_engine.dart            # frozen composite interface (UNCHANGED)
│   ├── engine_state_view.dart       # frozen read-only interface (UNCHANGED)
│   ├── engine_state.dart            # barrel export (UNCHANGED)
│   ├── fvp_engine.dart              # RENAMED → old_fvp_engine.dart (baseline, dual-track)
│   ├── new_fvp_engine.dart          # NEW v3.0 implementation (built incrementally)
│   ├── engine_state_machine.dart    # v2 — hardened lifecycle
│   ├── kernel_adapter.dart          # NEW — compatible-replacement seam
│   ├── delegation_policy.dart       # NEW — per-capability old/new routing
│   └── ...helpers (track_manager, position_poller, etc.)
├── diagnostics/                     # NEW folder — diagnostics first-class
│   ├── kernel_logger.dart           # NEW — zero-dep facade + impl
│   ├── log_level.dart               # NEW
│   ├── log_sink.dart                # NEW — dart:developer sink, debugPrint sink
│   ├── memory_monitor.dart          # MOVED from utils/ + refactored to instance
│   ├── memory_snapshot.dart         # MOVED from utils/memory_monitor.dart (split)
│   ├── engine_metrics.dart          # MOVED from engine/ (already exists v2.1)
│   ├── engine_event_log.dart        # MOVED from engine/ (already exists v2.1)
│   └── diagnostics_bundle.dart      # NEW — composite carrier
├── errors/                          # NEW folder — error model first-class
│   ├── player_error.dart            # MOVED from models/ (sealed class, EXTENDED)
│   ├── error_code.dart              # NEW — stable error code registry
│   └── error_context.dart           # NEW — structured context bag
├── services/
│   ├── playback_controller.dart     # OLD (frozen shape) during dual-track
│   ├── playback_controller_v2.dart  # NEW — decomposed orchestrator (target)
│   └── ... (navigator, state_manager, auto_advance, file_ops)
├── models/  · persistence/ · playlist/ · scanner/ · bridge/ · utils/
└── utils/log.dart                   # app-level logger (package:logger) — NOT a kernel dep after v3.0
```

### Structure Rationale

- **`diagnostics/` (NEW):** Elevates `KernelLogger`, `MemoryMonitor`, `EngineMetrics`, `EngineEventLog` to a single cohesive subsystem. Today these are scattered (`utils/memory_monitor.dart`, `engine/engine_metrics.dart`, `engine/engine_event_log.dart`, `utils/log.dart`). A dedicated folder makes "diagnostics as a first-class kernel citizen" structurally visible and gives the `DiagnosticsBundle` a home.
- **`errors/` (NEW):** The sealed `PlayerError` hierarchy is a cross-cutting domain type, not a generic model. Giving it a folder signals it is the canonical error contract and concentrates the v3.0 stabilization work (codes + context).
- **`engine/kernel_adapter.dart` + `delegation_policy.dart`:** The adapter seam must be discoverable and co-located with the engine interfaces it implements. Separating the policy (which capability routes where) from the adapter (the `MediaEngine`-shaped shell) keeps the cutover switch in one auditable file.
- **`old_fvp_engine.dart` vs `new_fvp_engine.dart`:** Renaming the current `fvp_engine.dart` to `old_fvp_engine.dart` makes dual-track coexistence literal — both files exist, the adapter picks. After full cutover, `old_*` is deleted and `new_fvp_engine.dart` is renamed back.

## Architectural Patterns

### Pattern 1: Compatible-Replacement Adapter (the spine of v3.0)

**What:** A class implementing the frozen `MediaEngine` interface that holds references to both the old and new engine implementations and delegates each call to one of them per a `DelegationPolicy`. UI never knows which engine served a call.
**When to use:** When rewriting a subsystem whose consumers (UI) must not change and whose behavior must not regress during a long migration.
**Trade-offs:** + zero UI churn, + per-capability cutover, + instant rollback (flip policy); − a transient indirection layer (deleted after cutover), − adapter must faithfully reproduce ValueNotifier identity semantics (see Pitfall 1).

```dart
/// The single MediaEngine-shaped shell UI talks to during v3.0.
class KernelAdapter implements MediaEngine {
  KernelAdapter(this._old, this._new, this._policy);

  final MediaEngine _old;          // old FvpEngine (baseline)
  final MediaEngine _new;          // NewFvpEngine (incremental)
  final DelegationPolicy _policy;  // per-capability old/new routing

  @override
  ValueNotifier<MediaState> get state =>
      _policy.useStateV2 ? _new.state : _old.state;

  @override
  Future<void> open(String path) =>
      _policy.openUsesV2 ? _new.open(path) : _old.open(path);
  // ... every MediaEngine member delegates via _policy
}
```

### Pattern 2: DiagnosticsBundle (dependency injection for first-class diagnostics)

**What:** One immutable bundle carrying `KernelLogger` + `MemoryMonitor` + `EngineMetrics` + `EngineEventLog`, passed as a single ctor param to any kernel component that needs diagnostics. Replaces global singletons and `static` access.
**When to use:** Whenever "diagnostics is a first-class kernel citizen" must be enforced structurally rather than by convention.
**Trade-offs:** + testability (inject fakes), + toggleability (pass a no-op bundle in tests/release), + one wiring site; − every kernel class grows one ctor param (acceptable; it's the single seam for all observability).

```dart
final class DiagnosticsBundle {
  const DiagnosticsBundle({
    required this.logger,
    required this.memoryMonitor,
    required this.metrics,
    required this.eventLog,
    this.enabled = true,
  });
  final KernelLogger logger;
  final MemoryMonitor memoryMonitor; // instance, not singleton
  final EngineMetrics metrics;
  final EngineEventLog eventLog;
  final bool enabled;

  static const DiagnosticsBundle noop = DiagnosticsBundle(
    logger: NoopKernelLogger(),
    memoryMonitor: _NoopMemoryMonitor(),
    metrics: EngineMetrics(),
    eventLog: EngineEventLog(),
    enabled: false,
  );
}
```

### Pattern 3: Static-Singleton-to-Instance Bridge (backward-compat migration)

**What:** Promote `MemoryMonitor` from `static final _instance` to a normal instance class, but keep the existing `static void start(...)` / `static MemorySnapshot? snapshot()` / `static String exportJson()` methods as thin delegates to a held instance. Existing callers (`main.dart` `MemoryMonitor.start()`; `debug_exporter.dart` `MemoryMonitor.snapshot()`) keep compiling unchanged. New code injects an instance via `DiagnosticsBundle`.
**When to use:** Refactoring a global singleton without churning every call site at once.
**Trade-offs:** + zero churn at old call sites, + new code gets a real instance; − a transitional static bridge that must be deleted post-cutover (schedule it).

```dart
class MemoryMonitor {
  MemoryMonitor({this.thresholdBytes = 50 * 1024 * 1024, this.maxHistory = 200});
  // instance API: start(), stop(), snapshot(), exportJson(), snapshotNotifier

  // ── backward-compat static bridge (delete after full cutover) ──
  static final MemoryMonitor _default = MemoryMonitor();
  static void start({Duration interval = const Duration(seconds: 30),
      void Function(MemorySnapshot)? onTick}) =>
      _default.start(interval: interval, onTick: onTick);
  static MemorySnapshot? snapshot() => _default.snapshot();
  static String exportJson() => _default.exportJson();
}
```

### Pattern 4: Sealed Error Model with Structured Context

**What:** The existing `sealed class PlayerError` is extended with a stable `ErrorCode` registry and an `ErrorContext` bag (path, action, generation, timestamp, module). Engine sets `lastError.value`; service catches and enriches; UI renders by exhaustive `switch`. `KernelLogger` consumes the same model so logs and errors share a vocabulary.
**When to use:** Any time error handling spans engine→service→UI and must be stable, typed, and exhaustively matchable.
**Trade-offs:** + compile-time exhaustiveness, + structured logs for free; − one-time cost to audit every `on Exception catch` site and route through the model.

## Data Flow

### Current (v2.1) data flow — the baseline being preserved

```
User Action (key/tap)
   ↓
player_screen (holds MediaEngine + PlaybackController)
   ↓
PlaybackController facade → PlaybackNavigator / FileOperations / PlaybackStateManager / AutoAdvancePolicy
   ↓
MediaEngine (FvpEngine) → mdk.Player → texture/position/state ValueNotifiers
   ↑                                          ↓
   └─ EngineStateMachine guards transitions    ValueListenableBuilder rebuilds UI
MemoryMonitor.start() runs globally; debugPrint scattered; log.dart (package:logger) used directly
```

### v3.0 target data flow — same shape, instrumented backbone

```
User Action (key/tap)
   ↓
player_screen (holds MediaEngine + PlaybackController)  ← UNCHANGED contract
   ↓
KernelAdapter (implements MediaEngine) ──DelegationPolicy──▶ OldFvpEngine | NewFvpEngine
   ↓ (new path)                                                ↓ (old path = baseline)
PlaybackControllerV2 (decomposed) ── DiagnosticsBundle ──▶ KernelLogger · MemoryMonitor(instance)
   ↓                                                          ↓
NewFvpEngine → EngineStateMachine v2 (openGeneration guard)    EngineMetrics · EngineEventLog
   ↓                                                          ↓
SealedErrorModel (PlayerError + ErrorContext) ── lastError.value ──▶ UI error_banner (exhaustive switch)
   ↓
KernelLogger emits via dart:developer + debugPrint (zero kernel dep); app-level log.dart may attach as a sink
```

### Key Data-Flow Changes

1. **Diagnostics injection replaces global access.** Today `MemoryMonitor.start()` is called once in `main.dart` and `EngineMetrics`/`EngineEventLog` are fields on `FvpEngine`. In v3.0 a single `DiagnosticsBundle` is built in `app.dart` and threaded into `NewFvpEngine` + `PlaybackControllerV2`. Old `MemoryMonitor.start()` still works via the static bridge.
2. **Error flow becomes typed end-to-end.** Today `lastError.value` is set ad-hoc inside `FvpEngine.open/play/seek` with `on Exception catch (e)` then `debugPrint`. In v3.0 every error site constructs a `PlayerError` subclass with `ErrorContext` (action, generation, path), assigns it to `lastError.value`, AND emits one structured `KernelLogger` record. Service layer enriches context; UI renders via exhaustive `switch`.
3. **Log calls decouple from `package:logger`.** Today kernel code imports `utils/log.dart` (`logEngine`, `logServices`, …) which depends on `package:logger`. In v3.0 kernel code calls `bundle.logger.i(...)` against the `KernelLogger` abstraction. The concrete `KernelLoggerImpl` may still forward to `dart:developer.log` + controlled `debugPrint`; the app layer (`log.dart`) keeps `package:logger` for file rotation but is no longer a kernel dependency.
4. **Adapter introduces a fan-out point.** Every `MediaEngine` call now flows through `KernelAdapter` which fans out to old or new. `ValueNotifier` identity is preserved by the adapter forwarding the SAME notifier instance from the active engine (see Pitfall 1).
5. **`openGeneration` guard becomes a first-class lifecycle concept.** Already present in `FvpEngine._openGeneration`; v3.0 promotes it into `EngineStateMachine v2` so the guard survives the engine rewrite and is testable in isolation.

## How the 5 New Capabilities Integrate — per-capability breakdown

### Capability A: Zero-dependency `KernelLogger` facade

- **Where it sits:** `lib/kernel/diagnostics/kernel_logger.dart`. It is a kernel-internal abstraction; `lib/kernel/**` depends ONLY on this abstraction, never on `package:logger`.
- **What consumes it:** Every kernel component that today calls `logEngine`/`logServices`/`debugPrint` — `FvpEngine`, `PlaybackController`, `PlaybackNavigator`, `PlaybackStateManager`, `AutoAdvancePolicy`, `FileOperations`, `TrackManager`, `PositionPoller`, `VolumeController`, etc.
- **Integration points:** (1) `DiagnosticsBundle.logger` field; (2) replace `import '../utils/log.dart'` with `import '../diagnostics/kernel_logger.dart'` at each kernel file; (3) the engine `on Exception catch` sites call `bundle.logger.e(...)` instead of `logEngine.e(...)`.
- **New vs modified:** NEW `kernel_logger.dart`, `log_level.dart`, `log_sink.dart`, `diagnostics_bundle.dart`. MODIFIED: every kernel file that imports `log.dart` (the import line + call sites). UNCHANGED: `utils/log.dart` itself stays as the app-level logger (it may later register as a `LogSink` with `KernelLoggerImpl`, but that wiring lives outside kernel).
- **Data-flow change:** Kernel log calls now go `bundle.logger → LogSink → dart:developer.log / debugPrint`. The `package:logger` + file-rotation path is reachable only via an app-level sink registration, NOT by kernel importing it.

### Capability B: Sealed error model (stabilize + structured context)

- **Where it sits:** `lib/kernel/errors/player_error.dart` (MOVED from `models/`), plus NEW `error_code.dart` (stable code registry) and `error_context.dart` (structured bag).
- **What consumes it:** `FvpEngine.lastError` (already typed `ValueNotifier<PlayerError?>`); service-layer `on Exception catch` sites; UI `error_banner.dart` (already takes `EngineStateView` and reads `lastError`).
- **Integration points:** (1) every `FvpEngine` `on Exception catch (e) { lastError.value = PlaybackError(...) }` site gains an `ErrorContext`; (2) `PlaybackController.onError` callback receives a `PlayerError` not a bare `Object`; (3) `KernelLogger` emits a structured record from the same `PlayerError` (logger + error share a vocabulary).
- **New vs modified:** NEW `error_code.dart`, `error_context.dart`; MODIFIED `player_error.dart` (add `context` field + stable codes), all `FvpEngine` catch sites, `PlaybackController._onError` signature, UI `error_banner` rendering (exhaustive `switch`). Note the sealed hierarchy ALREADY EXISTS — v3.0 stabilizes it rather than inventing it.
- **Data-flow change:** `engine error → PlayerError+context → lastError.value + logger.e() → service enriches context → UI exhaustive switch`. Today the chain is broken: some sites `debugPrint` only, some set `lastError`, no structured context, logger and error use different vocabularies.

### Capability C: Injectable `MemoryMonitor` (promote from singleton)

- **Where it sits:** `lib/kernel/diagnostics/memory_monitor.dart` (MOVED from `utils/`), split into `memory_monitor.dart` (instance) + `memory_snapshot.dart` (`MetricSample`/`MemorySnapshot` data classes).
- **What consumes it:** Today: `main.dart` (`MemoryMonitor.start()`) and `debug_exporter.dart` (`MemoryMonitor.snapshot()`). v3.0 adds: `DiagnosticsBundle.memoryMonitor`, consumed by `NewFvpEngine` (for RSS-aware decisions) and exposed to UI via the bundle (for a future diagnostics panel).
- **Integration points:** (1) `main.dart` keeps calling `MemoryMonitor.start()` — the static bridge delegates to the held instance; (2) `app.dart` constructs a `MemoryMonitor` instance and puts it in `DiagnosticsBundle`; (3) `debug_exporter.dart` migrates from `MemoryMonitor.snapshot()` static to `bundle.memoryMonitor.snapshot()` (one-line change, do it late in migration).
- **New vs modified:** MODIFIED `memory_monitor.dart` (instance ctor + static bridge), MOVED to `diagnostics/`, split data classes into `memory_snapshot.dart`. MODIFIED `main.dart` (no change needed thanks to static bridge), `debug_exporter.dart` (optional migration). NEW: `DiagnosticsBundle.memoryMonitor` field.
- **Data-flow change:** No behavioral change to RSS sampling. The change is ownership: the monitor instance is now owned by `DiagnosticsBundle` (injectable, toggleable via `enabled` flag, fakeable in tests) instead of a process-global singleton. The hardcoded 50MB/200/30s constants become ctor params with current values as defaults.

### Capability D: Compatible-replacement adapter layer (the seam)

- **Where it sits:** `lib/kernel/engine/kernel_adapter.dart` + `lib/kernel/engine/delegation_policy.dart`. Between UI and old/new engines. Constructed in `app.dart`, passed to `player_screen` exactly where `MediaEngine` used to be passed.
- **What consumes it:** `player_screen.dart` and every UI widget that takes `MediaEngine`/`EngineStateView` — they receive the adapter instead of `FvpEngine` and never know the difference.
- **Integration points:** (1) `app.dart` builds `old = OldFvpEngine()`, `new = NewFvpEngine(diagnostics: bundle)`, `adapter = KernelAdapter(old, new, policy)`, hands `adapter` to `PlaybackController`/UI; (2) `DelegationPolicy` starts all-old, flips per-capability as each is migrated; (3) `ValueNotifier` getters on the adapter forward the active engine's notifier instance (NOT a wrapper) so existing listeners keep working.
- **New vs modified:** NEW `kernel_adapter.dart`, `delegation_policy.dart`. RENAMED `fvp_engine.dart` → `old_fvp_engine.dart`. MODIFIED `app.dart` (composition root: build adapter + bundle). UNCHANGED: every UI widget signature (`MediaEngine engine` still works), every frozen interface.
- **Data-flow change:** One extra hop per `MediaEngine` call (adapter → policy → engine). `ValueNotifier` identity is preserved by forwarding the same instance, so `ValueListenableBuilder` listeners are unaffected.

### Capability E: State & lifecycle rewrite (MediaEngine / FvpEngine)

- **Where it sits:** `lib/kernel/engine/new_fvp_engine.dart` (NEW) + `engine_state_machine.dart` (v2, hardened). The old `FvpEngine` becomes `OldFvpEngine` and keeps running.
- **What consumes it:** `KernelAdapter` (holds a `NewFvpEngine` reference); ultimately `PlaybackControllerV2`.
- **Integration points:** (1) `NewFvpEngine` implements the SAME `MediaEngine` interface — no new interface; (2) `EngineStateMachine v2` adds lifecycle states beyond the current 6-value `MediaState` enum (e.g. `disposed`, `disposing`) or models lifecycle as a separate orthogonal flag, hardened dispose ordering; (3) `openGeneration` guard moves into the state machine so it is testable in isolation; (4) double-dispose / use-after-dispose safety (`_disposed` checks become lifecycle states).
- **New vs modified:** NEW `new_fvp_engine.dart`. MODIFIED `engine_state_machine.dart` (lifecycle hardening). UNCHANGED: `MediaState` enum (frozen — UI switches on it), `MediaEngine` interface.
- **Data-flow change:** State transitions are still `state.value = next` via the state machine, but the machine now also owns the generation guard and lifecycle flags, so the engine class shrinks and the transition rules are unit-testable without an mdk.Player. Recovery from `error` state becomes explicit (a `recover()` transition rather than ad-hoc `transitionTo(idle)`).

## Suggested Build Order (respects compatible-replacement migration)

This ordering follows the milestone's own guidance (baseline contract freeze → adapter seam → state/lifecycle → error model + KernelLogger → MemoryMonitor first-class → test & migration verification → bilingual doc) and the inter-capability dependencies discovered above.

### Phase 1 — Baseline Contract Freeze (no new code, only capture)

- **Goal:** Pin the UI→Kernel contract so the adapter has something to implement.
- **Work:** (1) Document every `MediaEngine`/`EngineStateView` member actually consumed by UI (audit `lib/ui/**` imports — already mapped: 18 widgets take `MediaEngine`/`EngineStateView`). (2) Document every `PlaybackController` public method called by UI. (3) Snapshot the current `PlayerError` sealed hierarchy + `MediaState` enum as the frozen baseline. (4) Write **contract tests** against the interface (not the implementation) — these become the migration gate.
- **Why first:** The adapter and every later phase depend on a stable contract. Freezing it first prevents accidental contract drift during rewrite.
- **Capabilities touched:** none yet — establishes the seam definition for D and the surface for B/E.
- **Deepest research risk:** Low. Standard interface-capture work.

### Phase 2 — Adapter Seam + DiagnosticsBundle skeleton

- **Goal:** Stand up `KernelAdapter` + `DelegationPolicy` + `DiagnosticsBundle` shell so subsequent capabilities have somewhere to land. Adapter routes 100% to old engine (no behavior change).
- **Work:** (1) Rename `fvp_engine.dart` → `old_fvp_engine.dart`. (2) Create `KernelAdapter implements MediaEngine` forwarding everything to old. (3) Create `DiagnosticsBundle` with a `noop` default. (4) Wire `app.dart` to construct `KernelAdapter(old, old, policyAllOld)` and pass it where `FvpEngine` used to go. (5) Run full test suite — must be 100% green (zero behavior change).
- **Why second:** The adapter must exist before any new capability can be routed through it. Building the bundle shell now means Capabilities A/B/C have a carrier.
- **Capabilities touched:** D (skeleton), DiagnosticsBundle shell (carrier for A/B/C).
- **Deepest research risk:** MEDIUM. ValueNotifier identity forwarding (Pitfall 1) and ensuring the adapter faithfully reproduces ALL interface members are the subtle parts.

### Phase 3 — KernelLogger facade (Capability A)

- **Goal:** Kernel stops importing `package:logger`; all kernel log calls go through `KernelLogger`.
- **Work:** (1) Create `diagnostics/kernel_logger.dart` + `log_level.dart` + `log_sink.dart` (`dart:developer.log` + controlled `debugPrint` sinks). (2) Add `logger` to `DiagnosticsBundle`. (3) Sweep `lib/kernel/**` replacing `import '../utils/log.dart'` + `logEngine.x`/`logServices.x`/`debugPrint(...)` with `bundle.logger.x(...)`. (4) Optionally register the app-level `log.dart` as a `LogSink` in `app.dart` (wiring lives outside kernel).
- **Why third:** KernelLogger is a prerequisite for the sealed error model (Capability B) — errors and logs must share a vocabulary, and the logger must exist before error sites emit through it. It is independent of the state rewrite (E), so it can land before E.
- **Capabilities touched:** A fully; DiagnosticsBundle gains its first real member.
- **Deepest research risk:** LOW. Facade + sink is well-trodden. Main care area: preserving log level semantics vs the existing `package:logger` `Level` mapping and ensuring `dart:developer.log` carries structured fields.

### Phase 4 — Sealed Error Model stabilization (Capability B)

- **Goal:** Stable error codes + structured context; engine→service→UI typed error flow.
- **Work:** (1) Move `player_error.dart` to `errors/`, add `ErrorContext` (action, generation, path, timestamp, module) and an `ErrorCode` registry. (2) Audit every `FvpEngine` `on Exception catch` site — construct `PlayerError` with `ErrorContext`, assign `lastError.value`, emit via `bundle.logger.e(...)` (now available from Phase 3). (3) Change `PlaybackController._onError` from `void Function(Object)` to `void Function(PlayerError)`. (4) UI `error_banner` renders via exhaustive `switch` on the sealed hierarchy.
- **Why fourth:** Depends on KernelLogger (Phase 3) for structured emission. The error model touches engine (E's domain) but can be applied to the OLD engine first (it still runs behind the adapter), so it does NOT block on the state rewrite.
- **Capabilities touched:** B fully; interacts with E's catch sites but does not require E done.
- **Deepest research risk:** MEDIUM. Auditing every catch site and changing the `_onError` callback signature ripples to UI — must stay contract-compatible at the `EngineStateView.lastError` boundary (the `ValueNotifier<PlayerError?>` type is unchanged, only the callback typing changes).

### Phase 5 — MemoryMonitor first-class (Capability C)

- **Goal:** Injectable, toggleable instance; static bridge preserves callers.
- **Work:** (1) Move `memory_monitor.dart` to `diagnostics/`, split data classes to `memory_snapshot.dart`. (2) Convert to instance class with ctor params (threshold/maxHistory/interval) keeping current values as defaults. (3) Keep `static start/stop/snapshot/exportJson` as delegates to a held `_default` instance. (4) Add `memoryMonitor` to `DiagnosticsBundle`; construct one instance in `app.dart`. (5) `main.dart`'s `MemoryMonitor.start()` keeps working via static bridge. (6) (Optional, late) migrate `debug_exporter.dart` to `bundle.memoryMonitor.snapshot()`.
- **Why fifth:** Depends on `DiagnosticsBundle` (Phase 2) and benefits from KernelLogger (Phase 3) for its threshold-exceeded emission. It is the most self-contained capability and the lowest risk, so it lands after the cross-cutting logger/error work to avoid churning on two fronts at once.
- **Capabilities touched:** C fully.
- **Deepest research risk:** LOW. Singleton-to-instance bridge is a standard refactor. Care area: ensure the static bridge's `_default` instance is the SAME one put in the bundle, or the UI and the diagnostics panel would see different snapshots.

### Phase 6 — State & Lifecycle Rewrite (Capability E)

- **Goal:** `NewFvpEngine` + `EngineStateMachine v2` with hardened lifecycle, generation guard in the state machine, dispose ordering, error-recovery transition.
- **Work:** (1) Build `new_fvp_engine.dart` implementing `MediaEngine` against `DiagnosticsBundle` (A/C available) and emitting `PlayerError+context` (B available). (2) Harden `EngineStateMachine v2`: lifecycle flags, `openGeneration` guard moves in, explicit `recover()` from `error`, double-dispose safety. (3) Flip `DelegationPolicy` for engine-control capabilities one-by-one to `new`; run contract tests (Phase 1) after each flip. (4) When all policies point to `new`, delete `old_fvp_engine.dart` and collapse the adapter (or keep it as a thin facade for future multi-engine support).
- **Why sixth:** It is the largest change and the one that benefits from ALL prior capabilities being in place (logger, errors, memory monitor, bundle, adapter). Doing it earlier would mean rewriting the engine twice (once without diagnostics, once with). Doing it last means the new engine is born first-class.
- **Capabilities touched:** E fully; consumes A, B, C, D.
- **Deepest research risk:** HIGH. The state machine lifecycle hardening and the `openGeneration`-in-state-machine move are the subtlest parts. Recovery from `error` state and dispose ordering are the classic regression sources (see Pitfalls 2, 3).

### Phase 7 — Test & Migration Verification

- **Goal:** Prove the migration preserved behavior.
- **Work:** (1) Contract tests (Phase 1) pass against `NewFvpEngine`. (2) Dual-track regression suite: run the same UI widget tests against `KernelAdapter` with policy all-old (baseline) and all-new (cutover) — outputs must match. (3) Delete `old_fvp_engine.dart` + static `MemoryMonitor` bridge + adapter (or retain adapter as facade for future multi-engine). (4) Verify `flutter analyze` strict-clean, `flutter test --coverage` ≥ 80% on `kernel/`.
- **Why last:** Verification is only meaningful once the cutover is complete.
- **Deepest research risk:** MEDIUM. Dual-track differential testing is the non-trivial part.

### Phase 8 — Bilingual API doc standard

- **Goal:** Every new/refactored public API carries Chinese intent + English contract doc comments.
- **Work:** Sweep `diagnostics/`, `errors/`, `kernel_adapter.dart`, `new_fvp_engine.dart`, `engine_state_machine.dart` v2 and apply the bilingual standard. Can run in parallel with Phases 3–6 as each lands; finalize in Phase 8.
- **Why concurrent/last:** Documentation discipline per-phase is ideal, but a final pass guarantees no API missed.
- **Deepest research risk:** LOW.

### Build-order dependency graph

```
Phase 1 (Contract Freeze) ──────────────────────────────┐
        │                                                 │
        ▼                                                 │
Phase 2 (Adapter + Bundle skeleton) ──────────────┐       │
        │                                          │       │
        ├─▶ Phase 3 (KernelLogger A) ──┐          │       │
        │                              ▼          │       │
        │              Phase 4 (Error model B) ◀──┘       │
        │                              │                  │
        │                              ▼                  │
        │              Phase 5 (MemoryMonitor C) ◀─ Bundle │
        │                              │                  │
        │                              ▼                  │
        └────────────▶ Phase 6 (State rewrite E) ◀── A,B,C,D
                                       │
                                       ▼
                          Phase 7 (Verify) ◀── contract tests from Phase 1
                                       │
                                       ▼
                          Phase 8 (Bilingual docs)  (parallelizable with 3–6)
```

**Inter-capability dependencies (the load-bearing ordering constraints):**
- **Logger before Error model:** the error model emits structured logs through the logger; they must share a vocabulary, so KernelLogger (A) must exist before the error sites are rewritten (B).
- **Adapter before State rewrite:** the new engine (E) only has somewhere to live because the adapter (D) routes to it; without the adapter, replacing the engine means a big-bang swap (forbidden).
- **Bundle before A/B/C:** all three diagnostics capabilities need the `DiagnosticsBundle` carrier (built in Phase 2).
- **State rewrite last among capabilities:** E consumes A, B, C, D — building it earlier forces rework.
- **Contract freeze before everything:** the adapter implements the frozen contract; without freeze, contract drift breaks the migration gate.

## Scaling Considerations

This is a desktop media player, not a web service; "scale" means engine/playlist complexity, not user count.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single file, single engine | Adapter routes all-old; DiagnosticsBundle carries one logger + one monitor; contract tests guard the interface. |
| Multi-file playlist, frequent seek/skip | `openGeneration` guard (now in state machine) proves its worth; `EngineEventLog` ring buffer (100 events) may need to grow — make capacity a bundle param. |
| Future: multi-instance / ABR / plugins | The adapter seam IS the multi-engine hook — a second `NewFvpEngine` can be routed for a second texture without UI change. `DiagnosticsBundle` already makes per-instance diagnostics injectable. |

### Scaling Priorities

1. **First bottleneck:** `ValueNotifier` listener leaks on engine cutover — the adapter must forward the active engine's notifier instances, not re-wrap them, or listeners detach. Solve in Phase 2 (Pitfall 1).
2. **Second bottleneck:** Dual-track test explosion — maintaining old + new doubles the test surface. Solve by differential contract tests (Phase 1 + Phase 7) rather than duplicating suites.

## Anti-Patterns

### Anti-Pattern 1: Adapter wraps ValueNotifiers in fresh instances

**What people do:** `KernelAdapter` creates its own `ValueNotifier` and syncs from the active engine's notifier to keep it updated.
**Why it's wrong:** Every UI `ValueListenableBuilder` registered on the original `FvpEngine.state` stops receiving updates because the notifier object identity changed. Silent UI freeze on cutover.
**Do this instead:** The adapter returns the active engine's notifier instance directly: `ValueNotifier<MediaState> get state => _policy.useStateV2 ? _new.state : _old.state;`. On cutover, either (a) keep UI re-binding to the adapter's getter (re-evaluated on rebuild) or (b) use a single notifier owned by the adapter that the active engine writes into — but pick ONE and document it; do not re-wrap per call.

### Anti-Pattern 2: Big-bang engine swap behind the adapter

**What people do:** Flip `DelegationPolicy` from all-old to all-new in one commit to "finish the migration."
**Why it's wrong:** Violates the milestone's explicit "禁止一次性全量替换" constraint; one regression rolls back the entire rewrite.
**Do this instead:** Flip the policy per-capability (e.g. `open` to new first, then `seek`, then `trackControl`…) running contract tests after each flip. Only when all point to `new` is `old_*` deleted.

### Anti-Pattern 3: KernelLogger re-introduces `package:logger` as a kernel dep

**What people do:** Implement `KernelLoggerImpl` by extending `package:logger.Logger` "for convenience."
**Why it's wrong:** Re-couples the kernel to a third-party package, violating the zero-new-dependency constraint and the "minimal kernel dependency boundary" decision.
**Do this instead:** `KernelLoggerImpl` depends only on `dart:developer` + `debugPrint`. If rich file rotation is desired, the APP layer registers a `LogSink` with `KernelLoggerImpl` at composition time; the kernel never imports `package:logger`.

### Anti-Pattern 4: Keeping the `MemoryMonitor` static bridge forever

**What people do:** Ship the static-bridge refactor and never delete it; two access paths coexist indefinitely.
**Why it's wrong:** The bridge exists only for migration; leaving it recreates the global-singleton anti-pattern the refactor was meant to kill.
**Do this instead:** Schedule the static bridge deletion in Phase 7. Migrate `main.dart` and `debug_exporter.dart` to the instance API, then delete the static methods.

### Anti-Pattern 5: Treating the sealed error model as new when it already exists

**What people do:** Re-design a fresh error hierarchy, breaking the existing `ValueNotifier<PlayerError?>` contract and every `error_banner` switch.
**Why it's wrong:** The sealed `PlayerError` hierarchy already exists and is the frozen contract. Re-inventing it is out-of-scope churn.
**Do this instead:** EXTEND `player_error.dart` in place: add `ErrorContext` and `ErrorCode` registry, keep the five existing subclasses and their enum codes, preserve `ValueNotifier<PlayerError?>` typing. Stabilize, do not replace.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| fvp / MDK (`package:fvp`) | Unchanged — `NewFvpEngine` wraps `mdk.Player` exactly as `FvpEngine` does | Engine binding frozen; v3.0 does NOT touch the native layer |
| `package:logger` (app-level) | Stays in `lib/kernel/utils/log.dart` for app/file rotation; registers as a `LogSink` with `KernelLoggerImpl` via `app.dart` wiring | Kernel never imports it post-Phase-3; only the app composition root may connect it |
| `package:path_provider` | Used by `log.dart` for log directory; unaffected | Already app-level, not kernel-level |
| `shared_preferences` | Used by `SettingsStore`; unaffected | Not in kernel diagnostics path |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI ↔ KernelAdapter | `MediaEngine` / `EngineStateView` interface calls + `ValueNotifier` listener binding | Frozen contract; adapter is transparent |
| KernelAdapter ↔ Old/New engine | direct method dispatch via `DelegationPolicy` | One hop; policy is a pure routing decision |
| Kernel component ↔ DiagnosticsBundle | constructor injection of `DiagnosticsBundle` | Single seam for all observability; `noop` bundle for tests |
| Engine ↔ EngineStateMachine v2 | `transitionTo(next, caller)` + `openGeneration` guard | State machine owns lifecycle + generation; engine class shrinks |
| Engine ↔ SealedErrorModel | `lastError.value = PlayerError(...)` + `bundle.logger.e(...)` | One error → one notifier assignment + one log record; no double-handling |
| Service ↔ Engine | `PlaybackController` (v1 frozen / v2 decomposed) → `MediaEngine` | Facade shape frozen; v2 decomposes internals but keeps the facade |
| Old `MemoryMonitor.start()` static ↔ instance bridge | static method → `_default` instance | Migration-only; deleted in Phase 7 |

## Sources

- `D:\simple_player_flutter\.planning\PROJECT.md` — v3.0 milestone scope, constraints, key decisions (the authoritative requirements source)
- `D:\simple_player_flutter\lib\kernel\engine\media_engine.dart` — frozen `MediaEngine` composite interface (7-ISP aggregation)
- `D:\simple_player_flutter\lib\kernel\engine\engine_state_view.dart` — frozen UI read-only state surface (12 ValueNotifiers)
- `D:\simple_player_flutter\lib\kernel\engine\fvp_engine.dart` — current `FvpEngine` (becomes `OldFvpEngine`): factory ctor, `EngineStateMachine`, `openGeneration`, `EngineMetrics`, `EngineEventLog`, `on Exception catch` sites, `lastError` assignments
- `D:\simple_player_flutter\lib\kernel\engine\engine_state_machine.dart` — current exhaustive state machine (6 `MediaState` values, `_canTransitionTo` switch, `togglePlayPause` via injected callbacks) — the v2 hardening baseline
- `D:\simple_player_flutter\lib\kernel\models\player_error.dart` — EXISTING sealed `PlayerError` hierarchy (File/Codec/Playback/Network/UnknownError + enum codes) — v3.0 EXTENDS, does not replace
- `D:\simple_player_flutter\lib\kernel\utils\memory_monitor.dart` — current static-singleton `MemoryMonitor` (50MB/200/30s hardcoded, `DateTime.now()`, `debugPrint` direct) — the promotion target
- `D:\simple_player_flutter\lib\kernel\utils\log.dart` — current `package:logger`-based module loggers (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`) + `initLog()` file rotation — becomes app-level only post-Phase-3
- `D:\simple_player_flutter\lib\kernel\services\playback_controller.dart` — current `PlaybackController` facade (4 sub-modules via `PlaybackContract`), `DebugProbe`, `currentFileName`, `_onError` callback — the frozen facade shape
- `D:\simple_player_flutter\lib\main.dart` — composition root: `initLog()`, `MemoryMonitor.start()`, `EnginePrewarm`, `StartupCoordinator` — the wiring site that Phase 2 modifies
- `pubspec.yaml` — confirms `logger: ^2.5.0` and `path_provider: ^2.1.5` are EXISTING deps (the "zero NEW dependency" constraint is about not adding more, and decoupling kernel from them)
- UI consumer audit (`lib/ui/**` `MediaEngine`/`EngineStateView` references: 18 widgets) — confirms the contract surface that must remain frozen

---
*Architecture research for: Flutter desktop media player kernel rewrite (v3.0 compatible replacement)*
*Researched: 2026-07-16*
