# Technology Stack

**Analysis Date:** 2026-05-09

## Languages

**Primary:**
- Dart 3.11.5+ — All application logic, UI, state management
- C++ — Windows runner (`windows/runner/main.cpp`, `windows/runner/flutter_window.cpp`)

**Secondary:**
- YAML — Configuration (`pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`)
- ARB (JSON) — Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- CMake — Native build system (`windows/CMakeLists.txt`, `linux/CMakeLists.txt`)

## Runtime

**Environment:**
- Flutter SDK (stable channel)
- Dart SDK ^3.11.5

**Package Manager:**
- pub (Flutter's built-in package manager)
- Lockfile: present (`pubspec.lock`)

**Target Platforms:**
- Windows (primary, x64)
- Linux (secondary, x64, GTK3)
- macOS (CI build only)

## Frameworks

**Core:**
- Flutter — UI framework (Material Design 3, dark theme)
- fvp ^0.36.2 — Media playback engine (MDK/FFmpeg wrapper)

**UI Libraries:**
- shadcn_flutter 0.0.52 — Additional UI components
- glass_kit 4.0.2 — Glass-morphism effects (BackdropFilter)
- flutter_animate 4.5.2 — Animation utilities
- flutter_zoom_drawer 3.2.0 — Drawer navigation
- smooth_page_indicator 2.0.1 — Page indicators
- velocity_x 4.3.1 — Utility extensions

**State Management:**
- ValueNotifier + ValueListenableBuilder (Flutter built-in, no external state management library)

**Testing:**
- flutter_test — Widget and unit testing
- fake_async ^1.0.0 — Async timer control in tests

**Linting:**
- flutter_lints ^6.0.0 — Dart lint rules

## Key Dependencies

**Critical (Media Playback):**
- `fvp` ^0.36.2 — MDK/FFmpeg media engine, hardware-accelerated decoding (D3D11 on Windows, OpenGL on Linux)
- `just_audio` 0.10.5 — Audio-only playback (transitive, used by fvp)

**Critical (Platform Integration):**
- `window_manager` 0.5.1 — Window control (fullscreen, always-on-top, geometry)
- `desktop_drop` 0.7.1 — Drag-and-drop file support
- `file_picker` 11.0.2 — Native file open dialogs

**Infrastructure:**
- `shared_preferences` ^2.5.5 — Key-value persistence (settings, window geometry)
- `path_provider` ^2.1.5 — Application support directory paths

**Localization:**
- `easy_localization` 3.0.8 — i18n framework
- `flutter_localizations` (SDK) — Material localization delegates

**Visual Effects:**
- `dynamic_color` ^1.8.1 — System accent color integration

**Logging:**
- `logger` ^2.7.0 — Structured logging with PrettyPrinter

## Configuration

**Environment:**
- No `.env` files — all config is compile-time or runtime preferences
- SharedPreferences for user settings (volume, window geometry, play mode, video processing)
- No external API keys or secrets required

**Build:**
- `pubspec.yaml` — Dependencies and Flutter config
- `analysis_options.yaml` — Lint rules (uses `package:flutter_lints/flutter.yaml`)
- `l10n.yaml` — Localization generation config (ARB-based, en/zh)

**Platform-Specific:**
- Windows: Impeller rendering engine enabled (`--enable-impeller` flag in `windows/runner/main.cpp:26`)
- Windows: COM initialized for plugin support (`CoInitializeEx` in `windows/runner/main.cpp:18`)
- Linux: GTK3 native window, OpenGL rendering via fvp

## Platform Requirements

**Development:**
- Flutter SDK (stable channel)
- Dart SDK 3.11.5+
- Windows: Visual Studio with C++ desktop workload, Windows 10 SDK
- Linux: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev

**Production:**
- Windows: Win32 native window (1280x720 default), D3D11 hardware acceleration
- Linux: GTK3 window, OpenGL rendering
- macOS: Cocoa window (CI-built DMG)

## Design System

**Theme:**
- Single dark theme: "Midnight" (compile-time const)
- Tokens: `lib/kernel/ui/theme/tokens.dart` (50 tokens — colors, spacing, typography, animation)
- ThemeData bridge: `lib/kernel/ui/theme/app_theme.dart`
- Glass-morphism: `BackdropFilter` + `bgGlass` + `borderHighlight`
- Dynamic color: system accent via `dynamic_color` package

**Typography:**
- Title: 18.0 (w600)
- Body: 14.0
- Caption: 12.0
- Overline: 10.0

**Spacing Scale:**
- Xs: 4, Sm: 8, Md: 12, Lg: 16, Xl: 24

**Border Radius:**
- Sm: 6, Md: 10, Button: 8

## Architecture Pattern

**Overall:** Kernel architecture with mixin composition

**Key Layers:**
- `lib/kernel/engine/` — Media engine abstraction (MediaEngine interface + FvpEngine implementation)
- `lib/kernel/services/` — Business logic (PlaybackController with FileOperations/PlaybackNavigator/StateMonitor mixins)
- `lib/kernel/persistence/` — Settings and playlist storage (SharedPreferences + JSON files)
- `lib/kernel/models/` — Data classes (PlaylistItem, MediaState, MediaInfo, PlayMode)
- `lib/kernel/ui/` — Theme tokens and design system
- `lib/kernel/platform/` — Platform service abstraction (Windows/Linux)

**State Management:**
- ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- FvpEngine exposes 13 ValueNotifiers as reactive state
- Widgets rebuild via ValueListenableBuilder wrappers

---

*Stack analysis: 2026-05-09*
