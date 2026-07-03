# Technology Stack

**Analysis Date:** 2026-07-03

## Languages

**Primary:**
- Dart 3.12.2 (stable) — All application logic, UI, services, models
- C++ 17 — Windows runner (`windows/runner/*.cpp`), Win32 window management

**Secondary:**
- CMake — Build system for native platform runners (`windows/CMakeLists.txt`, `linux/CMakeLists.txt`)
- ARB (JSON) — Localization strings (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)

## Runtime

**Environment:**
- Flutter 3.44.4 (stable channel) — Framework revision `ad70ec4617`
- Dart SDK ^3.11.5 (resolved: 3.12.2)
- Engine: Flutter engine `700aebeca4`

**Package Manager:**
- pub (Dart built-in)
- Lockfile: present (`pubspec.lock`)

**Target Platform:**
- Windows desktop (primary, x64)
- Linux desktop (secondary, CMake build)
- macOS desktop (secondary, Xcode build)

## Frameworks

**Core:**
- Flutter 3.44.4 — UI framework, Material Design, platform channels
- fvp 0.37.2 — Media playback engine (MDK/FFmpeg + D3D11 rendering)

**State Management:**
- ValueNotifier + ValueListenableBuilder — No Provider/Riverpod/Bloc, pure Flutter reactive state

**Testing:**
- flutter_test (SDK) — Unit and widget tests
- integration_test (SDK) — Integration tests
- flutter_goldens — Golden image tests (`test/golden/`)

**Build/Dev:**
- build_runner 2.15.0 — Code generation (freezed, json_serializable)
- freezed 3.2.5 — Immutable data classes with copyWith/JSON support
- pigeon 27.1.0 — Platform channel code generation

## Key Dependencies

**Critical (Media Playback):**
- fvp 0.37.2 — FFmpeg + MDK media engine, D3D11 texture rendering
- ffi 2.2.0 — Dart FFI for Win32 API calls (display enumeration, window management)

**Window Management:**
- window_manager 0.5.1 — Cross-platform window control (position, size, fullscreen, always-on-top)
- fullscreen_window 1.3.0 (local package) — Platform-specific fullscreen toggle (`packages/fullscreen_window/`)
- hotkey_manager 0.2.3 — System-wide media key registration (play/pause/next/prev)

**File System:**
- file_picker 11.0.2 — Native file open dialog
- desktop_drop 0.7.1 — Drag-and-drop file support
- path_provider 2.1.6 — Platform-specific app data directories
- path 1.9.1 — Path manipulation utilities
- xdg_directories 1.1.0 — Linux XDG directory resolution
- file_selector 1.1.0 — File selection abstraction

**Data/Storage:**
- shared_preferences 2.5.5 — Key-value persistence (settings, window geometry)
- crypto 3.0.7 — Hash functions for cache keys

**UI/UX:**
- animations 2.2.0 — Material motion transitions
- cross_file 0.3.5+2 — Cross-platform file abstraction

**Code Generation:**
- freezed_annotation 3.1.0 — Annotations for freezed code generation
- json_annotation 4.12.0 — Annotations for json_serializable

**Logging:**
- logger 2.7.0 — Structured logging with PrettyPrinter, file rotation in release mode

## Configuration

**Environment:**
- `--dart-define=USE_MOCK_ENGINE=true` — Compile-time switch to use MockEngine for testing
- `.env` file: Not used (no external API keys required)

**Build:**
- `pubspec.yaml` — Dart/Flutter package configuration
- `analysis_options.yaml` — Strict mode enabled (strict-casts, strict-inference, strict-raw-types)
- `l10n.yaml` — Localization generation config (ARB → Dart)
- `distribute_options.yaml` — MSIX packaging config for Windows releases
- `devtools_options.yaml` — DevTools extension settings

**Design System:**
- Compile-time const design tokens in `lib/ui/theme/tokens.dart`
- All visual values via `Tokens.*` static constants
- Glassmorphism pattern: `BackdropFilter` + `bgGlass` + `borderHighlight`

**Fonts:**
- Noto Sans SC (Regular 400, Medium 500, SemiBold 600) — Bundled in `assets/fonts/`

**Localization:**
- English (en) and Chinese (zh) supported
- Generated via `flutter gen-l10n` from ARB files

## Platform Requirements

**Development:**
- Windows 10/11 (x64) — Primary development platform
- Flutter 3.44.4+ SDK
- Dart 3.12.2+ SDK
- Visual Studio 2022 with C++ workload (for Windows runner build)
- CMake 3.14+

**Production:**
- Windows 10/11 (x64) — Primary deployment target
- D3D11-capable GPU (hardware decoding) or CPU fallback (FFmpeg soft decode)
- Minimum window size: 854x513 (16:9 ratio)

**Build Commands:**
```bash
flutter pub get                 # Install dependencies
flutter run -d windows          # Run in debug mode
flutter analyze                 # Static analysis (strict mode)
flutter test                    # Run all tests
flutter build windows --release # Production build
```

## Native Platform Layer

**Windows (`windows/`):**
- `runner/main.cpp` — Win32 entry point
- `runner/win32_window.cpp` — Window creation with DWM integration
- `runner/flutter_window.cpp` — Flutter view host
- CMake build system with C++17 standard

**Dart FFI (`lib/kernel/bridge/win32/`):**
- `win32_display_enumerator.dart` — Direct Win32 FFI calls (EnumDisplayMonitors, GetMonitorInfoW, MonitorFromWindow)
- Uses `user32.dll` for display enumeration
- No win32 package dependency (raw FFI as per project policy)

**Local Package (`packages/fullscreen_window/`):**
- Forked fullscreen plugin with Windows, Linux, macOS, web, Android, iOS support
- Platform-specific implementations via pluginClass registrations

## Development Tools

**Code Generation:**
- `build_runner` — `dart run build_runner build` for freezed/json_serializable
- `pigeon` — Platform channel interface generation

**Debugging:**
- `DebugProbe` — Lightweight operation timing (`lib/kernel/utils/debug_probe.dart`)
- `MemoryMonitor` — RSS memory sampling (`lib/kernel/utils/memory_monitor.dart`)
- `DebugExporter` — One-click diagnostics export to `%APPDATA%/SimplePlayer/debug/`
- `scripts/apply_queryfence_patch.dart` — Auto-apply fvp performance patch

**MCP Integration:**
- `code-review-graph` MCP server configured in `.mcp.json`

---

*Stack analysis: 2026-07-03*
