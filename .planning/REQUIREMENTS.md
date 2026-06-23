# Requirements: Simple Player — Cross-Platform Window Management

**Defined:** 2026-06-23
**Core Value:** Seamless, native-quality window management across Windows/Linux/macOS without regressions

## v1 Requirements

### Platform Abstraction

- [ ] **PLAT-01**: WindowBridge interface supports platform-specific implementations (Windows/Linux/macOS)
- [ ] **PLAT-02**: Platform detection at startup selects correct WindowBridge implementation
- [ ] **PLAT-03**: Platform capabilities are queryable (supportsRoundedCorners, supportsNativeFullscreen, etc.)
- [ ] **PLAT-04**: Shared state model (WindowState) works identically across all platforms

### Linux Window Management

- [ ] **LNX-01**: X11 window management via _NET_WM_STATE_FULLSCREEN and XChangeProperty
- [ ] **LNX-02**: Wayland window management via xdg_toplevel_set_fullscreen
- [ ] **LNX-03**: Runtime X11/Wayland detection and appropriate backend selection
- [ ] **LNX-04**: Linux title bar (GTK header bar or custom frameless)
- [ ] **LNX-05**: Linux window geometry persistence (position/size/state)
- [ ] **LNX-06**: Linux always-on-top via _NET_WM_STATE_ABOVE
- [ ] **LNX-07**: Linux minimize/maximize via EWMH hints

### macOS Window Management

- [ ] **MAC-01**: NSWindow-based fullscreen via toggleFullScreen: (native API)
- [ ] **MAC-02**: macOS title bar (native NSWindow title bar or custom traffic lights)
- [ ] **MAC-03**: macOS window geometry persistence (NSWindow frame autosave)
- [ ] **MAC-04**: macOS always-on-top via NSWindow.level
- [ ] **MAC-05**: macOS minimize via NSWindow.miniaturize
- [ ] **MAC-06**: macOS HiDPI/Retina scaling support
- [ ] **MAC-07**: macOS animation lock for fullscreen transitions (NSCondition)

### Windows Enhancements

- [ ] **WIN-01**: Preserve existing Win32 FFI fullscreen (WS_THICKFRAME removal)
- [ ] **WIN-02**: Preserve existing DWM rounded corners + dark mode
- [ ] **WIN-03**: Preserve existing DPI adaptation (PerMonitor V1)
- [ ] **WIN-04**: Preserve existing DragToResizeArea edge resize

### Cross-Platform Features

- [ ] **XP-01**: Unified keyboard shortcuts across all platforms (Space/F/M/N/P/O etc.)
- [ ] **XP-02**: Cross-platform window geometry persistence (same SettingsStore API)
- [ ] **XP-03**: Cross-platform fullscreen with atomic mutex guard (existing pattern)
- [ ] **XP-04**: Cross-platform auto-hide title bar on fullscreen
- [ ] **XP-05**: Cross-platform minimum window size enforcement
- [ ] **XP-06**: Cross-platform window centering on first launch

### Architecture

- [ ] **ARCH-01**: Platform implementations behind WindowBridge abstraction (no platform code in UI)
- [ ] **ARCH-02**: Each platform has its own bridge implementation file
- [ ] **ARCH-03**: Factory pattern for platform bridge instantiation
- [ ] **ARCH-04**: Existing v1 tests continue passing on Windows

## v2 Requirements

### Advanced Platform Features

- **ADV-01**: Multi-monitor support (detect, move window, remember per-monitor settings)
- **ADV-02**: Linux snap layouts (tiling window manager hints)
- **ADV-03**: macOS Stage Manager integration
- **ADV-04**: Windows snap layouts (Win11 snap assist)
- **ADV-05**: Platform-specific gesture support (trackpad pinch-zoom, three-finger swipe)

### Media Engine Cross-Platform

- **ENG-01**: fvp engine with Vulkan backend on Linux (instead of D3D11)
- **ENG-02**: fvp engine with Metal/OpenGL backend on macOS
- **ENG-03**: ARM-native fvp builds (Linux ARM64, macOS ARM64/Apple Silicon)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Exclusive fullscreen (ChangeDisplaySettingsEx) | Media players use borderless fullscreen; exclusive mode is gaming-specific |
| Multi-monitor blanking (Kodi-style) | Niche feature, high complexity, low user demand |
| Mobile platforms (Android/iOS) | Desktop-only player; different UI paradigm |
| Wayland-only builds | Older distros still need X11; use runtime detection instead |
| Custom window chrome on Linux (CSD) | GTK header bar or frameless sufficient; CSD adds complexity |
| Window tiling WM integration (i3/sway) | WMs handle tiling; player just needs to respect WM hints |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01 | Phase 1 | Pending |
| PLAT-02 | Phase 1 | Pending |
| PLAT-03 | Phase 1 | Pending |
| PLAT-04 | Phase 1 | Pending |
| ARCH-01 | Phase 1 | Pending |
| ARCH-02 | Phase 1 | Pending |
| ARCH-03 | Phase 1 | Pending |
| ARCH-04 | Phase 1 | Pending |
| WIN-01 | Phase 2 | Pending |
| WIN-02 | Phase 2 | Pending |
| WIN-03 | Phase 2 | Pending |
| WIN-04 | Phase 2 | Pending |
| XP-01 | Phase 2 | Pending |
| XP-03 | Phase 2 | Pending |
| XP-04 | Phase 2 | Pending |
| XP-05 | Phase 2 | Pending |
| XP-06 | Phase 2 | Pending |
| LNX-01 | Phase 3 | Pending |
| LNX-02 | Phase 3 | Pending |
| LNX-03 | Phase 3 | Pending |
| LNX-04 | Phase 3 | Pending |
| LNX-05 | Phase 3 | Pending |
| LNX-06 | Phase 3 | Pending |
| LNX-07 | Phase 3 | Pending |
| XP-02 | Phase 3 | Pending |
| MAC-01 | Phase 4 | Pending |
| MAC-02 | Phase 4 | Pending |
| MAC-03 | Phase 4 | Pending |
| MAC-04 | Phase 4 | Pending |
| MAC-05 | Phase 4 | Pending |
| MAC-06 | Phase 4 | Pending |
| MAC-07 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-23*
*Last updated: 2026-06-23 after initial definition*
