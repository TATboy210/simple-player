# DevTools Frame Time Profiling Guide

**Purpose:** Document concrete 2-5ms/frame savings from D3D11 async mode via Flutter DevTools frame timeline.

**Status:** Template — fill in after running profiling measurements.

---

## Prerequisites

- Flutter DevTools (included with Flutter SDK)
- Profile mode build: `flutter run -d windows --profile`
- Test video: 4K HEVC recommended (same video for all measurements)
- D3D11 Sync toggle available in Settings > Performance

---

## Baseline Measurement (d3d11.sync.cpu=1, Sync Mode)

Record frame time data with default D3D11 sync mode enabled.

### Steps

1. **Launch in profile mode:**
   ```
   flutter run -d windows --profile
   ```

2. **Open DevTools** — connect to the running app

3. **Navigate to DevTools > Performance tab**

4. **Open 4K test video** — play for 10 seconds to stabilize

5. **Verify D3D11 Sync is ON** — Settings > Performance > D3D11 Sync toggle

6. **Start recording** in DevTools Performance tab

7. **Play video for 30 seconds** — idle playback, no mouse interaction

8. **Stop recording**

9. **Extract metrics** from the frame timeline:
   - Average frame time (ms)
   - P99 frame time (ms)
   - Worst frame time (ms)
   - Total frames recorded
   - Frames exceeding 16.6ms (jank frames)

10. **Fill baseline table below**

### Baseline Results

| Metric | Value |
|--------|-------|
| Average frame time (ms) | |
| P99 frame time (ms) | |
| Worst frame time (ms) | |
| Total frames recorded | |
| Jank frames (>16.6ms) | |
| Jank % | |
| Test video path | |
| Recording duration (s) | |

---

## Optimized Measurement (d3d11.sync.cpu=0, Async Mode)

Record frame time data with D3D11 async mode.

### Steps

1. **Same app instance** (or relaunch in profile mode)

2. **Toggle D3D11 Sync OFF** — Settings > Performance > D3D11 Sync

3. **Open same 4K test video** — play for 10 seconds to stabilize

4. **Start recording** in DevTools Performance tab

5. **Play video for 30 seconds** — idle playback, no mouse interaction

6. **Stop recording**

7. **Extract metrics** (same as baseline)

8. **Fill optimized table below**

### Optimized Results

| Metric | Value |
|--------|-------|
| Average frame time (ms) | |
| P99 frame time (ms) | |
| Worst frame time (ms) | |
| Total frames recorded | |
| Jank frames (>16.6ms) | |
| Jank % | |
| Test video path | |
| Recording duration (s) | |

---

## Comparison Table

Fill after completing both measurements:

| Metric | Baseline (sync) | Optimized (async) | Delta | Improvement |
|--------|----------------|-------------------|-------|-------------|
| Average frame time (ms) | | | | |
| P99 frame time (ms) | | | | |
| Worst frame time (ms) | | | | |
| Total frames recorded | | | | |
| Jank frames (>16.6ms) | | | | |
| Jank % | | | | |

**Delta = Baseline - Optimized** (positive = improvement)

**Success criteria:**
- Average frame time improvement >= 2ms with async mode
- Jank % < 5% in all scenarios
- Document any scenarios where async mode performs worse

---

## Control Bar Interaction Profiling

Separate test: measure frame time during UI interactions.

### Test Scenarios

| Scenario | Steps | Duration |
|----------|-------|----------|
| Hover over controls | Move mouse over control bar, hover on buttons | 10s |
| Seek via progress bar | Click and drag progress bar seek handle | 10s |
| Control bar fade in/out | Move mouse to trigger auto-hide, wait for fade | 10s |
| Volume adjustment | Click volume icon, drag slider | 10s |

### Per-Scenario Results

| Scenario | Total Frames | Jank Frames | Jank % | Avg Frame Time (ms) | Pass (<5% jank) |
|----------|-------------|-------------|--------|--------------------|--------------------|
| Hover over controls | | | | | Y / N |
| Seek via progress bar | | | | | Y / N |
| Control bar fade in/out | | | | | Y / N |
| Volume adjustment | | | | | Y / N |

---

## Data Recording Format (CSV)

Use this format to aggregate results across machines:

```csv
machine,gpu,os,mode,video,avg_ms,p99_ms,worst_ms,total_frames,jank_frames,jank_pct
DevMachine,Intel-UHD-Win11,sync,4k-hevc,,,,,,,,,
DevMachine,Intel-UHD-Win11,async,4k-hevc,,,,,,,,,
DevMachine,Intel-UHD-Win11,sync,4k-h264,,,,,,,,,
DevMachine,Intel-UHD-Win11,async,4k-h264,,,,,,,,,
```

**Column definitions:**
- `machine`: Identifier for the test machine
- `gpu`: GPU model (short name)
- `os`: OS version
- `mode`: `sync` (d3d11.sync.cpu=1) or `async` (d3d11.sync.cpu=0)
- `video`: Test video identifier (e.g., 4k-hevc, 4k-h264, 1080p-hevc)
- `avg_ms`: Average frame time in milliseconds
- `p99_ms`: 99th percentile frame time in milliseconds
- `worst_ms`: Worst (maximum) frame time in milliseconds
- `total_frames`: Total number of frames recorded
- `jank_frames`: Number of frames exceeding 16.6ms
- `jank_pct`: Jank percentage (jank_frames / total_frames * 100)

---

## Success Criteria Summary

| Criterion | Target | Actual | Pass |
|-----------|--------|--------|------|
| Average frame time improvement (async vs sync) | >= 2ms | | Y / N |
| Jank % in idle playback | < 5% | | Y / N |
| Jank % during hover | < 5% | | Y / N |
| Jank % during seek | < 5% | | Y / N |
| Jank % during fade animation | < 5% | | Y / N |
| No regression: async mode performs worse | None | | Y / N |

---

## Notes

- Run all measurements on the same machine for valid comparison
- Use the same test video for all measurements
- Close other applications to minimize background noise
- If DevTools shows unexpected spikes, note them in the CSV comments
- Profile mode is required for accurate frame timing (--profile flag)

---

_Template created: 2026-05-29_
_Plan: 03-04 (Gap Closure)_
