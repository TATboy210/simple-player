# Roadmap: Simple Player Flutter

## Overview

Build a stable frameless window shell first (the hard part -- flicker-free, resize-safe, persistence), then wire video playback and content management into it, and finally harden security for all external input paths. Each phase delivers a complete, verifiable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Window Shell** - Frameless window with custom title bar, aspect ratio, fullscreen, state persistence (15 requirements)
- [ ] **Phase 2: Video & Content** - Video surface rendering, play/pause, file picker, drag-and-drop, playlist wiring (6 requirements)
- [ ] **Phase 3: Security Hardening** - Input validation for URLs, subtitle delays, equalizer filters (3 requirements)

## Phase Details

### Phase 1: Window Shell
**Goal**: Users see a stable, flicker-free frameless window with custom title bar, can drag/resize/fullscreen, and window state persists across sessions
**Depends on**: Nothing (first phase)
**Requirements**: WIN-01, WIN-02, WIN-03, WIN-04, WIN-05, WIN-06, WIN-07, WIN-08, WIN-09, WIN-10, WIN-11, WIN-12, WIN-13, WIN-14, WIN-15
**Success Criteria** (what must be TRUE):
  1. App launches with no system title bar, no white flash -- frameless window appears immediately with correct size from persisted state
  2. Custom title bar (36px) shows app name, minimize/maximize/close buttons, and always-on-top pin -- buttons do not flicker during window resize
  3. User can drag title bar to move window, double-tap to toggle maximize, and resize edges while aspect ratio stays locked (16:9 idle, video ratio when playing)
  4. F11 toggles fullscreen reliably with no ABA state corruption, and fullscreen reentry guard prevents rapid toggling
  5. Window size/position/maximized/fullscreen/pin state persists (500ms debounce) and restores correctly, with bounds clamping to visible screen on multi-monitor setups
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — WindowManagerService + PlatformService extension + title bar tokens
- [ ] 01-02-PLAN.md — AspectRatioService + CustomTitleBar with Win11-style buttons
- [ ] 01-03-PLAN.md — App shell wiring + FakePlatformService + comprehensive tests

**UI hint**: yes

### Phase 2: Video & Content
**Goal**: Users can open video files (picker or drag-drop), see them rendered in the window, and control basic playback
**Depends on**: Phase 1
**Requirements**: VID-01, VID-02, VID-03, CON-01, CON-02, CON-03
**Success Criteria** (what must be TRUE):
  1. Video renders via Texture widget using fvp engine textureId -- video surface fills the window below the title bar
  2. User can play/pause video, and an empty state overlay with "Open File" button shows when no video is loaded
  3. User can open files via file picker (video type filter) or drag-and-drop onto the window
  4. Opened files are added to playlist via PlaybackController and playback starts automatically
**Plans**: TBD

**UI hint**: yes

### Phase 3: Security Hardening
**Goal**: All external input paths (URLs, subtitles, equalizer) are validated and bounded, preventing crashes or exploits
**Depends on**: Phase 2
**Requirements**: SEC-01, SEC-02, SEC-03
**Success Criteria** (what must be TRUE):
  1. URLs are validated against a scheme whitelist (http, https, rtmp, rtsp) before engine access -- invalid schemes are rejected with user feedback
  2. Subtitle delay is clamped to +/-30000ms -- out-of-range values are silently corrected
  3. Equalizer filter strings are validated before passing to engine -- malformed strings are rejected without crashing
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Window Shell | 0 | Planning complete | - |
| 2. Video & Content | 0 | Not started | - |
| 3. Security Hardening | 0 | Not started | - |
