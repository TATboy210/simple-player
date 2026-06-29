<!-- refreshed: 2026-06-26 -->

# Architecture

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  UI Layer (lib/ui/)                          8,540 lines / 51   │
│  player/ playlist/ shared/ dialogs/ theme/ window/              │
│  PlayerScreen · ControlBar · PlaylistPanel · SettingsPanel      │
├─────────────────────────────────────────────────────────────────┤
│  Feature Layer (lib/features/)               1,050 lines / 10   │
│  PlayerFeature → PlayerServices (service container)             │
│  PlaybackController → Navigator + FileOps + StateMonitor        │
├─────────────────────────────────────────────────────────────────┤
│  Kernel Layer (lib/kernel/)                  5,150 lines / 49   │
│  engine/    FvpEngine (MDK/FFmpeg + D3D11)                      │
│  bridge/    WindowBridge → WindowService (Win32 window_manager) │
│  playlist/  Playlist model + play mode logic                    │
│  persistence/ SettingsStore + PlaylistStore (SharedPreferences)  │
│  services/  ThemeService, LocaleService, ThumbnailService       │
│  models/    PlaylistItem, PlayMode, AppSettings, MediaState     │
│  startup/   StartupCoordinator + StartupState                   │
│  utils/     log, time, path, screen, memory, perf               │
├─────────────────────────────────────────────────────────────────┤
│  Native / Platform                                                │
│  fvp (MDK + FFmpeg + D3D11) · window_manager · file_picker      │
│  SharedPreferences · path_provider                              │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Patterns

### ValueNotifier / Observer

Primary state management. No Provider, Riverpod, or Bloc.

- `PlayerEngine` exposes `ValueNotifier<int?> textureId`, `state`, `position`, `duration`, `volume`, `isMuted`, `isBuffering`, `aspectRatio`, `playbackSpeed`, `errorMessage`
- `WindowBridge` exposes `ValueNotifier<WindowMode> mode`, `windowSize`, `isResizing`, `isAlwaysOnTop`
- Widgets rebuild via `ValueListenableBuilder` wrappers
- `ValueListenableBuilder2` merges two listenables into one builder
- `MergedListenable` combines multiple notifiers for progress bar

### Abstract Interface / Strategy

`WindowBridge` is the abstract interface; `WindowService` is the Win32 implementation. Tests use `FakeWindowService`. Same pattern for `PlayerEngine` (abstract) / `FvpEngine` (concrete), `PlatformFullscreen` (abstract) / `Win32PlatformFullscreen` (concrete), `ThumbnailProvider` (abstract) / platform-specific implementations.

### Composition / Facade

`PlaybackController` composes three sub-modules:
- `PlaybackNavigator` — index jumps, next/prev, openGeneration guard
- `FileOperations` — open/add files, path validation
- `StateMonitor` — auto-advance on completion, play mode handling

`WindowService` composes `WindowState` + `WindowPersistence`.

### Deferred Loading

`DeferredPlayerFeature` uses `deferred as` to lazy-load the player module, avoiding eager import of heavy FvpEngine types during splash.

### Startup Coordinator

`StartupCoordinator` reports phase/progress via `ValueNotifier<StartupState>`, driving `ProgressSplashScreen` during init. Phases: infrastructure → settings → playerModule → playerInit.

## Data Flow: Main User Actions

### Open File

```
UI (FilePicker / DropHandler)
  → PlayerFeature._openFile() / _onFilesDropped()
    → PlaybackController.openAndPlay(path) / addFiles(paths)
      → PathValidator.validate(path)
      → Playlist.add(path) → PlaylistStore.save()
      → PlaybackNavigator.playIndex(idx)
        → engine.open(path)
        → engine.seekTo(savedPosition)  // resume if > 1s
        → engine.play()
        → playlist.updateHistory()
```

### Play / Pause

```
UI (Space key / ControlBar tap)
  → engine.play() / engine.pause()
    → mdk.Player.play() / pause()
    → FvpCallbackHandler maps mdk state → ValueNotifier<MediaState>
```

### Seek

```
UI (ProgressBar drag / arrow keys)
  → engine.seekTo(ms)
    → mdk.Player.seek(ms)
    → PositionPoller picks up new position on next 250ms tick
```

### Next / Previous

```
UI (N/P keys / ControlBar buttons)
  → PlaybackController.playNext() / playPrevious()
    → Playlist.peekNext() / peekPrevious()  // respects PlayMode
    → PlaybackNavigator.playIndex(targetIndex)
      → engine.open() + engine.play()
```

### Fullscreen

```
UI (F key / title bar button)
  → WindowService.setMode(WindowMode.fullscreen)
    → windowManager.setFullScreen(true)
    → OS callback: onWindowEnterFullScreen
      → WindowState.mode = WindowMode.fullscreen
        → UI rebuilds via ValueListenableBuilder
```

## State Management Approach

All state flows through `ValueNotifier`:
- **Engine state** (12 notifiers): owned by `FvpEngine`, read by UI
- **Window state** (4 notifiers): owned by `WindowState` inside `WindowService`
- **UI state**: `_playlistVisible`, `_isDragHovering`, etc. local to widget state
- **Cross-cutting**: `playlistGeneration` in `PlayerServices` notifies playlist UI changes

No global state container. Services are created in `PlayerServices.init()`, passed down via constructor injection.

## Service Wiring / Dependency Injection

Manual constructor injection — no DI framework.

```
main()
  → WindowService() + SettingsStore.prewarm()
  → StartupCoordinator
  → App(coordinator, windowService)
    → DeferredPlayerFeature(coordinator, windowService)
      → PlayerFeature(coordinator, windowService)
        → PlayerServices(windowService)
          → FvpEngine()
          → Playlist()
          → PlaybackController(engine, playlist, onNeedRebuild)
          → VideoProcessingService(engine)
        → PlayerScreen(engine, controller, playlist, windowService, ...)
```

`App` handles MaterialApp shell + settings panel (needs MaterialApp-level BuildContext). `PlayerFeature` handles player UI state + callbacks. `PlayerServices` is the service container with `init()`/`dispose()` lifecycle.

## Entry Points

| Entry Point | Location | Responsibility |
|-------------|----------|----------------|
| `main()` | `lib/main.dart` | Logging, prewarm, WindowService, StartupCoordinator, EnginePrewarm, runApp |
| `App` | `lib/app.dart` | MaterialApp shell, theme/locale, settings panel, DeferredPlayerFeature |
| `DeferredPlayerFeature` | `lib/features/player/deferred_player_feature.dart` | Lazy-loads PlayerFeature via `deferred as` |
| `PlayerFeature` | `lib/features/player/player_feature.dart` | UI state, file picker, drag-drop, composes PlayerScreen |
| `PlayerServices` | `lib/features/player/player_services.dart` | Service container: engine + playlist + controller lifecycle |

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. MDK/FFmpeg runs on native threads, callbacks dispatched to main isolate via FvpCallbackHandler. Position polling via Timer (250ms normal, 100ms after seek).
- **Global state:** Module-scoped loggers (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`) in `lib/kernel/utils/log.dart`. SettingsStore prewarm cache (`_cachedPrefs`). ThumbnailService singleton cache.
- **Circular imports:** None detected. Kernel does not import Feature/UI. Feature imports Kernel. UI imports Feature and Kernel models.
- **Platform coupling:** Win32-specific code isolated in `lib/kernel/bridge/win32/` and `PlatformFullscreen` interface. `window_manager` package abstracts cross-platform window ops.

## Key Dependencies

| Package | Role |
|---------|------|
| `fvp` | MDK/FFmpeg player engine with D3D11 texture rendering |
| `window_manager` | Cross-platform window control (frameless, fullscreen, bounds) |
| `file_picker` | Native file open dialog |
| `shared_preferences` | Key-value persistence (settings, playlist) |
| `player_engine` | Abstract `PlayerEngine` interface (local imports — path dependency removed in Phase 1) |

---

*Architecture analysis: 2026-06-26*
