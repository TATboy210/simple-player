# Feature Landscape: v1.2.1 Window Polish & HLS ABR

**Domain:** Flutter desktop media player — window smoothness, HLS ABR, architecture simplification
**Researched:** 2026-05-31
**Confidence:** HIGH (existing codebase analysis + documented anti-patterns + fvp/MDK constraints)

## Table Stakes

Features the v1.2.1 milestone explicitly targets. Missing any = incomplete milestone.

### 1. Startup Border Flash Elimination

**Why Expected:** Win11 shows 1-frame straight-corner flash when `setAsFrameless()` strips `WS_CAPTION`. Every modern desktop app (Spotify, VS Code, Discord) launches without visual artifacts. Users notice immediately.

**Current State:**
- C++ `Win32Window::Create` uses `WS_OVERLAPPEDWINDOW` (default rounded corners on Win11)
- Dart `WindowService.init()` calls `_removeBorder()` which strips `WS_CAPTION`
- Between create and border removal, DWM resets corner preference to default (may show straight corners)
- Fix already documented: `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)` in `OnCreate`

**Complexity:** Low (3-line C++ fix in `flutter_window.cpp:OnCreate`)
**Dependencies:** None — purely C++ layer change

---

### 2. Fullscreen Smooth Transition

**Why Expected:** Current fullscreen uses `SetWindowPos` atomic resize (correct) but loses DWM maximize/restore animation. Users expect macOS-style smooth transition.

**Current State:**
- `WindowService._enterFullscreen()`: strips `WS_THICKFRAME | WS_CAPTION`, then `SetWindowPos` to fill monitor
- `WindowService._exitFullscreen()`: restores style + position atomically
- DWM animation lost because `WS_CAPTION` removal breaks DWM animation pipeline (documented anti-pattern)

**Complexity:** Very High
**Blocker:** Flutter engine's `HandleTopLevelWindowProc` intercepts `WM_NCCALCSIZE` before custom C++ handler. 3 documented failed approaches:
1. Direct `WS_CAPTION` removal → loses DWM animation
2. `WM_NCCALCSIZE` to hide title bar → conflicts with Flutter engine
3. Mixed approach → each fix introduces new side effects

**Viable Path:** Keep current `SetWindowPos` approach (no animation) OR investigate Microsoft Terminal's `NonClientIslandWindow` pattern (custom `WM_NCHITTEST` + DWM API bypass). The latter is a multi-week investigation.

**Recommendation:** Accept current behavior for v1.2.1. Flag for deeper research in v1.3.

---

### 3. HLS Single-Variant Stream Playback

**Why Expected:** Any media player must handle `.m3u8` URLs. FFmpeg's HLS demuxer is built-in.

**Current State:**
- `FvpEngine.open()` already passes URLs to MDK/FFmpeg
- Single-variant HLS (one bitrate) works out of the box
- No ABR logic exists

**Complexity:** Low (already works)
**Dependencies:** None

---

### 4. HLS Adaptive Bitrate Streaming (Throughput-Based)

**Why Expected:** Multi-variant HLS streams (360p/720p/1080p/4K) require quality switching. Without ABR, users get stuck on lowest quality or suffer buffering.

**Current State:**
- No ABR implementation exists
- MDK's FFmpeg HLS demuxer has basic ABR via `avformat.hls_prefer_list` but no fine-grained control
- Existing low-latency config (`fflags +nobuffer`, `drop:true`) conflicts with ABR buffering needs
- Architecture planned in memory: `AbrService` with `BandwidthEstimator` + `QualitySelector` + `SegmentPrefetcher`

**Complexity:** High
**Recommended Scope (v1.2.1):** Throughput-based only (not BBA/MPC)

```
New files:
├── lib/kernel/services/abr_service.dart       ← ABR decision engine
│   ├── BandwidthEstimator  (sliding window, EWMA)
│   ├── QualitySelector     (throughput-based, not BBA)
│   └── SegmentPrefetcher   (next-segment preload)
├── lib/kernel/models/abr_state.dart           ← ABR state model
│   ├── AbrState (currentBitrate, bufferLevel, bandwidth)
│   └── QualityVariant (resolution, bitrate, url)
└── lib/kernel/engine/network_configurator.dart ← URL-type routing
    └── Low-latency (RTSP/RTMP) vs ABR (HLS) config switching
```

**Key Design Decision:** URL-based routing — if URL contains `.m3u8`, apply ABR buffer config; otherwise apply low-latency config. No conflict.

**Dependencies:** MDK `setProperty('avformat.hls_*', ...)` API

---

### 5. SettingsStore Simplification

**Why Expected:** ARCH-02 in PROJECT.md. 25+ individual `saveX()` methods that all follow identical pattern.

**Current State:**
- `settings_store.dart`: 439 lines, 25+ typed save methods
- Each method: `_save('key', (p) => p.setTYPE(key, clamp(value)))`
- `load()` is 95 lines with individual field reads
- `AppSettings` model with `copyWith` already exists

**Complexity:** Medium
**Recommended Pattern:**

```dart
// Generic typed save
static Future<void> _saveValue<T>(
  String key, T value, T Function(T) sanitize,
) => _save(key, (p) async {
  final safe = sanitize(value);
  if (safe is double) await p.setDouble(key, safe);
  else if (safe is int) await p.setInt(key, safe);
  else if (safe is bool) await p.setBool(key, safe);
  else if (safe is String) await p.setString(key, safe);
});

// Individual methods become one-liners
static Future<void> saveVolume(double value) =>
    _saveValue(_keyVolume, value, (v) => v.clamp(0.0, 1.0));
```

**Dependencies:** None (pure refactoring)

---

### 6. Window Layer Simplification

**Why Expected:** WIN-06 in PROJECT.md. 5 files / 337 lines in `lib/kernel/bridge/` can be consolidated.

**Current State (from LAYER 8 analysis):**
| File | Lines | Role |
|------|-------|------|
| `window_constants.dart` | 14 | Compile-time constants |
| `window_state.dart` | 15 | 4 ValueNotifiers |
| `window_service.dart` | 163 | Init + 8 actions + OS callbacks |
| `aspect_ratio_service.dart` | 69 | Aspect ratio + rollback |
| `window_lifecycle.dart` | 76 | `isOperating` event bus + PerfMonitor |

**Core Value:** `WindowLifecycleBus.isOperating` — unique signal not provided by `window_manager` (resize/move pause)

**Complexity:** Low
**Recommended:** Merge into 1 `WindowManager` class in `kernel/services/`. Keep `isOperating` signal.

**Dependencies:** None (pure refactoring)

---

### 7. Platform Abstraction Interface

**Why Expected:** PLATFORM-03 in PROJECT.md. Interface definition only (no macOS/Linux implementation).

**Current State:**
- `WindowService` is Windows-only (Win32 FFI, `window_manager`)
- `ThumbnailService` already has platform-aware facade pattern
- macOS/Linux are v2

**Complexity:** Medium
**Recommended:**

```dart
abstract interface class PlatformService {
  Future<void> setFullscreen(bool value);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setAsFrameless();
  ValueNotifier<bool> get isFullscreen;
  ValueNotifier<bool> get isAlwaysOnTop;
  // ... etc
}

class WindowsPlatformService implements PlatformService {
  // wraps existing WindowService
}
```

**Dependencies:** Window layer simplification (blocks on #6)

## Differentiators

Features that improve quality of life beyond the milestone requirements.

### 8. ABR Quality Indicator OSD

**Value:** Transparency on stream quality. Users see current bitrate/resolution in OSD pill.

**Complexity:** Low (once ABR engine exists)
**Dependencies:** HLS ABR (#4)

---

### 9. Manual Quality Override

**Value:** User control over auto ABR. Accessibility for bandwidth-limited users.

**Complexity:** Medium
**Implementation:** Settings panel toggle: Auto/1080p/720p/480p. Needs `QualityVariant` model.
**Dependencies:** HLS ABR (#4) + Settings panel tab

---

### 10. Window Entrance Animation

**Value:** First-launch delight. 200ms scale-up from 95% with ease-out curve.

**Complexity:** Low
**Implementation:** `AnimatedBuilder` + `Transform.scale` on first frame. No Win32 dependency.
**Dependencies:** None

---

### 11. Singleton-to-DI Migration

**Value:** Testability. Eliminate global mutable state.

**Current Singletons:**
| Singleton | Pattern | Consumers |
|-----------|---------|-----------|
| `LocaleService.I` | `static final I` | 5 files |
| `ThemeService.I` | `static final I` | 5 files |
| `SettingsStore._cachedPrefs` | Static mutable | 15+ files |
| `ThumbnailService._impl` | Lazy static | 3 files |
| `PerfMonitor.instance` | `static final` | 2 files |
| `OsdService.I` | `static final I` | 3 files |

**Complexity:** High (21+ files touched)
**Recommended:** Incremental constructor injection via `PlayerServices` composition root. NOT `get_it` (contradicts "no state management library" constraint).

**Dependencies:** SettingsStore simplification (#5) reduces migration surface

---

### 12. BBA Algorithm (Buffer-Based Approach)

**Value:** More stable quality switching than throughput-based. Avoids oscillation on variable bandwidth.

**Complexity:** High
**Algorithm:** Huang et al. (2014) — maps buffer occupancy to bitrate selection via utility function.
**Dependencies:** Throughput-based ABR (#4) as baseline

**Recommendation:** DEFER to v1.3. Throughput-based covers 80% of desktop use cases (stable bandwidth).

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom `WM_NCCALCSIZE` handler in C++ | Flutter engine intercepts before custom code; 3 documented failed approaches | Use Dart-side `setFrameless()` + `DWMWA_WINDOW_CORNER_PREFERENCE` in C++ `OnCreate` |
| Replace `window_manager` package | Already the best option for frameless; self-built MethodChannel wraps it | Keep as dependency; simplify wrapper layer |
| Full ABR algorithm suite (BBA + BOLA + MPC) | Over-engineering for desktop player; browser players need this because network is shared | Implement throughput-based first; skip BOLA/MPC |
| Custom HLS demuxer | FFmpeg already handles HLS | Use FFmpeg's built-in demuxer; configure via `setProperty()` |
| Offline HLS segment caching | Desktop has local files; different use case than mobile | Not needed |
| Picture-in-picture / multi-player | Out of scope; complexity explosion with shared D3D11 device | Defer to v2+ |
| `get_it` / service locator | Contradicts "no state management library" constraint; hides dependencies | Constructor injection via PlayerServices |
| `part/part of` for file splitting | Dart officially discourages; creates hidden coupling | Separate files with explicit imports |
| State management migration | ValueNotifier works; migration cost with zero user-visible benefit | Keep ValueNotifier pattern |

## Feature Dependencies

```
Startup border flash fix (1) ──> C++ only, no Dart dependency
Fullscreen smooth transition (2) ──> BLOCKED by Flutter engine WM_NCCALCSIZE interception
HLS single-variant (3) ──> already works
HLS ABR throughput-based (4) ──> BandwidthEstimator → QualitySelector → MDK buffer config
SettingsStore simplification (5) ──> standalone, simplifies DI migration
Window layer simplification (6) ──> standalone
Platform abstraction (7) ──> depends on 6 (WindowService refactor)
ABR quality OSD (8) ──> depends on 4
Manual quality override (9) ──> depends on 4 + Settings panel
Window entrance animation (10) ──> standalone
Singleton-to-DI (11) ──> depends on 5 (SettingsStore simplification)
BBA algorithm (12) ──> depends on 4 (throughput-based as baseline)
```

## MVP Recommendation

**Prioritize (v1.2.1 scope):**

1. **Startup border flash fix (#1)** — 3-line C++ fix. HIGH impact, LOW effort. Documented in memory.
2. **HLS throughput-based ABR (#4)** — New feature, MEDIUM effort. Covers 80% of streaming use cases.
3. **SettingsStore simplification (#5)** — Code reduction, MEDIUM effort. 439 → ~200 lines.
4. **Window layer simplification (#6)** — Consolidation, LOW effort. 5 files → 1.
5. **Platform abstraction interface (#7)** — Interface only, MEDIUM effort. No implementation.

**Defer:**

- **Fullscreen smooth transition (#2)** — BLOCKED by Flutter engine. Needs deep investigation. Flag for v1.3 research.
- **BBA algorithm (#12)** — Throughput-based covers desktop. BBA adds marginal value. DEFER to v1.3.
- **Singleton-to-DI (#11)** — Architecture improvement, not user-visible. Incremental. DEFER to v1.3.
- **Manual quality override (#9)** — Nice-to-have. DEFER to v1.3.

## Complexity Summary

| Feature | Complexity | Files Changed | Risk |
|---------|-----------|---------------|------|
| Startup border flash (#1) | Low | 1 (flutter_window.cpp) | Low — additive, documented |
| Fullscreen smooth (#2) | Very High | 3+ (C++ + Dart) | High — Flutter engine blocker |
| HLS single-variant (#3) | Low | 0 (already works) | None |
| HLS ABR (#4) | High | 4-5 new files + fvp_engine | Medium — new feature, MDK dependency |
| SettingsStore simplification (#5) | Medium | 1 (settings_store.dart) | Low — internal refactor |
| Window layer simplification (#6) | Low | 5→1 files | Low — consolidation |
| Platform abstraction (#7) | Medium | 2-3 new + modified | Low — interface only |
| ABR quality OSD (#8) | Low | 1-2 (osd_overlay + abr_service) | Low — additive |
| Manual quality override (#9) | Medium | 2-3 (settings + abr) | Low — additive |
| Window entrance animation (#10) | Low | 1 (player_screen.dart) | Low — additive |
| Singleton-to-DI (#11) | High | 21+ files | Medium — behavioral change |
| BBA algorithm (#12) | High | 2-3 (abr_service) | Medium — algorithm complexity |

## Sources

- Memory: `project_window_corner_fix` — DWM corner preference fix (C++ OnCreate)
- Memory: `anti_pattern_window_frameless` — 3 failed C++ frameless approaches
- Memory: `project_fullscreen_win32_fix` — Win32 FFI fullscreen rewrite (SetWindowPos atomic)
- Memory: `project_hls_abr_plan` — HLS ABR architecture, BBA/throughput/MPC comparison
- Memory: `project_layer8_window_analysis` — Window layer 5-file analysis, isOperating signal
- Memory: `project_startup_optimization` — Startup state machine, lazy FvpEngine
- Memory: `project_settings_panel_redesign` — Settings panel architecture, deferred apply
- Memory: `project_service_layer_design` — Mixin composition, PlaybackContract
- Memory: `reference_fvp_optimization_plan` — fvp D3D11 pipeline, 3-tier optimization
- Codebase: `lib/kernel/bridge/window_service.dart` (328 lines, Win32 FFI)
- Codebase: `lib/kernel/persistence/settings_store.dart` (439 lines, 25+ save methods)
- Codebase: `lib/kernel/engine/fvp_engine.dart` (690 lines, network config)
- PROJECT.md — v1.2.1 milestone scope and constraints
