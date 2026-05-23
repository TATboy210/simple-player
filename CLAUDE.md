# Simple Player Flutter

Flutter desktop media player powered by fvp (MDK/FFmpeg).

## Build & Run

```bash
flutter pub get
flutter run -d windows
flutter analyze
flutter test
```

## Architecture

```
lib/
├── main.dart                    # Entry point (fvp init, window setup)
├── app.dart                     # MaterialApp shell, service wiring
├── kernel/                      # Core logic (no UI)
│   ├── engine/                  # fvp/MDK engine wrapper
│   │   ├── media_engine.dart       # Abstract engine interface
│   │   ├── fvp_engine.dart         # Concrete fvp implementation
│   │   ├── position_poller.dart    # Timer-based position updates
│   │   └── track_manager.dart      # Audio/subtitle track management
│   ├── bridge/
│   │   └── window_bridge.dart      # Win32 window control (MethodChannel)
│   ├── models/                  # Data classes
│   │   ├── playlist_item.dart      # PlaylistItem (path, timestamp, position)
│   │   ├── media_state.dart        # Playback state enum
│   │   ├── play_mode.dart          # LoopAll/LoopSingle/Shuffle
│   │   └── media_info.dart         # Codec/resolution metadata
│   ├── persistence/             # Storage
│   │   ├── playlist_store.dart     # Playlist save/load
│   │   └── settings_store.dart     # Preferences (locale, volume, etc.)
│   ├── playlist/
│   │   └── playlist.dart           # Playlist model + play mode logic
│   ├── scanner/
│   │   └── folder_scanner.dart     # Directory video file scanner
│   ├── services/
│   │   ├── playback_controller.dart   # Orchestrator (open/next/prev/seek)
│   │   ├── playback_navigator.dart    # Track advancement logic
│   │   ├── thumbnail_service.dart     # Win32 COM thumbnail extraction
│   │   ├── video_processing_service.dart # Color correction, rotation
│   │   └── file_operations.dart       # File open/drop handling
│   └── utils/
│       ├── time_utils.dart          # formatMs()
│       └── path_utils.dart          # Path validation
├── ui/
│   ├── theme/
│   │   └── tokens.dart              # Design tokens (colors, spacing, radius)
│   ├── player/                  # Player screen components
│   │   ├── player_screen.dart      # Main screen (Stack compositing)
│   │   ├── custom_title_bar.dart   # Window title bar (glass, drag, controls)
│   │   ├── controls_overlay.dart   # Auto-hide control layer
│   │   ├── control_bar.dart        # Bottom glass bar
│   │   ├── progress_bar.dart       # Seekbar + thumbnails
│   │   ├── volume_controls.dart    # Volume slider + mute
│   │   ├── speed_button.dart       # Playback speed selector
│   │   ├── keyboard_handler.dart   # 20+ key Focus handler
│   │   ├── video_surface.dart      # Texture renderer
│   │   └── drop_handler.dart       # Drag-and-drop files
│   ├── playlist/                # Immersive floating playlist
│   │   ├── playlist_panel.dart     # Floating window (glass, animation)
│   │   ├── folder_tab.dart         # Folder-grouped thumbnails
│   │   ├── history_tab.dart        # Timestamp-sorted history
│   │   └── thumbnail_tile.dart     # 16:9 thumbnail card
│   ├── shared/                  # Reusable components
│   │   ├── glass_container.dart    # Glassmorphism wrapper
│   │   ├── empty_state.dart        # Empty state screen
│   │   └── play_mode_utils.dart    # PlayMode → icon/label
│   ├── widgets/
│   │   └── osd_overlay.dart        # Floating OSD pill
│   └── dialogs/
│       ├── settings_dialog.dart    # Settings (EQ, video, tracks)
│       └── media_info_dialog.dart  # File properties dialog
└── l10n/                        # Localization (ARB + generated)
```

## State Management

- **ValueNotifier + ValueListenableBuilder** (no Provider/Riverpod/Bloc)
- `MediaEngine` exposes ValueNotifiers for playback state (position, volume, mute, etc.)
- `PlaybackController` orchestrates playlist + engine state
- Widgets rebuild via `ValueListenableBuilder` wrappers

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| Left/Right | Seek ±5s |
| Up/Down | Volume ±5% |
| F | Toggle fullscreen |
| M | Toggle mute |
| N | Previous track |
| P | Next track |
| O | Open file |
| A | Cycle aspect ratio |
| S | Toggle subtitle |
| [ / ] | Subtitle delay ±500ms |
| F1 / ? | Show shortcuts help |
| ESC | Exit fullscreen / Close playlist |
| Media keys | Play/Pause, Next, Previous |

## Design System

- Single theme: Midnight (compile-time const)
- Design tokens in `kernel/ui/theme/tokens.dart` — `Tokens.*` static constants
- Glass-morphism: `BackdropFilter` + `bgGlass` + `borderHighlight`
- All colors/fonts/spacing via `Tokens.*` (no hardcoded values)

## Coding Conventions

- Use `debugPrint()` not `print()` for logging
- Use `Tokens.*` for all visual values
- Errors: catch with `debugPrint` + graceful fallback (never silent `catch (_) {}`)
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Chinese comments are OK (existing codebase convention)
