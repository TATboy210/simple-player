# Phase 2: Profile and Measure - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish frame-level performance baselines and identify the exact bottleneck causing title bar frame drops. This is a measurement-only phase — no code changes, no optimizations. Output is profiling data and root cause analysis that drives Phase 3 and Phase 4 decisions.

</domain>

<decisions>
## Implementation Decisions

### Test Scenario
- **D-01:** Profile **idle window only** (no video playback) — eliminates decoder as a variable, isolates UI-layer issues
- **D-02:** If idle window shows no jitter, expand to video playback scenario as follow-up (not in initial scope)

### Baseline Metrics
- **D-03:** Frame time target: build+raster < 16.67ms (60fps)
- **D-04:** Jank ratio: frames exceeding 16.67ms < 5%
- **D-05:** Worst frame: < 33ms (floor at 30fps)
- **D-06:** Rebuild count: track per-second widget rebuild count to identify excessive rebuilders

### Reproduction Method
- **D-07:** Primary reproduction via **window resize** (drag edge) — triggers layout recalculation, exposes rebuild issues
- **D-08:** Secondary: static observation (window idle) to check for spontaneous jitter

### Instrumentation
- **D-09:** Use **DevTools built-in only** — "Track Widget Rebuilds" + Timeline view. No code changes, no custom trace events, no debugPrint instrumentation
- **D-10:** Phase 2 is zero-code-change: profiling output informs Phase 3/4, not this phase

### Claude's Discretion
- Profiling duration: capture at least 30 seconds of continuous resize activity per session
- Multiple capture sessions: take 3 profiles to establish consistent baseline (not a one-off spike)
- DevTools settings: enable "Track Widget Rebuilds" in Performance settings before capture

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Performance Analysis
- `.planning/research/STACK.md` — DevTools profiling workflow, fvp rendering pipeline analysis
- `.planning/research/PITFALLS.md` — #1 BackdropFilter GPU readback, #2 ValueNotifier fan-out
- `.planning/codebase/CONCERNS.md` — Performance Bottlenecks section, ValueNotifier Fan-Out

### Widget Architecture
- `reference_fvp_performance_bottlenecks.md`（memory）— 9 bottlenecks ranked, application-layer mitigations
- `project_widget_layer_design.md`（memory）— 22 files ~5000 lines, ValueNotifier reactive UI
- `project_floating_controlbar_design.md`（memory）— 毛玻璃悬浮控制栏，BackdropFilter usage

### Prior Decisions
- `.planning/phases/01-zero-risk-rendering-fixes/01-CONTEXT.md` — fvp config decisions (Phase 1 complete)
- `.planning/phases/01-zero-risk-rendering-fixes/01-01-SUMMARY.md` — Phase 1 results

</canonical_refs>

<code_context>
## Existing Code Insights

### Key Files to Profile
- `lib/ui/player/custom_title_bar.dart` — Title bar widget (glass, drag, controls) — primary jitter target
- `lib/ui/player/player_screen.dart` — Main screen Stack compositing — layout root
- `lib/ui/player/controls_overlay.dart` — Auto-hide control layer — ValueListenableBuilder heavy
- `lib/ui/player/control_bar.dart` — Bottom glass bar — BackdropFilter usage
- `lib/ui/shared/glass_container.dart` — Glassmorphism wrapper — BackdropFilter source

### ValueNotifier Sources
- `lib/kernel/engine/fvp_engine.dart` — Exposes ValueNotifiers for position, volume, mute, state, speed
- `lib/kernel/services/playback_controller.dart` — Orchestrates playlist + engine state
- Each ValueNotifier triggers independent widget rebuilds via ValueListenableBuilder

### BackdropFilter Usage Points
- Control bar (glass effect)
- Title bar (glass effect)
- Playlist panel (glass effect)
- Empty state (glass effect)
- Settings dialog (glass effect)
- OSD overlay (glass effect)
Total: 6 BackdropFilter instances documented in PERF-04

### Established Patterns
- `ValueListenableBuilder<T>` wraps each state-dependent widget
- `GlassContainer` provides BackdropFilter + ClipRRect wrapper
- `Tokens.*` for all visual constants (no hardcoded values)

</code_context>

<specifics>
## Specific Ideas

- DevTools "Track Widget Rebuilds" shows colored highlights on rebuilt widgets — directly visualizes the rebuild storm
- Timeline view shows UI thread, raster thread, GPU thread activity — can distinguish between build-heavy vs raster-heavy jank
- Window resize is the best reproduction because it forces layout recalculation across the entire widget tree
- If the title bar janks during resize but other widgets don't, the issue is in the title bar's build/raster path
- If all widgets jank equally, the issue is in the raster thread (likely BackdropFilter GPU readback)

</specifics>

<deferred>
## Deferred Ideas

- Custom Timeline instrumentation — deferred to Phase 3/4 if DevTools built-in proves insufficient
- Video playback profiling — deferred to follow-up if idle window shows no issues
- Automated benchmark scripts — deferred (manual profiling sufficient for v1)

</deferred>

---

*Phase: 2-Profile and Measure*
*Context gathered: 2026-05-23*
