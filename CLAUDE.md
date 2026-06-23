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
│   │   ├── thumbnail_service.dart     # Platform-aware thumbnail facade (LRU cache)
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

## Dart/Flutter Rules (from GitHub best practices)

> Synthesized from GitHubGenUI, flex_color_scheme, webf CLAUDE.md files.

### Type Safety (strict mode enabled in analysis_options.yaml)

- **Avoid `!` (bang operator)** — prefer `?.`, `??`, `if (x != null)`, or Dart 3 pattern matching. Reserve `!` only where a null value is a programming error and crashing is correct
- **Avoid `late`** — prefer nullable types or constructor initialization
- **Avoid `as` casts** — use pattern matching (`switch`, `if (x is Type)`) for type-safe downcasts
- **Prefer `final` for all local variables** — `const` for compile-time constants
- **Use `required` for constructor params** that must always be provided

```dart
// BAD
final name = user!.name;
final item = data as Map<String, dynamic>;

// GOOD
final name = user?.name ?? 'Unknown';
final (:name, :age) = user;  // Dart 3 destructuring
```

### Function & File Size

- **Functions < 50 lines** (20 for pure logic, 50 for UI builders)
- **Files < 500 lines** — extract modules when approaching limit
- **Switch expressions over if/else chains** (except in declarative widget contexts)

### Error Handling

- **Specify exception types** in `on` clauses — never bare `catch (e)`
- **Never catch `Error` subtypes** — they indicate programming bugs
- Use sealed classes for recoverable errors:

```dart
sealed class Result<T> {
  const Result();
}
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}
final class Err<T> extends Result<T> {
  const Err(this.error);
  final Object error;
}
```

### FFI / C++ Bridge Patterns (from webf)

- **Always free FFI memory in `finally` blocks** — `malloc.free()` for `toNativeUtf8()`
- **Copy strings that cross thread boundaries** — `const char*` from Dart may be freed after call
- **Use persistent handles for async Dart callbacks** — regular handles become invalid across threads
- **Document memory ownership** — who allocates, who frees
- **MethodChannel naming**: `com.simple_player/window` for Win32 bridge

### Testing

- **Widget tests double as integration tests** — test full app flows, not isolated components
- **Never skip tests, never remove assertions** — failing tests are OK, silent failures are not
- **Fakes over mocks** for complex dependencies (hand-written test doubles)
- **Unique controller names** in tests: `'test-${name}-${DateTime.now().millisecondsSinceEpoch}'`

### Design System Enforcement

- **All visual values via `Tokens.*`** — no hardcoded colors, fonts, or spacing
- **Don't fight the design system** — use Flutter's theming properly
- **Glass-morphism pattern**: `BackdropFilter` + `bgGlass` + `borderHighlight` (see `GlassContainer`)

### Async Best Practices

- Always `await` Futures or explicitly call `unawaited()` for fire-and-forget
- Never mark a function `async` if it never `await`s anything
- Check `context.mounted` before using `BuildContext` after any `await`
- Prefer `Future.wait` for concurrent operations
