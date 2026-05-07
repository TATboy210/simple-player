# External Integrations

**Analysis Date:** 2026-05-07

## APIs & External Services

**None detected:**
- No external API calls, REST endpoints, or cloud services
- No HTTP client packages (no `dio`, `http`, or `grpc`)
- Pure local desktop application

## Data Storage

**Databases:**
- None (no SQL or NoSQL databases)

**File Storage:**
- Local filesystem via `path_provider` (`getApplicationSupportDirectory()`)
  - `playlist.json` - Playlist persistence with 300ms debounce, atomic write (.tmp + rename)
  - `history.json` - Legacy history file (auto-migrated to playlist.json on first load)
  - Location: `lib/kernel/persistence/playlist_store.dart`

**Key-Value Storage:**
- `shared_preferences` 2.5.5
  - Settings: volume, mute, window geometry, play mode, always-on-top, fullscreen
  - Video effects: brightness, contrast, saturation, hue, rotation, aspect ratio, deinterlace
  - Subtitle: font size, color index, bottom offset
  - Locale preference (zh/en)
  - Location: `lib/kernel/persistence/settings_store.dart`

**Caching:**
- In-memory only (`ValueNotifier` instances in `FvpEngine`)
- SharedPreferences instance prewarmed at startup (`SettingsStore.prewarm()`)
- Window geometry cached in `WindowManagerService` for fullscreen restore

## Authentication & Identity

**Auth Provider:**
- Not applicable (local desktop app, no user accounts)

## Media Engine Integration

**fvp/MDK:**
- SDK: `package:fvp` (Dart bindings for MDK/FFmpeg)
- Native backend: FFmpeg codecs + Windows D3D11 rendering
- Texture rendering: `_player.textureId` → Flutter `Texture` widget
- Callback system: `onStateChanged` + `onMediaStatus` streams
- Position polling: 250ms timer (`PositionPoller`)
- Properties: subtitle.external, subtitle.delay, af (equalizer), video.avfilter (deinterlace)
- Location: `lib/kernel/engine/fvp_engine.dart`, `lib/kernel/engine/fvp_callback_handler.dart`

**Supported Media Formats:**
- Video: mp4, mkv, avi, mov, flv, m4v, wmv, webm, ts, mpeg, mpg, 3gp, ogv
- Audio: mp3, flac, wav, aac, ogg, opus, m4a, wma, ape, alac, aiff
- Streaming: http://, https://, rtmp://, rtsp:// (URL validation in `PathValidator`)
- Location: `lib/kernel/services/path_validator.dart`

## Window Management

**window_manager 0.5.1:**
- Frameless window with custom title bar
- Fullscreen toggle (manual setSize + setPosition, not native setFullScreen)
- Always-on-top, minimize, maximize controls
- WindowListener callbacks for resize/move/close events
- Debounced persistence (500ms) for window geometry
- Bounds checking for multi-monitor → single-monitor scenarios
- Location: `lib/kernel/window/window_manager_service.dart`

**Platform Channel:**
- `com.simple_player/redraw` - Custom MethodChannel for forced redraw after frameless transition
- Location: `lib/kernel/window/window_manager_service.dart:44`

## File System Integration

**File Picker:**
- `file_picker` 11.0.2 - Native open dialog
- Extension filtering via `PathValidator.supportedExtensions`
- Location: Used in UI layer for file open actions

**Drag and Drop:**
- `desktop_drop` 0.7.1 - Desktop file drop support
- Files validated through `PathValidator` before processing
- Location: Used in UI layer for drag-to-play

## Localization

**i18n:**
- Framework: `flutter_localizations` (SDK)
- Implementation: ARB files in `lib/l10n/`
- Languages: English (`app_en.arb`), Chinese (`app_zh.arb`)
- Config: `l10n.yaml` (template: `app_en.arb`, preferred: `en`)
- Generated files: `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart`

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, Crashlytics, or similar)

**Logs:**
- `debugPrint()` throughout codebase (Flutter's debug-only logging)
- Error handling: try-catch with `debugPrint` + graceful fallback
- No production logging framework

## CI/CD & Deployment

**Hosting:**
- Local desktop application (no cloud deployment)

**CI Pipeline:**
- None detected (no `.github/workflows/`, no CI config files)

**Packaging:**
- Linux packaging scripts in `packaging/linux/` (install-desktop.sh, simple-player.sh)
- Windows: Standard Flutter Windows build

## Environment Configuration

**Required env vars:**
- None (no `.env` files, no environment variable usage)

**Secrets location:**
- Not applicable (no secrets, no API keys, no authentication)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

---

*Integration audit: 2026-05-07*
