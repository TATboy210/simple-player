---
phase: 02-profile-and-measure
plan: 01
type: execute
wave: 1
depends_on:
  - "01-01"
files_modified:
  - .planning/phases/02-profile-and-measure/PROFILING.md
autonomous: false
requirements:
  - PERF-01
must_haves:
  truths:
    - "Idle window (no video) shows measurable frame timing data with jank ratio < 5%"
    - "Window resize triggers layout recalculation and exposes rebuild bottlenecks"
    - "Root cause of title bar jitter is identified (BackdropFilter vs ValueNotifier vs other)"
    - "Ranked list of worst rebuild offenders exists with widget names and trigger notifiers"
  artifacts:
    - path: ".planning/phases/02-profile-and-measure/PROFILING.md"
      provides: "Baseline metrics, resize profiling data, root cause analysis"
      contains: "Idle Baseline"
  key_links:
    - from: "PROFILING.md baseline metrics"
      to: "Phase 3 d3d11.sync.cpu=0 validation"
      via: "Baseline numbers confirm/deny raster thread bottleneck"
      pattern: "Raster Thread Jank|GPU"
    - from: "PROFILING.md rebuild rankings"
      to: "Phase 4 BackdropFilter/ValueNotifier optimization"
      via: "Rebuild offender list guides which widgets to optimize first"
      pattern: "Rebuild Offenders|ValueListenableBuilder"
---

<objective>
Establish frame-level performance baselines for the idle window and identify the exact root cause of title bar frame drops during window resize, using DevTools profiling with zero code changes.

Purpose: Phase 3 (d3d11.sync.cpu=0) and Phase 4 (BackdropFilter/ValueNotifier optimization) need concrete data to prioritize fixes. Without baselines, optimization is guesswork.

Output: `.planning/phases/02-profile-and-measure/PROFILING.md` containing idle baseline metrics, 3 resize session recordings, jank ratios, worst frame times, rebuild rankings, and root cause hypothesis.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-profile-and-measure/02-CONTEXT.md
@.planning/phases/02-profile-and-measure/02-RESEARCH.md
</context>

<tasks>

<task type="checkpoint:human-verify">
  <name>Task 1: Launch Profile Mode and Capture Idle Baseline</name>
  <files></files>
  <read_first>
    - .planning/phases/02-profile-and-measure/02-RESEARCH.md (profiling workflow, pitfalls, environment)
    - .planning/phases/02-profile-and-measure/02-CONTEXT.md (D-01 idle window, D-03-D-05 baseline targets, D-09 DevTools only)
  </read_first>
  <action>
Step 1: Create the profiling output file. Create `.planning/phases/02-profile-and-measure/PROFILING.md` with the following sections (fill in placeholder values after capture):

```
# Phase 2: Profiling Results

**Date:** [date]
**Hardware:** [your GPU/CPU]
**Flutter:** 3.44.0-0.3.pre beta
**Mode:** Profile (--profile)

## Idle Baseline

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Total frames | [N] | -- | -- |
| Jank frames (>16.67ms) | [N] | -- | -- |
| Jank ratio | [%] | < 5% | [PASS/FAIL] |
| Worst frame (ms) | [ms] | < 33ms | [PASS/FAIL] |
| Avg UI thread (ms) | [ms] | < 16.67ms | -- |
| Avg Raster thread (ms) | [ms] | < 16.67ms | -- |
| Renderer | [Impeller/Skia] | -- | -- |

### Idle Notes
[observations about idle state behavior]

## Resize Profiling

### Session 1
| Metric | Value |
|--------|-------|
| Duration | [seconds] |
| Total frames | [N] |
| Jank frames | [N] |
| Jank ratio | [%] |
| Worst frame (ms) | [ms] |
| UI thread dominant jank | [N frames] |
| Raster thread dominant jank | [N frames] |

### Session 2
[same table]

### Session 3
[same table]

### Resize Notes
[observations about resize behavior, visual jitter]

## Rebuild Analysis

### Top Rebuild Offenders
| Rank | Widget | Rebuild Count | Trigger Notifier |
|------|--------|---------------|------------------|
| 1 | [widget] | [count] | [notifier] |
| 2 | [widget] | [count] | [notifier] |
| 3 | [widget] | [count] | [notifier] |
| ... | ... | ... | ... |

### Rebuild Notes
[which widgets rebuild unnecessarily, which notifiers cause cascading rebuilds]

## Root Cause Analysis

### Hypothesis A: BackdropFilter GPU Readback
[Evidence for/against]

### Hypothesis B: ValueNotifier Fan-Out
[Evidence for/against]

### Other Observations
[any third cause discovered]

### Conclusion
[root cause verdict with evidence]
```

Step 2: Launch the app in profile mode. Open a terminal and run:

```
D:\flutter\bin\flutter run --profile -d windows
```

Wait for the console to print the DevTools URL (looks like `The Flutter DevTools debugger and profiler on Windows is available at: http://127.0.0.1:9100?uri=...`).

Step 3: Open DevTools. Copy the URL from the console output and open it in a browser. Navigate to the "Performance" tab.

Step 4: Warm up. Interact with the app for 5-10 seconds (move mouse, hover over controls) to get past initial shader compilation frames. Ignore the first few frames in the frames chart.

Step 5: Capture idle baseline. With the app idle (no mouse movement, no resize), click "Clear" in DevTools to reset the timeline. Wait 30 seconds with the window completely idle. Click "Stop" to end recording.

Step 6: Record idle baseline metrics in PROFILING.md:
- Count total frames in the frames chart
- Count jank frames (red bars, exceeding 16.67ms)
- Calculate jank ratio: jank_frames / total_frames * 100
- Note worst frame time from the frames chart
- Check if renderer is Impeller or Skia (visible in console output or DevTools)
- Note whether there is any spontaneous jitter in the idle state (D-08)
  </action>
  <verify>
    <human-check>
      1. App launches without crash in profile mode (no "debug" banner visible)
      2. DevTools connects and shows the frames chart with green/red bars
      3. PROFILING.md exists with "Idle Baseline" section filled in (not placeholder text)
      4. Idle baseline recorded: total frames, jank frames, jank ratio, worst frame time
      5. Idle jank ratio is below 5% (D-04 target) — if above, note in PROFILING.md
    </human-check>
  </verify>
  <acceptance_criteria>
    - PROFILING.md exists at .planning/phases/02-profile-and-measure/PROFILING.md
    - "Idle Baseline" table has numeric values (not "[N]" placeholders) for: Total frames, Jank frames, Jank ratio, Worst frame
    - Jank ratio value is a percentage number (e.g., "2.3%")
    - Worst frame value is in milliseconds (e.g., "12.4ms")
    - "Renderer" field is filled in (Impeller or Skia)
    - "Idle Notes" section has at least one sentence describing observed behavior
  </acceptance_criteria>
  <done>Idle baseline captured: jank ratio, worst frame time, renderer type documented in PROFILING.md. App confirmed stable in profile mode.</done>
</task>

<task type="checkpoint:human-verify">
  <name>Task 2: Resize Profiling Sessions and Root Cause Analysis</name>
  <files>.planning/phases/02-profile-and-measure/PROFILING.md</files>
  <read_first>
    - .planning/phases/02-profile-and-measure/02-RESEARCH.md (Pitfall 4 UI vs Raster, Pitfall 6 resize speed, Key Files to Profile, ValueNotifier Sources, BackdropFilter Usage Points)
    - .planning/phases/02-profile-and-measure/02-CONTEXT.md (D-06 rebuild count, D-07 window resize reproduction)
    - .planning/phases/02-profile-and-measure/PROFILING.md (existing idle baseline from Task 1)
  </read_first>
  <action>
Step 1: Enable widget build tracking. In DevTools Performance view, click the "Enhance Tracing" dropdown (above the timeline). Check "Track Widget Builds". This makes `build()` events visible in the timeline with widget class names.

Step 2: Resize Session 1. Click "Clear" to reset the timeline. Drag the window edge to resize the window at a moderate, consistent speed for 30+ seconds. Click "Stop" to end recording. Record in PROFILING.md Session 1 table:
- Total frames, jank frames, jank ratio, worst frame time
- For jank frames: click on red bars in the frames chart. The frame detail shows UI thread time and Raster thread time separately. Count how many jank frames are UI-dominant (UI bar red) vs Raster-dominant (Raster bar red).
- Note which widgets show `build` events in the timeline during resize. Look for widget class names like `_CustomTitleBarState`, `_PlayerScreenState`, `_ControlsOverlayState`, `_ControlBarState`, etc.

Step 3: Resize Session 2. Click "Clear" again. Resize the window again for 30+ seconds at the same moderate speed. Record Session 2 metrics. Compare with Session 1 — if jank ratios differ by more than 5 percentage points, note the variance in Resize Notes.

Step 4: Resize Session 3. Repeat for a third session. Record Session 3 metrics.

Step 5: Identify rebuild offenders. With "Track Widget Builds" still enabled, do one more short resize (10 seconds). In the timeline, look for widgets that show the most `build` events. List the top 10 most-rebuilt widgets in the "Top Rebuild Offenders" table. For each, identify which ValueNotifier likely triggered the rebuild by cross-referencing with the ValueNotifier Sources table in 02-RESEARCH.md:
- `_CustomTitleBarState` rebuilds → likely `WindowBridge.I.interaction`, `isMaximized`, `isAlwaysOnTop`, `AspectRatioService.I.ratioNotifier`
- `_PlayerScreenState` rebuilds → likely `WindowBridge.I.mode`
- `_ControlsOverlayState` rebuilds → likely `engine.state`
- `_ProgressBarState` rebuilds → likely `engine.position`

Step 6: Root cause analysis. Based on the profiling data, evaluate the two hypotheses:

Hypothesis A (BackdropFilter GPU readback): If Raster thread jank dominates during resize, and disabling BackdropFilter-related rendering layers in DevTools ("More debugging options" → uncheck "Render Clip layers") reduces jank, then BackdropFilter is a significant contributor.

Hypothesis B (ValueNotifier fan-out): If UI thread jank dominates, and the rebuild analysis shows many widgets rebuilding on the same notifier during resize, then ValueNotifier fan-out is the primary cause.

If both contribute, rank them by impact (which causes more jank frames).

Step 7: Finalize PROFILING.md. Fill in all remaining placeholder values. Write the Root Cause Analysis section with evidence-based conclusions. The conclusion must state which hypothesis wins (or if both contribute) with specific numbers from the profiling data.
  </action>
  <verify>
    <human-check>
      1. "Track Widget Builds" is enabled (timeline shows build events with widget names)
      2. Three resize sessions completed, each 30+ seconds
      3. PROFILING.md Session 1/2/3 tables have numeric values (not placeholders)
      4. "Top Rebuild Offenders" table has at least 5 entries with widget names and trigger notifiers
      5. "Root Cause Analysis" section has evidence-based conclusion (not placeholder text)
      6. Jank ratios are consistent across 3 sessions (within 5pp of each other) — if not, variance is documented
    </human-check>
  </verify>
  <acceptance_criteria>
    - PROFILING.md Session 1 table has numeric values for: Total frames, Jank frames, Jank ratio, Worst frame, UI thread dominant jank, Raster thread dominant jank
    - PROFILING.md Session 2 table has same numeric values
    - PROFILING.md Session 3 table has same numeric values
    - "Top Rebuild Offenders" table has at least 5 rows, each with: Widget name (e.g., "_CustomTitleBarState"), Rebuild count (number), Trigger notifier (e.g., "WindowBridge.I.interaction")
    - "Root Cause Analysis" → "Conclusion" subsection contains one of: "BackdropFilter GPU readback is the primary cause", "ValueNotifier fan-out is the primary cause", or "Both contribute — [X] is primary, [Y] is secondary"
    - Conclusion references specific numbers from profiling data (e.g., "Raster thread dominated 78% of jank frames")
  </acceptance_criteria>
  <done>Three resize profiling sessions completed. Rebuild offenders ranked. Root cause identified with evidence. PROFILING.md is complete with all baseline metrics, session data, rebuild rankings, and root cause analysis. Phase 3/4 have the data they need to prioritize fixes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| DevTools → localhost | DevTools VM service binds to localhost only; no external exposure risk |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-01 | Information Disclosure | DevTools VM service port | accept | DevTools binds to localhost by default; no user data exposed in profiling snapshots |
</threat_model>

<verification>
Phase 2 is complete when:
1. PROFILING.md exists with all sections filled in (no placeholder text remaining)
2. Idle baseline shows jank ratio < 5% (or deviation documented)
3. Three resize sessions show consistent jank ratios (within 5pp variance, or deviation documented)
4. Top rebuild offenders table has 5+ entries with widget names and trigger notifiers
5. Root cause conclusion identifies primary bottleneck with evidence from profiling data
</verification>

<success_criteria>
- PROFILING.md contains concrete baseline numbers (not placeholders) for idle state and 3 resize sessions
- Root cause of title bar jitter identified: either BackdropFilter GPU readback, ValueNotifier fan-out, or both with ranking
- Ranked list of worst rebuild offenders exists with widget class names and triggering ValueNotifiers
- Phase 3 (d3d11.sync.cpu=0) can proceed knowing whether raster thread is the bottleneck
- Phase 4 (BackdropFilter/ValueNotifier optimization) can proceed knowing which widgets to prioritize
</success_criteria>

<output>
Create `.planning/phases/02-profile-and-measure/02-01-SUMMARY.md` when done
</output>
