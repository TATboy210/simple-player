<!-- refreshed: 2026-05-09 -->
# Architecture

**Analysis Date:** 2026-05-09

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                          lib/app.dart                               │
│                    MaterialApp + Service Wiring                      │
├─────────────────────────┬───────────────────────────────────────────┤
│   lib/kernel/services/  │           lib/kernel/engine/              │
│  PlaybackController     │           FvpEngine (MediaEngine)         │
│  (3-mixin orchestrator) │           FvpCallbackHandler              │
│  ├─ FileOperations      │           PositionPoller                  │
│  ├─ PlaybackNavigator   │           TrackManager                   │
│  └─ StateMonitor        │                                          │
│  VideoProcessingService │                                          │
│  PlatformService (abs)  │                                          │
└───────────┬─────────────┴───────────────┬───────────────────────────┘
            │                             │
            ▼                             ▼
┌───────────────────────┐   ┌──────────────────────────────────────────┐
│  lib/kernel/persistence/ │ │  lib/kernel/playlist/                    │
│  SettingsStore          │ │  Playlist (state machine)                 │
│  PlaylistStore          │ │  4 play modes, CQS navigation            │
│  (shared_preferences)   │ │  JSON serialization                      │
│  (JSON atomic write)    │ │                                          │
└─────────────────────────┘ └──────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     lib/kernel/models/                               │
│  MediaState · MediaInfo · PlaylistItem · PlayMode                    │
│  VideoEffectType · AspectRatioMode                                   │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App | Material shell, service wiring, locale/theme init | `lib/app.dart` |
| FvpEngine | MediaEngine implementation wrapping fvp/MDK | `lib/kernel/engine/fvp_engine.dart` |
| FvpCallbackHandler | mdk callback registration, state mapping, main-thread scheduling | `lib/kernel/engine/fvp_callback_handler.dart` |
| PositionPoller | 250ms timer polling playback position/buffered | `lib/kernel/engine/position_poller.dart` |
| TrackManager | Audio/subtitle track selection and switching | `lib/kernel/engine/track_manager.dart` |
| PlaybackController | Business orchestrator (3-mixin composition) | `lib/kernel/services/playback_controller.dart` |
| FileOperations | File open (validate -> add to list -> play) | `lib/kernel/services/file_operations.dart` |
| PlaybackNavigator | Playlist navigation (prev/next/playIndex) | `lib/kernel/services/playback_navigator.dart` |
| StateMonitor | Auto-advance, breakpoint save, settings restore | `lib/kernel/services/state_monitor.dart` |
| VideoProcessingService | 7 ValueNotifiers for video effects, delegates to engine | `lib/kernel/services/video_processing_service.dart` |
| PlatformService | Abstract platform interface (singleton factory) | `lib/kernel/services/platform_service.dart` |
| WindowsPlatformService | No-op implementation (OS provides native window) | `lib/kernel/platform/windows_platform_service.dart` |
| LinuxPlatformService | No-op implementation (GTK native window) | `lib/kernel/platform/linux_platform_service.dart` |
| Playlist | Playlist state machine (4 play modes, CQS navigation) | `lib/kernel/playlist/playlist.dart` |
| SettingsStore | SharedPreferences persistence (prewarm, sanitize) | `lib/kernel/persistence/settings_store.dart` |
| PlaylistStore | JSON atomic write with 300ms debounce | `lib/kernel/persistence/playlist_store.dart` |
| PathValidator | Path security: extension whitelist, traversal detection | `lib/kernel/utils/path_validator.dart` |
| PathUtils | Cross-platform basename/dirname extraction | `lib/kernel/utils/path_utils.dart` |
| TimeUtils | Milliseconds to HH:MM:SS formatting | `lib/kernel/utils/time_utils.dart` |
| MotionUtils | Reduced-motion accessibility adapter | `lib/kernel/utils/motion_utils.dart` |
| log | Kernel-wide Logger instance (PrettyPrinter) | `lib/kernel/utils/log.dart` |
| Tokens | Design tokens (colors, fonts, spacing, glass, animation) | `lib/kernel/ui/theme/tokens.dart` |
| AppTheme | ThemeData bridge from Tokens | `lib/kernel/ui/theme/app_theme.dart` |

## Pattern Overview

**Overall:** Layered architecture with Interface Segregation + Mixin Composition

**Key Characteristics:**
- **ValueNotifier + ValueListenableBuilder** for reactive state (no Provider/Riverpod/Bloc)
- **MediaEngine** abstract interface decouples UI from fvp/MDK implementation
- **PlaybackController** uses Dart mixins (`with FileOperations, PlaybackNavigator, StateMonitor`) to separate concerns while sharing state
- **Singleton factory** pattern for PlatformService (`PlatformService.init()` in main, `PlatformService.I` everywhere)
- **CQS (Command-Query Separation)** in Playlist: `peekNext()`/`peekPrevious()` are pure queries, callers update `currentIndex` explicitly
- **Defensive programming**: `_disposed` guards on every engine method, `clamp()` on all inputs, try-catch with `log.d()` fallbacks
- **No external state management**: pure Flutter primitives (ValueNotifier, ValueListenableBuilder, setState)

## Layers

**Entry Layer:**
- Purpose: Bootstrap Flutter app, initialize fvp/MDK, set up platform service
- Location: `lib/main.dart`
- Contains: `fvp.registerWith()`, `SettingsStore.prewarm()`, `PlatformService.init()`, `runApp()`
- Depends on: SettingsStore, PlatformService, App
- Used by: Flutter runtime

**Application Shell:**
- Purpose: Material shell with theme, locale, engine/playlist/controller wiring
- Location: `lib/app.dart`
- Contains: `App` StatefulWidget, creates `FvpEngine`, `Playlist`, `PlaybackController`
- Depends on: FvpEngine, Playlist, PlaybackController, AppTheme, AppLocalizations
- Used by: main.dart

**Engine Layer:**
- Purpose: Abstract media playback interface + fvp/MDK concrete implementation
- Location: `lib/kernel/engine/`
- Contains: `MediaEngine` (abstract), `FvpEngine` (impl), 3 helpers (FvpCallbackHandler, PositionPoller, TrackManager)
- Depends on: fvp/mdk, models, utils
- Used by: PlaybackController, VideoProcessingService, UI widgets

**Service Layer:**
- Purpose: Business orchestration — file operations, playback navigation, state monitoring
- Location: `lib/kernel/services/`
- Contains: PlaybackController (mixin composition), PlatformService (abstract), VideoProcessingService
- Depends on: Engine, Playlist, Persistence, Utils
- Used by: App, UI widgets

**Persistence Layer:**
- Purpose: Settings and playlist persistence
- Location: `lib/kernel/persistence/`
- Contains: SettingsStore (shared_preferences), PlaylistStore (JSON file with atomic write)
- Depends on: shared_preferences, path_provider, models
- Used by: StateMonitor, SettingsDialog, App

**Playlist Layer:**
- Purpose: Playlist state machine with play mode navigation
- Location: `lib/kernel/playlist/`
- Contains: Playlist class (add/remove/reorder, 4 play modes, JSON serialization)
- Depends on: models
- Used by: PlaybackController, PlaylistStore

**Model Layer:**
- Purpose: Pure data classes and enums, no business logic
- Location: `lib/kernel/models/`
- Contains: MediaState, MediaInfo, PlaylistItem, PlayMode, VideoEffectType, AspectRatioMode
- Depends on: utils (PathUtils only for PlaylistItem.name)
- Used by: All layers

**Platform Layer:**
- Purpose: Platform-specific service implementations
- Location: `lib/kernel/platform/`
- Contains: WindowsPlatformService, LinuxPlatformService (both no-op)
- Depends on: PlatformService interface
- Used by: main.dart (init)

**Utils Layer:**
- Purpose: Shared utilities — logging, path validation, time formatting
- Location: `lib/kernel/utils/`
- Contains: log (Logger), PathValidator, PathUtils, TimeUtils, MotionUtils
- Depends on: logger package
- Used by: Engine, Services, Playlist, Models

**Theme Layer:**
- Purpose: Design tokens and ThemeData bridge
- Location: `lib/kernel/ui/theme/`
- Contains: Tokens (compile-time constants), AppTheme (ThemeData builder)
- Depends on: flutter/material
- Used by: App, UI widgets

**L10n Layer:**
- Purpose: Internationalization (zh/en)
- Location: `lib/l10n/`
- Contains: AppLocalizations, AppLocalizationsEn, AppLocalizationsZh
- Depends on: flutter_localizations
- Used by: App, UI widgets

## Data Flow

### Primary Request Path: Open and Play File

1. User triggers file open (keyboard O / FilePicker / drag-drop) -> UI calls `PlaybackController.openAndPlay(path)` (`lib/kernel/services/file_operations.dart:29`)
2. `PathValidator.validate(path)` checks extension whitelist + path traversal (`lib/kernel/utils/path_validator.dart:64`)
3. `Playlist.add(path)` appends item, returns index (`lib/kernel/playlist/playlist.dart:81`)
4. `PlaybackNavigator.playIndex(idx)` called (`lib/kernel/services/playback_navigator.dart:30`)
5. Path validated again, `playlist.currentIndex = index` set (`lib/kernel/services/playback_navigator.dart:49`)
6. `engine.open(path)` -> `FvpEngine.open()` sets media, calls `_player.prepare()`, reads mediaInfo, creates texture (`lib/kernel/engine/fvp_engine.dart:137`)
7. Resume from saved position if `positionMs > 1000` (`lib/kernel/services/playback_navigator.dart:60`)
8. Auto-detect external subtitles in same directory (`lib/kernel/services/playback_navigator.dart:107`)
9. `engine.play()` -> sets mdk.PlaybackState.playing, starts PositionPoller 250ms timer (`lib/kernel/engine/fvp_engine.dart:276`)
10. `currentFileName` notifier updated, `playlist.updateHistory()` called, `savePlaylist()` persists (`lib/kernel/services/playback_navigator.dart:77-83`)

### Auto-Advance Flow: Track Completes

1. mdk fires `onMediaStatus` with `end` flag -> `FvpCallbackHandler` sets `state = MediaState.completed` (`lib/kernel/engine/fvp_callback_handler.dart:66`)
2. `StateMonitor._onStateChanged()` detects completed state (`lib/kernel/services/state_monitor.dart:73`)
3. If `loopSingle` mode: `playIndex(currentIndex)` replays same track (`lib/kernel/services/state_monitor.dart:78`)
4. Otherwise: `playNext()` -> `Playlist.peekNext()` calculates next index based on play mode (`lib/kernel/playlist/playlist.dart:217`)
5. `playIndex(nextIndex)` opens next track (same flow as primary request from step 4)

### State Persistence Flow: Pause/Exit

1. Pause detected in `StateMonitor._onStateChanged()`: saves breakpoint position to playlist item (`lib/kernel/services/state_monitor.dart:60-70`)
2. On `dispose()`: saves current position, volume, muted state, play mode to SettingsStore (`lib/kernel/services/state_monitor.dart:131-147`)
3. `PlaylistStore.save(playlist)` serializes to JSON, 300ms debounce, atomic write (.tmp rename) (`lib/kernel/persistence/playlist_store.dart:44-77`)
4. `SettingsStore.saveVolume/saveIsMuted` write individual keys to SharedPreferences (`lib/kernel/persistence/settings_store.dart:182-216`)

### Video Effect Flow: User Adjusts Brightness

1. UI updates `VideoProcessingService.brightness.value` (`lib/kernel/services/video_processing_service.dart:57`)
2. Listener calls `engine.setVideoEffect(VideoEffectType.brightness, value)` (`lib/kernel/services/video_processing_service.dart:57`)
3. `FvpEngine._guardedAction` clamps value, maps to mdk.VideoEffect, calls `_player.setVideoEffect()` (`lib/kernel/engine/fvp_engine.dart:486-496`)
4. 50ms debounce persists to SettingsStore (`lib/kernel/services/video_processing_service.dart:72-75`)

**State Management:**
- **ValueNotifier** is the sole reactive primitive. Engine exposes 13 ValueNotifiers. Services add their own (e.g., VideoProcessingService has 7). `ValueListenableBuilder` in UI binds to these.
- **No global state container.** Each service holds its own notifiers. PlaybackController shares state via mixin `get` declarations.
- **Playlist** is a mutable state machine. Its `items` getter returns `List.unmodifiable` to prevent external mutation.

## Key Abstractions

**MediaEngine:**
- Purpose: Abstract media playback interface decoupled from fvp/MDK
- Examples: `lib/kernel/engine/media_engine.dart` (interface), `lib/kernel/engine/fvp_engine.dart` (impl)
- Pattern: Interface with 13 ValueNotifiers for state, command methods (play/pause/seek), query methods (getAudioTracks/mediaInfo)

**PlaybackController (Mixin Composition):**
- Purpose: Business orchestration combining file ops, navigation, and state monitoring
- Examples: `lib/kernel/services/playback_controller.dart` (composition), `lib/kernel/services/file_operations.dart`, `lib/kernel/services/playback_navigator.dart`, `lib/kernel/services/state_monitor.dart` (mixins)
- Pattern: Concrete class `with` 3 mixins. Each mixin declares abstract `get` for shared state (engine, playlist, currentFileName). Controller provides concrete fields.

**PlatformService (Singleton Factory):**
- Purpose: Platform abstraction for window management
- Examples: `lib/kernel/services/platform_service.dart` (interface + static singleton), `lib/kernel/platform/windows_platform_service.dart`, `lib/kernel/platform/linux_platform_service.dart`
- Pattern: `PlatformService.init(impl)` in main(), `PlatformService.I` accessor elsewhere. `@visibleForTesting static reset()` for test isolation.

**Playlist (State Machine):**
- Purpose: Ordered list with 4 play modes and CQS navigation
- Examples: `lib/kernel/playlist/playlist.dart`
- Pattern: `peekNext()`/`peekPrevious()` return index without modifying state. Caller sets `currentIndex` explicitly. `List.unmodifiable` for external access.

## Entry Points

**App Entry:**
- Location: `lib/main.dart`
- Triggers: Flutter runtime `runApp()`
- Responsibilities: fvp registration, SharedPreferences prewarm, PlatformService init, launch App widget

**App Shell:**
- Location: `lib/app.dart`
- Triggers: `runApp(App(...))`
- Responsibilities: Create FvpEngine, Playlist, PlaybackController. Init services in parallel (`Future.wait`). Build MaterialApp with theme/locale.

**File Open:**
- Location: `lib/kernel/services/file_operations.dart:29` (`openAndPlay`)
- Triggers: Keyboard O, FilePicker dialog, drag-drop
- Responsibilities: Validate path, add to playlist, trigger playIndex

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. mdk callbacks dispatched to main thread via `SchedulerBinding.instance.addPostFrameCallback`. Position polling via `Timer.periodic(250ms)`.
- **Global state:** `SettingsStore._cachedPrefs` (prewarmed SharedPreferences), `PlaylistStore` static debounce/write-in-flight state, `PlatformService._instance` singleton, `MotionUtils._reducedMotion` flag, `log` global Logger instance.
- **Circular imports:** None detected. All imports flow downward: services -> engine -> models <- utils.
- **Mixin coupling:** PlaybackController mixins share state via abstract `get` declarations. Mixins call each other's methods (e.g., `StateMonitor` calls `playIndex` from `PlaybackNavigator`). This is by design but means mixins cannot be used independently.
- **No UI in kernel:** `lib/kernel/` contains no Flutter widgets (only theme tokens/ThemeData). UI widgets are expected outside kernel (currently missing from tree — see CONCERNS.md).

## Anti-Patterns

### Missing UI Layer

**What happens:** The `lib/kernel/` directory contains engine, services, models, persistence, playlist, and theme — but no actual Flutter widgets. The CLAUDE.md references widgets like `control_bar.dart`, `progress_bar.dart`, `player_screen.dart` that do not exist in the current codebase.
**Why it's wrong:** The architecture is incomplete — there is no visible UI consuming the kernel services.
**Do this instead:** Create `lib/ui/` with screens and widgets that use `ValueListenableBuilder` to bind to engine/service ValueNotifiers. Reference CLAUDE.md for the expected widget structure.

### Deprecated Model/Utils Directories

**What happens:** `lib/models/` and `lib/utils/` exist at the top level alongside `lib/kernel/`. These appear to be deprecated locations being migrated into `lib/kernel/models/` and `lib/kernel/utils/`.
**Why it's wrong:** Two locations for the same concern creates confusion about canonical source.
**Do this instead:** Use only `lib/kernel/models/` and `lib/kernel/utils/`. Remove top-level duplicates after confirming no imports remain.

## Error Handling

**Strategy:** Defensive programming with try-catch + log.d() + graceful fallback. Never crash, never silently swallow.

**Patterns:**
- **Guard Clause:** Every FvpEngine method checks `_disposed` before proceeding (`lib/kernel/engine/fvp_engine.dart:124-132`)
- **_guardedAction:** Generic wrapper for engine methods — try-catch + log + set errorMessage ValueNotifier (`lib/kernel/engine/fvp_engine.dart:124-132`)
- **Validation at boundary:** PathValidator checks at file open entry points, not deep in engine (`lib/kernel/utils/path_validator.dart:64`)
- **Sanitize persistence:** SettingsStore clamps all values on load, sanitizes NaN/Infinity for window geometry (`lib/kernel/persistence/settings_store.dart:83-104`)
- **Atomic write:** PlaylistStore writes .tmp then renames to prevent corruption (`lib/kernel/persistence/playlist_store.dart:51-77`)
- **Corrupted data tolerance:** Playlist.fromJson skips individual corrupt items, PlaylistStore.load catches all exceptions and returns null (`lib/kernel/playlist/playlist.dart:288-295`, `lib/kernel/persistence/playlist_store.dart:82-100`)

## Cross-Cutting Concerns

**Logging:** `log` global instance from `lib/kernel/utils/log.dart` using `logger` package PrettyPrinter. Debug-only (default filter). Used as `log.d()` throughout kernel.
**Validation:** PathValidator at all file entry points. SettingsStore sanitizes all loaded values. Playlist clamps indices.
**Authentication:** Not applicable (local desktop app).
**Localization:** `flutter_localizations` + `AppLocalizations` generated from ARB files. zh/en supported. Default locale 'zh'.
**Accessibility:** MotionUtils adapts animations when `AccessibilityFeatures.disableAnimations` is true (`lib/kernel/utils/motion_utils.dart`).

---

*Architecture analysis: 2026-05-09*
