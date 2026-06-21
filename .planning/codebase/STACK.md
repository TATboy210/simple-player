# Technology Stack

**Analysis Date:** 2026-06-21

## Languages

**Primary:**
- Dart 3.13.0 (SDK constraint `^3.11.5`) — All application logic, UI, state management (`pubspec.yaml:7`)
- C++ 17 — Windows runner, COM initialization, Flutter view hosting (`windows/CMakeLists.txt:46`)

**Secondary:**
- ARB (JSON) — Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- CMake 3.14+ — Build system for Windows native code (`windows/CMakeLists.txt:2`)

## Runtime

**Environment:**
- Flutter 3.45.0-0.1.pre (beta channel) — UI framework, rendering, platform integration
- Dart 3.13.0 (build 3.13.0-103.1.beta) — Language runtime
- DevTools 2.58.0

**Package Manager:**
- pub (Dart built-in) — Dependency management
- Lockfile: `pubspec.lock` present and committed

## Frameworks

**Core:**
- Flutter SDK 3.45.0 — UI framework with Material Design 3
- `fvp` 0.36.2 — MDK/FFmpeg media playback engine with D3D11 rendering (`pubspec.yaml:14`)
- `player_engine` (local path: `../widget_tree_flutter/player_engine`) — Abstract player engine interface with 12 ValueNotifiers (`pubspec.yaml:13`)

**Window Management:**
- `window_manager` 0.5.1 — Cross-platform window control (size, position, maximize, always-on-top, close) (`pubspec.yaml:25`)
- `flutter_fullscreen` 1.2.0 — Native fullscreen toggle (`pubspec.yaml:16`)

**State Management:**
- `ValueNotifier` + `ValueListenableBuilder` — Raw Flutter reactive primitives (no Provider/Riverpod/Bloc)

**Testing:**
- `flutter_test` (SDK) — Unit and widget testing
- `integration_test` (SDK) — Integration testing

**Build/Dev:**
- `build_runner` 2.15.0 — Code generation runner (`pubspec.yaml:34`)
- `freezed` 3.2.5 — Immutable data class generation (`pubspec.yaml:33`)
- `pigeon` 26.3.4 — Platform channel code generation (available, not actively used) (`dev_dependencies`)
- `flutter_lints` 6.0.0 — Lint rules extending `package:flutter_lints/flutter.yaml` (`pubspec.yaml:31`)

## Key Dependencies

**Critical:**
- `fvp` 0.36.2 — Core media engine. Wraps MDK SDK (FFmpeg decoding + D3D11 rendering). Provides `mdk.Player` with FFI bindings for play/pause/seek/texture/video effects/track management. Hardware decoders: D3D11, NVDEC, with FFmpeg software fallback.
- `player_engine` (local) — Abstract `PlayerEngine` class (`lib/kernel/engine/` consumers import from `package:player_engine/player_engine.dart`). Defines 12 ValueNotifiers (textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText, buffered, aspectRatio, errorMessage, playbackSpeed) + playback control methods. `FvpEngine` is the concrete implementation.
- `window_manager` 0.5.1 — Window lifecycle management. `WindowService` wraps it with `WindowListener` mixin for maximize/unmaximize/resize/close events. All window geometry persistence flows through `SettingsStore`.

**Infrastructure:**
- `shared_preferences` 2.5.5 — Key-value persistence for ~25 settings keys (volume, mute, play mode, window geometry, video effects, locale, theme, shortcuts) (`pubspec.yaml:17`)
- `path_provider` 2.1.5 — Platform-specific directory paths (`pubspec.yaml:15`)
- `file_picker` 11.0.2 — Native file open dialog (`pubspec.yaml:16`)
- `desktop_drop` 0.7.1 — Drag-and-drop file support (`pubspec.yaml:18`)
- `logger` 2.7.0 — Structured logging with PrettyPrinter, module-scoped loggers (engine/bridge/services/ui), rotating file output in release builds (`pubspec.yaml:19`)
- `crypto` 3.0.7 — MD5 hashing for XDG thumbnail cache lookup on Linux (`pubspec.yaml:22`)
- `path` 1.9.1 — Cross-platform path manipulation (`pubspec.yaml:21`)

**Data/Serialization:**
- `freezed_annotation` 3.1.0 — Annotations for freezed code generation (`pubspec.yaml:23`)
- `json_annotation` 4.12.0 — Annotations for json_serializable (`pubspec.yaml:24`)

**UI/UX:**
- `animations` 2.2.0 — Material motion transitions (`pubspec.yaml`)
- `xdg_directories` 1.1.0 — Linux XDG directory resolution for thumbnail cache (`pubspec.yaml`)
- `cross_file` 0.3.5+2 — Cross-platform file abstraction (`pubspec.yaml`)
- `file_selector` 1.1.0 — File selection abstraction (`pubspec.yaml`)

## Configuration

**Analysis Options:**
- `analysis_options.yaml` — Strict mode enabled:
  - `strict-casts: true`
  - `strict-inference: true`
  - `strict-raw-types: true`
  - Errors: `missing_required_param: error`, `missing_return: error`
  - Key lint rules: `prefer_final_locals`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `prefer_single_quotes`, `always_declare_return_types`, `avoid_void_async`

**Localization:**
- `l10n.yaml` — ARB-based localization config
  - Template: `app_en.arb`
  - Output class: `AppLocalizations`
  - Supported locales: English (en), Chinese (zh)
  - Default: `preferred-supported-locales: ["en"]`

**Build:**
- `pubspec.yaml` — Flutter project manifest, fonts (Noto Sans SC: Regular/Medium/SemiBold)
- `windows/CMakeLists.txt` — Windows build config (C++17, MSVC `/W4 /WX`, Unicode `-DUNICODE -D_UNICODE`)
- `windows/runner/CMakeLists.txt` — Runner executable build (UTF-8 source via `/utf-8`, `NOMINMAX` defined)
- `devtools_options.yaml` — DevTools configuration

**Code Generation:**
- `freezed` — Generates immutable data classes with `copyWith`, `==`, `hashCode`
- `json_serializable` — Generates `fromJson`/`toJson` for model classes
- Run: `dart run build_runner build --delete-conflicting-outputs`

## Platform Requirements

**Development:**
- Windows 10/11 with Visual Studio 2022 (C++ desktop workload)
- Flutter SDK 3.45.0+ (beta channel)
- Dart SDK 3.13.0+
- MSVC compiler (C++17 standard)

**Production:**
- Windows 10 version 1903+ (for D3D11 support)
- GPU with D3D11 hardware acceleration (or software fallback via FFmpeg)
- Minimum window size: 854x480 (`lib/kernel/bridge/window_service.dart:51`)

---

*Stack analysis: 2026-06-21*
