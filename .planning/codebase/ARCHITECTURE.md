<!-- refreshed: 2026-07-03 -->
# Architecture

**Analysis Date:** 2026-07-03

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        App Shell (`lib/app.dart`)                    │
│  MaterialApp + Theme + Locale + Settings Panel + Right-click menu    │
├─────────────────────────────────────────────────────────────────────┤
│                  DeferredPlayerFeature (deferred load)               │
│                  `lib/features/player/deferred_player_feature.dart`  │
├─────────────────────────────────────────────────────────────────────┤
│                     PlayerFeature (UI state + callbacks)             │
│                     `lib/features/player/player_feature.dart`        │
├────────────────────────────────────┬────────────────────────────────┤
│        PlayerScreen (compose)      │      PlayerServices (DI)       │
│   `lib/ui/player/player_screen.dart`│ `lib/features/player/player_services.dart`│
├────────────────────────────────────┴────────────────────────────────┤
│                        UI Layer (`lib/ui/`)                          │
│  player/ │ playlist/ │ shared/ │ dialogs/ │ theme/ │ window/        │
├─────────────────────────────────────────────────────────────────────┤
│                     Feature Services (`lib/features/player/services/`)│
│  PlaybackController → PlaybackNavigator, FileOperations, StateMonitor│
├─────────────────────────────────────────────────────────────────────┤
│                        Kernel Layer (`lib/kernel/`)                  │
│  engine/ │ bridge/ │ models/ │ persistence/ │ playlist/ │ services/ │
│  scanner/│ startup/│ utils/                                         │
├─────────────────────────────────────────────────────────────────────┤
│              External: fvp (MDK/FFmpeg) + window_manager + Win32     │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App | MaterialApp shell, theme/locale wiring, settings panel trigger | `lib/app.dart` |
| DeferredPlayerFeature | Deferred library loading with progress reporting | `lib/features/player/deferred_player_feature.dart` |
| PlayerFeature | UI state management, file/drag callbacks, PlayerScreen composition | `lib/features/player/player_feature.dart` |
| PlayerViewModel | Extracted business logic from PlayerFeature (ChangeNotifier) | `lib/features/player/player_view_model.dart` |
| PlayerServices | Service container: engine + playlist + controller + videoProcessing | `lib/features/player/player_services.dart` |
| PlayerScreen | Main screen compositing: video surface + controls + playlist panel | `lib/ui/player/player_screen.dart` |
| ControlsOverlay | Auto-hide control layer with mouse/touch gesture handling | `lib/ui/player/controls_overlay.dart` |
| ControlBar | Bottom glass bar with playback controls (2-row layout) | `lib/ui/player/control_bar.dart` |
| PlaybackController | Unified playback API: orchestrates navigator + fileOps + monitor | `lib/features/player/services/playback_controller.dart` |
| PlaybackNavigator | Index-based track navigation with openGeneration concurrency guard | `lib/features/player/services/playback_navigator.dart` |
| FileOperations | File open/add with PathValidator security checks | `lib/features/player/services/file_operations.dart` |
| StateMonitor | Auto-advance, breakpoint save, settings restore on engine state changes | `lib/features/player/services/state_monitor.dart` |
| FvpEngine | fvp/MDK engine wrapper exposing ValueNotifier interface | `lib/kernel/engine/fvp_engine.dart` |
| EngineState | Abstract mixin defining all reactive playback state (ValueNotifiers) | `lib/kernel/engine/engine_state.dart` |
| WindowBridge | Abstract window management interface (4 state + 7 commands) | `lib/kernel/bridge/window_bridge.dart` |
| WindowService | Win32 window implementation using window_manager + fullscreen_window | `lib/kernel/bridge/window_service.dart` |
| WindowState | Pure state container for window mode/size/resizing/always-on-top | `lib/kernel/bridge/window_state.dart` |
| Playlist | State machine for ordered playlist with 4 play modes (CQS pattern) | `lib/kernel/playlist/playlist.dart` |
| SettingsStore | SharedPreferences persistence with prewarm caching | `lib/kernel/persistence/settings_store.dart` |
| PlaylistStore | JSON persistence with 300ms debounce + atomic write + Isolate load | `lib/kernel/persistence/playlist_store.dart` |
| StartupCoordinator | Multi-phase startup progress tracking with ValueNotifier broadcast | `lib/kernel/startup/startup_coordinator.dart` |
| Tokens | Compile-time design token constants (colors, spacing, radius, blur) | `lib/ui/theme/tokens.dart` |
| GlassContainer | Glassmorphism wrapper: BackdropFilter + 3-tier blur + resize skip | `lib/ui/shared/glass_container.dart` |

## Pattern Overview

**Overall:** Layered Architecture with ValueNotifier-based reactive state (MVVM-lite)

**Key Characteristics:**
- No Provider/Riverpod/Bloc -- pure ValueNotifier + ValueListenableBuilder throughout
- Kernel/Feature/UI 3-layer separation with clear dependency direction (UI -> Feature -> Kernel)
- Composition over inheritance: FvpEngine composed of 6 helpers, PlaybackController of 3 sub-modules
- Abstract interfaces (EngineState mixin, WindowBridge) enable test doubles
- Deferred loading for the player feature module to reduce startup time
- Single design system: all visual values via `Tokens.*` compile-time constants

## Layers

**Kernel Layer (`lib/kernel/`):**
- Purpose: Core logic with zero UI dependency
- Location: `lib/kernel/`
- Contains: Engine abstraction, window bridge, data models, persistence, playlist state machine, scanner, services, startup coordination, utilities
- Depends on: fvp, window_manager, fullscreen_window, shared_preferences, path_provider
- Used by: Feature layer, UI layer

**Feature Layer (`lib/features/player/`):**
- Purpose: Player-specific business logic and service orchestration
- Location: `lib/features/player/`
- Contains: PlayerFeature widget, PlayerServices container, PlaybackController, PlaybackNavigator, FileOperations, StateMonitor, SubtitleService, VideoProcessingService
- Depends on: Kernel layer
- Used by: UI layer, App shell

**UI Layer (`lib/ui/`):**
- Purpose: All visual components, no business logic
- Location: `lib/ui/`
- Contains: Player screen components, playlist panel, shared glass widgets, dialogs, design tokens, window title bar
- Depends on: Kernel models/state interfaces (EngineState, WindowBridge, Playlist)
- Used by: Feature layer (PlayerFeature composes PlayerScreen)

**App Shell (`lib/app.dart`, `lib/main.dart`):**
- Purpose: Bootstrap, MaterialApp wiring, settings panel trigger
- Location: `lib/main.dart`, `lib/app.dart`
- Contains: main() entry point, App StatefulWidget, DeferredPlayerFeature
- Depends on: All layers
- Used by: Flutter framework

## Data Flow

### Primary Playback Request Path

1. User opens file via FilePicker or drag-drop (`lib/features/player/player_feature.dart:99`)
2. PlayerFeature calls `controller.openAndPlay(path)` (`lib/features/player/player_feature.dart:122`)
3. FileOperations validates path via PathValidator (`lib/features/player/services/file_operations.dart:19`)
4. PlaybackNavigator.playIndex() calls `engine.open(path)` (`lib/features/player/services/playback_navigator.dart:40`)
5. FvpEngine.open() delegates to MediaOpener (`lib/kernel/engine/media_opener.dart:44`)
6. MediaOpener validates, configures network/buffer, calls mdk prepare (`lib/kernel/engine/media_opener.dart:67-79`)
7. FvpCallbackHandler maps mdk state to MediaState ValueNotifier (`lib/kernel/engine/fvp_callback_handler.dart:36`)
8. PositionPoller starts polling position every 250ms (`lib/kernel/engine/position_poller.dart:78`)
9. UI rebuilds via ValueListenableBuilder on engine.state/position/duration

### Window State Flow

1. OS event (resize/maximize/close) arrives via WindowListener (`lib/kernel/bridge/window_service.dart:123`)
2. WindowService updates WindowState ValueNotifiers (`lib/kernel/bridge/window_service.dart:163`)
3. WindowPersistence debounces geometry save to SettingsStore (`lib/kernel/bridge/window_persistence.dart:27`)
4. UI listens to WindowState.mode/isResizing for blur skip and layout adaptation

### Auto-Advance Flow

1. Engine state transitions to `completed` (`lib/features/player/services/state_monitor.dart:51`)
2. StateMonitor checks PlayMode via playlist.next() (`lib/features/player/services/state_monitor.dart`)
3. PlaybackNavigator.playIndex() opens next track (`lib/features/player/services/playback_navigator.dart:23`)
4. PlaylistStore debounced save fires after 300ms (`lib/kernel/persistence/playlist_store.dart:24`)

**State Management:**
- All reactive state uses `ValueNotifier<T>` -- no streams, no ChangeNotifier (except PlayerViewModel)
- UI binds via `ValueListenableBuilder<T>` or `AnimatedBuilder` with `Listenable.merge([...])`
- Performance optimization: child caching in VLB, MergedListenable for multi-notifier widgets
- Resize-aware: `GlassContainer` skips BackdropFilter when `resizing.value == true`

## Key Abstractions

**EngineState (mixin):**
- Purpose: Abstract playback state interface -- UI depends on this, not FvpEngine
- Examples: `lib/kernel/engine/engine_state.dart`
- Pattern: Mixin with ValueNotifier fields + abstract methods. FvpEngine `with EngineState, TrackControl, VideoEffects, RendererConfig`
- Capability mixins (TrackControl, VideoEffects, RendererConfig) enable runtime type checks: `if (engine case VideoEffects ve) { ... }`

**WindowBridge (abstract class):**
- Purpose: Abstract window management -- 4 state notifiers + 7 command methods
- Examples: `lib/kernel/bridge/window_bridge.dart`
- Pattern: Interface with ValueNotifier getters. WindowService implements it; FakeWindowService for tests.

**PlayerProxy (abstract class):**
- Purpose: Abstract mdk.Player subset for helper classes (VolumeController, SubtitleConfigurator, D3D11Configurator)
- Examples: `lib/kernel/engine/player_proxy.dart`, `lib/kernel/engine/mdk_player_proxy.dart`
- Pattern: Adapter wrapping mdk.Player. Enables pure-Dart testing without FFI.

**Composition Pattern (FvpEngine):**
- FvpEngine is composed of 6 helper classes: FvpCallbackHandler, PositionPoller, TrackManager, MediaOpener, VideoEffectController, VolumeController, SubtitleConfigurator, D3D11Configurator
- Each helper has a single responsibility and can be tested independently
- FvpEngine delegates to helpers and exposes unified EngineState interface

**Composition Pattern (PlaybackController):**
- PlaybackController composes 3 sub-modules: PlaybackNavigator, FileOperations, StateMonitor
- UI layer only interacts with PlaybackController (facade pattern)
- Sub-modules access shared state via `_controller` reference

## Entry Points

**Main Entry:**
- Location: `lib/main.dart`
- Triggers: Flutter framework calls `main()`
- Responsibilities: WidgetsFlutterBinding init, log init, MemoryMonitor start, SettingsStore prewarm, WindowService init, EnginePrewarm (fire-and-forget), runApp(App(...))

**App Shell:**
- Location: `lib/app.dart`
- Triggers: runApp() from main.dart
- Responsibilities: MaterialApp creation, theme/locale init, DeferredPlayerFeature composition, settings panel trigger

**Player Feature:**
- Location: `lib/features/player/deferred_player_feature.dart`
- Triggers: First build of App widget
- Responsibilities: Deferred library loading with progress, then delegates to PlayerFeature

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop. Platform callbacks (WindowListener) may arrive on platform thread; WindowService uses `_updateOnUIThread()` to schedule ValueNotifier updates safely. PlaylistStore uses Isolate for background JSON loading.
- **Global state:** SettingsStore uses static `_instance` singleton with prewarm pattern. PlaylistStore uses static `_instance`. LocaleService and ThemeService are singletons. OsdService is a singleton.
- **Circular imports:** None detected. Dependency direction is strictly: UI -> Feature -> Kernel.
- **Deferred loading:** PlayerFeature is loaded via `deferred as` to avoid eager import of heavy FvpEngine types. All callbacks use abstract `EngineState` type.
- **No third-party state management:** No Provider, Riverpod, Bloc, or GetX. Pure ValueNotifier + ValueListenableBuilder.

## Anti-Patterns

### Static Singleton Pre-warm

**What happens:** SettingsStore, PlaylistStore, LocaleService, ThemeService use static `_instance` with `prewarm()` or lazy initialization
**Why it's wrong:** Creates hidden global state, makes testing harder (requires `resetPrewarm()`)
**Do this instead:** New services should use constructor injection. Existing singletons provide `@visibleForTesting resetPrewarm()` as mitigation.

### Debug Dump in Production Path

**What happens:** `player_feature.dart:182` calls `debugDumpApp()` in a post-frame callback
**Why it's wrong:** debugDumpApp outputs the entire widget tree to console on every build -- expensive and noisy
**Do this instead:** Remove or gate behind `kDebugMode` flag

## Error Handling

**Strategy:** Defensive catch with `debugPrint`/`log` + graceful fallback. Never silent `catch (_) {}`.

**Patterns:**
- Engine errors surface via `engine.errorMessage` ValueNotifier -- UI shows ErrorBanner
- File validation via `PathValidator.validate()` returns nullable error string
- PlaybackNavigator uses `openGeneration` guard to discard stale async results
- PlaylistStore uses atomic write (`.tmp` + rename) with 3-retry exponential backoff
- SettingsStore load failure returns safe defaults, never crashes

## Cross-Cutting Concerns

**Logging:** Custom `Log` class (`lib/kernel/utils/log.dart`) with `log.d()`, `log.i()`, `log.w()`, `log.e()`. Category loggers: `logBridge`, `logEngine`.
**Validation:** PathValidator (`lib/kernel/services/path_validator.dart`) for file path security. SettingsValidator (`lib/kernel/persistence/settings_validator.dart`) for settings geometry bounds.
**Authentication:** Not applicable (local desktop app).
**Performance Monitoring:** PerfMonitor (`lib/kernel/utils/perf_monitor.dart`), DebugProbe (`lib/kernel/utils/debug_probe.dart`), MemoryMonitor (`lib/kernel/utils/memory_monitor.dart`).

---

*Architecture analysis: 2026-07-03*
