# Simple Player Flutter — Cross-Platform Window Management

## What This Is

A Flutter desktop media player (Simple Player) that currently runs on Windows only. This project adds cross-platform window management to support Windows, Linux, and macOS on both x86 and ARM architectures. The player uses fvp (MDK/FFmpeg) for media playback with D3D11 texture rendering.

## Core Value

Seamless, native-quality window management across all three desktop platforms — fullscreen, maximize, minimize, drag, resize, persistence — without sacrificing the existing Windows experience.

## Requirements

### Validated

- ✓ Custom frameless title bar (32px) — existing
- ✓ Drag-to-move window (window_manager) — existing
- ✓ Double-click title bar toggle maximize — existing
- ✓ Minimize / maximize / restore / close — existing
- ✓ Always-on-top toggle + persistence — existing
- ✓ Fullscreen toggle (FullscreenController, mutex + atomic + rollback) — existing
- ✓ Window geometry persistence (position/size/state) — existing
- ✓ DragToResizeArea edge resize — existing
- ✓ Resize BackdropFilter skip (GPU optimization) — existing
- ✓ Rounded corners (DWMWCP_ROUND) — existing
- ✓ DPI adaptation (Win32 PerMonitor V1) — existing
- ✓ Minimum window size (854×480) — existing

### Active

- [ ] Cross-platform WindowBridge abstraction (Windows/Linux/macOS)
- [ ] Linux window management (X11 + Wayland)
- [ ] macOS window management (NSWindow + native fullscreen)
- [ ] Platform-specific fullscreen (Win32 FFI / NSWindow / _NET_WM_STATE)
- [ ] Cross-platform window geometry persistence
- [ ] Platform-detection and capability negotiation
- [ ] Cross-platform title bar (macOS native / Linux GTK / Windows custom)
- [ ] ARM architecture validation (fvp + window management)
- [ ] Unified keyboard shortcuts across platforms
- [ ] Cross-platform DPI/HiDPI scaling

### Out of Scope

- Exclusive fullscreen (ChangeDisplaySettingsEx) — media players use borderless fullscreen
- Multi-monitor blanking (Kodi-style) — niche feature
- Mobile platforms (Android/iOS) — desktop-only player
- Wayland-only builds — X11 compatibility layer still needed for older distros

## Context

### Current Architecture (v1 Windows-only)

The v1 player uses:
- **window_manager** (0.5.1) — Flutter plugin for window control (setFullScreen, setAsFrameless, startDragging)
- **Win32 C++ runner** — custom main.cpp with DWM dark mode, rounded corners, DPI support
- **FullscreenController** — atomic fullscreen with mutex guard, save/rollback, Completer-based isOperating signal
- **WindowService** — thin coordinator composing WindowState + FullscreenController + WindowPersistence
- **WindowBridge** — abstract interface (4 state ValueNotifiers + 6 command methods)

### Cross-Platform Research Findings

From analyzing mpv, Kodi, and VLC:

1. **mpv Windows**: Removes WS_THICKFRAME for fullscreen, keeps WS_OVERLAPPED | WS_MINIMIZEBOX
2. **mpv macOS**: Uses NSWindow.styleMask = .borderless + NSApp.presentationOptions for fullscreen
3. **mpv Linux**: _NET_WM_STATE_FULLSCREEN (X11) / xdg_toplevel_set_fullscreen (Wayland)
4. **Kodi**: FULLSCREEN_WINDOW_STYLE removes WS_CAPTION, supports fake fullscreen + exclusive mode
5. **All mature players**: Use animation locks (NSCondition / m_IsAlteringWindow / Completer)
6. **macOS fullscreen**: All players use NSWindow.toggleFullScreen: — one-line solution
7. **Flutter limitation**: window_manager is a thin wrapper; platform-specific FFI needed for fine control

### Key Technical Decisions

- Keep window_manager as base layer, extend with platform-specific FFI where needed
- WS_POPUP approach for Windows fullscreen (already proven in v1)
- Native NSWindow APIs for macOS (no FFI needed — Flutter's macOS runner uses NSWindow directly)
- XDG shell for Wayland, _NET_WM_STATE for X11
- Preserve existing WindowBridge abstraction — add platform implementations

## Constraints

- **Flutter desktop**: All three platforms must use Flutter's official desktop support
- **fvp engine**: Media engine uses D3D11 on Windows, needs Vulkan/OpenGL backends on Linux/macOS
- **window_manager 0.5.1**: Current dependency — may need to fork or replace for Linux/macOS gaps
- **No breaking changes**: v1 Windows experience must not regress
- **Architecture**: Keep WindowBridge as abstract interface; platform impls behind it

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep WindowBridge abstraction | Clean platform separation, testable | — Pending |
| Use native platform APIs over Flutter plugins | Fine-grained control (mpv/Kodi pattern) | — Pending |
| Borderless fullscreen only (no exclusive) | Media player standard, simpler, no resolution changes | — Pending |
| Preserve v1 Windows FFI approach | Proven WS_THICKFRAME removal + SetWindowPos atomic | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-23 after initialization*
