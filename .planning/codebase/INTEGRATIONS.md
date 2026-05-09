# External Integrations

**Analysis Date:** 2026-05-09

## APIs & External Services

**None.** This is a standalone desktop media player with no external API calls, no network services, and no cloud dependencies. All functionality is local.

## Media Engine (Native FFI)

**fvp/MDK (FFmpeg wrapper):**
- Package: `fvp` ^0.36.2 (pub.dev)
- FFI binding: `package:fvp/mdk.dart` — exposes `mdk.Player` class
- Initialization: `fvp.registerWith()` in `lib/main.dart:14`
- Capabilities:
  - Hardware-accelerated decoding (D3D11 on Windows, OpenGL/VAAPI on Linux)
  - Audio/video/subtitle track management
  - Video effects (brightness, contrast, saturation, hue)
  - Deinterlacing (yadif filter via FFmpeg avfilter)
  - Equalizer (FFmpeg af filter strings)
  - External subtitle loading (.srt, .ass, .ssa, .vtt)
  - Subtitle delay adjustment
  - AB loop / range playback
  - Playback rate control (0.25x - 4.0x)
  - Video rotation (0/90/180/270)
  - Aspect ratio control
- Interface: `lib/kernel/engine/media_engine.dart` (abstract MediaEngine)
- Implementation: `lib/kernel/engine/fvp_engine.dart` (FvpEngine)
- Helpers:
  - `lib/kernel/engine/fvp_callback_handler.dart` — mdk callback → ValueNotifier mapping, main-thread scheduling
  - `lib/kernel/engine/position_poller.dart` — 250ms timer polling for playback position
  - `lib/kernel/engine/track_manager.dart` — audio/subtitle track switching

## Data Storage

**Key-Value (SharedPreferences):**
- Package: `shared_preferences` ^2.5.5
- Implementation: `lib/kernel/persistence/settings_store.dart`
- Pre-warmed: `SharedPreferences.getInstance()` called in `main()` and cached
- Stored values:
  - Volume (double, 0.0-1.0)
  - Last opened file path (String)
  - Window geometry: width, height, x, y (doubles)
  - Window state: isMaximized, isAlwaysOnTop, isFullscreen (bools)
  - Play mode (int, 0-3)
  - Is muted (bool)
  - Subtitle settings: fontSize, colorIndex, bottomOffset
  - Video processing: brightness, contrast, saturation, hue (doubles, -1.0 to 1.0)
  - Video rotation (int, 0/90/180/270)
  - Video aspect ratio index (int)
  - Video deinterlace (bool)
  - Locale code (String, default 'zh')

**File Storage (JSON):**
- Package: `path_provider` ^2.1.5 (application support directory)
- Playlist: `lib/kernel/persistence/playlist_store.dart`
  - File: `playlist.json` in app support directory
  - Format: JSON with playlist items, current index, play mode
  - Features: 300ms debounced writes, atomic write (.tmp + rename), concurrent write guard
  - History migration: one-time migration from legacy `history.json`
- No database — all persistence is flat files + key-value store

**File Storage (None):**
- No SQLite, Hive, or other database
- No cloud storage or file sync

## File System Integration

**File Picker:**
- Package: `file_picker` ^11.0.2
- Used for: Open file dialog (native OS file picker)
- Extension filter: 30+ video formats + 20+ audio formats (defined in `lib/kernel/utils/path_validator.dart`)

**Drag and Drop:**
- Package: `desktop_drop` 0.7.1
- Used for: Drag files onto the window to open them

**Path Validation:**
- `lib/kernel/utils/path_validator.dart` — Extension whitelist, path traversal detection (../, ..\, UNC, null bytes, ~)
- `lib/kernel/utils/path_utils.dart` — Cross-platform basename/dirname extraction

## Window Management

**window_manager:**
- Package: `window_manager` 0.5.1
- Platform plugin registered in `windows/flutter/generated_plugins.cmake`
- Capabilities: fullscreen toggle, always-on-top, window geometry save/restore
- Service abstraction: `lib/kernel/services/platform_service.dart` (abstract interface)
- Implementations:
  - `lib/kernel/platform/windows_platform_service.dart` — No-op (OS provides native decorations)
  - `lib/kernel/platform/linux_platform_service.dart` — No-op (GTK native window)

## Authentication & Identity

**None.** No authentication, no user accounts, no identity provider.

## Monitoring & Observability

**Error Tracking:** None (no Sentry, Crashlytics, etc.)

**Logging:**
- Package: `logger` ^2.7.0
- Singleton: `lib/kernel/utils/log.dart`
- Configuration: PrettyPrinter, methodCount=0, colors=true, no emojis, time-only timestamps
- Usage: `log.d()` throughout kernel layer for debug output
- Debug-only: Logger's default filter suppresses logs in release builds

## CI/CD & Deployment

**Hosting:** Self-distributed desktop app (no server deployment)

**CI Pipeline (GitHub Actions):**
- `.github/workflows/ci.yml` — Runs on `windows-latest`:
  - `flutter pub get`
  - `dart analyze --fatal-infos`
  - `flutter test`
  - `dart format --set-exit-if-changed .`
- `.github/workflows/build-linux.yml` — Runs on `ubuntu-latest`:
  - Full analyze + test + `flutter build linux --release`
  - Icon generation from SVG (ImageMagick)
  - Packages as `SimplePlayer-linux-x64.tar.gz`
- `.github/workflows/build-macos.yml` — Runs on `macos-latest`:
  - Full analyze + test + `flutter build macos --release`
  - Creates DMG via `create-dmg`
  - Packages as `SimplePlayer.dmg`

**Triggers:**
- CI: push/PR to `main` or `master`
- Build Linux/macOS: push to `main`, tags `v*`, PRs to `main`

## Localization

**Framework:**
- `easy_localization` 3.0.8 + `flutter_localizations` (SDK)
- Config: `l10n.yaml` (ARB-based, output: `AppLocalizations`)
- Supported locales: English (`app_en.arb`), Chinese (`app_zh.arb`)
- Default locale: `zh` (Chinese)
- Locale persistence: `SettingsStore.loadLocale()` / `saveLocale()`

## Native Platform Plugins

**Windows (`windows/flutter/generated_plugins.cmake`):**
- `desktop_drop` — Drag-and-drop
- `dynamic_color` — System accent color
- `fvp` — Media engine (FFmpeg/D3D11)
- `screen_retriever_windows` — Screen info (transitive, used by window_manager)
- `window_manager` — Window control
- `jni` — Java Native Interface (FFI plugin, transitive)

**Linux:**
- `fvp` — Media engine (FFmpeg/OpenGL)
- `desktop_drop` — Drag-and-drop
- `window_manager` — Window control

## Environment Configuration

**Required env vars:** None

**Secrets location:** None (no secrets, no API keys, no external services)

## Webhooks & Callbacks

**Incoming:** None

**Outgoing:** None

## Supported Media Formats

**Video (22 formats):**
mp4, mkv, avi, mov, flv, m4v, wmv, webm, ts, mpeg, mpg, 3gp, ogv, mts, m2ts, vob, rmvb, rm, f4v, divx, asf

**Audio (23 formats):**
mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff, dsf, dff, wv, tta, tak, ac3, dts, mka, oga, spx, amr, mid/midi

**Subtitle (7 formats):**
srt, ass, ssa, sub, vtt, idx, sup

**Streaming protocols:** http, https, rtmp, rtsp (URL playback supported)

---

*Integration audit: 2026-05-09*
