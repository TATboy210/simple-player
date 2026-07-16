> ⚠️ **v2.1 前快照（2026-07-12）** — 此文档描述 v2.1 重构前结构，Phase 15+ 一律对 LIVE code + codegraph 核对，勿信本快照具体路径/类名。保留作演进历史。

# Codebase Structure

**Analysis Date:** 2026-07-12

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                          # App entry: bootstrap, prefs, window, engine prewarm
│   ├── app.dart                           # MaterialApp shell: theme, locale, settings panel
│   ├── features/
│   │   └── player/                        # Player feature: DI container + business logic
│   │       ├── deferred_player_feature.dart  # Lazy-load wrapper (deferred as)
│   │       ├── player_feature.dart           # DI owner, UI state, PlayerScreen composition
│   │       ├── player_services.dart          # DI container: engine + playlist + controller
│   │       ├── models/
│   │       │   └── video_processing_state.dart  # Immutable video processing state
│   │       └── services/
│   │           ├── playback_controller.dart     # Facade: unified entry to sub-modules
│   │           ├── playback_contract.dart       # Abstract interface for sub-module DI
│   │           ├── playback_navigator.dart      # Track navigation + openGeneration guard
│   │           ├── file_operations.dart         # File open/add with path validation
│   │           ├── state_monitor.dart           # Engine state observer: breakpoints, auto-advance
│   │           ├── subtitle_service.dart        # External subtitle auto-detection
│   │           ├── video_processing_service.dart # Diff-based engine sync + debounced persist
│   │           └── breakpoint_saver.dart        # Breakpoint persistence helper
│   ├── kernel/                            # Core logic: engine, bridge, models, persistence
│   │   ├── engine/                        # fvp/MDK video engine wrapper
│   │   │   ├── engine_state.dart              # Mixin: all ValueNotifier state + methods
│   │   │   ├── fvp_engine.dart                # Concrete engine: 6 helper composition
│   │   │   ├── media_state.dart               # MediaState enum + transition guard
│   │   │   ├── media_error_type.dart          # Error classification enum
│   │   │   ├── engine_constants.dart          # Default values, limits, thresholds
│   │   │   ├── engine_metrics.dart            # Health counters (open/seek/error)
│   │   │   ├── engine_event_log.dart          # Ring buffer: last 100 events
│   │   │   ├── engine_prewarm.dart            # Startup: FFmpeg codec + D3D11 context
│   │   │   ├── player_proxy.dart              # Abstract proxy for test injection
│   │   │   ├── mdk_player_proxy.dart          # Concrete proxy wrapping mdk.Player
│   │   │   ├── position_poller.dart           # Adaptive interval position polling
│   │   │   ├── track_manager.dart             # Audio/subtitle track management
│   │   │   ├── track_control.dart             # Track control mixin
│   │   │   ├── volume_controller.dart         # Volume + mute control
│   │   │   ├── video_effect_controller.dart   # Brightness/contrast/rotation
│   │   │   ├── video_effect_type.dart         # Effect type enum
│   │   │   ├── video_effects.dart             # Video effects mixin
│   │   │   ├── subtitle_configurator.dart     # External subtitle + delay + equalizer
│   │   │   ├── d3d11_configurator.dart        # D3D11 sync + hardware decode
│   │   │   ├── renderer_config.dart           # Renderer configuration mixin
│   │   │   ├── media_opener.dart              # Async open with error classification
│   │   │   ├── open_result.dart               # OpenSuccess/OpenError sealed result
│   │   │   ├── fvp_callback_handler.dart      # mdk callbacks → ValueNotifier bridge
│   │   │   └── models/
│   │   │       ├── media_info.dart            # Codec/resolution metadata
│   │   │       ├── video_codec_info.dart      # Video codec details
│   │   │       ├── audio_track_info.dart      # Audio track metadata
│   │   │       └── subtitle_track_info.dart   # Subtitle track metadata
│   │   ├── bridge/                        # Window management + fullscreen drivers
│   │   │   ├── window_bridge.dart             # Abstract interface: 4 states + 7 commands
│   │   │   ├── window_service.dart            # Concrete: WindowListener + FullscreenDriver
│   │   │   ├── window_mode.dart               # WindowMode enum (windowed/maximized/fullscreen/minimized)
│   │   │   ├── window_state.dart              # Immutable state container: mode, size, resizing
│   │   │   ├── window_persistence.dart        # Window geometry save/load
│   │   │   ├── fullscreen_driver.dart         # Abstract: enter/leave/query fullscreen
│   │   │   ├── desktop_fullscreen_driver.dart # window_manager fallback driver
│   │   │   ├── desktop_fullscreen_driver_factory.dart  # Factory: platform + compile flag
│   │   │   ├── display_config.dart            # Display configuration data
│   │   │   ├── display_enumerator.dart        # Abstract: enumerate displays
│   │   │   ├── platform/
│   │   │   │   ├── windows_fullscreen_driver.dart  # Win32 FFI driver
│   │   │   │   ├── macos_fullscreen_driver.dart    # macOS fullscreen_window plugin
│   │   │   │   └── linux_fullscreen_driver.dart    # Linux fullscreen_window plugin
│   │   │   └── win32/
│   │   │       ├── win32_fullscreen_ffi.dart       # Win32 FFI bindings (user32.dll)
│   │   │       └── win32_display_enumerator.dart   # Win32 display enumeration
│   │   ├── models/                        # Shared data models
│   │   │   ├── playlist_item.dart             # PlaylistItem: immutable data class
│   │   │   ├── play_mode.dart                 # PlayMode enum (loopAll/loopSingle/shuffle)
│   │   │   ├── app_settings.dart              # AppSettings: all persisted preferences
│   │   │   ├── aspect_ratio_mode.dart         # AspectRatioMode enum
│   │   │   ├── fullscreen_capability.dart     # FullscreenCapability: platform capabilities
│   │   │   ├── player_error.dart              # PlayerError types
│   │   │   └── validation_error.dart          # ValidationError types
│   │   ├── persistence/                   # Data persistence layer
│   │   │   ├── settings_store.dart            # SharedPreferences with validation
│   │   │   ├── settings_validator.dart        # Input sanitization rules
│   │   │   └── playlist_store.dart            # JSON file persistence for playlist
│   │   ├── playlist/                      # Playlist state machine
│   │   │   └── playlist.dart                  # Playlist: items, index, modes, CQS navigation
│   │   ├── scanner/                       # File system scanning
│   │   │   └── folder_scanner.dart            # Directory video file scanner (14 formats)
│   │   ├── services/                      # Cross-cutting kernel services
│   │   │   ├── thumbnail_service.dart         # Platform-aware thumbnail facade (LRU cache)
│   │   │   ├── thumbnail_provider.dart        # Abstract thumbnail provider
│   │   │   ├── linux_thumbnail_provider.dart  # Linux thumbnail provider
│   │   │   ├── macos_thumbnail_provider.dart  # macOS thumbnail provider
│   │   │   ├── noop_thumbnail_provider.dart   # No-op for unsupported platforms
│   │   │   ├── global_hotkey_service.dart     # Global hotkey registration
│   │   │   ├── locale_service.dart            # Locale persistence + ValueNotifier
│   │   │   ├── theme_service.dart             # Theme persistence + accent switching
│   │   │   └── path_validator.dart            # Path traversal validation
│   │   ├── startup/                       # App startup coordination
│   │   │   ├── startup_coordinator.dart       # Phase-based progress tracker
│   │   │   └── startup_state.dart             # StartupState: immutable value object
│   │   └── utils/                         # Shared utilities
│   │       ├── log.dart                       # Logging wrappers (log.i/d/w/e)
│   │       ├── time_utils.dart                # formatMs() duration formatting
│   │       ├── path_utils.dart                # Path validation + basename
│   │       ├── screen_utils.dart              # Multi-monitor clamp utilities
│   │       ├── debug_probe.dart               # Operation timing (DebugProbe)
│   │       ├── debug_exporter.dart            # Debug data export
│   │       ├── perf_monitor.dart              # Frame timing monitor
│   │       └── memory_monitor.dart            # RSS memory tracking
│   ├── ui/                                # All visual components
│   │   ├── player/                        # Player screen components
│   │   │   ├── player_screen.dart             # Main: Stack compositing + responsive layout
│   │   │   ├── controls_overlay.dart          # Auto-hide layer: gestures, double-click
│   │   │   ├── control_bar.dart               # Bottom glass bar: play/seek/volume/speed
│   │   │   ├── progress_bar.dart              # Seekbar with thumbnail preview
│   │   │   ├── volume_controls.dart           # Volume slider + mute toggle
│   │   │   ├── speed_button.dart              # Playback speed selector
│   │   │   ├── keyboard_handler.dart          # 20+ key Focus handler
│   │   │   ├── video_surface.dart             # Texture renderer with aspect ratio
│   │   │   ├── drop_handler.dart              # Drag-and-drop file handler
│   │   │   ├── auto_hide_controller.dart      # Auto-hide timer + opacity
│   │   │   ├── center_controls.dart           # Center play/pause button
│   │   │   ├── left_button_group.dart         # Left side buttons (prev/play-mode)
│   │   │   ├── right_button_group.dart        # Right side buttons (subtitle/fullscreen/settings)
│   │   │   ├── player_actions.dart            # Action callbacks data class
│   │   │   ├── error_banner.dart              # Error display banner
│   │   │   └── time_range_display.dart        # Time display widget
│   │   ├── playlist/                      # Floating playlist panel
│   │   │   ├── playlist_panel.dart            # Floating window with tabs (folder/history)
│   │   │   ├── folder_tab.dart                # Folder-grouped video thumbnails
│   │   │   ├── history_tab.dart               # Timestamp-sorted play history
│   │   │   └── thumbnail_tile.dart            # 16:9 thumbnail card
│   │   ├── shared/                        # Reusable UI components
│   │   │   ├── glass_container.dart           # Glassmorphism wrapper (3-tier blur)
│   │   │   ├── glass_widgets.dart             # Additional glass components
│   │   │   ├── glass_chip.dart                # Glass chip/badge component
│   │   │   ├── aurora_background.dart         # Animated aurora breathing background
│   │   │   ├── transmitted_light.dart         # Light transmission effect
│   │   │   ├── hover_glow.dart                # Hover glow effect
│   │   │   ├── edge_glow.dart                 # Edge glow effect
│   │   │   ├── osd_overlay.dart               # OSD: global singleton + overlay widget
│   │   │   ├── empty_state.dart               # Idle screen: aurora + branding + open button
│   │   │   ├── splash_screen.dart             # Splash screen
│   │   │   ├── progress_splash_screen.dart    # Startup progress splash
│   │   │   ├── play_mode_utils.dart           # PlayMode → icon/label mapping
│   │   │   ├── context_menu_row.dart          # Right-click menu row
│   │   │   ├── section_header.dart            # Settings section header
│   │   │   ├── setting_action_row.dart        # Settings action row
│   │   │   ├── setting_slider_row.dart        # Settings slider row
│   │   │   ├── settings_card.dart             # Settings card container
│   │   │   ├── merged_listenable.dart         # Multi-notifier merger
│   │   │   ├── value_listenable_builder2.dart # Dual-notifier builder
│   │   │   └── app_dialog.dart                # Base dialog wrapper
│   │   ├── widgets/                       # Specialized widgets
│   │   │   └── osd_overlay.dart               # (see shared/ above)
│   │   ├── dialogs/                       # Dialog components
│   │   │   ├── media_info_dialog.dart         # File properties dialog
│   │   │   ├── settings_panel.dart            # Settings side panel
│   │   │   └── settings/                      # Settings tab components
│   │   │       ├── general_tab.dart           # General settings tab
│   │   │       ├── audio_tab.dart             # Audio settings tab
│   │   │       ├── video_tab.dart             # Video settings tab
│   │   │       ├── equalizer_tab.dart         # Equalizer settings tab
│   │   │       ├── shortcuts_tab.dart         # Keyboard shortcuts tab
│   │   │       ├── settings_tab_performance.dart  # Performance settings tab
│   │   │       ├── about_tab.dart             # About tab
│   │   │       └── _settings_nav_item.dart    # Navigation item component
│   │   ├── theme/
│   │   │   └── tokens.dart                   # Design tokens: colors, spacing, radii, durations
│   │   └── window/
│   │       └── custom_title_bar.dart          # Window title bar (glass, drag, controls)
│   └── l10n/                              # Localization
│       ├── app_localizations.dart             # Generated localizations
│       ├── app_localizations_en.dart          # English translations
│       └── app_localizations_zh.dart          # Chinese translations
├── test/                                  # Test suite
├── windows/                               # Windows platform code (Win32 runner)
├── macos/                                 # macOS platform code
├── linux/                                 # Linux platform code
├── assets/                                # Static assets
├── docs/                                  # Documentation
├── packages/                              # Local packages
├── integration_test/                      # Integration tests
├── scripts/                               # Build/utility scripts
├── patches/                               # Platform patches
└── tool/                                  # Dev tooling
```

## Directory Purposes

**`lib/features/player/`:**
- Purpose: Player feature module -- DI container, business logic composition, sub-module services
- Contains: PlayerServices (DI), PlaybackController (facade), PlaybackNavigator, FileOperations, StateMonitor, SubtitleService, VideoProcessingService, BreakpointSaver
- Key files: `player_services.dart`, `player_feature.dart`, `services/playback_controller.dart`

**`lib/kernel/engine/`:**
- Purpose: fvp/MDK video engine wrapper -- abstract interface + concrete implementation + helpers
- Contains: EngineState mixin, FvpEngine, 8+ helper classes (PositionPoller, TrackManager, VolumeController, etc.), media models
- Key files: `engine_state.dart`, `fvp_engine.dart`, `media_state.dart`

**`lib/kernel/bridge/`:**
- Purpose: Window management and fullscreen abstraction -- abstract interfaces + concrete implementations per platform
- Contains: WindowBridge, WindowService, FullscreenDriver, DesktopFullscreenDriverFactory, platform-specific drivers (Windows/macOS/Linux), Win32 FFI bindings
- Key files: `window_bridge.dart`, `window_service.dart`, `fullscreen_driver.dart`, `desktop_fullscreen_driver_factory.dart`

**`lib/kernel/models/`:**
- Purpose: Shared immutable data models used across kernel and features layers
- Contains: PlaylistItem, PlayMode, AppSettings, AspectRatioMode, FullscreenCapability, PlayerError, ValidationError
- Key files: `playlist_item.dart`, `play_mode.dart`, `app_settings.dart`

**`lib/kernel/persistence/`:**
- Purpose: Data persistence -- SharedPreferences for settings, JSON files for playlist
- Contains: SettingsStore (with validation), SettingsValidator, PlaylistStore
- Key files: `settings_store.dart`, `playlist_store.dart`

**`lib/kernel/services/`:**
- Purpose: Cross-cutting kernel services -- thumbnail, locale, theme, hotkey, path validation
- Contains: ThumbnailService (platform-aware with LRU cache), LocaleService, ThemeService, GlobalHotkeyService, PathValidator
- Key files: `thumbnail_service.dart`, `locale_service.dart`, `theme_service.dart`

**`lib/kernel/startup/`:**
- Purpose: App startup coordination -- phase tracking, progress reporting
- Contains: StartupCoordinator (phase-based timeline), StartupState (immutable value object)
- Key files: `startup_coordinator.dart`, `startup_state.dart`

**`lib/kernel/utils/`:**
- Purpose: Shared utilities -- logging, time formatting, path operations, debug tools
- Contains: log, time_utils, path_utils, screen_utils, debug_probe, debug_exporter, perf_monitor, memory_monitor
- Key files: `log.dart`, `path_utils.dart`

**`lib/ui/player/`:**
- Purpose: Player screen and all interactive overlay components
- Contains: PlayerScreen (main composition), ControlsOverlay (auto-hide), ControlBar (bottom bar), ProgressBar, VolumeControls, SpeedButton, KeyboardHandler, VideoSurface, DropHandler, AutoHideController, center/left/right control groups
- Key files: `player_screen.dart`, `controls_overlay.dart`, `control_bar.dart`

**`lib/ui/shared/`:**
- Purpose: Reusable UI components used across player, playlist, and dialogs
- Contains: GlassContainer (glassmorphism), AuroraBackground, OSD overlay, EmptyState, GlassButton, MergedListenable, ValueListenableBuilder2, play_mode_utils, settings row components
- Key files: `glass_container.dart`, `osd_overlay.dart`, `empty_state.dart`

**`lib/ui/playlist/`:**
- Purpose: Floating playlist panel with folder and history tabs
- Contains: PlaylistPanel, FolderTab, HistoryTab, ThumbnailTile
- Key files: `playlist_panel.dart`

**`lib/ui/dialogs/`:**
- Purpose: Dialog components for settings and media info
- Contains: SettingsPanel (side panel), MediaInfoDialog, settings tabs (General/Audio/Video/Equalizer/Shortcuts/Performance/About)
- Key files: `settings_panel.dart`, `media_info_dialog.dart`

**`lib/ui/theme/`:**
- Purpose: Design system tokens -- all compile-time constants
- Contains: Tokens (colors, spacing, radii, durations, font sizes, breakpoints)
- Key files: `tokens.dart`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App bootstrap (Flutter binding, prefs, window, engine prewarm, runApp)
- `lib/app.dart`: MaterialApp shell (theme, locale, settings, quick menu)

**Configuration:**
- `lib/ui/theme/tokens.dart`: All design tokens (compile-time const)
- `lib/kernel/engine/engine_constants.dart`: Engine defaults and limits
- `lib/kernel/persistence/settings_validator.dart`: Input validation rules
- `pubspec.yaml`: Dependencies and Flutter config
- `analysis_options.yaml`: Dart analysis rules
- `l10n.yaml`: Localization config

**Core Logic:**
- `lib/kernel/engine/engine_state.dart`: Abstract engine interface (all ValueNotifier state)
- `lib/kernel/engine/fvp_engine.dart`: Concrete engine implementation (6 helpers)
- `lib/features/player/services/playback_controller.dart`: Playback orchestration facade
- `lib/kernel/bridge/window_service.dart`: Window management coordinator

**Testing:**
- `test/`: Unit and widget tests
- `integration_test/`: Integration tests

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files
- Feature files: `{feature_name}_feature.dart` (e.g., `player_feature.dart`)
- Service files: `{service_name}_service.dart` (e.g., `thumbnail_service.dart`)
- Model files: `{model_name}.dart` (e.g., `playlist_item.dart`)
- Widget files: `{widget_name}.dart` matching the primary widget class name (e.g., `player_screen.dart`)
- Abstract interfaces: no prefix, just the concept name (e.g., `window_bridge.dart`, `fullscreen_driver.dart`)
- Platform drivers: `{platform}_{feature}_driver.dart` (e.g., `windows_fullscreen_driver.dart`)

**Directories:**
- `snake_case` for all directories
- Feature modules under `lib/features/{feature_name}/`
- Platform-specific code under `{kernel/bridge/platform/}` or `{kernel/bridge/win32/}`
- Settings tabs under `lib/ui/dialogs/settings/`

## Where to Add New Code

**New Feature Module:**
- Implementation: `lib/features/{feature_name}/`
- Models: `lib/features/{feature_name}/models/`
- Services: `lib/features/{feature_name}/services/`
- Register in `PlayerServices` if player-related, or create standalone service

**New Engine Capability:**
- Interface method: add to `lib/kernel/engine/engine_state.dart`
- Implementation: add to `lib/kernel/engine/fvp_engine.dart` or create new helper in `lib/kernel/engine/`
- Helper files: `lib/kernel/engine/{helper_name}.dart`

**New Window/Fullscreen Feature:**
- Abstract interface: `lib/kernel/bridge/fullscreen_driver.dart` or `lib/kernel/bridge/window_bridge.dart`
- Platform implementation: `lib/kernel/bridge/platform/{platform}_{feature}.dart`
- Win32 FFI: `lib/kernel/bridge/win32/win32_{feature}.dart`

**New UI Component:**
- Player-related: `lib/ui/player/{component_name}.dart`
- Shared/reusable: `lib/ui/shared/{component_name}.dart`
- Dialog: `lib/ui/dialogs/{dialog_name}.dart`
- Settings tab: `lib/ui/dialogs/settings/{tab_name}_tab.dart`

**New Data Model:**
- Shared model: `lib/kernel/models/{model_name}.dart`
- Feature-specific model: `lib/features/{feature}/models/{model_name}.dart`

**New Utility:**
- Kernel utility: `lib/kernel/utils/{utility_name}.dart`
- UI utility: `lib/ui/shared/{utility_name}.dart`

**New Test:**
- Unit test: `test/{area}/{test_name}_test.dart`
- Widget test: `test/widget/{test_name}_test.dart`
- Regression test: `test/regression/{suite_name}_test.dart`

## Special Directories

**`lib/l10n/`:**
- Purpose: Auto-generated localization code from ARB files
- Generated: Yes (by `gen_l10n`)
- Committed: Yes (generated files checked in)

**`lib/kernel/engine/models/`:**
- Purpose: Engine-specific data models (media info, track info, codec info)
- Generated: No
- Committed: Yes

**`lib/ui/dialogs/settings/`:**
- Purpose: Individual settings tab components (General, Audio, Video, Equalizer, Shortcuts, Performance, About)
- Generated: No
- Committed: Yes

**`lib/kernel/bridge/win32/`:**
- Purpose: Win32-specific FFI bindings and display enumeration
- Generated: No (manual FFI bindings, not ffigen)
- Committed: Yes

**`lib/kernel/bridge/platform/`:**
- Purpose: Platform-specific fullscreen driver implementations
- Generated: No
- Committed: Yes

**`build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No

**`windows/`, `macos/`, `linux/`:**
- Purpose: Platform runner code (main entry points for each OS)
- Generated: Partially (Flutter template) + manual modifications
- Committed: Yes

**`packages/`:**
- Purpose: Local packages (if any)
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-07-12*
