# Technology Stack

**Analysis Date:** 2026/06/23

## Languages

**Primary:**
- Dart 3.11.5+ — Application logic, UI, state management (`lib/`)
- C++ 17 — Windows runner, COM initialization, Flutter view hosting (`windows/runner/`)
- CMake 3.14+ — Build system for native Windows runner (`windows/CMakeLists.txt`)

**Secondary:**
- ARB (JSON) — Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- Dart FFI — Win32 API calls from Dart (`lib/kernel/bridge/win32/win32_platform_fullscreen.dart`)

## Runtime

**Environment:**
- Flutter SDK (stable channel) — UI framework, rendering, platform integration
- Dart SDK ^3.11.5 — Language runtime

**Package Manager:**
- pub (Dart built-in) — Dependency management
- Lockfile: `pubspec.lock` present and committed

## Frameworks

**Core:**
- Flutter SDK — UI framework with Material Design 3
- fvp ^0.37.2 — MDK/FFmpeg media playback engine with D3D11 rendering (`pubspec.yaml:16`)
- player_engine (local path: `../widget_tree_flutter/player_engine`) — Abstract player engine interface with 12 ValueNotifiers (`pubspec.yaml:15`)

**Window Management:**
- window_manager ^0.5.1 — Cross-platform window control (size, position, maximize, always-on-top, close) (`pubspec.yaml:27`)
- Win32 FFI — Direct fullscreen control via `user32.dll` (FindWindow, GetWindowLongPtr, SetWindowLongPtr, SetWindowPos) (`lib/kernel/bridge/win32/win32_platform_fullscreen.dart`)

**State Management:**
- ValueNotifier + ValueListenableBuilder — Raw Flutter reactive primitives (no Provider/Riverpod/Bloc)

**Testing:**
- flutter_test (SDK) — Unit and widget testing
- integration_test (SDK) — Integration testing

**Build/Dev:**
- build_runner ^2.15.0 — Code generation runner (`pubspec.yaml:40`)
- freezed ^3.2.5 — Immutable data class generation (`pubspec.yaml:39`)
- pigeon — Platform channel code generation (`pubspec.yaml:41`)
- flutter_lints ^6.0.0 — Lint rules extending `package:flutter_lints/flutter.yaml` (`pubspec.yaml:36`)

## Key Dependencies

**Critical (media pipeline):**
- fvp ^0.37.2 — Core media engine. Wraps MDK SDK (FFmpeg decoding + D3D11 rendering). Provides `mdk.Player` with FFI bindings for play/pause/seek/texture/video effects/track management. Hardware decoders: D3D11, NVDEC, with FFmpeg software fallback.
- player_engine (local) — Abstract `PlayerEngine` class (`lib/kernel/engine/` consumers import from `package:player_engine/player_engine.dart`). Defines 12 ValueNotifiers (textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText, buffered, aspectRatio, errorMessage, playbackSpeed) + playback control methods. `FvpEngine` is the concrete implementation.

**Critical (window control):**
- window_manager ^0.5.1 — Window lifecycle management. `WindowService` wraps it with `WindowListener` mixin for maximize/unmaximize/resize/close events. All window geometry persistence flows through `SettingsStore`.
- ffi ^2.1.0 — Dart FFI for direct Win32 API calls (fullscreen, style manipulation) (`pubspec.yaml:26`)

**Infrastructure:**
- shared_preferences ^2.5.5 — Key-value persistence for ~25 settings keys (volume, mute, play mode, window geometry, video effects, locale, theme, shortcuts) (`pubspec.yaml:19`)
- path_provider ^2.1.5 — Platform-specific directory paths (`pubspec.yaml:17`)
- file_picker ^11.0.2 — Native file open dialog (`pubspec.yaml:18`)
- desktop_drop ^0.7.1 — Drag-and-drop file support (`pubspec.yaml:20`)
- logger ^2.5.0 — Structured logging with module-scoped loggers (`pubspec.yaml:21`)
- crypto ^3.0.6 — MD5 hashing for thumbnail cache keys (`pubspec.yaml:23`)
- path ^1.9.1 — Cross-platform path manipulation (`pubspec.yaml:22`)

**Data/Serialization:**
- freezed_annotation ^3.1.0 — Annotations for freezed code generation (`pubspec.yaml:24`)
- json_annotation ^4.12.0 — Annotations for json_serializable (`pubspec.yaml:25`)

**UI/UX:**
- animations — Material motion transitions (`pubspec.yaml:30`)
- xdg_directories — Linux XDG directory resolution for thumbnail cache (`pubspec.yaml:29`)
- cross_file — Cross-platform file abstraction (`pubspec.yaml:31`)
- file_selector — File selection abstraction (`pubspec.yaml:28`)

**Localization:**
- flutter_localizations (SDK) — Material/Cupertino localization delegates
- intl — Date/number formatting (via `package:intl`)

## Configuration

**Analysis Options:**
- `analysis_options.yaml` — Strict mode enabled:
  - `strict-casts: true`
  - `strict-inference: true`
  - `strict-raw-types: true`
  - Errors: `missing_required_param: error`, `missing_return: error`, `dead_code: warning`
  - Key lint rules: `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, `prefer_final_locals`, `prefer_final_in_for_each`, `avoid_print`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_void_async`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`

**Localization:**
- `l10n.yaml` — ARB-based localization config
  - Template: `app_en.arb`
  - Output class: `AppLocalizations`
  - Supported locales: English (en), Chinese (zh)
  - Default: `preferred-supported-locales: ["en"]`
  - Nullable getter: false

**Build (Windows CMake):**
- `windows/CMakeLists.txt` — C++17, MSVC `/W4 /WX`, Unicode (`-DUNICODE -D_UNICODE`)
- `windows/runner/CMakeLists.txt` — Runner executable build (UTF-8 source via `/utf-8`, `NOMINMAX` defined)
- Linker: `dwmapi.lib` (Desktop Window Manager API)
- Preprocessor: `_HAS_EXCEPTIONS=0`

**DevTools:**
- `devtools_options.yaml` — shared_preferences extension enabled

**Code Generation:**
- freezed — Generates immutable data classes with `copyWith`, `==`, `hashCode`
- json_serializable — Generates `fromJson`/`toJson` for model classes
- Run: `dart run build_runner build --delete-conflicting-outputs`

## Build Commands

```bash
flutter pub get                              # Install dependencies
flutter run -d windows                       # Development run
flutter analyze                              # Static analysis
flutter test                                 # Run unit/widget tests
flutter build windows                        # Release build
flutter generate                             # Regenerate l10n + code gen
dart run build_runner build --delete-conflicting-outputs  # Code generation
```

## Platform Requirements

**Development:**
- Windows 10/11 with Visual Studio 2022 (C++ desktop workload)
- Flutter SDK (stable channel)
- Dart SDK 3.11.5+
- MSVC compiler (C++17 standard)

**Production:**
- Windows 10 version 1903+ (for D3D11 support)
- GPU with D3D11 hardware acceleration (or software fallback via FFmpeg)
- Minimum window size: 854x480 (`lib/kernel/bridge/window_service.dart:76`)
- Default window size: 1280x720 (`windows/runner/main.cpp:29`)

**Fonts:**
- Noto Sans SC (Chinese font) — bundled in `assets/fonts/`
  - Regular (400), Medium (500), SemiBold (600)

---

*Stack analysis: 2026/06/23*
