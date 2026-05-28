# Roadmap: Simple Player Flutter — Window Management & UI Unification

## Overview

Build self-managed window control via MethodChannel + Win32 FFI, unify the glassmorphism component library, optimize playback performance, and prepare multi-platform stubs. Strategy: foundation first (window layer), then UI cleanup, then performance tuning, then quality.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Window Management Foundation** — MethodChannel + Win32 FFI + state persistence + error handling fixes
- [ ] **Phase 2: Widget Unification** — Glass component library + ValueNotifier rebuild optimization
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
  3. Window geometry saved on close and restored on startup via `SettingsStore`
  4. Frameless window with custom title bar: drag, resize edges, close/minimize/maximize buttons
  5. All `catch (_)` and `on Object catch` anti-patterns replaced with proper error handling
  6. `didChangeMetrics()` wired to update window state on resize/fullscreen
**Plans**: TBD

Plans:
- [ ] 01-01: TBD — MethodChannel + Win32 C++ handler
- [ ] 01-02: TBD — Window state persistence + restoration
- [ ] 01-03: TBD — Frameless window + custom title bar
- [ ] 01-04: TBD — Error handling fixes

### Phase 2: Widget Unification
**Goal**: Unify glass component library and optimize ValueNotifier rebuild patterns
**Depends on**: Phase 1 (window layer stable before UI work)
**Requirements**: WIDGET-01, WIDGET-02
**Success Criteria** (what must be TRUE):
  1. Single `glass_widgets.dart` export file with consistent `GlassTier` enum
  2. `GlassButton` supports both `icon` and `iconOnly` constructors (merged from `GlassIconButton`)
  3. Shared hover/press animation extracted into reusable mixin
  4. All `ValueListenableBuilder` instances audited — static subtrees cached via `child`
  5. `ControlsOverlay` 8-field cache replaced with single immutable state object
  6. Measurable: 30%+ reduction in control bar rebuild count
**Plans**: TBD

Plans:
- [ ] 02-01: TBD — Glass component unification
- [ ] 02-02: TBD — ValueNotifier rebuild optimization

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
| WIN-01 | 1 | 01-01 |
| WIN-02 | 1 | 01-02 |
| WIN-03 | 1 | 01-03 |
| WIDGET-01 | 2 | 02-01 |
| WIDGET-02 | 2 | 02-02 |
| PERF-01 | 3 | 03-01 |
| PERF-02 | 1 | 01-04 |
| PERF-03 | 3 | 03-02 |
| PLATFORM-01 | 1 | 01-01 |
| PLATFORM-02 | 4 | 04-01 |
| TEST-01 | 4 | 04-02 |
| TEST-02 | 4 | 04-03 |
| TEST-03 | 4 | 04-03 |
| TEST-04 | 4 | 04-03 |

---
*Last updated: 2026-05-28 after reinitialization*
