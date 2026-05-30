# Technology Stack

**Analysis Date:** 2026-05-30

## Languages

**Primary:**
- Dart 3.11.5+ — Application logic, UI, state management (`pubspec.yaml:7`)
- C++ 17 — Windows runner, COM initialization (`windows/CMakeLists.txt:46`)

**Secondary:**
- CMake 3.14+ — Build system for Windows native code (`windows/CMakeLists.txt:2`)

## Runtime

**Environment:**
- Flutter SDK (latest stable) — UI framework, rendering, platform integration
- Dart SDK ^3.11.5 — Language runtime (`pubspec.yaml:7`)
- Windows 10/11 — Target platform (Win32 API, D3D11)

**Package Manager:**
- Flutter/pub — Dependency management
- Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Flutter — UI framework with Material Design 3
- fvp ^0.36.2 — MDK/FFmpeg media playback engine with D3D11 rendering (`pubspec.yaml:14`)
- window_manager ^0.5.1 — Window management (frameless, fullscreen, resize) (`pubspec.yaml:25`)

**Testing:**
- flutter_test — Unit and widget testing (SDK)
- integration_test — Integration testing (SDK)

**Build/Dev:**
- build_runner ^2.15.0 — Code generation runner (`pubspec.yaml:34`)
- freezed ^3.2.5 — Immutable data class generation (`pubspec.yaml:33`)
- flutter_lints ^6.0.0 — Lint rules (`pubspec.yaml:31`)

## Key Dependencies

**Critical:**
- fvp ^0.36.2 — Core media engine; wraps MDK (FFmpeg + D3D11). Provides `mdk.Player` FFI interface for playback, seeking, track management, video effects
- window_manager ^0.5.1 — Window lifecycle management; provides `WindowListener` events, `DragToResizeArea`, frameless window support
- ffi ^2.1.4 — Dart FFI for calling Win32 APIs directly (`pubspec.yaml:20`)

**Infrastructure:**
- shared_preferences ^2.5.5 — Key-value persistence for app settings (`pubspec.yaml:17`)
- path_provider ^2.1.5 — Platform-specific directory paths (ApplicationSupport) (`pubspec.yaml:15`)
- file_picker ^11.0.2 — Native file open dialogs (`pubspec.yaml:16`)
- desktop_drop ^0.7.1 — Drag-and-drop file support (`pubspec.yaml:18`)
- logger ^2.5.0 — Structured logging with file rotation (`pubspec.yaml:19`)
- path ^1.9.1 — Path manipulation utilities (`pubspec.yaml:21`)
- crypto ^3.0.6 — Hashing (used for thumbnail cache keys) (`pubspec.yaml:22`)

**Data/Serialization:**
- freezed_annotation ^3.1.0 — Annotations for freezed code generation (`pubspec.yaml:23`)
- json_annotation ^4.12.0 — Annotations for json_serializable (`pubspec.yaml:24`)

## Configuration

**Environment:**
- `.env` files: Not used — all configuration via `SharedPreferences` at runtime
- Settings persistence: `SettingsStore` wraps `SharedPreferences` with validation (`lib/kernel/persistence/settings_store.dart`)
- Window geometry: Saved/restored via `SettingsStore.saveWindowGeometry()`

**Build:**
- `pubspec.yaml` — Flutter project configuration, dependencies, fonts
- `analysis_options.yaml` — Lint rules extending `flutter_lints/flutter.yaml`
- `l10n.yaml` — Localization config (ARB-based, en/zh) (`l10n.yaml`)
- `windows/CMakeLists.txt` — CMake build for Windows runner

**Code Generation:**
- `freezed` — Generates immutable data classes with `copyWith`, `==`, `hashCode`
- `json_serializable` — Generates `fromJson`/`toJson` for model classes
- Run: `dart run build_runner build --delete-conflicting-outputs`

## Platform Requirements

**Development:**
- Windows 10/11 with Visual Studio 2022 (C++ desktop workload)
- Flutter SDK with Windows desktop support enabled
- Dart SDK 3.11.5+

**Production:**
- Windows 10 version 1903+ (for D3D11 support)
- GPU with D3D11 hardware acceleration (or software fallback via FFmpeg)
- Minimum window size: 854x480 (`lib/main.dart:25`)

## Architecture Patterns

**State Management:**
- ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- 12+ ValueNotifiers per `MediaEngine` instance (`lib/kernel/engine/media_engine.dart:20-58`)
- Window state via `WindowService` ValueNotifiers (`lib/kernel/bridge/window_service.dart:32-35`)

**Engine Abstraction:**
- `MediaEngine` abstract interface (`lib/kernel/engine/media_engine.dart`)
- `FvpEngine` concrete implementation (`lib/kernel/engine/fvp_engine.dart`)
- Composed of 3 helpers: `FvpCallbackHandler`, `PositionPoller`, `TrackManager`

**Window Management:**
- `WindowService` wraps `window_manager` with Win32 FFI (`lib/kernel/bridge/window_service.dart`)
- `Win32Bindings` lazy singleton for user32.dll/dwmapi.dll FFI (`lib/kernel/bridge/win32_bindings.dart`)
- Custom fullscreen via WS_POPUP + DwmExtendFrameIntoClientArea (`lib/kernel/bridge/window_service.dart:158-206`)
- Custom maximize via rcWork (work area, not full monitor) (`lib/kernel/bridge/window_service.dart:253-287`)

**Startup Sequence:**
- `StartupCoordinator` tracks phase progress (`lib/kernel/startup/startup_coordinator.dart`)
- Phases: infrastructure → settings → ready
- `EnginePrewarm` pre-initializes MDK/FFmpeg context (`lib/kernel/engine/engine_prewarm.dart`)
- `SettingsStore.prewarm()` caches SharedPreferences instance (`lib/kernel/persistence/settings_store.dart:26`)

---

*Stack analysis: 2026-05-30*
