# External Integrations

**Analysis Date:** 2026-07-12

## APIs & External Services

**Media Playback (MDK/FFmpeg):**
- fvp (MDK) - Primary media playback engine
  - Dart API: `package:fvp/mdk.dart` (imported as `mdk`)
  - Capabilities: local file playback, network streaming (HTTP/HTTPS, RTSP, RTMP, SRT, UDP, TCP)
  - Hardware acceleration: D3D11 (Windows), NVDEC (NVIDIA GPU)
  - No authentication required - direct library calls via FFI

**Network Streaming Protocols:**
- RTSP/RTMP/SRT/UDP/TCP - Low-latency live stream support via `NetworkConfigurator`
  - Configured in `lib/kernel/engine/network_configurator.dart`
  - Protocol-specific tuning: buffer ranges, probe sizes, analysis duration
  - Adaptive buffering based on network latency

## Data Storage

**Databases:**
- None detected (no SQLite, Hive, Isar, or other database packages)

**Key-Value Persistence:**
- shared_preferences ^2.5.5
  - Used for: application settings, window geometry, locale, volume, playback preferences
  - Implementation: `lib/kernel/persistence/settings_store.dart`
  - Path: Platform-specific (Windows: `%APPDATA%\SimplePlayer\`)

**File Storage:**
- Playlist persistence: JSON files via path_provider (`lib/kernel/persistence/playlist_store.dart`)
- Log files: `%APPDATA%\SimplePlayer\logs\` with 2 MB rotation (`lib/kernel/utils/log.dart`)
- Font assets: `assets/fonts/NotoSansSC-*.ttf` (bundled, not downloaded)

**Caching:**
- Thumbnail LRU cache: `lib/kernel/services/thumbnail_service.dart` (in-memory, per-session)
- SharedPreferences prewarm cache: `lib/kernel/persistence/settings_store.dart`

## Authentication & Identity

**Auth Provider:**
- None - This is a local desktop media player with no user accounts or authentication

## Monitoring & Observability

**Error Tracking:**
- None external - errors logged locally via `logger` package

**Logging:**
- Framework: `logger` ^2.5.0 (`package:logger/logger.dart`)
- Implementation: `lib/kernel/utils/log.dart`
- Module-scoped loggers: `logEngine`, `logBridge` with PrefixPrinter
- Output: Console (debug), file rotation (release) at `%APPDATA%\SimplePlayer\logs\`
- Rotation: 2 MB max per file

**Performance Monitoring:**
- `lib/kernel/utils/perf_monitor.dart` - Frame timing, jank detection
- `lib/kernel/utils/memory_monitor.dart` - Memory usage tracking
- `lib/kernel/engine/engine_metrics.dart` - Engine-level performance counters
- `lib/kernel/engine/engine_event_log.dart` - Structured event logging

## CI/CD & Deployment

**Hosting:**
- Local desktop application (no cloud hosting)

**CI Pipeline:**
- None detected in repository

**Packaging:**
- Windows: MSIX via `msix` ^3.16.0 (`pubspec.yaml` msix_config section)
  - Display name: "Simple Player"
  - Identity: `com.simpleplayer.app`
  - Capability: `internetClient`
  - Logo: `windows/runner/resources/app_icon.ico`
- macOS: Standard Xcode project (`macos/Runner.xcodeproj/`)
- Linux: CMake build (`linux/CMakeLists.txt`)

## Environment Configuration

**Required env vars:**
- None - application is fully self-contained

**Compile-time configuration:**
- `USE_WINDOWS_NATIVE_FULLSCREEN` (bool, `--dart-define`)
  - Controls Windows fullscreen driver selection
  - `true`: Win32 FFI driver (`lib/kernel/bridge/win32/win32_fullscreen_ffi.dart`)
  - `false` (default): window_manager wrapper

**Runtime configuration:**
- All settings via SharedPreferences (`lib/kernel/persistence/settings_store.dart`)
- Window geometry persistence (`lib/kernel/bridge/window_persistence.dart`)

**Secrets location:**
- None - no API keys, tokens, or secrets in the codebase

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Platform Bridge (MethodChannel / FFI)

**Win32 FFI (direct Win32 API calls):**
- `lib/kernel/bridge/win32/win32_fullscreen_ffi.dart` - Fullscreen control (SetWindowPos, GetWindowLong, SetWindowLong, monitor enumeration)
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` - Multi-monitor enumeration (EnumDisplayMonitors, GetMonitorInfo)
- `lib/kernel/bridge/display_config.dart` - Display configuration queries

**MethodChannel (Flutter ↔ Native):**
- `lib/kernel/bridge/window_bridge.dart` - Window management commands (not directly using MethodChannel, but through window_manager package)
- `lib/kernel/bridge/platform/windows_fullscreen_driver.dart` - Windows fullscreen via window_manager
- `lib/kernel/bridge/platform/linux_fullscreen_driver.dart` - Linux fullscreen via window_manager
- `lib/kernel/bridge/platform/macos_fullscreen_driver.dart` - macOS fullscreen via window_manager

**Native Runner Code:**
- `windows/runner/main.cpp` - Win32 window creation and message loop
- `windows/runner/win32_window.cpp` - Win32 window class implementation
- `linux/runner/main.cc` - GTK application entry
- `macos/Runner/AppDelegate.swift` - macOS application delegate

---

*Integration audit: 2026-07-12*
