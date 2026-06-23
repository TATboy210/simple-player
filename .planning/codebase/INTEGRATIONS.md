# External Integrations

**Analysis Date:** 2026-06-23

## APIs & External Services

**Media Engine (fvp/MDK):**
- SDK: `fvp` ^0.37.2 (pub.dev package wrapping MDK SDK)
- Dart API: `package:fvp/mdk.dart` — `mdk.Player`, `mdk.PlaybackState`, `mdk.VideoEffect`, `mdk.MediaStatus`
- Native backend: FFmpeg (codec) + D3D11 (rendering on Windows)
- Entry point: `lib/kernel/engine/fvp_engine.dart` — `FvpEngine extends PlayerEngine`
- Texture rendering: `mdk.Player.textureId` → Flutter `Texture` widget
- Hardware decoders: D3D11 → NVDEC → FFmpeg (software fallback)
- Key MDK properties configured:
  - `d3d11.sync.cpu` (0=async, 1=sync)
  - `video.decoders` (decoder priority chain)
  - `avcodec.threads` (FFmpeg thread count, default 2)
  - `videoout.buffer_frames` (renderer buffer, default 3)
  - `avformat.probesize`, `avformat.analyzeduration` (stream probing)
  - `avformat.fflags`, `avformat.fpsprobesize`, `avformat.avioflags` (low-latency)
  - `subtitle.external`, `subtitle.delay` (subtitle control)
  - `video.avfilter` (yadif deinterlace)
  - `af` (audio equalizer filters)

**Player Engine Interface:**
- Package: `player_engine` (local path: `../widget_tree_flutter/player_engine`)
- Abstract class: `PlayerEngine` — defines full playback contract
- Key types: `MediaState`, `MediaInfo`, `MediaErrorType`, `VideoEffectType`, `AudioTrackInfo`, `SubtitleTrackInfo`, `VideoCodecInfo`
- Implementation: `FvpEngine` in `lib/kernel/engine/fvp_engine.dart`
- Test fake: `FakeEngine` in `test/helpers/fake_engine.dart`

**Window Manager:**
- Package: `window_manager` ^0.5.1
- Dart API: `package:window_manager/window_manager.dart` — singleton `windowManager`
- Features used: `ensureInitialized()`, `waitUntilReadyToShow()`, `show()`, `focus()`, `setSize()`, `setPosition()`, `center()`, `maximize()`, `unmaximize()`, `minimize()`, `close()`, `destroy()`, `startDragging()`, `setAlwaysOnTop()`, `isFullScreen()`, `setFullScreen()`, `getPosition()`, `getSize()`
- WindowListener callbacks: `onWindowMaximize`, `onWindowUnmaximize`, `onWindowResize`, `onWindowClose`
- Integration: `lib/kernel/bridge/window_service.dart` — `WindowService implements WindowBridge`

## FFI Bindings

**Win32 API (dart:ffi):**
- Library: `user32.dll` (loaded via `DynamicLibrary.open`)
- Location: `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`
- Functions bound:
  - `FindWindowW` — Find Flutter window by class name `FLUTTER_RUNNER_WIN32_WINDOW`
  - `GetWindowLongPtrW` — Read window style (GWL_STYLE)
  - `SetWindowLongPtrW` — Modify window style (remove WS_CAPTION, WS_THICKFRAME)
  - `SetWindowPos` — Atomic position+size+style refresh (SWP_FRAMECHANGED)
  - `GetSystemMetrics` — Screen dimensions (SM_CXSCREEN, SM_CYSCREEN)
- Constants: `_gwlStyle=-16`, `_wsCaption=0x00C00000`, `_wsThickframe=0x00040000`, `_swpFrameChanged=0x0020`
- Purpose: Bypass window_manager's setFullScreen() to fix 7px border gap (WS_THICKFRAME invisible frame)

**PlatformFullscreen Interface:**
- Location: `lib/kernel/bridge/platform_fullscreen.dart`
- Implementations:
  - `Win32PlatformFullscreen` — Win32 FFI (Windows, `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`)
  - `MacosPlatformFullscreen` — TODO (macOS, not yet implemented)
  - `LinuxPlatformFullscreen` — TODO (Linux, not yet implemented)
- Pattern: Enter returns `FullscreenSnapshot` (immutable), exit restores from snapshot

**D3D11 Configuration:**
- Location: `lib/kernel/engine/d3d11_configurator.dart`
- Indirect integration via MDK properties (not direct FFI)
- Configures: `d3d11.sync.cpu`, `video.decoders`

## Native Plugins

**fvp (MDK/FFmpeg):**
- Version: ^0.37.2
- Platform support: Windows, macOS, Linux, iOS, Android
- Windows: D3D11 texture rendering, hardware decoding
- Key integration: `lib/kernel/engine/fvp_engine.dart` (460+ lines)
- Prewarm: `lib/kernel/engine/engine_prewarm.dart` — Creates+destroys temp player to trigger FFmpeg codec registration and D3D11 context init
- Callback streams: `mdk.Player.onStateChanged`, `mdk.Player.onMediaStatus`
- Texture: `mdk.Player.textureId` (ValueNotifier<int?>) → Flutter `Texture` widget

**window_manager:**
- Version: ^0.5.1
- Platform support: Windows, macOS, Linux
- Dependencies: `screen_retriever` (for multi-monitor support)
- Key integration: `lib/kernel/bridge/window_service.dart`
- Mode: TitleBarStyle.hidden, windowButtonVisibility=false

**desktop_drop:**
- Version: ^0.7.1
- Platform support: Windows, macOS, Linux, Android
- Purpose: Drag-and-drop file support for media files
- Key integration: `lib/ui/player/drop_handler.dart` (referenced in CLAUDE.md)

**file_picker:**
- Version: ^11.0.2
- Platform support: All platforms
- Purpose: Native file open dialog for media file selection
- Extensions filter: `PathValidator.supportedExtensions` (24 video + 12 audio formats)

**shared_preferences:**
- Version: ^2.5.5
- Platform support: All platforms
- Purpose: Key-value persistence for app settings
- Integration: `lib/kernel/persistence/settings_store.dart` — 25+ keys
- Prewarm: `SettingsStore.prewarm(prefs)` in `main.dart` before `runApp()`

**path_provider:**
- Version: ^2.1.5
- Platform support: All platforms
- Purpose: Application support directory for playlist JSON files
- Integration: `lib/kernel/persistence/playlist_store.dart` — `getApplicationSupportDirectory()`

**file_selector:**
- Version: any
- Platform support: All platforms
- Purpose: Cross-platform file selection (alternative to file_picker)

**screen_retriever:**
- Version: (transitive via window_manager)
- Platform support: Windows, macOS, Linux
- Purpose: Multi-monitor detection, screen dimensions

## Data Storage

**SharedPreferences (key-value):**
- 25+ keys stored in `lib/kernel/persistence/settings_store.dart`
- Categories: window geometry, playback state, video effects, subtitle settings, performance settings, locale, theme, shortcuts
- Prewarmed in `main.dart` before `runApp()`

**JSON Files (playlist):**
- Location: Application support directory (`path_provider`)
- Files: `playlist.json`, `history.json` (legacy, auto-migrated)
- Write strategy: 300ms debounce + atomic write (.tmp → rename) + exponential backoff retry (3 attempts)
- Background loading: `Isolate.run()` for file I/O + JSON parsing
- Location: `lib/kernel/persistence/playlist_store.dart`

**File System:**
- `FolderScanner` (`lib/kernel/scanner/folder_scanner.dart`) — Non-recursive directory scan for video files
- 14 video extensions supported: mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Caching:**
- LRU memory cache for thumbnails (200 entries max) in `ThumbnailService` (`lib/kernel/services/thumbnail_service.dart`)
- Linux XDG thumbnail cache: `~/.cache/thumbnails/{size}/{md5(uri)}.png` in `LinuxThumbnailProvider`
- No persistent disk cache for thumbnails (platform OS cache only)

## Platform Channels

**Window Bridge (MethodChannel):**
- Channel name: `com.simple_player/window` (per CLAUDE.md)
- Interface: `WindowBridge` (`lib/kernel/bridge/window_bridge.dart`)
- Commands: `init()`, `setMode()`, `setAlwaysOnTop()`, `minimize()`, `close()`, `startDragging()`
- State: `ValueNotifier<WindowMode>`, `ValueNotifier<Size>`, `ValueNotifier<bool>` (isResizing, isAlwaysOnTop)
- Implementation: `WindowService` (`lib/kernel/bridge/window_service.dart`)
- Test fake: `FakeWindowService` (`test/helpers/fake_window_service.dart`)

**Win32 Runner (C++ → Flutter):**
- Location: `windows/runner/flutter_window.cpp`
- MessageHandler: Routes Win32 messages to Flutter engine (`HandleTopLevelWindowProc`)
- WM_FONTCHANGE: Triggers `ReloadSystemFonts()`
- COM: Initialized apartment-threaded in `main.cpp`
- Window class: `FLUTTER_RUNNER_WIN32_WINDOW`

## Authentication & Identity

**Auth Provider:** None — single-user desktop application, no authentication

## Monitoring & Observability

**Error Tracking:** None (no Sentry/Crashlytics)

**Logging:**
- Framework: `logger` ^2.5.0 with custom `PrefixPrinter`
- Module-scoped loggers: `log` (global), `logEngine`, `logBridge`, `logServices`, `logUi`
- Location: `lib/kernel/utils/log.dart`
- Debug: Console output with PrettyPrinter (colors, timestamps)
- Release: File output with rotation (`%APPDATA%\SimplePlayer\logs\`, 2MB rotation, 5 archives max)
- Release filter: Warning+ only (`ProductionFilter`)

**Memory Monitoring:**
- `MemoryMonitor` (`lib/kernel/utils/memory_monitor.dart`) — RSS tracking every 30s in debug builds
- Threshold: 50MB growth triggers warning log

**Performance Monitoring:**
- `PerfMonitor` (`lib/kernel/utils/perf_monitor.dart`) — Referenced but not explored in detail
- `Timeline.startSync`/`finishSync` used for fvp.open and fvp.seek profiling

## Localization

**Framework:** Flutter gen_l10n (ARB → Dart codegen)
- Config: `l10n.yaml` — ARB dir `lib/l10n`, template `app_en.arb`, output `AppLocalizations`
- Languages: English (en, default), Chinese (zh)
- Files: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_localizations.dart` (generated)
- Service: `LocaleService` (`lib/kernel/services/locale_service.dart`) — ValueNotifier<Locale>, persisted via SettingsStore

## Theming

**Service:** `ThemeService` (`lib/kernel/services/theme_service.dart`)
- 3 themes: Midnight (default), Ocean, Forest
- Accent colors stored in `ThemeService.accents`
- Current theme exposed as `ThemeService.I.currentTheme` (ThemeData)
- Persisted via `SettingsStore.saveThemeIndex()`

## CI/CD & Deployment

**Hosting:** Not applicable — local desktop application

**CI Pipeline:** None detected (no `.github/workflows`, no CI config)

**Build:**
- `flutter build windows` — Production build
- `flutter run -d windows` — Development run
- CMake handles native C++ compilation
- UTF-8 source compilation enabled (`/utf-8` flag in runner CMakeLists)

## MCP Integration

**Code Review Graph:**
- Config: `.mcp.json`
- Server: `code-review-graph` (Python executable)
- Purpose: Tree-sitter code analysis, 30 MCP tools for code understanding
- CWD: `D:\simple_player_flutter`

## External Tools

**DevTools Extensions:**
- `shared_preferences` extension enabled (`devtools_options.yaml`)

**Node.js Tooling:**
- `@opengsd/gsd-core` ^1.4.2 (dev tooling, `package.json`)
- Not part of the Flutter application

## V2 Architecture (Experimental)

**Location:** `v2/` directory
- Separate pubspec: `simple_player_v2`
- Different engine: mpv FFI (not fvp)
- Different fullscreen: `flutter_fullscreen` ^1.2.0
- Status: Archived (per MEMORY.md)

## Environment Configuration

**Required env vars:**
- None required for basic operation
- `APPDATA` — Used for log file storage in release builds (`%APPDATA%\SimplePlayer\logs\`)

**Secrets location:**
- `.env` file present — contains environment configuration (not read for security)
- No API keys or secrets required — local desktop application

## Supported Media Formats

**Video:** mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, ogv, vob
**Audio:** mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff
**Streaming:** http, https, rtmp, rtsp, srt, udp, tcp

---

*Integration audit: 2026-06-23*
