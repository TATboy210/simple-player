# Research Summary — v1.2.1 Window Polish & Architecture Simplification

**Date:** 2026-05-31
**Source:** Context7 (Flutter docs), claude-mem (project history), codebase analysis, 4 parallel research agents

## Key Findings

### Window Smoothness (WIN-05)

**Root Cause**: 4 overlapping timing issues cause a single ugly frame to flash at startup and fullscreen transitions:
1. Startup: async `removeBorderImmediate()` races with `windowManager.show()`
2. Fullscreen: two-step transition (style change + position change) has gap
3. Triple border removal: `window_manager` plugin + main.dart FFI + app.dart `WindowService.init()` create path conflicts
4. No C++ `WM_NCCALCSIZE` handler for synchronous frameless enforcement

**Solution — C++ WM_NCCALCSIZE (synchronous)**:
- Handle `WM_NCCALCSIZE` in `flutter_window.cpp` BEFORE `HandleTopLevelWindowProc` (lines 46-53)
- Collapse non-client area to zero while preserving `WS_CAPTION` for DWM animations
- Eliminates ALL async border removal timing issues — window is frameless from first paint
- **Risk**: Flutter engine may consume WM_NCCALCSIZE before custom handlers (3 prior failed C++ attempts documented in anti-pattern memory)
- **Mitigation**: Spike with `OutputDebugString` verification (0.5 day)

**Fullscreen smooth transition**: BLOCKED by Flutter engine's `HandleTopLevelWindowProc` interception. Deferred to v1.3+.

### HLS ABR (HLS-01)

**Algorithm choice**: Throughput-based (EWMA), NOT BBA.
- Desktop bandwidth is stable; BBA's buffer-level approach is over-engineering
- FFmpeg's built-in `hls.c` demuxer handles variant selection
- Throughput estimation via EWMA covers 80% of desktop use cases

**Critical conflict**: `fflags +nobuffer` and `setBufferRange(drop:true)` applied to ALL URLs conflicts with ABR buffer requirements.
- **Solution**: URL-type routing — `.m3u8` → ABR config (remove low-latency flags), else → low-latency config

**MDK metric availability**: Need spike (0.5 day) to verify `MediaInfo` exposes bitrate/buffer metrics for EWMA calculation.

### Architecture Simplification (ARCH-02, ARCH-03, PLATFORM-03)

**SettingsStore**: 25+ save methods → generic `_get<T>`/`_set<T>` pattern. Standard refactoring, no research needed.

**Singleton migration**: 6 static mutable singletons → constructor injection.
- Pattern: `PlatformService` abstract interface with `WindowsPlatformService` implementation
- Constructor injection (NOT service locator) — simplest, most testable
- `WindowsPlatformService` delegates to existing `WindowService` (no rewrite)

**Platform abstraction**: Interface definitions only, no macOS/Linux implementation yet.
- Main interface: `PlatformService` (window, system, path operations)
- FFI/C++ runner is the ONLY platform-specific binding

## Recommended Phase Order

| Phase | Focus | Risk | Rationale |
|-------|-------|------|-----------|
| Phase 13 | Window Foundation (C++ WM_NCCALCSIZE) | HIGH | Highest impact, needs spike first, unblocks Phase 15 |
| Phase 14 | HLS ABR (AbrService + URL Routing) | MEDIUM | Independent of Phase 13, can run in parallel |
| Phase 15 | Architecture Simplification (SettingsStore + PlatformService) | LOW | Standard patterns, benefits from Phase 13 decisions |

## Research Flags

- Phase 13 needs WM_NCCALCSIZE spike (0.5 day) with `OutputDebugString` verification
- Phase 14 needs MDK metric availability spike (0.5 day)
- Phase 15 uses standard patterns, no research needed
- Fullscreen smooth transition deferred to v1.3+ (blocked by engine)

## Source Documents

- STACK.md — fvp/MDK engine capabilities, D3D11 pipeline, FFmpeg HLS demuxer
- FEATURES.md — Window smoothness patterns, HLS ABR architecture, platform abstraction
- ARCHITECTURE.md — WM_NCCALCSIZE integration, bridge layer design, DI patterns
- PITFALLS.md — Anti-patterns from project history, timing conflicts, engine limitations

---
*Research completed: 2026-05-31*
