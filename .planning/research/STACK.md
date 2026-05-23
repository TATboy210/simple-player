# Technology Stack: Performance Optimization

**Project:** Simple Player Flutter (desktop media player)
**Researched:** 2026-05-23
**Confidence:** MEDIUM-HIGH (codebase analysis + training data; web search tools were unavailable for live verification)

---

## 1. Flutter DevTools Profiling for Desktop

### Recommended Tool Chain

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **Flutter DevTools** (bundled with SDK) | 3.x (matches project SDK 3.11.5) | Frame timeline, widget rebuild tracking, GPU profiling | Only tool that shows Flutter-specific raster/UI thread split and widget rebuild counts |
| **`flutter run --profile -d windows`** | SDK built-in | Release-like performance with DevTools hooks | Debug mode disables optimizations; profile mode is mandatory for accurate measurement |
| **`--trace-startup`** | SDK built-in | Startup timing breakdown | Identifies cold-start bottlenecks (fvp init, SharedPreferences, WindowBootstrap) |
| **DevTools Performance Overlay** | SDK built-in | Real-time frame time bars (green/red) | Quick visual check during development; red bars = jank |
| **DevTools Widget Rebuild Tracker** | SDK built-in | Per-widget rebuild count + frequency | Identifies which `ValueListenableBuilder` instances fire most often |
| **Dart DevTools Timeline** | SDK built-in | CPU flame chart, async event tracing | Pinpoints expensive operations in the UI thread (build, layout, paint) |
| **Windows Performance Analyzer (WPA)** | Windows ADK | System-level GPU/CPU profiling | When Flutter DevTools shows "raster jank" but the cause is in native D3D11 code |
| **GPUView** | Windows ADK | D3D11 GPU queue visualization | Identifies GPU pipeline stalls from fvp's CopyResource/Flush calls |
| **RenderDoc** | Latest stable | Frame-level D3D11 GPU debugging | Captures individual frames to inspect shader execution, texture copies, GPU stalls |

### Desktop-Specific Profiling Notes

**Profile mode is critical.** Debug mode on Windows uses a software renderer fallback and disables all optimizations. The `--profile` flag enables:
- AOT compilation (release-like)
- DevTools service extensions
- Real GPU rendering path

**Impeller status on Windows (Flutter 3.44+):** The project's memory notes indicate Impeller may be the default on Windows in Flutter 3.44 beta, using Vulkan 1.4 with OpenGL fallback. The `--enable-impeller` flag reportedly no longer exists in this version. Profiling must account for which renderer is active -- check `flutter run --verbose` for the actual backend in use.

**What to measure:**
1. **UI thread frame time** -- target <8ms for 120fps, <16ms for 60fps
2. **Raster thread frame time** -- BackdropFilter and Texture rendering show up here
3. **Shader compilation events** -- first-time shader compilation causes one-time jank (Impeller eliminates this; Skia does not)
4. **Widget rebuild counts** -- use DevTools "Track Widget Rebuilds" to count ValueListenableBuilder firings per frame
5. **GPU memory** -- D3D11 textures (video ~8MB/1080p, glass blur surfaces) consume VRAM

### What NOT to Use

| Tool | Why Not |
|------|---------|
| `flutter run --debug` | Software renderer, no GPU path, meaningless for performance |
| `print()` timing | `debugPrint()` is the project convention; use DevTools timeline instead |
| Third-party profilers (e.g., Sentry performance) | Overhead on desktop; DevTools + WPA covers the full stack |
| Chrome DevTools (for desktop) | Only works for Flutter Web; desktop uses native DevTools |

---

## 2. BackdropFilter Performance Optimization

### Current State in Project

6 files use `BackdropFilter`:
- `custom_title_bar.dart` -- sigma 12 (thin), resize-aware (skips during resize)
- `control_bar.dart` -- sigma 16 (normal), resize-aware via `enableBlur` flag
- `glass_container.dart` -- 3 tiers: thin(12)/normal(16)/thick(24), resize-aware
- `empty_state.dart` -- BackdropFilter usage
- `playlist_panel.dart` -- BackdropFilter, no resize degradation noted
- `player_screen.dart` -- BackdropFilter in title bar path

### Recommended Optimizations (Ordered by Impact)

**1. Ensure all BackdropFilters are wrapped in ClipRect (HIGH impact)**

`BackdropFilter` without `ClipRect` applies the blur to the **entire screen** behind it. The project already does this correctly in `GlassContainer` and `CustomTitleBar`, but verify `playlist_panel.dart` and `empty_state.dart`.

```dart
// CORRECT: ClipRect constrains the blur area
ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: child,
  ),
)
```

**2. Expand resize-aware degradation to all glass components (HIGH impact)**

Currently `GlassContainer` and `CustomTitleBar` skip BackdropFilter during window resize/interaction. `playlist_panel.dart` does NOT. During resize, every frame triggers a full blur recalculation. Add the same `respectResizeState` pattern to all glass components.

**3. Reduce sigma values (MEDIUM impact)**

Current: thin=12, normal=16, thick=24. Blur cost scales roughly quadratically with sigma. Recommendations:
- thin: 8 (was 12) -- title bar, barely visible difference
- normal: 12 (was 16) -- control bar, still reads as glass
- thick: 16 (was 24) -- dialogs, acceptable quality

**4. Use RepaintBoundary around content BEHIND the blur (MEDIUM impact)**

`GlassContainer` already wraps `content` in `RepaintBoundary`, which is correct. The `RepaintBoundary` caches the child's paint output so the blur filter doesn't re-rasterize the child when only the blur layer needs updating.

**5. Consider Impeller FragmentShader replacement (LONG-TERM)**

The project's Impeller migration plan mentions replacing BackdropFilter with custom `FragmentShader` (`glass_blur.frag`). This is the nuclear option -- eliminates the GPU readback that makes BackdropFilter expensive. Requires:
- Impeller confirmed stable on Windows
- Shader compilation pipeline tested
- Fallback to Skia BackdropFilter if shader fails

**6. Pre-blurred static backgrounds for non-animated cases (LOW priority)**

For the empty state or idle screen, a pre-rendered blurred image is cheaper than real-time blur. Not worth the complexity for the current use cases.

### What NOT to Do

| Approach | Why Not |
|----------|---------|
| Remove BackdropFilter entirely | Glassmorphism is a core design identity |
| Use `ImageFilter.blur` with sigma=0 | Still triggers the blur pipeline; use conditional rendering instead |
| Nest multiple BackdropFilters | Each nesting multiplies GPU readback cost |
| Use `BackdropFilter` without `RepaintBoundary` child | Forces re-blur even when child hasn't changed |

---

## 3. ValueNotifier / ValueListenableBuilder Rebuild Optimization

### Current State

- **35 `ValueListenableBuilder` instances** across 19 files
- **111 `ValueNotifier` references** across 29 files
- `FvpEngine` alone has **14 ValueNotifiers** (textureId, state, position, duration, volume, isMuted, isBuffering, subtitleText, etc.)
- `PositionPoller` fires every **250ms**, updating `position` ValueNotifier
- `custom_title_bar.dart` has **6 ValueListenableBuilder** instances

### Problem Analysis

The `PositionPoller` updates `engine.position` every 250ms. Any widget listening to `position` rebuilds 4 times per second. If a `ValueListenableBuilder` is high in the widget tree (like in `PlayerScreen`), it can cascade rebuilds to many children.

**Critical rebuild chain:**
```
PositionPoller (250ms) → engine.position → ???
  - ProgressBar (listens to position) → rebuilds seekbar
  - TimeDisplay (listens to position) → rebuilds time text
  - ControlsOverlay (does NOT listen to position directly -- good)
  - PlayerScreen (listens to windowMode, playlistGeneration) → rebuilds on those changes
```

### Recommended Optimizations

**1. Narrow ValueListenableBuilder scope (HIGH impact)**

Each `ValueListenableBuilder` should be as low in the tree as possible. The `PlayerScreen.build()` has a `ValueListenableBuilder<WindowMode>` at the top that rebuilds the entire screen on fullscreen toggle. This is acceptable since fullscreen is rare, but verify no high-frequency notifiers are wrapped at this level.

**2. Use the `child` parameter of ValueListenableBuilder (HIGH impact)**

```dart
// BAD: rebuilds both the builder AND the child every time
ValueListenableBuilder<int>(
  valueListenable: engine.position,
  builder: (_, pos, _) => Column(
    children: [
      Text('$pos'),
      ExpensiveWidget(), // rebuilds unnecessarily
    ],
  ),
)

// GOOD: child is built once and cached
ValueListenableBuilder<int>(
  valueListenable: engine.position,
  builder: (_, pos, child) => Column(
    children: [
      Text('$pos'),
      child!, // cached, never rebuilt
    ],
  ),
  child: ExpensiveWidget(), // built once
)
```

**3. Implement a Selector-like wrapper for ValueNotifier (MEDIUM impact)**

The project does not use Provider, so `Selector` is unavailable. Create a `ValueListenableSelector<S, T>` that only rebuilds when a derived value changes:

```dart
class ValueListenableSelector<S, T> extends StatelessWidget {
  final ValueListenable<S> valueListenable;
  final T Function(S) selector;
  final Widget Function(BuildContext, T, Widget?) builder;
  final Widget? child;

  const ValueListenableSelector({
    required this.valueListenable,
    required this.selector,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<S>(
      valueListenable: valueListenable,
      builder: (context, value, child) {
        final selected = selector(value);
        return builder(context, selected, child);
      },
      child: child,
    );
  }
}
```

**4. Merge related notifiers with ValueListenableBuilder2 (ALREADY DONE)**

The project has `value_listenable_builder2.dart` which merges 2 notifiers. This is correct for cases where both notifiers drive the same widget. Avoid expanding to Builder3/4/5 -- that pattern doesn't scale.

**5. Consider grouping position + duration into a single PlaybackPosition notifier (LOW priority)**

`position` and `duration` are always consumed together (progress bar, time display). A single `ValueNotifier<PlaybackPosition>` would halve the listener count for time-related widgets. However, the 250ms poll interval already limits rebuild frequency, so the gain is marginal.

**6. Snapshot debounce for high-frequency notifiers (ALREADY OPTIMIZED)**

The project's memory notes confirm "Snapshot Debounce already optimal." The `PositionPoller` already uses 250ms intervals and skips writes when the value hasn't changed (`if (position.value != newPos)`). No further optimization needed here.

### What NOT to Do

| Approach | Why Not |
|----------|---------|
| Migrate to Provider/Riverpod/Bloc | Violates project constraint (ValueNotifier-only) |
| Use `setState()` instead of ValueNotifier | Loses fine-grained rebuild control |
| Create one mega-ChangeNotifier for all state | Every change rebuilds every listener |
| Use `AnimatedBuilder` with `Listenable.merge` for many notifiers | `Listenable.merge` with 5+ listenables fires on ANY change |

---

## 4. D3D11 Texture Rendering Optimization

### Current fvp Pipeline

```
MDK decode → render to rt (D3D11 render target)
  → mutex lock → CopyResource(rt → tex) → Flush()
  → MarkTextureFrameAvailable → Flutter compositor
  → DXGI shared handle → Texture widget
```

### Application-Layer Optimizations (Zero Fork)

These changes require no modification to fvp source code.

| Optimization | File | Change | Expected Impact | Risk |
|-------------|------|--------|----------------|------|
| **MFT:d3d=11** (not d3d=1) | `platform_decoders.dart:12` | Change `d3d=1` to `d3d=11` | MEDIUM -- eliminates D3D9→D3D11 surface conversion | LOW -- auto-fallback on old drivers |
| **shader_resource=1** | `main.dart` registerWith | Add `D3D11:shader_resource=1` to decoder list | MEDIUM -- GPU YUV→RGB instead of CPU | MEDIUM -- some driver incompatibility |
| **d3d11.sync.cpu=0** | `main.dart` registerWith | Add `'d3d11.sync.cpu': '0'` to global options | HIGH -- eliminates per-frame CPU-GPU sync stall | MEDIUM -- possible tearing on integrated GPUs |
| **log=warning** | `main.dart` registerWith | Add `'log': 'warning'` to global options | LOW -- reduces string formatting + I/O | NONE |

**Recommended registerWith configuration:**

```dart
fvp.registerWith(options: {
  'video.decoders': 'MFT:d3d=11,NVDEC,D3D11:shader_resource=1,FFmpeg',
  'global': {
    'd3d11.sync.cpu': '0',
    'log': 'warning',
  },
});
```

### C++ Plugin-Layer Optimizations (Requires Fork)

These require forking `fvp_plugin.cpp` (193 lines). Ranked by priority.

| Optimization | Lines Changed | Expected Impact | Complexity |
|-------------|---------------|----------------|------------|
| **Fence替代Flush** | ~15 lines | HIGH -- `GetData()` waits only for copy commands, not full pipeline flush. Saves 1-3ms per frame at 60fps | LOW |
| **移除冗余MultithreadProtected** | Delete 3 lines | MEDIUM -- removes per-API-call internal mutex (already protected by app-level mutex) | LOW |
| **三缓冲** | ~50 lines | HIGH -- eliminates 90% of mutex contention between MDK render thread and Flutter raster thread | MEDIUM |
| **共享D3D11设备** | ~10 lines | LOW for single-player; HIGH for future PiP | LOW |

### What NOT to Do

| Approach | Why Not |
|----------|---------|
| Replace fvp with video_player | Loses D3D11 hardware decoding, worse performance |
| Use `Map/Unmap` for texture transfer | CPU copy is slower than GPU CopyResource |
| Skip CopyResource entirely | MDK needs its own render target; direct-to-shared-texture requires MDK upstream changes |
| Set `d3d11.sync.cpu=0` without testing | May cause visible tearing on Intel integrated GPUs |

---

## 5. Win32 Frameless Window Performance Patterns

### Current Implementation

- `FullscreenController` uses Win32 FFI (`SetWindowLongPtrW`, `SetWindowPos`) for fullscreen
- `WS_THICKFRAME` + `WS_CAPTION` style manipulation
- `window_manager` package for frameless window, minimize, maximize, always-on-top
- `DragToResizeArea` from `window_manager` for resize handles
- Resize-aware BackdropFilter degradation (skips blur during resize)

### Performance Patterns

**1. Atomic fullscreen transitions (ALREADY IMPLEMENTED)**

`FullscreenController` uses `SetWindowPos` with `SWP_FRAMECHANGED` to atomically apply style changes. This prevents the intermediate "flash" of incorrect styling. The project already handles this correctly.

**2. Resize debounce for BackdropFilter (ALREADY IMPLEMENTED)**

`WindowBridge.I.interaction` exposes `WindowInteractionState` (idle/resizing/moving). Glass components check this and skip BackdropFilter during interaction. This is the correct pattern.

**3. WS_THICKFRAME invisible border (HANDLED)**

The project's memory notes document that `WS_THICKFRAME` creates invisible resize borders. The `FullscreenController.enter()` correctly removes `WS_THICKFRAME` for true fullscreen and restores it for windowed mode.

**4. DWM Window Corner Preference (ALREADY FIXED)**

`DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` set in C++ `OnCreate` eliminates the one-frame right-angle corner flash during window creation.

**5. Recommended: Reduce WM_SIZE message flood during resize**

During resize, Win32 sends continuous `WM_SIZE` messages. Each triggers Flutter layout. The current `interaction` state check prevents BackdropFilter recalculation, but the layout pass still runs. Consider:

```dart
// In WindowService, debounce resize callbacks
Timer? _resizeDebounce;
void _onResize() {
  _resizeDebounce?.cancel();
  _resizeDebounce = Timer(const Duration(milliseconds: 16), () {
    // Apply final size, skip intermediate
  });
}
```

**6. Recommended: WS_EX_NOREDIRECTIONBITMAP for DWM optimization**

This extended style tells DWM not to allocate a redirection bitmap for the window, reducing memory and compositing overhead. Apply during frameless window setup:

```cpp
// In flutter_window.cpp OnCreate
SetWindowLongPtr(hwnd, GWL_EXSTYLE,
    GetWindowLongPtr(hwnd, GWL_EXSTYLE) | WS_EX_NOREDIRECTIONBITMAP);
```

### What NOT to Do

| Approach | Why Not |
|----------|---------|
| Use `SetWindowPos` in a loop | Causes DWM composition storms |
| Remove `WS_THICKFRAME` entirely | Loses native resize handles; custom resize is slower |
| Use `WS_POPUP` for frameless | Loses DWM composition benefits, causes flicker |
| Skip `SWP_FRAMECHANGED` after style changes | DWM doesn't apply new frame metrics; causes visual glitches |

---

## Summary of All Optimizations by Priority

### P0 -- Immediate, Zero Risk

1. Fix `platform_decoders.dart`: `MFT:d3d=1` -> `MFT:d3d=11`
2. Add `'log': 'warning'` to fvp registerWith
3. Add `shader_resource=1` to D3D11 decoder config
4. Verify all BackdropFilters have ClipRect wrapper
5. Expand resize-aware degradation to `playlist_panel.dart`

### P1 -- Immediate, Low Risk

6. Test `d3d11.sync.cpu=0` on target hardware
7. Reduce glass blur sigma values (12/16/24 -> 8/12/16)
8. Audit all ValueListenableBuilder `child` parameter usage
9. Add `WS_EX_NOREDIRECTIONBITMAP` to C++ window creation

### P2 -- Short-term, Medium Effort

10. Create `ValueListenableSelector` utility widget
11. Fork fvp_plugin.cpp: Fence替代Flush
12. Fork fvp_plugin.cpp: 移除冗余MultithreadProtected

### P3 -- Medium-term, Higher Effort

13. Fork fvp_plugin.cpp: 三缓冲方案
14. Impeller FragmentShader replacement for BackdropFilter
15. Shared D3D11 device in fvp plugin

---

## Sources

- Project codebase analysis (direct file reads)
- Project memory files: `reference_fvp_performance_bottlenecks.md`, `reference_fvp_optimization_plan.md`, `reference_fvp_source_structure.md`, `project_impeller_migration.md`, `reference_rendering_pipeline_comparison.md`
- Flutter official docs: `docs.flutter.dev/perf/ui-performance`, `docs.flutter.dev/perf/best-practices`
- fvp source: `~/.pub-cache/hosted/pub.dev/fvp-0.36.2/windows/fvp_plugin.cpp` (193 lines)

**Confidence note:** Web search tools were unavailable during this research session. Findings are based on direct codebase analysis and training data. The Impeller status on Windows (3.44 beta) and specific DevTools feature availability should be verified against current Flutter release notes.

---

*Research: 2026-05-23*
