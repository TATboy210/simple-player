# Codebase Structure

**Analysis Date:** 2026-05-23

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                    # Entry point (fvp init, window setup)
│   ├── app.dart                     # MaterialApp shell, service wiring
│   ├── kernel/                      # Core logic (no UI)
│   │   ├── bridge/                  # Abstract platform interfaces
│   │   ├── engine/                  # fvp/MDK engine wrapper
│   │   ├── models/                  # Data classes
│   │   ├── persistence/             # SharedPreferences + JSON storage
│   │   ├── platform/                # Platform detection utilities
│   │   ├── playlist/                # Playlist model + play mode logic
│   │   ├── scanner/                 # Directory video file scanner
│   │   ├── services/                # Business orchestration (mixins)
│   │   ├── ui/                      # Kernel-owned UI (theme, title bar, widgets)
│   │   ├── utils/                   # Shared utilities
│   │   └── window/                  # Window-specific kernel services
│   ├── l10n/                        # Localization (ARB + generated)
│   ├── models/                      # Top-level models (if any)
│   ├── ui/                          # UI layer
│   │   ├── dialogs/                 # Settings panel, media info dialog
│   │   │   └── settings/            # Settings tab components
│   │   ├── player/                  # Player screen components
│   │   ├── playlist/                # Immersive floating playlist
│   │   ├── shared/                  # Reusable UI components
│   │   └── widgets/                 # OSD overlay
│   ├── utils/                       # Top-level utilities
│   └── window/                      # Platform window management
├── test/
│   ├── helpers/                     # Test helpers (FakeEngine)
│   ├── kernel/                      # Kernel unit tests (mirrors lib/kernel/)
│   ├── unit/                        # Additional unit tests
│   ├── widget/                      # Widget tests
│   └── window/                      # Window service tests
├── windows/
│   ├── runner/                      # C++ Win32 window + Flutter engine
│   └── flutter/                     # Flutter Windows build artifacts
├── linux/                           # Linux platform files
├── macos/                           # macOS platform files
├── android/                         # Android platform files
├── ios/                             # iOS platform files
├── assets/
│   └── fonts/                       # Custom fonts
├── packaging/
│   └── linux/                       # Linux packaging (icons)
├── docs/                            # Documentation
├── production/
│   └── session-logs/                # Development session logs
└── .planning/                       # Planning documents
    └── codebase/                    # Codebase analysis docs
```

## Directory Purposes

**`lib/kernel/` (Core Logic):**
- Purpose: All non-UI business logic -- engine, models, persistence, services, playlist, utilities
- Contains: Abstract interfaces, concrete implementations, data classes, orchestrators
- Key files: `media_engine.dart`, `fvp_engine.dart`, `playback_controller.dart`, `playlist.dart`, `settings_store.dart`

**`lib/kernel/engine/` (Engine):**
- Purpose: Media engine abstraction and fvp/MDK implementation
- Contains: `MediaEngine` (abstract), `FvpEngine` (concrete), `PositionPoller`, `TrackManager`, `FvpCallbackHandler`, `EnginePrewarm`
- Key files: `lib/kernel/engine/media_engine.dart`, `lib/kernel/engine/fvp_engine.dart`

**`lib/kernel/services/` (Services):**
- Purpose: Business orchestration via mixin composition
- Contains: `PlaybackController` (orchestrator), `FileOperations`, `PlaybackNavigator`, `StateMonitor`, `VideoProcessingService`, `ThumbnailService`, `SubtitleService`, `PathValidator`, platform-specific thumbnail providers
- Key files: `lib/kernel/services/playback_controller.dart`, `lib/kernel/services/playback_navigator.dart`

**`lib/kernel/models/` (Models):**
- Purpose: Pure data classes and enums
- Contains: `PlaylistItem`, `MediaState`, `MediaInfo`, `PlayMode`, `PlayerError`, `MediaErrorType`, `VideoEffectType`, `AspectRatioMode`, `ValidationError`
- Key files: `lib/kernel/models/playlist_item.dart`, `lib/kernel/models/media_state.dart`

**`lib/kernel/persistence/` (Persistence):**
- Purpose: Data persistence via SharedPreferences and JSON files
- Contains: `SettingsStore` (SharedPreferences), `PlaylistStore` (JSON file)
- Key files: `lib/kernel/persistence/settings_store.dart`, `lib/kernel/persistence/playlist_store.dart`

**`lib/kernel/playlist/` (Playlist):**
- Purpose: Playlist model with play mode state machine
- Contains: `Playlist` class (ordered list, current index, 4 play modes, JSON serialization)
- Key files: `lib/kernel/playlist/playlist.dart`

**`lib/kernel/scanner/` (Scanner):**
- Purpose: Directory scanning for video files
- Contains: `FolderScanner`
- Key files: `lib/kernel/scanner/folder_scanner.dart`

**`lib/kernel/ui/` (Kernel UI):**
- Purpose: UI components that belong to the kernel layer (theme, title bar, dialogs)
- Contains: Theme tokens, app theme, custom title bar, kernel dialogs, playlist UI, widgets
- Key files: `lib/kernel/ui/theme/tokens.dart`, `lib/kernel/ui/window/custom_title_bar.dart`

**`lib/kernel/utils/` (Kernel Utilities):**
- Purpose: Shared utility functions
- Contains: `Log`, `PathUtils`, `TimeUtils`, `MotionUtils`, `PlatformDecoders`
- Key files: `lib/kernel/utils/log.dart`, `lib/kernel/utils/path_utils.dart`, `lib/kernel/utils/time_utils.dart`

**`lib/kernel/window/` (Kernel Window Services):**
- Purpose: Window-related kernel services (aspect ratio)
- Contains: `AspectRatioService`
- Key files: `lib/kernel/window/aspect_ratio_service.dart`

**`lib/window/` (Window Layer):**
- Purpose: Platform-specific window management implementations
- Contains: `WindowService`, `WindowState`, `AspectRatioService`, `WindowLifecycleBus`, `WindowConstants`
- Key files: `lib/window/window_service.dart`, `lib/window/window_lifecycle.dart`, `lib/window/aspect_ratio_service.dart`

**`lib/ui/player/` (Player UI):**
- Purpose: Player screen and all control widgets
- Contains: `PlayerScreen`, `ControlsOverlay`, `ControlBar`, `ProgressBar`, `VolumeControls`, `SpeedButton`, `KeyboardHandler`, `VideoSurface`, `DropHandler`, `AutoHideController`, `CenterControls`, `ErrorBanner`, `TimeRangeDisplay`
- Key files: `lib/ui/player/player_screen.dart`, `lib/ui/player/controls_overlay.dart`

**`lib/ui/playlist/` (Playlist UI):**
- Purpose: Immersive floating playlist panel
- Contains: `PlaylistPanel`, `FolderTab`, `HistoryTab`, `ThumbnailTile`
- Key files: `lib/ui/playlist/playlist_panel.dart`

**`lib/ui/dialogs/` (Dialogs):**
- Purpose: Settings panel and media info dialog
- Contains: `SettingsPanel`, `MediaInfoDialog`, settings tab components (`GeneralTab`, `AudioTab`, `VideoTab`, `EqualizerTab`, `ShortcutsTab`, `AboutTab`)
- Key files: `lib/ui/dialogs/settings_panel.dart`

**`lib/ui/shared/` (Shared UI):**
- Purpose: Reusable UI components
- Contains: `GlassContainer`, `GlassChip`, `GlassIconButton`, `AuroraBackground`, `EmptyState`, `AppDialog`, `SettingsCard`, `PlayModeUtils`, `MergedListenable`, `ValueListenableBuilder2`
- Key files: `lib/ui/shared/glass_container.dart`, `lib/ui/shared/settings_card.dart`

**`lib/ui/widgets/` (Widgets):**
- Purpose: Overlay widgets
- Contains: `OsdOverlay` (floating OSD pill)
- Key files: `lib/ui/widgets/osd_overlay.dart`

**`lib/l10n/` (Localization):**
- Purpose: Internationalization (zh + en)
- Contains: Generated `AppLocalizations` classes from ARB files
- Key files: `lib/l10n/app_localizations.dart`

**`test/` (Tests):**
- Purpose: Unit and widget tests mirroring lib/ structure
- Contains: `test/kernel/` (kernel unit tests), `test/unit/` (additional unit tests), `test/widget/` (widget tests), `test/window/` (window tests), `test/helpers/` (fakes)
- Key files: `test/helpers/fake_engine.dart`

**`windows/runner/` (C++ Native):**
- Purpose: Win32 window creation and Flutter engine integration
- Contains: `FlutterWindow` (creates Flutter view, handles MethodChannel), `Win32Window` (Win32 HWND management)
- Key files: `windows/runner/flutter_window.cpp`, `windows/runner/win32_window.cpp`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application startup (parallel init: Rust, SharedPreferences, WindowService, runApp)
- `lib/app.dart`: MaterialApp shell, service wiring, top-level state management
- `windows/runner/main.cpp`: Win32 process entry point
- `windows/runner/flutter_window.cpp`: C++ Flutter window creation

**Configuration:**
- `pubspec.yaml`: Dart dependencies and assets
- `lib/kernel/ui/theme/tokens.dart`: Design tokens (colors, spacing, radius, fonts)
- `lib/kernel/ui/theme/app_theme.dart`: ThemeData bridge
- `lib/kernel/utils/platform_decoders.dart`: Platform-specific decoder selection

**Core Logic:**
- `lib/kernel/engine/media_engine.dart`: Abstract engine interface (10 ValueNotifiers)
- `lib/kernel/engine/fvp_engine.dart`: Concrete fvp/MDK engine
- `lib/kernel/services/playback_controller.dart`: Business orchestrator (3 mixins)
- `lib/kernel/services/playback_navigator.dart`: Track advancement + openGeneration guard
- `lib/kernel/services/state_monitor.dart`: Auto-advance + settings restore + playlist persistence
- `lib/kernel/services/file_operations.dart`: File open/drop handling
- `lib/kernel/playlist/playlist.dart`: Playlist model + play mode state machine

**Persistence:**
- `lib/kernel/persistence/settings_store.dart`: SharedPreferences for all settings
- `lib/kernel/persistence/playlist_store.dart`: JSON file for playlist history
- `lib/window/geometry_store.dart`: Window geometry persistence
- `lib/window/window_persistence_service.dart`: Debounced window position saving

**Window Management:**
- `lib/kernel/bridge/window_bridge.dart`: Abstract window interface
- `lib/window/window_service.dart`: Window management singleton
- `lib/window/window_service.dart`: Windows implementation (window_manager + Win32 FFI)
- `lib/window/fullscreen_controller.dart`: Win32 FFI fullscreen (WS_THICKFRAME + SetWindowPos)
- `lib/window/window_state_service.dart`: Window state ValueNotifiers
- `lib/window/linux_window_service.dart`: Linux window implementation
- `lib/window/macos_window_service.dart`: macOS window implementation

**Testing:**
- `test/helpers/fake_engine.dart`: FakeMediaEngine for testing
- `test/kernel/services/playback_controller_test.dart`: PlaybackController tests
- `test/kernel/services/playback_navigator_test.dart`: Navigation tests
- `test/widget/player/control_bar_test.dart`: Control bar widget tests
- `test/window/window_service_test.dart`: Window service tests

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files (Dart convention)
- Class names `PascalCase` within snake_case files
- Test files: `{name}_test.dart` mirroring source structure

**Directories:**
- `snake_case` for all directories
- Feature-based grouping within `lib/ui/` (player, playlist, dialogs, shared, widgets)
- Layer-based grouping within `lib/kernel/` (engine, services, models, persistence, bridge)

**Classes:**
- `PascalCase` for all classes, enums, typedefs
- Private classes prefixed with `_` (e.g., `_PlayerScreenState`, `_WindowListener`)
- Abstract interfaces use descriptive names (e.g., `MediaEngine`, `ThumbnailProvider`)

**Functions/Variables:**
- `camelCase` for all functions and variables
- Private members prefixed with `_`
- Boolean getters: `is`, `has`, `should` prefixes (e.g., `isFullscreen`, `hasNext`, `isEmpty`)

**Constants:**
- `SCREAMING_SNAKE_CASE` for Win32 constants in C++ and FFI
- `Tokens.*` static constants for design tokens (e.g., `Tokens.bgBase`, `Tokens.accent`)

## Where to Add New Code

**New Playback Feature (e.g., AB loop, screenshot):**
- Add method to `lib/kernel/engine/media_engine.dart` (abstract interface)
- Implement in `lib/kernel/engine/fvp_engine.dart`
- If orchestrator needed: add mixin to `lib/kernel/services/`
- Wire in `lib/kernel/services/playback_controller.dart`
- Add UI in `lib/ui/player/`

**New UI Component (e.g., new control button):**
- Reusable glass component: `lib/ui/shared/`
- Player-specific control: `lib/ui/player/`
- Playlist feature: `lib/ui/playlist/`
- Dialog/tab: `lib/ui/dialogs/settings/`
- Use `Tokens.*` for all visual values

**New Model/Enum:**
- Data class: `lib/kernel/models/`
- Follow existing pattern: immutable, with `const` constructor, JSON serialization if persisted

**New Persistence:**
- SharedPreferences: extend `lib/kernel/persistence/settings_store.dart`
- JSON file: create new store similar to `lib/kernel/persistence/playlist_store.dart`

**New Platform Service:**
- Abstract interface in `lib/kernel/bridge/` or `lib/kernel/services/`
- Platform implementation in `lib/window/` (Windows), `lib/window/linux_window_service.dart` (Linux), `lib/window/macos_window_service.dart` (macOS)
- Wire in `lib/window/window_service.dart`

**New Test:**
- Kernel unit test: `test/kernel/{module}/{name}_test.dart`
- Widget test: `test/widget/{area}/{name}_test.dart`
- Window test: `test/window/{name}_test.dart`
- Use `test/helpers/fake_engine.dart` for engine mocking

## Special Directories

**`lib/kernel/ui/`:**
- Purpose: UI components that belong to the kernel layer (theme tokens, custom title bar)
- Generated: No
- Committed: Yes

**`lib/l10n/`:**
- Purpose: Localization files (ARB source + generated Dart classes)
- Generated: Partially (generated Dart from ARB)
- Committed: Yes

**`assets/fonts/`:**
- Purpose: Custom font files
- Generated: No
- Committed: Yes

**`build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No (gitignored)

**`coverage/`:**
- Purpose: Test coverage reports
- Generated: Yes
- Committed: No (gitignored)

**`production/session-logs/`:**
- Purpose: Development session logs
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-05-23*
