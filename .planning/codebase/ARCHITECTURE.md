<!-- refreshed: 2026-08-21 -->
# Architecture

**Analysis Date:** 2026-08-21

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│                        Composition Root (main.dart)                    │
│  MediaKit.ensureInitialized() · windowManager · StartupCoordinator    │
│  `lib/main.dart` → `lib/app.dart`                                     │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ constructs
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         Feature / View Layer                          │
│  App → DeferredPlayerFeature → PlayerFeature → PlayerScreen          │
│  `lib/features/player/*` · `lib/ui/player/*` · `lib/ui/window/*`     │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ owns + injects
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Service Container (PlayerServices)                  │
│  DI container — creates engine, controller, videoProcessing         │
│  `lib/kernel/player_services.dart`                                    │
└───────┬───────────────────────┬───────────────────────┬────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌──────────────────┐ ┌─────────────────────┐ ┌──────────────────────────┐
│ PlaybackController│ │  MediaKitEngine     │ │ VideoProcessingService  │
│ (Facade)          │ │  (MediaEngine impl) │ │ (stubs — media_kit gaps) │
│ `lib/kernel/      │ │ `lib/kernel/engine/ │ │ `lib/kernel/services/   │
│  services/        │ │  media_kit_engine.  │ │  video_processing_      │
│  playback_        │ │  dart`              │ │  service.dart`          │
│  controller.dart` │ │                     │ │                          │
└────────┬─────────┘ └──────────┬──────────┘ └──────────────────────────┘
         │ delegates             │ wraps Player.stream → ValueNotifier
         ▼                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Window Bridge (WindowService → WindowBridge)             │
│  WindowMode/Resize/Persistence coordinators — native window control  │
│  `lib/kernel/window_Bridge/window_manager_service.dart`              │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ wraps
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│      Platform Native (window_manager + media_kit libmpv FFI)          │
│  Windows runner WM_NCHITTEST · libmpv native player                   │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `main.dart` | Composition root: init MediaKit, windowManager, KernelLogger; construct WindowService + StartupCoordinator; runApp | `lib/main.dart` |
| `App` | MaterialApp shell: fixed dark theme, localization (zh default), splash → player home | `lib/app.dart` |
| `DeferredPlayerFeature` | Dart `deferred as` wrapper: async-loads PlayerFeature module, reports load progress to StartupCoordinator | `lib/features/player/deferred_player_feature.dart` |
| `PlayerFeature` | View layer: owns `PlayerServices` container, manages ready/error UI state, file picker + drop callbacks | `lib/features/player/player_feature.dart` |
| `PlayerScreen` | Main screen: composites CustomTitleBar + video surface + controls inside `Video.controls` builder; keyboard actions | `lib/ui/player/player_screen.dart` |
| `PlayerServices` | DI container: creates and disposes MediaKitEngine, PlaybackController, VideoProcessingService in init order | `lib/kernel/player_services.dart` |
| `PlaybackController` | Facade over `MediaEngine`: openAndPlay (path validate → engine.open → OpenResult dispatch), stop, play/pause contract | `lib/kernel/services/playback_controller.dart` |
| `MediaKitEngine` | Sole `MediaEngine` implementation: wraps media_kit Player, bridges `Player.stream.*` to ValueNotifiers, generation-guarded open | `lib/kernel/engine/media_kit_engine.dart` |
| `EngineStateMachine` | Owns 3 ValueNotifiers (state/isSeeking/isBuffering) + generation counter; stale-callback guard via `transitionTo(..., generation:)` | `lib/kernel/engine/engine_state_machine.dart` |
| `WindowService` | `WindowBridge` impl: thin coordinator delegating to WindowMode/Resize/Persistence sub-coordinators | `lib/kernel/window_Bridge/window_manager_service.dart` |
| `PlayerVideoControls` | Control layer: subscribes to `Player.stream` via PlayerPort; AutoHide, subtitle padding sync, fullscreen toggle | `lib/ui/player/player_video_controls.dart` |
| `StartupCoordinator` | Phase progress tracker: reports phases to ValueNotifier, logs timeline at markReady | `lib/kernel/startup/startup_coordinator.dart` |
| `KernelLoggerImpl` | Build-mode-gated logging facade: debug → DebugPrint+DevTools, profile → DevTools, release → NullSink | `lib/kernel/diagnostics/kernel_logger.dart` |

## Pattern Overview

**Overall:** Layered MVVM with ISP-decomposed engine + Facade controller + DI container + deferred module loading.

**Key Characteristics:**
- **ValueNotifier + ValueListenableBuilder** state management throughout (no Provider/Riverpod/Bloc)
- **ISP-decomposed engine interface**: `MediaEngine` is a composite of 7 `implements` (1 read-only view + 6 control facets)
- **Facade pattern** at `PlaybackController` — UI talks only to the facade, never to `MediaEngine` directly for open/stop
- **Deferred import** for PlayerFeature module to keep libmpv/MediaKitEngine types out of startup hot path
- **Generation-guarded async** — stale open/stop callbacks rejected via embedded generation counter in state machine
- **Coordinator sub-objects** for window service (mode/resize/persistence each serialized independently)
- **Identity-preservation forwarding** — engine getters return the same notifier instances UI listens to (no wrapping)

## Layers

**Composition Root (`lib/main.dart`, `lib/app.dart`):**
- Purpose: bootstrap platform, construct singletons, wire App widget
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: MediaKit.ensureInitialized, windowManager init, KernelLogger.init, StartupCoordinator
- Depends on: WindowService, StartupCoordinator, App
- Used by: Flutter runtime (entry point)

**Feature / View Layer (`lib/features/player/`, `lib/ui/`):**
- Purpose: widget composition, UI state, user interaction callbacks
- Location: `lib/features/player/player_feature.dart`, `lib/ui/player/player_screen.dart`, `lib/ui/player/player_video_controls.dart`, `lib/ui/window/custom_title_bar.dart`
- Contains: StatefulWidget views, keyboard handler, control bar widget tree, OSD, dialogs
- Depends on: PlayerServices (DI), PlaybackController (facade), WindowBridge, Tokens
- Used by: App (MaterialApp home)

**Service Layer (`lib/kernel/services/`, `lib/kernel/player_services.dart`):**
- Purpose: orchestration, runtime state management, file operations
- Location: `lib/kernel/services/playback_controller.dart`, `lib/kernel/player_services.dart`
- Contains: PlaybackController facade, PlaybackStateManager, SubtitleService, TrackPreferenceService, ThumbnailService, PathValidator, InputModeDetector
- Depends on: MediaEngine (interface), not concrete MediaKitEngine
- Used by: PlayerFeature (constructs PlayerServices)

**Engine Layer (`lib/kernel/engine/`):**
- Purpose: media playback abstraction + concrete libmpv implementation
- Location: `lib/kernel/engine/media_engine.dart`, `lib/kernel/engine/media_kit_engine.dart`, `lib/kernel/engine/engine_state_machine.dart`
- Contains: 7 ISP interfaces, EngineStateMachine, OpenResult sealed class, MediaInfo models
- Depends on: media_kit package (Player, VideoController), EngineStateMachine
- Used by: PlayerServices (constructs), PlaybackController (delegates)

**Window Bridge (`lib/kernel/window_Bridge/`):**
- Purpose: native window abstraction (fullscreen/maximize/resize/persistence) decoupled from window_manager package
- Location: `lib/kernel/window_Bridge/window_bridge.dart`, `lib/kernel/window_Bridge/window_manager_service.dart`, `lib/kernel/window_Bridge/window_service_state.dart`
- Contains: WindowBridge interface, WindowService impl, WindowServiceState, 3 coordinators (Mode/Resize/Persistence)
- Depends on: window_manager package, WindowPersistence (shared_preferences)
- Used by: main.dart (constructs), PlayerFeature (injects), PlayerScreen (consumes mode/resize)

**Diagnostics (`lib/kernel/diagnostics/`):**
- Purpose: logging, memory monitoring, resize probes
- Location: `lib/kernel/diagnostics/kernel_logger.dart`, `lib/kernel/diagnostics/memory_monitor.dart`, `lib/kernel/diagnostics/video_texture_resize_probe.dart`
- Contains: KernelLogger facade + sinks, MemoryMonitor, ResizeFrameMetrics, VideoTextureResizeProbe
- Depends on: dart:developer, flutter foundation
- Used by: all layers (via `KernelLogger.I`)

**Persistence (`lib/kernel/persistence/`):**
- Purpose: SharedPreferences-backed storage for window geometry
- Location: `lib/kernel/persistence/window_persistence.dart`, `lib/kernel/persistence/playlist_store.dart`
- Contains: WindowPersistence, PersistedWindowState (validated snapshots)
- Depends on: shared_preferences
- Used by: WindowService (via WindowPersistenceCoordinator)

## Data Flow

### Primary Request Path: Open and Play a File

1. User triggers open (button or `O` key) → `PlayerActions.onOpenFile` → `_openFileWhenReady` gate (`lib/ui/player/player_screen.dart:203`)
2. `FilePickerCoordinator.open()` → `FilePickerMediaGateway` picks path → `_services.controller.openAndPlay(path)` (`lib/features/player/file_picker_coordinator.dart`)
3. `PlaybackController.openAndPlay(path)` validates via `PathValidator.validate(path)` (`lib/kernel/services/playback_controller.dart:171`)
4. `engine.open(path)` → `MediaKitEngine.open` increments generation, transitions to `opening`, awaits `_player.open(Media, play:false)` (`lib/kernel/engine/media_kit_engine.dart:161`)
5. Returns `OpenResult` (sealed: `OpenSuccess` / `OpenError` / `OpenSuperseded`) — controller dispatches side effects only on `OpenSuccess` (`lib/kernel/services/playback_controller.dart:181`)
6. On success: `engine.play()` transitions to `playing`, `currentFileName`/`currentPath` ValueNotifiers update → UI rebuilds via ValueListenableBuilder

### Secondary Flow: Playback State via stream → ValueNotifier

1. media_kit `Player.stream.position/duration/playing/buffering/...` emit events (`lib/kernel/engine/media_kit_engine.dart:508`)
2. `MediaKitEngine._subscribeStreams()` listeners write to owned ValueNotifiers (position/duration/volume/isMuted/subtitleText/buffered/aspectRatio/lastError/playbackSpeed)
3. State-only notifiers (`state`/`isSeeking`/`isBuffering`) are **forwarded** from `EngineStateMachine` (identity preserved — Blocking Constraint #6)
4. UI `ValueListenableBuilder` widgets rebuild on notifier change

**State Management:**
- Single source of truth per notifier; no duplicate state held elsewhere
- `PlayerControlsState` (path B control bar) re-subscribes to `Player.stream` directly for low-latency seek/rate, NOT to engine notifiers — `lib/ui/player/player_video_controls.dart:155`
- Volume/mute writes go through `MediaEngine` (preserves `_preMuteVolume` semantics) — `lib/ui/player/player_video_controls.dart:217`

### Window Mode Flow

1. UI calls `windowService.setMode(WindowMode.fullscreen)` or `syncFullscreenState(bool)` (`lib/ui/player/player_screen.dart:155`)
2. `WindowModeCoordinator.setMode(target)` serializes via `_operation` chain, commits `_state.mode.value` (`lib/kernel/window_Bridge/window_service_state.dart:177`)
3. Fullscreen: media_kit Video route push/pop handled by `PlayerVideoControls._toggleFullscreen` calling `widget.video.toggleFullscreen()` (VideoState) — `lib/ui/player/player_video_controls.dart:398`
4. `WindowPersistenceCoordinator.save()` skips fullscreen snapshots, persists windowed/maximized geometry to SharedPreferences (`lib/kernel/window_Bridge/window_service_state.dart:272`)

## Key Abstractions

**MediaEngine (ISP composite interface):**
- Purpose: unified dependency type for service layer — aggregates 1 read-only + 6 control facets
- Examples: `lib/kernel/engine/media_engine.dart`, 7 facet files in `lib/kernel/engine/`
- Pattern: Interface Segregation Principle — `MediaEngine implements EngineStateView, PlaybackControl, TrackControl, SubtitleConfig, VideoEffectControl, RendererControl, VolumeControl`

**WindowBridge (abstract interface):**
- Purpose: window management abstraction hiding platform window library
- Examples: `lib/kernel/window_Bridge/window_bridge.dart`
- Pattern: Interface + concrete `WindowService implements WindowBridge with WindowListener`; coordinators decompose mode/resize/persistence

**OpenResult (sealed class):**
- Purpose: typed open outcome — success/error/superseded; callers use exhaustive switch
- Examples: `lib/kernel/engine/open_result.dart`
- Pattern: Sealed result type (Dart 3) — controller dispatches side effects only on `OpenSuccess`

**PlayerActions (callback bundle):**
- Purpose: stable, cached action closure set injected into controls builder
- Examples: `lib/ui/player/player_actions.dart`
- Pattern: Plain data class holding `VoidCallback`/typed callbacks; constructed once in `PlayerScreen.initState` to protect Video subtree identity

**ControlBarViewModel (read-only data binding):**
- Purpose: decouple ControlBar from MediaEngine — pass notifiers + callbacks, not engine
- Examples: `lib/ui/player/control_bar_view_model.dart`
- Pattern: Value-object holding `ValueListenable` references + callback closures

**PlayerPort / VideoControlsPort (test ports):**
- Purpose: abstract media_kit `Player` and `VideoState` behind interfaces for headless widget tests
- Examples: `lib/ui/player/media_kit_player_port.dart`, `lib/ui/player/player_video_controls.dart:29-82`
- Pattern: Hexagonal port/adapter — `MediaKitVideoControlsPort` adapts `VideoState`; fakes inject in tests to avoid libmpv FFI

## Entry Points

**`main()` (Dart entry):**
- Location: `lib/main.dart:13`
- Triggers: app launch
- Responsibilities: ensureInitialized (MediaKit, windowManager, KernelLogger), construct WindowService + StartupCoordinator, runApp(App)

**`App` widget:**
- Location: `lib/app.dart:11`
- Triggers: runApp
- Responsibilities: MaterialApp shell, fixed dark theme, zh locale, splash → DeferredPlayerFeature

**`WindowService.onWindowClose()` (native callback):**
- Location: `lib/kernel/window_Bridge/window_manager_service.dart:254`
- Triggers: native window close button
- Responsibilities: persist window state, then destroy native window

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. All ValueNotifier updates from `Player.stream` listeners run on UI isolate. `WindowService._updateOnUIThread` schedules mutations via `SchedulerBinding` when not in idle/post-frame phase (`lib/kernel/window_Bridge/window_manager_service.dart:194`).
- **Global state:** `KernelLoggerImpl._instance` (nullable singleton via `I` accessor, `lib/kernel/diagnostics/kernel_logger.dart:495`); `MemoryMonitor` static instance (`lib/kernel/diagnostics/memory_monitor.dart`); `windowManager` (package-level global).
- **Circular imports:** `EngineStateMachine ↔ MediaKitEngine` circular dependency broken by injecting `onPlay`/`onPause` callbacks after construction (`lib/kernel/engine/engine_state_machine.dart:32`, `lib/kernel/engine/media_kit_engine.dart:50`).
- **Identity preservation (Blocking Constraint #6):** UI ValueListenableBuilder listens to engine's own notifier instances. Wrapping in new notifiers breaks listener attach. `state`/`isSeeking`/`isBuffering` forward from `EngineStateMachine`; `textureId` forwards from `VideoController.id` (`lib/kernel/engine/media_kit_engine.dart:101-123`).
- **Deferred loading:** `player_feature.dart` imported as `deferred as` — MediaKitEngine and heavy types excluded from startup module (`lib/features/player/deferred_player_feature.dart:22`).
- **Borrowed dependency:** `PlayerServices` does NOT dispose `WindowBridge` (borrowed from composition root); only disposes services it created (`lib/kernel/player_services.dart:192`).
- **media_kit immutability:** Never modify media_kit base capabilities. Playback issues handled in project wrapper/UI/tests only (per MEMORY: project_media_kit_immutable).
- **Single-file player (v1.8):** No playlist queue/history/breakpoints/play-modes. `PlaybackController` is a single-file facade; `Playlist`/`PlayMode` legacy code retained but not wired (`lib/kernel/player_services.dart:21`).

## Anti-Patterns

### Stale Async Callback Pollution

**What happens:** Open/seek/stop callbacks race — old open's completion overwrites newer open's state.
**Why it's wrong:** User sees flicker/wrong file state; subtitle detection fires for abandoned file.
**Do this instead:** `EngineStateMachine` embeds generation counter; `transitionTo(next, caller, generation:)` rejects stale writes with `KernelLogger.warn`. `open()` calls `nextGeneration()` and checks `_isCurrentGeneration(gen)` after each await (`lib/kernel/engine/media_kit_engine.dart:180`, `lib/kernel/engine/engine_state_machine.dart:103`).

### Cross-Layer State Duplication

**What happens:** Mirroring engine state in a widget-local flag drifts from source of truth.
**Why it's wrong:** Double-source bugs — `isPlaying` flag desyncs from `MediaState.playing`.
**Do this instead:** `PlayerControlsState.isPlaying` derives from `Player.stream.playing` (subscription), `isMuted` reuses `engine.isMuted` directly (`lib/ui/player/player_video_controls.dart:142`). Never duplicate.

### Subtitle Padding Directed at Wrong VideoState

**What happens:** Old path used window-level `_videoKey.currentState` to set subtitle padding — fullscreen route has a different VideoState instance.
**Why it's wrong:** Padding applied to wrong instance; fullscreen subtitle obscured by control bar.
**Do this instead:** Each `PlayerVideoControls` instance monitors its own `_autoHide.visible` and calls `widget.video.setSubtitleViewPadding` (its own VideoState) (`lib/ui/player/player_video_controls.dart:407-442`).

## Error Handling

**Strategy:** Structured `PlayerError` sealed hierarchy surfaced via `lastError` ValueNotifier + `state → error`; never thrown to callers.

**Patterns:**
- `OpenResult` sealed class: `OpenSuccess(MediaInfo)` / `OpenError(PlayerError)` / `OpenSuperseded()` — exhaustive switch dispatch (`lib/kernel/engine/open_result.dart`)
- `PlayerError` sealed subtypes: `FileError(FileErrorCode)`, `PlaybackError(PlaybackErrorCode)`, `UnknownError` + `ErrorContext` (action/generation/path/module/stackTrace) (`lib/kernel/models/player_error.dart`)
- Engine methods are safe to call from any reachable state — invalid transitions are no-ops, not exceptions (`lib/kernel/engine/playback_control.dart:12`)
- `PlaybackController.openAndPlay` catches validation failure, surfaces via `onError` callback + `validationError` notifier (`lib/kernel/services/playback_controller.dart:175`)
- `WindowService._persistThenDestroy` isolates destroy failures from persistence state (`lib/kernel/window_Bridge/window_manager_service.dart:271`)
- Disposal is idempotent and best-effort: `_disposeSafely` swallows per-resource errors to avoid masking the original init failure (`lib/kernel/player_services.dart:171`)

## Cross-Cutting Concerns

**Logging:** `KernelLogger.I` facade, build-mode-gated. Debug → DebugPrintSink + DevToolsSink (composite); Profile → DevToolsSink only; Release → NullSink (tree-shaken). Path redaction via `redactPath()`. `KernelLoggerImpl.init()` must be called before any kernel access (`lib/kernel/diagnostics/kernel_logger.dart:510`).

**Validation:** Boundary validation at system edges. `PathValidator.validate(path)` guards open flow against path traversal (`lib/kernel/services/path_validator.dart`). `SubtitlePathValidator.isLoadableLocalFile` re-validates file immediately before native load (TOCTOU defense) (`lib/ui/player/player_screen.dart:124`). `WindowPersistence` clamps dimensions to `[minimum, 16384]` and coordinates to `[-100000, 100000]` (`lib/kernel/persistence/window_persistence.dart:45`).

**Authentication:** Not applicable (local desktop media player, no auth).

**Localization:** ARB-based (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`) with generated `AppLocalizations`. Default locale `zh`; `onGenerateTitle` localizes app title. `App.materialLocalizationsDelegates` wired in `lib/app.dart:55`.

**Design System:** Single compile-time const theme "Midnight". All visual values via `Tokens.*` static constants in `lib/ui/theme/tokens.dart`. Glass-morphism pattern: `BackdropFilter` + `bgGlass` + `borderHighlight` via `GlassContainer` (`lib/ui/shared/glass_container.dart`). No hardcoded colors/fonts/spacing.

---

*Architecture analysis: 2026-08-21*
