# External Integrations

**Analysis Date:** 2026-05-09

## APIs & External Services

**None.** This is a standalone desktop media player with no external API calls, no network services, and no cloud dependencies. All functionality is local.

## Data Storage

**Key-Value Store (SharedPreferences):**
- Platform: Windows Registry / Linux filesystem / macOS UserDefaults
- Client: `shared_preferences` 2.5.5
- Implementation: `lib/kernel/persistence/settings_store.dart`
- Stores: window geometry, volume, mute state, play mode, subtitle prefs, video processing settings, locale, last opened file
- Prewarm pattern: `SettingsStore.prewarm(prefs)` called in `main()` before `runApp()` to avoid repeated `getInstance()` I/O

**JSON File Storage (Playlists):**
- Platform: `path_provider` application support directory
- Implementation: `lib/kernel/persistence/playlist_store.dart`
- Files: `playlist.json` (current playlist), `history.json` (legacy, auto-migrated on first load)
- Features: 300ms debounce write, atomic write (`.tmp` + rename), history migration on load
- Path: `{app_support_dir}/playlist.json`

**File Storage:**
- Local filesystem only. No cloud storage, no file sync.
- Media files accessed by absolute path (stored in playlist JSON)
- Path validation: `lib/kernel/utils/path_validator.dart` checks existence before open

**Caching:**
- None. No in-memory cache layer beyond SharedPreferences prewarm.

## Authentication & Identity

**Auth Provider:** None. No user accounts, no login, no authentication.

## Media Engine Integration

**fvp (MDK/FFmpeg):**
- Package: `fvp` 0.36.2 (`pubspec.yaml`)
- Registration: `fvp.registerWith()` in `lib/main.dart` (registers texture-based video player)
- Engine wrapper: `lib/kernel/engine/fvp_engine.dart` (implements `MediaEngine` interface)
- Native backend: MDK (Media Development Kit) which wraps FFmpeg
  - Windows: D3D11 hardware-accelerated rendering
  - Linux: OpenGL rendering
  - Decoders: h264_d3d11va, hevc_vaapi, etc. (hardware), ffmpeg software fallback
- Capabilities exposed: play/pause/stop, seek, volume, mute, playback rate (0.25x-4.0x), AB loop, audio track switching, subtitle track switching, external subtitle loading, subtitle delay, equalizer (FFmpeg af filters), video effects (brightness/contrast/saturation/hue), rotation (0/90/180/270), aspect ratio, deinterlace (yadif)
- Texture pipeline: `_player.updateTexture()` returns texture ID for Flutter `Texture` widget

**just_audio:**
- Package: `just_audio` 0.10.5 (`pubspec.yaml`)
- Purpose: Audio-only playback capability (supplementary to fvp)

## Window Management

**window_manager 0.5.1:**
- Package: pinned to exact version (not `^`)
- Implementation: `lib/kernel/platform/windows_platform_service.dart`, `lib/kernel/platform/linux_platform_service.dart`
- Features used: window geometry persistence, always-on-top, fullscreen toggle, title bar control
- Platform service pattern: abstract `PlatformService` (`lib/kernel/services/platform_service.dart`) with factory singleton, platform implementations registered in `main()`

**desktop_drop 0.7.1:**
- Drag-and-drop file support for desktop platforms
- Files dropped onto window are added to playlist

## Localization

**easy_localization 3.0.8:**
- Config: `l10n.yaml`
- ARB files: `lib/l10n/app_en.arb` (English), `lib/l10n/app_zh.arb` (Chinese)
- Generated code: `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_zh.dart`
- Default locale: `zh` (Chinese), persisted via `SettingsStore.saveLocale()`
- Supported locales: `en`, `zh`

## Monitoring & Observability

**Error Tracking:** None. No Sentry, Crashlytics, or remote error reporting.

**Logging:**
- Framework: `logger` 2.7.0
- Implementation: `lib/kernel/utils/log.dart` (global `log` instance)
- Config: PrettyPrinter, methodCount=0, no emojis, time-only datetime format
- Usage: `log.d()` for debug, `log.w()` for warning
- Pattern: try-catch blocks log errors via `log.d()` then set `errorMessage` ValueNotifier for UI display

## CI/CD & Deployment

**Hosting:** None. Desktop app distributed as platform-specific binaries.

**CI Pipeline (GitHub Actions):**
- `.github/workflows/ci.yml` - Runs on `windows-latest`:
  1. `flutter pub get`
  2. `dart analyze --fatal-infos`
  3. `flutter test`
  4. `dart format --set-exit-if-changed .`
- `.github/workflows/build-linux.yml` - Builds on `ubuntu-latest`:
  1. Install Linux deps (clang, cmake, ninja, GTK3, etc.)
  2. Analyze + test
  3. `flutter build linux --release`
  4. Generate icon PNGs from SVG (ImageMagick)
  5. Package as `SimplePlayer-linux-x64.tar.gz`
- `.github/workflows/build-macos.yml` - Builds on `macos-latest`:
  1. Analyze + test
  2. `flutter build macos --release`
  3. Create DMG via `create-dmg`

**Distribution:**
- Windows: Direct executable (no installer packaging detected)
- Linux: tar.gz with shell scripts (`packaging/linux/simple-player.sh`, `packaging/linux/install-desktop.sh`)
- macOS: DMG

## Environment Configuration

**Required env vars:** None. No environment variables needed.

**Secrets:** None. No API keys, tokens, or credentials.

**Compile-time config:** None. No `--dart-define` usage detected.

## Webhooks & Callbacks

**Incoming:** None.

**Outgoing:** None.

## Platform Native Code

**Windows:**
- C++ runner: `windows/runner/` (flutter_window.cpp, main.cpp, win32_window.cpp, utils.cpp)
- Build: CMake with MSVC, C++17, `/utf-8` flag for Chinese source comments
- Manifest: `runner.exe.manifest`

**Linux:**
- GTK-based runner (standard Flutter Linux template)
- Packaging: `packaging/linux/` with desktop entry, install script, icon generation

**macOS:**
- Standard Flutter macOS runner
- Packaging: DMG via create-dmg

---

*Integration audit: 2026-05-09*
