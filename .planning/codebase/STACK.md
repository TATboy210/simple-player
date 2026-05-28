# Technology Stack

**Analysis Date:** 2026-05-28

## Runtime

| Component | Version | Notes |
|-----------|---------|-------|
| Flutter | 3.44 beta | Desktop target (Windows) |
| Dart | 3.12 | Language version |
| fvp | 0.36.2 | MDK/FFmpeg plugin for video playback |
| MDK | (bundled in fvp) | Media engine backend |
| FFmpeg | (bundled in fvp) | Codec/decoding |

## Direct Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `fvp` | ^0.36.2 | Video playback engine (MDK/FFmpeg) |
| `window_manager` | ^0.5.0 | Window management (frameless, resize, fullscreen) |
| `file_picker` | ^10.2.0 | Native file open dialog |
| `desktop_drop` | ^0.6.0 | Drag-and-drop file support |
| `shared_preferences` | ^2.5.3 | Key-value persistence |
| `logger` | ^2.5.0 | Structured logging |
| `intl` | ^0.20.2 | Internationalization |
| `url_launcher` | ^6.3.1 | Open URLs in browser |
| `collection` | ^1.19.0 | Extended collection utilities |

## Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Test framework |
| `flutter_lints` | ^6.0.0 | Lint rules |
| `integration_test` | SDK | E2E test support (unused) |

## Build System

```bash
flutter pub get          # Install dependencies
flutter run -d windows   # Run on Windows
flutter analyze          # Static analysis
flutter test             # Run tests
flutter build windows    # Release build
```

**Platform:** Windows only (macOS/Linux planned)
**Build target:** `windows/x64`
**C++ standard:** C++17 (Windows runner)

## Rendering Pipeline

```
fvp plugin → MDK → D3D11 → Flutter Texture widget
```

- D3D11 hardware-accelerated rendering
- `updateTexture()` sync CPU/GPU (known bottleneck for 4K)
- `queryFence` patch must be reapplied after `flutter pub get` (modifies pub cache)

## Runtime Requirements

- **Windows 10+** (DWM APIs, dark mode support)
- **D3D11 GPU** (hardware video decoding)
- **FFmpeg codecs** (bundled in fvp/MDK)
- **Win32 APIs** (window management, COM thumbnails)

## Build Notes

- fvp `queryFence` patch: after `flutter pub get`, apply patch to fvp pub cache for D3D11 performance
- LNK4075 warning on fvp_plugin.vcxproj is expected (incremental linking)
- `flutter` CLI not in system PATH — use full path `D:\flutter\bin\flutter`
