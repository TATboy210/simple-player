<!-- refreshed: 2026-05-30 -->
# Architecture

**Analysis Date:** 2026-05-30

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         UI Layer (lib/ui/)                          │
│  player/       playlist/       dialogs/       shared/    widgets/   │
│  PlayerScreen  PlaylistPanel   SettingsPanel  Glass      OsdOverlay │
│  ControlBar    FolderTab       MediaInfo      EmptyState            │
│  ProgressBar   HistoryTab                   AuroraBg               │
│  10 files      4 files         3 files        17 files   1 file    │
├─────────────────────────────────────────────────────────────────────┤
│                    Features Layer (lib/features/)                    │
│  player/                                                              │
│  ├── PlayerFeature          DeferredPlayerFeature   PlayerServices  │
│  └── services/                                                        │
│      PlaybackController → PlaybackNavigator                         │
│                          → FileOperations                           │
│                          → StateMonitor                             │
│      VideoProcessingService    SubtitleService                      │
│  10 files                                                     models/│
├─────────────────────────────────────────────────────────────────────┤
│                      Kernel Layer (lib/kernel/)                      │
│  engine/         bridge/          models/        persistence/        │
│  MediaEngine     WindowService    MediaState     SettingsStore       │
│  FvpEngine       Win32Bindings    PlaylistItem   PlaylistStore       │
│  6 files         2 files          10 files       2 files             │
│  playlist/       services/        scanner/       startup/    utils/  │
│  Playlist        ThumbnailSvc     FolderScanner  Coord.      Log    │
│  1 file          8 files          1 file         2 files     4 files│
└─────────────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌──────────────────────┐    ┌───────────────────────────────────────┐
│  fvp / MDK (plugin)  │    │  window_manager + Win32 FFI / DWM    │
│  FFmpeg + D3D11      │    │  WS_CAPTION / WS_THICKFRAME / DWM    │
└──────────────────────┘    └───────────────────────────────────────┘
```

## Layer Boundaries

| Layer | Import Rule | Purpose |
|-------|------------|---------|
| **Kernel** | No imports from UI or Features | Core logic: engine, models, persistence, utils |
| **Features** | Imports Kernel only | Feature orchestration: services, controllers |
| **UI** | Imports Kernel and Features | Visual components: widgets, dialogs, themes |

**Forbidden directions:**
- Kernel -> UI: never
- Kernel -> Features: never
- Features -> UI: never

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| MediaEngine | Abstract engine interface (13 ValueNotifiers) | `lib/kernel/engine/media_engine.dart` |
| FvpEngine | Concrete fvp/MDK implementation (690 lines) | `lib/kernel/engine/fvp_engine.dart` |
| WindowService | Win32 window management (FFI + DWM) | `lib/kernel/bridge/window_service.dart` |
| PlaybackController | Playback orchestrator (compose 3 sub-modules) | `lib/features/player/services/playback_controller.dart` |
| PlaybackNavigator | Track advancement, open guard (generation) | `lib/features/player/services/playback_navigator.dart` |
| FileOperations | File open/drop, path validation | `lib/features/player/services/file_operations.dart` |
| StateMonitor | Auto-advance, resume, settings restore | `lib/features/player/services/state_monitor.dart` |
| VideoProcessingService | Color/rotation/aspect with copyWith state | `lib/features/player/services/video_processing_service.dart` |
| Playlist | Playlist model + 4 play modes | `lib/kernel/playlist/playlist.dart` |
| SettingsStore | SharedPreferences persistence (439 lines) | `lib/kernel/persistence/settings_store.dart` |
| PlayerServices | Service container (create + lifecycle) | `lib/features/player/player_services.dart` |
| StartupCoordinator | Phase-based startup progress tracking | `lib/kernel/startup/startup_coordinator.dart` |

## Pattern Overview

**Overall:** ValueNotifier-driven reactive architecture without third-party state management

**Key Characteristics:**
- No Provider, Riverpod, or Bloc -- pure `ValueNotifier` + `ValueListenableBuilder`
- Abstract engine interface enables `FakeEngine` for testing
- Composition over inheritance: `PlaybackController` composes 3 sub-modules
- Deferred loading via Dart `deferred as` for the player feature module
- Win32 direct FFI for window control (bypasses MethodChannel for critical paths)

## Layers

### Kernel Layer
- Purpose: Core logic with no UI or feature dependencies
- Location: `lib/kernel/`
- Contains: Engine abstraction, data models, persistence, playlist logic, utilities, startup coordination, window bridge
- Depends on: fvp package, window_manager, shared_preferences, logger
- Used by: Features layer, UI layer

### Features Layer
- Purpose: Feature-specific orchestration and service composition
- Location: `lib/features/`
- Contains: PlaybackController, PlaybackNavigator, FileOperations, StateMonitor, VideoProcessingService, SubtitleService, PlayerFeature widget
- Depends on: Kernel layer (engine, models, persistence, utils)
- Used by: UI layer

### UI Layer
- Purpose: Visual components, theming, dialogs
- Location: `lib/ui/`
- Contains: Player screen widgets, playlist panel, settings dialogs, shared glass widgets, design tokens
- Depends on: Kernel layer (MediaEngine, Playlist, WindowService), Features layer (PlaybackController)
- Used by: App shell (`lib/app.dart`)

## State Management

**Pattern:** ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)

### Engine State Exposure
`MediaEngine` (`lib/kernel/engine/media_engine.dart`) exposes 13 ValueNotifiers:

| Notifier | Type | Purpose |
|----------|------|---------|
| `textureId` | `int?` | D3D11 texture ID for Texture widget |
| `state` | `MediaState` | Playback state enum (idle/loading/playing/paused/error...) |
| `position` | `int` | Current position in ms |
| `duration` | `int` | Total duration in ms |
| `volume` | `double` | Volume 0.0-1.0 |
| `isMuted` | `bool` | Mute state |
| `isBuffering` | `bool` | Buffering indicator |
| `subtitleText` | `String` | Current subtitle text |
| `buffered` | `int` | Buffered amount in ms |
| `aspectRatio` | `double` | Video aspect ratio |
| `errorMessage` | `String?` | Error message (null = no error) |
| `playbackSpeed` | `double` | Playback rate 0.25-4.0 |

### Window State
`WindowService` (`lib/kernel/bridge/window_service.dart`) exposes 4 ValueNotifiers:

| Notifier | Type | Purpose |
|----------|------|---------|
| `isFullscreen` | `bool` | Fullscreen state |
| `isMaximized` | `bool` | Maximized state |
| `isAlwaysOnTop` | `bool` | Always-on-top state |
| `windowSize` | `Size` | Current window size |

### Video Processing State
`VideoProcessingService` (`lib/features/player/services/video_processing_service.dart`):
- Single `ValueNotifier<VideoProcessingState>` holds immutable state
- Each property update uses `copyWith` to generate new state
- 50ms debounce auto-persists to `SettingsStore`

### Utility Widgets
- `ValueListenableBuilder2<A,B>` (`lib/ui/shared/value_listenable_builder2.dart`) -- Dual-notifier builder
- `MergedListenable` (`lib/ui/shared/merged_listenable.dart`) -- Merge two `ValueNotifier<int>`

## Data Flow

### Primary Request Path (User Action -> UI Update)

1. User action (click/key) -- widget callback (`onPlay`, `onSeek`, etc.)
2. `PlaybackController` method (`lib/features/player/services/playback_controller.dart`)
3. Sub-module dispatch (e.g., `PlaybackNavigator.playIndex`)
4. Engine method call (`engine.open()`, `engine.play()`, etc.)
5. ValueNotifier update (state, position, etc.)
6. `ValueListenableBuilder` rebuilds widget

### File Open Flow

1. `FilePicker.pickFiles()` or drag-and-drop (`lib/ui/player/drop_handler.dart`)
2. `FileOperations.openAndPlay(path)` validates via `PathValidator` (`lib/kernel/services/path_validator.dart`)
3. `PlaybackNavigator.playIndex(index)` sets playlist index
4. `engine.open(path)` triggers fvp/MDK load
5. `StateMonitor._onStateChanged()` handles auto-play logic

### Fullscreen Toggle Flow

1. Keyboard `F` or title bar button
2. `WindowService.setFullscreen(bool)` (`lib/kernel/bridge/window_service.dart`)
3. Win32 FFI: save style/frame, set `WS_POPUP`, remove DWM margins
4. `SetWindowPos` to fill monitor
5. `isFullscreen` ValueNotifier update
6. UI rebuilds via `ValueListenableBuilder`

## Key Abstractions

**MediaEngine (Abstract Interface):**
- Purpose: Decouple UI from concrete playback backend
- Location: `lib/kernel/engine/media_engine.dart` (185 lines)
- Pattern: Abstract class with 13 ValueNotifiers + command methods
- Implementations: `FvpEngine` (production), `FakeEngine` (testing at `test/helpers/fake_engine.dart`)

**PlaybackController (Composition Root):**
- Purpose: Unified entry point for all playback operations
- Location: `lib/features/player/services/playback_controller.dart` (119 lines)
- Pattern: Facade composing PlaybackNavigator + FileOperations + StateMonitor
- Sub-modules receive `_rt` (runtime) reference back to controller

**WindowService (FFI Bridge):**
- Purpose: Win32 window management with reactive state
- Location: `lib/kernel/bridge/window_service.dart` (329 lines)
- Pattern: Win32 FFI calls + WindowListener mixin + ValueNotifier state
- Key: Custom maximize uses `rcWork` (work area) to respect taskbar

**Playlist (Data Model):**
- Purpose: Ordered media list with play mode logic
- Location: `lib/kernel/playlist/playlist.dart` (283 lines)
- Pattern: CQS separation -- `next()`/`previous()` return index, caller updates state
- Returns `List.unmodifiable` to prevent external mutation

## Entry Points

**main.dart:**
- Location: `lib/main.dart` (50 lines)
- Triggers: Flutter engine startup
- Responsibilities: Flutter binding init, logging init, window_manager setup, `removeBorderImmediate()` before show, `EnginePrewarm` (fire-and-forget), `SettingsStore.prewarm()`, `StartupCoordinator`, `runApp(App())`

**App (MaterialApp Shell):**
- Location: `lib/app.dart` (219 lines)
- Triggers: `runApp()` from main.dart
- Responsibilities: MaterialApp with theme/locale, `DragToResizeArea` wrapper, `DeferredPlayerFeature` loading, settings panel, right-click quick menu

**PlayerFeature:**
- Location: `lib/features/player/player_feature.dart` (183 lines)
- Triggers: `DeferredPlayerFeature` after `deferred as` load
- Responsibilities: `PlayerServices` init, file picker, drag-drop, play mode toggle, `PlayerScreen` composition

## Architectural Constraints

- **Threading:** Single Dart isolate. MDK callbacks are marshalled to main thread by `FvpCallbackHandler`. `PositionPoller` uses 250ms `Timer` for position updates.
- **Global state:** `SettingsStore._cachedPrefs` (SharedPreferences singleton), `LocaleService.I` (private constructor singleton), `ThemeService.I` (singleton), `log` (global Logger instance), `ThumbnailService._impl` (lazy singleton)
- **Circular imports:** None detected. Layer boundary enforcement prevents cycles.
- **Platform coupling:** Win32-specific code isolated to `lib/kernel/bridge/window_service.dart` and `lib/kernel/bridge/win32_bindings.dart`. Thumbnail providers are platform-dispatched via `ThumbnailService`.

## Anti-Patterns

### Excessive Constructor Parameters (PlayerScreen)

**What happens:** `PlayerScreen` takes 15+ constructor parameters including multiple callbacks
**Why it's wrong:** Difficult to maintain, easy to pass wrong callback
**Do this instead:** Group related callbacks into a configuration object or use `InheritedWidget` for deeply-nested dependencies

### Singleton Services

**What happens:** `LocaleService.I`, `ThemeService.I`, `SettingsStore._cachedPrefs` are module-level singletons
**Why it's wrong:** Makes testing harder, creates hidden global state
**Do this instead:** Accept instances via constructor injection where practical; singletons are acceptable for truly global app-level services

## Error Handling

**Strategy:** Defensive with graceful fallback

**Patterns:**
- `try-catch` with `debugPrint` for non-critical operations (settings load, geometry save)
- `PathValidator.validate()` rejects unsafe paths before playback (`lib/kernel/services/path_validator.dart`)
- `MediaState.error` + `errorMessage` ValueNotifier for engine errors -- UI shows error banner
- `_guardedAction` pattern in `FvpEngine`: checks `_disposed` before every engine call
- `onError` callback chain: sub-modules -> `PlaybackController` -> UI layer
- `ValidationNotifier<String?>` for file operation errors

## Cross-Cutting Concerns

**Logging:** `Logger` package via global `log` instance (`lib/kernel/utils/log.dart`). Debug mode: console only. Release mode: console + rotating file output to `%APPDATA%\SimplePlayer\logs\` (2MB rotation, 5 archives).

**Validation:** `PathValidator` (`lib/kernel/services/path_validator.dart`) validates file paths and URLs before playback. `SettingsStore` sanitizes window geometry (NaN/Infinity/negative protection).

**Localization:** Flutter `gen-l10n` with ARB files (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`). Generated `AppLocalizations` (1022 lines).

**Theming:** Single "Midnight" theme with `Tokens.*` static constants (`lib/ui/theme/tokens.dart`). `ThemeService` manages accent color variants via `ValueNotifier`.

---

*Architecture analysis: 2026-05-30*
