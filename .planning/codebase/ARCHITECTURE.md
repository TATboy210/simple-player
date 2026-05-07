<!-- refreshed: 2026-05-07 -->
# Architecture

**Analysis Date:** 2026-05-07

## System Overview

```text
+------------------------------------------------------------------+
|                         App Shell                                |
|                   `lib/main.dart` + `lib/app.dart`               |
|           (fvp register, SharedPreferences, PlatformService init)|
+------------------------------------------------------------------+
         |                    |                    |
         v                    v                    v
+------------------+  +------------------+  +------------------+
| PlaybackController|  | PlatformService  |  | WindowManager   |
| (Orchestrator)    |  | (Abstract I/F)   |  | Service          |
| `lib/kernel/      |  | `lib/kernel/     |  | `lib/kernel/     |
|  services/         |  |  services/       |  |  window/          |
|  playback_         |  |  platform_       |  |  window_manager   |
|  controller.dart` |  |  service.dart`   |  |  _service.dart`   |
+--------+----------+  +--------+---------+  +--------+---------+
         |                      |                      |
    +----+----+          +------+------+         +-----+------+
    | 3 Mixins|          | Windows     |         | AspectRatio|
    | FileOps |          | Impl        |         | Service    |
    | Nav     |          | `lib/kernel/|         | (MethodCh) |
    | Monitor |          |  platform/` |         +------------+
    +---------+          +-------------+
         |
         v
+------------------------------------------------------------------+
|                      MediaEngine (Abstract)                       |
|                `lib/kernel/engine/media_engine.dart`              |
|              13 ValueNotifiers + playback controls                |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|                    FvpEngine (Concrete)                            |
|                 `lib/kernel/engine/fvp_engine.dart`               |
|  +-------------------+  +----------------+  +------------------+  |
|  | FvpCallbackHandler|  | PositionPoller |  | TrackManager     |  |
|  | (mdk callbacks)   |  | (250ms timer)  |  | (audio/subtitle) |  |
|  +-------------------+  +----------------+  +------------------+  |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|                    fvp / MDK / FFmpeg                              |
|               (Native C++ via FFI bindings)                       |
|            Windows D3D11 rendering                                |
+------------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `main()` | Bootstrap: fvp register, SharedPreferences prewarm, PlatformService init | `lib/main.dart` |
| `App` | MaterialApp shell, engine/service init, locale/window mode binding | `lib/app.dart` |
| `MediaEngine` | Abstract engine interface (13 ValueNotifiers + playback controls) | `lib/kernel/engine/media_engine.dart` |
| `FvpEngine` | fvp/MDK concrete implementation, delegates to 3 helpers | `lib/kernel/engine/fvp_engine.dart` |
| `FvpCallbackHandler` | mdk callback registration, state mapping (mdk -> MediaState), main-thread scheduling | `lib/kernel/engine/fvp_callback_handler.dart` |
| `PositionPoller` | 250ms timer polling playback position/buffered | `lib/kernel/engine/position_poller.dart` |
| `TrackManager` | Audio/subtitle track selection and switching | `lib/kernel/engine/track_manager.dart` |
| `PlaybackController` | Business orchestrator (3 mixins combined) | `lib/kernel/services/playback_controller.dart` |
| `FileOperations` | File open (validate -> add to playlist -> play) | `lib/kernel/services/file_operations.dart` |
| `PlaybackNavigator` | Playlist navigation (prev/next/index), external subtitle detection, concurrency guard | `lib/kernel/services/playback_navigator.dart` |
| `StateMonitor` | Auto-advance, breakpoint save, settings restore, playlist management | `lib/kernel/services/state_monitor.dart` |
| `VideoProcessingService` | 7 ValueNotifiers for video effects, delegates to MediaEngine, auto-persists | `lib/kernel/services/video_processing_service.dart` |
| `Playlist` | Ordered playlist model, 4 play modes, CQS navigation, JSON serialization | `lib/kernel/playlist/playlist.dart` |
| `SettingsStore` | SharedPreferences persistence (static class, prewarmed) | `lib/kernel/persistence/settings_store.dart` |
| `PlaylistStore` | JSON file persistence with 300ms debounce + atomic write (.tmp rename) | `lib/kernel/persistence/playlist_store.dart` |
| `PlatformService` | Abstract platform interface (window controls, reactive state) | `lib/kernel/services/platform_service.dart` |
| `WindowsPlatformService` | Windows implementation, delegates to WindowManagerService | `lib/kernel/platform/windows_platform_service.dart` |
| `WindowManagerService` | Singleton window management (frameless, fullscreen, persistence) | `lib/kernel/window/window_manager_service.dart` |
| `AspectRatioService` | Native MethodChannel aspect ratio constraints | `lib/kernel/window/aspect_ratio_service.dart` |
| `PathValidator` | Path security (extension whitelist, traversal detection) | `lib/kernel/services/path_validator.dart` |
| `PathUtils` | Cross-platform basename/dirname extraction | `lib/kernel/utils/path_utils.dart` |
| `Tokens` | Design tokens (compile-time const colors/fonts/spacing) | `lib/kernel/ui/theme/tokens.dart` |
| `AppTheme` | ThemeData bridge from Tokens | `lib/kernel/ui/theme/app_theme.dart` |

## Pattern Overview

**Overall:** Kernel-based architecture with abstract interfaces and ValueNotifier reactive state

**Key Characteristics:**
- **Kernel isolation**: All business logic lives in `lib/kernel/`, no Flutter UI imports in kernel code (except `foundation.dart` for ValueNotifier)
- **Abstract interfaces**: `MediaEngine` and `PlatformService` are abstract; UI depends on interfaces, not implementations
- **ValueNotifier + ValueListenableBuilder**: No third-party state management (no Provider/Riverpod/Bloc)
- **Mixin composition**: `PlaybackController` combines 3 focused mixins instead of one large class
- **Defensive programming**: Pervasive `_disposed` guards, try-catch wrappers, input clamping
- **CQS principle**: `Playlist.peekNext()`/`peekPrevious()` are pure queries; callers update state explicitly

## Layers

**App Shell Layer:**
- Purpose: Bootstrap and framework wiring
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: fvp registration, SharedPreferences prewarm, PlatformService init, MaterialApp setup
- Depends on: kernel/services, kernel/persistence, kernel/platform
- Used by: Flutter runtime

**Kernel / Engine Layer:**
- Purpose: Media playback abstraction and concrete implementation
- Location: `lib/kernel/engine/`
- Contains: `MediaEngine` interface, `FvpEngine` implementation, 3 helpers (callback handler, position poller, track manager)
- Depends on: fvp/mdk (FFI), kernel/models
- Used by: kernel/services

**Kernel / Services Layer:**
- Purpose: Business orchestration and cross-cutting services
- Location: `lib/kernel/services/`
- Contains: `PlaybackController` (3 mixins), `VideoProcessingService`, `PathValidator`, `PlatformService` interface
- Depends on: kernel/engine, kernel/playlist, kernel/persistence, kernel/models
- Used by: App shell, UI widgets

**Kernel / Playlist Layer:**
- Purpose: Playlist state machine and navigation logic
- Location: `lib/kernel/playlist/`
- Contains: `Playlist` class with 4 play modes, CQS navigation, JSON serialization
- Depends on: kernel/models
- Used by: kernel/services

**Kernel / Models Layer:**
- Purpose: Data classes and enums (pure Dart, no dependencies)
- Location: `lib/kernel/models/`
- Contains: `MediaState`, `MediaInfo`, `PlaylistItem`, `PlayMode`, `AspectRatioMode`, `VideoEffectType`
- Depends on: kernel/utils (PathUtils)
- Used by: All other layers

**Kernel / Persistence Layer:**
- Purpose: Settings and playlist persistence
- Location: `lib/kernel/persistence/`
- Contains: `SettingsStore` (SharedPreferences, static), `PlaylistStore` (JSON file, debounced)
- Depends on: shared_preferences, path_provider, kernel/models, kernel/playlist
- Used by: kernel/services, App shell

**Kernel / Platform Layer:**
- Purpose: Platform-specific service implementations
- Location: `lib/kernel/platform/`
- Contains: `WindowsPlatformService`
- Depends on: kernel/window
- Used by: App shell (main.dart)

**Kernel / Window Layer:**
- Purpose: Window management and aspect ratio control
- Location: `lib/kernel/window/`
- Contains: `WindowManagerService` (singleton), `AspectRatioService` (MethodChannel)
- Depends on: window_manager, kernel/persistence
- Used by: kernel/platform

**Kernel / UI Theme Layer:**
- Purpose: Design tokens and ThemeData
- Location: `lib/kernel/ui/theme/`
- Contains: `Tokens` (compile-time const), `AppTheme` (ThemeData bridge)
- Depends on: flutter/material
- Used by: UI widgets (not yet wired in current codebase)

**Kernel / Utils Layer:**
- Purpose: Pure utility functions
- Location: `lib/kernel/utils/`
- Contains: `PathUtils`, `time_utils`, `MotionUtils`
- Depends on: nothing (pure Dart)
- Used by: kernel/models, kernel/services, UI

**L10n Layer:**
- Purpose: Internationalization (zh/en)
- Location: `lib/l10n/`
- Contains: `AppLocalizations` and generated files
- Depends on: flutter_localizations
- Used by: App shell

## Data Flow

### Media File Open Flow

1. User action (file picker / drag-drop / history) -> `FileOperations.openAndPlay(path)` (`lib/kernel/services/file_operations.dart:23`)
2. `PathValidator.validate(path)` checks extension whitelist + path traversal (`lib/kernel/services/path_validator.dart:52`)
3. `Playlist.add(path)` adds item to list (`lib/kernel/playlist/playlist.dart:82`)
4. `PlaybackNavigator.playIndex(idx)` is called (`lib/kernel/services/playback_navigator.dart:29`)
5. `openGeneration` guard incremented (concurrent open protection) (`lib/kernel/services/playback_navigator.dart:31`)
6. `PathValidator.validate()` again for playlist injection safety (`lib/kernel/services/playback_navigator.dart:39`)
7. `FvpEngine.open(path)` called (`lib/kernel/engine/fvp_engine.dart:130`)
   - File existence check via `dart:io`
   - `_player.media = path` sets media on mdk player
   - `_player.prepare()` with 10s timeout
   - Media info extracted (video/audio/subtitle tracks, PAR-corrected aspect ratio)
   - `_player.updateTexture()` with 5s timeout for D3D11 texture
8. Resume from saved position if `positionMs > 1000` (`lib/kernel/services/playback_navigator.dart:54`)
9. Auto-detect external subtitles in same directory (`lib/kernel/services/playback_navigator.dart:59`)
10. `engine.play()` starts playback
11. `PositionPoller.start()` begins 250ms polling (`lib/kernel/engine/position_poller.dart:39`)
12. `FvpCallbackHandler` receives mdk state/status callbacks, maps to `MediaState`, dispatches to main thread (`lib/kernel/engine/fvp_callback_handler.dart:36`)
13. `StateMonitor._onStateChanged()` listens for completion -> auto-advance (`lib/kernel/services/state_monitor.dart:56`)

### Playlist Save Flow

1. Any playlist mutation calls `savePlaylist()` on `PlaybackController` (`lib/kernel/services/playback_controller.dart:40`)
2. `PlaylistStore.save(playlist)` immediately serializes to JSON snapshot (`lib/kernel/persistence/playlist_store.dart:43`)
3. 300ms debounce timer starts; subsequent calls reset timer and replace snapshot (`lib/kernel/persistence/playlist_store.dart:44-46`)
4. `_flush()` writes to `.tmp` file then renames (atomic write) (`lib/kernel/persistence/playlist_store.dart:50-66`)
5. Previous write completion awaited before starting new write (concurrency guard) (`lib/kernel/persistence/playlist_store.dart:55-57`)

### Window State Persistence Flow

1. Window resize/move event -> `WindowManagerService.onWindowResized()` (`lib/kernel/window/window_manager_service.dart:373`)
2. `_schedulePersist()` starts 500ms debounce timer (`lib/kernel/window/window_manager_service.dart:428`)
3. `_persistWindowState()` queries 4 FFI values in parallel (size, position, maximized, fullscreen) (`lib/kernel/window/window_manager_service.dart:441-451`)
4. Fullscreen: uses cached windowed geometry (not fullscreen size) (`lib/kernel/window/window_manager_service.dart:457-469`)
5. `SettingsStore.saveWindowGeometry()` validates all values (NaN/Infinity/negative guards) before writing (`lib/kernel/persistence/settings_store.dart:190-208`)
6. Sequential writes (not Future.wait) for data consistency (`lib/kernel/persistence/settings_store.dart:203-207`)

**State Management:**
- All reactive state uses `ValueNotifier<T>` exposed as public fields
- UI binds via `ValueListenableBuilder<T>`
- No centralized state store; each service owns its own notifiers
- `PlaybackController.currentFileName` is a shared `ValueNotifier<String>` across mixins

## Key Abstractions

**MediaEngine:**
- Purpose: Abstract playback engine interface enabling testability and swappability
- Examples: `lib/kernel/engine/media_engine.dart` (interface), `lib/kernel/engine/fvp_engine.dart` (implementation)
- Pattern: Strategy pattern with 13 ValueNotifiers for reactive state

**PlatformService:**
- Purpose: Abstract platform operations (window controls) enabling multi-platform support
- Examples: `lib/kernel/services/platform_service.dart` (interface), `lib/kernel/platform/windows_platform_service.dart` (implementation)
- Pattern: Factory singleton (`PlatformService.init()` in main, `PlatformService.I` accessor)

**PlaybackController Mixin Composition:**
- Purpose: Split complex playback logic into focused mixins
- Examples: `lib/kernel/services/playback_controller.dart` combines `FileOperations`, `PlaybackNavigator`, `StateMonitor`
- Pattern: Mixin-based composition with shared abstract getters for dependencies

## Entry Points

**App Bootstrap:**
- Location: `lib/main.dart`
- Triggers: `flutter run` / OS launch
- Responsibilities: fvp register, SharedPreferences prewarm, PlatformService init, `runApp(App())`

**App Init:**
- Location: `lib/app.dart` `_init()`
- Triggers: `_AppState.initState()`
- Responsibilities: Parallel init of PlatformService, PlaybackController, locale loading

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. mdk callbacks from native threads are dispatched to main thread via `SchedulerBinding.instance.addPostFrameCallback` in `FvpCallbackHandler._scheduleOnMain()`.
- **Global state:** `SettingsStore._cachedPrefs` (prewarmed SharedPreferences), `PlatformService._instance` (singleton), `WindowManagerService.I` (singleton), `AspectRatioService.I` (singleton), `MotionUtils._reducedMotion` (static bool).
- **Circular imports:** None detected. Kernel layers have clear dependency direction: models <- engine <- services <- platform <- app shell.
- **Dispose safety:** All services implement `_disposed` flag pattern. Every public method checks `_disposed` before executing. `FvpEngine._guardedAction()` is the canonical pattern.

## Anti-Patterns

### Duplicate Root-Level Models

**What happens:** `lib/models/playlist_item.dart` and `lib/utils/time_utils.dart` are older versions of `lib/kernel/models/playlist_item.dart` and `lib/kernel/utils/time_utils.dart`. The root-level `PlaylistItem` lacks `timestamp`/`positionMs`/`durationMs` fields and uses naive path splitting.
**Why it's wrong:** Two implementations of the same concept create confusion and divergence risk.
**Do this instead:** Delete `lib/models/playlist_item.dart` and `lib/utils/time_utils.dart`. Use only the kernel versions.

### Static Singleton Services

**What happens:** `SettingsStore`, `WindowManagerService`, `AspectRatioService` use static singletons instead of dependency injection.
**Why it's wrong:** Makes unit testing harder (requires `reset()` methods), prevents running multiple instances.
**Do this instead:** For new services, prefer constructor injection. Existing singletons have `@visibleForTesting reset()` as mitigation.

## Error Handling

**Strategy:** Catch-all with `debugPrint` + graceful fallback. Never crash. Never silently swallow.

**Patterns:**
- `_guardedAction(name, action)` in `FvpEngine` -- wraps every public method with disposed check + try-catch + error message update (`lib/kernel/engine/fvp_engine.dart:117-125`)
- `SettingsStore._save(method, op)` -- generic save wrapper with try-catch + debugPrint (`lib/kernel/persistence/settings_store.dart:171-178`)
- `PlaylistStore._flush()` -- atomic write with try-catch + completer completion in finally (`lib/kernel/persistence/playlist_store.dart:50-76`)
- `PathValidator.validate()` -- returns `String?` (null = valid, string = error message) (`lib/kernel/services/path_validator.dart:52-59`)
- Error messages stored in `MediaEngine.errorMessage` ValueNotifier for UI display

## Cross-Cutting Concerns

**Logging:** `debugPrint()` throughout (never `print()`). All catch blocks log via `debugPrint('[ClassName] method failed: $e')`.

**Validation:** `PathValidator` at all file-open entry points. Extension whitelist + path traversal detection + null byte injection check. Input clamping via `.clamp()` on all numeric parameters.

**Authentication:** Not applicable (local desktop app, no auth).

**Persistence:** Two strategies -- `SharedPreferences` for key-value settings (prewarmed, debounced), JSON files for playlist (300ms debounce, atomic write).

**Concurrency:** `openGeneration` counter in `PlaybackNavigator` discards stale async open requests. `_persistInFlight` Completer in `WindowManagerService` prevents concurrent persistence writes.

---

*Architecture analysis: 2026-05-07*
