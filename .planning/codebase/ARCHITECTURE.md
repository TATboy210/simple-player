<!-- refreshed: 2026-06-23 -->
# Architecture

**Analysis Date:** 2026-06-23

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI Layer                                    │
│   PlayerScreen │ ControlsOverlay │ PlaylistPanel │ SettingsPanel          │
│   `lib/ui/`                                                             │
├────────────────────────────────────┬────────────────────────────────────┤
│         Feature Layer              │         Shared Widgets              │
│   PlayerFeature                    │   GlassContainer │ OsdOverlay       │
│   `lib/features/player/`           │   `lib/ui/shared/`                  │
├────────────────────────────────────┴────────────────────────────────────┤
│                           Service Layer                                   │
│   PlaybackController │ PlaybackNavigator │ StateMonitor                   │
│   `lib/features/player/services/`                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                            Kernel Layer                                   │
│   ┌─────────────┐ ┌─────────────┐ ┌──────────────┐ ┌─────────────────┐  │
│   │   Engine     │ │   Bridge    │ │  Persistence │ │    Models       │  │
│   │ FvpEngine    │ │ WindowService│ │ SettingsStore│ │ PlaylistItem    │  │
│   │ `engine/`    │ │ `bridge/`   │ │ `persistence/`│ │ `models/`      │  │
│   └─────────────┘ └─────────────┘ └──────────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│  fvp/MDK SDK    │  │  window_manager │
│  (FFmpeg+D3D11) │  │  (Win32/macOS)  │
└─────────────────┘  └─────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App | MaterialApp shell, theme/locale, settings panel | `lib/app.dart` |
| DeferredPlayerFeature | Lazy-loads PlayerFeature via `deferred as` | `lib/features/player/deferred_player_feature.dart` |
| PlayerFeature | UI state, file picker, drag-drop, composes PlayerScreen | `lib/features/player/player_feature.dart` |
| PlayerServices | Service container: engine + playlist + controller lifecycle | `lib/features/player/player_services.dart` |
| PlaybackController | Unified entry for all playback operations | `lib/features/player/services/playback_controller.dart` |
| PlaybackNavigator | Index navigation, open generation guard, resume position | `lib/features/player/services/playback_navigator.dart` |
| StateMonitor | Auto-advance, breakpoint save, settings restore | `lib/features/player/services/state_monitor.dart` |
| FvpEngine | fvp/MDK wrapper, ValueNotifier state, D3D11 config | `lib/kernel/engine/fvp_engine.dart` |
| WindowService | Window management, OS callbacks, fullscreen, persistence | `lib/kernel/bridge/window_service.dart` |
| WindowBridge | Abstract window interface for testability | `lib/kernel/bridge/window_bridge.dart` |
| FullscreenController | Atomic fullscreen + mutex + rollback | `lib/kernel/bridge/fullscreen_controller.dart` |
| Playlist | Ordered item list, CQS navigation, JSON serialization | `lib/kernel/playlist/playlist.dart` |
| SettingsStore | SharedPreferences persistence, prewarm cache | `lib/kernel/persistence/settings_store.dart` |
| PathValidator | Path security: extension whitelist, traversal detection | `lib/kernel/services/path_validator.dart` |

## Pattern Overview

**Overall:** Layered architecture with ValueNotifier-based reactive state

**Key Characteristics:**
- 4-layer separation: Kernel (engine/bridge/models) -> Service (playback orchestration) -> Feature (UI state + composition) -> UI (widgets)
- ValueNotifier + ValueListenableBuilder for all reactive state (no Provider/Riverpod/Bloc)
- Abstract interfaces for platform dependencies (WindowBridge, PlatformFullscreen) enabling test doubles
- Composition over inheritance: PlaybackController composes 3 sub-modules via delegation
- Immutable data models with `copyWith()` pattern (PlaylistItem, AppSettings)
- CQS (Command-Query Separation) in Playlist navigation (peekNext/peekPrevious are pure queries)

## Layers

### Kernel Layer
- **Purpose:** Core logic with zero UI dependencies. Engine wrappers, platform bridge, data models, persistence.
- **Location:** `lib/kernel/`
- **Contains:** `engine/`, `bridge/`, `models/`, `persistence/`, `playlist/`, `scanner/`, `services/`, `startup/`, `utils/`
- **Depends on:** fvp SDK, window_manager, shared_preferences, ffi
- **Used by:** Feature layer, UI layer

### Feature Layer
- **Purpose:** Combines kernel services with UI state. Owns service lifecycle.
- **Location:** `lib/features/player/`
- **Contains:** `PlayerFeature` (StatefulWidget), `PlayerServices` (service container), `services/` (PlaybackController, PlaybackNavigator, StateMonitor, SubtitleService, VideoProcessingService, FileOperations)
- **Depends on:** Kernel layer
- **Used by:** UI layer via `DeferredPlayerFeature`

### UI Layer
- **Purpose:** Pure Flutter widgets. No business logic, only presentation.
- **Location:** `lib/ui/`
- **Contains:** `player/` (PlayerScreen, ControlBar, ProgressBar, KeyboardHandler), `playlist/` (PlaylistPanel, FolderTab, HistoryTab), `dialogs/` (SettingsPanel, MediaInfoDialog), `shared/` (GlassContainer, OsdOverlay, EmptyState), `theme/` (Tokens), `window/` (CustomTitleBar)
- **Depends on:** Feature layer (via callbacks), Kernel models
- **Used by:** App shell

## Data Flow

### Primary Playback Flow

1. **User opens file** -> `PlayerFeature._openFile()` -> `FilePicker.pickFiles()` (`lib/features/player/player_feature.dart:87`)
2. **Files added** -> `PlaybackController.openAndPlay(path)` -> `FileOperations.openAndPlay()` (`lib/features/player/services/playback_controller.dart:63`)
3. **Navigation** -> `PlaybackNavigator.playIndex(index)` -> validates path via `PathValidator.validate()` (`lib/features/player/services/playback_navigator.dart:21`)
4. **Engine open** -> `FvpEngine.open(path)` -> `_player.media = trimmed` -> `_player.prepare()` -> `_player.updateTexture()` (`lib/kernel/engine/fvp_engine.dart:248`)
5. **State update** -> `FvpEngine.state` ValueNotifier -> `StateMonitor._onStateChanged()` listens for auto-advance (`lib/features/player/services/state_monitor.dart:51`)
6. **UI rebuild** -> `ValueListenableBuilder<PlayerState>` in `ControlsOverlay` rebuilds control bar (`lib/ui/player/controls_overlay.dart`)

### State Propagation Pattern

```
FvpEngine (ValueNotifiers: state, position, volume, ...)
    │
    ├──► StateMonitor._onStateChanged()  [auto-advance, breakpoint save]
    ├──► ControlsOverlay (ValueListenableBuilder)  [UI controls]
    ├──► ProgressBar (MergedListenable)  [seek position]
    └──► VolumeControls (ValueListenableBuilder2)  [volume slider]
```

### Window Mode Flow

1. **User presses F** -> `KeyboardHandler` -> `PlayerActions.onToggleFullscreen` (`lib/ui/player/keyboard_handler.dart`)
2. **Action** -> `WindowService.setMode(WindowMode.fullscreen)` (`lib/kernel/bridge/window_service.dart:174`)
3. **FullscreenController.setFullscreen(true)** -> saves state -> `PlatformFullscreen.enter()` -> `Win32PlatformFullscreen` FFI (`lib/kernel/bridge/fullscreen_controller.dart:105`)
4. **State update** -> `WindowState.mode` ValueNotifier -> UI rebuilds (`lib/kernel/bridge/window_state.dart:23`)
5. **OS callback** -> `WindowService.onWindowMaximize()` drives mode from OS events (`lib/kernel/bridge/window_service.dart:120`)

## Key Abstractions

**PlayerEngine (abstract):**
- Purpose: Abstract engine interface for testability
- Concrete: `FvpEngine` (`lib/kernel/engine/fvp_engine.dart`)
- Test double: `FakeEngine` (`test/helpers/fake_engine.dart`)
- Pattern: ValueNotifiers for all state (state, position, volume, etc.)

**WindowBridge (abstract):**
- Purpose: Window management abstraction
- Concrete: `WindowService` (`lib/kernel/bridge/window_service.dart`)
- Test double: `FakeWindowService` (`test/helpers/fake_window_service.dart`)
- Pattern: 4 ValueNotifiers (mode, windowSize, isResizing, isAlwaysOnTop) + 6 commands

**PlatformFullscreen (abstract):**
- Purpose: Platform-specific fullscreen operations
- Concrete: `Win32PlatformFullscreen` (`lib/kernel/bridge/win32/win32_platform_fullscreen.dart`)
- Pattern: Returns `FullscreenSnapshot` for rollback on failure

## Entry Points

**main():**
- Location: `lib/main.dart`
- Triggers: Flutter app bootstrap
- Responsibilities: Init logging, prewarm SharedPreferences, create WindowService, create StartupCoordinator, fire-and-forget EnginePrewarm, runApp(App)

**App:**
- Location: `lib/app.dart`
- Triggers: runApp
- Responsibilities: MaterialApp shell, theme/locale via ValueListenableBuilder, DeferredPlayerFeature loading

**DeferredPlayerFeature:**
- Location: `lib/features/player/deferred_player_feature.dart`
- Triggers: App.build()
- Responsibilities: Lazy-loads PlayerFeature via Dart `deferred as` to avoid eager FvpEngine import

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. MDK/FFmpeg runs on native threads, callbacks dispatched to main isolate via FvpCallbackHandler. Position polling via Timer (250ms normal, 100ms after seek).
- **Global state:** Module-scoped loggers (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`) in `lib/kernel/utils/log.dart`. SettingsStore prewarm cache (`_cachedPrefs`). ThumbnailService singleton cache.
- **Circular imports:** None detected. Kernel does not import Feature/UI. Feature imports Kernel. UI imports Feature and Kernel models.
- **Platform coupling:** Win32-specific code isolated in `lib/kernel/bridge/win32/` and `PlatformFullscreen` interface. `window_manager` package abstracts cross-platform window ops.

## Design Patterns

### Observer Pattern (ValueNotifier)
All reactive state uses `ValueNotifier<T>` exposed as public fields. UI subscribes via `ValueListenableBuilder`. No event bus or streams for state propagation.

```dart
// FvpEngine exposes state
final ValueNotifier<MediaState> state = ValueNotifier<MediaState>(MediaState.idle);

// UI subscribes
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, child) => ...
)
```

### Composition Pattern (PlaybackController)
`PlaybackController` delegates to 3 sub-modules, each receiving `_rt` (the controller itself) as a back-reference:

```dart
class PlaybackController {
  late final PlaybackNavigator navigator;  // navigation logic
  late final FileOperations fileOps;       // file open/drop
  late final StateMonitor monitor;         // auto-advance, persistence
}
```

### Strategy Pattern (PlatformFullscreen)
Platform-specific fullscreen via abstract interface + DI:

```dart
abstract class PlatformFullscreen {
  Future<FullscreenSnapshot> enter();
  void exit(FullscreenSnapshot snapshot);
}
```

### Factory Pattern (ThumbnailService)
Platform-aware thumbnail provider selection:

```dart
_impl = switch (defaultTargetPlatform) {
  TargetPlatform.windows => const NoopThumbnailProvider(),
  TargetPlatform.linux => const LinuxThumbnailProvider(),
  TargetPlatform.macOS => const MacosThumbnailProvider(),
};
```

### Guard Pattern (openGeneration)
Concurrent open() requests are guarded by generation counter. Stale async results are discarded:

```dart
final gen = ++_openGeneration;
await engine.open(path);
if (gen != _openGeneration) return; // stale, discard
```

## Error Handling

**Strategy:** Catch at boundaries, log with context, expose via ValueNotifier, never crash.

**Patterns:**
- `_guardedAction(name, action)` in FvpEngine wraps every engine call with try-catch + `errorMessage` ValueNotifier
- `SettingsStore` load/save methods try-catch with safe defaults on failure
- `Playlist.fromJson` skips corrupted items with warning log
- `PathValidator.validate()` returns null (ok) or error string (never throws)
- All `dispose()` methods check `_disposed` flag to prevent double-dispose

## Cross-Cutting Concerns

**Logging:** Module-scoped `Logger` instances (`log`, `logEngine`, `logBridge`, `logServices`, `logUi`) via `package:logger`. Release mode adds rotating file output to `%APPDATA%\SimplePlayer\logs\`. (`lib/kernel/utils/log.dart`)

**Validation:** `PathValidator` validates all file paths at entry points (FilePicker, drag-drop, history). Checks: empty, extension whitelist, path traversal, control characters, URL format. (`lib/kernel/services/path_validator.dart`)

**Persistence:** `SettingsStore` (SharedPreferences) for app settings. `PlaylistStore` for playlist JSON. Both use defensive serialization with safe defaults.

**Design System:** All visual values via `Tokens.*` static constants. Glass-morphism via `GlassContainer` with 3 blur tiers (thin/normal/thick). (`lib/ui/theme/tokens.dart`, `lib/ui/shared/glass_container.dart`)

---

*Architecture analysis: 2026-06-23*
