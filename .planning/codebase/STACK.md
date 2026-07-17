> ⚠️ **v2.1 前快照（2026-07-12）** — 此文档描述 v2.1 重构前结构，Phase 15+ 一律对 LIVE code + codegraph 核对，勿信本快照具体路径/类名。保留作演进历史。

# Technology Stack

**Analysis Date:** 2026-07-12

## Languages

**Primary:**
- Dart 3.11.5+ - All application code (`lib/`), UI layer, business logic, persistence

**Secondary:**
- C++ - Windows native runner (`windows/runner/main.cpp`, `win32_window.cpp`, `flutter_window.cpp`)
- C - Linux native runner (`linux/runner/main.cc`, `my_application.cc`)
- Swift - macOS native runner (`macos/Runner/AppDelegate.swift`, `MainFlutterWindow.swift`)
- C (FFI) - Win32 API bindings (`lib/kernel/bridge/win32/win32_fullscreen_ffi.dart`, `win32_display_enumerator.dart`)

## Runtime

**Environment:**
- Flutter 3.x (desktop targets: Windows, macOS, Linux)
- Dart SDK ^3.11.5

**Package Manager:**
- pub (Flutter built-in)
- Lockfile: `pubspec.lock` (present, committed)

## Frameworks

**Core:**
- Flutter - Cross-platform UI framework (desktop-focused)
- fvp ^0.37.2 - Media playback engine (MDK/FFmpeg wrapper, D3D11 rendering on Windows)
- window_manager ^0.5.2 - Window management (positioning, frameless, title bar)
- hotkey_manager ^0.2.3 - Global hotkey registration

**Testing:**
- flutter_test (SDK) - Widget and unit testing
- integration_test (SDK) - Integration testing
- build_runner ^2.15.0 - Code generation runner (for freezed)

**Build/Dev:**
- flutter_lints ^6.0.0 - Lint rules
- freezed ^3.2.5 (dev) - Immutable data class code generation
- pigeon (dev) - Type-safe platform channel code generation
- msix ^3.16.0 (dev) - Windows MSIX packaging

## Key Dependencies

**Critical (media playback):**
- fvp ^0.37.2 - MDK/FFmpeg playback engine; D3D11 hardware decoding on Windows, NVDEC GPU acceleration
- ffi ^2.1.0 - Dart FFI for direct Win32 API calls (fullscreen, display enumeration)

**Infrastructure:**
- shared_preferences ^2.5.5 - Key-value persistence (settings, window geometry)
- path_provider ^2.1.5 - Platform-appropriate file paths (logs, playlists)
- path ^1.9.1 - Cross-platform path manipulation
- crypto ^3.0.6 - Hash generation (file identification)
- logger ^2.5.0 - Structured logging with PrettyPrinter

**UI:**
- window_manager ^0.5.2 - Window frame, position, fullscreen, always-on-top
- hotkey_manager ^0.2.3 - Global keyboard shortcuts
- desktop_drop ^0.7.1 - Drag-and-drop file support
- file_picker ^11.0.2 - Native file picker dialog
- file_selector - Platform file selection
- animations - Material motion transitions
- xdg_directories - Linux XDG base directory support

**Code Generation:**
- freezed_annotation ^3.1.0 - Annotations for freezed immutable classes
- json_annotation ^4.12.0 - JSON serialization annotations

**Local Package:**
- fullscreen_window (path: `packages/fullscreen_window`) - Forked fullscreen plugin (v1.3.0), provides platform-specific fullscreen via native plugin classes

## Configuration

**Environment:**
- No `.env` files detected - configuration is compile-time or runtime-persisted
- Compile-time flags via `--dart-define`:
  - `USE_WINDOWS_NATIVE_FULLSCREEN=true` - Enables Win32 FFI fullscreen driver (default: false, uses window_manager)
- Runtime settings stored via `shared_preferences` (key-value)

**Build:**
- `pubspec.yaml` - Package manifest, dependencies, MSIX config
- `analysis_options.yaml` - Strict Dart analysis (strict-casts, strict-inference, strict-raw-types)
- `windows/CMakeLists.txt` - Windows native build
- `linux/CMakeLists.txt` - Linux native build
- `macos/Runner.xcodeproj/` - macOS Xcode project

**Linting (analysis_options.yaml):**
- Base: `package:flutter_lints/flutter.yaml`
- Strict mode: `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
- Errors elevated: `missing_required_param: error`, `missing_return: error`
- Key rules: `prefer_const_constructors`, `prefer_final_locals`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`

## Platform Requirements

**Development:**
- Flutter SDK with desktop support enabled
- Windows: Visual Studio 2022+ with C++ desktop development workload
- macOS: Xcode 14+
- Linux: GTK 3 development libraries, CMake

**Production:**
- Windows: MSIX packaging (msix ^3.16.0), `internetClient` capability
- Windows: D3D11-capable GPU for hardware-accelerated playback
- macOS/Linux: Standard desktop runtime

## Package Highlights

**fullscreen_window (local fork at `packages/fullscreen_window/`):**
- Version 1.3.0, forked from `jakky1/fullscreen_window`
- Platform plugin classes: `FullscreenWindowPluginCApi` (Windows), `FullscreenWindowPlugin` (Linux/macOS)
- Supplemented by app-level Win32 FFI driver (`lib/kernel/bridge/win32/win32_fullscreen_ffi.dart`)

---

*Stack analysis: 2026-07-12*
