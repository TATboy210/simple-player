<!-- refreshed: 2026-05-23 -->
# Architecture

**Analysis Date:** 2026-05-23

## System Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                 │
│  `lib/ui/`                    `lib/l10n/`                       │
│  PlayerScreen, ControlsOverlay, PlaylistPanel, SettingsPanel    │
│  ValueListenableBuilder reactive widgets                        │
├──────────────────────────┬──────────────────────────────────────┤
│    Service Layer         │         Window Layer                 │
│  `lib/kernel/services/`  │         `lib/window/`                │
│  PlaybackController      │  WindowService (Win32 FFI)           │
│  (3 mixins composed)     │  FullscreenController                │
├──────────────────────────┴──────────────────────────────────────┤
│                       Kernel Layer                               │
│  `lib/kernel/`                                                   │
│  MediaEngine (abstract)  Playlist  Persistence  Models           │
│  FvpEngine (concrete)    Scanner   SettingsStore                 │
├─────────────────────────────────────────────────────────────────┤
│                    Native Layer                                    │
│  `windows/runner/`                                               │
│  flutter_window.cpp    MethodChannel                              │
│  C++ Win32 window                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App | Material shell, service wiring, locale/theme state | `lib/app.dart` |
| PlayerScreen | Main composition widget, keyboard + title bar + controls + playlist | `lib/ui/player/player_screen.dart` |
| ControlsOverlay | Auto-hide control layer (progress bar, volume, speed) | `lib/ui/player/controls_overlay.dart` |
| PlaybackController | Orchestrator: file ops + navigation + state monitoring | `lib/kernel/services/playback_controller.dart` |
| MediaEngine | Abstract engine interface (10 ValueNotifiers + playback methods) | `lib/kernel/engine/media_engine.dart` |
| FvpEngine | Concrete fvp/MDK implementation (D3D11 + FFmpeg) | `lib/kernel/engine/fvp_engine.dart` |
| Playlist | Ordered list + play mode state machine | `lib/kernel/playlist/playlist.dart` |
| WindowService | Window management singleton (frameless, fullscreen, lifecycle events) | `lib/window/window_service.dart` |
| WindowLifecycleBus | Unified window event bus (resize/move + isOperating) | `lib/window/window_lifecycle.dart` |
| FullscreenController | Win32 FFI fullscreen (WS_THICKFRAME + SetWindowPos) | `lib/window/fullscreen_controller.dart` |
| SettingsStore | SharedPreferences persistence for all app settings | `lib/kernel/persistence/settings_store.dart` |
| PlaylistStore | JSON file persistence for playlist history | `lib/kernel/persistence/playlist_store.dart` |

## Pattern Overview

**Overall:** Layered architecture with mixin composition and dependency inversion

**Key Characteristics:**
- 3-layer separation: Kernel (no UI), Window (platform), UI (widgets)
- ValueNotifier + ValueListenableBuilder for reactive state (no Provider/Riverpod/Bloc)
- Mixin composition for PlaybackController (FileOperations + PlaybackNavigator + StateMonitor)
- Abstract interfaces with platform-specific implementations (MediaEngine, ThumbnailProvider)
- Singleton pattern for WindowService (`WindowService.instance`)

## Layers

**Kernel Layer:**
- Purpose: Core logic, engine, models, persistence -- no Flutter UI dependency except ValueNotifier
- Location: `lib/kernel/`
- Contains: Engine abstraction, models, persistence, playlist logic, services, theme tokens, utilities
- Depends on: `fvp` package, `shared_preferences`, `dart:io`
- Used by: UI layer, Window layer

**Service Layer (within Kernel):**
- Purpose: Business orchestration via mixin composition
- Location: `lib/kernel/services/`
- Contains: `PlaybackController` (orchestrator), `FileOperations`, `PlaybackNavigator`, `StateMonitor`, `VideoProcessingService`, `ThumbnailService`, `SubtitleService`, `PathValidator`
- Depends on: MediaEngine, Playlist, Persistence
- Used by: App (`lib/app.dart`), PlayerScreen

**Window Layer:**
- Purpose: Platform-specific window management
- Location: `lib/window/`
- Contains: `WindowService` (Windows), `LinuxWindowService`, `MacosWindowService`, `FullscreenController`, `WindowPersistenceService`, `WindowStateService`, `GeometryStore`, `WindowLifecycleBus`
- Depends on: `window_manager` package, Win32 FFI (`dart:ffi`), `shared_preferences`
- Used by: `main()` at startup (parallel init), UI directly via `WindowService.instance`

**UI Layer:**
- Purpose: Flutter widgets for player, playlist, dialogs, shared components
- Location: `lib/ui/`
- Contains: Player screen, control bar, progress bar, volume controls, speed button, playlist panel, settings panel, OSD overlay, glass containers
- Depends on: Kernel layer (MediaEngine, PlaybackController, Playlist, models), Window layer (WindowService)
- Used by: App shell

**Native C++ Layer:**
- Purpose: Win32 window creation and MethodChannel handler for forceRedraw
- Location: `windows/runner/`
- Contains: `flutter_window.cpp`, `win32_window.cpp`, `main.cpp`
- Depends on: Flutter engine, Win32 API
- Used by: Flutter engine at startup

## Data Flow

### Primary Playback Path

1. User opens file via FilePicker or drag-drop (`lib/app.dart:95-122`, `lib/ui/player/drop_handler.dart`)
2. `PlaybackController.openAndPlay()` validates path via `PathValidator` (`lib/kernel/services/file_operations.dart`)
3. `PlaybackNavigator.playIndex()` calls `engine.open(path)` then `engine.play()` (`lib/kernel/services/playback_navigator.dart:29-78`)
4. `FvpEngine.open()` delegates to `mdk.Player.open()` (`lib/kernel/engine/fvp_engine.dart`)
5. `PositionPoller` starts 250ms timer polling engine position (`lib/kernel/engine/position_poller.dart`)
6. UI rebuilds via `ValueListenableBuilder` on engine's 10 ValueNotifiers
7. `StateMonitor._onStateChanged()` handles auto-advance on completion (`lib/kernel/services/state_monitor.dart`)

### Window Control Path

1. User clicks title bar button (minimize/maximize/close/fullscreen) (`lib/kernel/ui/window/custom_title_bar.dart`)
2. Calls `WindowService.instance.minimize()` etc. (`lib/window/window_service.dart`)
3. `WindowService` delegates to `window_manager` or `FullscreenController` (`lib/window/window_service.dart`)
4. For fullscreen: Win32 FFI manipulates `WS_THICKFRAME`/`WS_CAPTION` styles + `SetWindowPos` (`lib/window/fullscreen_controller.dart`)
5. Window events flow back via `_WindowListener` → updates ValueNotifiers

### Settings Flow

1. User opens SettingsPanel dialog (`lib/app.dart:128-149`)
2. Changes stored locally in dialog state (deferred apply pattern)
3. On Apply: `SettingsStore.save()` writes to `SharedPreferences` (`lib/kernel/persistence/settings_store.dart`)
4. `VideoProcessingService` applies effects to engine immediately (`lib/kernel/services/video_processing_service.dart`)

**State Management:**
- All state exposed as `ValueNotifier<T>` instances on `MediaEngine`, `Playlist`, `WindowService`
- UI rebuilds via `ValueListenableBuilder` or custom `ValueListenableBuilder2`
- No global state management library (Provider/Riverpod/Bloc) used
- `PlaybackController` is the single orchestrator, composed from 3 mixins

## Key Abstractions

**MediaEngine:**
- Purpose: Abstract playback interface -- any backend (fvp, libmpv, video_player) can implement
- Examples: `lib/kernel/engine/media_engine.dart` (abstract), `lib/kernel/engine/fvp_engine.dart` (concrete)
- Pattern: Strategy pattern with 10 ValueNotifiers for reactive state

**WindowService + WindowLifecycleBus:**
- Purpose: Platform window management + unified event bus for resize/move events
- Examples: `lib/window/window_service.dart` (singleton), `lib/window/window_lifecycle.dart` (event bus)
- Pattern: Singleton (`WindowService.instance`) + broadcast Stream + ValueNotifier (`isOperating`)

**ThumbnailProvider:**
- Purpose: Platform-specific thumbnail extraction (Win32 COM, noop fallback)
- Examples: `lib/kernel/services/thumbnail_provider.dart` (abstract), `lib/kernel/services/windows_thumbnail_provider.dart` (concrete)
- Pattern: Strategy pattern with platform-specific factories

**PlaybackController (Mixin Composition):**
- Purpose: Orchestrator combining file operations, navigation, and state monitoring
- Examples: `lib/kernel/services/playback_controller.dart` (composer), `lib/kernel/services/file_operations.dart`, `lib/kernel/services/playback_navigator.dart`, `lib/kernel/services/state_monitor.dart`
- Pattern: Mixin composition -- each mixin declares abstract members, controller provides implementations

## Entry Points

**main():**
- Location: `lib/main.dart`
- Triggers: Application startup
- Responsibilities: Initialize fvp decoders, prewarm SharedPreferences, initialize WindowService (parallel), run `App` widget

**App widget:**
- Location: `lib/app.dart`
- Triggers: `runApp()` from main
- Responsibilities: Create FvpEngine + Playlist + PlaybackController, parallel init of services, build MaterialApp with PlayerScreen

**FlutterWindow::OnCreate (C++):**
- Location: `windows/runner/flutter_window.cpp`
- Triggers: Win32 window creation
- Responsibilities: Create FlutterViewController, register plugins, set up `com.simple_player/redraw` MethodChannel

## Architectural Constraints

- **Threading:** Single Dart isolate (event loop). fvp/MDK uses internal threads for decoding/rendering. ValueNotifiers updated on main thread via FvpCallbackHandler.
- **Global state:** `WindowService.instance` singleton. `SettingsStore` uses static `SharedPreferences` reference. `AspectRatioService.I` singleton. `WindowLifecycleBus.instance` singleton.
- **Platform coupling:** Win32 FFI used only in `lib/window/fullscreen_controller.dart` and `lib/window/window_service.dart`. `windows/runner/flutter_window.cpp` handles C++ MethodChannel.
- **No DI framework:** All wiring done manually in `App.initState()` and `main()`.
- **ValueNotifier-only state:** No Provider/Riverpod/Bloc/GetX. All reactive state flows through ValueNotifier + ValueListenableBuilder.

## Anti-Patterns

### Callback Drilling

**What happens:** `PlayerScreen` receives 10+ callback parameters from `App` (`onOpenFile`, `onPrevious`, `onNext`, `onTogglePlayMode`, `onSettings`, etc.)
**Why it's wrong:** Deep parameter passing makes the widget API unwieldy and couples PlayerScreen to App's implementation details.
**Do this instead:** Consider an inherited widget or context-based approach for commonly-needed callbacks. Currently acceptable given the single-screen architecture.

### Mixed Layer Imports in UI

**What happens:** `lib/ui/player/player_screen.dart` imports from `../../kernel/` paths (cross-layer)
**Why it's wrong:** UI layer directly depends on kernel internals rather than going through a clean boundary.
**Do this instead:** Define UI-specific interfaces or use the existing abstract interfaces (MediaEngine) consistently.

## Error Handling

**Strategy:** Catch-and-log with graceful fallback. Never silent `catch (_) {}`.

**Patterns:**
- All engine operations wrapped in try/catch with `debugPrint` logging (`lib/kernel/engine/fvp_engine.dart`)
- `PlaybackNavigator.playIndex()` catches exceptions, restores previous index, calls `onError` callback (`lib/kernel/services/playback_navigator.dart:62-69`)
- `WindowService` catches all window operations individually, logs, continues (`lib/window/window_service.dart`)
- `WindowService` catches all window operations individually, logs, continues (`lib/window/window_service.dart`)
- `PathValidator.validate()` rejects unsafe paths before playback (`lib/kernel/services/path_validator.dart`)

## Cross-Cutting Concerns

**Logging:** `debugPrint()` throughout (never `print()`). Kernel layer uses `Log` utility in `lib/kernel/utils/log.dart`.
**Validation:** `PathValidator` for file path security. `clamp()` for numeric ranges in engine methods.
**Persistence:** `SharedPreferences` for settings (`lib/kernel/persistence/settings_store.dart`), JSON file for playlist history (`lib/kernel/persistence/playlist_store.dart`), window geometry via `GeometryStore` (`lib/window/geometry_store.dart`).
**Localization:** ARB-based via `flutter_localizations` + `AppLocalizations` (`lib/l10n/`). Chinese (zh) and English (en) supported.
**Design System:** Compile-time const tokens in `lib/kernel/ui/theme/tokens.dart`. Glassmorphism via `GlassContainer` (`lib/ui/shared/glass_container.dart`).

---

*Architecture analysis: 2026-05-23*
