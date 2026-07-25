# ADR-004: Layered Architecture with MVVM-inspired Service Composition

## Status

**Adopted** (evolved through v1.x-v2.x, formalized in Phase 14, preserved for v3.0 kernel rewrite)

## Context

A desktop media player with complex interactions (playback control, window management, playlist management, keyboard shortcuts, auto-hide controls, drag-and-drop) needs an architecture that:

1. Separates UI rendering from business logic (testability, independent evolution).
2. Prevents a "god widget" where `PlayerScreen` holds all state and logic.
3. Enables the engine layer to be rewritten (v3.0) without touching the UI.
4. Supports manual dependency injection without a DI framework.
5. Keeps files small and focused (<500 lines preferred, <800 max).

### Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Layered Architecture (Kernel/Features/UI)** | Clear separation, testable layers, engine abstraction | Mild indirection (services passed via constructors) | **CHOSEN** |
| Feature-first (co-located feature modules) | High cohesion per feature | Cross-feature state (playback affects window, window affects controls) creates coupling between features | REJECTED — features are not independent enough |
| BLoC/Clean Architecture | Strict separation, use cases, entities | Over-engineered for a single-screen desktop player, massive boilerplate | REJECTED — YAGNI |
| Single-file god widget | Simplest, no indirection | Untestable, unmaintainable, 2000+ lines | REJECTED — project has outgrown this |

## Decision

Adopt a **4-layer architecture** with MVVM-inspired service composition:

```
┌─────────────────────────────────────────────────────┐
│  Entry Layer     (main.dart, app.dart)              │
│  Bootstrap, MaterialApp, theme/locale, DI wiring    │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Features Layer  (lib/features/player/)             │
│  PlayerServices (DI), PlaybackController (facade),  │
│  PlaybackNavigator, FileOperations, StateMonitor,   │
│  SubtitleService, VideoProcessingService            │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Kernel Layer    (lib/kernel/)                      │
│  Engine (fvp/MDK), Bridge (Win32), Models,          │
│  Persistence, Playlist, Scanner, Services, Utils    │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  UI Layer        (lib/ui/)                          │
│  PlayerScreen, ControlBar, PlaylistPanel,           │
│  GlassContainer, OSD, Tokens, Dialogs               │
└─────────────────────────────────────────────────────┘
```

### Layer Rules

1. **Entry Layer** (`main.dart`, `app.dart`): Bootstrap only. Initializes Flutter bindings, SharedPreferences, window, engine prewarm, theme/locale. Creates `PlayerServices` (composition root). No business logic.

2. **Features Layer** (`lib/features/player/`): Business logic composition. `PlayerServices` is the DI container (constructor injection). `PlaybackController` is a Facade that unifies `PlaybackNavigator`, `FileOperations`, `PlaybackStateManager`, `AutoAdvancePolicy`. `PlaybackContract` (abstract interface) enables Dependency Inversion for sub-modules.

3. **Kernel Layer** (`lib/kernel/`): Core logic with no UI dependency. Engine abstraction (`MediaEngine`/`FvpEngine`), window bridge (`WindowBridge`/`WindowService`), data models, persistence, playlist, scanner, utilities. v3.0 adds `diagnostics/` and `errors/` subdirectories.

4. **UI Layer** (`lib/ui/`): All visual components. Depends on Features layer (for callbacks) and Kernel layer (for `EngineState` direct read). No business logic — only rendering and user interaction dispatch.

### Key Patterns

| Pattern | Where | Purpose |
|---------|-------|---------|
| **Facade** | `PlaybackController` | Unified entry to navigator + fileOps + stateManager + autoAdvance |
| **Factory** | `DesktopFullscreenDriverFactory` | Platform-specific driver selection |
| **Observer** | `StateMonitor` | Engine state observation: breakpoint save, auto-advance, settings restore |
| **Immutable data + copyWith** | `VideoProcessingState`, `StartupState`, `PlaylistItem` | Immutable state updates with diff-based engine sync |
| **Dependency Inversion** | `PlaybackContract` | Sub-modules depend on abstract interface, not `PlaybackController` concrete |
| **ISP (Interface Segregation)** | `MediaEngine` = 7 interfaces | `EngineStateView` (read-only) + 6 control interfaces, consumers depend only on what they use |
| **Deferred loading** | `DeferredPlayerFeature` | Lazy-loads `PlayerFeature` via `deferred as` to avoid eagerly importing fvp/MDK types |

### Dependency Injection

- **No DI framework.** All injection is manual via constructor parameters.
- `PlayerServices` is the **composition root** for player-related services: creates `FvpEngine`, `Playlist`, `PlaybackController`, `VideoProcessingService`.
- `PlayerFeature` (StatefulWidget) owns `PlayerServices` and passes services down the widget tree via constructor parameters.
- v3.0 adds `DiagnosticsBundle` as a single ctor param for diagnostics injection.

## Consequences

### Positive

- **Engine rewrite without UI changes.** The `MediaEngine` interface decouples the UI from the specific engine implementation. v3.0 kernel rewrite preserves the frozen `MediaEngine` contract; only the backing implementation moves behind a `KernelAdapter`.
- **Testable at every layer.** Kernel layer has no UI dependency — pure Dart unit tests. Features layer tests use `FakeEngine` + `FakeWindowService`. UI layer tests use `FakePlayerServices`.
- **Clear responsibility boundaries.** `PlayerScreen` composes widgets; `PlaybackController` orchestrates services; `FvpEngine` manages the playback engine. No overlap.
- **Small, focused files.** Most files are 100-400 lines. The largest (`fvp_engine.dart` at ~628 lines) is being decomposed in v3.0.
- **Manual DI is simple.** No framework magic, no code generation, no provider scoping rules. `PlayerServices` constructor is the single wiring site.

### Negative

- **Mild indirection.** A UI action (play button) flows: `PlayerScreen` -> `PlaybackController.openAndPlay()` -> `PlaybackNavigator.playIndex()` -> `FvpEngine.open()`. This is 4 hops for a simple action.
- **Features layer dual responsibility.** `PlayerFeature` (283 lines) admits it "simultaneously serves View and some ViewModel responsibilities." This is a legacy debt targeted for extraction.
- **No formal ViewModel layer.** Unlike strict MVVM, there is no explicit `ViewModel` (ChangeNotifier) between View and Services. Services hold `ValueNotifier` state directly. This works but blurs the boundary.
- **DI is manual.** Adding a new service requires updating `PlayerServices` constructor and passing it through the widget tree. No automatic wiring.

### Mitigations

- `PlaybackController` facade reduces the hop count for UI callers — most UI code calls `playbackController.openAndPlay()` without knowing about `PlaybackNavigator` or `FileOperations`.
- v3.0 addresses `PlayerFeature` dual responsibility by further decomposing the orchestrator.
- `PlaybackContract` interface provides Dependency Inversion without a DI framework.
- Constructor injection is explicit and traceable — IDE "Find Usages" shows exactly where each service is wired.

## Related Decisions

- [ADR-001: ValueNotifier State Management](001-value-notifier-state-management.md) — State flows through the layers via ValueNotifier.
- [ADR-002: fvp/MDK Engine](002-fvp-mdk-engine.md) — Engine lives in the Kernel layer.
- [ADR-003: Win32 FFI Window](003-win32-ffi-window.md) — Window bridge lives in the Kernel/Bridge layer.
- [ADR-005: Design System Tokens](005-design-system-tokens.md) — UI layer uses Tokens.* for all visual values.

## References

- `.planning/codebase/ARCHITECTURE.md` — Full architecture documentation with component responsibilities, data flow, pattern overview.
- `.planning/codebase/STRUCTURE.md` — Directory structure.
- `lib/features/player/player_services.dart` — DI composition root.
- `lib/features/player/player_feature.dart` — Feature owner (View + partial ViewModel).
- `lib/features/player/services/playback_controller.dart` — Facade pattern.
- `lib/features/player/services/playback_contract.dart` — Dependency Inversion interface.
- `lib/kernel/engine/media_engine.dart` — 7-ISP composite engine interface.
- `lib/kernel/bridge/window_bridge.dart` — Abstract window management interface.
- `lib/features/player/deferred_player_feature.dart` — Deferred loading.
- `.planning/PROJECT.md` — "内核与 UI 解耦重构 — 允许独立演进，降低回归风险".
- `.planning/research/ARCHITECTURE.md` — v3.0 compatible-replacement adapter architecture.
