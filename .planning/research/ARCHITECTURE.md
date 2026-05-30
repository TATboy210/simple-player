# Architecture Patterns

**Domain:** Flutter desktop media player (Windows)
**Researched:** 2026-05-31
**Confidence:** HIGH (based on direct codebase analysis + memory files)

---

## 1. C++ WM_NCCALCSIZE Integration

### Current State

The `flutter_window.cpp` is **stock Flutter template** -- only handles `WM_FONTCHANGE`. No custom `WM_NCCALCSIZE`, `WM_NCHITTEST`, or `WM_SIZING` handlers exist yet. The current frameless approach uses Dart-side FFI (`WindowService.removeBorderImmediate()`) which removes `WS_CAPTION` via `SetWindowLongPtr`, losing DWM animations.

### The Flutter Message Interception Problem

Documented in `anti_pattern_window_frameless.md` -- 3 previous C++ approaches all failed because:

```
Win32 message pipeline:
  WndProc -> FlutterWindow::MessageHandler
    -> flutter_controller_->HandleTopLevelWindowProc  <- Flutter may consume message
    -> custom handler  <- NEVER REACHED if Flutter consumed it
    -> Win32Window::MessageHandler  <- default processing
```

**Root cause:** `HandleTopLevelWindowProc` runs BEFORE custom handlers. If Flutter processes `WM_NCCALCSIZE` or `WM_NCHITTEST`, custom logic is bypassed.

### Correct Integration Pattern

**The handler MUST run BEFORE `HandleTopLevelWindowProc`.** This means restructuring `flutter_window.cpp`:

```cpp
LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  // Phase 1: Custom non-client handling BEFORE Flutter
  switch (message) {
    case WM_NCCALCSIZE:
      return OnNcCalcSize(hwnd, wparam, lparam);
    case WM_NCHITTEST:
      return OnNcHitTest(hwnd, wparam, lparam);
    case WM_SIZING:
      return OnSizing(hwnd, wparam, lparam);
    case WM_SIZE:
      return OnSize(hwnd, wparam, lparam);
  }

  // Phase 2: Let Flutter handle everything else
  if (flutter_controller_) {
    auto result = flutter_controller_->HandleTopLevelWindowProc(
        hwnd, message, wparam, lparam);
    if (result) return *result;
  }

  // Phase 3: Default handling
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
```

**Critical:** The `WM_NCCALCSIZE` handler must NOT set `WS_CAPTION` removal -- it must KEEP `WS_CAPTION` for DWM animations, and instead use the `WM_NCCALCSIZE` trick to collapse the non-client area to zero:

```cpp
LRESULT OnNcCalcSize(HWND hwnd, WPARAM wparam, LPARAM lparam) {
  if (wparam == TRUE) {
    auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
    // Keep client area = window area (no non-client border)
    params->rgrc[0] = params->rgrc[1];
    return 0;
  }
  return DefWindowProc(hwnd, WM_NCCALCSIZE, wparam, lparam);
}
```

**Why this works:**
- `WS_CAPTION` remains set -> DWM animations preserved
- `WM_NCCALCSIZE` collapses client area to fill entire window -> no visible title bar
- `WS_THICKFRAME` remains set -> native resize edges work
- DWM shadow preserved by `DwmExtendFrameIntoClientArea(0,0,1,0)`

### Integration with Existing WindowService

The C++ handler replaces the Dart-side `_removeBorder()` and `removeBorderImmediate()`. The flow becomes:

1. `CreateWindow` with `WS_OVERLAPPEDWINDOW` (full frame)
2. `OnCreate()` in `FlutterWindow` -- sets up MethodChannel, applies `WM_NCCALCSIZE` frameless
3. `ApplyRoundedCorners()` -- re-apply Win11 rounded corners
4. Dart-side `WindowService.init()` -- no longer calls `_removeBorder()`, only registers listeners

### New C++ Files/Changes

| File | Change | Lines (est.) |
|------|--------|--------------|
| `windows/runner/flutter_window.h` | Add handler methods + state fields | +20 |
| `windows/runner/flutter_window.cpp` | WM_NCCALCSIZE/NCHITTEST/SIZING/Size handlers | +80 |
| `windows/runner/win32_window.h` | Expose fullscreen state flag | +5 |
| `lib/kernel/bridge/window_service.dart` | Remove `_removeBorder()`, add MethodChannel commands | -30/+20 |

### Hit Test Zones (WM_NCHITTEST)

```
+--------------------------------------+
| HTCAPTION (drag area, top 36px)      |
+----+---------------------------+-----+
|    |                           |     |
| HT |   HTCLIENT (video area)   | HT  |
| LEFT|                          |RIGHT|
| 8px|                           |8px  |
|    |                           |     |
+----+---------------------------+-----+
| HTBOTTOMLEFT  HTBOTTOM  HTBOTRIGHT  |
|         8px resize edges            |
+--------------------------------------+
```

### Sizing Handler (WM_SIZING)

The existing `AspectRatioService` in Dart handles aspect ratio via MethodChannel. Moving this to C++ eliminates the MethodChannel round-trip during resize:

```cpp
LRESULT OnSizing(HWND hwnd, WPARAM wparam, LPARAM lparam) {
  auto rect = reinterpret_cast<RECT*>(lparam);
  if (aspect_ratio_ > 0) {
    ApplyAspectRatio(rect, wparam, aspect_ratio_);
  }
  EnforceMinSize(rect, min_width_, min_height_);
  return TRUE;
}
```

---

## 2. Platform Abstraction Layer

### Current Architecture

```
WindowBridge (abstract) <- lib/kernel/bridge/
  +-- WindowService (concrete) <- lib/kernel/bridge/window_service.dart
  +-- NoopWindowBridge (fallback) <- lib/kernel/bridge/
```

The `WindowService` currently:
- Uses `window_manager` package for init (ensureInitialized, setAsFrameless, setMinimumSize, show, focus)
- Uses Dart FFI (`win32_bindings.dart`) for runtime ops (fullscreen, maximize, minimize)
- Uses `WindowListener` mixin for events
- Persists geometry via `SettingsStore`

### Problem: Platform Coupling

The `WindowService` directly imports `window_manager` and `dart:ffi` + `win32_bindings.dart`. This makes it impossible to test without platform mocking and blocks macOS/Linux porting.

### Recommended Abstraction: PlatformService Interface

```dart
/// Platform-specific window operations.
///
/// Each platform provides one implementation:
/// - WindowsPlatformService (FFI + MethodChannel)
/// - MacOSPlatformService (NSWindow via MethodChannel)
/// - LinuxPlatformService (GTK via MethodChannel)
///
/// NoopPlatformService for testing.
abstract interface class PlatformService {
  // Lifecycle
  Future<void> init();
  void dispose();

  // Window state (ValueNotifier pattern -- matches existing)
  ValueNotifier<bool> get isFullscreen;
  ValueNotifier<bool> get isMaximized;
  ValueNotifier<bool> get isAlwaysOnTop;
  ValueNotifier<Size> get windowSize;

  // Window commands
  Future<void> setFullscreen(bool value);
  Future<void> maximize();
  Future<void> restore();
  Future<void> minimize();
  Future<void> close();
  Future<void> center();
  Future<void> startDragging();
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setSize(double width, double height);
  Future<void> setMinSize(double width, double height);
  Future<void> setAspectRatio(double ratio);
}
```

### Implementation Strategy

**Phase 1 (v1.2.1):** Extract interface only -- no macOS/Linux impl
- Create `PlatformService` abstract interface in `lib/kernel/platform/`
- Move `WindowService` to `lib/kernel/platform/windows_platform_service.dart`
- Inject via constructor in `main.dart`
- `NoopPlatformService` for tests

**Phase 2 (v2):** macOS/Linux stubs
- `MacOSPlatformService` using `MethodChannel` to native Cocoa
- `LinuxPlatformService` using `MethodChannel` to native GTK

### Singleton Migration

Current 6 static singletons to migrate:

| Singleton | Current | Target |
|-----------|---------|--------|
| `SettingsStore` | Static methods + `_cachedPrefs` | Instance with constructor injection |
| `WindowService` | Global `win32` bindings | Injected `PlatformService` |
| `DisplayConfig` | Static `_cachedHz` | Instance in `PlatformService` |
| `Win32Bindings` | `final win32 = Win32Bindings()` | Injected via `PlatformService` |
| `PathValidator` | Static methods | Keep static (pure utility, no state) |
| `WindowBootstrap` | Static methods | Keep static (init-only, no runtime state) |

**Migration pattern:**

```dart
// Before: static singleton
class SettingsStore {
  static SharedPreferences? _cachedPrefs;
  static void prewarm(SharedPreferences prefs) => _cachedPrefs = prefs;
  static Future<void> saveVolume(double value) async { ... }
}

// After: injectable instance
class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;
  Future<void> saveVolume(double value) async { ... }
}
```

### File Structure After Migration

```
lib/kernel/
+-- platform/
|   +-- platform_service.dart          <- abstract interface
|   +-- noop_platform_service.dart     <- test fallback
|   +-- windows/
|       +-- windows_platform_service.dart  <- FFI + MethodChannel
|       +-- win32_bindings.dart            <- FFI definitions (moved)
|       +-- display_config.dart            <- refresh rate detection
+-- bridge/
|   +-- window_bridge.dart             <- keep (DI entry point)
|   +-- window_bootstrap.dart          <- keep (init sequence)
+-- persistence/
|   +-- settings_store.dart            <- simplified (see below)
+-- ... (engine, models, services unchanged)
```

---

## 3. SettingsStore Simplification

### Current Problem

25+ individual `save*` methods, each wrapping `SharedPreferences` with try-catch:

```dart
static Future<void> saveVolume(double value) => _save('saveVolume', (p) => p.setDouble(_keyVolume, value.clamp(0.0, 1.0)));
static Future<void> saveLastFile(String path) => _save('saveLastFile', (p) => p.setString(_keyLastFile, path));
// ... 23 more methods
```

### Recommended: Generic Read/Write Pattern

```dart
class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  // Generic typed read
  T read<T>(String key, T defaultValue) {
    final value = _prefs.get(key);
    return (value is T) ? value : defaultValue;
  }

  // Generic typed write with validation
  Future<void> write<T>(String key, T value) async {
    try {
      switch (value) {
        case double v: await _prefs.setDouble(key, v);
        case int v: await _prefs.setInt(key, v);
        case String v: await _prefs.setString(key, v);
        case bool v: await _prefs.setBool(key, v);
      }
    } on Exception catch (e) {
      log.e('SettingsStore.write($key) failed: $e');
    }
  }

  // Domain-specific getters with validation (keep these)
  double get volume => read<double>('volume', 1.0).clamp(0.0, 1.0);
  set volume(double v) => write('volume', v.clamp(0.0, 1.0));

  // Batch save for atomic updates
  Future<void> saveAll(AppSettings s) async { ... }
}
```

**Benefits:**
- 25+ methods -> ~5 generic methods + property accessors
- Validation stays at the accessor level (domain knowledge preserved)
- `saveAll()` remains for atomic multi-key writes

---

## 4. HLS ABR Integration with fvp/MDK

### How FFmpeg HLS Works in fvp

fvp uses FFmpeg's built-in HLS demuxer (`hls.c`). When a `.m3u8` URL is opened:

1. FFmpeg fetches the master playlist
2. Parses variant streams (different bitrates)
3. Selects a variant (default: first/highest)
4. Downloads segments sequentially

**Current fvp config gap:** The `_configureNetworkOptions()` in `fvp_engine.dart` treats all HTTP URLs the same -- no HLS-specific buffering or ABR logic.

### Architecture: Where ABR Fits

```
+---------------------------------------------+
|  UI Layer                                    |
|  +-----------------+ +------------------+   |
|  | ABR indicator   | | Quality selector |   |
|  | (OSD pill)      | | (settings panel) |   |
|  +--------+--------+ +--------+---------+   |
+-----------+--------------------+-------------+
|  Kernel Layer                  |             |
|  +--------+--------------------+----------+  |
|  | AbrService (NEW)                       |  |
|  |  +-- BandwidthEstimator                |  |
|  |  +-- QualitySelector (BBA algorithm)   |  |
|  |  +-- SegmentMonitor                    |  |
|  +----------------+-----------------------+  |
|  +----------------+-----------------------+  |
|  | FvpEngine (MODIFIED)                   |  |
|  |  +-- _configureNetworkOptions()        |  |
|  |  +-- _configureHlsAbr()  <- NEW        |  |
|  |  +-- mdk.Player.setProperty(...)       |  |
|  +----------------------------------------+  |
+---------------------------------------------+
|  fvp/MDK                                     |
|  FFmpeg HLS demuxer -> variant selection      |
|  avformat.hls_* properties                   |
+---------------------------------------------+
```

### Key Conflict: Low-Latency vs ABR

| Parameter | Low-Latency (RTSP/RTMP) | ABR (HLS) | Resolution |
|-----------|------------------------|-----------|------------|
| `fflags +nobuffer` | Required | Harmful | Route by URL type |
| `setBufferRange(drop:true)` | Required | Harmful | Route by URL type |
| `demux.buffer.ranges` | 0-1 | 3+ | Route by URL type |
| `timeout` | 10s | 10s | Same |
| `probesize` | 1MB | 1MB | Same |

**Solution:** URL-type routing in `_configureNetworkOptions()`:

```dart
void _configureNetworkOptions(String url) {
  // Common settings
  _player.setProperty('timeout', _networkTimeoutMs.toString());
  _player.setProperty('avformat.probesize', _networkProbeSize.toString());

  if (_isHlsUrl(url)) {
    _configureHlsAbr(url);
  } else if (url.startsWith('rtsp://')) {
    _configureRtspLowLatency();
  } // ... etc
}

bool _isHlsUrl(String url) =>
    url.contains('.m3u8') || url.contains('/hls/');
```

### AbrService Design

```dart
class AbrService {
  AbrService(this._player);

  final mdk.Player _player;
  final _estimator = BandwidthEstimator(windowSize: 5);
  QualityLevel _currentQuality = QualityLevel.auto;

  /// Configure HLS ABR on the player
  void configure() {
    // Disable low-latency buffering
    // Let FFmpeg HLS demuxer manage buffering
    _player.setProperty('demux.buffer.ranges', '3');
    // Do NOT set fflags +nobuffer
    // Do NOT set drop:true
  }

  /// Called periodically with segment download metrics
  void onSegmentDownloaded(int bytes, Duration downloadTime) {
    _estimator.record(bytes, downloadTime);
    if (_currentQuality == QualityLevel.auto) {
      _selectQuality();
    }
  }

  void _selectQuality() {
    final bandwidth = _estimator.estimate();
    // BBA: select highest bitrate that fits in buffer
    // For now: simple throughput-based
    final level = _selectByThroughput(bandwidth);
    if (level != _currentQuality) {
      _player.setProperty('avformat.hls_prefer_list', level.name);
    }
  }
}
```

### MDK Properties for HLS ABR

| Property | Purpose | Example |
|----------|---------|---------|
| `avformat.hls_prefer_list` | Preferred quality variants | `'1080p:720p:480p'` |
| `protocol_whitelist` | Allowed protocols | `'file,http,https,tcp,tls'` |
| `demux.buffer.ranges` | Buffer depth for HLS | `'3'` |
| `avformat.allow_static_reoptimize` | Allow re-optimization | `'1'` |

**Note:** FFmpeg's HLS demuxer has built-in ABR via `hls_prefer_list`. For basic ABR, the application only needs to set the prefer list -- FFmpeg handles segment selection. For advanced ABR (BBA/MPC), the application needs to monitor buffer levels and override the prefer list dynamically.

### Integration Points

1. **FvpEngine._configureNetworkOptions()** -- add HLS branch
2. **New AbrService** -- bandwidth estimation + quality selection
3. **MediaEngine interface** -- add `ValueNotifier<AbrState> get abrState` (optional, for UI)
4. **SettingsStore** -- add ABR mode preference (auto/manual/off)

---

## 5. Build Order (Dependencies)

### Phase Dependency Graph

```
1. PlatformService interface + singleton migration
   | (no external dependency)
   v
2. C++ WM_NCCALCSIZE handler
   | (depends on PlatformService for Dart-side cleanup)
   v
3. Window layer simplification
   | (depends on C++ handler replacing Dart FFI)
   v
4. SettingsStore simplification
   | (independent, but easier after singleton migration)
   v
5. HLS ABR integration
   (independent of window work, but touches FvpEngine)
```

### Recommended Build Order

| Step | Task | Dependencies | Risk |
|------|------|-------------|------|
| 1 | Extract `PlatformService` interface | None | Low -- pure extraction |
| 2 | Migrate singletons to constructor injection | Step 1 | Medium -- touches many files |
| 3 | C++ `WM_NCCALCSIZE` handler | Step 1 (for Dart cleanup) | High -- Win32 API complexity |
| 4 | C++ `WM_NCHITTEST` handler | Step 3 | Medium -- hit zone tuning |
| 5 | C++ `WM_SIZING` aspect ratio | Step 3 | Medium -- 8-edge math |
| 6 | Remove Dart `_removeBorder()` | Steps 3-5 | Low -- deletion |
| 7 | Window layer file consolidation | Step 6 | Low -- reorganization |
| 8 | `SettingsStore` generic pattern | Step 2 | Low -- refactor |
| 9 | `AbrService` + HLS routing | None (independent) | Medium -- FFmpeg config |
| 10 | ABR UI integration | Step 9 | Low -- display only |

### Parallel Work Streams

- **Window stream:** Steps 1-7 (sequential, high risk)
- **Settings stream:** Step 8 (independent, low risk)
- **HLS stream:** Steps 9-10 (independent, medium risk)

Steps 8 and 9 can run in parallel with the window stream.

---

## Sources

- Codebase: `windows/runner/flutter_window.cpp`, `win32_window.cpp` (stock template)
- Memory: `anti_pattern_window_frameless.md` (3 failed approaches)
- Memory: `project_native_layer_interfaces.md` (MethodChannel contract)
- Memory: `project_bridge_layer_design.md` (bridge architecture)
- Memory: `project_hls_abr_plan.md` (ABR architecture + MDK properties)
- Memory: `reference_fvp_source_structure.md` (fvp internals)
- Memory: `reference_fvp_performance_bottlenecks.md` (rendering pipeline)
- Memory: `reference_desktop_embedder_api.md` (Flutter embedder API)
