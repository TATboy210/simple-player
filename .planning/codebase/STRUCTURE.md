# Codebase Structure

**Analysis Date:** 2026-06-23

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                          # Entry point (fvp init, window setup)
│   ├── app.dart                           # MaterialApp shell, service wiring
│   ├── kernel/                            # Core logic (no UI dependencies)
│   │   ├── bridge/                        # Window management abstraction
│   │   │   ├── win32/                     # Win32-specific implementations
│   │   │   ├── window_bridge.dart         # Abstract window interface
│   │   │   ├── window_service.dart        # Concrete Win32 implementation
│   │   │   ├── window_state.dart          # Window state container
│   │   │   ├── window_mode.dart           # WindowMode enum
│   │   │   ├── fullscreen_controller.dart # Atomic fullscreen + mutex
│   │   │   ├── platform_fullscreen.dart   # Platform fullscreen interface
│   │   │   ├── window_persistence.dart    # Debounced geometry save
│   │   │   └── display_config.dart        # Display/refresh rate detection
│   │   ├── engine/                        # fvp/MDK engine wrapper
│   │   │   ├── fvp_engine.dart            # Concrete engine (724 lines)
│   │   │   ├── position_poller.dart       # Timer-based position updates
│   │   │   ├── track_manager.dart         # Audio/subtitle track management
│   │   │   ├── fvp_callback_handler.dart  # MDK callback registration
│   │   │   ├── media_opener.dart          # Open logic helper
│   │   │   ├── d3d11_configurator.dart    # D3D11 settings
│   │   │   ├── network_configurator.dart  # Network stream config
│   │   │   ├── subtitle_configurator.dart # Subtitle settings
│   │   │   ├── video_effect_controller.dart # Video effects
│   │   │   ├── volume_controller.dart     # Volume control
│   │   │   ├── engine_prewarm.dart        # Background codec registration
│   │   │   └── open_result.dart           # Open result type
│   │   ├── models/                        # Data classes
│   │   │   ├── app_settings.dart          # AppSettings (immutable, copyWith)
│   │   │   ├── playlist_item.dart         # PlaylistItem (path, timestamp, position)
│   │   │   ├── play_mode.dart             # PlayMode enum (loopAll/loopSingle/shuffle)
│   │   │   ├── aspect_ratio_mode.dart     # AspectRatioMode enum
│   │   │   ├── player_error.dart          # PlayerError types
│   │   │   └── validation_error.dart      # ValidationError types
│   │   ├── persistence/                   # Storage
│   │   │   ├── settings_store.dart        # SharedPreferences persistence
│   │   │   └── playlist_store.dart        # Playlist JSON persistence
│   │   ├── playlist/
│   │   │   └── playlist.dart              # Playlist model + CQS navigation
│   │   ├── scanner/
│   │   │   └── folder_scanner.dart        # Directory video file scanner
│   │   ├── services/                      # Kernel-level services
│   │   │   ├── thumbnail_service.dart     # Platform-aware thumbnail facade
│   │   │   ├── thumbnail_provider.dart    # Abstract thumbnail interface
│   │   │   ├── linux_thumbnail_provider.dart
│   │   │   ├── macos_thumbnail_provider.dart
│   │   │   ├── noop_thumbnail_provider.dart
│   │   │   ├── path_validator.dart        # Path security validation
│   │   │   ├── locale_service.dart        # Locale management
│   │   │   └── theme_service.dart         # Theme management
│   │   ├── startup/
│   │   │   ├── startup_coordinator.dart   # Startup phase tracking
│   │   │   └── startup_state.dart         # StartupState data class
│   │   └── utils/                         # Shared utilities
│   │       ├── log.dart                   # Module-scoped loggers
│   │       ├── path_utils.dart            # Path manipulation
│   │       ├── time_utils.dart            # Time formatting
│   │       ├── screen_utils.dart          # Screen/display utilities
│   │       ├── memory_monitor.dart        # Memory usage monitoring
│   │       └── perf_monitor.dart          # Performance monitoring
│   ├── features/
│   │   └── player/
│   │       ├── player_feature.dart        # PlayerFeature StatefulWidget
│   │       ├── deferred_player_feature.dart # Lazy-loaded wrapper
│   │       ├── player_services.dart       # Service container
│   │       ├── models/
│   │       │   └── video_processing_state.dart
│   │       └── services/
│   │           ├── playback_controller.dart    # Unified playback entry
│   │           ├── playback_navigator.dart     # Index navigation + resume
│   │           ├── state_monitor.dart          # Auto-advance + persistence
│   │           ├── file_operations.dart        # File open/drop handling
│   │           ├── subtitle_service.dart       # Subtitle detection
│   │           └── video_processing_service.dart # Color correction
│   ├── ui/
│   │   ├── player/                        # Player screen components
│   │   │   ├── player_screen.dart         # Main screen (338 lines)
│   │   │   ├── controls_overlay.dart      # Auto-hide control layer
│   │   │   ├── control_bar.dart           # Bottom glass bar (350 lines)
│   │   │   ├── progress_bar.dart          # Seekbar + thumbnails
│   │   │   ├── volume_controls.dart       # Volume slider + mute
│   │   │   ├── speed_button.dart          # Playback speed selector
│   │   │   ├── keyboard_handler.dart      # 20+ key Focus handler
│   │   │   ├── video_surface.dart         # Texture renderer
│   │   │   ├── drop_handler.dart          # Drag-and-drop files
│   │   │   ├── center_controls.dart       # Center play/pause button
│   │   │   ├── error_banner.dart          # Error display
│   │   │   ├── auto_hide_controller.dart  # Auto-hide animation
│   │   │   ├── player_actions.dart        # Action callbacks struct
│   │   │   └── time_range_display.dart    # Time display
│   │   ├── playlist/                      # Immersive floating playlist
│   │   │   ├── playlist_panel.dart        # Floating window (358 lines)
│   │   │   ├── folder_tab.dart            # Folder-grouped thumbnails
│   │   │   ├── history_tab.dart           # Timestamp-sorted history
│   │   │   └── thumbnail_tile.dart        # 16:9 thumbnail card
│   │   ├── dialogs/
│   │   │   ├── settings_panel.dart        # Settings dialog (402 lines)
│   │   │   ├── media_info_dialog.dart     # File properties dialog
│   │   │   └── settings/                  # Settings tabs
│   │   │       ├── general_tab.dart
│   │   │       ├── audio_tab.dart
│   │   │       ├── video_tab.dart
│   │   │       ├── equalizer_tab.dart
│   │   │       ├── shortcuts_tab.dart
│   │   │       ├── about_tab.dart
│   │   │       ├── settings_tab_performance.dart
│   │   │       └── _settings_nav_item.dart
│   │   ├── shared/                        # Reusable components
│   │   │   ├── glass_container.dart       # Glassmorphism wrapper (270 lines)
│   │   │   ├── glass_widgets.dart         # GlassChip, GlassDivider
│   │   │   ├── glass_chip.dart            # Glass chip component
│   │   │   ├── empty_state.dart           # Empty state screen
│   │   │   ├── osd_overlay.dart           # Floating OSD pill
│   │   │   ├── aurora_background.dart     # Aurora gradient background
│   │   │   ├── play_mode_utils.dart       # PlayMode -> icon/label
│   │   │   ├── merged_listenable.dart     # Multi-ValueNotifier merge
│   │   │   ├── value_listenable_builder2.dart # Dual notifier builder
│   │   │   ├── progress_splash_screen.dart # Startup progress UI
│   │   │   ├── splash_screen.dart         # Splash screen
│   │   │   ├── app_dialog.dart            # Base dialog
│   │   │   ├── context_menu_row.dart      # Context menu item
│   │   │   ├── setting_action_row.dart    # Settings row
│   │   │   ├── setting_slider_row.dart    # Settings slider
│   │   │   ├── settings_card.dart         # Settings card
│   │   │   ├── settings_action_card.dart  # Settings action card
│   │   │       └── settings_expander_card.dart # Settings expander
│   │   ├── theme/
│   │   │   └── tokens.dart                # Design tokens (colors, spacing)
│   │   └── window/
│   │       └── custom_title_bar.dart      # Window title bar
│   └── l10n/                              # Localization
│       ├── app_localizations.dart         # Generated (1022 lines)
│       ├── app_localizations_en.dart      # English strings
│       ├── app_localizations_zh.dart      # Chinese strings
│       ├── app_en.arb                     # English ARB source
│       └── app_zh.arb                     # Chinese ARB source
├── test/
│   ├── kernel/                            # Kernel unit tests
│   │   ├── bridge/
│   │   ├── engine/
│   │   ├── models/
│   │   ├── persistence/
│   │   └── services/
│   ├── features/
│   │   └── player/
│   │       └── services/
│   ├── golden/                            # Golden tests
│   ├── integration/                       # Integration tests
│   └── helpers/                           # Test doubles
│       ├── fake_engine.dart               # FakePlayerEngine
│       └── fake_window_service.dart       # FakeWindowService
├── windows/                               # Win32 runner + C++ code
├── assets/
│   └── fonts/                             # Noto Sans SC font files
├── pubspec.yaml                           # Dependencies
├── analysis_options.yaml                  # Dart analyzer config
└── CLAUDE.md                              # Project instructions
```

## Directory Purposes

**`lib/kernel/`:**
- Purpose: Core logic with zero UI dependencies. Engine wrappers, platform bridge, data models, persistence.
- Contains: 7 subdirectories (bridge, engine, models, persistence, playlist, scanner, services, startup, utils)
- Key files: `fvp_engine.dart` (724 lines), `window_service.dart` (262 lines), `settings_store.dart` (439 lines)

**`lib/features/player/`:**
- Purpose: Combines kernel services with UI state. Owns service lifecycle.
- Contains: PlayerFeature (StatefulWidget), PlayerServices (service container), services/ subdirectory
- Key files: `player_feature.dart`, `player_services.dart`, `playback_controller.dart`

**`lib/ui/`:**
- Purpose: Pure Flutter widgets. No business logic, only presentation.
- Contains: 5 subdirectories (player, playlist, dialogs, shared, theme, window)
- Key files: `player_screen.dart` (338 lines), `control_bar.dart` (350 lines), `glass_container.dart` (270 lines)

**`lib/l10n/`:**
- Purpose: Localization (ARB + generated)
- Contains: Generated Dart files + ARB source files
- Key files: `app_localizations.dart` (1022 lines, generated)

**`test/`:**
- Purpose: Unit, integration, and golden tests
- Contains: Mirrors `lib/` structure + `helpers/` for test doubles
- Key files: `fake_engine.dart`, `fake_window_service.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App bootstrap (logging, prewarm, window init, engine prewarm, runApp)
- `lib/app.dart`: MaterialApp shell (theme, locale, DeferredPlayerFeature)
- `lib/features/player/deferred_player_feature.dart`: Lazy-loads PlayerFeature

**Configuration:**
- `pubspec.yaml`: Dependencies (fvp, window_manager, shared_preferences, file_picker, etc.)
- `analysis_options.yaml`: Dart analyzer strict mode
- `lib/ui/theme/tokens.dart`: Design tokens (colors, spacing, typography)

**Core Logic:**
- `lib/kernel/engine/fvp_engine.dart`: fvp/MDK engine wrapper (724 lines, largest non-generated file)
- `lib/kernel/bridge/window_service.dart`: Window management (262 lines)
- `lib/kernel/playlist/playlist.dart`: Playlist model + CQS navigation (283 lines)
- `lib/features/player/services/playback_controller.dart`: Unified playback entry

**Testing:**
- `test/helpers/fake_engine.dart`: FakePlayerEngine for unit tests
- `test/helpers/fake_window_service.dart`: FakeWindowService for unit tests
- `test/integration/`: Integration tests for controls, playback, playlist flows

## Naming Conventions

**Files:**
- snake_case for all Dart files: `playback_controller.dart`, `glass_container.dart`
- Private files prefixed with underscore: `_settings_nav_item.dart`
- Test files suffixed with `_test.dart`: `playlist_test.dart`

**Directories:**
- snake_case for all directories: `features/player/`, `ui/shared/`
- Feature directories mirror domain: `kernel/bridge/`, `kernel/engine/`

**Classes:**
- PascalCase: `PlaybackController`, `GlassContainer`, `WindowState`
- Private classes prefixed with underscore: `_PlayerFeatureState`, `_RotatingFileOutput`

**Enums:**
- PascalCase type, camelCase values: `WindowMode.windowed`, `PlayMode.loopAll`

## Where to Add New Code

**New Playback Feature:**
- Service logic: `lib/features/player/services/` (create new file, compose into PlaybackController)
- UI controls: `lib/ui/player/` (add to PlayerScreen build method)
- Tests: `test/features/player/services/` or `test/kernel/services/`

**New Window Feature:**
- Bridge logic: `lib/kernel/bridge/` (implement WindowBridge method or add to WindowService)
- Platform-specific: `lib/kernel/bridge/win32/` (Win32 FFI)
- Tests: `test/kernel/bridge/`

**New Engine Feature:**
- Engine wrapper: `lib/kernel/engine/` (add to FvpEngine or create helper)
- Tests: `test/kernel/engine/`

**New UI Widget:**
- Shared/reusable: `lib/ui/shared/` (GlassContainer pattern)
- Player-specific: `lib/ui/player/`
- Dialog: `lib/ui/dialogs/`
- Tests: `test/golden/` for visual tests, `test/ui/` for widget tests

**New Data Model:**
- Kernel models: `lib/kernel/models/` (immutable, copyWith, toJson/fromJson)
- Tests: `test/kernel/models/`

**New Utility:**
- Kernel utils: `lib/kernel/utils/`
- Tests: `test/kernel/utils/`

**New Settings Tab:**
- Tab widget: `lib/ui/dialogs/settings/` (create `*_tab.dart`)
- Register in: `lib/ui/dialogs/settings_panel.dart`

## Special Directories

**`lib/l10n/`:**
- Purpose: Localization files (ARB source + generated Dart)
- Generated: Yes (by `flutter gen-l10n`)
- Committed: Yes (generated files committed for CI)

**`windows/`:**
- Purpose: Win32 runner and C++ native code
- Generated: Partially (Flutter creates scaffold, C++ is custom)
- Committed: Yes

**`assets/fonts/`:**
- Purpose: Noto Sans SC font files (Regular, Medium, SemiBold)
- Generated: No
- Committed: Yes

**`.planning/`:**
- Purpose: Project planning documents (codebase maps, milestones, research)
- Generated: No
- Committed: Yes

## File Statistics

- **Total Dart files:** 110
- **Total directories:** 25
- **Total lines:** ~15,884
- **Largest files (non-generated):**
  - `lib/kernel/engine/fvp_engine.dart`: 724 lines
  - `lib/kernel/persistence/settings_store.dart`: 439 lines
  - `lib/ui/dialogs/settings_panel.dart`: 402 lines
  - `lib/ui/shared/aurora_background.dart`: 362 lines
  - `lib/ui/playlist/playlist_panel.dart`: 358 lines
  - `lib/ui/player/control_bar.dart`: 350 lines
  - `lib/ui/player/player_screen.dart`: 338 lines

---

*Structure analysis: 2026-06-23*
