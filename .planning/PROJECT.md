# Simple Player Flutter — Performance & Architecture

## What This Is

Flutter desktop media player powered by fvp (MDK/FFmpeg), targeting Windows with macOS/Linux stubs. Single-screen architecture with glassmorphism UI, Win32 frameless window, and ValueNotifier-driven reactive state. This project focuses on performance optimization and architectural cleanup of the existing codebase.

## Core Value

Eliminate frame drops and rendering bottlenecks so the player delivers smooth, responsive playback and UI interaction on Windows desktop.

## Requirements

### Validated

- ✓ Basic playback (open/play/pause/seek/next/prev) — existing
- ✓ Keyboard shortcuts (20+ keys) — existing
- ✓ Playlist management (folder scan, history, play modes) — existing
- ✓ Glassmorphism UI (control bar, progress bar, volume, speed) — existing
- ✓ Win32 frameless window (drag, resize, fullscreen, always-on-top) — existing
- ✓ Settings panel (video effects, subtitle, audio tracks) — existing
- ✓ Localization (zh/en) — existing
- ✓ Drag-and-drop file support — existing
- ✓ Aspect ratio cycling — existing
- ✓ OSD overlay notifications — existing

### Active

- [ ] **PERF-01**: Profile and fix title bar frame drops (BackdropFilter, ValueNotifier rebuilds, or other root cause)
- [ ] **PERF-02**: Optimize fvp D3D11 rendering pipeline (application-layer mitigations for 9 known bottlenecks)
- [ ] **PERF-03**: Reduce ValueNotifier excessive widget rebuilds (group related state, Selector optimization)
- [ ] **ARCH-01**: Deduplicate WindowService (Windows/macOS/Linux share 90%+ code) — extract base mixin/abstract
- [ ] **ARCH-02**: Refactor ThumbnailService (static singleton → instance-based, LRU O(n) → O(1))
- [ ] **ARCH-03**: Remove legacy `lib/models/playlist_item.dart` (dead code, superseded by kernel version)
- [ ] **TEST-01**: Add integration tests for critical flows (open → play → seek → pause → next)
- [ ] **TEST-02**: Add golden tests for UI components (control bar, progress bar, playlist)
- [ ] **TEST-03**: Add unit tests for untested window layer (FullscreenController, WindowStateService, WindowPersistenceService)

### Out of Scope

- Cross-platform expansion (macOS/Linux real implementation) — stubs exist, not priority
- Online subtitle search — TODO stub exists, separate feature
- HLS/ABR streaming — long-term plan, separate project
- Steam/SteamOS distribution — separate project
- New UI features (equalizer, video filters) — focus on optimization, not new features

## Context

- **Tech stack**: Flutter 3.x, fvp 0.36.2 (MDK/FFmpeg), Win32 FFI, SharedPreferences
- **State management**: ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- **Architecture**: 5-layer (Kernel → Bridge → Window → Service → UI) with mixin composition
- **Known bottlenecks**: fvp D3D11 pipeline has 9 documented bottlenecks (GPU-CPU sync, Flush, mutex, CopyResource)
- **Codebase map**: 7 analysis documents in `.planning/codebase/`
- **Title bar issue**: User reports severe jitter/frame drops in title bar area — root cause needs profiling
- **Legacy code**: `lib/models/playlist_item.dart` (26 lines, dead) vs `lib/kernel/models/playlist_item.dart` (72 lines, active)
- **Test gaps**: Zero integration tests, zero golden tests, Window/Settings/Playlist UI untested
- **Window triplication**: WindowService (302 lines), MacosWindowService (286 lines), LinuxWindowService (279 lines) — 90%+ identical

## Constraints

- **Platform**: Windows primary — macOS/Linux are stubs, not blocking
- **Engine**: fvp/MDK is the only playback backend — no migration planned
- **State model**: ValueNotifier-only — no state management library migration
- **Window**: Win32 FFI for fullscreen — existing pattern must be preserved
- **Dependencies**: fvp, window_manager, shared_preferences — stable, not changing

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Performance-first approach | Title bar frame drops are user-visible, fix before architecture cleanup | — Pending |
| Profile before optimizing title bar | Don't guess — measure actual bottleneck (BackdropFilter vs ValueNotifier vs other) | — Pending |
| Keep ValueNotifier pattern | No state management migration — optimize within existing pattern | — Pending |
| Extract WindowService base mixin | 90% code duplication across 3 platforms is unsustainable | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-23 after initialization*
