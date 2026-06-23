# External Integrations

**Analysis Date:** 2026/06/23

## APIs & External Services

**Media Engine (fvp/MDK):**
- fvp (MDK/FFmpeg) — Video playback, decoding, rendering
  - SDK/Client: `fvp` package ^0.37.2 — `pubspec.yaml:16`
  - Interface: `PlayerEngine` abstract class — `package:player_engine/player_engine.dart` (local dependency at `../widget_tree_flutter/player_engine`)
  - Implementation: `FvpEngine` — `lib/kernel/engine/fvp_engine.dart`
  - Helpers:
    - `FvpCallbackHandler` — mdk callback registration, state mapping, main-thread dispatch (`lib/kernel/engine/fvp_callback_handler.dart`)
    - `PositionPoller` — Timer-based position polling (250ms steady) (`lib/kernel/engine/position_poller.dart`)
    - `TrackManager` — Audio/subtitle track selection and switching (`lib/kernel/engine/track_manager.dart`)
    - `MediaOpener` — Media file opening logic (`lib/kernel/engine/media_opener.dart`)
    - `D3d11Configurator` — D3D11 rendering pipeline configuration (`lib/kernel/engine/d3d11_configurator.dart`)
    - `NetworkConfigurator` — Network stream parameters (`lib/kernel/engine/network_configurator.dart`)
    - `VideoEffectController` — Video effects (brightness, contrast, hue, saturation) (`lib/kernel/engine/video_effect_controller.dart`)
    - `VolumeController` — Volume and mute control (`lib/kernel/engine/volume_controller.dart`)
    - `SubtitleConfigurator` — External subtitle and delay settings (`lib/kernel/engine/subtitle_configurator.dart`)
  - Auth: N/A (local playback + optional URL streams)
  - Network protocols: HTTP/HTTPS, RTSP, RTMP, SRT, UDP/TCP (with per-protocol low-latency config in `FvpEngine._configureNetworkOptions()`)

**Window Management:**
- window_manager ^0.5.1 — Cross-platform window control
  - SDK/Client: `window_manager` package — `pubspec.yaml:27`
  - Wrapper: `WindowService` — `lib/kernel/bridge/window_service.dart`
  - Events: `WindowListener` mixin for maximize/unmaximize/resize/close
  - Commands: setMode (fullscreen/maximized/windowed/minimized), setAlwaysOnTop, minimize, close, startDragging
  - Geometry persistence: `_saveGeometry()` writes position + size + maximized state to `SettingsStore`
  - Components:
    - `WindowState` — State container (mode, windowSize, isResizing, isAlwaysOnTop) (`lib/kernel/bridge/window_state.dart`)
    - `FullscreenController` — Atomic fullscreen + mutex + rollback (`lib/kernel/bridge/fullscreen_controller.dart`)
    - `WindowPersistence` — Debounced geometry persistence (`lib/kernel/bridge/window_persistence.dart`)
    - `WindowBridge` — Abstract interface for UI layer dependency (`lib/kernel/bridge/window_bridge.dart`)

**Win32 FFI (Fullscreen):**
- `Win32PlatformFullscreen` — Direct Win32 API calls for fullscreen control
  - File: `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`
  - DLL: `user32.dll` (DynamicLibrary.open)
  - Functions: `FindWindowW`, `GetWindowLongPtrW`, `SetWindowLongPtrW`, `SetWindowPos`, `GetSystemMetrics`
  - Purpose: Bypasses `window_manager.setFullScreen()` to properly handle WS_THICKFRAME (eliminates 7px border gap)
  - Interface: `PlatformFullscreen` — `lib/kernel/bridge/platform_fullscreen.dart`
  - Snapshot: `FullscreenSnapshot` — Immutable value object for rollback on failure

## Data Storage

**Key-Value Persistence (SharedPreferences):**
- SharedPreferences — App settings storage
  - Connection: Platform-specific (Windows Registry)
  - Client: `shared_preferences` ^2.5.5 — `pubspec.yaml:19`
  - Wrapper: `SettingsStore` — `lib/kernel/persistence/settings_store.dart`
  - Prewarm: `SettingsStore.prewarm()` caches instance in `main()` before `runApp()` to avoid repeated `getInstance()` I/O
  - Keys (~25): volume, lastFile, windowWidth/Height/X/Y, playMode, isMuted, isFullscreen, isAlwaysOnTop, isMaximized, subtitleFontSize/ColorIndex/BottomOffset, videoBrightness/Contrast/Saturation/Hue/Rotation/AspectRatio/Deinterlace, d3d11Sync, hardwareDecoding, locale, themeIndex, shortcuts
  - Validation: Input sanitization for window dimensions (NaN/Infinity/negative), coordinates (clamp -30000..30000), rotation angles (0/90/180/270 only)
  - Batch save: `saveAll()` uses sequential writes (not `Future.wait`) for data consistency

**JSON File Storage (Playlist):**
- Playlist persistence — Application support directory
  - Client: `path_provider` ^2.1.5 — `pubspec.yaml:17`
  - Location: `%APPDATA%/SimplePlayer/` (via `getApplicationSupportDirectory()`)
  - Files: `playlist.json`
  - Implementation: `PlaylistStore` — `lib/kernel/persistence/playlist_store.dart`
  - Features: Debounced writes, atomic file operations (.tmp + rename)

**File Storage:**
- Local filesystem — Media files (read-only access)
  - Open dialog: `file_picker` ^11.0.2 — `pubspec.yaml:18`
  - Drag-and-drop: `desktop_drop` ^0.7.1 — `pubspec.yaml:20`
  - Scanner: `FolderScanner` — `lib/kernel/scanner/folder_scanner.dart`
  - Supported formats: mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Caching:**
- In-memory LRU cache — Thumbnail images
  - Implementation: `ThumbnailService` — `lib/kernel/services/thumbnail_service.dart`
  - Capacity: 200 entries
  - Eviction: Least Recently Used (LinkedHashMap-based)
  - Platform-aware provider selection via `defaultTargetPlatform`

## Thumbnail System

**Platform Providers:**
- Windows: `NoopThumbnailProvider` — Returns null (thumbnails disabled) — `lib/kernel/services/noop_thumbnail_provider.dart`
- Linux: `LinuxThumbnailProvider` — XDG Thumbnail Factory (`~/.cache/thumbnails/{size}/{md5(uri)}.png`) — `lib/kernel/services/linux_thumbnail_provider.dart`
- macOS: `MacosThumbnailProvider` — Stub, returns null (TODO: QLThumbnailGenerator FFI) — `lib/kernel/services/macos_thumbnail_provider.dart`

**Interface:**
- `ThumbnailProvider` abstract class — `lib/kernel/services/thumbnail_provider.dart`
- `ThumbnailService` facade — `lib/kernel/services/thumbnail_service.dart`
  - Lazy platform detection via `defaultTargetPlatform`
  - LRU cache (200 entries) with `evict()` and `clearCache()` methods
  - `@visibleForTesting` reset/touch/cacheLength accessors

## Display Configuration

**Refresh Rate Detection:**
- `DisplayConfig` — `lib/kernel/bridge/display_config.dart`
  - Policy: 120Hz+ displays use async D3D11 sync (`'0'`), sub-120Hz use sync (`'1'`)
  - Current: Defaults to 60Hz (safe fallback), returns `'1'` (sync mode)
  - Used by: `FvpEngine._applyD3d11Defaults()` to set `d3d11.sync.cpu` property

## Windows Runner (C++)

**Entry Point:**
- `windows/runner/main.cpp` — Win32 message loop (`GetMessage`/`TranslateMessage`/`DispatchMessage`), COM initialization (`CoInitializeEx` with `COINIT_APARTMENTTHREADED`)
- `windows/runner/flutter_window.cpp` — Flutter view hosting, plugin registration, `WM_FONTCHANGE` handling
- `windows/runner/win32_window.cpp` — Win32 window class registration, DPI scaling, window creation
- `windows/runner/win32_window.h` — Win32Window class definition with `Create`, `Show`, `Destroy`, `SetChildContent`, `GetHandle`, `SetQuitOnClose`, `GetClientArea`

**Key Details:**
- Window visibility managed by `window_manager` Flutter plugin via `waitUntilReadyToShow` — C++ runner does NOT call `Show()` directly
- COM required for plugin system
- Build: CMake 3.14+, C++17, MSVC `/W4 /WX`, Unicode (`-DUNICODE -D_UNICODE`), UTF-8 source (`/utf-8`)
- Linker: `dwmapi.lib` (Desktop Window Manager API)

## Localization (l10n)

**Framework:**
- Flutter built-in localization with ARB files
- Config: `l10n.yaml`
- Generated output: `lib/l10n/app_localizations.dart`

**Supported Locales:**
- English (en) — `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_en.arb`
- Chinese (zh) — `lib/l10n/app_localizations_zh.dart`, `lib/l10n/app_zh.arb`

**Service:**
- `LocaleService` — `lib/kernel/services/locale_service.dart`
- Persistence: SharedPreferences key `locale`
- Default: `'zh'` (Chinese)
- Reactive: `ValueNotifier<Locale>` drives `MaterialApp.locale`

## Theme System

**Implementation:**
- `ThemeService` — `lib/kernel/services/theme_service.dart`
- 3 themes: Midnight, Ocean, Forest
- Persistence: SharedPreferences key `themeIndex`
- Design tokens: `lib/ui/theme/tokens.dart` — `Tokens.*` static constants (colors, spacing, radius, typography)
- Reactive: `AnimatedTheme` with 250ms duration wraps `MaterialApp`

## Logging

**Framework:**
- `logger` ^2.5.0 — `pubspec.yaml:21`
- Implementation: `lib/kernel/utils/log.dart`

**Module-Scoped Loggers:**
- `log` — Global logger (no prefix)
- `logEngine` — `[engine]` prefix
- `logBridge` — `[bridge]` prefix
- `logServices` — `[services]` prefix
- `logUi` — `[ui]` prefix

**Configuration:**
- Debug mode: Console output only (`PrettyPrinter`, colors enabled, no emojis)
- Release mode: Console + rotating file output
  - File location: `%APPDATA%/SimplePlayer/logs/app_<timestamp>.log`
  - Rotation: 2 MB max per file, keep 5 archives
  - Filter: `ProductionFilter` (warning+ level only)

## Startup Coordination

**Coordinator:**
- `StartupCoordinator` — `lib/kernel/startup/startup_coordinator.dart`
- Phases: `infrastructure` (engine prewarm), `settings` (locale/theme load), `ready`
- Progress: `ValueNotifier<StartupState>` drives `ProgressSplashScreen`
- Per-phase timing: Individual `Stopwatch` instances with structured timeline logging

**Pre-warming:**
- `EnginePrewarm` — `lib/kernel/engine/engine_prewarm.dart`
  - Creates temporary `mdk.Player()` to trigger FFmpeg codec registration + D3D11 context initialization
  - Fire-and-forget in `main()` — `lib/main.dart:29-35`
  - Idempotent: Safe to call multiple times (boolean guard)
  - Tier model: playerCreated, codecsReady, gpuReady, prewarmed
- `SettingsStore.prewarm()` — `lib/kernel/persistence/settings_store.dart:26`
  - Caches `SharedPreferences` instance before `runApp()` to avoid repeated platform I/O

## Memory Monitoring

**Debug-Only:**
- `MemoryMonitor` — `lib/kernel/utils/memory_monitor.dart`
  - Periodic RSS logging every 30 seconds (debug builds only)
  - Warning threshold: 50 MB growth since last reading
  - Uses `ProcessInfo.currentRss` from `dart:io`

## Environment Configuration

**Required env vars:**
- None — all configuration via runtime `SharedPreferences`

**Secrets location:**
- N/A — no external API keys or secrets

**Platform detection:**
- `defaultTargetPlatform` — Thumbnail provider selection
- `Platform.environment['APPDATA']` — Log file location (release builds)
- `Platform.environment['HOME']` — Linux thumbnail cache path

## Webhooks & Callbacks

**Incoming:**
- None — local-only application

**Outgoing:**
- None — no network communication (except optional URL/stream playback via fvp)

## CI/CD & Deployment

**Hosting:**
- Local Windows desktop application
- No server deployment

**CI Pipeline:**
- Not configured — manual build via `flutter build windows`

---

*Integration audit: 2026/06/23*
