# Requirements: Simple Player Flutter -- Window Border

**Defined:** 2026-05-07
**Core Value:** Smooth, jank-free window resize that respects video aspect ratio

## v1 Requirements

### Window Border

- [ ] **WB-01**: Custom title bar with glass-morphism (BackdropFilter blur), 36px height
- [ ] **WB-02**: Title bar shows app icon, current file name, and window controls (pin, minimize, maximize, close)
- [ ] **WB-03**: Drag-to-move window via title bar gesture
- [ ] **WB-04**: Double-tap title bar toggles maximize
- [ ] **WB-05**: During resize, BackdropFilter is skipped (isResizing notifier) to prevent GPU jank
- [ ] **WB-06**: Resize debounce (500ms) before restoring glass-morphism after drag ends

### Window Sizing -- Empty State

- [ ] **WS-01**: Minimum window size is 1024x576 (16:9) when no video is playing
- [ ] **WS-02**: Window can be freely resized to any aspect ratio in empty state
- [ ] **WS-03**: Window geometry (size, position, maximized, fullscreen) persists across sessions via SettingsStore

### Window Sizing -- Playing State

- [ ] **WP-01**: When video starts playing, window aspect ratio locks to video's aspect ratio
- [ ] **WP-02**: Resize during playback scales proportionally (maintains video aspect ratio)
- [ ] **WP-03**: Aspect ratio lock uses native AspectRatioService (MethodChannel) for OS-level enforcement
- [ ] **WP-04**: When video stops/exits, window returns to free-resize mode with minimum 16:9

### Window Controls

- [ ] **WC-01**: Pin button toggles always-on-top
- [ ] **WC-02**: Minimize button minimizes window
- [ ] **WC-03**: Maximize button toggles maximize/restore
- [ ] **WC-04**: Close button closes window safely (persist state, dispose resources)
- [ ] **WC-05**: All controls reflect current state via ValueNotifier (pinned, maximized)

### Production Quality

- [ ] **PQ-01**: All window border code passes `flutter analyze` with zero warnings
- [ ] **PQ-02**: Unit tests for WindowManagerService resize debounce, isResizing state, and persistence
- [ ] **PQ-03**: Unit tests for CustomTitleBar controls state reflection
- [ ] **PQ-04**: Edge case handling: DPI changes, monitor disconnect, rapid fullscreen toggle
- [ ] **PQ-05**: Dispose safety — all ValueNotifiers disposed, all timers cancelled, no leaks
- [ ] **PQ-06**: Error handling — all FFI/native calls wrapped in try-catch with graceful fallback
- [ ] **PQ-07**: No hardcoded values — all sizes, colors, durations from DesignTokens/constants

## v2 Requirements

- **WB-07**: Window border glow/shadow effect
- **WB-08**: Animated transitions between empty and playing states
- **WS-04**: Multi-monitor edge snapping

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom window shadow/glow | Unnecessary complexity for v1, defer to polish |
| Multi-monitor edge snapping | Not core to border experience |
| Animated window transitions | Defer to polish phase |
| Title bar theme switching | Single midnight theme for v1 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WB-01 | Phase 1 | Pending |
| WB-02 | Phase 1 | Pending |
| WB-03 | Phase 1 | Pending |
| WB-04 | Phase 1 | Pending |
| WB-05 | Phase 2 | Pending |
| WB-06 | Phase 2 | Pending |
| WS-01 | Phase 2 | Pending |
| WS-02 | Phase 2 | Pending |
| WS-03 | Phase 2 | Pending |
| WP-01 | Phase 3 | Pending |
| WP-02 | Phase 3 | Pending |
| WP-03 | Phase 3 | Pending |
| WP-04 | Phase 3 | Pending |
| WC-01 | Phase 1 | Pending |
| WC-02 | Phase 1 | Pending |
| WC-03 | Phase 1 | Pending |
| WC-04 | Phase 1 | Pending |
| WC-05 | Phase 1 | Pending |
| PQ-01 | Phase 1 | Pending |
| PQ-02 | Phase 2 | Pending |
| PQ-03 | Phase 1 | Pending |
| PQ-04 | Phase 2 | Pending |
| PQ-05 | Phase 1 | Pending |
| PQ-06 | Phase 1 | Pending |
| PQ-07 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-07*
*Last updated: 2026-05-07 after adding production quality requirements (PQ-01..07)*
