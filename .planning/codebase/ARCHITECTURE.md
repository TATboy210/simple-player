<!-- refreshed: 2026-05-09 -->
# Architecture

**Analysis Date:** 2026-05-09

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                         App Shell                            │
│                      `lib/app.dart`                          │
├─────────────────────────────────────────────────────────────┤
│                    PlaybackController                        │
│              `lib/kernel/services/playback_controller.dart`  │
│        (Orchestrator — 3 mixins composed)                    │
├──────────────┬──────────────────┬────────────────────────────┤
│ FileOperations│ PlaybackNavigator│      StateMonitor          │
│ `file_ops`    │ `playback_nav`   │   `state_monitor`          │
└──────┬───────┴────────┬─────────┴──────────┬─────────────────┘
       │                │                     │
       ▼                ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      MediaEngine                             │
│               `lib/kernel/engine/media_engine.dart`          │
│              (abstract interface — 13 ValueNotifiers)        │
├─────────────────────────────────────────────────────────────┤
│                      FvpEngine                               │
│               `lib/kernel/engine/fvp_engine.dart`            │
│        (fvp/MDK implementation — FFmpeg + D3D11)             │
├──────────────┬──────────────────┬────────────────────────────┤
│FvpCallback   │  PositionPoller  │     TrackManager           │
│ Handler      │  (250ms timer)   │  (audio/subtitle tracks)   │
└──────────────┴──────────────────┴────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│                   Persistence Layer                          │
│         `lib/kernel/persistence/settings_store.dart`         │
│         `lib/kernel/persistence/playlist_store.dart`         │
│            (SharedPreferences + JSON files)                  │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `App` | App shell: engine/service init + MaterialApp skeleton | `lib/app.dart` |
| `PlaybackController` | Business orchestration: file ops, navigation, state monitoring | `lib/kernel/services/playback_controller.dart` |
| `FileOperations` mixin | File open, batch add, path validation | `lib/kernel/services/file_operations.dart` |
| `PlaybackNavigator` mixin | Index jump, prev/next, concurrency guard (openGeneration) | `lib/kernel/services/playback_navigator.dart` |
| `StateMonitor` mixin | Auto-advance, breakpoint save, settings restore, playlist management | `lib/kernel/services/state_monitor.dart` |
| `MediaEngine` | Abstract engine interface (13 ValueNotifiers + playback commands) | `lib/kernel/engine/media_engine.dart` |
| `FvpEngine` | fvp/MDK engine implementation (FFmpeg + D3D11 rendering) | `lib/kernel/engine/fvp_engine.dart` |
| `FvpCallbackHandler` | mdk callback registration, state mapping, main-thread dispatch | `lib/kernel/engine/fvp_callback_handler.dart` |
| `PositionPoller` | 250ms timer polling for playback position | `lib/kernel/engine/position_poller.dart` |
| `TrackManager` | Audio/subtitle track selection and switching | `lib/kernel/engine/track_manager.dart` |
| `Playlist` | Ordered playlist model with 4 play modes (CQS navigation) | `lib/kernel/playlist/playlist.dart` |
| `PlaylistItem` | Immutable data class (path + name + history metadata) | `lib/kernel/models/playlist_item.dart` |
| `VideoProcessingService` | Reactive video effects (brightness/contrast/saturation/hue/rotation/aspect) | `lib/kernel/services/video_processing_service.dart` |
| `SettingsStore` | SharedPreferences persistence (window/volume/mute/video settings) | `lib/kernel/persistence/settings_store.dart` |
| `PlaylistStore` | JSON file persistence (300ms debounce, atomic write) | `lib/kernel/persistence/playlist_store.dart` |
| `PlatformService` | Abstract platform interface (factory singleton) | `lib/kernel/services/platform_service.dart` |
| `Tokens` | Compile-time design constants (colors, spacing, fonts, radii) | `lib/kernel/ui/theme/tokens.dart` |
| `AppTheme` | ThemeData bridge from Tokens | `lib/kernel/ui/theme/app_theme.dart` |
| `PathValidator` | Security: extension whitelist, path traversal detection | `lib/kernel/utils/path_validator.dart` |

## Pattern Overview

**Overall:** Layered architecture with mixin composition for the business logic layer.

**Key Characteristics:**
- **ValueNotifier + ValueListenableBuilder** — no Provider/Riverpod/Bloc. All reactive state flows through `ValueNotifier` on `MediaEngine` and `VideoProcessingService`.
- **Mixin composition** — `PlaybackController` is assembled from 3 mixins (`FileOperations`, `PlaybackNavigator`, `StateMonitor`), each with a narrow responsibility.
- **Abstract engine interface** — `MediaEngine` is the contract. `FvpEngine` is the only production implementation. UI never touches fvp/mdk directly.
- **CQS (Command-Query Separation)** — `Playlist.peekNext()`/`peekPrevious()` are pure queries returning indices. State mutation happens only through explicit `currentIndex` setter.
- **Defensive programming** — All persistence uses clamp/sanitize. All engine methods check `_disposed`. All file paths go through `PathValidator`.
- **Debounced persistence** — `PlaylistStore` uses 300ms debounce + atomic write (`.tmp` then rename). `VideoProcessingService` uses 50ms debounce.

## Layers

**Entry Layer:**
- Purpose: Bootstrap and app shell
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: fvp registration, SharedPreferences prewarm, platform service init, MaterialApp setup
- Depends on: kernel layer
- Used by: Flutter framework

**Service Layer (Business Logic):**
- Purpose: Orchestrate playback operations
- Location: `lib/kernel/services/`
- Contains: `PlaybackController` + 3 mixins (`FileOperations`, `PlaybackNavigator`, `StateMonitor`), `VideoProcessingService`
- Depends on: Engine layer, Persistence layer, Models, Utils
- Used by: UI layer (widgets)

**Engine Layer:**
- Purpose: Abstract media playback backend
- Location: `lib/kernel/engine/`
- Contains: `MediaEngine` interface, `FvpEngine` implementation, 3 helpers (`FvpCallbackHandler`, `PositionPoller`, `TrackManager`)
- Depends on: fvp/mdk package, Models, Utils
- Used by: Service layer

**Model Layer:**
- Purpose: Data types and enums
- Location: `lib/kernel/models/`
- Contains: `MediaState` (9-state enum), `MediaInfo`, `PlaylistItem`, `PlayMode`, `AspectRatioMode`, `VideoEffectType`
- Depends on: Utils (PathUtils)
- Used by: All layers

**Persistence Layer:**
- Purpose: Settings and playlist storage
- Location: `lib/kernel/persistence/`
- Contains: `SettingsStore` (SharedPreferences), `PlaylistStore` (JSON files)
- Depends on: Models, shared_preferences, path_provider
- Used by: Service layer

**Platform Layer:**
- Purpose: Platform-specific behavior
- Location: `lib/kernel/platform/`
- Contains: `PlatformService` interface, `WindowsPlatformService`, `LinuxPlatformService`
- Depends on: Nothing (no-op implementations)
- Used by: Entry layer (init), Service layer (lifecycle)

**Theme Layer:**
- Purpose: Design tokens and ThemeData
- Location: `lib/kernel/ui/theme/`
- Contains: `Tokens` (compile-time constants), `AppTheme` (ThemeData bridge)
- Depends on: Flutter Material
- Used by: UI widgets

**Utils Layer:**
- Purpose: Pure utility functions
- Location: `lib/kernel/utils/`
- Contains: `PathValidator`, `PathUtils`, `TimeUtils`, `MotionUtils`, `log`
- Depends on: logger package
- Used by: All layers

**Localization Layer:**
- Purpose: i18n strings
- Location: `lib/l10n/`
- Contains: ARB files + generated Dart localizations (zh, en)
- Depends on: Flutter localizations
- Used by: UI widgets

## Data Flow

### Primary Playback Request Path

1. User action (file picker / drag-drop / keyboard) triggers `FileOperations.openAndPlay(path)` (`lib/kernel/services/file_operations.dart:29`)
2. `PathValidator.validate(path)` checks extension whitelist + path traversal (`lib/kernel/utils/path_validator.dart:64`)
3. `Playlist.add(path)` adds to list, returns index (`lib/kernel/playlist/playlist.dart:82`)
4. `PlaybackNavigator.playIndex(idx)` calls `engine.open(path)` (`lib/kernel/services/playback_navigator.dart:30`)
5. `FvpEngine.open(path)` sets media, calls `_player.prepare()`, waits for texture (`lib/kernel/engine/fvp_engine.dart:137`)
6. `FvpCallbackHandler` maps mdk state changes to `MediaEngine.state` ValueNotifier via `SchedulerBinding.addPostFrameCallback` (`lib/kernel/engine/fvp_callback_handler.dart:36`)
7. `PositionPoller.start()` begins 250ms polling loop (`lib/kernel/engine/position_poller.dart:39`)
8. `engine.play()` sets mdk playing state (`lib/kernel/engine/fvp_engine.dart:276`)
9. UI rebuilds via `ValueListenableBuilder` on `MediaEngine.state`, `position`, `duration`, etc.

### Auto-Advance Flow (StateMonitor)

1. `FvpCallbackHandler` detects `mdk.MediaStatus.end` → sets `state = MediaState.completed` (`lib/kernel/engine/fvp_callback_handler.dart:65`)
2. `StateMonitor._onStateChanged()` receives notification (`lib/kernel/services/state_monitor.dart:56`)
3. Checks `Playlist.mode`: `loopSingle` → replay current; otherwise → `playNext()` (`lib/kernel/services/state_monitor.dart:75-88`)
4. `PlaybackNavigator.playNext()` calls `Playlist.peekNext()` to get index (`lib/kernel/services/playback_navigator.dart:87`)

### Breakpoint Resume Flow

1. On pause: `StateMonitor._onStateChanged()` saves position via `Playlist.updatePosition()` + `PlaylistStore.save()` (`lib/kernel/services/state_monitor.dart:60-69`)
2. On play: `PlaybackNavigator.playIndex()` checks `current.positionMs`, if > 1000ms calls `engine.seekTo(savedMs)` (`lib/kernel/services/playback_navigator.dart:59-62`)

**State Management:**
- All reactive state uses `ValueNotifier` — no external state management packages
- `MediaEngine` exposes 13 `ValueNotifier`s: `textureId`, `state`, `position`, `duration`, `volume`, `isMuted`, `isBuffering`, `subtitleText`, `buffered`, `aspectRatio`, `errorMessage`, `playbackSpeed`, `activeDecoder`
- `VideoProcessingService` exposes 7 `ValueNotifier`s: `brightness`, `contrast`, `saturation`, `hue`, `deinterlaceEnabled`, `rotation`, `aspectRatioMode`
- `PlaybackController` adds `currentFileName` and `validationError` ValueNotifiers

## Key Abstractions

**MediaEngine (abstract interface):**
- Purpose: Decouple UI from playback backend (fvp/mdk). Enables testing with fake implementations.
- Pattern: Abstract class with ValueNotifier getters + command methods
- File: `lib/kernel/engine/media_engine.dart`

**PlaybackController (mixin composition):**
- Purpose: Single entry point for all playback business logic
- Pattern: Class with 3 mixins sharing state via abstract getters
- File: `lib/kernel/services/playback_controller.dart`

**PlatformService (factory singleton):**
- Purpose: Platform-specific behavior abstraction
- Pattern: `PlatformService.init(impl)` in main(), `PlatformService.I` everywhere
- File: `lib/kernel/services/platform_service.dart`

**Playlist (state machine with CQS):**
- Purpose: Ordered list + play mode navigation
- Pattern: `peekNext()`/`peekPrevious()` are pure queries; caller sets `currentIndex`
- File: `lib/kernel/playlist/playlist.dart`

## Entry Points

**App Entry:**
- Location: `lib/main.dart`
- Triggers: Flutter framework
- Responsibilities: Register fvp, prewarm SharedPreferences, init PlatformService, run App widget

**App Shell:**
- Location: `lib/app.dart`
- Triggers: `main()` → `runApp(App(...))`
- Responsibilities: Create FvpEngine, Playlist, PlaybackController; parallel init; MaterialApp with DynamicColor + locale

## Architectural Constraints

- **Threading:** Single-threaded (Dart event loop). mdk callbacks from native threads are dispatched to main thread via `SchedulerBinding.addPostFrameCallback` in `FvpCallbackHandler`.
- **Global state:** `SettingsStore._cachedPrefs` (SharedPreferences cache), `PlaylistStore` static state (debounce timer, pending JSON, write-in-flight), `PlatformService._instance` (singleton), `MotionUtils._reducedMotion` (static bool), `log` (global Logger instance).
- **Circular imports:** None detected. Layer dependency flows: Entry → Service → Engine → Models. Persistence and Utils are leaf dependencies.
- **Mixin coupling:** The 3 mixins (`FileOperations`, `PlaybackNavigator`, `StateMonitor`) share state via abstract getters declared in each mixin. `PlaybackController` provides the concrete implementations. This creates implicit coupling — all mixins must agree on the shared interface.

## Anti-Patterns

### Static Mutable State in Stores

**What happens:** `SettingsStore` and `PlaylistStore` use static methods with mutable static fields (`_cachedPrefs`, `_debounce`, `_pendingJson`, `_writeInFlight`).
**Why it's wrong:** Makes testing harder (requires `reset()` calls), prevents multiple instances, creates hidden global dependencies.
**Do this instead:** Consider constructor-injected store instances. Current code mitigates with `@visibleForTesting static void reset()` in both stores.

### Mixin Interface Contract

**What happens:** The 3 mixins in `PlaybackController` declare abstract getters (`engine`, `playlist`, `currentFileName`, etc.) that must match exactly.
**Why it's wrong:** If one mixin adds a new abstract member, compilation fails at the composing class, not at the mixin. The contract is implicit.
**Do this instead:** Extract a shared interface (`PlaybackContext` or similar) that all mixins implement, making the contract explicit. Current approach works but relies on convention.

## Error Handling

**Strategy:** Catch + log + graceful fallback. No exceptions propagate to UI.

**Patterns:**
- Engine methods: `_guardedAction()` wraps try-catch, sets `errorMessage` ValueNotifier, logs via `debugPrint` (`lib/kernel/engine/fvp_engine.dart:124-132`)
- Persistence: All `SettingsStore._save()` calls catch exceptions, log, and continue (`lib/kernel/persistence/settings_store.dart:173-180`)
- PlaylistStore: `_flush()` catches write errors, logs, completes future to unblock next write (`lib/kernel/persistence/playlist_store.dart:51-77`)
- Services: `StateMonitor.init()` catches settings load failure, continues with defaults (`lib/kernel/services/state_monitor.dart:37-43`)
- UI: App `_init()` catches all exceptions, continues (player works without saved settings) (`lib/app.dart:46-58`)

## Cross-Cutting Concerns

**Logging:** `logger` package via global `log` instance (`lib/kernel/utils/log.dart`). Uses `PrettyPrinter` with no method count, compact desktop output. Only logs in debug mode.
**Validation:** `PathValidator` for all file paths — extension whitelist, path traversal detection, null byte injection check (`lib/kernel/utils/path_validator.dart`).
**Persistence:** `SharedPreferences` for settings (key-value), JSON files for playlist (debounced + atomic). Window geometry sanitized against NaN/Infinity/negative values.
**Localization:** Flutter's built-in l10n with ARB files (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`). Default locale: Chinese (`zh`).
**Accessibility:** `MotionUtils` adapts animations when system `disableAnimations` is enabled (`lib/kernel/utils/motion_utils.dart`).

---

*Architecture analysis: 2026-05-09*
