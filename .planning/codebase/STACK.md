# Technology Stack

**Analysis Date:** 2026-06-23

## Languages

**Primary:**
- Dart 3.11.5+ — Application logic, UI, state management, FFI bindings
- C++17 — Windows runner (`windows/runner/`), Win32 window management

**Secondary:**
- CMake — Native build system for Windows runner and plugins
- ARB (JSON) — Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)

## Runtime

**Environment:**
- Flutter SDK (stable channel, version 3.45.0-0.1.pre per `.flutter-plugins-dependencies`)
- Dart SDK ^3.11.5 (strict mode enabled)

**Package Manager:**
- Pub (Flutter's built-in package manager)
- Lockfile: `pubspec.lock` (present, 31898 bytes)
- Node.js/npm also present (`package.json` for `@opengsd/gsd-core` tooling only)

## Frameworks

**Core:**
- Flutter — UI framework (Material Design 3)
- `fvp` ^0.37.2 — MDK/FFmpeg video playback engine (D3D11 texture rendering on Windows)
- `window_manager` ^0.5.1 — Cross-platform window management (titlebar, size, position, fullscreen)

**State Management:**
- ValueNotifier + ValueListenableBuilder — No Provider/Riverpod/Bloc
- Custom `MergedListenable` for combining multiple ValueNotifiers (`lib/ui/shared/merged_listenable.dart`)

**Code Generation:**
- `freezed` ^3.2.5 + `freezed_annotation` ^3.1.0 — Immutable data classes
- `json_annotation` ^4.12.0 — JSON serialization
- `build_runner` ^2.15.0 — Code generation runner
- `pigeon` (any) — Platform channel code generation (TypeScript/Dart)

**Testing:**
- `flutter_test` (SDK) — Unit and widget tests
- `integration_test` (SDK) — Integration/E2E tests
- `flutter_lints` ^6.0.0 — Lint rules

**Build/Dev:**
- CMake 3.14+ — Windows native build
- DevTools — Flutter DevTools with `shared_preferences` extension enabled

## Key Dependencies

**Critical (media playback):**
- `fvp` ^0.37.2 — MDK/FFmpeg wrapper, provides `mdk.Player` API, D3D11 texture rendering, hardware decoding (D3D11/NVDEC/FFmpeg fallback)
- `player_engine` (local path: `../widget_tree_flutter/player_engine`) — Abstract `PlayerEngine` interface defining playback contract (open/play/pause/seek/volume/tracks/effects)

**Infrastructure:**
- `window_manager` ^0.5.1 — Window lifecycle, position/size control, fullscreen, always-on-top, drag support
- `shared_preferences` ^2.5.5 — Key-value persistence (settings, window geometry, play mode)
- `path_provider` ^2.1.5 — Application support directory for playlist JSON storage
- `file_picker` ^11.0.2 — Native file open dialog
- `file_selector` (any) — Cross-platform file selection
- `desktop_drop` ^0.7.1 — Drag-and-drop file support

**Utilities:**
- `ffi` ^2.1.0 — Dart FFI for Win32 API calls (fullscreen, display config)
- `path` ^1.9.1 — Path manipulation
- `crypto` ^3.0.6 — MD5 hashing for Linux XDG thumbnail cache lookup
- `logger` ^2.5.0 — Structured logging with PrettyPrinter, module-scoped loggers, file rotation
- `xdg_directories` (any) — XDG directory paths (Linux)
- `cross_file` (any) — Cross-platform file abstraction
- `animations` (any) — Material motion transitions

## Configuration

**Environment:**
- `.env` file present — contains environment configuration (not read for security)
- `SettingsStore` (`lib/kernel/persistence/settings_store.dart`) — 25+ persistent settings via SharedPreferences
- `DisplayConfig` (`lib/kernel/bridge/display_config.dart`) — Refresh-rate-aware D3D11 sync policy

**Build:**
- `pubspec.yaml` — Main project config, dependencies, font assets, l10n generation
- `analysis_options.yaml` — Strict Dart analysis (strict-casts, strict-inference, strict-raw-types)
- `l10n.yaml` — Localization config (ARB → Dart codegen, `AppLocalizations` class)
- `windows/CMakeLists.txt` — Windows build config (C++17, /W4 /WX, UNICODE)
- `windows/runner/CMakeLists.txt` — Runner build config (UTF-8 source, dwmapi.lib)

**Analysis Rules (strict mode):**
```yaml
# analysis_options.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_required_param: error
    missing_return: error
    dead_code: warning
```

**Lint Rules:**
- `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`
- `prefer_final_locals`, `prefer_final_in_for_each`
- `avoid_print` (use `debugPrint()` or `log.*()`)
- `prefer_single_quotes`, `always_declare_return_types`
- `avoid_void_async`, `cancel_subscriptions`, `close_sinks`
- `unawaited_futures`

## Platform Requirements

**Development:**
- Windows 10/11 (primary target)
- Flutter SDK with Windows desktop support enabled
- Visual Studio 2022+ with C++ workload (for CMake/MSVC)
- Dart SDK 3.11.5+
- Node.js/npm (for `@opengsd/gsd-core` tooling only)

**Production:**
- Windows 10/11 (x64)
- Minimum window size: 854x480
- D3D11-capable GPU (hardware decoding) with FFmpeg software fallback
- COM initialization (apartment-threaded, in `main.cpp`)

**Fonts Bundled:**
- Noto Sans SC (Regular/Medium/SemiBold) — Chinese UI text
- Assets: `assets/fonts/NotoSansSC-Regular.ttf`, `NotoSansSC-Medium.ttf`, `NotoSansSC-SemiBold.ttf`

**Network Protocols Supported (via MDK/FFmpeg):**
- Local files: mp4, mkv, avi, mov, flv, webm, m4v, wmv, ts, rmvb, mpg, mpeg, 3gp, vob
- Audio: mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff
- Streaming: http, https, rtmp, rtsp, srt, udp, tcp

---

*Stack analysis: 2026-06-23*
