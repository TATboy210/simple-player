# External Integrations

**Analysis Date:** 2026-08-21

## APIs & External Services

**Media Playback (libmpv via media_kit):**
- libmpv (bundled by `media_kit_libs_windows_video` 1.0.11) — the sole native media backend; no remote API, runs in-process
  - SDK/Client: `package:media_kit` 1.2.6 (`pubspec.yaml:17`)
  - Bridge: `MediaKitEngine implements MediaEngine` in `lib/kernel/engine/media_kit_engine.dart:34`
  - Event streams: `Player.stream.{position,duration,volume,rate,buffering,buffer,playing,completed,tracks,track,width,height,subtitle,error}` → project ValueNotifiers (`lib/kernel/engine/media_kit_engine.dart:508-583`)
  - Auth: None (local in-process library)

**Streaming URL Schemes (passed to libmpv, not fetched by Dart):**
- http://, https://, rtmp://, rtsp://, srt://, udp://, tcp:// — accepted by `PathValidator` and forwarded to `Player.open()` (`lib/kernel/services/path_validator.dart:53-61`, `lib/kernel/engine/media_kit_engine.dart:695-702`)
- No Dart-side HTTP client is used for these; dio 5.11.0 is declared but unused in `lib/`

**File Picker Attention (native platform channel):**
- MethodChannel `com.simple_player/file_picker_attention` — requests focus on an already-shown native file dialog
  - Client: `MethodChannelFilePickerAttention` in `lib/features/player/file_picker_adapters.dart:7-8,38-45`
  - Method: `focusExistingPicker` (`lib/features/player/file_picker_adapters.dart:43`)
  - Note: This is the **only** custom platform channel in the app; the legacy `com.simple_player/window` channel is deprecated and removed

## Data Storage

**Databases:**
- None (no SQL/Drift/sqflite/isar). A `ruvector.db` file exists at repo root but is unrelated tooling data, not referenced by `lib/`.

**File Storage:**
- Playlist JSON — `playlist.json` in `getApplicationSupportDirectory()`, atomic write via `.tmp` + rename, 300ms debounce, 3-retry exponential backoff (`lib/kernel/persistence/playlist_store.dart:23-123`)
- History migration — legacy `history.json` merged into playlist on load, then deleted (`lib/kernel/persistence/playlist_store.dart:192-229`)
- Debug export — `%APPDATA%/SimplePlayer/debug/debug_<timestamp>.json` (`lib/kernel/utils/debug_exporter.dart:37-49`)
- Local filesystem only — no cloud/object storage integration

**Caching:**
- In-memory LRU thumbnail cache — capacity 200 entries, LinkedHashMap with remove+reinsert touch (`lib/kernel/services/thumbnail_service.dart:18-125`)
- Platform thumbnail caches read-only (Linux XDG `~/.cache/thumbnails/{size}/{md5(uri)}.png` via `lib/kernel/services/linux_thumbnail_provider.dart:20-39`; macOS + Windows currently no-op, `lib/kernel/services/macos_thumbnail_provider.dart`, `lib/kernel/services/noop_thumbnail_provider.dart`)

**Preferences / Key-Value:**
- `shared_preferences` 2.5.5 — window geometry only (width/height/x/y/alwaysOnTop/maximized); keys prefixed `window*` (`lib/kernel/persistence/window_persistence.dart:37-42`)
- `flutter_secure_storage` 9.2.4 — declared in `pubspec.yaml:25` but **no direct usage in `lib/`**; reserved for future secret storage

## Authentication & Identity

**Auth Provider:**
- None — the app is a local single-user desktop media player with no login, accounts, or identity provider

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry/Crashlytics/Bugsnag). Errors flow through `KernelLoggerImpl` and `debugPrint` only.

**Logs:**
- Custom `KernelLogger` facade — 6 severity levels (trace/debug/info/warn/error/fatal), build-mode-gated sink selection (`lib/kernel/diagnostics/kernel_logger.dart:364-584`)
  - Debug: `CompositeSink([DebugPrintSink, DevToolsSink])` → `debugPrint` + `dart:developer.log(name: 'Kernel')`
  - Profile: `DevToolsSink` only
  - Release: `NullSink` (tree-shakeable, zero output)
  - Path redaction via `redactPath()` strips directory prefixes (`lib/kernel/diagnostics/kernel_logger.dart:126-132`)
- No remote log aggregation; logs stay local (DevTools console / stdout)

**Diagnostics (in-app):**
- `MemoryMonitor` — periodic RSS sampling (default 30s, threshold 50MB growth), `ProcessInfo.currentRss` via `RssProvider` abstraction (`lib/kernel/diagnostics/memory_monitor.dart:40-275`, `lib/kernel/diagnostics/rss_provider.dart`)
- `DebugProbe` / `DebugProbeRegistry` — timing probes for playback + playlistStore operations (`lib/kernel/utils/debug_probe.dart`)
- `VideoTextureResizeProbe` — correlates `VideoController.rect`/`textureId` with resize sessions, Debug/Profile only (`lib/kernel/diagnostics/video_texture_resize_probe.dart:18-40`)
- `StartupCoordinator` — per-phase stopwatch timing + structured timeline log (`lib/kernel/startup/startup_coordinator.dart:22-103`)
- `DebugExporter.exportAll()` — collects memory + probe summary to JSON file (`lib/kernel/utils/debug_exporter.dart:24-49`)

## CI/CD & Deployment

**Hosting:**
- Windows desktop MSIX package — `com.simpleplayer.app`, version `1.0.0.1`, `internetClient` capability (`pubspec.yaml:73-79`)
- Local install only; no app store upload configured

**CI Pipeline:**
- None detected in repo (no `.github/workflows/` CI files found for build/test despite `.github/` directory existing). Quality gates run locally: `flutter analyze`, `flutter test --coverage`.

## Environment Configuration

**Required env vars:**
- `HOME` — required on Linux for XDG thumbnail cache path resolution (`lib/kernel/services/linux_thumbnail_provider.dart:22-23`); not required on Windows (primary target)
- No other env vars consumed by `lib/` at runtime

**Secrets location:**
- No secrets managed. `flutter_secure_storage` is declared but unused; no API keys, tokens, or credentials exist in the app (local-only media player, no remote auth).

## Webhooks & Callbacks

**Incoming:**
- None (no HTTP server, no webhook endpoints)

**Outgoing:**
- None (no outbound HTTP calls from Dart; dio is declared but unused; streaming URLs are handed to libmpv which performs its own network I/O outside Dart's purview)

## Native Platform Bridges

**window_manager (Windows primary):**
- `WindowService implements WindowBridge` (`lib/kernel/window_Bridge/window_manager_service.dart:21`) wraps `window_manager` package
- Capabilities: `setPreventClose(true)` to intercept native close (`lib/kernel/window_Bridge/window_manager_service.dart:93`), `WindowOptions` with hidden title bar + transparent background + minimum size 854×513 (`lib/kernel/window_Bridge/window_manager_service.dart:94-99`, `lib/kernel/window_Bridge/window_constants.dart:7`)
- Listeners: `onWindowMaximize`/`onWindowUnmaximize`/`onWindowResize`/`onWindowClose` (`lib/kernel/window_Bridge/window_manager_service.dart:224-265`)
- Fullscreen is **not** driven by window_manager; media_kit's fullscreen semantics are synced back via `syncFullscreenState(bool)` (`lib/kernel/window_Bridge/window_bridge.dart:49`, `lib/kernel/window_Bridge/window_manager_service.dart:289-294`)

**media_kit native (libmpv FFI):**
- `MediaKit.ensureInitialized()` called at app startup (`lib/main.dart:20`) loads native libmpv
- `Player` + `VideoController` created in `MediaKitEngine` constructor (`lib/kernel/engine/media_kit_engine.dart:40-53`)
- No raw `dart:ffi`/`DynamicLibrary`/`lookupFunction` calls in `lib/` — all FFI is encapsulated inside the media_kit package

**Marionette (debug-only):**
- `MarionetteBinding.ensureInitialized()` replaces `WidgetsFlutterBinding` in `kDebugMode` (`lib/main.dart:14-18`) for VM-service-driven UI automation; MCP server `marionette` configured in `.mcp.json:12-22` runs `marionette_mcp` via `dart pub global run`

---

*Integration audit: 2026-08-21*
