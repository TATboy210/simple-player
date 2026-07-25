# Simple Player Flutter — API Documentation

Flutter desktop media player powered by fvp (MDK/FFmpeg).

## Architecture Overview

```
lib/
├── kernel/          # Core logic (no UI)
│   ├── engine/      # fvp/MDK engine wrapper
│   ├── bridge/      # Win32 window control
│   ├── models/      # Data classes
│   ├── persistence/ # Storage (playlist, settings)
│   ├── playlist/    # Playlist model + play mode
│   ├── scanner/     # Directory video file scanner
│   ├── services/    # Playback orchestration
│   ├── adapter/     # Kernel migration adapter
│   ├── diagnostics/ # Logging, metrics, memory
│   └── utils/       # Path, time, perf utilities
└── ui/              # Flutter widgets
    ├── player/      # Player screen components
    ├── playlist/    # Immersive floating playlist
    ├── shared/      # Reusable components
    ├── dialogs/     # Settings, media info
    ├── theme/       # Design tokens
    └── window/      # Custom title bar
```

## Module Index

### Kernel Layer

| Module | File | Description |
|--------|------|-------------|
| [Engine](engine.md) | `kernel/engine/` | MediaEngine interface, FvpEngine implementation, playback state machine |
| [Models](models.md) | `kernel/models/` | PlaylistItem, AppSettings, PlayMode, PlayerError, MediaInfo |
| [Services](services.md) | `kernel/services/` | PlaybackController facade, navigator, file operations |
| [Persistence](persistence.md) | `kernel/persistence/` | PlaylistStore (JSON), SettingsStore (shared_preferences) |
| [Bridge](bridge.md) | `kernel/bridge/` | WindowBridge abstract interface, WindowMode enum |
| [Scanner](scanner.md) | `kernel/scanner/` | FolderScanner for directory video file discovery |
| [Utils](utils.md) | `kernel/utils/` | PathUtils, PathValidator, formatMs, PerfMonitor |
| [Diagnostics](diagnostics.md) | `kernel/diagnostics/` | DiagnosticsBundle, KernelLogger, MemoryMonitor |
| [Adapter](adapter.md) | `kernel/adapter/` | KernelAdapter (Strangler Fig migration seam) |

### UI Layer

| Module | File | Description |
|--------|------|-------------|
| [Player Widgets](ui-player.md) | `ui/player/` | PlayerScreen, ControlBar, ProgressBar, VideoSurface |
| [Shared Widgets](ui-shared.md) | `ui/shared/` | GlassContainer, GlassButton, OSD, EmptyState |
| [Playlist Widgets](ui-playlist.md) | `ui/playlist/` | PlaylistPanel, FolderTab, HistoryTab |
| [Theme](ui-theme.md) | `ui/theme/` | Design tokens (colors, spacing, typography) |

## State Management

- **ValueNotifier + ValueListenableBuilder** (no Provider/Riverpod/Bloc)
- `MediaEngine` exposes ValueNotifiers for playback state
- `PlaybackController` orchestrates playlist + engine state
- Widgets rebuild via `ValueListenableBuilder` wrappers

## Key Design Patterns

1. **Facade** — `PlaybackController` unifies 4 sub-modules behind a single API
2. **ISP (Interface Segregation)** — `MediaEngine` composes 7 focused interfaces
3. **ValueNotifier reactive UI** — Engine state changes propagate without setState
4. **Glassmorphism** — `GlassContainer` + `BackdropFilter` + `bgGlass` + `borderHighlight`
5. **Strangler Fig** — `KernelAdapter` enables incremental engine migration
6. **CQS** — `Playlist.peekNext()` returns index without modifying state
7. **Factory Constructor** — `FvpEngine` eliminates `late` initialization risks

## Quick Start

```dart
// 1. Create engine
final engine = FvpEngine();

// 2. Create playlist and controller
final playlist = Playlist();
final controller = PlaybackController(
  engine: engine,
  playlist: playlist,
  onNeedRebuild: () => setState(() {}),
);

// 3. Initialize
await controller.init();

// 4. Open and play
await controller.openAndPlay('C:/Videos/movie.mp4');

// 5. Listen to state changes
engine.state.addListener(() {
  print('State: ${engine.state.value}');
});
engine.position.addListener(() {
  print('Position: ${formatMs(engine.position.value)}');
});

// 6. Cleanup
controller.dispose();
engine.dispose();
```
