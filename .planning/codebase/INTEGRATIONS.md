# Integrations

**Analysis Date:** 2026-05-28

## fvp/MDK Engine

**Plugin:** `fvp` 0.36.2
**Interface:** `MediaEngine` (abstract) → `FvpEngine` (concrete)
**File:** `lib/kernel/engine/fvp_engine.dart` (633 lines)

### API Surface
- `open(path)` — Open media file or URL
- `play()` / `pause()` / `stop()` — Playback control
- `seekTo(ms)` — Position seeking
- `setVolume(0.0-1.0)` — Volume control
- `setRate(speed)` — Playback speed
- `setAudioTrack(index)` / `setSubtitleTrack(index)` — Track selection
- `updateTexture()` — D3D11 texture sync (per-frame)

### State Exposure
10+ ValueNotifiers for reactive UI binding:
- `state` (MediaState), `position`, `duration`, `volume`, `isMuted`
- `buffering`, `errorMessage`, `errorType`
- `audioTracks`, `subtitleTracks`

### Network Streams
- Supports RTSP, HTTP, HLS via FFmpeg
- Configurable timeouts: `_networkTimeoutMs`, `_prepareTimeoutSeconds`

## Win32 Runner (C++)

**File:** `windows/runner/main.cpp`
**Integration:** Flutter's default C++ runner with customizations

### Customizations
- `WM_NCCALCSIZE` — Frameless window (removes title bar chrome)
- `WM_NCHITTEST` — Custom hit testing for resize areas
- DWM dark mode preference (`DWMWA_USE_IMMERSIVE_DARK_MODE`)
- Rounded corner preference (`DWMWA_WINDOW_CORNER_PREFERENCE`)

### Window Manager Package
- `window_manager` handles cross-platform window operations
- No custom MethodChannel — all via package API
- Frameless mode, resize constraints, fullscreen toggle

## File System

### File Picker
- `file_picker` package for native open dialog
- Supports video file filtering

### Drag & Drop
- `desktop_drop` package for drag-drop onto window
- `DropHandler` widget wraps the player surface

### Folder Scanner
- `lib/kernel/scanner/folder_scanner.dart`
- Recursive directory scan for video files
- Extension-based filtering (mp4, mkv, avi, etc.)

## Thumbnail System

| Platform | Provider | Status |
|----------|----------|--------|
| Windows | `NoopThumbnailProvider` | **Disabled** — returns null |
| macOS | `MacosThumbnailProvider` | Stub — TODO: QLThumbnailGenerator FFI |
| Linux | `NoopThumbnailProvider` | Disabled |

**File:** `lib/kernel/services/thumbnail_service.dart`
**Note:** CLAUDE.md mentions "Win32 COM thumbnail extraction" but currently wired to NoopThumbnailProvider.

## SharedPreferences Persistence

**Package:** `shared_preferences` 2.5.3
**File:** `lib/kernel/persistence/settings_store.dart` (446 lines)

### Stored Keys (~24 keys)
- Volume, mute state, play mode
- Last played file, position
- Brightness, contrast, saturation (video processing)
- Audio/subtitle track preferences
- UI preferences (locale, theme)

## Localization (l10n)

**Framework:** `intl` + Flutter's built-in l10n
**Files:** `lib/l10n/` (ARB source + generated `AppLocalizations`)
**Locales:** en, zh (Chinese)
**Generated file:** `app_localizations.dart` (974 lines — auto-generated)

## Theme System

**Single theme:** Midnight (compile-time const)
**Tokens:** `lib/ui/theme/tokens.dart` — `Tokens.*` static constants
**Glass:** `GlassContainer` with `BackdropFilter` + `bgGlass` + `borderHighlight`

## Startup Sequence

1. `main()` — fvp init, window setup
2. `StartupCoordinator` — Phase-based initialization tracking
3. `EnginePrewarm` — Fire-and-forget `mdk.Player()` creation
4. `DeferredPlayerFeature` — Deferred loading of player UI
5. `PlaybackController` init — Service wiring

## No Custom MethodChannels

All platform integration uses third-party packages:
- `fvp` — engine (no custom channel)
- `window_manager` — window control
- `desktop_drop` — drag-drop
- `file_picker` — file dialogs
- `shared_preferences` — persistence
