---
phase: 11-performance-optimization
plan: 04
subsystem: ui/rendering
tags: [repaint-boundary, texture, widget-tree, video-surface, rendering-pipeline, audit]

# Dependency graph
requires:
  - phase: 11-performance-optimization
    provides: "LRU cache (01), adaptive poller (02), D3D11 sync (03)"
provides:
  - "Rendering pipeline audit confirming VideoSurface rebuilds are minimal and RepaintBoundary placement is optimal"
  - "Phase 11 verification: all 4 optimizations verified working together"
affects: [video-surface, controls-overlay, player-screen]

# Tech tracking
tech-stack:
  added: []
  patterns: [repaint-boundary-isolation, texture-layer-compositing]

key-files:
  created: []
  modified: []

key-decisions:
  - "No code changes needed — rendering pipeline already optimally structured"
  - "RepaintBoundary placement confirmed: video and controls are independently isolated"

patterns-established:
  - "Audit-first pattern: verify before optimizing to avoid unnecessary changes"

requirements-completed: [PERF-04]

# Metrics
duration: 5min
completed: 2026-05-30
---

# Phase 11 Plan 04: Rendering Pipeline Audit Summary

**Rendering pipeline audit confirming VideoSurface rebuilds are minimal, RepaintBoundary isolation is optimal, and all Phase 11 optimizations verified working together**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-30
- **Completed:** 2026-05-30
- **Tasks:** 2 (1 audit + 1 checkpoint)
- **Files modified:** 0 (audit-only)

## Audit Findings

### 1. VideoSurface Rebuild Analysis

**AnimatedBuilder animation list:** `Listenable.merge([engine.textureId, engine.aspectRatio])`

| ValueNotifier | Changes when | Frequency |
|---|---|---|
| `textureId` | Video opened (after `updateTexture()`) | Once per video open |
| `aspectRatio` | Video opened (PAR correction) | Once per video open |

**Conclusion:** Minimal and necessary. No additional ValueNotifiers needed for texture rendering. The two notifiers cover exactly the data the Texture widget requires.

**No unnecessary rebuilds found.** During playback (seeking, volume changes, state transitions), neither `textureId` nor `aspectRatio` changes, so the AnimatedBuilder does not rebuild.

### 2. RepaintBoundary Placement

**Structure:**
```
Listener (scroll handler — outside boundary)
  └─ RepaintBoundary (video texture isolation)
       └─ AnimatedBuilder
            └─ SizedBox.expand
                 └─ ClipRect → FittedBox → SizedBox → Texture
```

**ControlsOverlay structure:**
```
ValueListenableBuilder<bool> (visible toggle)
  └─ RepaintBoundary (controls isolation)
       └─ Stack
            └─ OsdOverlay, FadeTransition(ControlBar), RepaintBoundary(ErrorBanner)
```

**Findings:**
- Video and controls have **separate RepaintBoundaries** — control repaints (fade animation, button hover) do NOT trigger video texture repaint
- Listener is correctly placed **outside** the video RepaintBoundary — scroll volume changes don't cause video repaints
- ErrorBanner has its own inner RepaintBoundary — error state changes are further isolated
- Texture widget has its own internal compositing layer — no additional RepaintBoundary needed

**Conclusion:** RepaintBoundary placement is optimal. Three-level isolation: video texture, controls overlay, error banner.

### 3. Widget Tree Depth

**VideoSurface chain:** Listener → RepaintBoundary → AnimatedBuilder → SizedBox.expand → ClipRect → FittedBox → SizedBox → Texture (7 levels)

| Widget | Purpose | Removable? |
|---|---|---|
| Listener | Scroll volume handler | No — must be outside RepaintBoundary |
| RepaintBoundary | Isolate video from controls | No — critical for performance |
| AnimatedBuilder | Listen to textureId + aspectRatio | No — reactive rebuild |
| SizedBox.expand | Fill available space | No — required for Stack |
| ClipRect | Clip overflow for BoxFit.contain | No — prevents visual artifacts |
| FittedBox | Scale to fit while preserving aspect ratio | No — core scaling logic |
| SizedBox | Virtual canvas for aspect ratio math | No — defines source dimensions for FittedBox |
| Texture | D3D11 texture rendering | No — engine interface |

**Conclusion:** Every widget in the chain serves a distinct purpose. No simplification possible without losing functionality.

### 4. Listener Behavior

- `onPointerSignal` callback captures `engine` reference (stable, no rebuild)
- Calls `engine.setVolume()` directly — no `setState()` or widget rebuild
- Volume change triggers `engine.volume` ValueNotifier update — handled by VolumeControls widget elsewhere

### 5. Texture Widget Behavior

- Texture widget creates a separate **texture layer** in Flutter's rendering pipeline
- Texture ID is stable during playback — assigned once per `open()` call
- No additional RepaintBoundary needed — Texture already composited independently by GPU
- fvp C++ plugin uses query fence (not Flush) — no CPU/GPU sync stall on the Flutter side

### 6. Interaction with Prior Phase 11 Optimizations

| Optimization | Interaction with Rendering Pipeline |
|---|---|
| **Plan 01: LRU Cache** | Thumbnails use separate caching, no interaction with video texture rendering |
| **Plan 02: Adaptive Poller** | Position updates trigger `position` ValueNotifier → ProgressBar rebuild only, not VideoSurface |
| **Plan 03: D3D11 Sync** | Affects C++ rendering pipeline directly — `d3d11.sync.cpu` controls GPU fence behavior, transparent to Flutter widget tree |

**Conclusion:** All 4 Phase 11 optimizations are orthogonal — they address different layers (cache, polling, GPU sync, widget rendering) without interference.

## Task Commits

Audit-only plan — no code changes, no commits.

## Files Created/Modified

None — read-only audit.

## Decisions Made

- No code changes needed — rendering pipeline already optimally structured
- RepaintBoundary placement confirmed as optimal (video + controls + error banner isolated)

## Deviations from Plan

None — audit confirmed all findings match plan expectations.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Phase 11 Verification Checklist

- [x] **Plan 01: LRU Cache** — LinkedHashMap O(1) touch/evict, 11 tests passing
- [x] **Plan 02: Adaptive Poller** — 100ms active / 250ms normal, seeking auto-triggers
- [x] **Plan 03: D3D11 Sync** — EnumDisplaySettings FFI, refresh-rate-aware sync mode, 7 tests
- [x] **Plan 04: Rendering Audit** — VideoSurface rebuilds minimal, RepaintBoundary optimal, no changes needed

**Combined verification:**
- `flutter analyze` — 4 pre-existing issues (0 in Phase 11 files)
- All optimizations target independent layers — no interaction risks
- Widget tree is well-structured with proper isolation boundaries

## Next Phase Readiness

- Phase 11 performance optimization complete (all 4 plans)
- Rendering pipeline verified as production-ready
- Ready for next phase in project roadmap

---
*Phase: 11-performance-optimization*
*Completed: 2026-05-30*
