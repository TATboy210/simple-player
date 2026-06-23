# v2 Architecture

**Analysis Date:** 2026-06-19
**Tools:** CodeGraph + Understand-Anything (4 agents: scanner, architecture-analyzer, file-analyzer, domain-analyzer)

## 7-Layer Architecture

| Layer | Files | Responsibility |
|-------|-------|----------------|
| App Shell | 2 | `main.dart`, `app.dart` — bootstrap, DI wiring, runApp |
| Core | 5 | Types, events, state, models — zero dependencies |
| Infrastructure | 5 | EventBus, mpv FFI, WindowService, AppLogger |
| Feature | 2 | Command handlers (PlayerFeature, WindowFeature) |
| UI | 3 | PlayerScreen, TitleBar, Tokens |
| Test | 4 | Unit tests for data classes and EventBus |
| Config & Docs | 3 | pubspec.yaml, analysis_options.yaml, README.md |

## Dependency Graph (strictly downward)

```
App Shell (main.dart, app.dart)
    │
    ├──→ UI Layer ────→ Core Layer (types, events, state)
    │
    ├──→ Feature Layer ─→ Infrastructure Layer ─→ Core Layer
    │                      (EventBus, mpv, WindowService)
    └──→ Infrastructure Layer
```

**Rule:** Core depends on nothing. Infrastructure depends on Core. Feature depends on Infrastructure + Core. UI depends on Core + EventBus. App Shell is the only module that sees all layers.

## Knowledge Graph (Understand-Anything)

- **37 nodes** — 17 source files, 15 classes, 5 key functions
- **82 edges** — 30 imports, 18 contains, 10 depends_on, 4 calls, 4 tested_by
- **EventBus fan-in = 8** — all modules communicate through single hub

## Data Flow Patterns

### Command Flow (UI → Feature → Infra → mpv)
```
UI widget → bus.fire(PlayerCommand) → PlayerFeature._handleCommand → MpvAdapter.load/play/pause → mpv FFI
```

### Event Flow (mpv → Infra → EventBus → UI)
```
mpv_wait_event → MpvAdapter._handleEvent → bus.fire(PlayerEvent) → UI StreamSubscription → setState
```

### Window Flow (UI → Feature → Infra → Win32)
```
TitleBar tap → bus.fire(WindowCommand) → WindowFeature → WindowService → window_manager → bus.fire(WindowEvent) → UI StreamBuilder
```

## 6 End-to-End Business Flows

| Flow | Steps | Description |
|------|-------|-------------|
| Open & Play Media | 5 | UI OpenCommand → PlayerFeature → MpvAdapter loadfile → mpv fileLoaded → UI state update |
| Playback Control | 4 | Button → PlayerCommand → feature dispatch → mpv property → state propagation |
| Volume & Mute | 3 | Slider/button → SetVolumeCommand → mpv property write → property change event |
| Window Chrome | 4 | TitleBar tap → WindowCommand → WindowFeature → window_manager → WindowEvent |
| MPV Event Polling | 5 | 16ms timer → mpv_wait_event loop → event translation → property change → EventBus |
| App Initialization | 5 | EventBus → mpv FFI init → WindowService init → feature subscriptions → runApp |

## 5 Business Domains

| Domain | Key Classes | Responsibility |
|--------|-------------|----------------|
| Media Playback | MpvAdapter, PlayerFeature, PlaybackState | Playback lifecycle with 8-state machine |
| Window Management | WindowService, WindowFeature | Fullscreen/maximize/pin with animation guards |
| Event Infrastructure | EventBus, sealed class hierarchies | Typed pub-sub, command/event separation |
| MPV FFI Binding | MpvBindings, MpvAdapter | 12 C function pointers, 16ms polling, 5 observed properties |
| UI Presentation | PlayerScreen, TitleBar | StreamSubscription/StreamBuilder reactive state |

## Key Architectural Patterns

1. **EventBus as central nervous system** — `fire()` / `on<T>()` sole communication channel, zero direct coupling between layers
2. **Sealed class hierarchies** — `PlayerEvent` (9+8 subtypes), `WindowCommand` (8), `WindowEvent` (4) — exhaustive pattern matching
3. **Strict layered dependencies** — Core depends on nothing, each layer only sees downward
4. **Single state machine** — `PlaybackState` enum (8 states) prevents boolean flag proliferation
5. **Command/Event separation** — `PlayerCommand extends PlayerEvent` enables unified transport + type-safe dispatch
6. **Platform abstraction** — mpv FFI + window_manager isolate platform code from business logic

## Complexity Hotspots

| File | Lines | Risk |
|------|-------|------|
| `mpv_render_plugin.cpp` | 446 | C++ render pipeline, D3D11 + ANGLE |
| `mpv_adapter.dart` | 221 | FFI memory management, 16ms polling |
| `window_service.dart` | 188 | Win32 callbacks, animation guards |
| `title_bar.dart` | 170 | StreamBuilder composition, hover/press state |

---

*Architecture analysis: 2026-06-19 — CodeGraph + Understand-Anything*
