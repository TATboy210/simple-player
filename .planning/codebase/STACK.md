# Technology Stack

**Analysis Date:** 2026-05-23

## Languages

**Primary:**
- Dart 3.11+ — All application logic, UI, services, persistence
- C++ — Windows native runner (`windows/runner/`), Win32 window management, MethodChannel bridge

**Secondary:**
- Win32 API via Dart FFI — Fullscreen control, thumbnail extraction, window style manipulation

## Runtime

**Environment:**
- Flutter SDK (Dart ^3.11.5)
- Targets: Windows desktop (primary), Linux desktop, macOS desktop

**Package Manager:**
- Flutter/Dart pub
- Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Flutter — UI framework, Material Design, localization
- fvp ^0.36.2 — Media playback engine wrapping MDK/FFmpeg, provides Texture rendering via D3D11

**Build/Dev:**
- flutter_lints ^6.0.0 — Lint rules (extends `package:flutter_lints/flutter.yaml`)
- flutter_test — Built-in test framework

## Key Dependencies

**Critical:**
- `fvp` ^0.36.2 — Core media engine. Wraps MDK (FFmpeg-based) with D3D11 texture rendering on Windows. Provides `mdk.Player` API for playback control, seeking, track management, video effects
- `window_manager` ^0.5.1 — Cross-platform window management (frameless, fullscreen, size/position, always-on-top). Used by `WindowService`, `LinuxWindowService`, `MacosWindowService`

**Infrastructure:**
- `shared_preferences` ^2.5.5 — Key-value persistence for settings (`SettingsStore`, `WindowGeometryStore`), locale, theme, shortcuts, window geometry
- `path_provider` ^2.1.5 — Application support directory for `PlaylistStore` JSON files
- `file_picker` ^11.0.2 — Native file open dialog for media file selection
- `desktop_drop` ^0.7.1 — Drag-and-drop file support on desktop platforms

**UI/UX:**
- `dynamic_color` ^1.8.1 — Material You dynamic color support (desktop)
- `widgets_easier` ^0.0.10 — Utility widgets
- `flutter_easy_animations` ^0.0.2 — Animation helpers

**Platform (Windows-specific):**
- `ffi` ^2.1.4 — Dart FFI for calling Win32 APIs directly (fullscreen, thumbnails, window styles)
- `win32` ^5.12.0 — Win32 API bindings (used alongside raw FFI for COM interop)
- `crypto` ^3.0.6 — MD5 hashing for XDG thumbnail cache lookup on Linux

**Utilities:**
- `path` ^1.9.1 — Cross-platform path manipulation
- `logger` ^2.5.0 — Structured logging

## Configuration

**Environment:**
- No `.env` files detected — all configuration via `SharedPreferences` at runtime
- Hardware decoder selection via `getOptimalDecoders()` in `lib/kernel/utils/platform_decoders.dart` — platform+architecture-aware decoder chain

**Build:**
- `analysis_options.yaml` — Extends `package:flutter_lints/flutter.yaml`
- `l10n.yaml` — Flutter localization config: ARB-based, template `app_en.arb`, generates `AppLocalizations`
- `pubspec.yaml` — Project config, fonts (Noto Sans SC), `generate: true` for l10n

## Platform Requirements

**Development:**
- Flutter SDK with desktop support enabled
- Windows: Visual Studio with C++ workload (for `windows/runner/` native code)
- Linux: GTK3 development headers
- macOS: Xcode

**Production:**
- Windows 10+ (D3D11 required for fvp texture rendering)
- Linux with VAAPI/VDPAU/NVDEC for hardware decoding
- macOS with VideoToolbox for hardware decoding

## Hardware Decoder Chains

Configured in `lib/kernel/utils/platform_decoders.dart`:

| Platform | ARM | x86_64 |
|----------|-----|--------|
| Windows | MFT:d3d=1, D3D11, FFmpeg | MFT:d3d=1, NVDEC, D3D11, FFmpeg |
| Linux | V4L2M2M, RKMPP, VAAPI, FFmpeg | VAAPI, VDPAU, NVDEC, FFmpeg |
| macOS | VT, FFmpeg | VT, FFmpeg |

## Supported Media Formats

**Video:** mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Audio:** mp3, flac, wav, aac, ogg, wma, m4a

**Streaming Protocols:** http/https, rtsp, rtmp, srt, udp, tcp (configured in `lib/kernel/engine/fvp_engine.dart`)

## Localization

- ARB-based (`lib/l10n/`): English (`app_en.arb`), Chinese (`app_zh.arb`)
- Default locale: `zh` (Chinese)
- Generated files: `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`

## Design System

- Single dark theme with 3 accent variants (Midnight/Ocean/Forest)
- Design tokens in `lib/kernel/ui/theme/tokens.dart` — `Tokens.*` static constants
- Glassmorphism: `BackdropFilter` + custom glass containers
- Font: Noto Sans SC (Regular/Medium/SemiBold) bundled in `assets/fonts/`

---

*Stack analysis: 2026-05-23*
