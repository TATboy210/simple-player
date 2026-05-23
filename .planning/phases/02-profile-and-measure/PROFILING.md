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
| Metric | Value |
|--------|-------|
| Duration | [seconds] |
| Total frames | [N] |
| Jank frames | [N] |
| Jank ratio | [%] |
| Worst frame (ms) | [ms] |
| UI thread dominant jank | [N frames] |
| Raster thread dominant jank | [N frames] |

### Session 3
| Metric | Value |
|--------|-------|
| Duration | [seconds] |
| Total frames | [N] |
| Jank frames | [N] |
| Jank ratio | [%] |
| Worst frame (ms) | [ms] |
| UI thread dominant jank | [N frames] |
| Raster thread dominant jank | [N frames] |

### Resize Notes
[observations about resize behavior, visual jitter]

## Rebuild Analysis

### Top Rebuild Offenders
| Rank | Widget | Rebuild Count | Trigger Notifier |
|------|--------|---------------|------------------|
| 1 | [widget] | [count] | [notifier] |
| 2 | [widget] | [count] | [notifier] |
| 3 | [widget] | [count] | [notifier] |
| 4 | [widget] | [count] | [notifier] |
| 5 | [widget] | [count] | [notifier] |

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
