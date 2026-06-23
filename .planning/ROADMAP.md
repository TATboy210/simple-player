# Roadmap: Simple Player — Cross-Platform Window Management

**Created:** 2026-06-23
**Mode:** fine-grained (8-12 phases)

---

### Phase 1: Platform Abstraction Layer
**Goal:** Refactor WindowBridge into a platform-agnostic abstraction with factory pattern
**Mode:** mvp
**Requirements:** PLAT-01, PLAT-02, PLAT-03, PLAT-04, ARCH-01, ARCH-02, ARCH-03, ARCH-04
**Success Criteria**:
1. WindowBridge interface has no Windows-specific code
2. PlatformBridgeFactory selects correct implementation at startup
3. WindowCapabilities enum exposes platform feature queries
4. All existing Windows tests pass unchanged
5. WindowState shared model works with any bridge implementation

---

### Phase 2: Windows Bridge Refactor
**Goal:** Extract current Windows implementation into dedicated WindowsBridge, preserve all existing behavior
**Mode:** mvp
**Requirements:** WIN-01, WIN-02, WIN-03, WIN-04, XP-01, XP-03, XP-04, XP-05, XP-06
**Success Criteria**:
1. WindowsBridge wraps existing FullscreenController + WindowState + WindowPersistence
2. All v1 Windows features preserved (fullscreen, drag, resize, DPI, rounded corners)
3. Unified keyboard shortcuts registered through platform-agnostic interface
4. Window centering works via WindowBridge.center() method
5. No regression in existing 327+ tests

---

### Phase 3: Linux Window Management
**Goal:** Implement LinuxBridge with X11 and Wayland support
**Mode:** mvp
**Requirements:** LNX-01, LNX-02, LNX-03, LNX-04, LNX-05, LNX-06, LNX-07, XP-02
**Success Criteria**:
1. LinuxBridge detects X11 vs Wayland at runtime
2. Fullscreen works on X11 via _NET_WM_STATE_FULLSCREEN
3. Fullscreen works on Wayland via xdg_toplevel
4. Window geometry persists across sessions on Linux
5. Always-on-top and minimize/maximize work on both X11 and Wayland
6. Title bar renders correctly (frameless or GTK header bar)

---

### Phase 4: macOS Window Management
**Goal:** Implement MacBridge with NSWindow native integration
**Mode:** mvp
**Requirements:** MAC-01, MAC-02, MAC-03, MAC-04, MAC-05, MAC-06, MAC-07
**Success Criteria**:
1. Fullscreen uses NSWindow.toggleFullScreen: (native animation)
2. macOS title bar shows traffic light buttons correctly
3. Window geometry persists via NSWindow frame autosave or SettingsStore
4. Always-on-top uses NSWindow.level
5. Retina/HiDPI scaling works without blurriness
6. Fullscreen animation lock prevents race conditions

---

### Phase 5: ARM Architecture Validation
**Goal:** Ensure all platform builds work on ARM (Linux ARM64, macOS Apple Silicon)
**Mode:** mvp
**Requirements:** (cross-cutting — validates PLAT/LNX/MAC)
**Success Criteria**:
1. fvp engine runs on Linux ARM64
2. fvp engine runs on macOS Apple Silicon (ARM64)
3. Window management functions identically on ARM vs x86
4. No architecture-specific FFI issues

---

### Phase 6: Integration Testing & Polish
**Goal:** Cross-platform integration tests, edge cases, and UX polish
**Mode:** mvp
**Requirements:** (cross-cutting — validates all)
**Success Criteria**:
1. Integration tests pass on Windows/Linux/macOS CI
2. Fullscreen transitions are smooth on all platforms
3. Edge cases handled: multi-monitor disconnect, screen lock, sleep/wake
4. Keyboard shortcuts work consistently across platforms
5. Settings migration from Windows-only to cross-platform settings

---

## Phase Summary

| # | Phase | Goal | Requirements |
|---|-------|------|--------------|
| 1 | Platform Abstraction Layer | Refactor WindowBridge for cross-platform | PLAT-01..04, ARCH-01..04 |
| 2 | Windows Bridge Refactor | Extract Windows impl, preserve behavior | WIN-01..04, XP-01,03,04,05,06 |
| 3 | Linux Window Management | X11 + Wayland support | LNX-01..07, XP-02 |
| 4 | macOS Window Management | NSWindow native integration | MAC-01..07 |
| 5 | ARM Architecture Validation | ARM builds work | (cross-cutting) |
| 6 | Integration Testing & Polish | CI, edge cases, UX | (cross-cutting) |

**Total phases:** 6
**Requirements mapped:** 28/28 ✓

---
*Created: 2026-06-23*
