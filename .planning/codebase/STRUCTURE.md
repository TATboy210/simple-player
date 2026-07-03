# Codebase Structure

**Analysis Date:** 2026-07-03

## Directory Layout

```
simple_player_flutter/
├── lib/                            # Dart source (135 files)
│   ├── main.dart                   # Entry point: fvp init, window setup, runApp
│   ├── app.dart                    # MaterialApp shell, theme/locale, settings trigger
│   ├── kernel/                     # Core logic (no UI dependency)
│   │   ├── engine/                 # fvp/MDK engine abstraction + helpers
│   │   ├── bridge/                 # Window management (Win32 + abstract interface)
│   │   ├── models/                 # Data classes (PlaylistItem, PlayMode, MediaState, etc.)
│   │   ├── persistence/            # Settings + playlist JSON storage
│   │   ├── playlist/               # Playlist state machine (4 play modes)
│   │   ├── scanner/                # Directory video file scanner
│   │   ├── services/               # Cross-cutting services (thumbnail, hotkey, locale, theme, path)
│   │   ├── startup/                # Startup coordinator + state
│   │   └── utils/                  # Logging, time, path, perf, memory, debug utilities
│   ├── features/
│   │   └── player/                 # Player feature module
│   │       ├── player_feature.dart # UI state + PlayerScreen composition
│   │       ├── player_view_model.dart # Extracted business logic (ChangeNotifier)
│   │       ├── player_services.dart # Service container (DI)
│   │       ├── deferred_player_feature.dart # Deferred loading wrapper
│   │       ├── models/             # Feature-specific models
│   │       └── services/           # PlaybackController + sub-modules
│   ├── ui/                         # All visual components
│   │   ├── theme/                  # Design tokens (Tokens class)
│   │   ├── player/                 # Player screen components
│   │   ├── playlist/               # Playlist panel + tabs
│   │   ├── shared/                 # Reusable glass widgets, OSD, empty state
│   │   ├── dialogs/                # Settings panel + media info dialog
│   │   └── window/                 # Custom title bar
│   └── l10n/                       # Localization (ARB + generated Dart)
├── test/                           # Tests (76 files)
│   ├── kernel/                     # Kernel unit tests (mirrors lib/kernel/)
│   ├── features/                   # Feature service tests
│   ├── widget/                     # Widget tests (player + shared components)
│   ├── integration/                # Integration flow tests
│   ├── golden/                     # Golden image tests
│   ├── unit/                       # Additional unit tests
│   ├── perf/                       # Performance benchmark tests
│   ├── helpers/                    # Test doubles (FakeEngine, FakeWindowService)
│   └── debug/                      # Debug utilities
├── packages/
│   └── fullscreen_window/          # Local plugin: cross-platform fullscreen (Win/Mac/Linux)
├── assets/
│   └── fonts/                      # Noto Sans SC font family (Regular/Medium/SemiBold)
├── android/                        # Android platform shell (minimal)
├── ios/                            # iOS platform shell (minimal)
├── docs/                           # Documentation + screenshots
├── .planning/                      # Phase plans + codebase analysis
├── .claude/                        # Claude Code config (agents, skills, workflows)
├── pubspec.yaml                    # Package manifest
├── analysis_options.yaml           # Dart analyzer config (very_good_analysis)
└── l10n.yaml                       # Localization config
```

## Directory Purposes

**`lib/kernel/engine/`:**
- Purpose: fvp/MDK engine abstraction layer
- Contains: EngineState mixin, FvpEngine implementation, 8 helper classes (FvpCallbackHandler, PositionPoller, TrackManager, MediaOpener, VideoEffectController, VolumeController, SubtitleConfigurator, D3D11Configurator), PlayerProxy interface, MockEngine
- Key files: `engine_state.dart` (abstract interface), `fvp_engine.dart` (concrete impl), `media_opener.dart` (open flow), `position_poller.dart` (timer-based polling)

**`lib/kernel/bridge/`:**
- Purpose: Window management abstraction + Win32 implementation
- Contains: WindowBridge interface, WindowService (Win32), WindowState (state container), WindowPersistence (debounce save), DisplayEnumerator, WindowMode enum
- Key files: `window_bridge.dart` (interface), `window_service.dart` (impl), `window_state.dart` (state)

**`lib/kernel/models/`:**
- Purpose: Shared data classes
- Contains: PlaylistItem, PlayMode, AppSettings, AspectRatioMode, PlayerError, ValidationError
- Key files: `playlist_item.dart`, `play_mode.dart`, `app_settings.dart`

**`lib/kernel/persistence/`:**
- Purpose: Settings and playlist persistence
- Contains: SettingsStore (SharedPreferences), PlaylistStore (JSON file), SettingsValidator
- Key files: `settings_store.dart` (prewarm pattern), `playlist_store.dart` (debounce + atomic write)

**`lib/kernel/services/`:**
- Purpose: Cross-cutting kernel services
- Contains: ThumbnailService (LRU cache + platform providers), PathValidator, LocaleService, ThemeService, GlobalHotkeyService
- Key files: `thumbnail_service.dart`, `path_validator.dart`, `locale_service.dart`, `theme_service.dart`

**`lib/kernel/startup/`:**
- Purpose: Application startup coordination
- Contains: StartupCoordinator (phase tracking), StartupState (phase enum + progress)
- Key files: `startup_coordinator.dart`

**`lib/kernel/utils/`:**
- Purpose: Pure utility functions
- Contains: Log, TimeUtils (formatMs), PathUtils, ScreenUtils, PerfMonitor, DebugProbe, DebugExporter, MemoryMonitor
- Key files: `log.dart`, `time_utils.dart`, `path_utils.dart`

**`lib/features/player/`:**
- Purpose: Player feature module with business logic
- Contains: PlayerFeature widget, PlayerViewModel, PlayerServices container, DeferredPlayerFeature, services subdirectory
- Key files: `player_feature.dart` (UI state), `player_services.dart` (DI container), `deferred_player_feature.dart` (lazy load)

**`lib/features/player/services/`:**
- Purpose: Playback orchestration sub-modules
- Contains: PlaybackController (facade), PlaybackNavigator, FileOperations, StateMonitor, SubtitleService, VideoProcessingService, PlaybackContract, BreakpointSaver, AutoAdvancePolicy, PlayerErrorBus
- Key files: `playback_controller.dart` (unified API), `playback_navigator.dart` (track nav), `state_monitor.dart` (auto-advance)

**`lib/ui/player/`:**
- Purpose: Player screen visual components
- Contains: PlayerScreen, ControlsOverlay, ControlBar, ProgressBar, VolumeControls, SpeedButton, CenterControls, KeyboardHandler, VideoSurface, DropHandler, ErrorBanner, AutoHideController, TimeRangeDisplay, PlayerActions
- Key files: `player_screen.dart` (main compositing), `controls_overlay.dart` (auto-hide), `control_bar.dart` (glass bar), `keyboard_handler.dart` (20+ shortcuts)

**`lib/ui/playlist/`:**
- Purpose: Immersive floating playlist panel
- Contains: PlaylistPanel (glass floating window), FolderTab, HistoryTab, ThumbnailTile
- Key files: `playlist_panel.dart`

**`lib/ui/shared/`:**
- Purpose: Reusable UI components
- Contains: GlassContainer, GlassButton, GlassChip, GlassWidgets, EmptyState, AuroraBackground, EdgeGlow, HoverGlow, TransmittedLight, OsdOverlay, ProgressSplashScreen, SplashScreen, MergedListenable, ValueListenableBuilder2, SettingActionRow, SettingSliderRow, SettingsCard, SettingsExpanderCard, SettingsActionCard, AppDialog, ContextMenuRow
- Key files: `glass_container.dart` (core glass widget), `osd_overlay.dart` (floating pill), `empty_state.dart` (idle screen)

**`lib/ui/dialogs/`:**
- Purpose: Dialog windows
- Contains: SettingsPanel (sidebar navigation), MediaInfoDialog, settings subdirectory with tabs (General, Audio, Video, Equalizer, Shortcuts, About, Performance)
- Key files: `settings_panel.dart`, `media_info_dialog.dart`

**`lib/ui/window/`:**
- Purpose: Custom window title bar
- Contains: CustomTitleBar (glass, drag, window controls)
- Key files: `custom_title_bar.dart`

**`lib/ui/theme/`:**
- Purpose: Design system tokens
- Contains: Tokens class with all compile-time constants
- Key files: `tokens.dart`

**`lib/l10n/`:**
- Purpose: Internationalization
- Contains: Generated Dart localization files + ARB source files
- Key files: `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`

**`packages/fullscreen_window/`:**
- Purpose: Local Flutter plugin for cross-platform fullscreen
- Contains: Windows (C++), macOS (Swift), Linux (Dart) implementations
- Key files: `lib/` (Dart API), `windows/` (C++ impl), `macos/` (Swift impl)

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application bootstrap (fvp init, window setup, runApp)
- `lib/app.dart`: MaterialApp shell with theme/locale/settings
- `lib/features/player/deferred_player_feature.dart`: Deferred player module loader

**Configuration:**
- `pubspec.yaml`: Dependencies and Flutter config
- `analysis_options.yaml`: Dart analyzer rules (very_good_analysis)
- `l10n.yaml`: Localization generation config

**Core Logic:**
- `lib/kernel/engine/engine_state.dart`: Abstract playback state interface (mixin)
- `lib/kernel/engine/fvp_engine.dart`: Concrete fvp/MDK engine implementation
- `lib/kernel/bridge/window_bridge.dart`: Abstract window management interface
- `lib/kernel/bridge/window_service.dart`: Win32 window implementation
- `lib/features/player/services/playback_controller.dart`: Unified playback API facade
- `lib/kernel/playlist/playlist.dart`: Playlist state machine

**Design System:**
- `lib/ui/theme/tokens.dart`: All visual constants (colors, spacing, radius, blur, animation)
- `lib/ui/shared/glass_container.dart`: Core glassmorphism component

**Testing:**
- `test/helpers/fake_engine.dart`: EngineState test double
- `test/helpers/fake_window_service.dart`: WindowBridge test double
- `test/kernel/`: Kernel unit tests
- `test/widget/`: Widget tests
- `test/integration/`: Integration flow tests
- `test/golden/`: Golden image tests

## Naming Conventions

**Files:**
- snake_case for all Dart files: `playback_controller.dart`, `glass_container.dart`
- Private files prefixed with underscore: `_settings_nav_item.dart`
- Test files suffixed with `_test.dart`: `playlist_test.dart`

**Directories:**
- snake_case for all directories: `player/`, `shared/`, `kernel/`
- Feature directories match feature name: `features/player/`

**Classes:**
- PascalCase: `PlaybackController`, `GlassContainer`, `FvpEngine`
- Private classes prefixed with underscore: `_PlayerFeatureState`, `_QuickMenuItem`

**Enums:**
- PascalCase type name, camelCase values: `WindowMode.windowed`, `MediaState.playing`

**Constants:**
- Static const in Tokens class: `Tokens.bgDeep`, `Tokens.radiusLarge`
- Private constants prefixed with underscore: `_durationWindowResize`

## Where to Add New Code

**New Engine Feature:**
- Helper class: `lib/kernel/engine/` (e.g., new configurator)
- Engine state field: Add ValueNotifier to `lib/kernel/engine/engine_state.dart`
- Engine method: Add to EngineState mixin, implement in FvpEngine

**New Player Service:**
- Service file: `lib/features/player/services/`
- Wire into PlaybackController: `lib/features/player/services/playback_controller.dart`
- Wire into PlayerServices: `lib/features/player/player_services.dart`

**New UI Component:**
- Player screen component: `lib/ui/player/`
- Shared/reusable component: `lib/ui/shared/`
- Dialog: `lib/ui/dialogs/`
- Playlist component: `lib/ui/playlist/`

**New Data Model:**
- Kernel model: `lib/kernel/models/`
- Feature model: `lib/features/player/models/`

**New Persistence:**
- Settings: Add key to `lib/kernel/persistence/settings_store.dart`
- New store: `lib/kernel/persistence/`

**New Utility:**
- Utility function: `lib/kernel/utils/`
- Service: `lib/kernel/services/`

**New Test:**
- Kernel unit test: `test/kernel/` (mirror `lib/kernel/` structure)
- Widget test: `test/widget/`
- Integration test: `test/integration/`
- Golden test: `test/golden/`
- Test helper/fake: `test/helpers/`

**New Localization String:**
- ARB files: `lib/l10n/` (app_en.arb, app_zh.arb)
- Generated code auto-updates on `flutter gen-l10n`

## Special Directories

**`packages/fullscreen_window/`:**
- Purpose: Local Flutter plugin for cross-platform fullscreen window control
- Generated: No (hand-written)
- Committed: Yes

**`.planning/`:**
- Purpose: Phase plans, codebase analysis documents
- Generated: No (manual)
- Committed: Yes

**`.claude/`:**
- Purpose: Claude Code configuration (agents, skills, workflows, memory)
- Generated: Partially (memory files auto-generated)
- Committed: Selective (skills committed, memory may not be)

**`assets/fonts/`:**
- Purpose: Noto Sans SC font files (Regular 400, Medium 500, SemiBold 600)
- Generated: No
- Committed: Yes

**`build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No (gitignored)

---

*Structure analysis: 2026-07-03*
