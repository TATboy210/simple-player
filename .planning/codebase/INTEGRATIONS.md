# External Integrations

**Analysis Date:** 2026-05-30

## APIs & External Services

**Media Engine:**
- fvp (MDK/FFmpeg) — Video playback, decoding, rendering
  - SDK/Client: `fvp` package (^0.36.2) — `pubspec.yaml:14`
  - Interface: `MediaEngine` abstract class — `lib/kernel/engine/media_engine.dart`
  - Implementation: `FvpEngine` — `lib/kernel/engine/fvp_engine.dart`
  - Helpers: `FvpCallbackHandler`, `PositionPoller`, `TrackManager`
  - Auth: N/A (local playback)

**Window Management:**
- window_manager — Cross-platform window control
  - SDK/Client: `window_manager` package (^0.5.1) — `pubspec.yaml:25`
  - Interface: `WindowService` wrapper — `lib/kernel/bridge/window_service.dart`
  - Events: `WindowListener` mixin for maximize/fullscreen/resize

## Data Storage

**Key-Value Persistence:**
- SharedPreferences — App settings storage
  - Connection: Platform-specific (Registry on Windows)
  - Client: `shared_preferences` package (^2.5.5) — `pubspec.yaml:17`
  - Wrapper: `SettingsStore` — `lib/kernel/persistence/settings_store.dart`
  - Keys: ~25 keys (volume, mute, play mode, window geometry, video effects, locale, theme)
  - Validation: Input sanitization for window dimensions, coordinates, rotation angles

**JSON File Storage:**
- Playlist persistence — Application support directory
  - Client: `path_provider` package (^2.1.5) — `pubspec.yaml:15`
  - Location: `%APPDATA%/SimplePlayer/` (via `getApplicationSupportDirectory()`)
  - Files: `playlist.json`, `history.json` (legacy, auto-migrated)
  - Implementation: `PlaylistStore` — `lib/kernel/persistence/playlist_store.dart`
  - Features: 300ms debounced writes, atomic file operations (.tmp + rename), exponential backoff retry

**File Storage:**
- Local filesystem — Media files (read-only)
  - Access: `file_picker` for open dialog — `pubspec.yaml:16`
  - Access: `desktop_drop` for drag-and-drop — `pubspec.yaml:18`
  - Scanner: `FolderScanner` — `lib/kernel/scanner/folder_scanner.dart`
  - Supported formats: mp4, mkv, avi, mov, wmv, flv, webm, m4v, ts, rmvb, mpg, mpeg, 3gp, vob

**Caching:**
- In-memory LRU cache — Thumbnail images
  - Location: `ThumbnailService` — `lib/kernel/services/thumbnail_service.dart`
  - Capacity: 200 entries
  - Eviction: Least Recently Used (LRU)

## Win32 FFI Integration

**Native Bindings:**
- user32.dll — Window manipulation
  - Functions: `GetWindowLongPtrW`, `SetWindowLongPtrW`, `SetWindowPos`, `MonitorFromWindow`, `GetMonitorInfoW`, `GetWindowRect`
  - Implementation: `Win32Bindings` lazy singleton — `lib/kernel/bridge/win32_bindings.dart`

- dwmapi.dll — Desktop Window Manager
  - Functions: `DwmExtendFrameIntoClientArea`
  - Purpose: Window shadow preservation, fullscreen border removal

**Constants:**
- `gwlStyle` (-16) — Window style index
- `wsCaption` (0x00C00000) — Title bar style flag
- `wsPopup` (0x80000000) — Popup window style (fullscreen)
- `swpFrameChanged` (0x0020) — SetWindowPos flag for frame update

**Structs:**
- `Rect` — Window rectangle (left, top, right, bottom)
- `MonitorInfo` — Monitor info (rcMonitor, rcWork, dwFlags)
- `Margins` — DWM frame margins (left, right, top, bottom)

## Windows Runner (C++)

**Entry Point:**
- `windows/runner/main.cpp` — Win32 message loop, COM initialization
- `windows/runner/flutter_window.cpp` — Flutter view hosting
- `windows/runner/win32_window.cpp` — Win32 window class

**COM Initialization:**
- `CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)` — Required for COM-based features
- `CoUninitialize()` — Cleanup on exit

**Build System:**
- CMake 3.14+ — `windows/CMakeLists.txt`
- C++17 standard — `target_compile_features(${TARGET} PUBLIC cxx_std_17)`
- Unicode build — `add_definitions(-DUNICODE -D_UNICODE)`

## Thumbnail System

**Platform Providers:**
- Windows: `NoopThumbnailProvider` — Returns null (disabled) — `lib/kernel/services/noop_thumbnail_provider.dart`
- Linux: `LinuxThumbnailProvider` — Implementation present — `lib/kernel/services/linux_thumbnail_provider.dart`
- macOS: `MacosThumbnailProvider` — Stub — `lib/kernel/services/macos_thumbnail_provider.dart`

**Interface:**
- `ThumbnailProvider` abstract class — `lib/kernel/services/thumbnail_provider.dart`
- `ThumbnailService` facade — `lib/kernel/services/thumbnail_service.dart`
- LRU cache (200 entries) with platform-aware provider selection

## Localization (l10n)

**Framework:**
- Flutter built-in localization with ARB files
- Config: `l10n.yaml`
- Output: `lib/l10n/app_localizations.dart` (generated)

**Supported Locales:**
- English (en) — `lib/l10n/app_localizations_en.dart`
- Chinese (zh) — `lib/l10n/app_localizations_zh.dart`

**Service:**
- `LocaleService` — `lib/kernel/services/locale_service.dart`
- Persistence: SharedPreferences key `locale`
- Default: 'zh' (Chinese)

## Theme System

**Implementation:**
- `ThemeService` — `lib/kernel/services/theme_service.dart`
- 3 themes: Midnight, Ocean, Forest
- Persistence: SharedPreferences key `themeIndex`
- Design tokens: `lib/ui/theme/tokens.dart` — `Tokens.*` static constants

## Logging

**Framework:**
- `logger` package (^2.5.0) — `pubspec.yaml:19`
- Implementation: `lib/kernel/utils/log.dart`

**Configuration:**
- Debug mode: Console output only (`PrettyPrinter`)
- Release mode: Console + rotating file output
- File location: `%APPDATA%/SimplePlayer/logs/`
- Rotation: 2 MB max per file, keep 5 archives
- Format: `app_<timestamp>.log`

## Startup Coordination

**Coordinator:**
- `StartupCoordinator` — `lib/kernel/startup/startup_coordinator.dart`
- Phases: `infrastructure`, `settings`, `ready`
- Progress tracking: 0.0 → 1.0 per phase
- UI: `ProgressSplashScreen` driven by `ValueNotifier<StartupState>`

**Pre-warming:**
- `EnginePrewarm` — `lib/kernel/engine/engine_prewarm.dart`
  - Creates temporary `mdk.Player()` to trigger FFmpeg codec registration + D3D11 context init
  - Fire-and-forget in `main()` — `lib/main.dart:38-42`
  - Idempotent: Safe to call multiple times

- `SettingsStore.prewarm()` — `lib/kernel/persistence/settings_store.dart:26`
  - Caches `SharedPreferences` instance to avoid repeated `getInstance()` I/O

## Environment Configuration

**Required env vars:**
- None — all configuration via runtime `SharedPreferences`

**Secrets location:**
- N/A — no external API keys or secrets

**Platform detection:**
- `defaultTargetPlatform` — Used for thumbnail provider selection
- `Platform.environment['APPDATA']` — Used for log file location

## Webhooks & Callbacks

**Incoming:**
- None — local-only application

**Outgoing:**
- None — no network communication (except optional URL playback)

## CI/CD & Deployment

**Hosting:**
- Local Windows desktop application
- No server deployment

**CI Pipeline:**
- Not configured — manual build via `flutter build windows`

**Build Commands:**
```bash
flutter pub get                    # Install dependencies
flutter run -d windows             # Development run
flutter analyze                    # Static analysis
flutter test                       # Run tests
flutter build windows              # Release build
dart run build_runner build        # Code generation (freezed, json_serializable)
```

---

*Integration audit: 2026-05-30*
