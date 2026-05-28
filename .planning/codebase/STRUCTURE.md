# Project Structure

**Analysis Date:** 2026-05-28

## Stats

| Metric | Value |
|--------|-------|
| Dart files | 94 |
| Total lines | 13,623 |
| Test files | 27 |
| Test lines | ~3,500 |

## Directory Tree

```
lib/
├── main.dart                          # Entry point (fvp init, window setup)
├── app.dart                           # MaterialApp shell, service wiring
├── kernel/                            # Core logic (no UI)
│   ├── engine/                        # fvp/MDK engine wrapper
│   │   ├── media_engine.dart          # Abstract engine interface
│   │   ├── fvp_engine.dart            # Concrete fvp implementation (633 lines)
│   │   ├── engine_prewarm.dart        # Startup prewarm
│   │   ├── position_poller.dart       # Timer-based position updates
│   │   └── track_manager.dart         # Audio/subtitle track management
│   ├── models/                        # Data classes
│   │   ├── playlist_item.dart
│   │   ├── media_state.dart
│   │   ├── play_mode.dart
│   │   ├── media_info.dart
│   │   ├── player_error.dart
│   │   ├── validation_error.dart
│   │   └── media_error_type.dart
│   ├── persistence/                   # Storage
│   │   ├── playlist_store.dart
│   │   └── settings_store.dart        # 446 lines, 24 save methods
│   ├── playlist/
│   │   └── playlist.dart              # Playlist model + play mode logic
│   ├── scanner/
│   │   └── folder_scanner.dart        # Directory video file scanner
│   ├── services/                      # Kernel-level services
│   │   ├── thumbnail_service.dart
│   │   ├── path_validator.dart
│   │   └── thumbnail_providers/       # Platform-specific (Win/Mac/Linux)
│   ├── startup/                       # Startup system
│   │   ├── startup_coordinator.dart
│   │   └── startup_state.dart
│   └── utils/
│       ├── time_utils.dart
│       ├── path_utils.dart
│       ├── log.dart                   # Logger instance
│       └── perf_monitor.dart
├── features/                          # Feature-specific
│   └── player/
│       ├── deferred_player_feature.dart
│       ├── player_feature.dart
│       ├── player_services.dart       # Service container
│       ├── models/
│       │   └── video_processing_state.dart
│       └── services/
│           ├── playback_controller.dart
│           ├── playback_navigator.dart
│           ├── file_operations.dart
│           ├── state_monitor.dart
│           ├── video_processing_service.dart
│           └── subtitle_service.dart
├── ui/                                # Widgets and visual components
│   ├── theme/
│   │   └── tokens.dart                # Design tokens (colors, spacing, radius)
│   ├── player/                        # Player screen
│   │   ├── player_screen.dart
│   │   ├── custom_title_bar.dart
│   │   ├── controls_overlay.dart
│   │   ├── control_bar.dart
│   │   ├── progress_bar.dart
│   │   ├── volume_controls.dart
│   │   ├── speed_button.dart
│   │   ├── keyboard_handler.dart
│   │   ├── video_surface.dart
│   │   ├── auto_hide_controller.dart
│   │   └── drop_handler.dart
│   ├── playlist/                      # Immersive floating playlist
│   │   ├── playlist_panel.dart
│   │   ├── folder_tab.dart
│   │   ├── history_tab.dart
│   │   └── thumbnail_tile.dart
│   ├── shared/                        # Reusable components
│   │   ├── glass_container.dart
│   │   ├── glass_icon_button.dart
│   │   ├── empty_state.dart
│   │   ├── play_mode_utils.dart
│   │   ├── value_listenable_builder2.dart
│   │   └── merged_listenable.dart
│   ├── widgets/
│   │   └── osd_overlay.dart
│   └── dialogs/
│       ├── settings_panel.dart        # Settings (386 lines)
│       └── media_info_dialog.dart
└── l10n/                              # Localization
    ├── app_en.arb
    ├── app_zh.arb
    └── app_localizations.dart         # Generated (974 lines)
```

## Recent Structural Changes

| Change | Before | After |
|--------|--------|-------|
| Window layer | `lib/window/` (Win32 FFI) | Deleted — uses `window_manager` package |
| Resize notifier | `lib/ui/shared/resize_notifier.dart` | Deleted |
| Features layer | `lib/kernel/services/` | `lib/features/player/services/` |
| Startup system | None | `lib/kernel/startup/` |
| Settings card | `lib/ui/dialogs/settings_card.dart` | Split into `settings/` subdirectory |

## Largest Files

| File | Lines | Concern |
|------|-------|---------|
| `app_localizations.dart` | 974 | Auto-generated |
| `fvp_engine.dart` | 633 | Single class, 12 ValueNotifiers |
| `settings_panel.dart` | 386 | Complex UI |
| `settings_store.dart` | 446 | 24 save methods |
| `aurora_background.dart` | 358 | Visual component |

## Entry Points

- **main.dart** — App entry, fvp init, window setup, startup coordinator
- **app.dart** — MaterialApp, service wiring, deferred player feature
