# D3D11 Async Mode Multi-Hardware Testing Template

**Purpose:** Verify `d3d11.sync.cpu=0` (async mode) produces no visible tearing on 3+ GPU configs, document fallback behavior.

**Status:** Template — fill in after testing on each hardware config.

---

## Hardware Configurations

Fill one row per test machine:

| Config | GPU Model | OS Version | Display Resolution | Driver Version | Date Tested |
|--------|-----------|------------|-------------------|----------------|-------------|
| Config 1 (Dedicated NVIDIA) | | | | | |
| Config 2 (Intel iGPU) | | | | | |
| Config 3 (AMD iGPU / Dedicated) | | | | | |
| Config 4 (Optional) | | | | | |

---

## Test Video Requirements

Minimum test videos needed:

| Video | Resolution | Codec | Frame Rate | Duration | Source |
|-------|-----------|-------|-----------|----------|-------|
| Video A | 3840x2160 (4K) | HEVC (H.265) | 30fps | 60s+ | |
| Video B | 3840x2160 (4K) | H.264 | 30fps | 60s+ | |
| Video C | 1920x1080 | HEVC (H.265) | 60fps | 60s+ | |

---

## Test Procedure (Per Config)

Execute these steps on each hardware config listed above:

1. **Launch in profile mode:**
   ```
   flutter run -d windows --profile
   ```

2. **Open 4K test video** (Video A — 4K HEVC):
   - Use File > Open or drag-and-drop
   - Document the video path: `________________`

3. **Navigate to Settings > Performance tab**

4. **Baseline test — D3D11 Sync ON (default):**
   - Verify D3D11 Sync toggle is ON (`d3d11.sync.cpu=1`)
   - Play video for 60+ seconds
   - Observe: tearing? stuttering? smooth?
   - Fill results table below

5. **Async test — D3D11 Sync OFF:**
   - Toggle D3D11 Sync OFF (`d3d11.sync.cpu=0`)
   - Play same video for 60+ seconds
   - Observe: tearing? stuttering? latency change?
   - Fill results table below

6. **Repeat with Video B** (4K H.264) — steps 4-5

7. **Repeat with Video C** (1080p HEVC) — steps 4-5

8. **Document all results** in the per-config tables below

---

## Per-Config Results

### Config 1: Dedicated NVIDIA

| Test | sync.cpu=1 (default) | sync.cpu=0 (async) |
|------|---------------------|-------------------|
| **4K HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **4K H.264** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **1080p HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| Playback smooth? | Y / N | Y / N |

**Notes:**
```
(fill in observations)


```

### Config 2: Intel iGPU

| Test | sync.cpu=1 (default) | sync.cpu=0 (async) |
|------|---------------------|-------------------|
| **4K HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **4K H.264** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **1080p HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| Playback smooth? | Y / N | Y / N |

**Notes:**
```
(fill in observations)


```

### Config 3: AMD iGPU / Dedicated

| Test | sync.cpu=1 (default) | sync.cpu=0 (async) |
|------|---------------------|-------------------|
| **4K HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **4K H.264** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| 4K playback smooth? | Y / N | Y / N |
| **1080p HEVC** | | |
| Tearing visible? | Y / N | Y / N |
| Tearing severity | none / minor / major | none / minor / major |
| Latency feel | same / better / worse | same / better / worse |
| Playback smooth? | Y / N | Y / N |

**Notes:**
```
(fill in observations)


```

---

## Fallback Decision Matrix

After completing all configs, use this matrix to decide the default behavior:

| Condition | Decision |
|-----------|----------|
| Tearing on >50% of configs | Keep sync default (d3d11.sync.cpu=1). Document async as opt-in for advanced users. |
| Tearing on <25% of configs | Consider async as default for non-4K content. Keep sync for 4K. |
| Tearing only on specific GPUs | Document per-GPU recommendation. Consider GPU detection at startup. |
| Tearing on all configs | Keep sync as default. Async mode is experimental only. |
| No tearing on any config | Async mode is safe. Consider making it the default for lower latency. |

**Decision after testing:**
```
(fill in conclusion)


```

---

## Hardware Decoding Fallback Test

While testing, also verify hardware decoding toggle:

1. Settings > Performance > Hardware Decoding ON (default)
2. Play 4K video — confirm hardware decode is active (check CPU usage — should be low)
3. Toggle Hardware Decoding OFF
4. Play same video — confirm software decode (CPU usage should be higher)
5. Document any visual artifacts or crashes

| Config | HW Decode ON (CPU%) | HW Decode OFF (CPU%) | Visual Artifacts? |
|--------|--------------------|--------------------|--------------------|
| Config 1 | | | Y / N |
| Config 2 | | | Y / N |
| Config 3 | | | Y / N |

---

_Template created: 2026-05-29_
_Plan: 03-04 (Gap Closure)_
