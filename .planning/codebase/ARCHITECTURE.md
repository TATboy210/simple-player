# Architecture

**Analysis Date:** 2026-05-28

## Layer Overview

```
┌─────────────────────────────────────────┐
│  UI Layer (lib/ui/)                     │
│  Player screen, controls, playlist,     │
│  dialogs, shared glass widgets          │
├─────────────────────────────────────────┤
│  Features Layer (lib/features/)         │
│  Player feature, services, models       │
├─────────────────────────────────────────┤
│  Kernel Layer (lib/kernel/)             │
│  Engine, models, persistence, utils,    │
│  playlist, scanner, startup             │
└─────────────────────────────────────────┘
```

**Previous:** 4-layer (Kernel/Bridge/Native/Window)
**Current:** 3-layer (Kernel/Features/UI) — simplified after window layer removal

## State Management

**Pattern:** ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)

```
Engine (ValueNotifiers) → ValueListenableBuilder → Widget rebuild
```

### Engine State
`MediaEngine` exposes 10+ ValueNotifiers:
- `state` (MediaState enum)
- `position`, `duration` (milliseconds)
- `volume`, `isMuted`
- `buffering`, `errorMessage`
- `audioTracks`, `subtitleTracks`

### Utility Widgets
- `ValueListenableBuilder2<A,B>` — Dual-notifier builder
- `MergedListenable` — Merge two `ValueNotifier<int>`
- `Listenable.merge([...])` — Combine multiple notifiers

## Engine Abstraction

```
MediaEngine (abstract) ← lib/kernel/engine/media_engine.dart
    │
    └── FvpEngine (concrete) ← lib/kernel/engine/fvp_engine.dart
            │
            └── fvp plugin → MDK → D3D11
```

- Abstract interface enables `FakeEngine` for testing
- `FvpEngine` wraps fvp/MDK with `_guardedAction` error handling
- 10+ ValueNotifiers for reactive state binding

## Service Layer

### PlaybackController (Orchestrator)
**File:** `lib/features/player/services/playback_controller.dart`

Composes 3 sub-modules:
- `PlaybackNavigator` — Track advancement logic
- `FileOperations` — File open/drop handling
- `StateMonitor` — State change monitoring

### Additional Services
- `VideoProcessingService` — Color correction, rotation
- `SubtitleService` — External subtitle loading
- `ThumbnailService` — Platform thumbnail extraction
- `PathValidator` — Path validation (URL + local)
- `LocaleService` / `ThemeService` — App preferences (singletons)

## Data Flow

```
User Action (click/key)
    │
    ▼
Widget callback (onPlay, onSeek, etc.)
    │
    ▼
PlaybackController method
    │
    ▼
Engine method (play, seekTo, etc.)
    │
    ▼
ValueNotifier update (state, position, etc.)
    │
    ▼
ValueListenableBuilder rebuilds widget
```

## Key Design Patterns

| Pattern | Where | Why |
|---------|-------|-----|
| Abstract Interface | `MediaEngine` | Enables FakeEngine testing |
| Composition | `PlaybackController` | Separates concerns |
| ValueNotifier | Engine, Services | Reactive UI without framework |
| Singleton | `LocaleService`, `SettingsStore` | Global access, lazy init |
| Deferred Loading | `DeferredPlayerFeature` | Startup performance |
| Phase-based Init | `StartupCoordinator` | Ordered initialization |
| `_guardedAction` | `FvpEngine` | Disposed-safe error handling |

## Cross-Layer Dependencies

```
UI → Features → Kernel (allowed)
Kernel → UI (forbidden)
Features → UI (forbidden)
```

- UI imports kernel and features
- Features imports kernel only
- Kernel has no UI or features imports
