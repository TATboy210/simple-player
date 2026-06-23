<!-- refreshed: 2026-06-23 -->
# Architecture

**Analysis Date:** 2026-06-23

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          UI Layer (lib/ui/)                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │ player/       │ │ playlist/    │ │ dialogs/     │ │ shared/      │    │
│  │ 15 files      │ │ 4 files      │ │ 10 files     │ │ 18 files     │    │
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
│  │ + 5 helpers          │ │ + 6 components│ │ ThemeService           │     │
│  └──────────┬───────────┘ └─────┬──────┘ │ ThumbnailService        │     │
│             │                   │         │ PathValidator           │     │
│             │                   │         └───────────┬─────────────┘     │
│             │                   │                     │                    │
│  ┌──────────┴──────────┐ ┌─────┴──────┐ ┌───────────┴──────────────┐     │
│  │ models/              │ │ persistence│ │ playlist/                │     │
│  │ 7 immutable classes  │ │ SettingsStore│ │ Playlist (state machine)│     │
│  │                      │ │ PlaylistStore│ │                         │     │
│  └──────────────────────┘ └────────────┘ └──────────────────────────┘     │
│                                                                          │
│  ┌──────────────────────┐ ┌────────────┐ ┌──────────────────────────┐     │
│  │ startup/              │ │ scanner/   │ │ utils/                   │     │
│  │ StartupCoordinator   │ │ FolderScan │ │ log, path, time, perf,  │     │
│  │ StartupState         │ │            │ │ memory, screen           │     │
│  └──────────────────────┘ └────────────┘ └──────────────────────────┘     │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  External: player_engine (abstract) │ fvp/MDK (FFmpeg+D3D11)             │
│  External: window_manager │ shared_preferences │ file_picker             │
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
| `PositionPoller` | Adaptive position polling (250ms normal, 100ms after seek) | `lib/kernel/engine/position_poller.dart` |
| `TrackManager` | Audio/subtitle track selection and switching | `lib/kernel/engine/track_manager.dart` |
| `EnginePrewarm` | Creates+destroys temporary mdk.Player to warm FFmpeg codecs + D3D11 | `lib/kernel/engine/engine_prewarm.dart` |
| `MediaOpener` | Media file open logic extracted from FvpEngine | `lib/kernel/engine/media_opener.dart` |
| `D3D11Configurator` | D3D11 rendering configuration | `lib/kernel/engine/d3d11_configurator.dart` |
| `NetworkConfigurator` | Network stream timeout/probe configuration | `lib/kernel/engine/network_configurator.dart` |
| `SubtitleConfigurator` | Subtitle rendering configuration | `lib/kernel/engine/subtitle_configurator.dart` |
| `VideoEffectController` | Video effect (brightness/contrast/saturation) engine commands | `lib/kernel/engine/video_effect_controller.dart` |
| `VolumeController` | Volume/mute engine commands | `lib/kernel/engine/volume_controller.dart` |
| `WindowService` | Thin coordinator: combines WindowState, FullscreenController, WindowPersistence | `lib/kernel/bridge/window_service.dart` |
| `WindowBridge` | Abstract window management interface (4 state notifiers + 6 commands) | `lib/kernel/bridge/window_bridge.dart` |
| `WindowState` | Pure state container: mode, windowSize, isResizing, isAlwaysOnTop ValueNotifiers | `lib/kernel/bridge/window_state.dart` |
| `FullscreenController` | Atomic fullscreen toggle with mutex guard and rollback on failure | `lib/kernel/bridge/fullscreen_controller.dart` |
| `PlatformFullscreen` | Platform-specific fullscreen abstraction (Win32 FFI) | `lib/kernel/bridge/platform_fullscreen.dart` |
| `Win32PlatformFullscreen` | Win32-specific fullscreen via FFI (WS_THICKFRAME, SetWindowPos) | `lib/kernel/bridge/win32/win32_platform_fullscreen.dart` |
| `WindowPersistence` | Debounced window geometry persistence with write-lock | `lib/kernel/bridge/window_persistence.dart` |
| `DisplayConfig` | Refresh-rate-aware D3D11 sync mode policy | `lib/kernel/bridge/display_config.dart` |
| `PlaybackController` | Unified playback entry point: orchestrates navigator, fileOps, state monitor | `lib/features/player/services/playback_controller.dart` |
| `PlaybackNavigator` | Index-based play: playIndex/playNext/playPrevious with openGeneration guard | `lib/features/player/services/playback_navigator.dart` |
| `FileOperations` | File open/batch add with path validation | `lib/features/player/services/file_operations.dart` |
| `StateMonitor` | Auto-advance on track completion, breakpoint save on pause/dispose | `lib/features/player/services/state_monitor.dart` |
| `SubtitleService` | Auto-detect and load external subtitle files (.srt, .ass, .vtt, etc.) | `lib/features/player/services/subtitle_service.dart` |
| `VideoProcessingService` | Video effects state (brightness/contrast/etc.), diff-based engine sync, 50ms debounce persist | `lib/features/player/services/video_processing_service.dart` |
| `Playlist` | Ordered playlist state machine: add/remove/reorder, 3 play modes, CQS navigation | `lib/kernel/playlist/playlist.dart` |
| `PlaylistItem` | Immutable data model: path, name, timestamp, positionMs, durationMs | `lib/kernel/models/playlist_item.dart` |
| `AppSettings` | Immutable settings data class with copyWith (23 fields) | `lib/kernel/models/app_settings.dart` |
| `SettingsStore` | SharedPreferences persistence with prewarm cache and input sanitization | `lib/kernel/persistence/settings_store.dart` |
| `PlaylistStore` | Playlist JSON persistence with background isolate loading | `lib/kernel/persistence/playlist_store.dart` |
| `PathValidator` | Path security: extension whitelist, path traversal detection, URL validation | `lib/kernel/services/path_validator.dart` |
| `LocaleService` | Global singleton: holds current locale ValueNotifier, auto-persists | `lib/kernel/services/locale_service.dart` |
| `ThemeService` | Global singleton: holds theme index (3 themes), auto-persists | `lib/kernel/services/theme_service.dart` |
| `ThumbnailService` | Platform-aware thumbnail facade with LRU cache (200 entries) | `lib/kernel/services/thumbnail_service.dart` |
| `FolderScanner` | Non-recursive directory scan for video files | `lib/kernel/scanner/folder_scanner.dart` |
| `StartupCoordinator` | Phase-based startup progress tracker, broadcasts via ValueNotifier | `lib/kernel/startup/startup_coordinator.dart` |
| `PlayerScreen` | Main player screen: Stack compositing, keyboard handler, playlist toggle | `lib/ui/player/player_screen.dart` |
| `ControlBar` | Bottom glass control bar: play/pause, seek, volume, speed | `lib/ui/player/control_bar.dart` |
| `ProgressBar` | Seekbar with thumbnail preview on hover | `lib/ui/player/progress_bar.dart` |
| `ControlsOverlay` | Auto-hide control layer (3s fullscreen, 5s windowed) | `lib/ui/player/controls_overlay.dart` |
| `CustomTitleBar` | Frameless window title bar: drag, glass, min/max/close | `lib/ui/window/custom_title_bar.dart` |
| `GlassContainer` | Reusable Glassmorphism wrapper with 3 blur tiers (thin/normal/thick) | `lib/ui/shared/glass_container.dart` |
| `Tokens` | Design tokens: colors, fonts, spacing, radii, animation durations | `lib/ui/theme/tokens.dart` |
| `SettingsPanel` | Tabbed settings dialog: general, audio, video, shortcuts, performance, about | `lib/ui/dialogs/settings_panel.dart` |

## Pattern Overview

**Overall:** Layered architecture with ValueNotifier reactive state management. No Provider/Riverpod/Bloc. Widgets rebuild via `ValueListenableBuilder` wrappers.

**Key Characteristics:**
- 3-layer architecture: Kernel (no UI) -> Features (service orchestration) -> UI (widgets)
- ValueNotifier + ValueListenableBuilder for all reactive state (position, volume, state, etc.)
- Immutable data models with copyWith pattern (AppSettings, PlaylistItem)
- Composition over inheritance: PlaybackController composes 3 sub-modules (Navigator, FileOps, StateMonitor)
- Thin coordinator pattern: WindowService delegates to WindowState + FullscreenController + WindowPersistence
- CQS (Command-Query Separation): Playlist.peekNext() returns index, caller updates state
- Deferred loading: PlayerFeature loaded via `deferred as` to avoid eager FFI imports
- Single design system: all visual values via `Tokens.*` static constants
- Abstract interfaces for testability: WindowBridge, PlatformFullscreen, ThumbnailProvider, WindowOps, PlayerEngine

## Layers

**Kernel Layer:**
- Purpose: Core logic with zero UI dependency. Contains engine, persistence, models, services.
- Location: `lib/kernel/`
- Contains: Engine wrappers (12 files), bridge (9 files), models (7 files), persistence (2 files), playlist (1 file), services (8 files), startup (2 files), utils (6 files), scanner (1 file)
- Depends on: `player_engine` (abstract interface), `fvp` (MDK/FFmpeg), `window_manager`, `shared_preferences`, `path_provider`
- Used by: Features layer

**Features Layer:**
- Purpose: Service orchestration and UI state management. Bridges kernel services to UI widgets.
- Location: `lib/features/`
- Contains: PlayerFeature, PlayerServices, PlaybackController (with 3 sub-modules), VideoProcessingService, SubtitleService
- Depends on: Kernel layer
- Used by: UI layer

**UI Layer:**
- Purpose: Flutter widgets, theming, dialogs. Pure presentation with callbacks.
- Location: `lib/ui/`
- Contains: Player screen (15 files), controls, playlist panel (4 files), settings dialog (10 files), shared glass components (18 files), theme tokens, window title bar
- Depends on: Features layer (via constructor injection), kernel models
- Used by: App shell

## Data Flow

### File Open -> Playback

1. **User triggers file open** via FilePicker/drag-drop in `PlayerFeature._openFile()` (`lib/features/player/player_feature.dart:87`)
2. **PathValidator.validate()** checks extension whitelist + path traversal (`lib/kernel/services/path_validator.dart:90`)
3. **FileOperations.openAndPlay()** adds to Playlist if new, calls navigator (`lib/features/player/services/file_operations.dart:18`)
4. **PlaybackNavigator.playIndex()** guards with openGeneration, validates path again (`lib/features/player/services/playback_navigator.dart:21`)
5. **FvpEngine.open()** calls mdk.Player.open() via FFI, starts PositionPoller (`lib/kernel/engine/fvp_engine.dart`)
6. **Engine state -> MediaState.notifying** triggers UI rebuild via ValueNotifier (`lib/kernel/engine/fvp_engine.dart`)
7. **StateMonitor._onStateChanged()** watches engine.state for auto-advance on completion (`lib/features/player/services/state_monitor.dart:51`)
8. **PlayerScreen** rebuilds via ValueListenableBuilder on engine.state/position/duration (`lib/ui/player/player_screen.dart`)

### State Change Flow (mdk -> UI)

1. mdk fires `onStateChanged` callback (off main thread) (`lib/kernel/engine/fvp_callback_handler.dart`)
2. `FvpCallbackHandler.mapMdkState()` maps to `MediaState` enum
3. `_scheduleOnMain()` uses `SchedulerBinding.addPostFrameCallback` to dispatch to main thread
4. `state.value = mapped` triggers `ValueListenableBuilder` rebuild in UI

### Auto-Advance Flow

1. Engine state changes to `MediaState.completed` -> `StateMonitor._onStateChanged()` (`lib/features/player/services/state_monitor.dart:51`)
2. If `loopSingle` mode: replay same index via `navigator.playIndex(currentIndex)`
3. Otherwise: `navigator.playNext()` -> `Playlist.peekNext()` calculates next index (`lib/kernel/playlist/playlist.dart`)

### Startup Sequence

1. `main()`: `WidgetsFlutterBinding.ensureInitialized()` -> `initLog()` -> `MemoryMonitor.start()` (`lib/main.dart:14`)
2. `SettingsStore.prewarm(prefs)`: Cache SharedPreferences instance before WindowService init (`lib/main.dart:20`)
3. `WindowService.init()`: `windowManager.ensureInitialized()` -> restore geometry -> show window (`lib/kernel/bridge/window_service.dart:68`)
4. `StartupCoordinator`: Reports phases: binding -> infrastructure -> settings -> playerModule -> playerInit -> ready
5. `EnginePrewarm.prewarm()`: Fire-and-forget MDK/FFmpeg codec registration (`lib/kernel/engine/engine_prewarm.dart:42`)
6. `App._init()`: Loads LocaleService + ThemeService in parallel (`lib/app.dart:40`)
7. `DeferredPlayerFeature`: `deferred as` loads PlayerFeature module, creates PlayerServices (`lib/features/player/deferred_player_feature.dart:53`)
8. `PlayerServices.init()`: Creates FvpEngine, Playlist, PlaybackController, loads settings (`lib/features/player/player_services.dart:25`)

**State Management:**
- All playback state: `ValueNotifier` on `FvpEngine` (position, duration, volume, isMuted, state, etc.)
- Window state: `ValueNotifier` on `WindowState` (mode, windowSize, isResizing, isAlwaysOnTop)
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

**WindowBridge:**
- Purpose: Abstract window management interface
- Implementation: `WindowService` implements `WindowBridge` (`lib/kernel/bridge/window_service.dart`)
- Test double: `FakeWindowService` (`test/helpers/fake_window_service.dart`)
- Pattern: 4 ValueNotifier state getters + 6 command methods

**PlatformFullscreen:**
- Purpose: Platform-specific fullscreen operations with snapshot-based rollback
- Implementation: `Win32PlatformFullscreen` (`lib/kernel/bridge/win32/win32_platform_fullscreen.dart`)
- Pattern: enter() returns FullscreenSnapshot for rollback, exit() restores from snapshot

**PlaybackController (Composition Root):**
- Purpose: Unified entry point for all playback operations
- Location: `lib/features/player/services/playback_controller.dart`
- Pattern: Facade composing PlaybackNavigator + FileOperations + StateMonitor
- Sub-modules receive `_rt` (runtime) reference back to controller

**Playlist (Data Model):**
- Purpose: Ordered media list with play mode logic
- Location: `lib/kernel/playlist/playlist.dart`
- Pattern: CQS separation -- `peekNext()`/`peekPrevious()` return index, caller updates state
- Returns `List.unmodifiable` to prevent external mutation

**GlassContainer (Glassmorphism):**
- Purpose: Reusable blur wrapper with 3 tiers (thin/normal/thick)
- Pattern: `BackdropFilter` + `bgGlass` + `borderHighlight`, with opacity-aware skip for GPU optimization
- Files: `lib/ui/shared/glass_container.dart`, `lib/ui/theme/tokens.dart`

## Entry Points

**Application Entry:**
- Location: `lib/main.dart`
- Triggers: `flutter run -d windows`
- Responsibilities: Init bindings, logging, MemoryMonitor, SharedPreferences prewarm, WindowService init, engine prewarm, runApp

**Deferred Player Load:**
- Location: `lib/features/player/deferred_player_feature.dart`
- Triggers: First build after App renders MaterialApp
- Responsibilities: `deferred as` import of PlayerFeature, progress reporting via StartupCoordinator

**Window Commands:**
- Location: `lib/kernel/bridge/window_service.dart`
- Triggers: Keyboard shortcuts (F for fullscreen), title bar buttons, settings
- Responsibilities: Fullscreen toggle, maximize/restore, always-on-top, window geometry persistence

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. mdk callbacks dispatched to main thread via `SchedulerBinding.addPostFrameCallback`. Playlist loading uses `Isolate.run` for file I/O.
- **Global state:** Singleton services (`LocaleService.I`, `ThemeService.I`) hold global ValueNotifiers. `SettingsStore` uses static `_cachedPrefs` for prewarmed SharedPreferences. `ThumbnailService` uses static LRU cache. `EnginePrewarm` uses static flags.
- **No circular imports:** Kernel layer has zero imports from features/UI. Features layer imports kernel only. UI layer imports features and kernel models.
- **Platform coupling:** `WindowService` uses `window_manager` package (cross-platform). `PlatformFullscreen` uses Win32 FFI for atomic fullscreen. `ThumbnailService` selects platform implementation via `defaultTargetPlatform`.
- **ValueNotifier only:** No state management packages (Provider/Riverpod/Bloc). All reactive state via ValueNotifier + ValueListenableBuilder.

## Anti-Patterns

### Callback Drilling

**What happens:** `PlayerScreen` receives 8+ callback parameters (onOpenFile, onTogglePlayMode, onSettings, onSettingsSecondary, onFilesDropped, onDragHoverChanged, onFolderScanned, onClearHistory) passed through from `App` -> `DeferredPlayerFeature` -> `PlayerFeature` -> `PlayerScreen`.

**Why it's wrong:** Deep callback chains make the widget tree hard to read and refactor. Adding a new callback requires touching 4+ files.

**Do this instead:** Consider a shared callback holder object or InheritedWidget for deeply-nested callbacks.

### SettingsStore Static Methods

**What happens:** `SettingsStore` is entirely static methods with a static `_cachedPrefs` instance (`lib/kernel/persistence/settings_store.dart`).

**Why it's wrong:** Static state makes testing harder (must call `resetPrewarm()` between tests). Cannot inject alternative implementations.

**Do this instead:** Consider making `SettingsStore` an injectable instance for better testability, while keeping the static facade for convenience.

### Direct Platform Manager Calls in UI

**What happens:** Calling windowManager.setFullScreen() directly from keyboard handler bypasses mutex and rollback logic.

**Why it's wrong:** No mutex protection, no rollback on failure, no state synchronization.

**Do this instead:** Route through WindowService.setMode() -> FullscreenController.setFullscreen() which provides mutex + rollback.

## Error Handling

**Strategy:** Catch at every level with `debugPrint` + graceful fallback. Never silent `catch (_) {}`. UI shows user-friendly messages, logs contain full context.

**Patterns:**
- `try { ... } on Exception catch (e) { log.e('...'); }` -- standard kernel pattern
- `PathValidator.validate()` returns nullable error string -- null = valid
- `SettingsStore.load()` never throws -- returns safe defaults on any failure
- `PlayerError` structured error class with `PlayerErrorCode` enum for typed errors
- All persistence operations wrapped in try-catch: `SettingsStore.save*()` methods
- PlaybackNavigator.playIndex() catches exceptions, restores old index on failure
- FullscreenController.setFullscreen() uses try/finally mutex, rolls back window state on failure

## Cross-Cutting Concerns

**Logging:** `logger` package with module-scoped loggers (`log`, `logEngine`, `logBridge`). Release mode adds rotating file output to `%APPDATA%\SimplePlayer\logs\`. Defined in `lib/kernel/utils/log.dart`.

**Validation:** `PathValidator` validates all file paths at system boundaries (file open, drag-drop, playlist restore). Extension whitelist + path traversal + URL validation. Located in `lib/kernel/services/path_validator.dart`.

**Localization:** Flutter gen-l10n with ARB files. Chinese (zh) default, English (en) secondary. Generated code in `lib/l10n/`. Locale persisted via `LocaleService` -> `SettingsStore`.

**Theme:** 3 accent themes (Midnight/Ocean/Forest) via `ThemeService`. All visual values from `Tokens.*` constants. Glass-morphism via `GlassContainer` with 3 blur tiers.

---

*Architecture analysis: 2026-06-23*
