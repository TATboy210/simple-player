# Technology Stack

**Analysis Date:** 2026-05-09

## Languages

**Primary:**
- Dart 3.12.0 - All application logic, UI, persistence, engine wrappers (`lib/`)
- C++17 - Windows native runner (`windows/runner/`)

**Secondary:**
- ARB (JSON-based) - Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- CMake - Windows/Linux native build configuration (`windows/CMakeLists.txt`, `linux/CMakeLists.txt`)

## Runtime

**Environment:**
- Flutter 3.44.0-0.3.pre (beta channel) with Dart 3.12.0
- Target platforms: Windows (primary), Linux, macOS

**Package Manager:**
- pub (Dart built-in)
- Lockfile: `pubspec.lock` (present, committed)

**Dart SDK Constraint:**
- `^3.11.5` (in `pubspec.yaml`)

## Frameworks

**Core:**
- Flutter SDK - UI framework, rendering, widget system
- fvp 0.36.2 - Media playback engine (wraps MDK/FFmpeg, D3D11 on Windows, OpenGL on Linux)

**UI Libraries:**
- shadcn_flutter 0.0.52 - Component library (buttons, dialogs, inputs)
- glass_kit 4.0.2 - Glass-morphism effects (BackdropFilter wrappers)
- flutter_animate 4.5.2 - Declarative animation chains
- flutter_zoom_drawer 3.2.0 - Zoom drawer animation
- smooth_page_indicator 2.0.1 - Page indicator dots
- velocity_x 4.3.1 - Utility extensions and layout helpers
- dynamic_color 1.8.1 - Material You dynamic color support

**Desktop/Platform:**
- window_manager 0.5.1 - Window geometry, always-on-top, fullscreen, title bar control
- desktop_drop 0.7.1 - Drag-and-drop file support for desktop
- file_picker 11.0.2 - Native file open dialogs

**Persistence:**
- shared_preferences 2.5.5 - Key-value storage (settings, window geometry, locale)
- path_provider 2.1.5 - Platform-specific app data directories

**Audio:**
- just_audio 0.10.5 - Audio-only playback (used alongside fvp)

**Localization:**
- easy_localization 3.0.8 - i18n framework
- flutter_localizations (SDK) - Flutter built-in localization delegates

**Logging:**
- logger 2.7.0 - Structured logging with PrettyPrinter (`lib/kernel/utils/log.dart`)

**Testing:**
- flutter_test (SDK) - Widget and unit test framework
- flutter_lints 6.0.0 - Lint rules (extends `package:flutter_lints/flutter.yaml`)
- fake_async 1.3.3 - Deterministic async testing

## Key Dependencies

**Critical:**
- fvp 0.36.2 - The entire media playback pipeline. Wraps MDK (Media Development Kit) which uses FFmpeg for decoding and D3D11/OpenGL for rendering. Without this, no media playback.
- window_manager 0.5.1 - All window chrome behavior (title bar, resize, fullscreen, pin-on-top). Pinned to exact version (not `^`).
- shared_preferences 2.5.5 - All persistence. Settings, window geometry, locale, video processing state all stored here.

**Infrastructure:**
- path_provider 2.1.5 - Resolves app support directory for playlist JSON files
- file_picker 11.0.2 - Native file open dialog (cross-platform)
- desktop_drop 0.7.1 - Drag-and-drop file handling

## Configuration

**Environment:**
- No `.env` files used. All configuration is compile-time or runtime persistence.
- No external API keys or service credentials required.
- Settings stored in platform-native SharedPreferences (Windows Registry / Linux file).

**Build:**
- `pubspec.yaml` - Dependency and Flutter config (`flutter generate: true` for l10n codegen)
- `analysis_options.yaml` - Extends `package:flutter_lints/flutter.yaml`, no custom rules
- `l10n.yaml` - Localization codegen config (ARB dir: `lib/l10n`, template: `app_en.arb`, output class: `AppLocalizations`)
- `windows/CMakeLists.txt` - Windows native build (C++17, MSVC, `/utf-8` for Chinese comments)
- `devtools_options.yaml` - Flutter DevTools config

**CI/CD:**
- `.github/workflows/ci.yml` - Runs on `windows-latest`: `flutter pub get`, `dart analyze --fatal-infos`, `flutter test`, `dart format --set-exit-if-changed .`
- `.github/workflows/build-linux.yml` - Builds Linux release tarball on `ubuntu-latest`
- `.github/workflows/build-macos.yml` - Builds macOS DMG on `macos-latest`

## Platform Requirements

**Development:**
- Flutter SDK 3.44.0+ (beta channel currently used)
- Dart SDK 3.12.0+
- Windows: MSVC build tools, CMake 3.14+
- Linux: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev
- macOS: Xcode, create-dmg (for packaging)

**Production:**
- Windows 10+ (D3D11 hardware acceleration)
- Linux (GTK3, OpenGL)
- macOS 10.15+ (Metal rendering)

## State Management Pattern

**Approach:** ValueNotifier + ValueListenableBuilder (no third-party state management)

**Pattern:**
- `MediaEngine` interface (`lib/kernel/engine/media_engine.dart`) exposes 13 `ValueNotifier` fields
- `FvpEngine` (`lib/kernel/engine/fvp_engine.dart`) implements the interface
- Widgets bind via `ValueListenableBuilder<T>` wrappers
- Services like `VideoProcessingService` (`lib/kernel/services/video_processing_service.dart`) hold additional ValueNotifiers with auto-persist listeners

**No Provider, Riverpod, BLoC, orGetX used.**

## Design System

**Tokens:**
- 50 compile-time const tokens in `lib/kernel/ui/theme/tokens.dart` (ThemeConfig)
- Exposed via `DesignTokens` static facade (`lib/kernel/ui/theme/app_theme.dart`)

**Theme:**
- Single dark theme: Midnight
- Glass-morphism: `BackdropFilter` + `bgGlass` + `borderHighlight`
- All visual values via `DesignTokens.*` (no hardcoded colors/fonts/spacing)

---

*Stack analysis: 2026-05-09*
