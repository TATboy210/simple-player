# Roadmap: Simple Player Flutter — Window Management & UI Unification

## Overview

Build self-managed window control via MethodChannel + Win32 FFI, unify the glassmorphism component library, optimize playback performance, and prepare multi-platform stubs. Strategy: foundation first (window layer), then UI cleanup, then performance tuning, then quality.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Window Management Foundation** — MethodChannel + Win32 FFI + state persistence + error handling fixes ✅ 2026-05-28
- [x] **Phase 2: Widget Unification** — Glass component library + ValueNotifier rebuild optimization ✅ 2026-05-28
- [ ] **Phase 3: Performance Optimization** — D3D11 tuning + control bar profiling + frame drop fixes
- [ ] **Phase 4: Platform Stubs & Test Coverage** — macOS/Linux stubs + test coverage 64% → 80%

## Phase Details

### Phase 1: Window Management Foundation
**Goal**: Build the complete window management layer — MethodChannel, Win32 C++ handler, state persistence, frameless window, and fix error handling anti-patterns
**Depends on**: Nothing (first phase)
**Requirements**: WIN-01, WIN-02, WIN-03, PERF-02, PLATFORM-01
**Success Criteria** (what must be TRUE):
  1. `WindowService` class exists with typed API for all window operations
  2. C++ MethodChannel handler in `windows/runner/` implements fullscreen, always-on-top, resize, position, frameless
  3. Window centered on startup with 960x540 defaults (D-29: no persistence)
  4. Frameless window with custom title bar: drag, resize edges, close/minimize/maximize buttons
  5. All `catch (_)` and `on Object catch` anti-patterns replaced with proper error handling
  6. `didChangeMetrics()` wired to update window state on resize/fullscreen
**Plans**: 4 plans in 3 waves

Plans:
- [x] 01-01-PLAN.md — C++ WindowChannel + Dart WindowService (WIN-01, PLATFORM-01) ✅
- [x] 01-02-PLAN.md — Frameless window + WM_NCHITTEST resize/drag (WIN-01, WIN-03, PLATFORM-01) ✅
- [x] 01-03-PLAN.md — CustomTitleBar + PlayerScreen integration + centering (WIN-02, WIN-03) ✅
- [x] 01-04-PLAN.md — Error handling anti-pattern fixes (PERF-02) ✅

### Phase 2: Widget Unification
**Goal**: Unify glass component library and optimize ValueNotifier rebuild patterns
**Depends on**: Phase 1 (window layer stable before UI work)
**Requirements**: WIDGET-01, WIDGET-02
**Success Criteria** (what must be TRUE):
  1. Single `glass_widgets.dart` export file with consistent `GlassTier` enum (D-03)
  2. `GlassButton` supports both `icon` and `iconOnly` constructors (merged from `GlassIconButton`) (D-01)
  3. All modes use InkWell hover/press feedback only — no scale animation (D-06, D-07)
  4. All `ValueListenableBuilder` instances audited — static subtrees cached via `child` (D-10, D-11)
  5. GlassContainer supports conditional BackdropFilter skip and degradation mode (D-13, D-14)
  6. Measurable: 30%+ reduction in control bar rebuild count (D-12: qualitative judgment + code analysis)
**Plans**: 2 plans in 2 waves

Plans:
- [x] 02-01-PLAN.md — Glass component merge + barrel file + migration + tests (WIDGET-01) ✅
- [x] 02-02-PLAN.md — Glass performance optimizations + ValueNotifier audit (WIDGET-02) ✅

### Phase 3: Performance Optimization
**Goal**: Apply D3D11 hardware tuning and fix control bar frame drops based on profiling data
**Depends on**: Phase 2 (optimized widgets before measuring performance)
**Requirements**: PERF-01, PERF-03
**Success Criteria** (what must be TRUE):
  1. `d3d11.sync.cpu=0` tested on 3+ hardware configs (dedicated GPU, Intel iGPU, AMD iGPU)
  2. No visible tearing on tested configs, OR tearing documented with fallback
  3. Measurable frame time improvement (2-5ms/frame savings via DevTools)
  4. Control bar frame drops eliminated or reduced to <5% jank in profile mode
  5. Root cause of control bar jitter identified and fixed
**Plans**: TBD

Plans:
- [ ] 03-01: TBD — D3D11 hardware tuning
- [ ] 03-02: TBD — Control bar profiling + fix

### Phase 4: Platform Stubs & Test Coverage
**Goal**: Add macOS/Linux platform stubs and raise test coverage from 64% to 80%
**Depends on**: Phase 1 (window layer must exist before testing it)
**Requirements**: PLATFORM-02, TEST-01, TEST-02, TEST-03, TEST-04
**Success Criteria** (what must be TRUE):
  1. Abstract `PlatformWindow` interface with Windows, macOS, Linux implementations
  2. macOS stub compiles and responds to MethodChannel (basic NSWindow operations)
  3. Linux stub compiles and responds to MethodChannel (basic GTK window operations)
  4. Unit tests pass for `WindowService` with mock `PlatformWindow`
  5. Widget tests pass for `SettingsPanel`
  6. Unit tests pass for `StartupCoordinator`
  7. Test coverage reaches 80%+ (from 64%)
**Plans**: TBD

Plans:
- [ ] 04-01: TBD — macOS/Linux platform stubs
- [ ] 04-02: TBD — Window layer tests
- [ ] 04-03: TBD — Settings/startup tests + coverage closure

## Requirement Traceability

| Requirement | Phase | Plan |
|-------------|-------|------|
| WIN-01 | 1 | 01-01, 01-02 |
| WIN-02 | 1 | 01-03 |
| WIN-03 | 1 | 01-02, 01-03 |
| WIDGET-01 | 2 | 02-01 |
| WIDGET-02 | 2 | 02-02 |
| PERF-01 | 3 | 03-01 |
| PERF-02 | 1 | 01-04 |
| PERF-03 | 3 | 03-02 |
| PLATFORM-01 | 1 | 01-01, 01-02 |
| PLATFORM-02 | 4 | 04-01 |
| TEST-01 | 4 | 04-02 |
| TEST-02 | 4 | 04-03 |
| TEST-03 | 4 | 04-03 |
| TEST-04 | 4 | 04-03 |

---
*Last updated: 2026-05-28 — Phase 2 planning complete*
