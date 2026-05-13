# Roadmap: Simple Player Flutter

## Overview

Fix widget-layer bugs (button highlights), complete fullscreen/settings wiring, and clean up code for production quality. Four phases, each delivering a verifiable improvement.

## Phases

- [x] **Phase 1: Button Highlight Fix** — Volume/Speed button highlight visible and consistent when popup open (5 requirements)
- [x] **Phase 2: Fullscreen Reliability** — Fullscreen toggle works from all entry points, mode persists, optimistic state (7 requirements)
- [x] **Phase 3: Settings Completion** — Settings dialog accessible, all tabs functional, correct fallback text (5 requirements)
- [ ] **Phase 4: Production Code Cleanup** — Remove dead code, fix keyboard handler, l10n labels, unused imports (5 requirements)

## Phase Details

### Phase 1: Button Highlight Fix
**Goal**: Volume and Speed buttons show clear cyan highlight when their popup is open, and the highlight state is visually consistent throughout the popup lifecycle
**Depends on**: Nothing
**Requirements**: BTN-01, BTN-02, BTN-03, BTN-04, BTN-05
**Success Criteria**:
  1. Clicking volume button opens popup AND icon turns cyan — both happen simultaneously, user can see the highlight
  2. Clicking speed button opens popup AND text turns cyan with border — both happen simultaneously
  3. Highlight stays while popup is visible — no flicker or premature clearing
  4. When control bar auto-hides, any open popup closes and highlight clears
  5. During close animation, highlight persists until overlay is fully removed (no 200ms gap)
**Root cause analysis**:
  - ValueKey(_popupOpen) mechanism is architecturally correct
  - Most likely: overlay popup's full-screen GestureDetector intercepts button taps
  - Secondary: popup overlay escapes ControlsOverlay FadeTransition
  - Tertiary: 200ms gap between highlight clear and overlay remove during close
**Plans**: 1 plan (single focused fix)

### Phase 2: Fullscreen Reliability
**Goal**: Fullscreen toggle works from all 4 entry points (F key, button, double-click, ESC), mode updates immediately, and persists across sessions
**Depends on**: Phase 1 (clean widget layer)
**Requirements**: FS-01 through FS-07
**Success Criteria**:
  1. F key, fullscreen button, double-click, and ESC all trigger fullscreen correctly
  2. `mode.value` updates optimistically in `toggleFullscreen()` — UI reflects change before window_manager callback
  3. Fullscreen state saved to GeometryStore on toggle (not just on callback)
  4. Aspect ratio unlocks in fullscreen, restores on exit
  5. Rapid toggle attempts guarded (reentrancy check)
**Plans**: 1 plan

### Phase 3: Settings Completion
**Goal**: Settings dialog opens from control bar, all 3 tabs work correctly, fallback text is accurate
**Depends on**: Phase 1
**Requirements**: SET-01 through SET-05
**Success Criteria**:
  1. Settings button in control bar opens SettingsDialog
  2. Equalizer presets apply FFmpeg filters correctly
  3. Audio track selection switches tracks
  4. Video processing sliders persist via SettingsStore
  5. Video processing tab shows correct fallback (not "no audio tracks")
**Plans**:
- [x] 06-01-PLAN.md — Fix l10n fallback text, video processing persistence, hardcoded Chinese close button

### Phase 4: Production Code Cleanup
**Goal**: Codebase is production-grade — no dead code, no hardcoded strings, no swallowed keys, proper cleanup
**Depends on**: Phases 1-3
**Requirements**: CODE-01 through CODE-05
**Success Criteria**:
  1. WindowManagerService (515 lines) removed
  2. KeyboardHandler 'A' key either wired to AB loop or removed
  3. AspectRatioService labels use l10n
  4. `dart analyze` passes with no warnings
  5. All overlay entries cleaned up on dispose
**Plans**: 1 plan

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Button Highlight | 1 | COMPLETE | 2026-05-13 |
| 2. Fullscreen | 1 | COMPLETE | 2026-05-14 |
| 3. Settings | 1 | COMPLETE | 2026-05-14 |
| 4. Code Cleanup | 0 | Blocked by Phase 3 | - |
