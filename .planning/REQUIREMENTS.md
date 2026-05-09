# Requirements: Simple Player Flutter

**Defined:** 2026-05-09
**Core Value:** Stable, efficient, secure frameless window with video playback

## v1 Requirements

### Window Shell (首要 — 先把窗口做出来)

- [ ] **WIN-01**: Frameless window with no system title bar (setAsFrameless before show)
- [ ] **WIN-02**: Custom title bar — 稳定不闪烁 (36px, app name, window controls)
- [ ] **WIN-03**: Title bar 按钮 resize 稳定性 — isResizing 守卫 + RepaintBoundary + ValueListenableBuilder 精确重建，resize 期间按钮不闪烁不重绘
- [ ] **WIN-04**: Title bar drag to move window (GestureDetector onPanStart → startDragging)
- [ ] **WIN-05**: Title bar double-tap to toggle maximize
- [ ] **WIN-06**: Aspect ratio lock (16:9 idle, video ratio when playing, cycle button)
- [ ] **WIN-07**: Aspect ratio enforcement via native MethodChannel (WM_SIZING, not Flutter AspectRatio widget)
- [ ] **WIN-08**: Fullscreen toggle (F11, manual setSize/setPosition for frameless)
- [ ] **WIN-09**: Fullscreen reentry guard (prevent rapid F11 ABA state corruption)
- [ ] **WIN-10**: Window state persistence (size, position, maximized, fullscreen, always-on-top)
- [ ] **WIN-11**: 500ms debounced persistence (merge continuous resize/move events)
- [ ] **WIN-12**: Window bounds check on restore (clamp to visible screen area)
- [ ] **WIN-13**: Minimum window size (640×360, 360p 16:9)
- [ ] **WIN-14**: Always-on-top toggle (pin button in title bar)
- [ ] **WIN-15**: First frame fix (setAsFrameless + forceRedraw MethodChannel, 零白色闪烁)

### Video Playback

- [ ] **VID-01**: VideoSurface rendering (Texture widget from fvp engine textureId)
- [ ] **VID-02**: Basic play/pause (wire to engine.togglePlayPause)
- [ ] **VID-03**: Empty state overlay (open file button when idle)

### Content Management

- [ ] **CON-01**: File picker integration (FilePicker.pickFiles, type: video)
- [ ] **CON-02**: Drag-and-drop file support (desktop_drop DropHandler)
- [ ] **CON-03**: Files added to playlist via PlaybackController.addFiles

### Security

- [ ] **SEC-01**: URL validation with scheme whitelist (http, https, rtmp, rtsp)
- [ ] **SEC-02**: Subtitle delay bounds check (clamp to ±30000ms)
- [ ] **SEC-03**: Equalizer filter string validation

## v2 Requirements

### Playback UI

- **PLY-01**: Controls overlay (seek bar, volume slider, mute toggle)
- **PLY-02**: Auto-hide controls when playing, show on mouse hover
- **PLY-03**: OSD overlay (floating pill for play/pause/seek actions)
- **PLY-04**: Progress bar with seek functionality
- **PLY-05**: Speed control button

### Content Management

- **CNT-01**: Playlist panel (right side, add/remove/reorder)
- **CNT-02**: Play modes (sequential, loop, shuffle, single)
- **CNT-03**: Resume playback from last position
- **CNT-04**: Recent files history

### Polish

- **POL-01**: Keyboard shortcuts (19 bindings from reference)
- **POL-02**: Aurora background animation (idle state)
- **POL-03**: Glass-morphism effects (BackdropFilter)
- **POL-04**: Responsive layout (wide/narrow breakpoint)
- **POL-05**: Localization (EN/ZH)
- **POL-06**: Media info dialog
- **POL-07**: Settings dialog (equalizer, video processing)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile platforms (Android/iOS) | Desktop only for v1 |
| Network streaming / DRM | Local file playback only |
| Audio-only player (just_audio) | fvp handles all media |
| Custom equalizer UI | Kernel supports it, UI deferred to v2 |
| Video processing UI | VideoProcessingService exists but UI deferred |
| AB loop | Kernel supports it, UI deferred |
| Subtitle overlay positioning | Deferred to v2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WIN-01 | Phase 1 | Pending |
| WIN-02 | Phase 1 | Pending |
| WIN-03 | Phase 1 | Pending |
| WIN-04 | Phase 1 | Pending |
| WIN-05 | Phase 1 | Pending |
| WIN-06 | Phase 1 | Pending |
| WIN-07 | Phase 1 | Pending |
| WIN-08 | Phase 1 | Pending |
| WIN-09 | Phase 1 | Pending |
| WIN-10 | Phase 1 | Pending |
| WIN-11 | Phase 1 | Pending |
| WIN-12 | Phase 1 | Pending |
| WIN-13 | Phase 1 | Pending |
| WIN-14 | Phase 1 | Pending |
| WIN-15 | Phase 1 | Pending |
| VID-01 | Phase 2 | Pending |
| VID-02 | Phase 2 | Pending |
| VID-03 | Phase 2 | Pending |
| CON-01 | Phase 2 | Pending |
| CON-02 | Phase 2 | Pending |
| CON-03 | Phase 2 | Pending |
| SEC-01 | Phase 3 | Pending |
| SEC-02 | Phase 3 | Pending |
| SEC-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-05-09*
*Last updated: 2026-05-09 — traceability updated with 3 phases, SEC requirements added (24 total)*
