# ADR-001: ValueNotifier + ValueListenableBuilder as State Management

## Status

**Adopted** (project inception, validated through v1.x, v2.x, and confirmed for v3.0)

## Context

Simple Player Flutter is a desktop media player with real-time playback state (position, volume, play mode, media state) that must update the UI at high frequency (position polls at ~200ms). The project needs a state management solution that:

1. Handles frequent, small state updates (position, volume, buffering status) efficiently.
2. Does not introduce a heavy dependency or framework for a single-screen desktop application.
3. Provides fine-grained rebuild control (only widgets observing a specific notifier rebuild).
4. Is well-understood by the Flutter ecosystem and requires no code generation.
5. Works with `ValueNotifier` fields already exposed by `fvp` engine callbacks.

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **ValueNotifier + ValueListenableBuilder** | Zero deps (stdlib), fine-grained rebuilds, simple mental model, low overhead | No computed/derived state, no devtools integration (standard) | **CHOSEN** |
| Provider / Riverpod | Devtools, dependency scoping, computed state | Adds a framework dependency, heavier abstraction for a single-screen app | REJECTED — overkill for desktop media player |
| Bloc / Cubit | Structured events, predictable transitions | Code generation, boilerplate, event-driven not suitable for continuous stream (position) | REJECTED — event-driven model mismatches continuous state |
| Redux | Time-travel debugging, strict unidirectional flow | Massive boilerplate, action/reducer for every state change | REJECTED — absurdly heavy for this use case |

## Decision

Use **`ValueNotifier<T>` + `ValueListenableBuilder<T>`** as the sole state management pattern. No Provider, Riverpod, Bloc, or any other framework.

Key design rules:

- Every playback state field is a `ValueNotifier<T>` on the engine or service (e.g., `ValueNotifier<MediaState> state`, `ValueNotifier<int> position`, `ValueNotifier<double> volume`).
- Widgets subscribe via `ValueListenableBuilder<T>` or `AnimatedBuilder` (which also listens to `Listenable`).
- Multi-notifier scenarios use `MergedListenable` (combines multiple notifiers) or `ValueListenableBuilder2` (dual-notifier).
- Services hold their own notifiers — no global state container.
- `ValueNotifier<int> playlistGeneration` serves as a lightweight change signal for playlist mutations (avoids deep copy of playlist items).

## Consequences

### Positive

- **Zero framework dependency.** State management uses only `package:flutter/foundation.dart`, which is already a transitive dependency. No additional package to maintain, version-pin, or migrate.
- **Fine-grained rebuilds.** Each `ValueListenableBuilder` only rebuilds when its specific notifier changes. Position updates at 200ms do not trigger rebuilds of the control bar or playlist panel.
- **Simple mental model.** Junior developers can understand `ValueNotifier` without learning event types, reducers, or code generation.
- **Engine alignment.** `fvp` (MDK) exposes state via Dart callbacks that naturally map to `ValueNotifier` assignments. No translation layer needed.
- **Testability.** Tests can directly set `notifier.value` to drive state without dispatching events or setting up a framework context.

### Negative

- **No computed/derived state.** Combining multiple notifiers (e.g., "is the player ready AND has a file loaded?") requires manual `ValueListenableBuilder` composition or a `MergedListenable`. This adds mild boilerplate in `PlayerScreen`.
- **No dependency scoping.** Services are passed via constructor injection (manual DI). There is no `InheritedWidget` or `Provider` scope — `PlayerServices` acts as the composition root.
- **No devtools integration.** Unlike Bloc or Riverpod, there is no dedicated devtools panel for inspecting state transitions. Debugging relies on `debugPrint` and the engine event log.

### Mitigations

- `MergedListenable` and `ValueListenableBuilder2` reduce the boilerplate for multi-notifier scenarios.
- `PlayerServices` as a composition root provides a single site for all dependency wiring.
- `EngineEventLog` (ring buffer of last 100 events) and `EngineMetrics` provide structured observability without a framework devtools plugin.

## Related Decisions

- [ADR-004: Layered Architecture with MVVM-inspired Service Composition](004-layered-architecture.md) — ValueNotifier-based state flows through the layered architecture.
- [ADR-002: fvp/MDK-FFmpeg as Playback Engine](002-fvp-mdk-engine.md) — Engine callbacks map directly to ValueNotifier assignments.

## References

- `lib/kernel/engine/engine_state.dart` — `EngineState` mixin with all `ValueNotifier` playback state fields.
- `lib/kernel/engine/engine_state_view.dart` — Read-only state surface (~12 ValueNotifier getters).
- `lib/kernel/window_bridge/window_service_state.dart` — Window state exposed as `ValueNotifier<WindowMode>`, `ValueNotifier<Size>`, etc.
- `lib/ui/player/player_screen.dart` — Primary consumer, `ValueListenableBuilder` on multiple notifiers.
- `lib/kernel/utils/mergable_listenable.dart` — Combines multiple notifiers for composite rebuild triggers.
- `.planning/codebase/CONVENTIONS.md` — State management section documents the pattern.
- `.planning/PROJECT.md` — Key Decisions table: "ValueNotifier 不变 — 项目已有成熟模式，引入新框架增加复杂度".
