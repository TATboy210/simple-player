# Technology Stack: v1.2.1 Window Smoothness + HLS ABR + Platform Abstraction

**Project:** Simple Player Flutter
**Researched:** 2026-05-31
**Scope:** Stack additions/changes for window smoothness, HLS ABR, platform abstraction layer

## Executive Summary

**Zero new packages required for window smoothness and platform abstraction.** HLS ABR also needs zero new packages — FFmpeg's built-in HLS demuxer handles the heavy lifting, and BBA is a pure Dart algorithm. All three capabilities build on existing dependencies (`dart:ffi`, `window_manager`, `fvp`/MDK).

The critical insight: the previous window frameless attempts failed because they tried to handle `WM_NCCALCSIZE` AFTER Flutter's `HandleTopLevelWindowProc`. The correct approach is intercepting it BEFORE. For HLS ABR, the existing `_configureNetworkOptions` has a direct conflict with ABR buffering needs — the low-latency strategy (`+nobuffer`, `drop:true`) must NOT apply to HLS URLs.

## Actual Versions (from pubspec.yaml + memory)

| Package | Version | Role |
|---------|---------|------|
| Flutter SDK | 3.45.0-0.1.pre (beta) | Framework |
| Dart SDK | ^3.11.5 (resolved 3.13.0-103.1.beta) | Language |
| fvp | ^0.36.2 (0.37.0 available) | MDK/FFmpeg playback engine |
| window_manager | ^0.5.1 | Cross-platform window API |
| ffi | ^2.1.4 (resolved 2.2.0) | FFI support |
| shared_preferences | ^2.5.5 | Settings persistence |

---

## 1. Window Smoothness (WM_NCCALCSIZE + Fullscreen Animation)

### Problem

Current approach (`setFrameless(true)` via Dart) removes `WS_CAPTION`, which kills DWM maximize/restore animation, shadows, and Win11 rounded corners. Three C++ approaches were previously tried and all failed (see `anti_pattern_window_frameless.md`). The root cause: Flutter's `HandleTopLevelWindowProc` in `flutter_window.cpp` runs BEFORE custom message handling, consuming `WM_NCCALCSIZE` and `WM_NCHITTEST`.

### Solution: Intercept BEFORE Flutter

**The message flow in `flutter_window.cpp` is:**

```cpp
FlutterWindow::MessageHandler
  → flutter_controller_->HandleTopLevelWindowProc  // Flutter gets first shot
  → Win32Window::MessageHandler                     // custom handling (too late)
```

**The fix: handle `WM_NCCALCSIZE` BEFORE calling `HandleTopLevelWindowProc`:**

```cpp
// flutter_window.cpp — FlutterWindow::MessageHandler
LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  // --- NEW: Handle WM_NCCALCSIZE BEFORE Flutter sees it ---
  if (message == WM_NCCALCSIZE && wparam == TRUE) {
    auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
    // Keep the client area as-is — this hides the non-client frame
    // while preserving WS_CAPTION for DWM animation.
    // params->rgrc[0] already equals the window rect when we don't modify it.
    // DWM will still draw its frame transition animation.
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }
  // ... rest unchanged
}
```

**Why this works:** By returning 0 from `WM_NCCALCSIZE` before Flutter sees it, we prevent both Flutter and the default `DefWindowProc` from calculating non-client area. The window style still has `WS_CAPTION` (DWM animation dependency), but the caption area is zeroed out visually.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Where to handle WM_NCCALCSIZE | `flutter_window.cpp` MessageHandler, BEFORE Flutter | Flutter intercepts if handled after; previous failure documented |
| Window creation style | Keep `WS_OVERLAPPEDWINDOW` (default) | WS_CAPTION required for DWM animation pipeline |
| Border removal method | WM_NCCALCSIZE return 0 (not style manipulation) | Preserves DWM transitions, shadows, Win11 rounded corners |
| Shadow preservation | `DwmExtendFrameIntoClientArea(0,0,1,0)` | Top 1px lets DWM think window has a frame; already in `removeBorderImmediate()` |
| Fullscreen | Keep existing WS_POPUP + `SetWindowPos` approach | Already works correctly; DWM animation not needed for fullscreen enter/exit |
| Win11 rounded corners | `ApplyRoundedCorners()` after snap/maximize/restore | Already in `win32_window.cpp`; DWM resets corners during transitions |

### Win32 Frameless Best Practices (Verified from Project History)

1. **Never remove WS_CAPTION in the style** — it is the DWM animation trigger, not just a visual element
2. **Handle WM_NCCALCSIZE BEFORE Flutter's HandleTopLevelWindowProc** — otherwise Flutter consumes the message
3. **Keep WS_THICKFRAME** — needed for native resize support (drag edges)
4. **Use `DwmExtendFrameIntoClientArea(0,0,1,0)`** — preserves DWM shadow without visible frame
5. **`WM_ERASEBKGND` return 1** — prevents black flash during resize (already implemented)
6. **Window class style = 0** (no `CS_HREDRAW|CS_VREDRAW`) — prevents full repaint on resize (already implemented)
7. **`MoveWindow(FALSE)`** in `WM_SIZE` — defers repaint to DWM composition, eliminates tearing (already implemented)
8. **`SWP_NOOWNERZORDER | SWP_FRAMECHANGED`** on `SetWindowPos` — forces DWM to recalculate frame

### Files to Modify

| File | Change | Risk |
|------|--------|------|
| `windows/runner/flutter_window.cpp` | Add WM_NCCALCSIZE handler before HandleTopLevelWindowProc | MEDIUM — message pipeline change |
| `windows/runner/win32_window.cpp` | Remove `setFrameless` from Dart init (no longer needed) | LOW |
| `lib/kernel/bridge/window_service.dart` | Remove `removeBorderImmediate()` style manipulation; keep DWM margins | LOW — simplification |
| `lib/kernel/bridge/win32_bindings.dart` | Add `NCCALCSIZE_PARAMS` struct if not present | LOW — FFI type |

### What NOT to Do

| Anti-Pattern | Why Not | Documented In |
|-------------|---------|---------------|
| Remove WS_CAPTION via SetWindowLongPtr | Kills DWM animation, shadows, rounded corners | anti_pattern_window_frameless.md |
| Handle WM_NCCALCSIZE after HandleTopLevelWindowProc | Flutter consumes the message first | anti_pattern_window_frameless.md |
| Mix style manipulation + WM_NCCALCSIZE | Conflicting state, unpredictable behavior | anti_pattern_window_frameless.md |
| Use window_manager's `setFullScreen()` | Keeps WS_CAPTION visible border | window_service.dart comment |
| Modify C++ runner for DwmFlush/timeBeginPeriod | Platform hacks belong in plugin, not runner | project_window_anti_patterns.md |

### Confidence: MEDIUM

The WM_NCCALCSIZE-before-Flutter approach is theoretically correct and addresses the documented root cause. However, it has not been tested in this codebase. The risk is that Flutter's `HandleTopLevelWindowProc` might still interfere even when `WM_NCCALCSIZE` is consumed earlier, or that DPI scaling introduces the 1-2px offset seen in the previous `WM_NCCALCSIZE` attempt. Test on both 100% and 150% DPI scaling.

---

## 2. HLS Adaptive Bitrate Streaming (BBA Algorithm)

### Problem

The existing `_configureNetworkOptions()` in `fvp_engine.dart` applies low-latency settings (`+nobuffer`, `setBufferRange(drop:true)`) to ALL URLs. This directly conflicts with ABR needs: ABR requires buffer accumulation for bandwidth measurement and smooth quality transitions. Additionally, FFmpeg's built-in HLS demuxer supports basic ABR, but fine-grained control (BBA algorithm) requires application-level implementation.

### Architecture: FFmpeg Demuxer + Dart BBA Controller

```
                    ┌─────────────────────────────┐
                    │     AbrController (Dart)     │
                    │  ┌───────────────────────┐   │
                    │  │  BandwidthEstimator   │   │
                    │  │  (EWMA sliding window)│   │
                    │  └───────────┬───────────┘   │
                    │              ▼               │
                    │  ┌───────────────────────┐   │
                    │  │  BbaQualitySelector   │   │
                    │  │  (buffer-based logic) │   │
                    │  └───────────┬───────────┘   │
                    │              ▼               │
                    │  ┌───────────────────────┐   │
                    │  │  HlsVariantParser     │   │
                    │  │  (master.m3u8 parse)  │   │
                    │  └───────────────────────┘   │
                    └─────────────┬───────────────┘
                                  │ setProperty() / setBufferRange()
                                  ▼
                    ┌─────────────────────────────┐
                    │      FvpEngine (MDK/FFmpeg)  │
                    │  FFmpeg hls.c demuxer        │
                    │  + configurable properties   │
                    └─────────────────────────────┘
```

### BBA Algorithm (Buffer-Based Approach)

BBA maps buffer occupancy to quality levels using two thresholds (`b_l` and `b_u`):

```
Buffer level:
  0        b_l       b_u       max
  |--------|---------|---------|
  | Rebuffer| Maintain | Fill up  |
  | min(q)  | current  | max(q)   |

Decision:
  if buffer < b_l: switch to LOWEST quality (prevent rebuffer)
  if buffer > b_u: try next HIGHER quality (buffer headroom)
  else: MAINTAIN current quality
```

**Why BBA over throughput-based:** Throughput estimation is noisy on desktop (WiFi fluctuation, background downloads). BBA is more stable because it reacts to actual buffer health, not instantaneous bandwidth. The original paper (Huang et al., 2014) showed BBA outperforms throughput-based in QoE metrics.

**Why BBA over MPC:** MPC (Model Predictive Control) requires future bandwidth prediction and chunk download time modeling. BBA is simpler, requires no prediction, and is sufficient for a desktop player where network conditions are relatively stable compared to mobile.

### MDK/FFmpeg HLS Configuration

FFmpeg's `hls.c` demuxer has built-in variant selection, controlled via `avformat.*` properties:

```dart
// HLS-specific configuration (replaces low-latency settings)
void _configureHlsOptions(String url) {
  // Buffer settings — ABR needs buffer accumulation, NOT low-latency
  _player.setProperty('demux.buffer.ranges', '3');           // wider buffer
  // Do NOT set fflags +nobuffer
  // Do NOT set setBufferRange(drop:true)

  // FFmpeg HLS demuxer properties
  _player.setProperty('avformat.probesize', '5000000');      // 5MB for HLS
  _player.setProperty('avformat.analyzeduration', '10000000'); // 10s analysis
  _player.setProperty('protocol_whitelist', 'file,http,https,tcp,tls,hls');

  // Disable FFmpeg's built-in ABR — Dart BBA will control quality
  // by manipulating the variant playlist URL selection
  _player.setProperty('avformat.hls_prefer_list', '');       // no preference
}
```

**Key insight:** FFmpeg's HLS demuxer can be told which variant to play via URL manipulation. The Dart BBA controller selects the variant URL and feeds it to `FvpEngine.open()`. For finer control, MDK's `setBufferRange` API can be used to influence the demuxer's buffering behavior.

### Quality Variant Parsing

HLS master playlists list available variants:

```
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
stream_360.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
stream_720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
stream_1080.m3u8
```

Parsing this is pure Dart — no package needed. `http` or `dio` package could help, but the project already uses `fvp` which handles HTTP internally. For the initial implementation, use `dart:io`'s `HttpClient` to fetch the master playlist, parse variants, then feed the selected variant URL to `FvpEngine.open()`.

### Bandwidth Estimation: EWMA

Exponentially Weighted Moving Average over chunk download times:

```dart
class BandwidthEstimator {
  double _ewma = 0;
  static const _alpha = 0.3; // smoothing factor

  void addSample(int bytesDownloaded, Duration downloadTime) {
    final bps = bytesDownloaded * 8 / downloadTime.inSeconds;
    _ewma = _alpha * bps + (1 - _alpha) * _ewma;
  }

  double get bandwidthBps => _ewma;
}
```

### Integration with FvpEngine

The BBA controller needs access to buffer level from MDK. The existing `buffered` ValueNotifier on `FvpEngine` provides buffered position in milliseconds. This is sufficient for BBA buffer-occupancy decisions.

```dart
// In AbrController
void _onBufferUpdate() {
  final bufferLevelMs = _engine.buffered.value - _engine.position.value;
  final bufferLevelSec = bufferLevelMs / 1000.0;

  if (bufferLevelSec < _bLow) {
    _switchToLowest();
  } else if (bufferLevelSec > _bHigh) {
    _tryHigherQuality();
  }
  // else maintain current
}
```

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/kernel/services/abr_controller.dart` | NEW | BBA algorithm, bandwidth estimator, quality selector |
| `lib/kernel/models/hls_variant.dart` | NEW | Quality variant data model (resolution, bandwidth, url) |
| `lib/kernel/engine/fvp_engine.dart` | MODIFY | Route `.m3u8` URLs to `_configureHlsOptions` instead of `_configureNetworkOptions` |
| `lib/kernel/services/path_validator.dart` | MODIFY | Add `isHls()` detection (`.m3u8` in URL) |

### What NOT to Add

| Tempting Package | Why Not |
|-----------------|---------|
| `dio` / `http` | Only need to fetch master.m3u8 once; `dart:io` HttpClient suffices |
| `hls_parser` | HLS playlist format is simple enough to parse in 50 lines of Dart |
| `connectivity_plus` | Bandwidth estimation from chunk downloads is more accurate than network type |
| Custom FFmpeg demuxer | FFmpeg's hls.c is battle-tested; only need to configure it, not replace it |

### Implementation Phases

| Phase | Scope | Days |
|-------|-------|------|
| 1 | HLS URL detection + `_configureHlsOptions` routing | 0.5 |
| 2 | Master.m3u8 parser + variant model | 0.5 |
| 3 | BBA algorithm (buffer thresholds + quality selection) | 1 |
| 4 | BandwidthEstimator (EWMA) | 0.5 |
| 5 | AbrController integration with FvpEngine.buffered | 1 |
| 6 | Quality switch (open new variant URL on switch) | 0.5 |

**Total: ~4 days**

### Confidence: MEDIUM

FFmpeg's HLS demuxer is well-proven. The BBA algorithm is well-documented (Huang et al., 2014). The risk is in the quality switching mechanism — switching HLS variants requires either: (a) opening a new variant URL (causes brief interruption), or (b) using FFmpeg's internal ABR (limited control). Approach (a) with a brief buffering pause is acceptable for a desktop player. Approach (b) may be preferable if MDK exposes FFmpeg's `hls_variants` API — verify this during implementation.

---

## 3. Platform Abstraction Layer

### Problem

`WindowService` directly depends on `window_manager` package and Win32 FFI (`win32_bindings.dart`). There's no interface boundary — everything is concrete. Adding macOS/Linux support later requires rewriting the entire service.

### Solution: Abstract Interface + Windows Implementation

Follow the pattern from `D:\player_flutter` (reference project):

```dart
/// Platform-agnostic window management interface.
///
/// Each platform provides a concrete implementation.
/// Only interface definition — no macOS/Linux implementation yet.
abstract class PlatformService {
  // Reactive state
  ValueNotifier<bool> get isFullscreen;
  ValueNotifier<bool> get isAlwaysOnTop;
  ValueNotifier<bool> get isMaximized;
  ValueNotifier<Size> get windowSize;

  // Lifecycle
  Future<void> init();
  Future<void> dispose();

  // Commands
  Future<void> setFullscreen(bool value);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> maximize();
  Future<void> restore();
  Future<void> minimize();
  Future<void> setSize(double width, double height);
  Future<void> setMinSize(double width, double height);
}
```

**`WindowsPlatformService`** wraps the existing `WindowService`:

```dart
class WindowsPlatformService implements PlatformService {
  WindowsPlatformService(this._windowService);
  final WindowService _windowService;

  @override
  ValueNotifier<bool> get isFullscreen => _windowService.isFullscreen;
  // ... delegate all methods
}
```

### Why Constructor Injection, Not Service Locator

The reference project uses `PlatformService.I` (static singleton). This project should use constructor injection instead:

```dart
// In app.dart or main.dart
final windowService = WindowService();
final platformService = WindowsPlatformService(windowService);

// Pass to widgets/services via constructor
class App extends StatelessWidget {
  const App({required this.platformService});
  final PlatformService platformService;
}
```

**Why:** Constructor injection is explicit, testable, and already used by `PlaybackController` and `PlayerServices`. No new dependencies needed.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/kernel/platform/platform_service.dart` | NEW | Abstract interface (no implementation) |
| `lib/kernel/platform/windows_platform_service.dart` | NEW | Delegates to existing `WindowService` |
| `lib/app.dart` | MODIFY | Wire `WindowsPlatformService` in composition root |
| `lib/features/player/player_services.dart` | MODIFY | Accept `PlatformService` instead of `WindowService` directly |

### What NOT to Do

| Anti-Pattern | Why Not |
|-------------|---------|
| Add `get_it` or service locator | Overkill for 2-3 services; constructor injection works |
| Implement macOS/Linux stubs | Out of scope per PROJECT.md; interface-only |
| Abstract `WindowService` internals | `WindowService` stays concrete; `PlatformService` wraps it |
| Make `PlatformService` a mixin | Interface is cleaner for platform swapping |

### Confidence: HIGH

This is a straightforward interface extraction. The pattern is proven in the reference project (`D:\player_flutter`). No new packages. Risk is LOW — the interface is thin and delegates everything.

---

## 4. SettingsStore Simplification (Quick Reference)

Already researched in v1.2 STACK.md. No new packages. Use `_saveField<T>()` generic helper pattern. See existing `.planning/research/STACK.md` section 4.

## 5. Singleton Migration (Quick Reference)

Already researched in v1.2 ARCHITECTURE.md. No new packages. Constructor injection for `LocaleService` + `ThemeService`. Keep `SettingsStore` static. See existing `.planning/research/ARCHITECTURE.md` section 3.

---

## Summary: Zero New Dependencies

| Capability | Solution | New Package? |
|-----------|----------|-------------|
| Window frameless (WM_NCCALCSIZE) | C++ handler in `flutter_window.cpp` before Flutter | No |
| Fullscreen animation | Existing WS_POPUP + SetWindowPos (already works) | No |
| DWM shadow/rounded corners | `DwmExtendFrameIntoClientArea` + `ApplyRoundedCorners` (already works) | No |
| HLS ABR (BBA) | FFmpeg hls.c demuxer + Dart BBA controller | No |
| HLS variant parsing | `dart:io` HttpClient + simple string parsing | No |
| Bandwidth estimation | EWMA in pure Dart | No |
| Platform abstraction | Abstract class + Windows impl wrapping WindowService | No |
| SettingsStore simplification | Generic `_saveField<T>()` (v1.2 research) | No |
| Singleton migration | Constructor injection (v1.2 research) | No |

### Only Version-Adjacent Action

**Upgrade fvp from 0.36.2 to 0.37.0** — check changelog for HLS-related improvements before upgrading. The 0.36.2 version already has full HLS support via FFmpeg, but 0.37.0 may have buffer management or demuxer improvements.

---

## Sources

- Codebase: `flutter_window.cpp` (63 lines), `win32_window.cpp` (323 lines), `window_service.dart` (358 lines), `fvp_engine.dart` (690 lines), `win32_bindings.dart` (180+ lines)
- Memory: `anti_pattern_window_frameless.md` (3 failed approaches + root cause), `project_hls_abr_plan.md` (ABR architecture + MDK config), `reference_fvp_source_structure.md` (fvp_plugin.cpp analysis), `project_window_cross_platform.md` (cross-platform strategy), `reference_fvp_performance_bottlenecks.md` (rendering pipeline), `reference_fvp_optimization_plan.md` (3-tier optimization)
- Reference project: `D:\player_flutter` (PlatformService pattern, WM_SIZING handler)

---

*Research: 2026-05-31. Confidence: MEDIUM overall — window smoothness is the riskiest (untested WM_NCCALCSIZE-before-Flutter approach), HLS ABR is well-understood but quality switching mechanism needs validation, platform abstraction is straightforward.*
