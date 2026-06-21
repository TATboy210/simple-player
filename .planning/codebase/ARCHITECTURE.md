<!-- refreshed: 2026-06-21 -->
# Architecture

**Analysis Date:** 2026-06-21

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          UI Layer (lib/ui/)                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │ player/       │ │ playlist/    │ │ dialogs/     │ │ shared/      │    │
│  │ 14 files      │ │ 4 files      │ │ 10 files     │ │ 17 files     │    │
│  │ 2331 lines    │ │ 1135 lines   │ │ 1827 lines   │ │ 2005 lines   │    │
│  └───────┬───────┘ └───────┬──────┘ └───────┬──────┘ └───────┬──────┘    │
│          └─────────────────┴────────────────┴─────────────────┘           │
│                                  │                                        │
│                          ValueListenableBuilder                           │
│                                  │                                        │
├──────────────────────────────────┼────────────────────────────────────────┤
│                   Features Layer (lib/features/)                          │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │ PlayerFeature + DeferredPlayerFeature                             │    │
│  │ ┌─────────────────┐ ┌──────────────┐ ┌──────────────────────┐    │    │
│  │ │PlaybackController│ │VideoProcessing│ │ SubtitleService     │    │    │
│  │ │(3 sub-modules)   │ │ Service       │ │                     │    │    │
│  │ └────────┬──────────┘ └──────┬───────┘ └──────────┬──────────┘    │    │
│  └──────────┼───────────────────┼────────────────────┼───────────────┘    │
│             │                   │                    │                     │
├─────────────┼───────────────────┼────────────────────┼─────────────────────┤
│             │         Kernel Layer (lib/kernel/)     │                     │
│  ┌──────────┴──────────┐ ┌─────┴──────┐ ┌───────────┴──────────────┐     │
│  │ engine/              │ │ bridge/    │ │ services/                │     │
│  │ FvpEngine            │ │ WindowService│ │ LocaleService          │     │
│  │ + helpers (3 files)  │ │ + bootstrap│ │ ThemeService             │     │
│  └──────────┬───────────┘ └─────┬──────┘ │ ThumbnailService        │     │
│             │                   │         │ PathValidator           │     │
│             │                   │         └───────────┬─────────────┘     │
│             │                   │                     │                    │
│  ┌──────────┴──────────┐ ┌─────┴──────┐ ┌───────────┴──────────────┐     │
│  │ models/              │ │ persistence│ │ playlist/                │     │
│  │ 6 immutable classes  │ │ SettingsStore│ │ Playlist (state machine)│     │
│  │                      │ │ PlaylistStore│ │                         │     │
│  └──────────────────────┘ └────────────┘ └──────────────────────────┘     │
│                                                                          │
│  ┌──────────────────────┐ ┌────────────┐ ┌──────────────────────────┐     │
│  │ startup/              │ │ scanner/   │ │ utils/                   │     │
│  │ StartupCoordinator   │ │ FolderScan │ │ log, path, time, perf,  │     │
│  │ StartupState         │ │            │ │ memory                   │     │
│  └──────────────────────┘ └────────────┘ └──────────────────────────┘     │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  External: player_engine (abstract) │ fvp/MDK (FFmpeg+D3D11)             │
│  External: window_manager │ flutter_fullscreen │ shared_preferences      │
└──────────────────────────────────────────────────────────────────────────┘
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
| `main()` | Entry point: init bindings, prefs, window, prewarm engine, runApp | `lib/main.dart` |
| `App` | MaterialApp shell, theme/locale, settings panel wiring | `lib/app.dart` |
| `DeferredPlayerFeature` | Deferred-loading wrapper for PlayerFeature (avoids eager FFI import) | `lib/features/player/deferred_player_feature.dart` |
| `PlayerFeature` | UI state holder: creates PlayerServices, manages drag/file callbacks | `lib/features/player/player_feature.dart` |
| `PlayerServices` | Service container: creates engine, playlist, controller, video processing | `lib/features/player/player_services.dart` |
| `FvpEngine` | fvp/MDK engine wrapper: exposes ValueNotifiers for all playback state | `lib/kernel/engine/fvp_engine.dart` |
| `FvpCallbackHandler` | Maps mdk callbacks to MediaState, schedules on main thread | `lib/kernel/engine/fvp_callback_handler.dart` |
| `PositionPoller` | Timer-based position polling (250ms normal, 100ms after seek) | `lib/kernel/engine/position_poller.dart` |
| `TrackManager` | Audio/subtitle track selection and switching | `lib/kernel/engine/track_manager.dart` |
| `EnginePrewarm` | Creates+destroys temporary mdk.Player to warm FFmpeg codecs + D3D11 | `lib/kernel/engine/engine_prewarm.dart` |
| `WindowService` | Window lifecycle: fullscreen, maximize, resize debounce, geometry persistence | `lib/kernel/bridge/window_service.dart` |
| `DisplayConfig` | Refresh-rate-aware D3D11 sync mode policy | `lib/kernel/bridge/display_config.dart` |
| `WindowBootstrap` | Window position clamping + fullscreen state cleanup | `lib/kernel/bridge/window_bootstrap.dart` |
| `PlaybackController` | Unified playback entry point: orchestrates navigator, fileOps, state monitor | `lib/features/player/services/playback_controller.dart` |
| `PlaybackNavigator` | Index-based play: playIndex/playNext/playPrevious with openGeneration guard | `lib/features/player/services/playback_navigator.dart` |
| `FileOperations` | File open/batch add with path validation | `lib/features/player/services/file_operations.dart` |
| `StateMonitor` | Auto-advance on track completion, breakpoint save on pause/dispose | `lib/features/player/services/state_monitor.dart` |
| `SubtitleService` | Auto-detect and load external subtitle files (.srt, .ass, .vtt, etc.) | `lib/features/player/services/subtitle_service.dart` |
| `VideoProcessingService` | Video effects state (brightness/contrast/etc.), diff-based engine sync, 50ms debounce persist | `lib/features/player/services/video_processing_service.dart` |
| `Playlist` | Ordered playlist state machine: add/remove/reorder, 3 play modes, CQS navigation | `lib/kernel/playlist/playlist.dart` |
| `SettingsStore` | SharedPreferences persistence with input sanitization (NaN/Infinity protection) | `lib/kernel/persistence/settings_store.dart` |
| `PlaylistStore` | JSON playlist persistence: 300ms debounce, atomic write (.tmp+rename), retry with backoff | `lib/kernel/persistence/playlist_store.dart` |
| `PathValidator` | Path security: extension whitelist, path traversal detection, URL validation | `lib/kernel/services/path_validator.dart` |
| `LocaleService` | Global singleton: holds current locale, auto-persists | `lib/kernel/services/locale_service.dart` |
| `ThemeService` | Global singleton: holds theme index (3 themes), auto-persists | `lib/kernel/services/theme_service.dart` |
| `ThumbnailService` | Platform-aware thumbnail facade with LRU cache (200 entries) | `lib/kernel/services/thumbnail_service.dart` |
| `FolderScanner` | Non-recursive directory scan for video files | `lib/kernel/scanner/folder_scanner.dart` |
| `StartupCoordinator` | Phase-based startup tracking with ValueNotifier<StartupState> | `lib/kernel/startup/startup_coordinator.dart` |
| `PlayerScreen` | Main player screen: Stack compositing, keyboard handler, playlist toggle | `lib/ui/player/player_screen.dart` |
| `ControlBar` | Bottom glass control bar: play/pause, seek, volume, speed | `lib/ui/player/control_bar.dart` |
| `ProgressBar` | Seekbar with thumbnail preview on hover | `lib/ui/player/progress_bar.dart` |
| `ControlsOverlay` | Auto-hide control layer (3s fullscreen, 5s windowed) | `lib/ui/player/controls_overlay.dart` |
| `CustomTitleBar` | Frameless window title bar: drag, glass, min/max/close | `lib/ui/player/custom_title_bar.dart` |
| `GlassContainer` | Reusable Glassmorphism wrapper with 3 blur tiers (thin/normal/thick) | `lib/ui/shared/glass_container.dart` |
| `Tokens` | Design tokens: colors, fonts, spacing, radii, animation durations | `lib/ui/theme/tokens.dart` |
| `SettingsPanel` | Tabbed settings dialog: general, audio, video, shortcuts, performance, about | `lib/ui/dialogs/settings_panel.dart` |

## Pattern Overview

**Overall:** Layered architecture with ValueNotifier reactive state management. No Provider/Riverpod/Bloc. Widgets rebuild via `ValueListenableBuilder` wrappers.

**Key Characteristics:**
- 3-layer architecture: Kernel (no UI) -> Features (service orchestration) -> UI (widgets)
- ValueNotifier + ValueListenableBuilder for all reactive state (position, volume, state, etc.)
- Immutable data models with copyWith pattern (AppSettings, VideoProcessingState, PlaylistItem)
- Composition over inheritance: PlaybackController composes 3 sub-modules
- Deferred loading: PlayerFeature loaded via `deferred as` to avoid eager FFI imports
- Single design system: all visual values via `Tokens.*` static constants
- Abstract engine interface (`PlayerEngine` from `player_engine` package) enables `FakeEngine` for testing

## Layers

**Kernel Layer:**
- Purpose: Core logic with zero UI dependency. Contains engine, persistence, models, services.
- Location: `lib/kernel/`
- Contains: Engine wrappers, bridge, models, persistence, playlist state machine, services, utilities
- Depends on: `player_engine` (abstract interface), `fvp` (MDK/FFmpeg), `window_manager`, `shared_preferences`, `path_provider`
- Used by: Features layer

**Features Layer:**
- Purpose: Service orchestration and UI state management. Bridges kernel services to UI widgets.
- Location: `lib/features/`
- Contains: PlayerFeature, PlayerServices, PlaybackController (with 3 sub-modules), VideoProcessingService
- Depends on: Kernel layer
- Used by: UI layer

**UI Layer:**
- Purpose: Flutter widgets, theming, dialogs. Pure presentation with callbacks.
- Location: `lib/ui/`
- Contains: Player screen, controls, playlist panel, settings dialog, shared glass components
- Depends on: Features layer (via constructor injection), kernel models
- Used by: App shell

## Data Flow

### Primary Playback Path

1. User opens file via FilePicker/drag-drop -> `PlayerFeature._openFile()` / `_onFilesDropped()` (`lib/features/player/player_feature.dart:87-118`)
2. `FileOperations.openAndPlay()` validates path via `PathValidator.validate()` (`lib/features/player/services/file_operations.dart:18-38`)
3. `PlaybackNavigator.playIndex()` sets playlist index, opens engine (`lib/features/player/services/playback_navigator.dart:22-69`)
4. `FvpEngine.open()` creates mdk.Player, calls `prepare()` + `updateTexture()` (`lib/kernel/engine/fvp_engine.dart:226-378`)
5. `FvpEngine.play()` sets mdk state to playing, starts `PositionPoller` (`lib/kernel/engine/fvp_engine.dart:381-393`)
6. `PositionPoller._poll()` updates `position` ValueNotifier every 250ms (`lib/kernel/engine/position_poller.dart:104-118`)
7. UI rebuilds via `ValueListenableBuilder` on engine's ValueNotifiers

### State Change Flow (mdk -> UI)

1. mdk fires `onStateChanged` callback (off main thread) (`lib/kernel/engine/fvp_callback_handler.dart:35-42`)
2. `FvpCallbackHandler.mapMdkState()` maps to `MediaState` enum (`lib/kernel/engine/fvp_callback_handler.dart:91-98`)
3. `_scheduleOnMain()` uses `SchedulerBinding.addPostFrameCallback` to dispatch to main thread (`lib/kernel/engine/fvp_callback_handler.dart:82-84`)
4. `state.value = mapped` triggers `ValueListenableBuilder` rebuild in UI (`lib/kernel/engine/fvp_callback_handler.dart:39`)

### Settings Persistence Flow

1. User changes setting in `SettingsPanel` (`lib/ui/dialogs/settings_panel.dart`)
2. `SettingsStore.save*()` writes to `SharedPreferences` with try-catch (`lib/kernel/persistence/settings_store.dart`)
3. On next launch, `SettingsStore.load()` restores all settings with input sanitization (`lib/kernel/persistence/settings_store.dart:86-180`)

### Auto-Advance Flow

1. Engine state changes to `MediaState.completed` -> `StateMonitor._onStateChanged()` (`lib/features/player/services/state_monitor.dart:51-84`)
2. If `loopSingle` mode: replay same index via `navigator.playIndex(currentIndex)`
3. Otherwise: `navigator.playNext()` -> `Playlist.peekNext()` calculates next index (`lib/kernel/playlist/playlist.dart:198-214`)

### Startup Flow

1. `main()`: init bindings, FullScreen, logging, MemoryMonitor, SettingsStore.prewarm, WindowService.init (`lib/main.dart:14-42`)
2. `StartupCoordinator` tracks phases: binding -> infrastructure -> settings -> playerModule -> playerInit -> ready (`lib/kernel/startup/startup_coordinator.dart`)
3. `EnginePrewarm.prewarm()` fire-and-forget: creates+destroys temp mdk.Player to warm FFmpeg+D3D11 (`lib/kernel/engine/engine_prewarm.dart`)
4. `App._init()`: parallel load of LocaleService + ThemeService (`lib/app.dart:40-53`)
5. `DeferredPlayerFeature._loadLibrary()`: deferred import of PlayerFeature (`lib/features/player/deferred_player_feature.dart:53-75`)
6. `PlayerFeature._init()`: creates PlayerServices, inits engine+playlist+controller (`lib/features/player/player_feature.dart:64-85`)

**State Management:**
- All playback state: `ValueNotifier` on `FvpEngine` (position, duration, volume, isMuted, state, etc.)
- Window state: `ValueNotifier` on `WindowService` (isFullscreen, isMaximized, windowSize)
- Video processing: single `ValueNotifier<VideoProcessingState>` with immutable copyWith
- Startup: `ValueNotifier<StartupState>` on `StartupCoordinator`
- Locale/Theme: `ValueNotifier` on singleton services (`LocaleService.I.locale`, `ThemeService.I.themeIndex`)
- Playlist generation: `ValueNotifier<int>` on `PlayerServices.playlistGeneration` (incremented on change)

## Key Abstractions

**PlayerEngine (abstract, from `player_engine` package):**
- Purpose: Abstract engine interface defined in external `player_engine` package
- Implementation: `FvpEngine` extends `PlayerEngine` (`lib/kernel/engine/fvp_engine.dart`)
- Pattern: Exposes ValueNotifiers for all state, methods for control (play/pause/seek/volume)
- Other code depends on `PlayerEngine` (abstract), not `FvpEngine` (concrete)

**ValueNotifier-based Reactive UI:**
- Purpose: Lightweight state management without external dependencies
- Pattern: Engine/services hold ValueNotifiers, UI uses `ValueListenableBuilder` to rebuild
- Helpers: `ValueListenableBuilder2` (dual notifier), `MergedListenable` (merge 2 int notifiers)
- Files: `lib/ui/shared/value_listenable_builder2.dart`, `lib/ui/shared/merged_listenable.dart`

**GlassContainer (Glassmorphism):**
- Purpose: Reusable blur wrapper with 3 tiers (thin/normal/thick)
- Pattern: `BackdropFilter` + `bgGlass` + `borderHighlight`, with opacity-aware skip for GPU optimization
- Files: `lib/ui/shared/glass_container.dart`, `lib/ui/theme/tokens.dart`

**PlaybackController (Composition Root):**
- Purpose: Unified entry point for all playback operations
- Location: `lib/features/player/services/playback_controller.dart` (119 lines)
- Pattern: Facade composing PlaybackNavigator + FileOperations + StateMonitor
- Sub-modules receive `_rt` (runtime) reference back to controller

**Playlist (Data Model):**
- Purpose: Ordered media list with play mode logic
- Location: `lib/kernel/playlist/playlist.dart` (283 lines)
- Pattern: CQS separation -- `peekNext()`/`peekPrevious()` return index, caller updates state
- Returns `List.unmodifiable` to prevent external mutation

## Entry Points

**Application Entry:**
- Location: `lib/main.dart`
- Triggers: `flutter run -d windows`
- Responsibilities: Init bindings, FullScreen, logging, SharedPreferences prewarm, WindowService init, engine prewarm, runApp

**Deferred Player Load:**
- Location: `lib/features/player/deferred_player_feature.dart`
- Triggers: First build after App renders MaterialApp
- Responsibilities: `deferred as` import of PlayerFeature, progress reporting via StartupCoordinator

**Window Commands:**
- Location: `lib/kernel/bridge/window_service.dart`
- Triggers: Keyboard shortcuts (F for fullscreen), title bar buttons, settings
- Responsibilities: Fullscreen toggle, maximize/restore, always-on-top, window geometry persistence

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. mdk callbacks dispatched to main thread via `SchedulerBinding.addPostFrameCallback` (`lib/kernel/engine/fvp_callback_handler.dart:82-84`). Playlist loading uses `Isolate.run` for file I/O (`lib/kernel/persistence/playlist_store.dart:122-132`).
- **Global state:** Singleton services (`LocaleService.I`, `ThemeService.I`) hold global ValueNotifiers. `SettingsStore` uses static `_cachedPrefs` for prewarmed SharedPreferences. `ThumbnailService` uses static LRU cache. `EnginePrewarm` uses static flags.
- **No circular imports:** Kernel layer has zero imports from features/UI. Features layer imports kernel only. UI layer imports features and kernel models.
- **Platform coupling:** `WindowService` uses `window_manager` package (cross-platform). `ThumbnailService` selects platform implementation via `defaultTargetPlatform`. FFI bridge is `window_manager`-based (no direct Win32 FFI in current codebase).

## Anti-Patterns

### Callback Drilling

**What happens:** `PlayerScreen` receives 8+ callback parameters (onOpenFile, onTogglePlayMode, onSettings, onSettingsSecondary, onFilesDropped, onDragHoverChanged, onFolderScanned, onClearHistory) passed through from `App` -> `DeferredPlayerFeature` -> `PlayerFeature` -> `PlayerScreen`.

**Why it's wrong:** Deep callback chains make the widget tree hard to read and refactor. Adding a new callback requires touching 4+ files.

**Do this instead:** Consider a shared callback holder object or InheritedWidget for deeply-nested callbacks.

### SettingsStore Static Methods

**What happens:** `SettingsStore` is entirely static methods with a static `_cachedPrefs` instance (`lib/kernel/persistence/settings_store.dart`).

**Why it's wrong:** Static state makes testing harder (must call `resetPrewarm()` between tests). Cannot inject alternative implementations.

**Do this instead:** Consider making `SettingsStore` an injectable instance for better testability, while keeping the static facade for convenience.

### Excessive Constructor Parameters (PlayerScreen)

**What happens:** `PlayerScreen` takes 15+ constructor parameters including multiple callbacks (`lib/ui/player/player_screen.dart:24-65`).

**Why it's wrong:** Difficult to maintain, easy to pass wrong callback.

**Do this instead:** Group related callbacks into a configuration object or use `InheritedWidget` for deeply-nested dependencies.

## Error Handling

**Strategy:** Catch at every level with `debugPrint` + graceful fallback. Never silent `catch (_) {}`. UI shows user-friendly messages, logs contain full context.

**Patterns:**
- `try { ... } on Exception catch (e) { log.e('...'); }` -- standard kernel pattern
- `_guardedAction(name, action)` in FvpEngine -- wraps action with disposed check + try-catch + error message (`lib/kernel/engine/fvp_engine.dart:212-221`)
- `PathValidator.validate()` returns nullable error string -- null = valid (`lib/kernel/services/path_validator.dart:90-109`)
- `SettingsStore.load()` never throws -- returns safe defaults on any failure (`lib/kernel/persistence/settings_store.dart:86-180`)
- `PlayerError` structured error class with `PlayerErrorCode` enum for typed errors (`lib/kernel/models/player_error.dart`)

## Cross-Cutting Concerns

**Logging:** `logger` package with module-scoped loggers (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`). Release mode adds rotating file output to `%APPDATA%\SimplePlayer\logs\`. Defined in `lib/kernel/utils/log.dart`.

**Validation:** `PathValidator` validates all file paths at system boundaries (file open, drag-drop, playlist restore). Extension whitelist + path traversal + URL validation. Located in `lib/kernel/services/path_validator.dart`.

**Localization:** Flutter gen-l10n with ARB files. Chinese (zh) default, English (en) secondary. Generated code in `lib/l10n/`. Locale persisted via `LocaleService` -> `SettingsStore`.

**Theme:** 3 accent themes (Midnight/Ocean/Forest) via `ThemeService`. All visual values from `Tokens.*` constants. Glass-morphism via `GlassContainer` with 3 blur tiers.

---

*Architecture analysis: 2026-06-21*
