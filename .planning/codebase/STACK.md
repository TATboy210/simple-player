# Technology Stack

**Analysis Date:** 2026-05-07

## Languages

**Primary:**
- Dart 3.12.0 - Application logic, UI, state management
- C++ - Windows native runner (`windows/runner/`)

**Secondary:**
- CMake - Windows build system (`windows/CMakeLists.txt`)

## Runtime

**Environment:**
- Flutter 3.44.0-0.2.pre (beta channel)
- Dart SDK ^3.11.5 (constraint in `pubspec.yaml`)

**Package Manager:**
- pub (Dart built-in)
- Lockfile: present (`pubspec.lock`)

## Frameworks

**Core:**
- Flutter SDK - UI framework, Material Design widgets
- fvp 0.36.2 - Media playback engine (MDK/FFmpeg wrapper, D3D11 rendering on Windows)

**Testing:**
- flutter_test (SDK) - Unit and widget testing
- flutter_lints 6.0.0 - Lint rules (`analysis_options.yaml`)

**Build/Dev:**
- CMake 3.14+ - Windows native build (`windows/CMakeLists.txt`)
- dart format - Code formatting (80 char line length)

## Key Dependencies

**Critical:**
- `fvp` 0.36.2 - Core media playback; wraps MDK (FFmpeg-based), provides texture rendering, codec support, subtitle/audio track management
- `window_manager` 0.5.1 - Frameless window, fullscreen, always-on-top, drag-to-resize on desktop
- `shared_preferences` 2.5.5 - Key-value persistence for settings (volume, window geometry, play mode, video effects)

**Infrastructure:**
- `path_provider` 2.1.5 - Application support directory for playlist JSON storage
- `file_picker` 11.0.2 - Native file open dialog with extension filtering
- `desktop_drop` 0.7.1 - Drag-and-drop file support on desktop
- `flutter_localizations` (SDK) - i18n support (English + Chinese)

## Configuration

**Environment:**
- No `.env` files detected
- No external API keys required
- All configuration via `shared_preferences` (runtime persistence)

**Build:**
- `pubspec.yaml` - Package manifest, Flutter config
- `analysis_options.yaml` - Lint rules (includes `package:flutter_lints/flutter.yaml`)
- `l10n.yaml` - Localization config (ARB files in `lib/l10n/`, template: `app_en.arb`)
- `devtools_options.yaml` - DevTools configuration

## Platform Requirements

**Development:**
- Flutter SDK 3.44+ (beta channel)
- Dart SDK 3.11.5+
- Windows SDK (for native runner compilation)
- CMake 3.14+

**Production:**
- Windows desktop (primary target)
- Frameless window with custom title bar
- D3D11 hardware-accelerated video rendering
- Minimum window size: 640x360

---

*Stack analysis: 2026-05-07*
