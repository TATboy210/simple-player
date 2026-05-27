# Project Research Summary

**Project:** Simple Player Flutter (Performance Optimization)
**Domain:** Flutter Desktop Media Player (Win32 + fvp/MDK + D3D11)
**Researched:** 2026-05-23
**Confidence:** HIGH

## Executive Summary

Simple Player Flutter is a Windows desktop media player built on Flutter + fvp (MDK/FFmpeg) with a glassmorphism UI. The performance optimization research identifies three bottleneck layers: (1) the fvp D3D11 rendering pipeline where per-frame CPU-GPU sync stalls and mutex contention cause micro-stutter, (2) the Flutter widget layer where 35 ValueListenableBuilder instances and 6 BackdropFilter widgets trigger excessive rebuilds and GPU readback, and (3) the Win32 window layer where 900+ lines of triplicated code across 3 platform services creates maintenance burden and bug reproduction risk.

The recommended approach is a "measure first, fix cheap, refactor clean" strategy. Start with zero-risk 1-line fvp configuration fixes (MFT:d3d=11, shader_resource=1, log=warning) that eliminate D3D9-to-D3D11 surface conversion and CPU-side YUV decoding. Then profile with `flutter run --profile -d windows` to establish baselines before touching BackdropFilter or ValueNotifier architecture. The window service deduplication (3 files to 1 mixin + 3 thin implementations) is independent of performance work and can proceed in parallel.

Key risks: (1) Setting d3d11.sync.cpu=0 may cause tearing on integrated GPUs -- requires hardware testing before shipping. (2) BackdropFilter optimization without profiling may target the wrong bottleneck -- the 18 control bar bugs prove that guessing causes more problems than measuring. (3) The popup overlay architecture (Pitfall #16) is an architectural issue that cannot be fixed by optimizing individual widgets.

## Key Findings

### Recommended Stack

The project already uses the right stack. No technology changes are needed. The optimization work is about configuration tuning and architectural cleanup within the existing ValueNotifier + fvp + Win32 FFI architecture.

**Profiling tools:**
- Flutter DevTools in profile mode (`flutter run --profile -d windows`) -- mandatory, debug mode uses software renderer
- Windows Performance Analyzer (WPA) for system-level GPU/CPU when DevTools shows raster jank
- RenderDoc for frame-level D3D11 GPU debugging

**fvp configuration (zero-fork optimizations):**
- `MFT:d3d=11` replaces `MFT:d3d=1` -- eliminates D3D9-to-D3D11 surface copy per frame
- `shader_resource=1` -- GPU-accelerated YUV-to-RGB instead of CPU fallback
- `d3d11.sync.cpu=0` -- eliminates per-frame CPU-GPU sync stall (2-5ms savings, needs HW test)
- `log=warning` -- stops wasting CPU on fvp debug string formatting

### Expected Features

**Must have (table stakes) -- Phase 1-3:**
- Fix MFT:d3d=1 to MFT:d3d=11 (1-line, zero risk)
- Enable shader_resource=1 and log=warning (1-line each)
- Test d3d11.sync.cpu=0 on target hardware (1-line, medium risk)
- MergedListenable for position+duration (halves rebuild count for time widgets)
- VLB audit pass -- tighten each ValueListenableBuilder to minimum required notifier
- Expand resize-aware BackdropFilter degradation to playlist_panel.dart
- LinkedHashMap-based LRU for ThumbnailService (O(1) touch vs current O(n))
- Extract WindowServiceBase mixin from 3 triplicated platform services

**Should have (competitive) -- Phase 4-5:**
- Unit tests for WindowStateService, WindowPersistenceService, FullscreenController
- Unit tests for ThumbnailService (after instance-based refactor)
- Widget tests for settings panel (754 lines, deferred-apply pattern)
- PlayerActions record to eliminate callback drilling (15+ VoidCallbacks)
- Instance-based ThumbnailService and OsdService (convert singletons)

**Defer (v2+):**
- Triple buffering in fvp C++ layer (requires fvp fork, ~50 lines C++)
- Fence替代Flush in fvp C++ layer (requires fvp fork, ~15 lines C++)
- Impeller FragmentShader replacement for BackdropFilter (requires Impeller stable on Windows)
- Integration tests (Flutter desktop integration testing is immature)
- Golden tests for glassmorphism (GPU-dependent, flaky across machines)
- Full macOS/Linux implementation (stubs only, 3-6 days per platform)
- State management migration (Provider/Riverpod/Bloc) -- violates project constraint
- HDR/ICC color management, frame interpolation, equalizer UI

### Architecture Approach

The codebase follows a 3-layer architecture: Kernel (engine, models, persistence), Window (WindowService singleton + WindowLifecycleBus event bus + C++ MethodChannel), and UI (ValueNotifier-driven widgets with glassmorphism). The architecture is sound. The main structural issue is static singleton services (ThumbnailService) that prevent testing.

**Major components to refactor:**
1. WindowService (302 lines) + MacosWindowService (286 lines) + LinuxWindowService (279 lines) -- extract WindowServiceBase mixin, shrink each to 40-60 lines
2. ThumbnailService -- convert from static singleton to instance-based with constructor-injected ThumbnailProvider
3. FvpEngine -- 14 ValueNotifiers, optimize scoping and grouping (not migration)

**Components to preserve as-is:**
- PlaybackController mixin composition (FileOperations + PlaybackNavigator + StateMonitor) -- well-structured
- WindowService.instance singleton + WindowLifecycleBus event bus
- ValueNotifier state management -- project constraint, optimize within pattern

### Critical Pitfalls

1. **Profile before optimizing** -- BackdropFilter, ValueNotifier, and fvp all contribute to jank. Optimizing the wrong layer wastes time. Use `flutter run --profile` + DevTools Timeline to identify which thread (UI vs raster) is the bottleneck before changing anything.

2. **BackdropFilter wrong layer caching** -- RepaintBoundary must wrap the BackdropFilter's *child*, not the BackdropFilter itself. The project already does this correctly in GlassContainer, but verify playlist_panel.dart and empty_state.dart. Each uncached BackdropFilter costs 2-4ms GPU readback at 1080p.

3. **d3d11.sync.cpu=0 tearing risk** -- This is the highest-impact single optimization (saves 2-5ms per frame) but may cause visible tearing on Intel integrated GPUs. Test on at least 3 hardware configs before shipping. Fallback: keep sync=1 but add shader_resource=1 to offload YUV-to-RGB to GPU.

4. **Popup overlay architecture (Pitfall #16)** -- Volume/Speed popups use app-level Overlay, which escapes the control bar's FadeTransition and intercepts button taps. This is an architectural issue requiring local Overlay within ControlsOverlay, not a widget-level fix.

5. **Completer race in window lifecycle** -- The 5 boolean guards across all 3 platform services have order-dependent checking. Extracting WindowServiceBase mixin fixes this once for all platforms. Always check _disposed FIRST in every async operation.

## Implications for Roadmap

### Phase 1: Zero-Risk Rendering Fixes (1-2 days)
1-line fvp config changes (MFT:d3d=11, shader_resource=1, log=warning), ClipRect verification.

### Phase 2: Profile and Measure (1 day)
Establish baselines with DevTools before optimizing. Identify worst rebuild offenders.

### Phase 3: fvp D3D11 Pipeline Tuning (2-3 days)
d3d11.sync.cpu=0 with hardware testing on 3+ configs.

### Phase 4: BackdropFilter and ValueNotifier Cleanup (3-4 days)
Targeted fixes based on profiling data: sigma reduction, VLB audit, MergedListenable.

### Phase 5: Window Service Deduplication (2-3 days)
Extract WindowServiceBase mixin from 3 triplicated files. ~600 lines removed.

### Phase 6: Singleton Cleanup and Test Coverage (3-4 days)
Instance-based services + unit tests for window/thumbnail layers.

### Phase 7: Advanced Optimizations — Only If Needed (3-5 days)
Triple buffering + Fence替代Flush. Requires fvp fork.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | fvp source analyzed, 9 bottlenecks ranked |
| Features | HIGH | 18+5 real bugs documented, codebase analyzed |
| Architecture | HIGH | 3 window services diffed, 3 mixins analyzed |
| Pitfalls | HIGH | 16 pitfalls from real bugs and source inspection |

## Sources

- Direct codebase analysis: 3 window services (870 lines diffed), fvp_plugin.cpp (193 lines)
- Project memory: 9 fvp bottlenecks, 18 control bar bugs, 5 fullscreen bugs
- Flutter docs: DevTools profiling, BackdropFilter, golden tests, integration tests
- Context7: window_manager API (setAsFrameless, startDragging, setTitleBarStyle)

---

*Research completed: 2026-05-23*
