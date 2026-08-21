# Technology Stack

**Analysis Date:** 2026-08-21

## Languages

**Primary:**
- Dart 3.13.0 — All application code under `lib/`; declared SDK constraint `sdk: ^3.11.5` in `pubspec.yaml:7`
- C++ — Windows desktop shell (`windows/runner/`: `main.cpp`, `flutter_window.cpp`, `win32_window.cpp`, `utils.cpp`) and CMake build (`windows/CMakeLists.txt`)

**Secondary:**
- CMake 3.14+ — Windows native build configuration (`windows/CMakeLists.txt`)
- YAML — Lint config (`analysis_options.yaml`), l10n config (`l10n.yaml`), distribution config (`distribute_options.yaml`)

## Runtime

**Environment:**
- Flutter 3.47.0 (channel stable, engine revision 59d54a2b2896) — desktop-only media player, no mobile/web target shipped
- Dart VM on Windows x64

**Package Manager:**
- pub (Flutter SDK) — `pubspec.yaml` + `pubspec.lock` committed
- Lockfile: present (`pubspec.lock`)
- Node `package.json` exists but only declares a dev-tooling dependency on `@opengsd/gsd-core` (`package.json:3`); not part of the app runtime

## Frameworks

**Core:**
- Flutter 3.47.0 — UI framework, `MaterialApp` shell in `lib/app.dart:53`
- media_kit 1.2.6 — libmpv-based media engine, the **sole** playback backend (`lib/kernel/engine/media_kit_engine.dart:34`)
- media_kit_video 2.0.1 — `VideoController` + `Video` widget for texture rendering (`lib/kernel/engine/media_kit_engine.dart:47`)
- media_kit_libs_windows_video 1.0.11 — prebuilt libmpv binaries for Windows (primary target)
- media_kit_libs_macos_video 1.1.4 + media_kit_libs_linux 1.2.1 — platform native libs for macOS/Linux

**Testing:**
- flutter_test (SDK) — unit, widget, golden tests
- integration_test (SDK) — device/E2E (`integration_test/simple_test.dart`)
- fake_async 1.3.3 — timer-controlled unit tests

**Build/Dev:**
- build_runner 2.15.1 — code generation runner
- freezed 3.2.5 — immutable data classes (annotations declared but no generated files currently committed under `lib/`)
- pigeon — platform channel codegen (dev dependency, declared `any`)
- msix 3.18.0 — Windows MSIX packaging (`pubspec.yaml:73-79`)
- flutter_lints 6.0.0 + lints 6.1.0 — static analysis rule sets

## Key Dependencies

**Critical:**
- media_kit 1.2.6 — The entire playback stack; `MediaKitEngine` is the only `MediaEngine` implementation; legacy fvp/MDK backend removed (`lib/kernel/engine/media_kit_engine.dart:20-34`)
- window_manager 5.15.0 — Window geometry, frameless title bar, fullscreen/maximize/minimize, `setPreventClose` hook (`lib/kernel/window_Bridge/window_manager_service.dart:93`)
- shared_preferences 2.5.5 — Window state persistence (size/position/alwaysOnTop/maximized) in `lib/kernel/persistence/window_persistence.dart:32`
- path_provider 2.1.6 — App support directory for playlist JSON + debug exports (`lib/kernel/persistence/playlist_store.dart:60`, `lib/kernel/utils/debug_exporter.dart:39`)

**Infrastructure:**
- file_picker 11.0.3 — Native OS file open dialog (`lib/features/player/file_picker_adapters.dart:20`)
- desktop_drop 0.7.1 — OS-level drag-and-drop file reception (`lib/ui/player/drop_handler.dart:43`)
- ffi 2.2.0 — `dart:ffi` bindings package (declared; no direct `dart:ffi`/`lookupFunction` usage in `lib/` currently — Win32 bridge lives in `lib/kernel/window_Bridge/` via `window_manager` rather than raw FFI)
- flutter_secure_storage 9.2.4 — Declared in `pubspec.yaml:25`; no direct import found in `lib/` (available for future secrets; currently unused at runtime)
- crypto 3.0.7 — MD5 hashing of file URIs for Linux XDG thumbnail cache lookup (`lib/kernel/services/linux_thumbnail_provider.dart:3`)

**State Management:**
- ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc/GetIt for app state) — `MediaEngine` exposes ValueNotifiers; `PlayerServices` wires them; see `lib/kernel/player_services.dart`
- get 4.7.3 + get_it 2.1.3 — Declared as direct dependencies; get_it is a transitive of media_kit. No `Get.find`/`Get.put` usage in `lib/` (unused at present)
- go_router 16.3.0 — Declared direct dependency; no `GoRouter`/`go(` usage in `lib/` (single-screen app, currently unused)

**Networking:**
- dio 5.11.0 — Declared direct dependency; no `Dio`/`BaseOptions` usage in `lib/` (no HTTP client calls in app; streaming URL schemes are passed to libmpv, not fetched by Dart)

**Observability:**
- logger 2.7.0 — Declared; app uses custom `KernelLogger` facade (`lib/kernel/diagnostics/kernel_logger.dart:364`) instead, routing through `dart:developer.log` + `debugPrint`
- marionette_flutter 0.6.0 — Debug-only VM service binding for UI automation via `MarionetteBinding.ensureInitialized()` (`lib/main.dart:15`), gated by `kDebugMode`

## Configuration

**Environment:**
- No `.env` file or runtime env-var loading. Configuration is compile-time via `--dart-define` (e.g. `--dart-define=USE_MOCK_ENGINE=false` in `distribute_options.yaml:10`)
- Build mode drives `KernelLogger` sink selection: debug → CompositeSink, profile → DevToolsSink, release → NullSink (`lib/kernel/diagnostics/kernel_logger.dart:510-519`)
- `KernelLoggerImpl.I` is a static singleton requiring `init()` at startup (`lib/main.dart:21`)

**Build:**
- `pubspec.yaml` — dependency manifest + MSIX config (`msix_config` block, `pubspec.yaml:73-79`)
- `analysis_options.yaml` — strict-casts/strict-inference/strict-raw-types enabled; DCM (dart_code_metrics) rules + metrics (cyclomatic-complexity 15, max-nesting 6, `analysis_options.yaml:39-71`)
- `l10n.yaml` — ARB localization config, template `app_en.arb`, output class `AppLocalizations` (`l10n.yaml:1-6`)
- `distribute_options.yaml` — MSIX release job targeting `windows`/`msix` (`distribute_options.yaml:1-11`)
- `windows/CMakeLists.txt` — CMake 3.14+, Unicode, Debug/Profile/Release configs, CMP0175 workaround for media_kit_libs subdirectory
- `.mcp.json` — MCP servers for dev tooling (code-review-graph, marionette); not part of app runtime
- `devtools_options.yaml` — Enables DevTools extensions for shared_preferences + get_it (`devtools_options.yaml:3-4`)

## Platform Requirements

**Development:**
- Windows 11 (current dev environment: Windows 11 Home China 10.0.26200)
- Flutter SDK 3.47.0 stable on PATH
- CMake 3.14+ and Visual Studio C++ build tools (for `windows/runner` native build)
- Optional: DCM (`dcm.exe`) for the 31 enabled rules in `analysis_options.yaml:40-63`

**Production:**
- Windows desktop MSIX package (`com.simpleplayer.app`, `pubspec.yaml:76`) with `internetClient` capability (`pubspec.yaml:79`)
- macOS and Linux targets structurally supported (native libs declared, thumbnail providers implemented for Linux/macOS in `lib/kernel/services/`), but the shipped/distributed target is Windows MSIX
- No web target (`web/` excluded from analysis in `analysis_options.yaml:16`); no Android/iOS target shipped (`android/`/`ios/` excluded in `analysis_options.yaml:13-14`)

---

*Stack analysis: 2026-08-21*
