# Feature Landscape

**Domain:** Flutter Desktop Media Player (Performance Optimization)
**Researched:** 2026-05-23
**Confidence:** HIGH (based on codebase analysis, prior architecture research, fvp/MDK bottleneck documentation)

## Table Stakes

These are the baseline performance and quality fixes. Without them, the player feels sluggish and the codebase becomes unmaintainable.

### Rendering Pipeline

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Fix MFT:d3d=1 to MFT:d3d=11 | Eliminates D3D9-to-D3D11 surface copy on every frame. Current config in `platform_decoders.dart` forces a redundant conversion. | Low (1-line change) | Zero risk, automatic fallback for old drivers |
| Enable shader_resource=1 | GPU-accelerated YUV-to-RGB color conversion instead of CPU fallback. Currently disabled by fvp default. | Low (1-line in registerWith) | May need driver compatibility testing |
| Set log=warning in production | fvp default `log=all` wastes CPU on string formatting and I/O for every MDK event. | Low (1-line in registerWith) | Zero risk |
| Snapshot debounce on Texture | Already implemented (verified in memory). Keep as-is. | N/A | Already done |
| Disable d3d11.sync.cpu for testing | The #1 bottleneck: forces CPU to wait for GPU every frame. Setting to 0 may eliminate visible title bar jitter. | Low (1-line in registerWith) | Medium risk: may cause tearing on integrated GPUs. Must test on target hardware. |

### State Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| MergedListenable for position+duration | ControlBar currently nests multiple ValueListenableBuilders. Merging related state into one notifier halves rebuild count for the most frequently updated widget. | Medium | Pattern: custom ValueNotifier that listens to 2 upstream notifiers |
| Selector/ValueListenableBuilder scoping | Widgets that only need `isMuted` rebuild on `volume` changes. Tighten each VLB to the exact notifier it needs. | Medium (audit pass) | Systematic: grep all VLBs, verify they listen to minimum required notifiers |
| Resize degradation (skip BackdropFilter) | Already implemented per memory. BackdropFilter skipped during `isResizing`. | N/A | Already done |
| RepaintBoundary on hot widgets | Already implemented per memory. ControlBar, VideoSurface, Aurora, progress bar isolated. | N/A | Already done |

### Window Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Extract WindowServiceBase mixin | WindowService (302 lines), MacosWindowService (286 lines), LinuxWindowService (279 lines) share 90%+ identical code: init lifecycle, Completer guard, `_togglingFullscreen`/`_closing` mutex, dispose, toggleAlwaysOnTop, minimize, close, startDragging. Every bug fix must be replicated 3 times. | Medium | Extract mixin with shared lifecycle/error-handling. Platform services override only fullscreen/native-specific methods. |

### LRU Cache

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| LinkedHashMap-based LRU for thumbnails | Current `ThumbnailService` uses `Map<String, ImageProvider>` + `List<String>`. `_touch()` calls `_order.remove(filePath)` which is O(n) on every cache hit. With 200 items, this is a linear scan on every thumbnail access. | Low | Replace with `LinkedHashMap` (access-order) for O(1) touch+evict. ~20 lines changed. |
| Instance-based ThumbnailService | Static singleton (`_impl`, `_cache`, `_order`) cannot be tested, state leaks between test runs, no way to inject fakes. | Medium | Convert to instance with constructor-injected `ThumbnailProvider`. Register via service locator or pass through widget tree. |

### Testing

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Unit tests for window layer | FullscreenController, WindowStateService, WindowPersistenceService have zero test coverage. Window management is the most platform-sensitive code. | Medium | FullscreenController needs Win32 mock/stub. StateService and PersistenceService are testable with SharedPreferences fake. |
| Unit tests for ThumbnailService | Static singleton prevents testing. After instance-based refactor, test LRU eviction, cache hit/miss, provider fallback. | Low (after refactor) | Depends on instance-based refactor |
| Widget tests for settings panel | SettingsCard (754 lines), SettingsPanel, ShortcutsTab, VideoTab untested. Deferred-apply pattern adds complexity. | Medium | Test locale switching, theme application, keyboard shortcut binding |

## Differentiators

Features that set this player apart from generic video players. Not expected by default, but provide competitive advantage.

### Rendering Pipeline

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Triple buffering in fvp C++ layer | Eliminates 90% of mutex contention between MDK render thread and Flutter raster thread. Current double-buffer (rt + tex) shares one lock. Third buffer enables lockless swap. | High (requires fvp fork) | ~50 lines C++ change. 8MB extra VRAM for 1080p BGRA. Per prior analysis: highest-impact C++ optimization. |
| Fence替代Flush | Replace `ctx->Flush()` with `ID3D11Query` event query. Flush drains entire GPU pipeline; fence only waits for CopyResource completion. Saves 1-3ms per frame at 60fps. | Medium (requires fvp fork) | ~15 lines C++ change. Low risk. |
| Remove redundant D3D11 multithread protection | `SetMultithreadProtected(TRUE)` adds internal locks to every D3D11 API call, but `mutex mtx` already protects cross-thread access. Two lock layers are redundant. | Low (requires fvp fork, delete 3 lines) | Must verify no uncovered code paths. |
| Shared D3D11 device across textures | Currently `D3D11CreateDevice` per texture. Shared device saves ~50ms init and device-level VRAM. | Low (requires fvp fork) | Only matters for multi-texture (PiP) scenarios. |

### State Management

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| PlayerActions record (callback deduplication) | PlayerScreen takes 15+ VoidCallbacks, ControlsOverlay takes 10+. Grouping into a single `record` type eliminates callback drilling through 5 widget layers. | Medium | `typedef PlayerActions = ({VoidCallback onPlay, VoidCallback onPause, ...})`. Requires touching ~8 files. |
| ChangeNotifier grouping for related state | Group volume+mute+playbackSpeed into one notifier, position+duration+buffered into another. Reduces total notifier count from 12 to ~5, cutting VLB rebuild surface. | High | Architectural change. Must preserve individual notifier access for widgets that only need one field. Can coexist: expose grouped notifier + individual getters. |

### Window Management

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Platform-agnostic fullscreen abstraction | Current Windows fullscreen uses Win32 FFI (SetWindowLongW, SetWindowPos). macOS uses NSWindow.toggleFullScreen. Linux uses window_manager. Abstract behind a `FullscreenStrategy` interface so platform service only calls `strategy.enter()`/`strategy.exit()`. | Medium | Isolates all FFI code into strategy implementations. Platform service becomes pure lifecycle management. |

### Testing

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Integration tests for critical flows | Zero integration tests exist. Open -> play -> seek -> pause -> next is the core user flow. Catching platform-specific regressions requires real device testing. | High | Needs `integration_test/` directory. Requires fvp engine mock or test media files. Flutter desktop integration testing is less mature than mobile. |
| Golden tests for glassmorphism UI | Control bar, progress bar, playlist panel use complex glassmorphism (BackdropFilter + gradient + border). Visual regressions are invisible without golden comparison. | Medium | Need `test/golden/` directory. Platform-specific rendering differences (Windows vs macOS) require per-platform golden files. |
| Fake engine for deterministic testing | Current `FakeEngine` in `test/helpers/fake_engine.dart` exists. Extend it to cover all 12 ValueNotifiers and error scenarios for comprehensive widget testing. | Low | Incremental extension of existing fake. |

## Anti-Features

Features to explicitly NOT build. These are tempting but waste time or introduce complexity without proportional value.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| State management migration (Provider/Riverpod/Bloc) | ValueNotifier is the project constraint. Migration touches every widget, every test, every service. Risk of regression is enormous for marginal DX improvement. | Optimize within ValueNotifier pattern: MergedListenable, Selector, tighter scoping. |
| Full macOS/Linux implementation | Stubs exist, not priority per PROJECT.md. Real implementation requires platform-specific FFI, thumbnail extraction, fullscreen strategy. 3-6 days per platform. | Keep stubs. Focus on Windows. Port after Windows is production-quality. |
| Custom frame scheduling (ExoPlayer-style 6-action decision tree) | Flutter Texture API does not expose frame release timing. MDK handles A/V sync internally. Implementing custom scheduling would require forking both fvp and Flutter engine. | Trust MDK's internal scheduling. Focus on reducing rendering overhead so frames arrive on time. |
| HDR/ICC color management pipeline | mpv's libplacebo pipeline is thousands of lines. Flutter Texture does not support color space metadata. | Out of scope. MDK handles basic tone mapping. Full HDR requires Flutter engine changes. |
| Frame interpolation (motion compensation) | mpv's pl_queue multi-frame mixing is GPU-shader-level work. No Flutter API support. | Out of scope. |
| Atomic file writes for PlaylistStore | Current 3-attempt flush loop mitigates crash corruption. Atomic write (write-to-temp + rename) adds complexity for a rare edge case. | Keep retry logic. Add a comment documenting the tradeoff. Only revisit if users report data loss. |
| UNC path / symlink blocking in PathValidator | Desktop media player is not a security-critical application. Users open their own files. | Keep current validation (existence + extension check). Document limitation. |
| Equalizer / audio effects UI | Per PROJECT.md: "New UI features (equalizer, video filters) -- focus on optimization, not new features" | Defer to separate feature project. |

## Feature Dependencies

```
MFT:d3d=11 ─┐
shader_resource=1 ─┤─── fvp registerWith config (all 3 are 1-line changes in same location)
log=warning ─┘

d3d11.sync.cpu=0 ──── requires hardware testing (independent of above 3)

LinkedHashMap LRU ──── ThumbnailService instance-based refactor (do LinkedHashMap first, then extract instance)

MergedListenable ──── Selector/audit pass (do merge first, then tighten scoping)

WindowServiceBase mixin ──── FullscreenStrategy abstraction (mixin first, then strategy extraction)

Unit tests (window) ──── WindowServiceBase mixin (test the extracted base)

Unit tests (thumbnail) ──── ThumbnailService instance-based refactor (test after refactor)

Integration tests ──── FakeEngine extension (extend fake first, then build integration flows)

Golden tests ──── RepaintBoundary audit (ensure boundaries are correct before golden comparison)
```

## MVP Recommendation

Prioritize in this order:

**Phase 1 - Zero-risk rendering fixes (1-2 days)**
1. MFT:d3d=1 to MFT:d3d=11 (1 line)
2. shader_resource=1 (1 line)
3. log=warning (1 line)
4. Test d3d11.sync.cpu=0 on target hardware (1 line, needs validation)

**Phase 2 - State management cleanup (2-3 days)**
5. MergedListenable for position+duration
6. VLB audit pass (tighten scoping)

**Phase 3 - LRU cache fix (1 day)**
7. LinkedHashMap-based LRU (O(1) touch)
8. Instance-based ThumbnailService

**Phase 4 - Window deduplication (2-3 days)**
9. Extract WindowServiceBase mixin
10. Unit tests for extracted base

**Phase 5 - Test coverage (3-4 days)**
11. Unit tests for window layer (WindowStateService, WindowPersistenceService)
12. Unit tests for ThumbnailService
13. Widget tests for settings panel
14. Golden tests for critical UI components

**Phase 6 - Advanced optimizations (requires fvp fork)**
15. Triple buffering (C++ plugin layer)
16. Fence替代Flush (C++ plugin layer)

**Defer:**
- Integration tests: Flutter desktop integration testing is immature. Build after unit/widget coverage is solid.
- PlayerActions record: Nice refactor but not a performance fix. Do after core optimizations.
- ChangeNotifier grouping: High risk architectural change. Only if VLB audit proves insufficient.

## Sources

- `reference_fvp_performance_bottlenecks.md` — 9 bottlenecks ranked by severity
- `reference_fvp_optimization_plan.md` — 3-tier optimization plan with code examples
- `reference_rendering_pipeline_comparison.md` — mpv vs ExoPlayer vs Flutter+fvp pipeline comparison
- `project_widget_layer_redesign.md` — Widget gap analysis, MergedListenable, PlayerActions record
- `project_window_cross_platform.md` — Window platform abstraction strategy
- `.planning/PROJECT.md` — Active requirements (PERF-01 through TEST-03)
- `.planning/codebase/CONCERNS.md` — Tech debt, bottlenecks, test gaps
- `lib/kernel/services/thumbnail_service.dart` — Current O(n) LRU implementation
- `lib/window/window_service.dart`, `macos_window_service.dart`, `linux_window_service.dart` — 90%+ code duplication
- `lib/kernel/engine/media_engine.dart` — 12 ValueNotifiers exposed
- Dart/Flutter testing docs (flutter_test, integration_test patterns)
