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
├── main.dart              # Entry point (fvp init, window setup)
├── app.dart               # MaterialApp shell
├── core/                  # Business logic (no UI)
│   ├── player_adapter.dart   # fvp wrapper, 13 ValueNotifiers
│   ├── player_state.dart     # 9-state enum
│   └── playlist.dart         # Playlist model, 4 play modes
├── models/
│   └── playlist_item.dart    # Data class (path + name)
├── persistence/           # JSON/shared_preferences storage
│   ├── history_storage.dart     # MRU history, max 50
│   ├── settings_storage.dart    # Window/volume/mute prefs
│   └── playlist_storage.dart    # Last playlist save
├── ui/
│   ├── screens/
│   │   └── player_screen.dart   # Main screen (Stack compositing)
│   ├── shortcuts/
│   │   └── keyboard_handler.dart # 14-key Focus handler
│   ├── theme/              # Design tokens (compile-time const)
│   │   ├── theme_config.dart      # 50 tokens (immutable)
│   │   ├── design_tokens.dart     # Static facade
│   │   ├── app_theme.dart         # ThemeData bridge
│   │   └── ambient_background.dart # Star river animation
│   └── widgets/            # Reusable UI components
│       ├── control_bar.dart       # Bottom glass bar
│       ├── progress_bar.dart      # 3-layer seekbar + thumbnails
│       ├── playlist_panel.dart    # Right side panel
│       ├── empty_state_buttons.dart
│       ├── equalizer_dialog.dart  # 10-band EQ
│       ├── osd_overlay.dart       # Floating pill
│       ├── ab_loop_button.dart    # 3-state AB loop
│       ├── buffering_indicator.dart
│       ├── audio_track_selector.dart
│       ├── subtitle_overlay.dart
│       ├── video_view.dart        # Texture renderer
│       └── settings_dialog.dart
└── utils/
    └── time_utils.dart     # formatMs() shared utility
```

## State Management

- **ValueNotifier + ValueListenableBuilder** (no Provider/Riverpod/Bloc)
- `PlayerAdapter` exposes 13 ValueNotifiers as reactive state
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
| A | Set AB loop A point |
| B | Set AB loop B point |
| S | Toggle subtitle |
| ESC | Exit fullscreen |

## Design System

- Single theme: Midnight (compile-time const)
- 50 tokens in `ThemeConfig`, exposed via `DesignTokens` static facade
- Glass-morphism: `BackdropFilter` + `bgGlass` + `borderHighlight`
- All colors/fonts/spacing via `DesignTokens.*` (no hardcoded values)

## Coding Conventions

- Use `debugPrint()` not `print()` for logging
- Use `DesignTokens.*` for all visual values
- Errors: catch with `debugPrint` + graceful fallback (never silent `catch (_) {}`)
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Chinese comments are OK (existing codebase convention)
