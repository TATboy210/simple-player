---
gsd_state_version: 1.0
milestone: v1.2.1
milestone_name: Window Polish & Architecture Simplification
status: planning
last_updated: "2026-05-30T16:14:54.305Z"
last_activity: 2026-05-30
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-30)

**Core value:** Build clean, dependency-free window management and unified widget system for smooth desktop playback.
**Current focus:** Phase 12 — Debug Tooling

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-30 — Milestone v1.2.1 started

## Accumulated Context

### Decisions

- [v1.0]: Self-built MethodChannel for window management
- [v1.0]: ValueNotifier pattern preserved
- [v1.0]: D3D11 sync safe default (d3d11.sync.cpu=1)
- [v1.0]: 3-layer architecture (Kernel/Features/UI)
- [v1.1]: BoxFit.contain for video rendering
- [v1.1]: Custom FFI maximize using rcWork
- [v1.2]: SEC-01 + SEC-02 combined in Phase 9 (both security, overlapping files)
- [v1.2]: ARCH-01/02/03 deferred to v1.3+ (need detailed reports)
- [v1.2]: LRU cache uses LinkedHashMap for O(1) touch/evict (pure Dart)
- [v1.2]: PositionPoller adaptive: 100ms seek / 250ms steady / 1s auto-revert
- [v1.2]: D3D11 sync mode: async (0) for 120Hz+, sync (1) for 60Hz
- [v1.2]: DevMode FFI struct uses Array<Uint16> not Array<Utf16>

### Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v1.3+ | ARCH-01: FvpEngine decomposition | Needs report | v1.2 |
| v1.3+ | ARCH-02: SettingsStore simplification | Needs report | v1.2 |
| v1.3+ | ARCH-03: Singleton migration | Needs report | v1.2 |
| v1.3+ | PLATFORM-02: macOS/Linux platform stubs | Deferred | v1.0 |
| v1.3+ | HLS/ABR streaming | Deferred | v1.0 |
| v1.3+ | Steam/SteamOS distribution | Deferred | v1.0 |

## Session Continuity

Last session: 2026-05-30T21:45:00.000Z
Stopped at: Phase 11 complete, ready for Phase 12
Resume file: None
