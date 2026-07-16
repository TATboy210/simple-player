> ⚠️ **v2.1 前快照（2026-07-12）** — 此文档描述 v2.1 重构前结构，Phase 15+ 一律对 LIVE code + codegraph 核对，勿信本快照具体路径/类名。保留作演进历史。

<!-- refreshed: 2026-07-12 -->
# Architecture

**Analysis Date:** 2026-07-12

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Entry Points                                │
│  `lib/main.dart`  →  `lib/app.dart`  →  `DeferredPlayerFeature`    │
└──────────────┬──────────────────────────────┬───────────────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────┐  ┌──────────────────────────────────┐
│       Kernel Layer           │  │        Features Layer            │
│   `lib/kernel/`              │  │   `lib/features/player/`         │
│                              │  │                                  │
│  ┌─────────┐  ┌──────────┐  │  │  ┌──────────────────────┐        │
│  │ Engine  │  │ Bridge   │  │  │  │  PlayerServices (DI) │        │
│  │ (fvp)   │  │ (Win32)  │  │  │  └──────────┬───────────┘        │
│  └────┬────┘  └────┬─────┘  │  │             │                    │
│       │            │         │  │  ┌──────────▼───────────┐        │
│  ┌────▼────┐  ┌────▼─────┐  │  │  │ PlaybackController   │        │
│  │ Models  │  │ Persist  │  │  │  │ (Facade pattern)     │        │
│  └─────────┘  └──────────┘  │  │  └──────────┬───────────┘        │
│  ┌────────────────────────┐  │  │             │                    │
│  │    Services / Utils    │  │  │  ┌──────────▼───────────┐        │
│  └────────────────────────┘  │  │  │ Navigator / FileOps  │        │
│                              │  │  │ / StateMonitor / Sub │        │
└──────────────────────────────┘  │  └──────────────────────┘        │
               │                  └──────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                           UI Layer                                   │
│                       `lib/ui/`                                      │
│                                                                      │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌──────────┐ ┌─────────┐ │
│  │  Player  │ │ Playlist │ │  Shared    │ │ Widgets  │ │ Dialogs │ │
│  │  Screen  │ │  Panel   │ │  (Glass)   │ │  (OSD)   │ │(Settings)│ │
│  └──────────┘ └──────────┘ └────────────┘ └──────────┘ └─────────┘ │
│                     `lib/ui/theme/tokens.dart` (Design Tokens)       │
└──────────────────────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Platform Layer (Native)                           │
│  `windows/` (Win32 FFI)  │  `macos/`  │  `linux/`                   │
│  user32.dll, D3D11        │  Swift/C++ │  GTK                         │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `main()` | Bootstrap: prefs, window, engine prewarm, run app | `lib/main.dart` |
| `App` | MaterialApp shell, theme/locale, settings panel | `lib/app.dart` |
| `DeferredPlayerFeature` | Lazy-load PlayerFeature via `deferred as` | `lib/features/player/deferred_player_feature.dart` |
| `PlayerFeature` | DI container owner, UI state, PlayerScreen composition | `lib/features/player/player_feature.dart` |
| `PlayerServices` | DI container: engine + playlist + controller + videoProcessing | `lib/features/player/player_services.dart` |
| `PlaybackController` | Facade: orchestrates engine + playlist via sub-modules | `lib/features/player/services/playback_controller.dart` |
| `PlaybackNavigator` | Track navigation with openGeneration concurrency guard | `lib/features/player/services/playback_navigator.dart` |
| `FileOperations` | File open/add with path validation | `lib/features/player/services/file_operations.dart` |
| `StateMonitor` | Engine state observer: breakpoint save, auto-advance, settings restore | `lib/features/player/services/state_monitor.dart` |
| `SubtitleService` | External subtitle auto-detection and loading | `lib/features/player/services/subtitle_service.dart` |
| `VideoProcessingService` | Immutable state + diff-based engine sync + debounced persistence | `lib/features/player/services/video_processing_service.dart` |
| `EngineState` | Mixin: all ValueNotifier playback state + control methods | `lib/kernel/engine/engine_state.dart` |
| `FvpEngine` | Concrete fvp/MDK engine: 6 helper composition | `lib/kernel/engine/fvp_engine.dart` |
| `WindowBridge` | Abstract interface for window management (4 states + 7 commands) | `lib/kernel/bridge/window_bridge.dart` |
| `WindowService` | Concrete WindowBridge: WindowListener + FullscreenDriver | `lib/kernel/bridge/window_service.dart` |
| `FullscreenDriver` | Abstract interface: enter/leave/query fullscreen | `lib/kernel/bridge/fullscreen_driver.dart` |
| `DesktopFullscreenDriverFactory` | Factory: platform detection + compile-time flag | `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart` |
| `WindowState` | Immutable state container: mode, size, resizing | `lib/kernel/bridge/window_state.dart` |
| `Playlist` | State machine: ordered items, current index, 3 play modes | `lib/kernel/playlist/playlist.dart` |
| `PlaylistItem` | Immutable data class: path, timestamp, position, duration | `lib/kernel/models/playlist_item.dart` |
| `SettingsStore` | SharedPreferences persistence with validation | `lib/kernel/persistence/settings_store.dart` |
| `PlaylistStore` | JSON file persistence for playlist | `lib/kernel/persistence/playlist_store.dart` |
| `PlayerScreen` | Main player UI: composes keyboard + controls + video | `lib/ui/player/player_screen.dart` |
| `ControlsOverlay` | Auto-hide layer: mouse/tap gestures, double-click fullscreen | `lib/ui/player/controls_overlay.dart` |
| `ControlBar` | Bottom glass bar: play/pause, seek, volume, speed | `lib/ui/player/control_bar.dart` |
| `VideoSurface` | Texture renderer with aspect ratio | `lib/ui/player/video_surface.dart` |
| `GlassContainer` | Reusable glassmorphism wrapper (3-tier blur) | `lib/ui/shared/glass_container.dart` |
| `Tokens` | Compile-time design tokens: colors, spacing, radii, durations | `lib/ui/theme/tokens.dart` |
| `OsdService` | Global singleton OSD: show/hide with auto-dismiss timer | `lib/ui/shared/osd_overlay.dart` |
| `ThumbnailService` | Platform-aware thumbnail facade with LRU cache | `lib/kernel/services/thumbnail_service.dart` |
| `StartupCoordinator` | Startup progress tracker with phase-based timeline | `lib/kernel/startup/startup_coordinator.dart` |

## Pattern Overview

**Overall:** Layered Architecture with MVVM-inspired service composition

**Key Characteristics:**
- **ValueNotifier-only state management** -- no Provider, Riverpod, or Bloc
- **Deferred loading** for heavy modules (PlayerFeature via `deferred as`)
- **Facade pattern** for PlaybackController (unified entry to sub-modules)
- **Factory pattern** for platform-specific driver selection
- **Observer pattern** for engine state monitoring
- **Immutable state** with `copyWith` (VideoProcessingState, StartupState, PlaylistItem)
- **Dependency Inversion** via `PlaybackContract` interface for sub-modules

## Layers

**Entry Layer:**
- Purpose: App bootstrap and MaterialApp shell
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: Flutter binding init, SharedPreferences prewarm, WindowService init, engine prewarm, theme/locale setup
- Depends on: Kernel layer (WindowService, SettingsStore, StartupCoordinator)
- Used by: Flutter framework

**Features Layer:**
- Purpose: Business logic composition and DI container
- Location: `lib/features/player/`
- Contains: PlayerServices (DI), PlaybackController (facade), PlaybackNavigator, FileOperations, StateMonitor, SubtitleService, VideoProcessingService
- Depends on: Kernel layer (EngineState, Playlist, WindowBridge, SettingsStore)
- Used by: UI layer (PlayerScreen)

**Kernel Layer:**
- Purpose: Core logic, platform abstractions, data models, persistence
- Location: `lib/kernel/`
- Contains: Engine (fvp/MDK), Bridge (window/fullscreen), Models, Persistence, Playlist, Scanner, Services, Utils
- Depends on: Platform native code (fvp, window_manager, Win32 FFI)
- Used by: Features layer, UI layer

**UI Layer:**
- Purpose: All visual components and user interaction
- Location: `lib/ui/`
- Contains: Player screen, playlist panel, shared widgets (GlassContainer, OSD), design tokens, dialogs
- Depends on: Features layer (for callbacks), Kernel layer (for EngineState direct read)
- Used by: App layer

## Data Flow

### Primary Playback Path

1. User triggers play (file picker / drag-drop / playlist select) -- `lib/features/player/player_feature.dart:154`
2. `PlaybackController.openAndPlay(path)` delegates to `FileOperations.openAndPlay()` -- `lib/features/player/services/playback_controller.dart:109`
3. `PlaybackNavigator.playIndex(index)` validates path, increments generation, calls `engine.open(path)` -- `lib/features/player/services/playback_navigator.dart:46`
4. `FvpEngine.open(path)` sets MediaState.loading, calls `MediaOpener.open()`, transitions to idle on success -- `lib/kernel/engine/fvp_engine.dart:235`
5. `PlaybackNavigator` resumes breakpoint, detects subtitles, calls `engine.play()` -- `lib/features/player/services/playback_navigator.dart:75-87`
6. `FvpEngine.play()` sets MDK player to playing, starts PositionPoller -- `lib/kernel/engine/fvp_engine.dart:314`
7. UI rebuilds via `ValueListenableBuilder` on `engine.textureId`, `engine.state`, `engine.position` -- `lib/ui/player/player_screen.dart:146`

### Startup Path

1. `main()` initializes bindings, logs, memory monitor, SharedPreferences -- `lib/main.dart:20-26`
2. `DesktopFullscreenDriverFactory.create()` selects platform-specific driver -- `lib/kernel/bridge/desktop_fullscreen_driver_factory.dart:48`
3. `WindowService.init()` ensures window manager, restores geometry, shows window -- `lib/kernel/bridge/window_service.dart:64`
4. `EnginePrewarm.prewarm()` fire-and-forget: registers FFmpeg codecs, D3D11 context -- `lib/kernel/engine/engine_prewarm.dart`
5. `App` loads locale/theme, shows `ProgressSplashScreen` -- `lib/app.dart:145-150`
6. `DeferredPlayerFeature` lazy-loads `PlayerFeature` module -- `lib/features/player/deferred_player_feature.dart:89`
7. `PlayerFeature._init()` creates `PlayerServices`, calls `init()` -- `lib/features/player/player_feature.dart:118`
8. `PlayerServices.init()` creates FvpEngine, Playlist, PlaybackController, VideoProcessingService -- `lib/features/player/player_services.dart:86`
9. `StartupCoordinator.markReady()` logs timeline, `PlayerScreen` renders -- `lib/kernel/startup/startup_coordinator.dart:64`

### Fullscreen Toggle Path

1. User presses F key or double-clicks -- `lib/ui/player/player_screen.dart:193`
2. `KeyboardHandler.onToggleFullscreen` calls `windowService.setMode(WindowMode.fullscreen)` -- `lib/ui/player/player_screen.dart:194`
3. `WindowService.setMode()` captures snapshot, calls `FullscreenDriver.enterFullscreen()` -- `lib/kernel/bridge/window_service.dart:232`
4. `WindowsFullscreenDriver.enterFullscreenFast()` strips WS_THICKFRAME, caches HWND/monitor, calls SetWindowPos atomically -- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart:194`
5. `WindowService._onNativeFullScreenChanged()` updates `_isFullscreen` and `_state.mode` -- `lib/kernel/bridge/window_service.dart:105`
6. `AnimatedBuilder` on `windowService.mode` in `PlayerScreen` rebuilds with `isFullscreen=true` -- `lib/ui/player/player_screen.dart:157`
7. `ControlsOverlay` receives `isFullscreen`, `AutoHideController` adjusts delay -- `lib/ui/player/controls_overlay.dart:185`

**State Management:**
- All reactive state exposed as `ValueNotifier<T>` instances
- UI subscribes via `ValueListenableBuilder<T>` or `AnimatedBuilder`
- `MergedListenable` combines multiple notifiers (e.g., position + duration + buffered)
- `ValueListenableBuilder2` for dual-notifier scenarios
- No global state container -- services hold their own notifiers
- `ValueNotifier<int> playlistGeneration` as lightweight change signal (avoids deep copy)

## Key Abstractions

**EngineState (mixin):**
- Purpose: Abstract playback interface decoupled from fvp/MDK implementation
- Examples: `lib/kernel/engine/engine_state.dart`, `lib/kernel/engine/fvp_engine.dart`
- Pattern: Mixin with ValueNotifier fields + abstract method signatures

**WindowBridge (abstract class):**
- Purpose: Abstract window management interface for testability
- Examples: `lib/kernel/bridge/window_bridge.dart`, `lib/kernel/bridge/window_service.dart`
- Pattern: Interface with 4 state notifiers + 7 command methods

**FullscreenDriver (abstract class):**
- Purpose: Platform-specific fullscreen operations behind a common interface
- Examples: `lib/kernel/bridge/fullscreen_driver.dart`, `lib/kernel/bridge/platform/windows_fullscreen_driver.dart`
- Pattern: Abstract with optional fast-path methods and capability queries

**PlaybackContract (abstract interface):**
- Purpose: Dependency Inversion for playback sub-modules
- Examples: `lib/features/player/services/playback_contract.dart`
- Pattern: Interface consumed by Navigator/FileOperations/StateMonitor, implemented by PlaybackController

**PlaybackController (facade):**
- Purpose: Unified entry point combining navigator + fileOps + monitor sub-modules
- Examples: `lib/features/player/services/playback_controller.dart`
- Pattern: Facade + Composition (creates sub-modules in constructor, delegates all calls)

**VideoProcessingState (immutable data):**
- Purpose: Video processing settings with copyWith for immutable updates
- Examples: `lib/features/player/models/video_processing_state.dart`
- Pattern: Immutable value object with diff-based engine sync

**StartupState (immutable data):**
- Purpose: Startup progress tracking with phase enum
- Examples: `lib/kernel/startup/startup_state.dart`
- Pattern: @immutable class with copyWith + equality

## Entry Points

**main():**
- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities: Flutter binding, log init, memory monitor, SharedPreferences prewarm, fullscreen driver factory, WindowService init, engine prewarm, runApp

**App (StatefulWidget):**
- Location: `lib/app.dart`
- Triggers: Created by main()
- Responsibilities: MaterialApp shell, theme/locale init, settings panel dialog, quick menu

**DeferredPlayerFeature (StatefulWidget):**
- Location: `lib/features/player/deferred_player_feature.dart`
- Triggers: Created by App.build()
- Responsibilities: Lazy-load PlayerFeature module via deferred import

**PlayerFeature (StatefulWidget):**
- Location: `lib/features/player/player_feature.dart`
- Triggers: Created by DeferredPlayerFeature after loadLibrary()
- Responsibilities: Create PlayerServices, manage UI state (ready/error/drag), compose PlayerScreen

**PlayerScreen (StatefulWidget):**
- Location: `lib/ui/player/player_screen.dart`
- Triggers: Created by PlayerFeature._buildPlayerScreen()
- Responsibilities: Compose all UI: CustomTitleBar + VideoSurface + ControlsOverlay + PlaylistPanel + KeyboardHandler

## Architectural Constraints

- **Threading:** Single-threaded Dart UI isolate. All engine callbacks dispatched to main isolate via `SchedulerBinding.instance.addPostFrameCallback`. FFI calls (Win32) are synchronous on UI thread (fast path).
- **Global state:** `OsdService.I` is a singleton (global OSD). `SettingsStore._instance` is a static prewarmed instance. `ThumbnailService._instance` is a static singleton with LRU cache. `StartupCoordinator` is instance-scoped but passed through widget tree.
- **Deferred loading:** `PlayerFeature` uses `deferred as` to avoid eagerly importing fvp/MDK types. This means `PlayerFeature` cannot be referenced by type outside its module boundary.
- **Platform branching:** `DesktopFullscreenDriverFactory` uses `Platform.isXXX` at runtime + `bool.fromEnvironment` at compile time for Windows driver selection. macOS/Linux always use their platform drivers.
- **No DI framework:** All dependency injection is manual via constructor injection. `PlayerServices` acts as the composition root for player-related services.
- **State machine guards:** `MediaStateTransition` extension enforces valid state transitions. Invalid transitions are logged in debug mode, silently ignored in release.

## Anti-Patterns

### Direct Engine Access from UI

**What happens:** Some UI widgets directly read `engine.position.value`, `engine.state.value`, etc.
**Why it's wrong:** Creates implicit coupling between UI and engine internals.
**Do this instead:** Pass `EngineState` through widget constructor parameters (already the pattern in PlayerScreen/ControlsOverlay/VideoSurface). Do not access engine via service locator.

### Mutable Playlist State with External Modification

**What happens:** `PlaybackController` and `PlayerFeature` both call `playlist.addAll()`, `playlistGeneration.value++` directly.
**Why it's wrong:** Split mutation responsibility makes it hard to track who changed what.
**Do this instead:** Route all playlist mutations through `PlaybackController` methods. The `PlayerFeature._buildPlayerScreen` callbacks that mutate playlist should call controller methods instead.

### Late Field Initialization in FvpEngine

**What happens:** `_callbackHandler`, `_positionPoller`, `_volumeController` are `late` fields initialized in the factory constructor.
**Why it's wrong:** If factory constructor throws between field assignment and helper initialization, these fields are uninitialized. Accessing them throws `LateInitializationError`.
**Do this instead:** The factory constructor pattern (already used) is the mitigation. Document that these helpers must be initialized in the factory, not in the private constructor.

## Error Handling

**Strategy:** Defensive catch + log + graceful degradation. Never crash the app.

**Patterns:**
- `SettingsStore.load()` returns safe defaults on any exception (never throws to caller)
- `FvpEngine._guardedAction()` wraps all engine operations with disposed check + try-catch + error type classification
- `PlaybackNavigator.playIndex()` restores old playlist index on failure
- `StateMonitor.dispose()` uses fire-and-forget `unawaited()` with `.catchError()` for save operations
- `WindowService._handleEnter/Leave()` returns bool success, caller rolls back on failure
- `DesktopFullscreenDriverFactory.createWindowsNative()` falls back to `DesktopFullscreenDriver` on HWND invalid or FFI exception

## Cross-Cutting Concerns

**Logging:** `lib/kernel/utils/log.dart` provides `log.i/d/w/e` wrappers around `debugPrint`. Engine-specific: `logEngine`. Bridge-specific: `logBridge`. All logging is debug-only in release builds.

**Validation:** `lib/kernel/services/path_validator.dart` validates file paths against traversal attacks. `lib/kernel/persistence/settings_validator.dart` sanitizes all persisted values (volume, dimensions, coordinates, enums) with clamp/default fallback.

**Authentication:** Not applicable (desktop media player, no user auth).

**Theming:** Single "Midnight" theme defined in `lib/ui/theme/tokens.dart`. All visual values accessed via `Tokens.*` static constants. No runtime theme switching beyond accent color (3 options: Midnight/Ocean/Forest via `ThemeService`).

**Localization:** ARB-based via `lib/l10n/`. Supported locales: `en`, `zh`. `LocaleService` persists preference. `AppLocalizations.of(context)` in all UI widgets.

**Performance Monitoring:** `lib/kernel/utils/perf_monitor.dart` for frame timing. `lib/kernel/utils/memory_monitor.dart` for RSS tracking. `DebugProbe` for operation timing in `PlaybackController`. `EngineMetrics` for engine health counters. `EngineEventLog` for last 100 events ring buffer.

---

*Architecture analysis: 2026-07-12*
