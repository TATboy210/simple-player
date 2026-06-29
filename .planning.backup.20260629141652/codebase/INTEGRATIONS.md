<!-- refreshed: 2026-06-26 -->
# External Integrations

## Platform Channels

| Channel | Platform | Methods | File |
|---------|----------|---------|------|
| `com.simple_player/fullscreen` | macOS | `enterFullscreen`, `exitFullscreen`, `getWindowRect` | `kernel/bridge/macos/macos_platform_fullscreen.dart` |
| `com.simple_player/window` | Linux | `getGtkWindowHandle` | `kernel/bridge/linux/linux_platform_fullscreen.dart` |

## Win32 FFI (user32.dll)

File: `lib/kernel/bridge/win32/win32_platform_fullscreen.dart`

Bound functions:
- `FindWindowW` — locate Flutter window by class `FLUTTER_RUNNER_WIN32_WINDOW`
- `GetWindowLongPtrW` / `SetWindowLongPtrW` — read/write GWL_STYLE
- `SetWindowPos` — atomic position+size+style refresh
- `MonitorFromWindow` / `GetMonitorInfoW` — multi-monitor support

FFI structs: `RECT`, `MONITORINFO`. Memory: `calloc`/`calloc.free` in `finally` blocks.

Styles manipulated: `WS_CAPTION` (0x00C00000), `WS_THICKFRAME` (0x00040000), `WS_VISIBLE` (0x10000000).

## GTK3 FFI (libgtk-3.so)

File: `lib/kernel/bridge/linux/linux_platform_fullscreen.dart`

Bound functions: `gtk_window_fullscreen`, `gtk_window_unfullscreen`, `gtk_window_get_size`, `gtk_window_get_position`.

Window handle obtained via MethodChannel `com.simple_player/window` -> `getGtkWindowHandle`, cached statically.

## Platform Fullscreen Abstraction

Interface: `PlatformFullscreen` (`lib/kernel/bridge/platform_fullscreen.dart`)

| Impl | Platform | Mechanism | requiresStyleSave |
|------|----------|-----------|-------------------|
| `Win32PlatformFullscreen` | Windows | FFI (user32.dll) | true |
| `MacosPlatformFullscreen` | macOS | MethodChannel | false |
| `LinuxPlatformFullscreen` | Linux | FFI (libgtk-3.so) + MethodChannel | false |

Pattern: `enter()` returns immutable `FullscreenSnapshot` for rollback; `exit()` restores from snapshot.

## Window Management

Interface: `WindowBridge` (`lib/kernel/bridge/window_bridge.dart`) — 4 state notifiers + 7 commands.

Impl: `WindowService` (`lib/kernel/bridge/window_service.dart`) — wraps `window_manager` singleton, listens to OS events (maximize/unmaximize/resize/close), debounce persistence via `WindowPersistence`.

## Media Engine (fvp/MDK)

Package: `fvp` ^0.37.2, API: `package:fvp/mdk.dart`

- `FvpEngine` (`kernel/engine/fvp_engine.dart`) implements `PlayerEngine` interface
- `EnginePrewarm` — startup pre-init (FFmpeg codec + D3D11 context)
- Texture rendering: `mdk.Player.textureId` -> Flutter `Texture` widget
- Hardware decoding: D3D11 -> NVDEC -> FFmpeg software fallback
- Key MDK properties: `d3d11.sync.cpu`, `video.decoders`, `video.avfilter`, `subtitle.external`

## File System

| Integration | Mechanism | Purpose |
|-------------|-----------|---------|
| SharedPreferences | Platform KV store | 25+ settings keys (window geometry, video prefs, locale, theme, shortcuts) |
| PlaylistStore | JSON + 300ms debounce + atomic write (.tmp + rename) | Playlist/history persistence with retry |
| FolderScanner | Directory scan, 14 video extensions | Non-recursive media discovery |
| ThumbnailService | LRU memory cache (200 entries) | Thumbnail caching with platform providers |

## Localization

- ARB files: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Generated: `AppLocalizations` (Flutter gen_l10n)
- Runtime: `LocaleService` with `ValueNotifier<Locale>`, persisted via SettingsStore

## Logging & Monitoring

- `logger` ^2.5.0 with module-scoped loggers (log, logEngine, logBridge, logServices, logUi)
- Release: file rotation (`%APPDATA%\SimplePlayer\logs\`, 2MB, 5 archives), Warning+ only
- `MemoryMonitor` — RSS tracking every 30s in debug, 50MB growth warning
- `PerfMonitor` — frame-level profiling via `Timeline.startSync`/`finishSync`

## No External APIs

Local desktop application. No cloud services, no auth, no external API calls. Network only for optional media streaming via MDK (http/https/rtmp/rtsp/srt/udp/tcp).
