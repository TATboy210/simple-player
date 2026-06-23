# Research Summary — Cross-Platform Window Management

**Synthesized:** 2026-06-23

## Executive Summary

Simple Player Flutter is a Windows desktop media player built on Flutter + fvp (MDK/FFmpeg) with a mature, clean architecture. All 12 table-stakes window management features are complete on Windows. The goal is expanding to Linux and macOS using the existing `PlatformFullscreen` strategy pattern — the architecture already has the right abstraction seams, so the work is adding concrete implementations, not restructuring. No new packages needed.

## Key Findings

1. **Stack:** Keep `window_manager` ^0.5.1 + `ffi` ^2.1.0 + `fvp` ^0.37.2. No new dependencies needed.
2. **Features:** 12/12 table stakes done on Windows. Cross-platform porting estimated 3-6 days per platform.
3. **Architecture:** 4-layer with `PlatformFullscreen` strategy pattern. Adding macOS/Linux = 2 files (~150 lines each) + factory method update.
4. **Top Risks:** macOS NSWindow thread safety (CRITICAL), Wayland blocks client positioning (HIGH), macOS fullscreen paradigm difference (HIGH), macOS App Nap (HIGH), ARM64 plugin binaries (MEDIUM).

## Roadmap Implications

1. **Phase 1 — Platform Abstraction:** Refactor WindowBridge, add factory pattern. Validates seam with existing Windows code.
2. **Phase 2 — Windows Bridge:** Extract current impl into WindowsBridge. Zero-risk validation of abstraction.
3. **Phase 3 — Linux:** X11 + Wayland. Highest compositor fragmentation. Wayland positioning is a silent failure.
4. **Phase 4 — macOS:** NSWindow native fullscreen. Thread safety is CRITICAL risk.
5. **Phase 5 — ARM Validation:** fvp ARM64 binaries are gating factor.
6. **Phase 6 — Integration Testing:** CI matrix across 3 platforms.

## Sources

- `.planning/research/STACK.md`
- `.planning/research/FEATURES.md`
- `.planning/research/ARCHITECTURE.md`
- `.planning/research/PITFALLS.md`

---
*Synthesized: 2026-06-23*
