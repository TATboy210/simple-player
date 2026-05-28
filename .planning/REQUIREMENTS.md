# Requirements — Simple Player Flutter

**Date:** 2026-05-28
**Strategy:** Window-first, then UI unification, then performance & quality

## v1 Requirements

### Window Management (WIN)

- [ ] **WIN-01**: Build MethodChannel window management layer
  - Dart side: `WindowService` class with typed API (fullscreen, alwaysOnTop, setSize, setPosition, setMinSize, setFrameless)
  - Windows side: C++ MethodChannel handler calling Win32 APIs (SetWindowLong, SetWindowPos, MonitorFromWindow)
  - Interface design: abstract `PlatformWindow` with Windows implementation, ready for macOS/Linux
  - Files: `lib/kernel/window/` (Dart), `windows/runner/window_channel.cpp` (C++)

- [ ] **WIN-02**: Window state persistence and restoration
  - On startup: read `SettingsStore` window geometry (x, y, width, height, isFullscreen, isAlwaysOnTop)
  - Apply saved state via `WindowService` after first frame
  - On close: save current geometry to `SettingsStore`
  - Edge cases: multi-monitor (clamp to visible bounds), DPI changes, display disconnected

- [ ] **WIN-03**: Frameless window with custom title bar
  - Remove `WS_CAPTION` via `SetWindowLong` on Windows
  - Custom `CustomTitleBar` widget: drag region, minimize/maximize/close buttons
  - `WM_NCHITTEST` for resize edges and drag area
  - Double-click title bar to maximize/restore

### Widget Unification (WIDGET)

- [ ] **WIDGET-01**: Unify glass component library
  - Current state: `GlassContainer`, `GlassButton`, `GlassIconButton` spread across files with inconsistent APIs
  - Target: Single `glass_widgets.dart` export file, consistent `GlassTier` enum, shared animation patterns
  - Merge `GlassButton` and `GlassIconButton` into `GlassButton` with `icon`/`iconOnly` constructors
  - Extract shared hover/press animation into `GlassAnimatedPress` mixin

- [ ] **WIDGET-02**: Optimize ValueNotifier rebuilds
  - Audit all `ValueListenableBuilder` instances for `child` parameter usage
  - Merge related notifiers: position + duration → `MergedListenable`
  - Cache static subtrees in `ControlsOverlay` (replace 8-field cache with single state object)
  - Measurable: reduce rebuild count by 30%+ in control bar area

### Performance (PERF)

- [x] **PERF-01**: fvp D3D11 sync optimization
  - Test `d3d11.sync.cpu=0` on 3+ hardware configs (dedicated GPU, Intel iGPU, AMD iGPU)
  - Document tearing behavior and fallback strategy
  - Target: 2-5ms/frame savings confirmed via DevTools

- [ ] **PERF-02**: Fix error handling anti-patterns
  - Replace `catch (_)` in `playlist_store.dart:168` with `on Exception catch (e)` + debugPrint
  - Replace `on Object catch` in `engine_prewarm.dart:56`, `subtitle_service.dart:37,59` with `on Exception catch`
  - Replace `catch (_)` in `fvp_engine.dart:544` with logging

- [x] **PERF-03**: Reduce control bar frame drops
  - Profile with DevTools in `--profile` mode
  - Identify root cause: BackdropFilter GPU readback vs ValueNotifier rebuild storm
  - Apply targeted fix based on profiling data

### Platform (PLATFORM)

- [ ] **PLATFORM-01**: Windows MethodChannel implementation
  - C++ handler in `windows/runner/` for all window operations
  - Win32 API calls: `SetWindowLong`, `SetWindowPos`, `MonitorFromWindow`, `GetWindowRect`
  - DPI-aware: `GetDpiForWindow`, `MonitorFromWindow`
  - Dark mode: `DWMWA_USE_IMMERSIVE_DARK_MODE` (already in runner)

- [ ] **PLATFORM-02**: macOS/Linux platform stubs
  - Abstract `PlatformWindow` interface
  - macOS stub: `NSWindow` MethodChannel handler (basic, not full implementation)
  - Linux stub: GTK window handler (basic)
  - Same MethodChannel name, platform-specific implementation

### Testing (TEST)

- [ ] **TEST-01**: Window layer unit tests
  - `WindowService` with mock `PlatformWindow`
  - State persistence round-trip (save → load → apply)
  - Multi-monitor clamping logic

- [ ] **TEST-02**: Settings panel widget tests
  - `SettingsPanel` rendering with `FakeEngine`
  - Deferred apply pattern (locale/theme changes)
  - Tab navigation

- [ ] **TEST-03**: Startup coordinator tests
  - Phase-based initialization
  - Error handling during startup
  - `EnginePrewarm` failure graceful degradation

- [ ] **TEST-04**: Coverage gap closure
  - Target: 64% → 80% (add ~300 lines of test coverage)
  - Priority: window layer, settings, startup, glass widgets

## v2 Requirements (Deferred)

- Triple buffering in fvp C++ layer (requires fvp fork)
- Impeller FragmentShader for BackdropFilter (requires Impeller stable on Windows)
- Integration tests for critical flows (Flutter desktop integration testing immature)
- Golden tests for glassmorphism components (GPU-dependent, flaky across machines)
- HLS/ABR streaming — separate project
- Steam/SteamOS distribution — separate project

## Out of Scope

- Third-party window packages (window_manager) — self-built MethodChannel only
- Mobile platforms (iOS/Android) — desktop only
- State management migration (Provider/Riverpod/Bloc) — ValueNotifier preserved
- Online subtitle search — separate feature
- HDR/ICC color management, frame interpolation, equalizer UI
- Full macOS/Linux window implementation (basic stubs only in v1)

## Traceability

| Requirement | Phase | Status | Source |
|-------------|-------|--------|--------|
| WIN-01 | 1 | Pending | User request, CONCERNS.md |
| WIN-02 | 1 | Pending | CONCERNS.md (SettingsStore unused fields) |
| WIN-03 | 1 | Pending | User request |
| WIDGET-01 | 2 | Pending | User request, CONCERNS.md |
| WIDGET-02 | 2 | Pending | CONCERNS.md #11, TESTING.md |
| PERF-01 | 3 | Complete | CONCERNS.md #2, fvp_performance_bottlenecks |
| PERF-02 | 1 | Pending | CONCERNS.md #3,#4 |
| PERF-03 | 3 | Complete | User request |
| PLATFORM-01 | 1 | Pending | User request |
| PLATFORM-02 | 4 | Pending | User request |
| TEST-01 | 4 | Pending | TESTING.md gaps |
| TEST-02 | 4 | Pending | TESTING.md gaps |
| TEST-03 | 4 | Pending | TESTING.md gaps |
| TEST-04 | 4 | Pending | TESTING.md (64% → 80%) |

---
*Last updated: 2026-05-28 after reinitialization*
