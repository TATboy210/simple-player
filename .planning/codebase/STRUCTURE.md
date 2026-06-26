<!-- refreshed: 2026-06-26 -->

# Codebase Structure

## Directory Layout

```
simple_player_flutter/
├── lib/
│   ├── main.dart                          # Entry point (fvp init, window setup)
│   ├── app.dart                           # MaterialApp shell, service wiring
│   ├── kernel/                            # Core logic (no UI dependencies)
│   │   ├── bridge/                        # Window management abstraction
│   │   │   ├── win32/                     # Win32-specific implementations
│   │   │   ├── linux/                     # Linux-specific implementations
│   │   │   ├── macos/                     # macOS-specific implementations
│   │   │   ├── window_bridge.dart         # Abstract window interface (29 lines)
│   │   │   ├── window_service.dart        # Concrete Win32 implementation (257 lines)
│   │   │   ├── window_state.dart          # Window state container (47 lines)
│   │   │   ├── window_mode.dart           # WindowMode enum (19 lines)
│   │   │   ├── fullscreen_controller.dart # Atomic fullscreen + mutex
│   │   │   ├── platform_fullscreen.dart   # Platform fullscreen interface (43 lines)
│   │   │   ├── window_persistence.dart    # Debounced geometry save
│   │   │   └── display_config.dart        # Display/refresh rate detection
│   │   ├── engine/                        # fvp/MDK engine wrapper
│   │   │   ├── fvp_engine.dart            # Concrete engine (724 lines)
│   │   │   ├── position_poller.dart       # Timer-based position updates
│   │   │   ├── track_manager.dart         # Audio/subtitle track management
│   │   │   ├── fvp_callback_handler.dart  # MDK callback registration
│   │   │   ├── media_opener.dart          # Open logic helper
│   │   │   ├── d3d11_configurator.dart    # D3D11 settings (37 lines)
│   │   │   ├── network_configurator.dart  # Network stream config
│   │   │   ├── subtitle_configurator.dart # Subtitle settings (37 lines)
│   │   │   ├── video_effect_controller.dart # Video effects (51 lines)
│   │   │   ├── volume_controller.dart     # Volume control (35 lines)
│   │   │   ├── engine_prewarm.dart        # Background codec registration
│   │   │   └── open_result.dart           # Open result type (22 lines)
│   │   ├── models/                        # Data classes
│   │   │   ├── app_settings.dart          # AppSettings (immutable, copyWith)
│   │   │   ├── playlist_item.dart         # PlaylistItem (path, timestamp, position)
│   │   │   ├── play_mode.dart             # PlayMode enum (loopAll/loopSingle/shuffle)
│   │   │   ├── aspect_ratio_mode.dart     # AspectRatioMode enum (17 lines)
│   │   │   ├── player_error.dart          # PlayerError types
│   │   │   └── validation_error.dart      # ValidationError types (41 lines)
│   │   ├── persistence/                   # Storage
│   │   │   ├── settings_store.dart        # SharedPreferences persistence (436 lines)
│   │   │   └── playlist_store.dart        # Playlist JSON persistence
│   │   ├── playlist/
│   │   │   └── playlist.dart              # Playlist model + CQS navigation (283 lines)
│   │   ├── scanner/
│   │   │   └── folder_scanner.dart        # Directory video file scanner (72 lines)
│   │   ├── services/                      # Kernel-level services
│   │   │   ├── thumbnail_service.dart     # Platform-aware thumbnail facade
│   │   │   ├── thumbnail_provider.dart    # Abstract thumbnail interface (10 lines)
│   │   │   ├── linux_thumbnail_provider.dart (40 lines)
│   │   │   ├── macos_thumbnail_provider.dart (13 lines)
│   │   │   ├── noop_thumbnail_provider.dart (11 lines)
│   │   │   ├── path_validator.dart        # Path security validation
│   │   │   ├── locale_service.dart        # Locale management (35 lines)
│   │   │   └── theme_service.dart         # Theme management (49 lines)
│   │   ├── startup/
│   │   │   ├── startup_coordinator.dart   # Startup phase tracking
│   │   │   └── startup_state.dart         # StartupState data class
│   │   └── utils/                         # Shared utilities
│   │       ├── log.dart                   # Module-scoped loggers
│   │       ├── path_utils.dart            # Path manipulation
│   │       ├── time_utils.dart            # Time formatting (12 lines)
│   │       ├── screen_utils.dart          # Screen/display utilities (48 lines)
│   │       ├── memory_monitor.dart        # Memory usage monitoring
│   │       └── perf_monitor.dart          # Performance monitoring
│   ├── features/
│   │   └── player/
│   │       ├── player_feature.dart        # PlayerFeature StatefulWidget (186 lines)
│   │       ├── deferred_player_feature.dart # Lazy-loaded wrapper (98 lines)
│   │       ├── player_services.dart       # Service container (45 lines)
│   │       ├── models/
│   │       │   └── video_processing_state.dart
│   │       └── services/
│   │           ├── playback_controller.dart    # Unified playback entry (118 lines)
│   │           ├── playback_navigator.dart     # Index navigation + resume (83 lines)
│   │           ├── state_monitor.dart          # Auto-advance + persistence
│   │           ├── file_operations.dart        # File open/drop handling (71 lines)
│   │           ├── subtitle_service.dart       # Subtitle detection
│   │           └── video_processing_service.dart # Color correction
│   ├── ui/
│   │   ├── player/                        # Player screen components
│   │   │   ├── player_screen.dart         # Main screen (356 lines)
│   │   │   ├── controls_overlay.dart      # Auto-hide control layer
│   │   │   ├── control_bar.dart           # Bottom glass bar (429 lines)
│   │   │   ├── progress_bar.dart          # Seekbar + thumbnails
│   │   │   ├── volume_controls.dart       # Volume slider + mute
│   │   │   ├── speed_button.dart          # Playback speed selector
│   │   │   ├── keyboard_handler.dart      # 20+ key Focus handler
│   │   │   ├── video_surface.dart         # Texture renderer (41 lines)
│   │   │   ├── drop_handler.dart          # Drag-and-drop files
│   │   │   ├── center_controls.dart       # Center play/pause button
│   │   │   ├── error_banner.dart          # Error display
│   │   │   ├── auto_hide_controller.dart  # Auto-hide animation
│   │   │   ├── player_actions.dart        # Action callbacks struct (54 lines)
│   │   │   └── time_range_display.dart    # Time display (49 lines)
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
│   │   │   ├── glass_container.dart       # Glassmorphism wrapper (349 lines)
│   │   │   ├── glass_widgets.dart         # GlassChip, GlassDivider (7 lines)
│   │   │   ├── glass_chip.dart            # Glass chip component
│   │   │   ├── empty_state.dart           # Empty state screen
│   │   │   ├── osd_overlay.dart           # Floating OSD pill
│   │   │   ├── aurora_background.dart     # Aurora gradient background (362 lines)
│   │   │   ├── play_mode_utils.dart       # PlayMode -> icon/label (22 lines)
│   │   │   ├── merged_listenable.dart     # Multi-ValueNotifier merge (27 lines)
│   │   │   ├── value_listenable_builder2.dart # Dual notifier builder (26 lines)
│   │   │   ├── progress_splash_screen.dart # Startup progress UI
│   │   │   ├── splash_screen.dart         # Splash screen (45 lines)
│   │   │   ├── app_dialog.dart            # Base dialog
│   │   │   ├── context_menu_row.dart      # Context menu item (30 lines)
│   │   │   ├── edge_glow.dart             # Edge glow effect
│   │   │   ├── hover_glow.dart            # Hover glow effect
│   │   │   ├── transmitted_light.dart     # Transmitted light effect
│   │   │   ├── setting_action_row.dart    # Settings row
│   │   │   ├── setting_slider_row.dart    # Settings slider
│   │   │   ├── settings_card.dart         # Settings card
│   │   │   ├── settings_action_card.dart  # Settings action card
│   │   │   └── settings_expander_card.dart # Settings expander
│   │   ├── theme/
│   │   │   └── tokens.dart                # Design tokens (170 lines)
│   │   └── window/
│   │       └── custom_title_bar.dart      # Window title bar (146 lines)
│   └── l10n/                              # Localization
│       ├── app_localizations.dart         # Generated (1022 lines)
│       ├── app_localizations_en.dart      # English strings
│       └── app_localizations_zh.dart      # Chinese strings
├── test/                                  # 64 files, 9,209 lines
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

## File Statistics

| Directory | Files | Lines |
|-----------|-------|-------|
| `lib/kernel/bridge/` | 8 | 701 |
| `lib/kernel/engine/` | 12 | 1,515 |
| `lib/kernel/models/` | 6 | 363 |
| `lib/kernel/persistence/` | 2 | 654 |
| `lib/kernel/playlist/` | 1 | 283 |
| `lib/kernel/scanner/` | 1 | 72 |
| `lib/kernel/services/` | 8 | 363 |
| `lib/kernel/startup/` | 2 | 166 |
| `lib/kernel/utils/` | 6 | 632 |
| `lib/features/player/` | 3 | 327 |
| `lib/features/player/services/` | 6 | 615 |
| `lib/ui/player/` | 14 | 2,528 |
| `lib/ui/playlist/` | 4 | 1,160 |
| `lib/ui/shared/` | 21 | 2,709 |
| `lib/ui/dialogs/` | 2 | 624 |
| `lib/ui/theme/` | 1 | 170 |
| `lib/ui/window/` | 1 | 146 |
| `lib/l10n/` | 3 | 1,964 |
| **lib/ total** | **113** | **16,945** |
| **test/ total** | **64** | **9,209** |

## Largest Files (non-generated)

| File | Lines | Role |
|------|-------|------|
| `kernel/engine/fvp_engine.dart` | 724 | fvp/MDK engine wrapper |
| `kernel/persistence/settings_store.dart` | 436 | SharedPreferences persistence |
| `ui/player/control_bar.dart` | 429 | Bottom glass control bar |
| `ui/dialogs/settings_panel.dart` | 402 | Settings dialog |
| `ui/shared/aurora_background.dart` | 362 | Aurora gradient background |
| `ui/playlist/playlist_panel.dart` | 358 | Floating playlist window |
| `ui/player/player_screen.dart` | 356 | Main player screen |
| `ui/shared/glass_container.dart` | 349 | Glassmorphism wrapper |
| `kernel/playlist/playlist.dart` | 283 | Playlist model + navigation |
| `kernel/bridge/window_service.dart` | 257 | Window management service |

## Naming Conventions

**Files:** snake_case for all Dart files (`playback_controller.dart`). Private files prefixed with `_` (`_settings_nav_item.dart`). Test files suffixed with `_test.dart`.

**Directories:** snake_case, mirror domain (`kernel/bridge/`, `ui/player/`).

**Classes:** PascalCase (`PlaybackController`, `GlassContainer`). Private: `_PlayerFeatureState`.

**Enums:** PascalCase type, camelCase values (`WindowMode.windowed`, `PlayMode.loopAll`).

## Where to Add New Code

| New... | Location | Notes |
|--------|----------|-------|
| Playback feature | `features/player/services/` | Compose into PlaybackController |
| UI control | `ui/player/` | Add to PlayerScreen build |
| Window feature | `kernel/bridge/` | Implement WindowBridge method |
| Engine feature | `kernel/engine/` | Add to FvpEngine or create helper |
| Shared widget | `ui/shared/` | Follow GlassContainer pattern |
| Data model | `kernel/models/` | Immutable, copyWith, toJson/fromJson |
| Settings tab | `ui/dialogs/settings/` | Register in settings_panel.dart |
| Utility | `kernel/utils/` | Pure functions, no side effects |
| Test | `test/` mirroring `lib/` | Fakes in `test/helpers/` |

---

*Structure analysis: 2026-06-26*
