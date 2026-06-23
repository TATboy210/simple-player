# Phase 3: Performance Optimization - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply D3D11 hardware tuning of the fvp video texture pipeline and fix control bar UI frame drops. This is an infrastructure/optimization phase — no new features. Scope: fvp/MDK parameter tuning, control bar profiling and fix, PerfMonitor cleanup, error handling re-scan, performance benchmark creation.

</domain>

<decisions>
## Implementation Decisions

### Control Bar Root Cause (PERF-03)
- **D-01:** Profile-first strategy — use Flutter DevTools frame timeline to identify root cause before fixing
- **D-02:** Profile in `--profile` mode (not debug) for accurate measurements
- **D-03:** Frame drop threshold: 16.6ms per frame (60fps standard)
- **D-04:** Test both control bar interaction AND 4K playback scenarios, plus progress bar seek separately
- **D-05:** Test both windowed and fullscreen modes
- **D-06:** Test with subtitles enabled (realistic scenario)
- **D-07:** Verify Phase 2 BackdropFilter optimizations (opacity skip + blurEnabled) before applying new fixes
- **D-08:** Isolate BackdropFilter vs ValueNotifier impact via blurEnabled=true/false comparison test
- **D-09:** Fix strategy: comprehensive, prevention-focused — fix all bottlenecks found, not just the primary one
- **D-10:** Fix layer: Widget layer optimizations + fvp parameter adjustments (both layers)
- **D-11:** Regression verification: test suite + DevTools re-profile after each fix

### D3D11 Tuning Scope (PERF-01)
- **D-12:** Test multiple fvp/MDK parameters (not just d3d11.sync.cpu=0) — rendering + decoding parameters
- **D-13:** Testing method: single-variable first, then combination optimization
- **D-14:** Hardware priority: low-end (10-year-old PC) as primary baseline
- **D-15:** Parameter scope: D3D11 parameters first, then MDK other parameters if needed
- **D-16:** Reference both fvp/MDK docs and mpv config for parameter discovery
- **D-17:** Parameter source: fvp source code first (more authoritative than docs)
- **D-18:** Parameters: hardcoded defaults + runtime-adjustable interface (settings panel)
- **D-19:** Parameter timing: set at initialization, adjustable at runtime
- **D-20:** Verification: test suite + DevTools after each parameter change
- **D-21:** queryFence patch: included in testing scope, automate patch application in build flow

### Measurement Approach
- **D-22:** Tool: Flutter DevTools frame timeline (no Performance Overlay needed)
- **D-23:** Metrics: multi-dimensional — frame time + CPU/GPU usage + memory
- **D-24:** Targets: both 2-5ms/frame savings AND jank elimination
- **D-25:** Data aggregation: average across all scenarios
- **D-26:** Baseline: measure before optimization, then compare after
- **D-27:** Measurement frequency: every optimization point measured
- **D-28:** Automation: create DevTools profiling script (not Flutter benchmark test)
- **D-29:** Data recording: independent performance report document

### Additional Scope
- **D-30:** Error handling re-scan: check for new catch(_)/on Object catch patterns (as part of Phase 3)
- **D-31:** PerfMonitor cleanup: remove mark/markEnd dead code + fix unbounded list growth (CONCERNS #14)
- **D-32:** queryFence: automate patch application after flutter pub get
- **D-33:** Phase 2 extension: decide based on Profile data whether further BackdropFilter optimization needed
- **D-34:** Performance tests: add automated performance benchmark
- **D-35:** Test data: prepare test videos (different resolutions/codecs)
- **D-36:** Build config: decide based on data whether CMakeLists.txt changes needed
- **D-37:** User interface: add performance options to settings panel (blurEnabled, D3D11 params)
- **D-38:** fvp version: research updates before deciding whether to upgrade
- **D-39:** New dependencies: decide based on data
- **D-40:** C++ modifications: decide based on data
- **D-41:** Priority order: D3D11 tuning first, then control bar profiling

### Claude's Discretion
- Specific fvp/MDK parameter values to test (data-driven)
- RepaintBoundary placement strategy (audit-driven)
- DevTools profiling script implementation details
- Performance report format and structure
- Settings panel UI layout for performance options

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Performance & Engine
- `.planning/codebase/STACK.md` — fvp 0.36.2, D3D11 rendering pipeline, queryFence patch requirement
- `.planning/codebase/INTEGRATIONS.md` — fvp/MDK API surface, updateTexture() D3D11 sync
- `.planning/codebase/CONCERNS.md` — #2 D3D11 sync bottleneck, #14 PerfMonitor unbounded lists

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — 3-layer architecture, ValueNotifier patterns
- `.planning/codebase/CONVENTIONS.md` — widget caching, error handling patterns

### Prior Phase Context
- `.planning/phases/01-window-management/01-CONTEXT.md` — D-32/D-33 error handling decisions
- `.planning/phases/02-widget-unification/02-CONTEXT.md` — D-13 BackdropFilter skip, D-14 blurEnabled, D-15 GlassTier

### Requirements
- `.planning/REQUIREMENTS.md` — PERF-01 (D3D11 sync), PERF-03 (control bar frame drops)

### fvp Source (for parameter discovery)
- `lib/kernel/engine/fvp_engine.dart` — FvpEngine class, updateTexture() at line 323, 12 ValueNotifiers

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GlassContainer` — conditional BackdropFilter skip (opacity param) + blurEnabled degradation (Phase 2)
- `PerfMonitor` — mark/markEnd dead code to clean up, unbounded lists to fix
- `Tokens.*` — design tokens for settings panel performance options
- Flutter DevTools — frame timeline for profiling

### Established Patterns
- `_guardedAction` error handling — on Exception catch + debugPrint
- ValueNotifier + ValueListenableBuilder — standard reactive pattern
- Widget caching in ControlsOverlay — 8-field cache pattern

### Integration Points
- `fvp_engine.dart:323` — updateTexture() D3D11 sync call (profiling target)
- `glass_container.dart` — BackdropFilter with opacity/blurEnabled params (Phase 2)
- `perf_monitor.dart` — dead code cleanup target
- `settings_panel.dart` — add performance options tab

</code_context>

<specifics>
## Specific Ideas

- Low-end hardware (10-year-old PC) is the primary performance baseline — optimize for worst case
- D3D11 tuning before control bar profiling — engine-level improvements may cascade to UI
- blurEnabled comparison test is the key isolation technique for BackdropFilter vs ValueNotifier
- queryFence patch must be automated — manual application is error-prone
- Performance options should be in settings panel for user control

</specifics>

<deferred>
## Deferred Ideas

- Triple buffering in fvp C++ layer — requires fvp fork (v2 deferred)
- Impeller FragmentShader for BackdropFilter — requires Impeller stable on Windows (v2 deferred)
- Golden tests for glassmorphism components — GPU-dependent, flaky across machines (Phase 4)

</deferred>

---

*Phase: 03-Performance Optimization*
*Context gathered: 2026-05-29*
