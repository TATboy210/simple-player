# Phase 2: Profile and Measure - Research

**Researched:** 2026-05-23
**Domain:** Flutter Desktop Performance Profiling (Windows)
**Confidence:** HIGH

## Summary

Phase 2 is a measurement-only phase with zero code changes. The goal is to establish frame-level performance baselines and identify the exact root cause of title bar frame drops during window resize. The profiling targets an idle window (no video playback) to isolate UI-layer issues from decoder/rendering pipeline variables.

The primary tool is Flutter DevTools Performance view running against a `--profile` build. The key features to use are: (1) the Flutter frames chart for UI/raster thread timing, (2) "Track Widget Builds" in the Enhance Tracing dropdown for rebuild visibility, and (3) Timeline events tab for detailed frame-level analysis. Window resize (drag edge) is the reproduction trigger because it forces layout recalculation across the entire widget tree, exposing rebuild and raster bottlenecks.

Two primary hypotheses exist: (A) BackdropFilter GPU readback cost compounds during resize when 6 instances are active, and (B) ValueNotifier fan-out causes excessive widget rebuilds. The profiling data will rank these and may reveal a third cause.

**Primary recommendation:** Run `flutter run --profile -d windows`, connect DevTools, enable "Track Widget Builds", resize the window for 30+ seconds, then analyze the frames chart for jank patterns and the timeline for rebuild counts per widget.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Profile **idle window only** (no video playback) -- eliminates decoder as a variable, isolates UI-layer issues
- **D-03:** Frame time target: build+raster < 16.67ms (60fps)
- **D-04:** Jank ratio: frames exceeding 16.67ms < 5%
- **D-05:** Worst frame: < 33ms (floor at 30fps)
- **D-06:** Rebuild count: track per-second widget rebuild count to identify excessive rebuilders
- **D-07:** Primary reproduction via **window resize** (drag edge) -- triggers layout recalculation, exposes rebuild issues
- **D-09:** Use **DevTools built-in only** -- "Track Widget Rebuilds" + Timeline view. No code changes, no custom trace events, no debugPrint instrumentation
- **D-10:** Phase 2 is zero-code-change: profiling output informs Phase 3/4, not this phase

### Claude's Discretion

- Profiling duration: capture at least 30 seconds of continuous resize activity per session
- Multiple capture sessions: take 3 profiles to establish consistent baseline (not a one-off spike)
- DevTools settings: enable "Track Widget Rebuilds" in Performance settings before capture

### Deferred Ideas (OUT OF SCOPE)

- Custom Timeline instrumentation -- deferred to Phase 3/4 if DevTools built-in proves insufficient
- Video playback profiling -- deferred to follow-up if idle window shows no issues
- Automated benchmark scripts -- deferred (manual profiling sufficient for v1)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Profile title bar frame drops using `flutter run --profile -d windows` + DevTools Timeline to identify root cause (BackdropFilter vs ValueNotifier vs other) | DevTools Performance view workflow documented below; "Track Widget Builds" for rebuild identification; Timeline events for raster/UI thread split; frames chart for jank detection |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frame timing measurement | DevTools (external tool) | -- | DevTools is the only tool that shows Flutter-specific UI/raster thread split |
| Widget rebuild tracking | DevTools Performance view | -- | "Track Widget Builds" shows per-widget build() events in timeline |
| BackdropFilter cost analysis | DevTools raster thread | -- | BackdropFilter GPU readback appears as raster thread work |
| ValueNotifier fan-out analysis | DevTools + code inspection | -- | Rebuild counts in timeline + ValueListenableBuilder audit in source |
| Performance baseline documentation | RESEARCH output | -- | Captured metrics feed Phase 3/4 optimization decisions |

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Flutter DevTools | 2.57.0 (bundled with SDK 3.44.0-0.3.pre) | Frame timeline, widget rebuild tracking, GPU profiling | Only tool that shows Flutter-specific raster/UI thread split and widget rebuild counts |
| `flutter run --profile -d windows` | SDK built-in | Release-like performance with DevTools hooks | Debug mode disables optimizations and uses software renderer; profile mode is mandatory |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Performance Overlay | SDK built-in | Real-time frame time bars (green/red) | Quick visual check during development; red bars = jank |
| `dart:developer` Timeline API | SDK built-in | Custom trace events | Only if DevTools built-in proves insufficient (deferred to Phase 3/4) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DevTools Timeline | Windows Performance Analyzer (WPA) | WPA shows system-level GPU/CPU but lacks Flutter-specific widget rebuild data |
| DevTools Timeline | RenderDoc | Frame-level D3D11 debugging but no Flutter layer visibility |
| Manual profiling | Automated benchmark scripts | More reproducible but deferred to v2 per D-10 |

## Package Legitimacy Audit

> Phase 2 installs zero packages. No external dependencies beyond the Flutter SDK (already present).

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | -- | -- | -- | -- | -- | N/A |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Profiling Data Flow:

┌─────────────────────────────────────────────────────────────┐
│  flutter run --profile -d windows                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Flutter App (profile mode)                           │  │
│  │                                                       │  │
│  │  UI Thread                  Raster Thread             │  │
│  │  ┌─────────────┐          ┌─────────────────┐        │  │
│  │  │ Widget.build│          │ BackdropFilter   │        │  │
│  │  │ Layout      │ ──layer─>│ GPU readback     │        │  │
│  │  │ Paint       │   tree   │ CopyResource     │        │  │
│  │  └─────────────┘          └─────────────────┘        │  │
│  │       ▲                                                │  │
│  │       │ ValueNotifier.notifyListeners()                │  │
│  │  ┌────┴────────────────────────────────┐              │  │
│  │  │ 35x ValueListenableBuilder         │              │  │
│  │  │ (position, volume, state, ...)      │              │  │
│  │  └─────────────────────────────────────┘              │  │
│  └───────────────────────────────────────────────────────┘  │
│                           │                                  │
│                    VM Service Protocol                       │
│                           │                                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  DevTools (browser)                                   │  │
│  │  ┌───────────────┐  ┌──────────────┐  ┌───────────┐  │  │
│  │  │ Frames Chart  │  │ Frame Analys.│  │ Timeline  │  │  │
│  │  │ (UI/Raster    │  │ (hints)      │  │ (events)  │  │  │
│  │  │  bars)        │  │              │  │           │  │  │
│  │  └───────────────┘  └──────────────┘  └───────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Files to Profile

| File | Role | Why Profile |
|------|------|-------------|
| `lib/ui/player/custom_title_bar.dart` | Title bar widget (glass, drag, controls) | Primary jitter target; has 3x ValueListenableBuilder (interaction, ratioNotifier, isAlwaysOnTop, isMaximized) + 1x BackdropFilter |
| `lib/ui/player/player_screen.dart` | Main screen Stack compositing | Layout root; has ValueListenableBuilder<WindowMode> at top that rebuilds entire screen on fullscreen toggle |
| `lib/ui/player/controls_overlay.dart` | Auto-hide control layer | Has ValueListenableBuilder<bool> for visibility + passes engine to ControlBar |
| `lib/ui/player/control_bar.dart` | Bottom glass bar | BackdropFilter via GlassContainer; passes engine to child widgets |
| `lib/ui/shared/glass_container.dart` | Glassmorphism wrapper | BackdropFilter source; resize-aware degradation pattern |

### ValueNotifier Sources (Potential Rebuild Triggers)

| Source | Notifiers | Update Frequency | Impact |
|--------|-----------|------------------|--------|
| `WindowBridge.I.interaction` | WindowInteractionState | On resize start/end | Triggers title bar + glass container rebuilds |
| `WindowBridge.I.mode` | WindowMode | On fullscreen toggle | Triggers PlayerScreen rebuild (entire tree) |
| `WindowBridge.I.isMaximized` | bool | On maximize/restore | Triggers title bar button rebuild |
| `WindowBridge.I.isAlwaysOnTop` | bool | On pin toggle | Triggers title bar button rebuild |
| `AspectRatioService.I.ratioNotifier` | double | On ratio change | Triggers title bar aspect ratio button rebuild |
| `engine.state` | MediaState | On play/pause/stop | Triggers ControlsOverlay + EmptyState rebuilds |
| `engine.position` | int | 250ms poller (4Hz) | Triggers ProgressBar + TimeDisplay rebuilds |
| `_playlistVisible` (local) | bool | On playlist toggle | Triggers PlayerScreen Stack rebuild |

### BackdropFilter Usage Points (6 total)

| Location | Sigma | Resize-Aware | ClipRect |
|----------|-------|--------------|----------|
| `custom_title_bar.dart` | 12 (thin) | Yes (skips during resize) | Yes |
| `control_bar.dart` (via GlassContainer) | 16 (normal) | Yes (enableBlur flag) | Yes |
| `playlist_panel.dart` | unknown | needs verification | needs verification |
| `empty_state.dart` | unknown | needs verification | needs verification |
| `settings_panel.dart` | unknown | needs verification | needs verification |
| `osd_overlay.dart` | unknown | needs verification | needs verification |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Frame timing | Custom Stopwatch in build() | DevTools Timeline | Custom timing adds overhead and misses raster thread data |
| Widget rebuild counting | debugPrint in every build() | DevTools "Track Widget Builds" | DebugPrint adds I/O overhead; DevTools shows rebuilds without code changes |
| GPU profiling | RenderDoc capture | DevTools raster thread bars | RenderDoc is D3D11-level, not Flutter-layer; DevTools shows the Flutter-specific cost |
| Performance snapshot | Manual notes | DevTools Export button | Export produces a JSON snapshot that can be re-imported for comparison |

**Key insight:** This phase is zero-code-change by design (D-10). All instrumentation comes from DevTools built-in features. Any suggestion to add debugPrint, custom Timeline events, or Stopwatch wrappers contradicts the locked decision.

## Common Pitfalls

### Pitfall 1: Profiling in Debug Mode

**What goes wrong:** Running `flutter run -d windows` without `--profile` uses debug mode, which disables AOT compilation and uses a software renderer fallback on Windows. All frame timing data is meaningless.

**Why it happens:** Debug mode is the default; `--profile` must be explicitly specified.

**How to avoid:** Always use `flutter run --profile -d windows`. The command is: `D:\flutter\bin\flutter run --profile -d windows` (Flutter is at `D:\flutter\bin\flutter`, not in PATH).

**Warning signs:** Frame times consistently >30ms, or "debug" banner visible in app.

### Pitfall 2: Not Enabling "Track Widget Builds" Before Capture

**What goes wrong:** The Timeline events tab shows framework events but NOT per-widget build() calls unless "Track Widget Builds" is explicitly enabled in the Enhance Tracing dropdown.

**Why it happens:** The option is off by default because it adds overhead. It must be enabled before reproducing the issue.

**How to avoid:** In DevTools Performance view, click "Enhance Tracing" dropdown, check "Track Widget Builds". Then reproduce the resize issue. The timeline will show `build` events with widget class names.

**Warning signs:** Timeline shows `Layout` and `Paint` events but no `build` events for individual widgets.

### Pitfall 3: Measuring During Initial Shader Compilation

**What goes wrong:** First-time rendering triggers shader compilation (Skia backend), causing one-time jank that is not representative of steady-state performance.

**Why it happens:** Skia compiles GPU shaders on first use. Frames with shader compilation are marked in dark red in the frames chart.

**How to avoid:** Interact with the app for 5-10 seconds before starting the actual profiling capture. Ignore the first few frames. Alternatively, check if Impeller is active (Flutter 3.44 beta may use Impeller on Windows by default, which eliminates shader compilation jank).

**Warning signs:** Dark red frames in the frames chart during the first few seconds of interaction.

### Pitfall 4: Confusing UI Thread vs Raster Thread Jank

**What goes wrong:** Seeing jank in the frames chart but misidentifying which thread is the bottleneck.

**Why it happens:** The frames chart shows two bars per frame (UI + Raster). A frame is janky if EITHER bar exceeds 16.67ms. The root cause differs by thread.

**How to avoid:**
- **UI thread jank (left bar red):** Caused by expensive build(), layout, or paint operations. Likely from ValueNotifier rebuild storms.
- **Raster thread jank (right bar red):** Caused by expensive GPU operations. Likely from BackdropFilter readback or complex clipping.
- If BOTH are red, the UI thread is blocking the raster thread (cascading delay).

**Warning signs:** Raster-only jank during resize points to BackdropFilter. UI-only jank points to rebuild storms.

### Pitfall 5: Single Profiling Session as Baseline

**What goes wrong:** Taking one 10-second capture and treating it as the baseline. Random background processes, GC pauses, or OS scheduling can cause one-off spikes.

**Why it happens:** Desktop systems have variable background load.

**How to avoid:** Take 3 profiling sessions of 30+ seconds each. Compare jank ratios and worst-frame metrics across sessions. Use the median values as baseline. D-06 in CONTEXT.md requires this.

**Warning signs:** One session shows 2% jank, another shows 15%. The true baseline is likely around 8% -- investigate the variance.

### Pitfall 6: Resize Speed Affects Results

**What goes wrong:** Slow, careful resize produces fewer frames and less jank than fast, aggressive resize. Different testers get different results.

**Why it happens:** Frame count during resize depends on how fast the window edge is dragged.

**How to avoid:** Standardize the resize speed: drag the window edge at a consistent moderate speed for 30 seconds. Document the resize speed in the profiling notes. If possible, use keyboard shortcut (Win+Arrow) for reproducible resize, though this may not trigger the same layout path as mouse drag.

**Warning signs:** Jank ratio varies wildly between sessions with no code changes.

## Code Examples

Verified patterns from official sources:

### Running Profile Mode on Windows

```bash
# Flutter is at D:\flutter\bin\flutter (not in PATH)
D:\flutter\bin\flutter run --profile -d windows
```

[VERIFIED: Flutter SDK at D:\flutter\bin\flutter, version 3.44.0-0.3.pre beta]

### Connecting DevTools

After `flutter run --profile` starts, the console output includes:
```
An Observatory debugger and profiler on Windows is available at: http://127.0.0.1:XXXXX/XXXXXXX=/
The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:9100?uri=...
```

Open the DevTools URL in a browser. Navigate to the "Performance" tab.

[CITED: docs.flutter.dev/tools/devtools/performance]

### Enabling Track Widget Builds

In DevTools Performance view:
1. Click "Enhance Tracing" dropdown (above the timeline)
2. Check "Track Widget Builds"
3. Reproduce the issue (resize window for 30+ seconds)
4. The timeline will now show `build()` events with widget class names

[CITED: docs.flutter.dev/tools/devtools/performance -- "Track widget builds" section]

### Exporting Performance Snapshot

In DevTools Performance view:
1. Click the export button (upper-right corner above the frame rendering chart)
2. Downloads a JSON snapshot of current performance data
3. Can be re-imported by dragging the file into DevTools from any page

Note: DevTools only supports importing files that were originally exported from DevTools.

[CITED: docs.flutter.dev/tools/devtools/performance -- "Import and export" section]

### Disabling Rendering Layers for Isolation

In DevTools Performance view, under "More debugging options":
- **Render Clip layers** -- disable to check if excessive clipping affects performance
- **Render Opacity layers** -- disable to check if opacity effects affect performance
- **Render Physical Shape layers** -- disable to check if shadows/elevation affect performance

If raster time significantly decreases with a layer disabled, that effect is contributing to jank.

[CITED: docs.flutter.dev/tools/devtools/performance -- "More debugging options" section]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `debugProfileBuildsEnabled` flag in code | "Track Widget Builds" checkbox in DevTools | DevTools 2.x | No code changes needed; toggle from DevTools UI |
| Performance Overlay only | DevTools Performance view + Frames chart | DevTools 2.x | Detailed per-frame analysis with export/import |
| Manual frame counting | Automatic jank detection (red frames) | DevTools 2.x | Jank ratio calculable from frames chart data |

**Deprecated/outdated:**
- `debugProfileBuildsEnabled` as a code-level flag: superseded by DevTools "Track Widget Builds" toggle. Still exists in the framework but the DevTools UI approach is preferred for zero-code-change profiling.
- `flutter run --trace-startup`: useful for startup timing but not relevant for steady-state frame profiling.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Flutter 3.44 beta uses Impeller on Windows by default | Pitfall 3 | If Skia is still default, shader compilation jank will appear in first frames and must be excluded from baseline |
| A2 | DevTools 2.57.0 "Track Widget Builds" shows widget class names in timeline | Pitfall 2 | If the feature changed in this version, rebuild identification methodology changes |
| A3 | Window resize via mouse drag triggers the same layout path as programmatic resize | Pitfall 6 | If mouse drag has extra overhead (hit testing, cursor updates), results may not generalize |

## Open Questions

1. **Is Impeller active on Windows with Flutter 3.44.0-0.3.pre?**
   - What we know: The project's memory notes indicate Impeller may be the default on Windows in Flutter 3.44 beta, using Vulkan 1.4 with OpenGL fallback.
   - What's unclear: Whether Impeller is actually active for this specific build, and whether the `--enable-impeller` flag still exists.
   - Recommendation: Check `flutter run --verbose -d windows` output for the renderer backend in use. If Impeller is active, shader compilation jank is eliminated. If Skia, first-frame shader compilation must be excluded from baseline.

2. **Do all 6 BackdropFilter instances fire during resize?**
   - What we know: CustomTitleBar and GlassContainer have resize-aware degradation (skip BackdropFilter during resize). ControlBar passes `enableBlur: isVisible`.
   - What's unclear: Whether playlist_panel, empty_state, settings_panel, and osd_overlay have the same resize-awareness.
   - Recommendation: During profiling, visually confirm which glass components remain blurred during resize. Check source code for `respectResizeState` or `interaction` listener patterns in those files.

3. **What is the actual jank ratio on the user's hardware?**
   - What we know: The user reports title bar frame drops/jitter. No quantitative baseline exists yet.
   - What's unclear: Whether jank is 5% (acceptable) or 30% (severe), and whether it's UI-thread or raster-thread dominated.
   - Recommendation: This is exactly what Phase 2 resolves. Run 3 profiling sessions and document the results.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Profiling build | Yes | 3.44.0-0.3.pre beta | -- |
| DevTools | Performance view | Yes (bundled) | 2.57.0 | -- |
| Windows desktop target | `flutter run -d windows` | Yes | Windows 11 10.0.26200 | -- |
| Chrome/Edge browser | DevTools UI | Yes (assumed) | -- | DevTools can open in any browser |

**Missing dependencies with no fallback:** none

**Missing dependencies with fallback:** none

## Validation Architecture

> nyquist_validation is enabled in config.json. However, Phase 2 is a measurement-only phase with zero code changes. No test files are created or modified. Validation architecture is documented here for completeness but has no actionable items.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with SDK) |
| Config file | none -- tests exist in `test/` directory |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01 | Profiling data collected and documented | manual-only | N/A -- requires human interaction with DevTools | N/A |

### Sampling Rate

- **Per task commit:** N/A (no code changes)
- **Per wave merge:** N/A (no code changes)
- **Phase gate:** Profiling data documented in task summary before `/gsd:verify-work`

### Wave 0 Gaps

None -- Phase 2 creates no code or test files. The "test" is the profiling data itself, which is manually verified.

## Security Domain

> Phase 2 is measurement-only with zero code changes. No security-relevant modifications are made. Security domain is documented for completeness but has no actionable items.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | -- |
| V3 Session Management | no | -- |
| V4 Access Control | no | -- |
| V5 Input Validation | no | -- |
| V6 Cryptography | no | -- |

### Known Threat Patterns for Flutter Desktop Profiling

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| DevTools exposes VM service port | Information Disclosure | DevTools only binds to localhost by default; no external exposure |

## Sources

### Primary (HIGH confidence)
- [CITED: docs.flutter.dev/tools/devtools/performance] -- DevTools Performance view workflow, Track Widget Builds, Enhance Tracing, Import/Export
- [CITED: docs.flutter.dev/perf/ui-performance] -- Profile mode requirement, Performance Overlay, UI/GPU graph interpretation
- [VERIFIED: Flutter SDK at D:\flutter\bin\flutter] -- Version 3.44.0-0.3.pre, DevTools 2.57.0, Dart 3.12.0
- [VERIFIED: project codebase] -- custom_title_bar.dart, player_screen.dart, controls_overlay.dart, control_bar.dart, glass_container.dart, main.dart

### Secondary (MEDIUM confidence)
- `.planning/research/STACK.md` -- DevTools profiling workflow, fvp rendering pipeline analysis (researched 2026-05-23)
- `.planning/research/PITFALLS.md` -- BackdropFilter GPU readback, ValueNotifier fan-out (researched 2026-05-23)
- `.planning/codebase/CONCERNS.md` -- Performance Bottlenecks section, ValueNotifier Fan-Out (researched 2026-05-23)

### Tertiary (LOW confidence)
- [ASSUMED] -- Impeller default status on Windows Flutter 3.44 beta (project memory notes, not verified against current build)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- DevTools is the only option for Flutter profiling; version verified against installed SDK
- Architecture: HIGH -- widget tree structure verified by reading source files
- Pitfalls: HIGH -- based on official Flutter docs and project-specific prior bug analysis

**Research date:** 2026-05-23
**Valid until:** 2026-06-23 (30 days -- Flutter DevTools features are stable within a SDK version)
