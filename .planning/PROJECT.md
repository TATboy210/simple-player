# Simple Player Flutter — Window Management & UI Unification

## What This Is

Flutter desktop media player powered by fvp (MDK/FFmpeg). This project focuses on building self-managed window control via MethodChannel + platform FFI, unifying the glassmorphism UI component library, and improving playback performance across Windows/Linux/macOS.

## Core Value

Build a clean, dependency-free window management layer and unified widget system that delivers smooth, responsive playback on all desktop platforms.

## Requirements

### Validated

- ✓ Basic playback (open/play/pause/seek/next/prev) — existing
- ✓ Keyboard shortcuts (20+ keys) — existing
- ✓ Playlist management (folder scan, history, play modes) — existing
- ✓ Glassmorphism UI (control bar, progress bar, volume, speed) — existing
- ✓ Settings panel (video effects, subtitle, audio tracks) — existing
- ✓ Localization (zh/en) — existing
- ✓ Drag-and-drop file support — existing
- ✓ Aspect ratio cycling — existing
- ✓ OSD overlay notifications — existing
- ✓ Startup system (StartupCoordinator + EnginePrewarm) — existing
- ✓ Features layer (PlaybackController + 3 mixins) — existing

### Active

- [ ] **WIN-01**: Build MethodChannel window management (Win32 FFI first): fullscreen, always-on-top, resize constraints, window position/size, frameless chrome
- [ ] **WIN-02**: Window state persistence — apply saved geometry (position, size, fullscreen, always-on-top) on startup
- [ ] **WIN-03**: Custom title bar with frameless window — drag, resize, close/minimize/maximize buttons
- [ ] **WIDGET-01**: Unify GlassContainer/GlassButton/GlassIconButton into consistent component library
- [ ] **WIDGET-02**: Optimize ValueNotifier rebuilds — merge related state, cache static subtrees
- [ ] **PERF-01**: Fix fvp D3D11 sync bottleneck (d3d11.sync.cpu=0 with hardware validation)
- [ ] **PERF-02**: Fix error handling — replace catch(_) and on Object catch with proper patterns
- [ ] **PERF-03**: Reduce frame drops in control bar area (BackdropFilter + ValueNotifier profiling)
- [ ] **PLATFORM-01**: Windows primary implementation; macOS/Linux platform stubs with MethodChannel interface ready
- [ ] **TEST-01**: Test coverage from 64% → 80% (add tests for window layer, settings, startup)

### Out of Scope

- Third-party window management packages (window_manager) — self-built only
- Cross-platform expansion to mobile (iOS/Android)
- Online subtitle search — separate feature
- HLS/ABR streaming — separate project
- Steam/SteamOS distribution — separate project
- State management migration (Provider/Riverpod/Bloc) — ValueNotifier pattern preserved
- HDR/ICC color management, frame interpolation, equalizer UI

## Context

- **Tech stack**: Flutter 3.44 beta, Dart 3.12, fvp 0.36.2 (MDK/FFmpeg)
- **State management**: ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- **Architecture**: 3-layer (Kernel/Features/UI) — simplified from 4-layer after window layer removal
- **Rendering**: D3D11 hardware-accelerated via fvp, known 9 bottlenecks documented
- **Window state**: No active window management — window_manager removed, lib/window/ deleted
- **Known gaps**: Fullscreen UI exists but no backend, geometry persisted but never applied, always-on-top has no implementation
- **Test coverage**: 63.7% (1,161/1,822 lines), 27 test files, FakeEngine hand-written
- **Codebase map**: 7 analysis documents in `.planning/codebase/` (refreshed 2026-05-28)
- **Platform target**: Windows primary, macOS/Linux stubs

## Constraints

- **Engine**: fvp/MDK is the only playback backend — no migration planned
- **State model**: ValueNotifier-only — no state management library migration
- **Window API**: Flutter has no native window mutation API — must use MethodChannel + platform code
- **Dependencies**: fvp, shared_preferences, desktop_drop, file_picker — stable, not changing
- **Platform**: Windows first — macOS/Linux follow with same MethodChannel interface

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Self-built MethodChannel | Full control, no third-party dependency for critical window layer | — Pending |
| Windows first | Primary platform, Win32 APIs well-known | — Pending |
| ValueNotifier preserved | Working pattern, no migration cost | — Pending |
| 3-layer architecture | Simplified from 4-layer after window removal | — Complete |
| Unified glass components | Reduce duplication, consistent API | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-28 after reinitialization*
