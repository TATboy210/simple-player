# Simple Player Flutter

## What This Is

Flutter desktop media player powered by fvp (MDK/FFmpeg). Shipped v1.0 with self-managed window control via MethodChannel + Win32 FFI, unified glassmorphism UI component library, and optimized playback performance on Windows. v1.1 delivered testing infrastructure (596 tests), architecture cleanup (file splitting, dead code removal), and code quality improvements. v1.2 focuses on security hardening, deep architecture optimization, and kernel improvements.

## Core Value

Build a clean, dependency-free window management layer and unified widget system that delivers smooth, responsive playback on all desktop platforms.

## Current Milestone: v1.2 Security, Architecture & Kernel

**Goal:** 安全加固 + 深度架构优化 + 窗口持续改进 + 内核优化 + Debug 工具

**Target features:**
- 安全加固 (FFI 内存安全、URL/路径验证、fullscreen 超时保护)
- 架构优化 (fvp_engine 拆分、SettingsStore 简化、单例迁移)
- 窗口优化 (持续改进窗口管理和用户体验)
- 内核改进 (引擎层优化、性能提升)
- Debug 工具 (调试日志、诊断能力改进)

## Requirements

### Validated (v1.0)

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
- ✓ WIN-01: MethodChannel window management (Win32 FFI) — v1.0
- ✓ WIN-02: Window state persistence — v1.0
- ✓ WIN-03: Frameless window + custom title bar — v1.0
- ✓ WIDGET-01: Unified glass component library — v1.0
- ✓ WIDGET-02: ValueNotifier rebuild optimization — v1.0
- ✓ PERF-01: fvp D3D11 sync optimization (partial, multi-GPU testing deferred) — v1.0
- ✓ PERF-02: Error handling anti-pattern fixes — v1.0
- ✓ PERF-03: Control bar frame drop reduction — v1.0
- ✓ PLATFORM-01: Windows MethodChannel implementation — v1.0
- ✓ TEST-01: Window layer unit tests — v1.0
- ✓ TEST-02: Settings panel widget tests — v1.0
- ✓ TEST-03: Startup coordinator tests — v1.0
- ✓ TEST-04: Coverage 64% → 80% — v1.0

### Validated (v1.1)

- ✓ OPT-01: Window layer code optimization — v1.1 Phase 6
- ✓ TEST-05: Integration tests for critical user flows (E2E) — v1.1 Phase 7
- ✓ TEST-06: Golden tests for glassmorphism components — v1.1 Phase 7
- ✓ QUAL-01: Architecture optimization (Context7-guided) — v1.1 Phase 8
- ✓ QUAL-02: Dead code cleanup — v1.1 Phase 8
- ✓ QUAL-03: Code quality maintenance — v1.1 Phase 8

### Active (v1.2)

- [ ] SEC-01: FFI memory safety (dispose leak fix, try/finally, fullscreen timeout)
- [ ] SEC-02: Input validation (URL structure, path length, null bytes)
- [ ] ARCH-01: fvp_engine.dart decomposition (690 → focused modules)
- [ ] ARCH-02: SettingsStore simplification (25+ save methods → generic pattern)
- [ ] ARCH-03: Singleton migration (6 static mutable singletons → DI)
- [ ] WIN-04: Window management continued optimization
- [ ] KERN-01: Kernel layer improvements (engine, bridge, persistence)
- [ ] DBG-01: Debug tooling and diagnostics improvements

### Future (v1.3+)

- [ ] PLATFORM-02: macOS/Linux platform stubs (deferred from v1)
- [ ] Impeller FragmentShader for BackdropFilter (requires Impeller stable on Windows)
- [ ] HLS/ABR streaming — adaptive bitrate architecture
- [ ] Steam/SteamOS distribution — Linux + Steam Deck

### Out of Scope

- Third-party window packages (window_manager) — self-built only
- Mobile platforms (iOS/Android) — desktop only
- State management migration (Provider/Riverpod/Bloc) — ValueNotifier preserved
- Online subtitle search — separate feature
- HDR/ICC color management, frame interpolation, equalizer UI

## Context

- **Tech stack**: Flutter 3.44 beta, Dart 3.12, fvp 0.36.2 (MDK/FFmpeg)
- **State management**: ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- **Architecture**: 3-layer (Kernel/Features/UI)
- **Rendering**: D3D11 hardware-accelerated via fvp
- **Codebase**: ~15,000 Dart LOC, 98 files, 596 tests, 80%+ coverage
- **Platform target**: Windows primary, macOS/Linux planned for v2

## Constraints

- **Engine**: fvp/MDK is the only playback backend — no migration planned
- **State model**: ValueNotifier-only — no state management library migration
- **Window API**: Flutter has no native window mutation API — must use MethodChannel + platform code
- **Dependencies**: fvp, shared_preferences, desktop_drop, file_picker — stable, not changing
- **Platform**: Windows shipped in v1.0 — macOS/Linux follow in v2

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Self-built MethodChannel | Full control, no third-party dependency for critical window layer | v1.0 shipped |
| Windows first | Primary platform, Win32 APIs well-known | v1.0 shipped |
| ValueNotifier preserved | Working pattern, no migration cost | v1.0 shipped |
| 3-layer architecture | Simplified from 4-layer after window removal | v1.0 shipped |
| Unified glass components | Reduce duplication, consistent API | v1.0 shipped |
| D3D11 sync safe default | d3d11.sync.cpu=1 for safety, user-tunable | v1.0 shipped |
| PLATFORM-02 deferred | Not blocking v1 release, low priority | Deferred to v2 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-30 after v1.2 milestone start*
