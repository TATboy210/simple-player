# Simple Player Flutter — Window Border

## What This Is

Immersive, lightweight window border for a Flutter desktop media player. The window adapts its behavior based on playback state: freely resizable with a minimum 16:9 (1024×576) constraint when empty, and locked to the video's aspect ratio during playback. The reference implementation lives at `D:\player_flutter`.

## Core Value

Smooth, jank-free window resize that respects video aspect ratio — the window should feel like part of the player, not a frame around it.

## Requirements

### Validated

- ✓ Media playback (fvp/MDK backend) — existing
- ✓ Playlist management with 4 play modes — existing
- ✓ Keyboard shortcuts (14-key handler) — existing
- ✓ Settings persistence (SharedPreferences) — existing
- ✓ Frameless window via C++ runner (WM_NCCALCSIZE) — existing
- ✓ WindowManagerService singleton with fullscreen/windowed/maximized — existing
- ✓ AspectRatioService via MethodChannel — existing

### Active

- [ ] Custom title bar with glass-morphism (BackdropFilter) and resize-aware rendering
- [ ] Empty state: minimum window size 1024×576 (16:9), freely resizable
- [ ] Playing state: window aspect ratio locks to video, resize scales proportionally
- [ ] Smooth resize: skip BackdropFilter during drag, debounce before restoring
- [ ] Drag-to-move via title bar, double-tap to maximize
- [ ] Window controls: pin, minimize, maximize, close

### Out of Scope

- Custom window shadow/glow effects — unnecessary complexity for v1
- Multi-monitor edge snapping — not core to border experience
- Animated window transitions — defer to polish phase

## Context

- **Reference project**: `D:\player_flutter` has a working `CustomTitleBar` (glass-morphism, resize-aware) and `WindowManagerService` (500ms debounce, isResizing notifier, Completer guards)
- **Current codebase**: Already has `WindowManagerService`, `AspectRatioService`, `PlatformService` abstract interface. `PlayerScreen` was recently stripped to bare video surface.
- **Key pattern**: `isResizing` ValueNotifier lets UI skip GPU-heavy `BackdropFilter` during drag, preventing jank.

## Constraints

- **Platform**: Windows primary (C++ runner, WM_NCCALCSIZE)
- **State**: ValueNotifier + ValueListenableBuilder (no Provider/Riverpod/Bloc)
- **Design**: Glass-morphism via `BackdropFilter` + `Tokens.bgGlass`
- **Performance**: Must not regress — resize debounce, persistence debounce

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Reuse reference project's CustomTitleBar pattern | Proven glass-morphism + resize optimization | — Pending |
| Minimum size 1024×576 (vs 640×360 in reference) | Better default for modern displays | — Pending |
| Aspect ratio lock on playback | Core user experience requirement | — Pending |

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
*Last updated: 2026-05-07 after initialization*
