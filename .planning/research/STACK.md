# Stack Research

**Domain:** Flutter desktop media player — v3.0 kernel rewrite (compatible replacement + diagnostic-first kernel)
**Researched:** 2026-07-16
**Confidence:** HIGH (stdlib/foundation primitives verified against Dart 3 + Flutter foundation docs via Context7)
**Supersedes:** prior 2026-07-14 STACK.md (which listed `package:logger` as KEEP — now contradicted by v3.0's hard zero-new-dep constraint; KernelLogger facade replaces it)

## Scope of This Research

This STACK answers ONE question: **what exact Dart stdlib + `package:flutter/foundation.dart` primitives are needed for the five NEW v3.0 kernel capabilities — using ONLY `dart:` and `package:flutter/foundation.dart`?**

The five capabilities:
1. Zero-dependency `KernelLogger` facade (NO third-party `logger` package).
2. Sealed error model (stable error codes + structured context).
3. Injectable / toggleable `MemoryMonitor` (first-class diagnostic).
4. Anti-corruption adapter layer for incremental kernel migration.
5. Engine abstraction + state machine (continuing v2.1 direction).

**HARD CONSTRAINT honored throughout:** kernel adds NO new third-party runtime dependencies. Every capability below is built from `dart:*` stdlib + `package:flutter/foundation.dart` only. Logging primary path = `dart:developer`; secondary path = controlled `debugPrint`. Future file/remote sinks are swappable *inside* the facade (no external dep required to swap).

**Relationship to the prior 2026-07-14 STACK:** the earlier doc's architectural recommendations (mixin → abstract interface, sealed `EngineError`, `PlaybackController` decomposition, unified `MediaControl`) remain valid context for capabilities 4 & 5. This file focuses on the NEW v3.0 diagnostic-surface primitives (capabilities 1–3) that the prior doc did not research, and corrects its stale "logger KEEP" verdict.

---

## Recommended Stack

### Core Technologies (all stdlib / foundation — zero new deps)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `dart:developer` | Dart 3.x stdlib | Primary logging surface (`log`, `Timeline`, `Debugger`, `Flow`) | Emitter into Dart DevTools logging view + performance timeline; carries `level`, `name`, `error`, `stackTrace` natively. No dep, no tree-shake, low cost when no client attached. |
| `dart:async` | Dart 3.x stdlib | `Timer`/`Timer.periodic`, `Stream`/`StreamController`, `Completer` | Diagnostic polling (MemoryMonitor), diagnostic event streams, async race guards (openGeneration). Already used in existing kernel. |
| `dart:io` | Dart 3.x stdlib | `ProcessInfo.currentRss` / `maxRss` (native only) | Sync RSS sampling for MemoryMonitor. Already proven in `lib/kernel/utils/memory_monitor.dart`. Desktop-only (Windows primary) — acceptable per project platform scope. |
| `dart:convert` | Dart 3.x stdlib | `jsonEncode` / `jsonDecode` | Structured-context serialization (error context, log payloads → JSON). Replaces any structured-logging dep. |
| Dart 3 `sealed` classes + pattern matching | Dart 3.0+ stdlib | Closed error hierarchy, state-machine states, exhaustive transitions | Compiler-enforced exhaustiveness = new error/state added → compile error at every switch. No `freezed`, no codegen. |
| `package:flutter/foundation.dart` | Flutter 3.x | `ValueNotifier`, `ChangeNotifier`, `Listenable`, `debugPrint`, `kDebugMode`/`kReleaseMode`, `assert` | Diagnostic state exposure (`ValueNotifier<MemorySnapshot?>`), controlled console logging, compile-time release stripping. Already a transitive dep via fvp/window_manager. |

### Supporting Primitives (stdlib, used by specific capabilities)

| Primitive | Library | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `debugPrint` / `debugPrintSynchronously` | `flutter/foundation` | Console sink for `KernelLogger` (secondary path) | Dev console + `flutter logs`. MUST be guarded for release stripping (see Pitfalls below). |
| `kDebugMode` / `kReleaseMode` / `kProfileMode` | `flutter/foundation` | Compile-time bool constants | Tree-shake debug-only logging branches in release. THE zero-dep release-strip mechanism. |
| `assert(expr)` | Dart 3 stdlib | Release-stripped debug side-effects | `assert(() { debugPrint(...); return true; }())` — canonical debug-only block, fully removed in release. |
| `ValueNotifier<T>` | `flutter/foundation` | Diagnostic state exposure | `MemorySnapshot` exposure to UI / tests via `ValueListenableBuilder`. Already used in existing `MemoryMonitor`. |
| `ChangeNotifier` / `Listenable` | `flutter/foundation` | Multi-listener diagnostic signals | When multiple consumers need notifications without a value (e.g., "metrics refreshed"). |
| `StreamController<T>.broadcast()` | `dart:async` | Diagnostic event bus (optional) | When diagnostics need fan-out beyond a single `ValueNotifier` (e.g., `EngineEventLog` events). |
| `Completer<T>` | `dart:async` | Race guards for async open/seek | openGeneration is int-based today; `Completer` useful for cancelling in-flight ops on generation bump. |
| `Timeline` / `TimelineTask` | `dart:developer` | Performance spans in DevTools timeline | Mark engine open/seek/track-switch durations. Zero-cost when no timeline client attached. |
| `Flow` | `dart:developer` | Async-flow visualization | Cross-isolate/cross-async-step causal chains (optional, defer). |
| `Debugger.inspect` | `dart:developer` | DevTools variable inspection | Debug-only introspection hooks (defer). |

### Development Tools (verification only — not runtime deps)

| Tool | Purpose | Notes |
|------|---------|-------|
| `flutter analyze` | Static exhaustiveness check on sealed switches | Compiler rejects non-exhaustive `switch` on sealed types — run in CI to enforce. |
| `dart test` / `flutter test` | Unit + widget tests for facade/diagnostics | Use `fake_async` (stdlib) for `Timer.periodic` control in MemoryMonitor tests (no `mocktail` needed for timers). |
| Dart DevTools (Logging + Performance tabs) | Verify `dart:developer.log` + `Timeline` emit correctly | Attach via `flutter run` (debug/profile). Confirms facade wiring. |
| `flutter run --release` | Verify release stripping | Confirm `debugPrint`/`assert`-guarded logs produce no console output + no perf cost. |

---

## Capability-by-Capability Primitive Mapping

### Capability 1: Zero-dependency `KernelLogger` facade

**Primitives used:**
- `dart:developer` → `log(String message, {int level, String name, Object? error, StackTrace? stackTrace})` — primary structured emitter (level, logger name/category, error, stack).
- `flutter/foundation` → `debugPrint` (secondary console sink), `kDebugMode` (compile-time guard), `assert` (release strip).
- `dart:convert` → `jsonEncode` for structured context payloads.
- Hand-rolled: `enum KernelLogLevel { debug, info, warning, error, fatal }` + `class KernelLogRecord` (message, level, name, error, stackTrace, context: `Map<String, Object?>`, timestamp).
- Facade shape: `abstract interface class KernelLoggerSink` (swappable) → `DevToolsSink` (default, wraps `dart:developer.log`) + `DebugPrintSink` (guarded) + future `FileSink`/`RemoteSink` (implement same interface, no dep needed — `dart:io File` + `IOSink`).

**WHY zero-dep is viable:**
- `dart:developer.log` already provides the four things a `logger` package adds: leveled logging, named category, error + stackTrace attachment, and emission to a tooling surface (DevTools). A "logger package" would only add file rotation, network shipping, and pretty formatting — none of which v3.0 needs, and all of which the facade defers to swappable sinks built on `dart:io`.
- The facade is ~150-250 lines of pure Dart. Adding `package:logger` would import a dependency for formatting/rotation we can hand-roll in <50 lines *when needed*.

**Integration with existing kernel:**
- Replace ad-hoc `debugPrint('[MemoryMonitor] ...')` calls in `memory_monitor.dart` with `KernelLogger.warning(...)`.
- Replace scattered `debugPrint` in `fvp_engine.dart` / `playback_controller.dart` with `KernelLogger.error(..., error: e, stackTrace: st)`.
- The facade lives at `lib/kernel/diagnostics/kernel_logger.dart` (new `diagnostics/` subdir — kernel-first-class placement, not `utils/`).

### Capability 2: Sealed error model

**Primitives used:**
- Dart 3 `sealed class KernelError` + `final class` subclasses.
- `enum KernelErrorCode { ... }` — stable, documented error codes (the "API contract" callers switch on).
- `StackTrace` (Dart stdlib) — captured via `StackTrace.current` at throw sites.
- Pattern matching: exhaustive `switch` on `KernelError` subtypes; exhaustive `switch` on `KernelErrorCode` for handler dispatch.

**Model shape:**
```dart
sealed class KernelError implements Exception {
  const KernelError({
    required this.code,
    required this.message,
    this.context = const {},
    this.stackTrace,
  });
  final KernelErrorCode code;
  final String message;
  final Map<String, Object?> context;  // structured context — stable contract
  final StackTrace? stackTrace;
}

final class EngineOpenError extends KernelError { ... }
final class StateTransitionError extends KernelError { ... }
final class SeekError extends KernelError { ... }
final class TrackSelectionError extends KernelError { ... }
// ... closed set, compiler-enforced exhaustiveness
```

**WHY zero-dep is viable:**
- Sealed classes + enum + `Map<String, Object?>` are all Dart 3 stdlib. No `freezed`, no `built_value`, no codegen.
- Structured context as `Map<String, Object?>` + `jsonEncode` (dart:convert) gives the same machine-readable payload a structured-logging lib would, without the dep.
- Stable error codes as `enum` give callers a versioned contract — no `error_code` package needed.

**Integration with existing kernel:**
- `MediaEngine` (7-interface composite, `media_engine.dart`) methods declare `throws KernelError` in doc contracts.
- Adapters (Capability 4) translate fvp-native exceptions → `KernelError` subclasses at the anti-corruption boundary.
- `KernelLogger.error(error: kernelError, stackTrace: kernelError.stackTrace)` — errors and logging share the same structured-context shape.

### Capability 3: Injectable / toggleable `MemoryMonitor`

**Primitives used:**
- `dart:async` → `Timer.periodic` (polling), `Timer?.cancel` (toggle off).
- `dart:io` → `ProcessInfo.currentRss` (int), `ProcessInfo.maxRss` (int).
- `flutter/foundation` → `ValueNotifier<MemorySnapshot?>` (diagnostic state exposure to UI/tests).
- Hand-rolled injection seams:
  - `abstract interface class RssProvider { int currentRss(); int maxRss(); }` — default impl wraps `ProcessInfo`; test impl returns scripted values (no `mocktail`).
  - Constructor injection: `MemoryMonitor({required RssProvider rssProvider, required Duration interval})` — replaces the current static singleton (`_instance` in `memory_monitor.dart`).
  - `bool enabled` toggle + `start()`/`stop()` — first-class on/off, does not disturb playback business state (separate `ValueNotifier`, separate `Timer`, never touches `PlaybackController`).

**WHY zero-dep is viable:**
- `ProcessInfo.currentRss` is a sync int getter on `dart:io` — no `process` package, no FFI, no platform plugin. Already proven in the existing singleton implementation (lines 142, 148 of `memory_monitor.dart`).
- `Timer.periodic` + `ValueNotifier` cover polling + reactive exposure — exactly what a `diagnostic` package would provide, built-in.
- Testability via constructor-injected `RssProvider` interface removes the need for `mocktail`/`mockito` — a hand-written `FakeRssProvider implements RssProvider` is ~10 lines.

**Integration with existing kernel:**
- Promote `lib/kernel/utils/memory_monitor.dart` from static singleton to injectable instance, move to `lib/kernel/diagnostics/memory_monitor.dart`.
- Keep the existing `MemorySnapshot` / `MetricSample` data classes (they're already well-shaped, use `dart:convert` for `toJson`).
- Inject `KernelLogger` for threshold-growth warnings (replaces the raw `debugPrint('[MemoryMonitor] RSS growth +...')` at line 158).
- Toggle via a `KernelDiagnostics` composition root that also wires `KernelLogger` + `EngineMetrics` + `EngineEventLog`.

### Capability 4: Anti-corruption adapter layer (compatible replacement)

**Primitives used:**
- Dart 3 `abstract interface class` — the contract type the UI/service layer depends on (the *unchanged* UI→Kernel contract).
- Dart 3 `final class ... implements <Contract>` — concrete adapters wrapping the *old* kernel impl.
- `package:flutter/foundation` → `ValueListenable` / `ChangeNotifier` (the existing reactive contract UI depends on — adapters must expose the same `ValueListenable<...>` surface so UI doesn't change).
- No third-party adapter/DI framework — constructor injection at a single composition root (`app.dart` / a new `KernelComposition`).

**Adapter shape:**
```dart
// The unchanged UI→Kernel contract (preserved from v2.1 MediaEngine composition)
abstract class MediaEngine implements EngineStateView, PlaybackControl, ... {}

// Old-kernel adapter (dual-track period): wraps existing FvpEngine,
// exposes the SAME MediaEngine contract to UI/services.
final class LegacyKernelAdapter implements MediaEngine { ... }

// New-kernel adapter (target): wraps rewritten engine internals.
final class NewKernelAdapter implements MediaEngine { ... }

// Composition root toggles which adapter is wired — no UI/service change.
```

**WHY zero-dep is viable:**
- Adapters are pure Dart interface implementations — the oldest, most dep-free pattern in the language.
- `ValueListenable` is already the project's reactive contract (CLAUDE.md mandates ValueNotifier + ValueListenableBuilder, no Provider/Riverpod/Bloc). Adapters re-expose `ValueNotifier` from the new internals → UI's `ValueListenableBuilder` keeps working unchanged.
- Dual-track toggle = a single `if` at composition root choosing `LegacyKernelAdapter` vs `NewKernelAdapter`. No feature-flag dep.

**Integration with existing kernel:**
- The 7-interface `MediaEngine` composite (`media_engine.dart`) IS the preserved contract. Adapters implement it.
- Migration path: `FvpEngine implements MediaEngine` (current) → extract `LegacyKernelAdapter(FvpEngine)` → introduce `NewKernelAdapter` alongside → flip composition root → delete `LegacyKernelAdapter`. Each step is independently testable.

### Capability 5: Engine abstraction + state machine (continuing v2.1)

**Primitives used:**
- `sealed class PlaybackState` (Dart 3) — the 9 states from v2.1 as a closed hierarchy (or a `sealed class` with `final class` per state carrying transition payload).
- `enum PlaybackEvent` — the ~40 edges as events.
- Exhaustive `switch` on `PlaybackEvent` × `PlaybackState` → next state (compiler enforces all cells).
- `ValueNotifier<PlaybackState>` — state exposure (unchanged from v2.1's `PlaybackStateManager`).
- `int openGeneration` (already v2.1) — stale-async-op guard; optionally paired with `Completer` for cancellation.
- `dart:async` `Timer` — `position_poller.dart` already uses it; state machine consumes its ticks.

**WHY zero-dep is viable:**
- State machines in Dart are idiomatic as `sealed state + switch`. No `state_machine`/`bloc`/`riverpod` package adds anything the stdlib doesn't — sealed exhaustiveness is *stronger* than what most FSM packages enforce (compile-time vs runtime).
- `openGeneration` is an `int` — no dep. `Completer` (dart:async) handles cancel-on-bump if needed.

---

## Installation

**No installation step.** All primitives are stdlib (`dart:developer`, `dart:async`, `dart:io`, `dart:convert`, Dart 3 sealed/pattern) or already-present transitives (`package:flutter/foundation.dart` is pulled in by fvp + window_manager).

Verify availability (one-time, in repo root):
```bash
# Confirm Dart 3 (sealed classes) + flutter foundation are resolvable
flutter --version          # expect Dart >= 3.0
flutter pub deps | grep flutter/foundation   # already a transitive
```

No `pubspec.yaml` change required for any of the five capabilities.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `dart:developer.log` | `package:logger` | Never in v3.0 (hard constraint forbids). Only revisit if/when file rotation + remote shipping are simultaneously required AND a future milestone relaxes the zero-dep rule. |
| `sealed class KernelError` | `package:freezed` sealed unions | Never in v3.0. freezed adds codegen + a dep for what Dart 3 sealed classes do natively. Revisit only if copyWith/ equality boilerplate across >20 error variants becomes painful. |
| Constructor-injected `RssProvider` interface | `package:mocktail`/`mockito` for `ProcessInfo` | Never in v3.0. `ProcessInfo` is static — can't be mocked cleanly anyway. The `RssProvider` seam + a 10-line `FakeRssProvider` is strictly better. |
| `ValueNotifier<MemorySnapshot?>` | `Stream<MemorySnapshot>` (rxdart) | Use `Stream` (stdlib `StreamController.broadcast`) IF multiple non-value consumers emerge. `ValueNotifier` is preferred now because UI already uses `ValueListenableBuilder`. |
| `debugPrint` guarded by `kDebugMode` | `package:logging` (Logger + Logger.root.onRecord) | Never in v3.0. `KernelLogger` facade replicates the `onRecord` listener pattern with a hand-rolled `List<KernelLoggerSink>` — same extensibility, no dep. |
| `assert(() { ...log...; return true; }())` | `if (kDebugMode) { ...log... }` | Both strip in release. Prefer `kDebugMode` (readable, branch tree-shaken); use `assert`-block form only for *side-effect*-heavy debug code that should never even compile into release. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `package:logger` | Violates hard zero-new-dep constraint; adds file/console/remote formatting we can defer to swappable sinks built on `dart:io`. Prior 2026-07-14 STACK listed it as KEEP — that verdict is now retracted. | `KernelLogger` facade over `dart:developer.log` + guarded `debugPrint`. |
| `package:freezed` / `built_value` (for error model) | Codegen + dep for sealed unions + equality — Dart 3 `sealed class` + `final class` gives exhaustiveness natively; `==`/`hashCode` for ~5-10 error variants is trivial hand-rolled. (Note: freezed is already a dep for data classes — that pre-existing use is fine; do NOT add it for the new error model.) | `sealed class KernelError` + `final class` subclasses, hand-rolled `==`/`hashCode` (or skip — errors compared by `code`). |
| `package:logging` | Replaced by `KernelLogger` facade. The `Logger.onRecord` listener bus is replicable with `List<KernelLoggerSink>`. | `KernelLogger` facade + `KernelLoggerSink` interface. |
| `package:mocktail` / `mockito` (for `ProcessInfo`/`Timer`) | `ProcessInfo` is static (un-mockable without reflection); `Timer` is faked by `fake_async` (stdlib). Adds a dep for nothing. | `RssProvider` interface + `FakeRssProvider`; `fake_async` for timers. |
| `package:state_machine` / FSM libs | Sealed-class + exhaustive-switch is compile-time-checked, stronger than runtime FSM libs. Adds a dep for weaker guarantees. | `sealed class PlaybackState` + `switch` expression. |
| `print()` (dart:core) | No throttling, no level, no DevTools integration, not swappable. | `KernelLogger` facade (which may route to `debugPrint`, never raw `print`). |
| Unguarded `debugPrint` in kernel hot paths | `debugPrint` is NOT auto-stripped in release — it stays in the binary and executes (throttled `print` to stdout). Polluting + small perf cost in release. | Guard every `debugPrint` with `if (kDebugMode)` OR route through `KernelLogger` (which guards internally). |
| `window_manager`/platform plugins for RSS | Desktop platform plugins add heavy deps for a one-liner `ProcessInfo.currentRss` already available on dart:io (native). | `ProcessInfo.currentRss` (dart:io, native only — matches project's desktop scope). |

---

## Stack Patterns by Variant

**If running on Windows/macOS/Linux (native desktop — project's scope):**
- Use `dart:io` `ProcessInfo.currentRss` directly.
- Because: sync, zero-dep, already proven in `memory_monitor.dart`.

**If a future milestone adds web support (out of v3.0 scope):**
- Swap `RssProvider` impl to a JS-interop backed one (`dart:js_interop`); `MemoryMonitor` shell unchanged via the injection seam.
- Because: the `RssProvider` interface isolates the only platform-specific primitive.

**If release-build logging is needed (crash reports in the wild):**
- Wire a `FileSink` (dart:io `File` + `IOSink`, size-rotated) into the `KernelLogger` facade behind `if (kReleaseMode)`.
- Because: the facade's swappable-sink design means no third-party crash-reporter dep is required for v3.0; a future Sentry/Datadog integration is one new `KernelLoggerSink` impl.

**If multiple diagnostic consumers need the same event stream:**
- Use `StreamController<DiagnosticEvent>.broadcast()` (dart:async) instead of multiple `ValueNotifier`s.
- Because: stdlib broadcast streams give fan-out without a reactive-framework dep.

---

## Version Compatibility

| Primitive | Compatible With | Notes |
|-----------|-----------------|-------|
| `dart:developer.log` | Dart 2.0+ (stable API) | `level`/`name`/`error`/`stackTrace` params stable for years. Safe. |
| `dart:io ProcessInfo.currentRss` | Native platforms only (Windows/macOS/Linux) | Throws on web. Project is desktop-native → fine. Confirmed already used in repo. |
| `sealed class` / exhaustive `switch` | Dart 3.0+ | Project uses Dart 3 (sealed enums, pattern matching in v2.1 state machine). Safe. |
| `ValueNotifier` / `ChangeNotifier` | Flutter 3.x (stable) | Unchanged API; already used across kernel + UI. |
| `debugPrint` / `kDebugMode` | Flutter 3.x (stable) | `debugPrint` is a `DebugPrintCallback` setter — swappable at runtime. `kDebugMode` is a compile-time `const bool`. |
| `dart:convert jsonEncode` on `Map<String, Object?>` | Dart 2.x+ | Stable. Use for structured context serialization. |

---

## Critical Pitfall (release-build logging elimination — explicit)

**The single most important gotcha for the KernelLogger facade:**

- `debugPrint` is **NOT automatically removed in release builds.** It is a normal function (a swappable `DebugPrintCallback`) that calls `debugPrintSynchronously` → throttled `print` to stdout. In a release build, unguarded `debugPrint` calls **remain in the binary and execute.** The default throttle (`debugPrintThrottleIdleCapacity`) limits flooding but each call still formats a string and writes to stdout.
- **The zero-dep release-strip mechanisms are exactly two:**
  1. `if (kDebugMode) { debugPrint(...); }` — `kDebugMode` is a compile-time `const bool`; the false-branch is tree-shaken in release. **Preferred for the facade's internal guard.**
  2. `assert(() { ...debugPrint or side-effect...; return true; }())` — `assert` is removed entirely in release. Use for debug-only blocks with side effects.
- `dart:developer.log` is also **not stripped** in release, but its cost when no DevTools/service-protocol client is attached is negligible (a structured record allocated + dropped). For a hot-path kernel, still prefer routing through the facade so a future `FileSink`/`RemoteSink` can gate it.
- **Facade rule:** `KernelLogger` methods internally guard the `DebugPrintSink` with `kDebugMode`; the `DevToolsSink` (dart:developer) is left on by default (low cost) but can be disabled via a runtime `level` threshold. This gives three independent knobs: (a) compile-time strip via `kDebugMode`, (b) runtime min-level filter, (c) per-sink enable flag. No dep provides this combination more cheaply.

---

## Gaps & Minimal Hand-Rolled Equivalents

| Gap (stdlib primitive missing) | Minimal hand-rolled equivalent | Effort | Needed in v3.0? |
|--------------------------------|-------------------------------|--------|------------------|
| No stdlib log-level enum | `enum KernelLogLevel { debug, info, warning, error, fatal }` + int mapping for `dart:developer.level` | ~15 lines | Yes |
| No stdlib `LogRecord` carrier | `class KernelLogRecord` (message, level, name, error, stackTrace, context, timestamp) | ~30 lines | Yes |
| No stdlib log file rotation | `FileSink` with size-based rotation (dart:io `File` + `IOSink` + `await file.length()`) | ~60 lines | No (defer to future sink) |
| No stdlib structured-logging format | `Map<String, Object?>` payload + `jsonEncode` (dart:convert) | ~5 lines per record | Yes (error context) |
| No stdlib async-context propagation (like `Logger.withContext`) | Pass `Map<String, Object?> context` explicitly to each `log` call; merge at facade | ~10 lines helper | Yes |
| No stdlib rate-limiting/throttle for `dart:developer.log` | `debugPrint`'s throttle is built-in; for `DevToolsSink` hand-roll a token-bucket if needed | ~25 lines | No (defer unless hot-path noise) |
| No stdlib crash-reporter | `FileSink` writes `KernelLogRecord` JSON lines on `level >= error` | ~40 lines | No (defer; future Sentry = new sink impl) |

Every gap has a sub-100-line hand-rolled equivalent. **No gap forces a third-party dependency for v3.0.**

---

## Sources

- Context7 `/dart-lang/site-www` (Dart docs, HIGH reputation) — verified: Dart 3 sealed classes + exhaustive switch with compiler-enforced error on non-exhaustive branches; `bool.fromEnvironment` compile-time strip pattern; `dart:developer` logging surface.
- Context7 `/websites/api_flutter_dev` (Flutter API, HIGH reputation) — verified: `debugPrint` is a `DebugPrintCallback` getter/setter (swappable, not auto-stripped); `debugPrintSynchronously` is the unthrottled variant; `kDebugMode`/`kReleaseMode` are the compile-time strip constants.
- Context7 `/websites/dart_dev` (Dart dev, HIGH reputation) — verified: `--enable-asserts`/`--observe` run flags; DevTools Logging + Performance tabs as the consumer for `dart:developer.log` + `Timeline`.
- Existing repo source (authoritative, already-integrated): `lib/kernel/utils/memory_monitor.dart` — confirms `ProcessInfo.currentRss` (dart:io) works on the project's Windows target; `ValueNotifier<MemorySnapshot?>` already the exposure pattern; `Timer.periodic` already the polling mechanism.
- Existing repo source: `lib/kernel/engine/media_engine.dart` — confirms the 7-interface `MediaEngine` composite contract to preserve through the anti-corruption adapter layer.
- Project context: `D:\simple_player_flutter\.planning\PROJECT.md` — confirms hard zero-new-dep constraint, compatible-replacement migration strategy, and v2.1 baseline (state machine, openGeneration, MemoryMonitor/EngineMetrics/EngineEventLog 初版).

---
*Stack research for: v3.0 kernel rewrite (compatible replacement + diagnostic-first kernel)*
*Researched: 2026-07-16*
