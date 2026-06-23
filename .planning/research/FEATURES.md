# Feature Landscape: Cross-Platform Window Management

**Domain:** Flutter desktop media player window management (Windows / Linux / macOS)
**Researched:** 2026-06-23
**Confidence:** HIGH (mpv/VLC/Kodi documented behaviors + existing codebase analysis + window_manager API surface)

## Table Stakes

Features every desktop media player must have. Missing any = users switch to VLC/mpv.

### 1. Frameless Window with Custom Title Bar

**Why Expected:** VLC (minimal interface), mpv (`--no-border`), Kodi (borderless mode) all support this. Users expect clean, distraction-free video viewing without OS chrome eating screen space.

**Current State:** DONE. `WindowService` uses `window_manager` with `TitleBarStyle.hidden`, custom `CustomTitleBar` widget provides drag-to-move + window controls.

**Complexity:** Already implemented.

---

### 2. Fullscreen Toggle (Atomic, No Flicker)

**Why Expected:** Every media player has this. mpv (`f` key), VLC (`F`/`F11`), Kodi (dedicated fullscreen mode). The transition must be atomic -- no flash, no intermediate frames showing border.

**Current State:** DONE. `FullscreenController` with mutex + `SetWindowPos` atomic resize. Win32 FFI handles `WS_THICKFRAME` removal/restoration.

**Complexity:** Already implemented (Windows). Linux/macOS need `window_manager.setFullScreen()` wrapper.

---

### 3. Always-on-Top

**Why Expected:** mpv (`--ontop`), VLC (`Ctrl+T`), all support pinning window above others. Essential for multitasking -- watching video while working.

**Current State:** DONE. `WindowService.setAlwaysOnTop()` with `ValueNotifier<bool>` state.

**Complexity:** Already implemented. Cross-platform via `window_manager`.

---

### 4. Window Geometry Persistence (Position + Size)

**Why Expected:** mpv (watch-later files), VLC (`save-window-geometry` setting), Kodi (guisettings.xml). Users expect window to reopen where they left it.

**Current State:** DONE. `WindowPersistence` with 500ms debounce + atomic `.tmp` write. Saves position, size, maximized state.

**Complexity:** Already implemented.

---

### 5. Edge Resize with Minimum Size Constraint

**Why Expected:** Standard window behavior. All platforms enforce minimum size to prevent UI breakage.

**Current State:** DONE. `minimumSize: Size(854, 480)` in `WindowOptions`. `DragToResizeArea` widget for frameless resize.

**Complexity:** Already implemented.

---

### 6. DPI / Per-Monitor Scaling Awareness

**Why Expected:** Multi-monitor setups are common (laptop + external). Windows 10+ has Per-Monitor v2, macOS uses Retina 2x, Linux Wayland has `wl_output.scale`. Media players must render correctly on all monitors.

**Current State:** DONE. Flutter handles per-monitor DPI natively. No custom code needed.

**Complexity:** Already handled by framework.

---

### 7. Keyboard Shortcut for All Window Operations

**Why Expected:** mpv (20+ keys), VLC (comprehensive shortcuts). Power users never touch the mouse for window control.

**Current State:** DONE. `KeyboardHandler` handles 20+ keys including Space, F (fullscreen), M (mute), arrows, etc.

**Complexity:** Already implemented.

---

### 8. Aspect Ratio Lock During Resize

**Why Expected:** mpv (`--keepaspect`), VLC (aspect ratio menu). Video windows should maintain 16:9 (or native ratio) when user drags to resize. Prevents distorted video.

**Current State:** DONE. C++ `WM_SIZING` handler enforces ratio on all 8 edges. `AspectRatioService` manages toggle.

**Complexity:** Already implemented (Windows C++). Linux/macOS need `window_manager`-based approach.

---

## Differentiators

Features that go beyond expectations. These make users prefer your player over VLC/mpv.

### 9. Rounded Corners on Windows 11

**Value:** Matches OS design language. Win11 apps without rounded corners look broken. VLC/mpv don't do this -- they show square corners.

**Complexity:** Low (3-line C++ fix: `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` in `OnCreate`).

**Dependencies:** None. Windows-only.

**Status:** Documented in memory (`project_window_corner_fix`). Needs verification on current branch.

---

### 10. Responsive Layout for Narrow Windows

**Value:** Player adapts when squeezed below 600dp -- control bar collapses to single row, playlist panel overlays instead of side-by-side. VLC/mpv don't adapt well to small sizes.

**Complexity:** Medium. Already partially done (responsive breakpoints in `PlayerScreen`).

**Dependencies:** None.

---

### 11. Glass-Morphism Control Bar (Blur + Transparency)

**Value:** Visual polish that VLC/mpv lack. `BackdropFilter` + `bgGlass` + `borderHighlight` creates modern aesthetic. Matches Fluent Design (Win11) and macOS vibrancy.

**Complexity:** Medium. `GlassContainer` widget already exists with 3-tier blur (thin/normal/thick).

**Dependencies:** None. Already implemented.

---

### 12. Auto-Hide Controls in Fullscreen

**Value:** mpv hides cursor after timeout, VLC has minimal mode. But auto-hide with smooth fade animation is rare. Controls reappear on mouse movement.

**Complexity:** Medium. `ControlsOverlay` with `AnimationController` + mouse listener. Fullscreen 3s / windowed 5s timeout.

**Dependencies:** Fullscreen toggle (#2).

**Status:** DONE.

---

### 13. Drag-and-Drop File Opening

**Value:** Convenience feature. Drop video files onto player window to open. VLC supports this, mpv does not natively.

**Complexity:** Low. `DropHandler` widget with `DragTarget`.

**Dependencies:** None.

**Status:** DONE.

---

### 14. OSD (On-Screen Display) Pill Notifications

**Value:** mpv shows volume/position in OSD. Custom OSD pill for volume change, speed change, aspect ratio switch gives feedback without looking at controls.

**Complexity:** Low. `OsdOverlay` widget with fade animation.

**Dependencies:** None.

**Status:** DONE.

---

### 15. Window Entrance Animation (First Launch)

**Value:** Delight moment. 200ms scale-up from 95% with ease-out curve. Spotify does this. VLC/mpv don't.

**Complexity:** Low. `AnimatedBuilder` + `Transform.scale` on first frame. Pure Dart, no platform dependency.

**Dependencies:** None.

**Status:** NOT IMPLEMENTED. Low priority.

---

### 16. Multi-Monitor Window Clamping

**Value:** When monitors are disconnected, window can end up off-screen. Smart clamping detects available displays and repositions window. Most apps don't handle this -- users have to edit config files.

**Complexity:** Medium. `ScreenUtils` already has display detection. Need to add clamping logic in `WindowPersistence.load()`.

**Dependencies:** Geometry persistence (#4).

**Status:** Partially done (window_manager handles some cases).

---

### 17. System Tray Minimize (Audio Continues)

**Value:** VLC has this. Minimize to tray while audio keeps playing. Useful for music/podcast playback in background.

**Complexity:** Medium. Need `system_tray` package + minimize-to-tray logic. Cross-platform but platform-specific icon handling.

**Dependencies:** None.

**Status:** NOT IMPLEMENTED. Defer to v2.

---

### 18. Picture-in-Picture (Floating Mini Player)

**Value:** Windows 11 native PiP, VLC floating window. Small always-on-top window for casual viewing while working.

**Complexity:** High. Need small window instance OR overlay window. Platform-specific (Win32 `WS_EX_TOOLWINDOW`, macOS `NSPanel`, Linux `_NET_WM_WINDOW_TYPE_DOCK`).

**Dependencies:** Always-on-top (#3).

**Status:** NOT IMPLEMENTED. Defer to v2+. Complexity explosion with shared D3D11 device.

---

### 19. Video Wallpaper / Desktop Mode

**Value:** mpv (`--wid=0`), VLC (DirectX wallpaper mode). Render video behind desktop icons as animated wallpaper.

**Complexity:** Very High. Win32: find `WorkerW` window, render behind it. macOS: `NSWindow.level = .desktopWindow`. Linux: `_NET_WM_WINDOW_TYPE_DESKTOP`.

**Dependencies:** Platform-specific FFI.

**Status:** NOT IMPLEMENTED. Niche feature, defer to v2+.

---

### 20. Window Snap Assist Integration

**Value:** Windows 11 Snap Layouts (`Win+Z`), macOS tiling (Sequoia+), Linux tiling WMs. App should respond correctly to OS snap commands.

**Complexity:** Low. Standard `WS_THICKFRAME` window on Windows gets snap for free. Frameless windows need `WS_THICKFRAME` restored (already handled in fullscreen exit).

**Dependencies:** Frameless implementation (#1).

**Status:** Works automatically when `WS_THICKFRAME` is present during windowed mode.

---

## Anti-Features

Features to explicitly NOT build. Complexity explosion with minimal user value.

| Anti-Feature | Why Avoid | What to Do Instead |
|---|---|---|
| Custom window chrome per-platform (native title bar buttons on macOS) | `window_manager` already handles this; custom implementation breaks on OS updates | Use `window_manager`'s `windowButtonVisibility` + platform defaults |
| Skin/theme system (VLC-style) | Massive UI framework for minimal value; VLC skins are mostly abandoned | Single design system (`Tokens.*`) with dark/light toggle at most |
| Window state sync across instances | Multi-instance state sync needs IPC/sockets; edge case complexity | Single instance enforcement OR independent persistence per instance |
| Custom WM_NCCALCSIZE handler in C++ | Flutter engine intercepts before custom code; 3 documented failed approaches | Use Dart-side `setFrameless()` + `DWMWA_WINDOW_CORNER_PREFERENCE` in C++ `OnCreate` |
| Full ABR algorithm suite (BBA + BOLA + MPC) | Over-engineering for desktop player; browser players need this because network is shared | Implement throughput-based first; skip BOLA/MPC |
| Custom HLS demuxer | FFmpeg already handles HLS | Use FFmpeg's built-in demuxer; configure via `setProperty()` |
| Offline HLS segment caching | Desktop has local files; different use case than mobile | Not needed |
| Multi-player / multi-window | Complexity explosion with shared D3D11 device; each window needs own swap chain | Defer to v2+ with separate engine instances |
| `get_it` / service locator | Contradicts "no state management library" constraint; hides dependencies | Constructor injection via PlayerServices |
| `part/part of` for file splitting | Dart officially discourages; creates hidden coupling | Separate files with explicit imports |
| State management migration (Riverpod/Bloc) | ValueNotifier works; migration cost with zero user-visible benefit | Keep ValueNotifier pattern |
| Skinnable UI / user-customizable layouts | Massive abstraction layer; 95% of users never change defaults | Single polished design |

## Feature Dependencies

```
Frameless window (1) ──> all other features depend on this
Fullscreen (2) ──> auto-hide controls (12), window snap (20)
Always-on-top (3) ──> PiP (18)
Geometry persistence (4) ──> multi-monitor clamping (16)
Edge resize (5) ──> aspect ratio lock (8)
Aspect ratio lock (8) ──> C++ WM_SIZING (Windows), window_manager (Linux/macOS)
Rounded corners (9) ──> C++ DWMWA (Windows only)
Glass-morphism (11) ──> independent, no dependencies
OSD (14) ──> independent, no dependencies
Entrance animation (15) ──> independent, no dependencies
System tray (17) ──> independent, adds system_tray dependency
PiP (18) ──> always-on-top (3), high platform complexity
Video wallpaper (19) ──> platform FFI, very high complexity
```

## Cross-Platform Gaps

Features that work on Windows but need Linux/macOS implementation:

| Feature | Windows Status | Linux Approach | macOS Approach | Effort |
|---|---|---|---|---|
| Frameless window | DONE (Win32 FFI) | `window_manager` API | `window_manager` API | Low |
| Fullscreen (atomic) | DONE (SetWindowPos) | `window_manager.setFullScreen()` | `NSWindow.toggleFullScreen` via FFI | Medium |
| Aspect ratio lock | DONE (C++ WM_SIZING) | `window_manager` setAspectRatio | `NSWindow.contentAspectRatio` | Medium |
| Edge resize (frameless) | DONE (DragToResizeArea) | Works via `window_manager` | Works via `window_manager` | Low |
| Rounded corners | DONE (DWMWA) | N/A (depends on WM) | N/A (always rounded) | N/A |
| Window persistence | DONE | Same Dart code | Same Dart code | None |
| Always-on-top | DONE | `window_manager` API | `NSWindow.level` via FFI | Low |

**Estimated porting effort:** 3-6 days per platform (Linux, macOS). Only `WindowService` internals change.

## MVP Recommendation

**Already Done (table stakes complete):**
1. Frameless window + custom title bar
2. Fullscreen toggle (atomic)
3. Always-on-top
4. Geometry persistence
5. Edge resize + minimum size
6. DPI awareness
7. Keyboard shortcuts
8. Aspect ratio lock (Windows)
9. Glass-morphism controls
10. Auto-hide controls
11. Drag-and-drop
12. OSD notifications

**Prioritize Next:**
1. **Rounded corners (#9)** -- 3-line C++ fix, high visual impact
2. **Multi-monitor clamping (#16)** -- prevents user frustration on monitor disconnect
3. **Window snap integration (#20)** -- works automatically, just verify

**Defer:**
- **Entrance animation (#15)** -- polish, not functional
- **System tray (#17)** -- v2, needs new dependency
- **PiP (#18)** -- v2+, very high complexity
- **Video wallpaper (#19)** -- v2+, niche

## Sources

- mpv manual: https://mpv.io/manual/master/ -- window options (geometry, autofit, ontop, border, keepaspect)
- VLC documentation: https://www.videolan.org/vlc/ -- minimal interface, save geometry, resume playback
- Kodi wiki: https://kodi.wiki/ -- display modes (fullscreen, borderless, windowed)
- Memory: `project_window_cross_platform` -- window_manager cross-platform strategy
- Memory: `project_full_architecture` -- 5-layer architecture, WindowService composition
- Memory: `anti_pattern_window_frameless` -- 3 failed C++ frameless approaches
- Memory: `project_window_corner_fix` -- DWM corner preference fix
- Memory: `project_fullscreen_win32_fix` -- Win32 FFI fullscreen rewrite
- Codebase: `lib/kernel/bridge/window_service.dart` -- current WindowService implementation
- Codebase: `lib/ui/player/player_screen.dart` -- PlayerScreen responsive layout
