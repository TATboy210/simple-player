# Roadmap: Simple Player Flutter -- Window Border

## Overview

Deliver an immersive window border for the Flutter desktop media player in three phases. Phase 1 builds the visual chrome (title bar + controls). Phase 2 adds resize optimization and state persistence for smooth, jank-free interaction. Phase 3 integrates playback-aware aspect ratio locking -- the core value of the project. Each phase delivers a complete, independently verifiable capability.

## Phases

- [x] **Phase 1: Window Chrome** - Title bar with glass-morphism, window controls, and production quality baseline
- [ ] **Phase 2: Resize & Persistence** - Jank-free resize optimization, minimum size enforcement, geometry persistence, edge case handling
- [ ] **Phase 3: Playback-Aware Sizing** - Window aspect ratio locks to video during playback, returns to free-resize on stop

## Phase Details

### Phase 1: Window Chrome
**Goal**: Users see a glass-morphism title bar with app icon, file name, and fully functional window controls (pin, minimize, maximize, close) that reflect live state. All code passes static analysis with zero warnings, no hardcoded values, proper dispose safety, and FFI error handling.
**Depends on**: Nothing (first phase)
**Requirements**: WB-01, WB-02, WB-03, WB-04, WC-01, WC-02, WC-03, WC-04, WC-05, PQ-01, PQ-03, PQ-05, PQ-06, PQ-07
**Success Criteria** (what must be TRUE):
  1. Title bar renders at 36px height with glass-morphism (BackdropFilter blur) showing app icon and current file name
  2. All four window controls (pin, minimize, maximize, close) are visible and functional
  3. Window controls reflect current state via ValueNotifier (pinned indicator, maximized/restore icon toggle)
  4. User can drag the window by grabbing the title bar
  5. Double-tap on title bar toggles maximize/restore
  6. All window border code passes `flutter analyze` with zero warnings
  7. Unit tests verify CustomTitleBar controls reflect pinned/maximized state changes
  8. All ValueNotifiers are disposed and all timers cancelled when widgets unmount -- no leaks
  9. All FFI/native calls (window manager, DPI) are wrapped in try-catch with graceful fallback
  10. All sizes, colors, and durations come from DesignTokens or named constants -- no hardcoded values
**Plans**: 3 plans
Plans:
- [x] 01-01-PLAN.md -- Design tokens + FakePlatformService extraction
- [x] 01-02-PLAN.md -- CustomTitleBar widget (glass-morphism + controls + gestures)
- [x] 01-03-PLAN.md -- App integration + widget tests

### Phase 2: Resize & Persistence
**Goal**: Window resizes smoothly without GPU jank, enforces minimum size in empty state, persists geometry across sessions, and handles edge cases gracefully. Unit tests cover resize debounce logic and persistence.
**Depends on**: Phase 1
**Requirements**: WB-05, WB-06, WS-01, WS-02, WS-03, PQ-02, PQ-04
**Success Criteria** (what must be TRUE):
  1. Window enforces minimum size of 1024x576 (16:9) when no video is playing
  2. During resize drag, BackdropFilter is skipped (isResizing notifier) preventing GPU jank
  3. After resize drag ends, glass-morphism restores after 500ms debounce (not instantly)
  4. Window geometry (size, position, maximized, fullscreen) persists across app restarts via SettingsStore
  5. Unit tests verify WindowManagerService resize debounce timing, isResizing state transitions, and persistence round-trip
  6. Edge cases handled gracefully: DPI changes mid-session, monitor disconnect, rapid fullscreen toggle
**Plans**: 3 plans
Plans:
- [ ] 02-01-PLAN.md -- Update minSize constant and SettingsStore sanitization bounds
- [ ] 02-02-PLAN.md -- Fix test inaccuracies and add comprehensive test coverage
- [ ] 02-03-PLAN.md -- Fix title bar jitter (Stack + AnimatedOpacity + RepaintBoundary + hover guard)

### Phase 3: Playback-Aware Sizing
**Goal**: Window adapts its sizing behavior based on playback state -- freely resizable when empty, locked to video aspect ratio when playing.
**Depends on**: Phase 2
**Requirements**: WP-01, WP-02, WP-03, WP-04
**Success Criteria** (what must be TRUE):
  1. When video starts playing, window aspect ratio locks to the video's native aspect ratio
  2. Resizing during playback scales proportionally (maintains video aspect ratio)
  3. Aspect ratio lock uses native AspectRatioService (MethodChannel) for OS-level enforcement
  4. When video stops or user exits playback, window returns to free-resize mode with minimum 16:9 constraint
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Window Chrome | 3/3 | Complete | 2026-05-07 |
| 2. Resize & Persistence | 0/3 | Planning complete | - |
| 3. Playback-Aware Sizing | 0/TBD | Not started | - |
