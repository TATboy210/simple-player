# Feature Landscape

**Domain:** Desktop media player fullscreen management
**Researched:** 2026-07-11

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Toggle fullscreen (F key) | Standard media player behavior | Low | Already implemented, keep |
| Double-click to toggle | Standard media player behavior | Low | Already implemented, keep |
| ESC to exit fullscreen | Standard media player behavior | Low | Already implemented, keep |
| Restore window position on exit | Users expect their layout preserved | Low | Keep, simplify implementation |
| Auto-hide controls in fullscreen | Standard media player behavior | Low | Already implemented, keep |
| Cursor hide in fullscreen | Standard media player behavior | Low | Already implemented, keep |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| WS_THICKFRAME border fix | Eliminates 7px gap on Windows | Medium | Keep Win32 FFI implementation |
| Focus recovery after exit | Prevents focus loss on Windows | Low | Keep in WindowsFullscreenDriver |
| TopMost cleanup | Prevents always-on-top after exit | Low | Keep in WindowsFullscreenDriver |
| Minimized state handling | Restore before fullscreen | Low | Keep in DesktopFullscreenAdapter |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-window fullscreen | App has one window | Remove per-window data structures |
| Multi-display targeting | App doesn't support display selection | Remove displayId parameter |
| Exclusive fullscreen | Not supported by Flutter desktop | Remove FullscreenMode.exclusive |
| Command queue serialization | No concurrent commands | Use direct await |
| 7-type error hierarchy | 6 of 7 types unused | Use try/catch |
| Capability query system | No UI depends on it | Remove FullscreenCapability |

## Feature Dependencies

```
F key toggle -> WindowService.setMode -> fullscreen enter/leave
Double-click -> ControlsOverlay._handleTap -> fullscreen toggle
ESC -> KeyboardHandler.onExitFullscreen -> fullscreen exit
Restore bounds -> save before enter -> restore on exit
Auto-hide -> AutoHideController (reads isFullscreen)
```

## MVP Recommendation

Prioritize:
1. F key / double-click / ESC toggle (already working)
2. Restore window position on exit (already working)
3. Auto-hide controls (already working)
4. Win32 border fix (already working)

Defer: Nothing -- all table stakes features are already implemented. The task is simplification, not feature addition.

## Sources

- Direct codebase analysis
- User feedback: "over-engineered"
