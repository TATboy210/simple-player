<!-- refreshed: 2026-06-26 -->
# Technology Stack

## Runtime

| Component | Version | Notes |
|-----------|---------|-------|
| Flutter | 3.45.0-0.1.pre (beta) | Channel beta |
| Dart SDK | ^3.11.5 (installed: 3.13.0-103.1.beta) | Strict mode enabled |
| Material | Material 3 | Dark theme only (Midnight/Ocean/Forest) |

## Direct Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `fvp` | ^0.37.2 | MDK/FFmpeg video engine, D3D11 texture rendering |
| `player_engine` | removed (Phase 1) | Abstract PlayerEngine interface — now uses local relative imports |
| `window_manager` | ^0.5.1 | Cross-platform window control |
| `shared_preferences` | ^2.5.5 | Settings KV persistence (25+ keys) |
| `path_provider` | ^2.1.5 | App directory for playlist JSON |
| `file_picker` | ^11.0.2 | Native file open dialog |
| `file_selector` | any | Supplementary file selection |
| `desktop_drop` | ^0.7.1 | Drag-and-drop file import |
| `ffi` | ^2.1.0 | Dart FFI for Win32/GTK native calls |
| `path` | ^1.9.1 | Path manipulation |
| `crypto` | ^3.0.6 | Thumbnail cache key hashing |
| `logger` | ^2.5.0 | Structured logging with file rotation |
| `freezed_annotation` | ^3.1.0 | Immutable data classes |
| `json_annotation` | ^4.12.0 | JSON serialization |
| `xdg_directories` | any | Linux XDG paths |
| `animations` | any | Material motion transitions |
| `cross_file` | any | Cross-platform file abstraction |

## Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | sdk | Unit/widget tests |
| `integration_test` | sdk | E2E tests |
| `flutter_lints` | ^6.0.0 | Strict lint rules |
| `freezed` | ^3.2.5 | Code generation for data classes |
| `build_runner` | ^2.15.0 | Codegen runner |
| `pigeon` | any | Platform channel codegen |

## Analysis (analysis_options.yaml)

- Strict mode: `strict-casts`, `strict-inference`, `strict-raw-types`
- Error-level: `missing_required_param`, `missing_return`
- Key rules: `prefer_const_constructors`, `prefer_final_locals`, `avoid_print`, `unawaited_futures`

## Platform Targets

| Platform | Status | Native Layer |
|----------|--------|-------------|
| Windows | Primary | C++ runner, Win32 FFI (user32.dll) |
| Linux | Supported | GTK3 FFI (libgtk-3.so), C runner |
| macOS | Supported | MethodChannel (NSWindow) |

## Native Dependencies

- **fvp/MDK**: FFmpeg codecs + D3D11 GPU rendering + hardware decoding
- **Win32 API**: FFI to user32.dll (FindWindow, SetWindowPos, SetWindowLongPtr, MonitorFromWindow)
- **GTK3**: FFI to libgtk-3.so (gtk_window_fullscreen, gtk_window_get_size)
- **NSWindow**: MethodChannel for macOS fullscreen

## Build & Testing

- Build: `flutter build windows` / `flutter run -d windows`
- CMake for native C++ (C++17, /W4 /WX, UNICODE)
- Testing: flutter_test + integration_test, AAA pattern, 80%+ coverage target
- Fonts: Noto Sans SC (400/500/600) bundled in `assets/fonts/`

## State Management

- ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- Custom `ValueListenableBuilder2` and `MergedListenable` for composition
