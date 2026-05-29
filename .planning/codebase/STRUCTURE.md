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

## Window Management Architecture

### Layer Stack

```
┌──────────────────────────────────────────────────────┐
│  Dart UI (custom_title_bar.dart, app.dart)           │
│  ValueListenableBuilder on isMaximized/isFullscreen  │
├──────────────────────────────────────────────────────┤
│  WindowService (window_service.dart)                 │
│  Win32 FFI + DWM API + window_manager delegates     │
├──────────────────────────────────────────────────────┤
│  window_manager plugin (C++)                         │
│  WM_NCCALCSIZE / WM_NCHITTEST / WM_SIZE handling    │
│  MethodChannel: maximize, restore, setFullScreen     │
├──────────────────────────────────────────────────────┤
│  C++ Runner (flutter_window.cpp, win32_window.cpp)   │
│  Message routing: plugin first → runner fallback     │
│  ApplyRoundedCorners on WM_SIZE                      │
├──────────────────────────────────────────────────────┤
│  Win32 / DWM                                         │
│  ShowWindow, SetWindowPos, DwmExtendFrameIntoClient  │
│  DwmSetWindowAttribute (transitions, corners, dark)  │
└──────────────────────────────────────────────────────┘
```

### Message Processing Chain

```
Win32 message → WndProc → FlutterWindow::MessageHandler
  ├─ flutter_controller_->HandleTopLevelWindowProc()
  │   └─ window_manager_plugin::HandleWindowProc()
  │       ├─ WM_NCCALCSIZE → adjustNCCALCSIZE (border expansion)
  │       ├─ WM_NCHITTEST → hit test zones (resize, caption, buttons)
  │       └─ WM_SIZE → emit "maximize"/"unmaximize" events
  └─ Win32Window::MessageHandler()
      ├─ WM_SIZE → MoveWindow(child) + ApplyRoundedCorners
      ├─ WM_ERASEBKGND → return 1 (skip black flash)
      └─ WM_DPICHANGED → reposition
```

### Window State Machine

| State | WS_STYLE | DWM Margins | Resize | Transitions |
|-------|----------|-------------|--------|-------------|
| Normal | `~WS_CAPTION` (keeps WS_THICKFRAME) | `{0,0,1,0}` | 6px edges | DWM enabled |
| Maximized | No change | No change | Disabled | **DWM disabled** |
| Fullscreen | `WS_POPUP` only | `{-1,-1,-1,-1}` | Disabled | DWM disabled |

### Key FFI Calls

| Win32 API | Dart Wrapper | Purpose |
|-----------|-------------|---------|
| `GetWindowLongPtrW` | `_getWindowLongPtr` | Read window style |
| `SetWindowLongPtrW` | `_setWindowLongPtr` | Set window style |
| `SetWindowPos` | `_setWindowPos` | Apply frame changes (SWP_FRAMECHANGED) |
| `DwmExtendFrameIntoClientArea` | `_dwmExtendFrameIntoClientArea` | Shadow preservation (top=1px) |
| `DwmSetWindowAttribute` | `_dwmSetWindowAttribute` | Disable transitions (DWMWA=3) |
| `MonitorFromWindow` | `_monitorFromWindow` | Get monitor for fullscreen |
| `GetMonitorInfoW` | `_getMonitorInfo` | Monitor bounds |
| `GetWindowRect` | `_getWindowRect` | Save/restore window frame |

### Startup Sequence

```
main.dart:
  1. windowManager.ensureInitialized()
  2. WindowOptions(titleBarStyle: hidden, backgroundColor: transparent)
  3. waitUntilReadyToShow callback:
     a. WindowService.removeBorderImmediate()  ← FFI: ~WS_CAPTION + DWM margins
     b. windowManager.show()
     c. windowManager.focus()
  4. WindowService.init() → windowManager.addListener(this)
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

- **main.dart** — App entry, fvp init, window setup (removeBorderImmediate before show), startup coordinator
- **app.dart** — MaterialApp, service wiring, DragToResizeArea wrapper (disabled when maximized/fullscreen), deferred player feature
