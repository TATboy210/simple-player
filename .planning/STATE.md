---
gsd_state_version: 1.0
milestone: v1.2.1
milestone_name: Window Polish & Architecture Simplification
current_phase: 13
current_phase_name: in-progress
status: completed
stopped_at: context exhaustion at 75% (2026-06-22)
last_updated: "2026-06-22T05:53:30.178Z"
last_activity: 2026-05-31
last_activity_desc: Phase 13 Wave 2 complete (H-1/H-2/H-4 fixes, _removeBorder/_baseStyle removed)
progress:
  total_phases: 12
  completed_phases: 7
  total_plans: 30
  completed_plans: 24
  percent: 58
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-31)

**Core value:** Build clean, dependency-free window management and unified widget system for smooth desktop playback.
**Current focus:** v1.2.1 — Window Polish & Architecture Simplification

## Current Position

Phase: Phase 13 — Window Foundation (in-progress)
Plan: .planning/phases/13-window-foundation/PLAN.md
Approach: Pure Dart (user chose over C++ WndProc)
Status: Wave 2 complete, Wave 3 pending
Resume: .planning/phases/13-window-foundation/.continue-here.md
Last activity: 2026-05-31 — Phase 13 Wave 2 complete (H-1/H-2/H-4 fixes, _removeBorder/_baseStyle removed)

## Accumulated Context

### Decisions

- [v1.0]: Self-built MethodChannel for window management
- [v1.0]: ValueNotifier pattern preserved
- [v1.0]: D3D11 sync safe default (d3d11.sync.cpu=1)
- [v1.0]: 3-layer architecture (Kernel/Features/UI)
- [v1.1]: BoxFit.contain for video rendering
- [v1.1]: Custom FFI maximize using rcWork
- [v1.2]: SEC-01 + SEC-02 combined in Phase 9 (both security, overlapping files)
- [v1.2]: LRU cache uses LinkedHashMap for O(1) touch/evict (pure Dart)
- [v1.2]: PositionPoller adaptive: 100ms seek / 250ms steady / 1s auto-revert
- [v1.2]: D3D11 sync mode: async (0) for 120Hz+, sync (1) for 60Hz
- [v1.2.1]: Pure Dart approach for window frameless (not C++ WndProc)
- [v1.2.1]: removeBorderImmediate() kept as static, _removeBorder() instance method removed
- [v1.2.1]: HLS ABR uses throughput-based EWMA, NOT BBA (desktop bandwidth stable)
- [v1.2.1]: URL-type routing for ABR vs low-latency config
- [v1.2.1]: PlatformService abstract interface with constructor injection (not service locator)
- [v1.2.1]: Fullscreen smooth transition deferred to v1.3+ (blocked by engine)

### Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v1.3+ | WIN-07: Fullscreen smooth transition | Blocked by engine | v1.2.1 |
| v1.3+ | PLATFORM-02: macOS/Linux platform stubs | Interface only in v1.2.1 | v1.0 |
| v1.3+ | ARCH-01: FvpEngine decomposition | Needs report | v1.2 |
| v1.3+ | Steam/SteamOS distribution | Deferred | v1.0 |

## Session Continuity

Last session: 2026-06-22T05:53:30.152Z
Stopped at: context exhaustion at 75% (2026-06-22)
Resume file: .planning/phases/13-window-foundation/.continue-here.md
