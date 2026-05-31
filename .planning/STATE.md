---
gsd_state_version: 1.0
milestone: v1.2.1
milestone_name: Window Polish & Architecture Simplification
status: planned
stopped_at: null
last_updated: "2026-05-31T18:00:00.000Z"
last_activity: 2026-05-31 — Phase 13 plan created (3-wave: Spike → C++ + Dart → 精简)
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 1
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-31)

**Core value:** Build clean, dependency-free window management and unified widget system for smooth desktop playback.
**Current focus:** v1.2.1 — Window Polish & Architecture Simplification

## Current Position

Phase: Phase 13 — Window Foundation (planned)
Plan: .planning/phases/13-window-foundation/PLAN.md
Status: Plan ready, awaiting execution
Last activity: 2026-05-31 — Phase 13 plan created (3-wave: Spike → C++ + Dart → 精简)

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
- [v1.2.1]: WM_NCCALCSIZE must be handled BEFORE HandleTopLevelWindowProc (C++ spike needed)
- [v1.2.1]: WndProc is the earliest message entry point — intercept there, not in MessageHandler
- [v1.2.1]: Fullscreen compatibility via WS_POPUP self-check (方案 B), no extra FFI needed
- [v1.2.1]: removeBorderImmediate() will be fully removed — C++ handles frameless synchronously
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

Last session: 2026-05-31T11:16:12.326Z
Stopped at: context exhaustion at 76% (2026-05-31)
Resume file: None
