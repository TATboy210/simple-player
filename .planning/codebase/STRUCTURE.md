<!-- refreshed: 2026-06-23 -->
# Codebase Structure

**Analysis Date:** 2026-06-23

## Stats

| Metric | Value |
|--------|-------|
| Dart files (lib/) | 110 |
| Total lines (lib/) | 15,884 |
| Test files | 61 |
| Layers | 3 (Kernel / Features / UI) |

## Directory Layout

```
lib/
├── main.dart                          # Entry point (40 lines)
├── app.dart                           # MaterialApp shell (201 lines)
├── kernel/                            # Core logic -- no UI dependencies
│   ├── engine/                        # fvp/MDK engine wrapper (12 files, 1515 lines)
│   │   ├── fvp_engine.dart            # Concrete fvp implementation (724 lines) ★
│   │   ├── fvp_callback_handler.dart  # mdk callback registration + state mapping
│   │   ├── engine_prewarm.dart        # Startup prewarm (FFmpeg + D3D11)
│   │   ├── position_poller.dart       # Adaptive position polling (250ms/100ms)
│   │   ├── track_manager.dart         # Audio/subtitle track selection
│   │   ├── media_opener.dart          # Media file open logic
│   │   ├── d3d11_configurator.dart    # D3D11 rendering configuration
│   │   ├── network_configurator.dart  # Network stream timeout/probe config
│   │   ├── subtitle_configurator.dart # Subtitle rendering configuration
│   │   ├── video_effect_controller.dart # Video effects (brightness/contrast)
│   │   ├── volume_controller.dart     # Volume/mute engine commands
│   │   └── open_result.dart           # Open result data class
│   ├── bridge/                        # Platform window control (9 files, 839 lines)
│   │   ├── window_service.dart        # Thin coordinator (262 lines)
│   │   ├── window_bridge.dart         # Abstract interface (26 lines)
│   │   ├── window_state.dart          # State container (47 lines)
│   │   ├── window_mode.dart           # WindowMode enum (19 lines)
│   │   ├── window_persistence.dart    # Debounced geometry save (78 lines)
│   │   ├── fullscreen_controller.dart # Atomic fullscreen with mutex (167 lines)
│   │   ├── platform_fullscreen.dart   # Platform abstraction (43 lines)
│   │   ├── display_config.dart        # Refresh-rate-aware D3D11 sync policy
│   │   └── win32/
│   │       └── win32_platform_fullscreen.dart  # Win32 FFI fullscreen (140 lines)
│   ├── models/                        # Data classes (7 files, 471 lines)
│   │   ├── app_settings.dart          # Settings data class with copyWith (167 lines)
│   │   ├── playlist_item.dart         # PlaylistItem (path, timestamp, position) (68 lines)
│   │   ├── play_mode.dart             # LoopAll/LoopSingle/Shuffle enum (9 lines)
│   │   ├── player_error.dart          # PlayerError + PlayerErrorCode enum
│   │   ├── validation_error.dart      # Path validation errors
│   │   ├── aspect_ratio_mode.dart     # Aspect ratio enum with mdk values
│   │   └── media_info.dart            # MediaInfo model (external, from player_engine)
│   ├── persistence/                   # SharedPreferences storage (2 files, 657 lines)
│   │   ├── settings_store.dart        # App settings persistence (439 lines) ★
│   │   └── playlist_store.dart        # Playlist JSON save/load (218 lines)
│   ├── playlist/                      # Playlist model (1 file, 283 lines)
│   │   └── playlist.dart             # Playlist state machine + 3 play modes
│   ├── scanner/                       # Directory scanner (1 file, 72 lines)
│   │   └── folder_scanner.dart        # Video file discovery (non-recursive)
│   ├── services/                      # Kernel-level services (8 files, ~500 lines)
│   │   ├── thumbnail_service.dart     # Platform-aware thumbnail facade (LRU cache)
│   │   ├── thumbnail_provider.dart    # Abstract thumbnail interface (10 lines)
│   │   ├── noop_thumbnail_provider.dart   # Fallback (no-op)
│   │   ├── linux_thumbnail_provider.dart  # Linux XDG implementation
│   │   ├── macos_thumbnail_provider.dart  # macOS implementation
│   │   ├── path_validator.dart        # Path safety validation (115 lines)
│   │   ├── locale_service.dart        # Locale singleton + persistence
│   │   └── theme_service.dart         # Theme accent singleton
│   ├── startup/                       # Startup coordination (2 files, 166 lines)
│   │   ├── startup_coordinator.dart   # Phase-based progress tracking (98 lines)
│   │   └── startup_state.dart         # StartupState + StartupPhase enum (68 lines)
│   └── utils/                         # Shared utilities (6 files, 632 lines)
│       ├── log.dart                   # Logger with rotating file output (284 lines)
│       ├── time_utils.dart            # formatMs()
│       ├── path_utils.dart            # Path basename/dirname + openFileLocation
│       ├── perf_monitor.dart          # Frame timing monitor (ring buffer)
│       ├── memory_monitor.dart        # RSS memory logger (debug only)
│       └── screen_utils.dart          # Multi-monitor clamping
├── features/                          # Feature-specific orchestration
│   └── player/                        # Player feature (10 files, 1050 lines)
│       ├── deferred_player_feature.dart  # Deferred loading wrapper (97 lines)
│       ├── player_feature.dart        # Player UI state + composition (185 lines)
│       ├── player_services.dart       # Service container + lifecycle (45 lines)
│       ├── models/
│       │   └── video_processing_state.dart  # Immutable state with copyWith
│       └── services/
│           ├── playback_controller.dart    # Unified playback entry (118 lines)
│           ├── playback_navigator.dart     # Track advancement + open guard (83 lines)
│           ├── file_operations.dart        # File open/drop + validation (71 lines)
│           ├── state_monitor.dart          # Auto-advance + resume (119 lines)
│           ├── video_processing_service.dart  # Color/rotation/aspect
│           └── subtitle_service.dart       # External subtitle loading
├── ui/                                # Visual components -- depends on Kernel + Features
│   ├── theme/
│   │   └── tokens.dart                # Design tokens -- compile-time constants (137 lines)
│   ├── player/                        # Player screen components (15 files)
│   │   ├── player_screen.dart         # Main screen compositing (338 lines) ★
│   │   ├── custom_title_bar.dart      # Window title bar (moved to window/)
│   │   ├── controls_overlay.dart      # Auto-hide control layer (189 lines)
│   │   ├── control_bar.dart           # Bottom glass bar (350 lines)
│   │   ├── progress_bar.dart          # Seekbar + thumbnails (282 lines)
│   │   ├── volume_controls.dart       # Volume slider + mute
│   │   ├── speed_button.dart          # Playback speed selector
│   │   ├── keyboard_handler.dart      # 20+ key Focus handler (212 lines)
│   │   ├── video_surface.dart         # Texture renderer
│   │   ├── auto_hide_controller.dart  # Auto-hide timer logic
│   │   ├── drop_handler.dart          # Drag-and-drop file handling
│   │   ├── center_controls.dart       # Center play/pause overlay
│   │   ├── error_banner.dart          # Error display banner
│   │   ├── time_range_display.dart    # Time range label
│   │   └── player_actions.dart        # Player action handlers
│   ├── playlist/                      # Immersive floating playlist (4 files)
│   │   ├── playlist_panel.dart        # Floating window (358 lines)
│   │   ├── folder_tab.dart            # Folder-grouped thumbnails (306 lines)
│   │   ├── history_tab.dart           # Timestamp-sorted history (187 lines)
│   │   └── thumbnail_tile.dart        # 16:9 thumbnail card (309 lines)
│   ├── shared/                        # Reusable glass widgets (18 files, 2188 lines)
│   │   ├── glass_container.dart       # Glassmorphism wrapper (270 lines)
│   │   ├── glass_widgets.dart         # GlassButton, GlassIconButton
│   │   ├── glass_chip.dart            # Glass chip component
│   │   ├── empty_state.dart           # Empty state screen (258 lines)
│   │   ├── aurora_background.dart     # Animated aurora background (362 lines)
│   │   ├── settings_card.dart         # Settings card component (273 lines)
│   │   ├── settings_expander_card.dart  # Expandable settings card
│   │   ├── settings_action_card.dart  # Action settings card
│   │   ├── setting_slider_row.dart    # Slider setting row
│   │   ├── setting_action_row.dart    # Action setting row
│   │   ├── app_dialog.dart            # Base dialog wrapper
│   │   ├── context_menu_row.dart      # Context menu item
│   │   ├── play_mode_utils.dart       # PlayMode -> icon/label
│   │   ├── splash_screen.dart         # Legacy splash screen
│   │   ├── progress_splash_screen.dart  # Progress splash with phases
│   │   ├── value_listenable_builder2.dart  # Dual-notifier builder
│   │   ├── merged_listenable.dart     # Merge two notifiers
│   │   └── osd_overlay.dart           # Floating OSD pill
│   ├── window/                        # Window-specific UI (1 file, 146 lines)
│   │   └── custom_title_bar.dart      # Frameless window title bar
│   ├── widgets/                       # (legacy, minimal)
│   └── dialogs/                       # Settings and info dialogs (10 files, 1827 lines)
│       ├── settings_panel.dart        # Settings panel with sidebar nav (402 lines) ★
│       ├── media_info_dialog.dart     # File properties dialog (222 lines)
│       └── settings/                  # Settings tab pages (8 files, 1203 lines)
│           ├── _settings_nav_item.dart  # Sidebar nav item
│           ├── general_tab.dart       # General settings (216 lines)
│           ├── video_tab.dart         # Video settings (317 lines)
│           ├── audio_tab.dart         # Audio settings
│           ├── equalizer_tab.dart     # Equalizer settings
│           ├── shortcuts_tab.dart     # Keyboard shortcuts (243 lines)
│           ├── settings_tab_performance.dart  # D3D11/hardware decoding
│           └── about_tab.dart         # About dialog
└── l10n/                              # Localization (auto-generated, 1964 lines)
    ├── app_en.arb                     # English strings
    ├── app_zh.arb                     # Chinese strings
    ├── app_localizations.dart         # Generated (1022 lines)
    ├── app_localizations_en.dart      # Generated English (472 lines)
    └── app_localizations_zh.dart      # Generated Chinese (470 lines)
```

## Largest Files (>300 lines, excluding generated)

| File | Lines | Category | Notes |
|------|-------|----------|-------|
| `lib/kernel/engine/fvp_engine.dart` | 724 | Engine | 13 ValueNotifiers + 7 helper composition |
| `lib/kernel/persistence/settings_store.dart` | 439 | Persistence | 24+ save/load methods, SharedPreferences |
| `lib/ui/dialogs/settings_panel.dart` | 402 | UI | Sidebar navigation, 7 tabs |
| `lib/ui/shared/aurora_background.dart` | 362 | UI | Animated visual component |
| `lib/ui/playlist/playlist_panel.dart` | 358 | UI | Floating playlist window |
| `lib/ui/player/control_bar.dart` | 350 | UI | Bottom glass control bar |
| `lib/ui/player/player_screen.dart` | 338 | UI | Main screen compositing |
| `lib/ui/dialogs/settings/video_tab.dart` | 317 | UI | Video processing controls |
| `lib/ui/playlist/thumbnail_tile.dart` | 309 | UI | 16:9 thumbnail card |
| `lib/ui/playlist/folder_tab.dart` | 306 | UI | Folder-grouped view |
| `lib/kernel/utils/log.dart` | 284 | Utils | Module-scoped loggers |
| `lib/kernel/playlist/playlist.dart` | 283 | Playlist | State machine + 3 play modes |
| `lib/ui/player/progress_bar.dart` | 282 | UI | Seekbar + thumbnails |
| `lib/ui/shared/settings_card.dart` | 273 | UI | Settings card component |
| `lib/ui/shared/glass_container.dart` | 270 | UI | Glassmorphism wrapper |

## Directory Purposes

**`lib/kernel/engine/`:**
- Purpose: Media playback engine abstraction and fvp/MDK implementation
- Contains: Concrete implementation (`FvpEngine`), 7 helper classes for callback handling, position polling, track management, media opening, D3D11/network/subtitle configuration, video effects, volume control
- Key files: `fvp_engine.dart` (724 lines -- largest non-generated file)
- Note: Abstract `PlayerEngine` interface comes from external `player_engine` package

**`lib/kernel/bridge/`:**
- Purpose: Platform window management with thin coordinator pattern
- Contains: `WindowService` (coordinator), `WindowBridge` (abstract interface), `WindowState` (state container), `FullscreenController` (atomic fullscreen with mutex), `PlatformFullscreen` (platform abstraction), `WindowPersistence` (debounced save), `DisplayConfig` (refresh rate policy), `Win32PlatformFullscreen` (Win32 FFI)
- Key files: `window_service.dart` (262 lines), `fullscreen_controller.dart` (167 lines)
- Design: WindowService delegates to 4 composed components (WindowState, FullscreenController, WindowPersistence, PlatformFullscreen)

**`lib/kernel/models/`:**
- Purpose: Pure data classes and enums with no business logic
- Contains: 7 files, 471 lines total -- all small, focused files
- Key files: `app_settings.dart` (167 lines, largest model), `playlist_item.dart` (68 lines), `play_mode.dart` (9 lines)

**`lib/kernel/persistence/`:**
- Purpose: SharedPreferences-based persistence
- Contains: `SettingsStore` (24+ save/load methods with prewarm cache), `PlaylistStore` (JSON serialization with background isolate loading)
- Key files: `settings_store.dart` (439 lines), `playlist_store.dart` (218 lines)

**`lib/kernel/playlist/`:**
- Purpose: Playlist data model and navigation logic
- Contains: `Playlist` class with 3 play modes (LoopAll, LoopSingle, Shuffle)
- Key files: `playlist.dart` (283 lines)
- Note: CQS pattern -- `peekNext()`/`peekPrevious()` return index, caller updates state

**`lib/kernel/services/`:**
- Purpose: Kernel-level services (thumbnails, validation, locale, theme)
- Contains: 8 files including platform-dispatched thumbnail providers (Windows/Linux/macOS), path validator, locale/theme singletons
- Key files: `thumbnail_service.dart` (facade + LRU cache), `path_validator.dart` (115 lines)

**`lib/kernel/startup/`:**
- Purpose: Phase-based startup progress coordination
- Contains: `StartupCoordinator` (report/markReady), `StartupState` (phase enum + progress)
- Key files: `startup_coordinator.dart` (98 lines)

**`lib/kernel/utils/`:**
- Purpose: Shared utility functions
- Contains: Logger setup with rotating file output, time formatting, path utilities, perf monitoring, memory monitoring, screen utils
- Key files: `log.dart` (284 lines -- module-scoped loggers), `screen_utils.dart` (multi-monitor clamping)

**`lib/features/player/`:**
- Purpose: Player feature orchestration -- bridges kernel services to UI
- Contains: Service container (`PlayerServices`), playback orchestration (`PlaybackController` + 3 sub-modules), video processing, subtitle handling, deferred loading
- Key files: `player_services.dart` (service wiring), `deferred_player_feature.dart` (lazy loading), `playback_controller.dart` (facade)

**`lib/ui/player/`:**
- Purpose: Player screen visual components
- Contains: 15 files -- main screen, controls, progress bar, keyboard handler, video surface, drag-drop, speed button, volume controls, auto-hide controller
- Key files: `player_screen.dart` (338 lines, compositing root), `controls_overlay.dart` (189 lines), `control_bar.dart` (350 lines)

**`lib/ui/playlist/`:**
- Purpose: Immersive floating playlist panel
- Contains: 4 files -- panel, folder tab, history tab, thumbnail tile
- Key files: `playlist_panel.dart` (358 lines)

**`lib/ui/shared/`:**
- Purpose: Reusable glass-morphism widgets and utility components
- Contains: 18 files -- the largest UI directory by file count
- Key files: `glass_container.dart` (270 lines), `aurora_background.dart` (362 lines), `empty_state.dart` (258 lines)

**`lib/ui/window/`:**
- Purpose: Window-specific UI components
- Contains: 1 file -- custom title bar for frameless window
- Key files: `custom_title_bar.dart` (146 lines)

**`lib/ui/dialogs/`:**
- Purpose: Settings panel and media info dialogs
- Contains: 3 files + `settings/` subdirectory with 8 tab pages
- Key files: `settings_panel.dart` (402 lines, sidebar nav)

## Naming Conventions

**Files:**
- snake_case for all Dart files: `playback_controller.dart`, `glass_container.dart`
- Feature-prefixed when ambiguous: `playback_controller.dart`, `playback_navigator.dart`
- Suffix indicates role: `_service.dart`, `_controller.dart`, `_store.dart`, `_provider.dart`, `_coordinator.dart`, `_configurator.dart`
- Private prefixed with underscore: `_settings_nav_item.dart`

**Directories:**
- Lowercase: `engine/`, `bridge/`, `models/`, `services/`, `utils/`
- Feature-named: `player/`, `playlist/`
- Platform-specific: `win32/` subdirectory under `bridge/`

## Where to Add New Code

**New Engine Feature (e.g., new codec support):**
- Implementation: `lib/kernel/engine/`
- Abstract method: Add to `PlayerEngine` in `player_engine` package
- Tests: `test/kernel/engine/`

**New Playback Service (e.g., bookmark service):**
- Implementation: `lib/features/player/services/`
- Wire into: `lib/features/player/player_services.dart` (add field + init/dispose)
- Wire into: `lib/features/player/services/playback_controller.dart` (add forwarding method)
- Tests: `test/kernel/services/` or `test/features/player/services/`

**New UI Component:**
- Reusable glass widget: `lib/ui/shared/`
- Player-specific widget: `lib/ui/player/`
- Dialog: `lib/ui/dialogs/` or `lib/ui/dialogs/settings/` for settings tabs
- Tests: `test/widget/player/` or `test/widget/shared/`

**New Data Model:**
- Enum or data class: `lib/kernel/models/`
- Tests: `test/kernel/models/`

**New Persistence:**
- Add method to `lib/kernel/persistence/settings_store.dart`
- Or new store file in `lib/kernel/persistence/`
- Tests: `test/kernel/persistence/`

**New Platform Bridge:**
- Abstract interface: `lib/kernel/bridge/` (e.g., `platform_fullscreen.dart`)
- Platform implementation: `lib/kernel/bridge/win32/` (or `macos/`, `linux/`)
- Coordinator integration: `lib/kernel/bridge/window_service.dart`

## Import Graph Highlights

**External package dependencies:**
- `player_engine` -- abstract `PlayerEngine` interface (local path: `../widget_tree_flutter/player_engine`)
- `fvp` -- MDK/FFmpeg media engine (version ^0.37.2)
- `window_manager` -- cross-platform window management
- `shared_preferences` -- key-value persistence
- `file_picker` -- native file picker
- `desktop_drop` -- drag-and-drop support
- `logger` -- structured logging
- `path_provider` -- app directory paths
- `crypto` -- MD5 for Linux thumbnails
- `ffi` -- Dart FFI for Win32 fullscreen
- `freezed_annotation` / `json_annotation` -- code generation annotations

**Layer boundary enforcement:**
- Kernel never imports from `lib/features/` or `lib/ui/`
- Features imports from `lib/kernel/` only
- UI imports from `lib/kernel/` (models, services) and `lib/features/` (controllers)
- `player_engine` package provides abstract types that all layers share

**Key import chains:**
- `main.dart` -> `app.dart` -> `deferred_player_feature.dart` -> `player_feature.dart` -> `player_screen.dart`
- `player_screen.dart` -> `control_bar.dart`, `progress_bar.dart`, `controls_overlay.dart`, `playlist_panel.dart`
- `playback_controller.dart` -> `playback_navigator.dart`, `file_operations.dart`, `state_monitor.dart`
- `fvp_engine.dart` -> `fvp_callback_handler.dart`, `position_poller.dart`, `track_manager.dart`, `media_opener.dart`, `video_effect_controller.dart`, `volume_controller.dart`
- `window_service.dart` -> `window_state.dart`, `fullscreen_controller.dart`, `window_persistence.dart`, `platform_fullscreen.dart`

## Special Directories

**`lib/l10n/`:**
- Purpose: Localization ARB files and generated Dart code
- Generated: Yes (`app_localizations*.dart` by `gen-l10n`)
- Committed: Yes (generated files are version-controlled)

**`test/`:**
- Purpose: Unit, widget, golden, and integration tests
- Generated: No (hand-written)
- Committed: Yes
- Structure: Mirrors `lib/` with additional `helpers/`, `golden/`, `integration/`, `unit/`, `widget/`, `perf/` categories
- Total: 61 test files, 9070 lines

**`test/helpers/`:**
- Purpose: Test doubles and utilities
- Key files: `fake_engine.dart` (372 lines -- FakeEngine for testing), `fake_window_service.dart`, `integration_helpers.dart`

**`.planning/`:**
- Purpose: Planning documents and codebase analysis
- Generated: No (hand-written)
- Committed: Yes

---

*Structure analysis: 2026-06-23*
