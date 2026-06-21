# v2 Tech Stack

**Analysis Date:** 2026-06-19

## Languages

| Language | Files | Lines | Purpose |
|----------|-------|-------|---------|
| Dart | 21 | 1,562 | Application logic, UI, FFI bindings |
| C++ | 11 | 1,179 | Windows runner, mpv render plugin |
| YAML | 2 | 52 | Configuration |
| CMake | 4 | 307 | Build system |

## Runtime

- **Dart SDK:** ^3.11.5
- **Flutter SDK:** ^3.35.5
- **Platform:** Windows (primary), Linux/macOS (FFI paths exist)

## Dependencies

### Runtime (5)

| Package | Version | Purpose |
|---------|---------|---------|
| `ffi` | ^2.1.0 | FFI memory allocation helpers |
| `window_manager` | ^0.5.1 | Frameless window, resize, fullscreen |
| `flutter_fullscreen` | ^1.2.0 | Platform fullscreen API |
| `path` | ^1.9.1 | Cross-platform path manipulation |
| `flutter_lints` | ^6.0.0 | Lint rules (dev) |

### Dev (2)

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Widget/unit testing |
| `flutter_lints` | ^6.0.0 | Static analysis rules |

## Native Libraries

| Library | Version | Platform | Purpose |
|---------|---------|----------|---------|
| libmpv-2.dll | bundled | Windows | mpv media engine |
| ANGLE | system | Windows | OpenGL→D3D11 translation |

## mpv Configuration

Set in `MpvAdapter.init()`:
- `vo=libmpv` — video output via libmpv API
- `hwdec=auto` — hardware decoding
- `ao=wasapi` — Windows audio output
- `keep-open=yes` — keep player open after playback

## Observed Properties (mpv_observe_property)

| UserData | Property | Unit |
|----------|----------|------|
| 1 | time-pos | seconds → ms |
| 2 | duration | seconds → ms |
| 3 | volume | 0-100 |
| 4 | mute | bool |
| 5 | pause | bool |

## Build System

- **Dart/Flutter:** pubspec.yaml + flutter CLI
- **C++:** CMake (4 CMakeLists.txt files)
- **mpv plugin:** Separate CMake target in `windows/mpv_render_plugin/`

## Platform Requirements

| Requirement | Value |
|-------------|-------|
| Windows SDK | 10.0+ |
| Visual Studio | 2019+ (C++ desktop) |
| CMake | 3.15+ |
| libmpv | Windows x64 DLL |

---

*Stack analysis: 2026-06-19 — Understand-Anything project-scanner*
