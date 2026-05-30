<!-- refreshed: 2026-05-30 -->
# Codebase Structure

**Analysis Date:** 2026-05-30

## Stats

| Metric | Value |
|--------|-------|
| Dart files (lib/) | 98 |
| Total lines (lib/) | 14,902 |
| Test files | 52 |
| Layers | 3 (Kernel / Features / UI) |

## Directory Layout

```
lib/
├── main.dart                          # Entry point (50 lines)
├── app.dart                           # MaterialApp shell (219 lines)
├── kernel/                            # Core logic — no UI dependencies
│   ├── engine/                        # fvp/MDK engine wrapper (6 files)
│   │   ├── media_engine.dart          # Abstract engine interface (185 lines)
│   │   ├── fvp_engine.dart            # Concrete fvp implementation (690 lines) ★
│   │   ├── fvp_callback_handler.dart  # mdk callback registration
│   │   ├── engine_prewarm.dart        # Startup prewarm (FFmpeg + D3D11)
│   │   ├── position_poller.dart       # 250ms Timer-based position polling
│   │   └── track_manager.dart         # Audio/subtitle track selection
│   ├── bridge/                        # Platform window control (2 files)
│   │   ├── window_service.dart        # Win32 window management (329 lines)
│   │   └── win32_bindings.dart        # FFI type definitions + Win32 constants
│   ├── models/                        # Data classes (10 files, 485 lines total)
│   │   ├── media_state.dart           # Playback state enum (9 states)
│   │   ├── media_info.dart            # Codec/resolution metadata
│   │   ├── playlist_item.dart         # PlaylistItem (path, timestamp, position)
│   │   ├── play_mode.dart             # LoopAll/LoopSingle/Shuffle enum
│   │   ├── media_error_type.dart      # Error type enum
│   │   ├── player_error.dart          # PlayerError exception class
│   │   ├── validation_error.dart      # Path validation errors
│   │   ├── aspect_ratio_mode.dart     # Aspect ratio enum
│   │   ├── app_settings.dart          # Settings data class (167 lines)
│   │   └── video_effect_type.dart     # Video effect enum
│   ├── persistence/                   # SharedPreferences storage (2 files)
│   │   ├── settings_store.dart        # App settings persistence (439 lines) ★
│   │   └── playlist_store.dart        # Playlist JSON save/load (218 lines)
│   ├── playlist/                      # Playlist model (1 file)
│   │   └── playlist.dart             # Playlist + 4 play modes (283 lines)
│   ├── scanner/                       # Directory scanner (1 file)
│   │   └── folder_scanner.dart        # Video file discovery (non-recursive)
│   ├── services/                      # Kernel-level services (8 files)
│   │   ├── thumbnail_service.dart     # Platform-aware thumbnail facade (LRU cache)
│   │   ├── thumbnail_provider.dart    # Abstract thumbnail interface
│   │   ├── noop_thumbnail_provider.dart   # Fallback (no-op)
│   │   ├── linux_thumbnail_provider.dart  # Linux implementation
│   │   ├── macos_thumbnail_provider.dart  # macOS implementation
│   │   ├── path_validator.dart        # Path safety validation
│   │   ├── locale_service.dart        # Locale singleton + persistence
│   │   └── theme_service.dart         # Theme accent singleton
│   ├── startup/                       # Startup coordination (2 files)
│   │   ├── startup_coordinator.dart   # Phase-based progress tracking (99 lines)
│   │   └── startup_state.dart         # StartupState + StartupPhase enum
│   └── utils/                         # Shared utilities (4 files)
│       ├── log.dart                   # Logger with rotating file output (136 lines)
│       ├── time_utils.dart            # formatMs()
│       ├── path_utils.dart            # Path validation helpers
│       └── perf_monitor.dart          # Performance monitoring
├── features/                          # Feature-specific orchestration
│   └── player/                        # Player feature (10 files)
│       ├── deferred_player_feature.dart  # Deferred loading wrapper (94 lines)
│       ├── player_feature.dart        # Player UI state + composition (183 lines)
│       ├── player_services.dart       # Service container + lifecycle (46 lines)
│       ├── models/
│       │   └── video_processing_state.dart  # Immutable state with copyWith
│       └── services/
│           ├── playback_controller.dart    # Unified playback entry (119 lines)
│           ├── playback_navigator.dart     # Track advancement + open guard
│           ├── file_operations.dart        # File open/drop + validation
│           ├── state_monitor.dart          # Auto-advance + resume
│           ├── video_processing_service.dart  # Color/rotation/aspect (245+ lines)
│           └── subtitle_service.dart       # External subtitle loading
├── ui/                                # Visual components — depends on Kernel + Features
│   ├── theme/
│   │   └── tokens.dart                # Design tokens — compile-time constants
│   ├── player/                        # Player screen components (10 files)
│   │   ├── player_screen.dart         # Main screen compositing (309 lines)
│   │   ├── custom_title_bar.dart      # Window title bar (191 lines)
│   │   ├── controls_overlay.dart      # Auto-hide control layer (221 lines)
│   │   ├── control_bar.dart           # Bottom glass bar (287 lines)
│   │   ├── progress_bar.dart          # Seekbar + thumbnails (282 lines)
│   │   ├── volume_controls.dart       # Volume slider + mute
│   │   ├── speed_button.dart          # Playback speed selector
│   │   ├── keyboard_handler.dart      # 20+ key Focus handler (212 lines)
│   │   ├── video_surface.dart         # Texture renderer
│   │   ├── auto_hide_controller.dart  # Auto-hide timer logic
│   │   └── drop_handler.dart          # Drag-and-drop file handling
│   ├── playlist/                      # Immersive floating playlist (4 files)
│   │   ├── playlist_panel.dart        # Floating window (333 lines)
│   │   ├── folder_tab.dart            # Folder-grouped thumbnails (306 lines)
│   │   ├── history_tab.dart           # Timestamp-sorted history (187 lines)
│   │   └── thumbnail_tile.dart        # 16:9 thumbnail card (309 lines)
│   ├── shared/                        # Reusable glass widgets (17 files)
│   │   ├── glass_container.dart       # Glassmorphism wrapper (245 lines)
│   │   ├── glass_widgets.dart         # GlassButton, GlassIconButton
│   │   ├── glass_chip.dart            # Glass chip component
│   │   ├── empty_state.dart           # Empty state screen (258 lines)
│   │   ├── aurora_background.dart     # Animated aurora background (358 lines)
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
│   │   └── merged_listenable.dart     # Merge two notifiers
│   ├── widgets/
│   │   └── osd_overlay.dart           # Floating OSD pill
│   └── dialogs/                       # Settings and info dialogs (3 files + subdir)
│       ├── settings_panel.dart        # Settings panel with sidebar nav (402 lines) ★
│       ├── media_info_dialog.dart     # File properties dialog (223 lines)
│       └── settings/                  # Settings tab pages
│           ├── general_tab.dart       # General settings (216 lines)
│           ├── video_tab.dart         # Video settings (317 lines)
│           └── shortcuts_tab.dart     # Keyboard shortcuts (243 lines)
└── l10n/                              # Localization (auto-generated)
    ├── app_en.arb                     # English strings
    ├── app_zh.arb                     # Chinese strings
    ├── app_localizations.dart         # Generated (1022 lines)
    ├── app_localizations_en.dart      # Generated English (472 lines)
    └── app_localizations_zh.dart      # Generated Chinese (470 lines)
```

★ = Large files (>400 lines, excluding generated)

## Largest Files (>400 lines)

| File | Lines | Category | Notes |
|------|-------|----------|-------|
| `lib/l10n/app_localizations.dart` | 1022 | Generated | Auto-generated by gen-l10n |
| `lib/kernel/engine/fvp_engine.dart` | 690 | Engine | 13 ValueNotifiers + 3 helper composition |
| `lib/kernel/persistence/settings_store.dart` | 439 | Persistence | 24+ save/load methods, SharedPreferences |
| `lib/ui/dialogs/settings_panel.dart` | 402 | UI | Sidebar navigation, 4 tabs |
| `lib/ui/shared/aurora_background.dart` | 358 | UI | Animated visual component |
| `lib/ui/playlist/playlist_panel.dart` | 333 | UI | Floating playlist window |
| `lib/kernel/bridge/window_service.dart` | 329 | Bridge | Win32 FFI + DWM management |
| `lib/ui/dialogs/settings/video_tab.dart` | 317 | UI | Video processing controls |
| `lib/ui/player/player_screen.dart` | 309 | UI | Main screen compositing |
| `lib/ui/playlist/thumbnail_tile.dart` | 309 | UI | 16:9 thumbnail card |
| `lib/ui/playlist/folder_tab.dart` | 306 | UI | Folder-grouped view |

## Directory Purposes

**`lib/kernel/engine/`:**
- Purpose: Media playback engine abstraction and fvp/MDK implementation
- Contains: Abstract interface (`MediaEngine`), concrete implementation (`FvpEngine`), helper classes (`FvpCallbackHandler`, `PositionPoller`, `TrackManager`), startup prewarm
- Key files: `media_engine.dart` (interface), `fvp_engine.dart` (implementation)
- Note: `fvp_engine.dart` at 690 lines is the largest non-generated file -- consider extraction of network config constants

**`lib/kernel/bridge/`:**
- Purpose: Platform-specific window management via Win32 FFI
- Contains: `WindowService` (reactive state + commands), `win32_bindings.dart` (FFI typedefs + constants)
- Key files: `window_service.dart` (329 lines)
- Note: Direct FFI calls bypass MethodChannel for performance-critical paths (fullscreen, maximize)

**`lib/kernel/models/`:**
- Purpose: Pure data classes and enums with no business logic
- Contains: 10 files, 485 lines total -- all small, focused files
- Key files: `media_state.dart` (9-state enum), `app_settings.dart` (167 lines, largest model)

**`lib/kernel/persistence/`:**
- Purpose: SharedPreferences-based persistence
- Contains: `SettingsStore` (24+ save/load methods), `PlaylistStore` (JSON serialization)
- Key files: `settings_store.dart` (439 lines) -- consider splitting by domain

**`lib/kernel/playlist/`:**
- Purpose: Playlist data model and navigation logic
- Contains: `Playlist` class with 4 play modes (LoopAll, LoopSingle, Shuffle, Sequential)
- Key files: `playlist.dart` (283 lines)

**`lib/kernel/services/`:**
- Purpose: Kernel-level services (thumbnails, validation, locale, theme)
- Contains: 8 files including platform-dispatched thumbnail providers
- Key files: `thumbnail_service.dart` (facade + LRU cache), `path_validator.dart`

**`lib/kernel/startup/`:**
- Purpose: Phase-based startup progress coordination
- Contains: `StartupCoordinator` (report/markReady), `StartupState` (phase enum + progress)
- Key files: `startup_coordinator.dart` (99 lines)

**`lib/kernel/utils/`:**
- Purpose: Shared utility functions
- Contains: Logger setup with rotating file output, time formatting, path utilities, perf monitoring
- Key files: `log.dart` (136 lines, global `log` instance)

**`lib/features/player/`:**
- Purpose: Player feature orchestration -- bridges kernel services to UI
- Contains: Service container (`PlayerServices`), playback orchestration (`PlaybackController` + 3 sub-modules), video processing, subtitle handling, deferred loading
- Key files: `player_services.dart` (service wiring), `deferred_player_feature.dart` (lazy loading)

**`lib/ui/player/`:**
- Purpose: Player screen visual components
- Contains: 10 files -- main screen, title bar, controls, progress bar, keyboard handler, video surface, drag-drop
- Key files: `player_screen.dart` (309 lines, compositing root), `controls_overlay.dart` (auto-hide)

**`lib/ui/playlist/`:**
- Purpose: Immersive floating playlist panel
- Contains: 4 files -- panel, folder tab, history tab, thumbnail tile
- Key files: `playlist_panel.dart` (333 lines)

**`lib/ui/shared/`:**
- Purpose: Reusable glass-morphism widgets and utility components
- Contains: 17 files -- the largest UI directory by file count
- Key files: `glass_container.dart` (245 lines), `aurora_background.dart` (358 lines)

**`lib/ui/dialogs/`:**
- Purpose: Settings panel and media info dialogs
- Contains: 3 files + `settings/` subdirectory with 3 tab pages
- Key files: `settings_panel.dart` (402 lines, sidebar nav)

## Naming Conventions

**Files:**
- snake_case for all Dart files: `playback_controller.dart`, `glass_container.dart`
- Feature-prefixed when ambiguous: `playback_controller.dart`, `playback_navigator.dart`
- Suffix indicates role: `_service.dart`, `_controller.dart`, `_store.dart`, `_provider.dart`

**Directories:**
- Lowercase singular nouns: `engine/`, `bridge/`, `model/` (not `models/` -- note: `models/` exists in kernel and features)
- Feature-named: `player/`, `playlist/`

## Where to Add New Code

**New Engine Feature (e.g., new codec support):**
- Implementation: `lib/kernel/engine/`
- Abstract method: `lib/kernel/engine/media_engine.dart`
- Tests: `test/kernel/engine/`

**New Playback Service (e.g., bookmark service):**
- Implementation: `lib/features/player/services/`
- Wire into: `lib/features/player/player_services.dart`
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
- Service: `lib/kernel/bridge/`
- FFI bindings: `lib/kernel/bridge/win32_bindings.dart`

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

**`.planning/`:**
- Purpose: Planning documents and codebase analysis
- Generated: No (hand-written)
- Committed: Yes

---

*Structure analysis: 2026-05-30*
