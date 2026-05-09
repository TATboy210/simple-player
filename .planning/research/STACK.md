# Technology Stack

**Project:** Simple Player Flutter
**Researched:** 2026-05-09

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flutter | 3.44.0+ (beta) | App framework | Desktop beta channel required for Windows stability fixes |
| Dart | 3.12.0+ | Language | Matches Flutter 3.44 SDK constraint |
| fvp | 0.36.2 | Media engine | Already integrated. MDK/FFmpeg backend, D3D11 direct rendering on Windows, lowest latency. Pre-1.0 so pin exact version |

### Window Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| window_manager | 0.5.1 | Window shell | Already integrated. Proven in reference project (D:\player_flutter). Singleton pattern, WindowListener events, frameless support. Pin exact — 0.5.x API is stable but 0.6+ may break |
| Native C++ runner (WM_SIZING) | custom | Aspect ratio lock | MethodChannel to WM_SIZING in win32_window.cpp. Already implemented in this project's windows/runner/. More reliable than Flutter-level constraints for frameless windows |
| Native C++ runner (forceRedraw) | custom | Frameless first-frame fix | MethodChannel to FlutterViewController::ForceRedraw(). Already implemented. Prevents black bar on frameless show() |

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| ValueNotifier + ValueListenableBuilder | built-in | Reactive state | Already established in kernel (13 ValueNotifiers in FvpEngine). Lightweight, zero dependencies, sufficient for single-window desktop app. No Provider/Riverpod/BLoC needed |

### Persistence

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| shared_preferences | 2.5.5 | Settings + window geometry | Already integrated. Key-value store, prewarmed in main() to avoid repeated getInstance() I/O |

### File Operations

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| file_picker | 11.0.2 | Open file dialog | Already integrated. Cross-platform file picker, supports FileType.video filter + multi-select |
| desktop_drop | 0.7.1 | Drag-and-drop | Already integrated. Desktop-native drag-and-drop support |

### UI / Theming

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Material 3 (built-in) | Flutter SDK | Base widgets | Standard Flutter widgets. No external UI library needed |
| dynamic_color | 1.8.1 | Material You accent | Already integrated. Windows 10/11 accent color for subtle theming |
| BackdropFilter + custom Tokens | custom | Glass-morphism | Already designed (50 tokens in tokens.dart). No glass_kit needed — manual BackdropFilter gives more control |

### Localization

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_localizations + ARB | Flutter SDK | i18n | Already implemented (EN/ZH). Standard Flutter approach, codegen via `flutter gen-l10n` |

### Logging

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| logger | 2.7.0 | Structured logging | Already integrated. Better than debugPrint for development; wraps debugPrint in production |

### Dev Dependencies

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_test | SDK | Unit + widget tests | Built-in test framework |
| flutter_lints | 6.0.0 | Lint rules | Standard Dart linting |
| fake_async | 1.0.0 | Timer testing | Control time in debounce/timer tests |

## Dependencies to REMOVE

These 7 packages are in pubspec.yaml but unused in the codebase. Remove them to reduce bundle size and dependency surface.

| Package | Version | Reason to Remove |
|---------|---------|-----------------|
| easy_localization | 3.0.8 | Not imported anywhere. Project uses flutter_localizations + ARB |
| shadcn_flutter | 0.0.52 | Not imported anywhere. Adds significant weight (animation_kit, auto_size_text_pk, country_flags transitive deps) |
| velocity_x | 4.3.1 | Not imported anywhere |
| smooth_page_indicator | 2.0.1 | Not imported anywhere |
| glass_kit | 4.0.2 | Not imported anywhere. Custom glass-morphism via BackdropFilter already designed |
| flutter_zoom_drawer | 3.2.0 | Not imported anywhere |
| flutter_animate | 4.5.2 | Not imported anywhere |
| just_audio | 0.10.5 | Not imported anywhere. fvp handles all media playback |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Media engine | fvp 0.36.2 | media_kit (libmpv) | fvp already integrated, D3D11 direct rendering on Windows is lower latency than libmpv's OpenGL path. media_kit has more features (streaming, subtitles) but adds libmpv binary dependency. fvp sufficient for local file playback |
| Media engine | fvp 0.36.2 | video_player (official) | Official plugin has poor desktop support, no hardware acceleration on Windows, limited codec support |
| Window management | window_manager 0.5.1 | bitsdojo_window | window_manager already integrated and proven in reference project. bitsdojo_window has similar API but less active maintenance |
| Window management | window_manager 0.5.1 | Native Win32 only | Would require reimplementing cross-platform abstractions. window_manager handles macOS/Linux too for future |
| State management | ValueNotifier | Riverpod | Overkill for single-window desktop app. 13 ValueNotifiers already established. Riverpod adds complexity (code generation, ProviderScope, ref.watch) without proportional benefit |
| State management | ValueNotifier | BLoC | Same as Riverpod — event/stream pattern adds ceremony. ValueListenableBuilder is sufficient for this scope |
| UI library | Material 3 (built-in) | shadcn_flutter | Adds 50+ transitive dependencies. Material 3 widgets + custom Tokens already cover all needs |
| UI library | Material 3 (built-in) | macos_ui / fluent_ui | Platform-specific UI kits add complexity. Dark theme media player looks the same on all platforms |

## Rendering Pipeline

### Texture Widget (recommended, already implemented)

fvp exposes a `textureId` via `_player.textureId` (ValueNotifier). The Texture widget renders video frames directly from GPU memory via D3D11 on Windows. This is the lowest-latency path.

```dart
// From VideoSurface in reference project
FittedBox(
  fit: BoxFit.contain,
  child: SizedBox(
    width: safeRatio >= 1 ? safeRatio * 1000 : 1000,
    height: safeRatio >= 1 ? 1000 : 1000 / safeRatio,
    child: Texture(textureId: id),
  ),
)
```

### Why NOT PlatformView

PlatformView (AndroidView/UiKitView) is used for embedding native views (webview, maps). For video, Texture widget is:
- Zero-copy on Windows (D3D11 texture shared with Flutter compositor)
- No platform view composition overhead
- No hit-testing interference with Flutter gesture system

## Architecture Summary

```
┌─────────────────────────────────────────────┐
│  UI Layer (to build)                        │
│  PlayerScreen, ControlsOverlay, TitleBar    │
│  ValueListenableBuilder on 13 Notifiers     │
├─────────────────────────────────────────────┤
│  Window Shell (to build)                    │
│  WindowManagerService (window_manager)      │
│  AspectRatioService (MethodChannel WM_SIZING)│
├─────────────────────────────────────────────┤
│  Kernel Layer (existing)                    │
│  FvpEngine, Playlist, PlaybackController    │
│  SettingsStore, PlaylistStore               │
├─────────────────────────────────────────────┤
│  Native Layer (existing)                    │
│  C++ runner: forceRedraw, WM_SIZING         │
│  fvp/MDK: D3D11 rendering, FFmpeg decode    │
└─────────────────────────────────────────────┘
```

## Installation

```bash
# Core dependencies (keep)
flutter pub add fvp window_manager shared_preferences file_picker desktop_drop logger dynamic_color path_provider

# Remove unused
flutter pub remove easy_localization shadcn_flutter velocity_x smooth_page_indicator glass_kit flutter_zoom_drawer flutter_animate just_audio
```

## Version Pinning Strategy

| Package | Constraint | Rationale |
|---------|-----------|-----------|
| fvp | `0.36.2` (exact) | Pre-1.0, breaking changes likely. Pin until stable release |
| window_manager | `0.5.1` (exact) | Reference project proven. 0.6+ may change frameless API |
| desktop_drop | `0.7.1` (exact) | Small package, pin to avoid surprises |
| shared_preferences | `^2.5.5` (caret) | Stable, well-maintained, safe to auto-update |
| file_picker | `^11.0.2` (caret) | Stable API, cross-platform |
| logger | `^2.7.0` (caret) | Stable, simple API |
| dynamic_color | `^1.8.1` (caret) | Stable, thin wrapper |

## Sources

- Existing codebase: pubspec.yaml, pubspec.lock, lib/kernel/engine/fvp_engine.dart
- Reference project: D:\player_flutter (WindowManagerService, AspectRatioService, VideoSurface, C++ runner)
- Flutter desktop docs: https://docs.flutter.dev/platform-integration/windows
- window_manager: https://pub.dev/packages/window_manager
- fvp: https://pub.dev/packages/fvp

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| fvp as engine | HIGH | Already integrated, proven in reference project |
| window_manager | HIGH | Already integrated, 500+ lines of production code in reference |
| ValueNotifier pattern | HIGH | Already established in kernel, 13 notifiers working |
| Texture rendering | HIGH | Proven in reference project VideoSurface |
| C++ runner channels | HIGH | Already implemented in this project's windows/runner/ |
| Package version numbers | MEDIUM | Based on pubspec.lock resolved versions; latest available may differ |
| Unused package removal | HIGH | Grep confirms zero imports of removed packages |
