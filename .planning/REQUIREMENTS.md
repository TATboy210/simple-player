# Requirements: Simple Player Flutter

**Defined:** 2026-05-09
**Updated:** 2026-05-13
**Core Value:** Stable, efficient, secure frameless window with video playback — every control must work reliably

## v1 Requirements

### Button Highlight (HIGH — user-visible bug)

- [ ] **BTN-01**: Volume button icon turns cyan (#66CCFF) when popup is open
- [ ] **BTN-02**: Speed button text turns cyan with border when popup is open
- [ ] **BTN-03**: Highlight persists while popup is visible (no premature clearing)
- [ ] **BTN-04**: Popup auto-closes when control bar auto-hides
- [ ] **BTN-05**: Close animation consistent — highlight stays during fade-out, clears on remove

### Fullscreen (HIGH — core functionality)

- [ ] **FS-01**: F key toggles fullscreen reliably
- [ ] **FS-02**: Fullscreen button in control bar toggles fullscreen
- [ ] **FS-03**: Double-click video area toggles fullscreen
- [ ] **FS-04**: ESC exits fullscreen
- [ ] **FS-05**: Mode ValueNotifier updates optimistically (not waiting for callback)
- [ ] **FS-06**: Fullscreen state persists across sessions
- [ ] **FS-07**: Aspect ratio unlocks in fullscreen, restores on exit

### Settings (MEDIUM — functionality gap)

- [ ] **SET-01**: Settings button opens dialog from control bar
- [ ] **SET-02**: Equalizer presets apply correctly
- [ ] **SET-03**: Audio track selection works
- [ ] **SET-04**: Video processing sliders persist
- [ ] **SET-05**: Fallback text correct for each tab (not l10n.noAudioTracks for video processing)

### Code Quality (MEDIUM — production readiness)

- [ ] **CODE-01**: Remove dead WindowManagerService (515 lines)
- [ ] **CODE-02**: Fix KeyboardHandler 'A' key (currently swallows key with no action)
- [ ] **CODE-03**: AspectRatioService labels use l10n (not hardcoded Chinese)
- [ ] **CODE-04**: No unused imports or dead code
- [ ] **CODE-05**: All popup overlay entries cleaned up on dispose

## v2 Requirements

### Playback UI Polish

- **PLY-01**: 10-band equalizer (replace 5 presets)
- **PLY-02**: AB loop button (kernel supports, UI deferred)
- **PLY-03**: Subtitle overlay positioning
- **PLY-04**: Media info dialog enhancements

### Settings

- **SET-10**: General settings tab (language, theme, startup behavior)
- **SET-11**: Keyboard shortcut customization

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mobile platforms | Desktop only |
| Network streaming / DRM | Local files only |
| Custom equalizer (10-band) | 5 presets sufficient for v1 |
| General settings tab | v2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BTN-01 | Phase 1 | Pending |
| BTN-02 | Phase 1 | Pending |
| BTN-03 | Phase 1 | Pending |
| BTN-04 | Phase 1 | Pending |
| BTN-05 | Phase 1 | Pending |
| FS-01 | Phase 2 | Pending |
| FS-02 | Phase 2 | Pending |
| FS-03 | Phase 2 | Pending |
| FS-04 | Phase 2 | Pending |
| FS-05 | Phase 2 | Pending |
| FS-06 | Phase 2 | Pending |
| FS-07 | Phase 2 | Pending |
| SET-01 | Phase 3 | Pending |
| SET-02 | Phase 3 | Pending |
| SET-03 | Phase 3 | Pending |
| SET-04 | Phase 3 | Pending |
| SET-05 | Phase 3 | Pending |
| CODE-01 | Phase 4 | Pending |
| CODE-02 | Phase 4 | Pending |
| CODE-03 | Phase 4 | Pending |
| CODE-04 | Phase 4 | Pending |
| CODE-05 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-05-09*
*Last updated: 2026-05-13 — refocused on button highlight, fullscreen, settings, code quality*
