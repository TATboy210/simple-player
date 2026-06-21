# v2 Project Structure

**Analysis Date:** 2026-06-19
**Total:** 27 files, ~2,900 lines (Dart 1,562 + C++ 1,179 + YAML 52 + CMake 307)

## Directory Layout

```
v2/
├── lib/                          # Dart source — 17 files, 1,388 lines
│   ├── main.dart                 # Entry point (34 lines)
│   ├── app.dart                  # MaterialApp shell (20 lines)
│   ├── core/                     # Types, events, state, models
│   │   ├── events/
│   │   │   ├── player_events.dart    # Sealed PlayerEvent/PlayerCommand (119 lines)
│   │   │   └── window_events.dart    # Sealed WindowEvent/WindowCommand (65 lines)
│   │   ├── state/
│   │   │   └── playback_state.dart   # PlaybackState enum (29 lines)
│   │   ├── models/
│   │   │   └── playlist_item.dart    # PlaylistItem data class (28 lines)
│   │   └── types/
│   │       └── play_mode.dart        # PlayMode enum (14 lines)
│   ├── infra/                    # Platform adapters
│   │   ├── event_bus/
│   │   │   └── event_bus.dart        # Typed EventBus (25 lines)
│   │   ├── mpv/
│   │   │   ├── mpv_adapter.dart      # High-level mpv wrapper (221 lines)
│   │   │   └── mpv_bindings.dart     # Raw FFI bindings (136 lines)
│   │   ├── window/
│   │   │   └── window_service.dart   # Window management (188 lines)
│   │   └── logger/
│   │       └── app_logger.dart       # Rotating file logger (144 lines)
│   ├── feature/                  # Command handlers
│   │   ├── player/
│   │   │   └── player_feature.dart   # PlayerCommand → MpvAdapter (46 lines)
│   │   └── window/
│   │       └── window_feature.dart   # WindowCommand → WindowService (52 lines)
│   └── ui/                       # Widgets
│       ├── player_screen.dart        # Main player screen (103 lines)
│       ├── widgets/
│       │   └── title_bar.dart        # Custom title bar (170 lines)
│       └── theme/
│           └── tokens.dart           # Design tokens (28 lines)
├── test/                         # Tests — 4 files, 174 lines
│   ├── core/
│   │   └── player_events_test.dart   # PlayerEvent tests (48 lines)
│   ├── feature/
│   │   └── player_command_test.dart  # PlayerCommand tests (48 lines)
│   ├── infra/
│   │   └── event_bus_test.dart       # EventBus tests (48 lines)
│   └── widget_test.dart             # Placeholder (30 lines)
├── windows/                      # C++ native layer
│   ├── runner/                   # Flutter Windows runner — 8 files, 641 lines
│   │   ├── main.cpp                  # Win32 entry point (43 lines)
│   │   ├── flutter_window.cpp        # Flutter view host (71 lines)
│   │   ├── flutter_window.h          # Flutter window header (33 lines)
│   │   ├── win32_window.cpp          # Win32 window class (288 lines)
│   │   ├── win32_window.h            # Win32 window header (102 lines)
│   │   ├── utils.cpp                 # Utility functions (69 lines)
│   │   ├── utils.h                   # Utils header (19 lines)
│   │   └── resource.h                # Resource definitions (16 lines)
│   ├── mpv_render_plugin/        # mpv render plugin — 3 files, 580 lines
│   │   ├── mpv_render_plugin.cpp     # Render implementation (446 lines)
│   │   ├── mpv_render_plugin.h       # Plugin header (96 lines)
│   │   └── CMakeLists.txt            # Plugin build config (38 lines)
│   ├── libmpv/                   # mpv C headers
│   │   ├── client.h                  # mpv client API
│   │   ├── render.h                  # mpv render API
│   │   └── render_gl.h               # OpenGL render API
│   ├── CMakeLists.txt                # Root build (111 lines)
│   └── flutter/
│       └── CMakeLists.txt            # Flutter framework build (109 lines)
├── pubspec.yaml                  # Package config (24 lines)
├── analysis_options.yaml         # Lint rules (28 lines)
└── README.md                     # Project readme
```

## Module Responsibilities

### Core Layer (5 files, 255 lines)
- Pure data types, zero dependencies
- Sealed class hierarchies for commands and events
- State enums and immutable data models

### Infrastructure Layer (5 files, 714 lines)
- Platform adapters wrapping native APIs
- EventBus: typed pub-sub using `StreamController<Object>.broadcast()`
- MpvAdapter: FFI bridge with 16ms event polling
- WindowService: window_manager + flutter_fullscreen wrapper
- AppLogger: rotating file output (2MB, 5 archives)

### Feature Layer (2 files, 98 lines)
- Command handlers subscribing to EventBus
- Exhaustive sealed class switch matching
- Error handling fires ErrorOccurred back to bus

### UI Layer (3 files, 301 lines)
- StreamSubscription for PlayerEvent → setState
- StreamBuilder for WindowEvent → reactive rebuild
- Design tokens via `Tokens.*` static constants

### C++ Layer (11 files, 1,179 lines)
- Flutter Windows runner (standard, 641 lines)
- mpv render plugin (D3D11 + ANGLE, 446 lines) — **largest file in project**
- libmpv C headers for FFI binding generation

## Import Rules

| From → To | Allowed | Example |
|-----------|---------|---------|
| Core → Core | ✅ | `player_events.dart` imports `playback_state.dart` |
| Infra → Core | ✅ | `mpv_adapter.dart` imports `player_events.dart` |
| Feature → Infra | ✅ | `player_feature.dart` imports `mpv_adapter.dart` |
| Feature → Core | ✅ | `player_feature.dart` imports `player_events.dart` |
| UI → Core | ✅ | `player_screen.dart` imports `playback_state.dart` |
| UI → Infra | ✅ (EventBus only) | `player_screen.dart` imports `event_bus.dart` |
| UI → Feature | ❌ | UI never directly references features |
| Core → Infra | ❌ | Core has zero dependencies |

---

*Structure analysis: 2026-06-19 — Understand-Anything project-scanner*
