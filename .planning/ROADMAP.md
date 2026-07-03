# Roadmap: v1.3 控制栏视觉协调与玻璃质感优化

## Overview

控制栏与背景的视觉协调：添加空状态 token 体系，让控制栏在无视频时自动切换到更淡的配色，调整玻璃质感参数使控制栏与 AuroraBackground 融合。

## Milestones

- ✅ **v1.0 MVP** - Phases 1-4 (shipped 2026-05-29)
- ✅ **v1.1 Testing & Quality** - Phases 5-7 (shipped 2026-05-30)
- ✅ **v1.2 Security & Kernel** - Phases 8-11 (shipped 2026-05-31)
- ✅ **v1.2.1 Window Polish** - Phases 12-15 (shipped 2026-06-28)
- 🚧 **v1.3 Glass Morphism Coordination** - Phases 16-18 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-4) — SHIPPED 2026-05-29</summary>

- [x] **Phase 1: Window Foundation** - C++ WindowChannel, frameless window, Win32 resize/drag
- [x] **Phase 2: GlassMorphism & Controls** - GlassWidget library, control bar, progress bar
- [x] **Phase 3: Playback Engine** - fvp integration, playlist, media state management
- [x] **Phase 4: D3D11 Performance** - Hardware decoders, ring buffer, PerfMonitor

</details>

<details>
<summary>✅ v1.1 Testing & Quality (Phases 5-7) — SHIPPED 2026-05-30</summary>

- [x] **Phase 5: Integration Tests** - Critical user flow E2E tests
- [x] **Phase 6: Golden Tests** - Glassmorphism component golden tests
- [x] **Phase 7: Code Optimization** - Architecture refactoring, dead code cleanup

</details>

<details>
<summary>✅ v1.2 Security & Kernel (Phases 8-11) — SHIPPED 2026-05-31</summary>

- [x] **Phase 8: FFI Safety** - Memory leak fix, try/finally, fullscreen timeout
- [x] **Phase 9: Input Validation** - URL structure, path length, null byte checks
- [x] **Phase 10: Window Optimization** - WM_NCCALCSIZE, D3D11 sync, PositionPoller
- [x] **Phase 11: Debug Tooling** - Structured logging, Timeline tracing

</details>

<details>
<summary>✅ v1.2.1 Window Polish (Phases 12-15) — SHIPPED 2026-06-28</summary>

- [x] **Phase 12: Window Foundation** - WM_NCCALCSIZE sync frame, zero-flicker startup
- [x] **Phase 13: HLS ABR** - Adaptive bitrate streaming
- [x] **Phase 14: Architecture Simplification** - Window layer cleanup, singleton migration
- [x] **Phase 15: Window Polish** - Multi-monitor, responsive layout, settings fixes

</details>

### 🚧 v1.3 Glass Morphism Coordination (In Progress)

**Milestone Goal:** 控制栏颜色/亮度与背景融合，减少视觉突兀感

- [x] **Phase 16: Token Foundation & Independent Fixes** - Idle tokens, glow param, contrast fix (completed 2026-07-03)
- [ ] **Phase 17: Adaptive Control Bar** - GlassContainer param, ControlBar state-aware decoration
- [ ] **Phase 18: Visual Tuning & Validation** - Alpha/sigma iteration, multi-content validation

## Phase Details

### Phase 16: Token Foundation & Independent Fixes

**Goal**: Project has idle-state design tokens, adjustable EdgeGlow, and WCAG-compliant contrast
**Depends on**: Phase 15
**Requirements**: UI-01, UI-04, UI-05
**Success Criteria** (what must be TRUE):

  1. Six idle-state constants exist in tokens.dart and compile without errors
  2. EdgeGlow widget accepts optional glowIntensity parameter (default null preserves existing behavior)
  3. Secondary text achieves WCAG AA contrast ratio (>= 4.5:1, target 5.3:1) against control bar background
  4. All existing golden and widget tests pass with no regressions

**Plans**: 1/1 plans complete

- [x] 16-01-PLAN.md

**UI hint**: yes

### Phase 17: Adaptive Control Bar

**Goal**: Control bar visually adapts between idle and playing states using idle tokens
**Depends on**: Phase 16
**Requirements**: UI-02, UI-03
**Success Criteria** (what must be TRUE):

  1. GlassContainer accepts optional backgroundColor parameter (default Tokens.bgGlass, backward compatible)
  2. ControlBar shows distinct idle-state decoration when no video is loaded (lighter, more transparent)
  3. ControlBar shows existing decoration during playback (no change from current behavior)
  4. Transition between idle/playing states is visually smooth (no flicker or jump)
  5. Existing call sites of GlassContainer and ControlBar require zero modifications

**Plans**: TBD

**UI hint**: yes

### Phase 18: Visual Tuning & Validation

**Goal**: All visual parameters are validated and tuned across diverse video content types
**Depends on**: Phase 17
**Requirements**: UI-06
**Success Criteria** (what must be TRUE):

  1. Control bar appearance is validated against dark, bright, mixed, colorful, and letterbox video content
  2. Idle-state border remains visible (alpha >= 15%) in all tested scenarios
  3. glassBlur vs glassBlurThick distinction is confirmed or consolidated based on visual evidence
  4. No visual regressions: playing-state control bar appearance unchanged from pre-v1.3 baseline

**Plans**: TBD

**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 16. Token Foundation & Independent Fixes | 1/1 | Complete    | 2026-07-03 |
| 17. Adaptive Control Bar | 0/0 | Not started | - |
| 18. Visual Tuning & Validation | 0/0 | Not started | - |
