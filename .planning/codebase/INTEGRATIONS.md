# External Integrations

**Analysis Date:** 2026-05-23

## APIs & External Services

**Media Engine (fvp/MDK):**
- fvp plugin wrapping MDK (FFmpeg-based media framework)
- SDK/Client: `package:fvp` (Dart bindings to native MDK library)
- Provides: `mdk.Player` for playback, D3D11 texture rendering, hardware decoding
- Integration point: `lib/kernel/engine/fvp_engine.dart`
- Registration: `fvp.registerWith()` in `lib/main.dart` with platform-specific decoder chain

**Network Streaming:**
- Supported via fvp/FFmpeg: HTTP/HTTPS, RTSP, RTMP, SRT, UDP, TCP
- Configuration: Network timeouts, probe sizes, buffer ranges set in `lib/kernel/engine/fvp_engine.dart`
- No external HTTP client — all network access through MDK's FFmpeg backend

## Data Storage

**Local Key-Value Store:**
- `SharedPreferences` — Primary persistence for all settings
  - Connection: Platform-native (Registry on Windows, files on Linux/macOS)
  - Client: `package:shared_preferences`
  - Used by: `SettingsStore` (`lib/kernel/persistence/settings_store.dart`), `WindowGeometryStore` (`lib/window/geometry_store.dart`)
  - Keys: volume, lastFile, window geometry, playMode, isMuted, locale, themeIndex, shortcuts, video effects, subtitle settings

**File-Based Storage:**
- `PlaylistStore` (`lib/kernel/persistence/playlist_store.dart`)
  - Location: `getApplicationSupportDirectory()` via `path_provider`
  - Files: `playlist.json` (current playlist), `history.json` (legacy, auto-migrated)
  - Format: JSON with 300ms debounce write, atomic write (.tmp + rename), exponential backoff retry

**Thumbnail Caching:**
- In-memory LRU cache (200 entries) in `ThumbnailService` (`lib/kernel/services/thumbnail_service.dart`)
- Platform-specific thumbnail sources:
  - Windows: COM FFI via `IShellItemImageFactory` (`lib/kernel/services/windows_thumbnail_provider.dart`)
  - Linux: XDG thumbnail cache (`~/.cache/thumbnails/{size}/{md5}.png`) (`lib/kernel/services/linux_thumbnail_provider.dart`)
  - macOS: Not implemented (returns null) (`lib/kernel/services/macos_thumbnail_provider.dart`)

**Caching:**
- No external cache service (Redis, Memcached, etc.)
- All caching is in-process: LRU thumbnail cache, `SharedPreferences` prewarm in `SettingsStore`

## Native Platform Integrations

**Windows Win32 FFI (via `dart:ffi`):**

| Integration | DLL | Purpose | File |
|-------------|-----|---------|------|
| Fullscreen control | user32.dll | WS_CAPTION/WS_THICKFRAME style, SetWindowPos, MonitorFromWindow | `lib/window/fullscreen_controller.dart` |
| Thumbnail extraction | shell32.dll, ole32.dll, gdi32.dll, user32.dll | COM IShellItemImageFactory for Explorer thumbnails | `lib/kernel/services/windows_thumbnail_provider.dart` |
| Window bridge | MethodChannel `com.simple_player/redraw` | ForceRedraw after frameless setup | `windows/runner/flutter_window.cpp` |

**Window Manager Plugin:**
- `window_manager` ^0.5.1 — Cross-platform window management
  - Used by: `WindowService` (Windows), `LinuxWindowService`, `MacosWindowService`
  - Operations: frameless mode, min/max/close, drag, fullscreen, always-on-top, size/position persistence
  - Files: `lib/window/window_service.dart`, `lib/window/linux_window_service.dart`, `lib/window/macos_window_service.dart`

**C++ Native Runner:**
- `windows/runner/flutter_window.cpp` — Hosts Flutter view, registers MethodChannel handler for `forceRedraw`
- `windows/runner/win32_window.cpp` — Base Win32 window class
- DWM integration: `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` in OnCreate for rounded corners

## Authentication & Identity

**Auth Provider:**
- Not applicable — standalone desktop application, no user accounts

## File System Access

**File Operations:**
- `FilePicker.pickFiles()` — Native file open dialog (`lib/app.dart`)
- `FolderScanner` — Directory listing for video files (`lib/kernel/scanner/folder_scanner.dart`)
- `desktop_drop` — Drag-and-drop file handling (`lib/ui/player/drop_handler.dart`)
- `dart:io` File — Direct file existence checks, playlist JSON read/write

**Supported File Extensions:**
- Video: mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob
- Audio: mp3, flac, wav, aac, ogg, wma, m4a

## Monitoring & Observability

**Error Tracking:**
- None — no Sentry, Crashlytics, or external error reporting

**Logs:**
- `debugPrint()` — Flutter's debug-only logging (stripped in release)
- `logger` package — Available but primarily `debugPrint` used throughout
- No structured logging or log aggregation

## CI/CD & Deployment

**Hosting:**
- Standalone desktop application — distributed as native binaries
- `packaging/` directory exists (not explored — likely installer config)
- `production/` directory exists (not explored)

**CI Pipeline:**
- Not detected in repository root (no `.github/workflows/`, no `Jenkinsfile`, no `azure-pipelines.yml`)

## Environment Configuration

**Required env vars:**
- None — all configuration via `SharedPreferences` at runtime
- Hardware decoder selection is automatic based on platform+architecture detection

**Secrets location:**
- Not applicable — no API keys, no external service credentials

## Webhooks & Callbacks

**Incoming:**
- MethodChannel `com.simple_player/redraw` — Dart triggers C++ `ForceRedraw` after frameless window setup (`windows/runner/flutter_window.cpp`)

**Outgoing:**
- None — no outbound webhooks or callbacks to external services

## Platform Bridge Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Dart (Flutter)                                          │
│  ├── FvpEngine ─── mdk.Player (fvp plugin)              │
│  ├── WindowService ── window_manager plugin              │
│  ├── AspectRatioService ── MethodChannel                 │
│  └── WindowsThumbnailProvider ─── COM FFI (shell32.dll) │
├─────────────────────────────────────────────────────────┤
│  C++ (windows/runner/)                                   │
│  ├── FlutterWindow ─── FlutterViewController             │
│  ├── MethodChannel `com.simple_player/redraw`            │
│  └── Win32Window ─── HWND message loop                   │
├─────────────────────────────────────────────────────────┤
│  Native Libraries                                        │
│  ├── MDK (via fvp) ─── FFmpeg + D3D11                   │
│  ├── user32.dll ─── Window management                    │
│  ├── shell32.dll ─── COM thumbnail extraction            │
│  └── gdi32.dll ─── Bitmap manipulation                   │
└─────────────────────────────────────────────────────────┘
```

## Dependency Injection Pattern

- `WindowService` uses static singleton: `WindowService.instance`
- `ThumbnailService` uses lazy platform dispatch with `_impl` singleton

---

*Integration audit: 2026-05-23*
