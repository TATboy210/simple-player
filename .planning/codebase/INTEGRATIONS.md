# External Integrations

**Analysis Date:** 2026-07-03

## APIs & External Services

**Media Engine (fvp/MDK):**
- fvp 0.37.2 — FFmpeg + MDK media playback engine
- SDK/Client: `package:fvp/mdk.dart` (imported as `mdk`)
- Auth: None required (local library)
- Usage: `FvpEngine` creates `mdk.Player` instances for media decoding and D3D11 rendering
- Key files: `lib/kernel/engine/fvp_engine.dart`, `lib/kernel/engine/media_opener.dart`

**Network Streaming Protocols:**
- RTSP — Real-time streaming protocol (`rtsp://`)
- RTMP — Real-time messaging protocol (`rtmp://`)
- SRT — Secure reliable transport (`srt://`)
- HTTP/HTTPS — Standard web streaming (`http://`, `https://`)
- UDP/TCP — Raw transport protocols (`udp://`, `tcp://`)
- Configuration: `lib/kernel/engine/network_configurator.dart`
- URL validation: `lib/kernel/services/path_validator.dart`

## Data Storage

**Local Storage:**
- SharedPreferences — Key-value persistence
  - Connection: Platform-specific (Windows registry, Linux GSettings, macOS NSUserDefaults)
  - Client: `package:shared_preferences`
  - Key file: `lib/kernel/persistence/settings_store.dart`
  - Stores: volume, window geometry, play mode, subtitle settings, video effects, locale, theme

**Playlist Storage:**
- JSON files in `%APPDATA%/SimplePlayer/`
  - `playlist.json` — Current playlist state
  - `history.json` — Playback history
  - Client: `PlaylistStore` with 300ms debounce + atomic write (`.tmp` then rename)
  - Key file: `lib/kernel/persistence/playlist_store.dart`

**Debug Storage:**
- JSON files in `%APPDATA%/SimplePlayer/debug/`
  - `debug_<timestamp>.json` — Memory snapshots, probe data
  - Client: `DebugExporter`
  - Key file: `lib/kernel/utils/debug_exporter.dart`

**File Storage:**
- Local filesystem only — No cloud storage integration
- Video file scanning: `lib/kernel/scanner/folder_scanner.dart`
- Supported formats: mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Caching:**
- In-memory LRU cache for thumbnails (200 entries max)
  - Key file: `lib/kernel/services/thumbnail_service.dart`
- SharedPreferences prewarm cache at startup
  - Key file: `lib/kernel/persistence/settings_store.dart`

## Authentication & Identity

**Auth Provider:**
- None — Desktop application with no user accounts or authentication
- All data stored locally, no cloud sync

## Platform Integrations

**Windows Win32 API (via FFI):**
- `user32.dll` — Display enumeration (EnumDisplayMonitors, GetMonitorInfoW, MonitorFromWindow)
  - Key file: `lib/kernel/bridge/win32/win32_display_enumerator.dart`
- `dwmapi.dll` — Desktop Window Manager (DWMWA_WINDOW_CORNER_PREFERENCE)
  - Used via `window_manager` package
- Window management: `window_manager` package wraps Win32 window APIs
  - Key file: `lib/kernel/bridge/window_service.dart`

**Fullscreen Control:**
- `fullscreen_window` local package — Platform-specific fullscreen toggle
  - Windows: `FullscreenWindowPluginCApi`
  - Linux: `FullscreenWindowPlugin`
  - macOS: `FullscreenWindowPlugin`
  - Key file: `packages/fullscreen_window/`

**Global Hotkeys:**
- `hotkey_manager` package — System-wide media key registration
  - Scope: `HotKeyScope.system` (works when window is not focused)
  - Keys: MediaPlayPause, MediaTrackNext, MediaTrackPrevious
  - Key file: `lib/kernel/services/global_hotkey_service.dart`

**File Picker:**
- `file_picker` package — Native file open dialog
  - Key file: `lib/features/player/services/file_operations.dart`

**Drag and Drop:**
- `desktop_drop` package — Cross-platform file drag-and-drop
  - Key file: `lib/ui/player/drop_handler.dart`

## Thumbnail Providers

**Platform-Aware Thumbnail Service:**
- Facade pattern: `ThumbnailService` selects platform implementation
  - Windows: `NoopThumbnailProvider` (placeholder)
  - Linux: `LinuxThumbnailProvider` (xdg_directories)
  - macOS: `MacosThumbnailProvider`
  - Key files: `lib/kernel/services/thumbnail_service.dart`, `lib/kernel/services/thumbnail_provider.dart`

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, Crashlytics, or external error reporting)
- Errors logged via `logger` package with PrettyPrinter
- Error bus: `lib/features/player/services/player_error_bus.dart`

**Logging:**
- Framework: `logger` 2.7.0 with PrettyPrinter
- Module-scoped loggers: `log`, `logEngine`, `logBridge`
- Release mode: File output to `%APPDATA%/SimplePlayer/logs/` with 2 MB rotation
- Key file: `lib/kernel/utils/log.dart`

**Performance Monitoring:**
- `DebugProbe` — Lightweight operation timing (debug-only, tree-shaken in release)
  - Key file: `lib/kernel/utils/debug_probe.dart`
- `MemoryMonitor` — RSS memory sampling every 30 seconds (debug-only)
  - Key file: `lib/kernel/utils/memory_monitor.dart`
- `DebugExporter` — One-click diagnostics export
  - Key file: `lib/kernel/utils/debug_exporter.dart`

## CI/CD & Deployment

**Hosting:**
- Desktop application — No server deployment
- Distribution: MSIX package for Windows (`distribute_options.yaml`)

**CI Pipeline:**
- Not detected (no `.github/workflows/`, `.gitlab-ci.yml`, or similar)
- Manual build: `flutter build windows --release`

**Patching:**
- `scripts/apply_queryfence_patch.dart` — Auto-applies fvp performance patch
- Patch file: `patches/fvp_query_fence.patch.md`

## Environment Configuration

**No external API keys required:**
- This is a local desktop media player
- No cloud services, analytics, or external APIs
- All configuration via SharedPreferences (local key-value store)

**Compile-time defines:**
- `USE_MOCK_ENGINE=true` — Enables MockEngine for testing without fvp/FFmpeg dependencies

## Webhooks & Callbacks

**Incoming:**
- None — No server endpoints

**Outgoing:**
- None — No external API calls

## Network Protocols Supported

**Streaming (via FFmpeg):**
- HTTP/HTTPS — Standard web streaming
- RTSP — Real-time streaming protocol (low-latency config in `NetworkConfigurator`)
- RTMP — Real-time messaging protocol
- SRT — Secure reliable transport
- UDP/TCP — Raw transport protocols

**Configuration per protocol:**
- `lib/kernel/engine/network_configurator.dart` — Protocol-specific FFmpeg parameters
- Buffer ranges, probe sizes, and timeout values optimized per protocol

## External Libraries (Native)

**FFmpeg (via fvp):**
- Media decoding (video/audio codecs)
- Network streaming protocols
- Container format parsing
- Hardware acceleration: D3D11, NVDEC with FFmpeg fallback

**D3D11 (Direct3D 11):**
- GPU-accelerated video rendering
- Texture-based frame delivery to Flutter
- CPU-GPU sync mode (adaptive based on display refresh rate)
- Key file: `lib/kernel/engine/d3d11_configurator.dart`

**MDK (via fvp):**
- Media engine abstraction layer
- Player lifecycle management
- Track selection (audio/subtitle)
- Playback control (play, pause, seek, speed)

## Supported Media Formats

**Video Containers:**
mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Audio Formats:**
mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff

**Streaming Protocols:**
http, https, rtmp, rtsp, srt, udp, tcp

---

*Integration audit: 2026-07-03*
