# Architecture Research: Window Chrome Fixes & Fullscreen Transition

**Domain:** Flutter desktop media player window-chrome layer (v1.1 milestone)
**Researched:** 2026-09-01
**Confidence:** HIGH (integration points verified by reading actual source; DWM API claims verified against Microsoft Learn docs)

## Executive Summary

The four fixes (accent border, rounded corners, flicker-free fullscreen, title bar drag) all cross the same three layers: **runner C++** (`windows/runner/`), **window_bridge Dart** (`lib/kernel/window_Bridge/`), and **media_kit native fullscreen chain** (`media_kit_video` windows plugin). The existing architecture already has two load-bearing invariants that every fix must respect:

- **C1** — `WM_NCCALCSIZE` 8px inset fix: `FlutterWindow::MessageHandler` (`flutter_window.cpp:63-71`) intercepts `WM_NCCALCSIZE` when `WS_OVERLAPPEDWINDOW` is fully removed (media_kit fullscreen) and returns 0, so client area = whole window with no seam. `Win32Window::MessageHandler` (`win32_window.cpp:243-246`) is the纵深防御 fallback that also returns 0.
- **C2** — `WindowMode` single source of truth: `_TitleBarDragArea`, `PlayerVideoControls._syncModeFullscreen`, `WindowResizeCoordinator._settle`, and `WindowPersistenceCoordinator._saveSerialized` all read fullscreen state from `_state.mode` (`WindowServiceState`), never from `VideoState.isFullscreen`. Every fullscreen transition must commit via `WindowModeCoordinator._commit` / `syncFullscreenState`.

The cleanest integration principle: **native window appearance (border color, corner radius, frame style) belongs in runner C++ alongside C1; window-mode semantics and transition timing belong in window_bridge Dart alongside C2; per-OS capability detection is a C++ responsibility because `RtlGetVersion` and DWM attribute availability are native facts.** The Dart layer should never probe Win32 build numbers via FFI when the C++ layer already holds the HWND.

## System Overview — Current Layered Architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ UI LAYER (Flutter widgets)                                              │
│  CustomTitleBar ─ _TitleBarDragArea ─ GestureDetector.onPanStart        │
│  PlayerVideoControls._toggleFullscreen ─ onToggleFullscreen callback    │
│  PlayerScreen.onToggleFullscreen ─ windowService.setMode(...)           │
└──────────────┬───────────────────────────────────┬──────────────────────┘
               │ startDragging() / setMode()       │ video.toggleFullscreen()
               v                                   v
┌──────────────────────────────────┐  ┌───────────────────────────────────┐
│ WINDOW BRIDGE (Dart, lib/kernel/ │  │ MEDIA_KIT VIDEO CHAIN             │
│  window_Bridge/)                 │  │  Video.controls builder           │
│  WindowService (coordinator)     │  │  enterFullscreen/exitFullscreen   │
│   ├ WindowModeCoordinator (C2)   │  │  PageRouteBuilder(Duration.zero)  │
│   ├ WindowResizeCoordinator      │  │  defaultEnterNativeFullscreen     │
│   ├ WindowPersistenceCoordinator │  │   └ MethodChannel                │
│   └ WindowServiceState (notifiers)│  └──────────┬────────────────────────┘
│  WindowBridge (interface)        │             │ Utils.EnterNativeFullscreen
└──────────────┬───────────────────┘             v
               │ windowManager (package)   ┌──────────────────────────────┐
               v                           │ media_kit_video windows      │
┌──────────────────────────────┐           │  utils.cc                    │
│ window_manager 5.15.0        │           │   EnterNativeFullscreen:     │
│  startDragging → MethodChannel│          │    SetWindowLongPtr(~WS_OVER)│
│  maximize/unmaximize/show    │           │    SetWindowPos(monitor rect)│
└──────────────┬───────────────┘           └──────────────┬───────────────┘
               │                                          │
               v                                          v
┌─────────────────────────────────────────────────────────────────────────┐
│ RUNNER C++ (windows/runner/)                                            │
│  FlutterWindow::MessageHandler (flutter_window.cpp)                     │
│   ├ WM_NCCALCSIZE: media_kit fullscreen抢跑 (C1) ──────────────────────│
│   └ HandleTopLevelWindowProc → window_manager plugin delegate           │
│  Win32Window::MessageHandler (win32_window.cpp)                         │
│   ├ WM_NCCALCSIZE: return 0 fallback (C1)                               │
│   ├ WM_NCHITTEST: HitTestWindowEdge (8px resize, kResizeBorderWidth)    │
│   ├ WM_ERASEBKGND: return 1 (suppress fullscreen route bg flash)        │
│   └ WM_DPICHANGED / WM_SIZE / WM_DESTROY                               │
│  main.cpp: wWinMain → FlutterWindow::Create → MSG loop                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | File | Communicates With |
|-----------|---------------|------|-------------------|
| `FlutterWindow::MessageHandler` | Top-level WndProc; media_kit fullscreen NCCALCSIZE抢跑 (C1); forwards to plugin delegate then base | `windows/runner/flutter_window.cpp:46` | window_manager plugin (HandleTopLevelWindowProc), `Win32Window::MessageHandler` |
| `Win32Window::MessageHandler` | Base WndProc; NCCALCSIZE fallback (C1), WM_NCHITTEST 8px edges, WM_ERASEBKGND suppression | `windows/runner/win32_window.cpp:198` | `FlutterWindow` (inheritance), DefWindowProc |
| `HitTestWindowEdge` | Pure function: screen-point → HT* edge code (8px borders, corners first) | `windows/runner/win32_window.cpp:50` | `Win32Window::MessageHandler` (WM_NCHITTEST) |
| `WindowService` | Thin coordinator; owns sub-coordinators, delegates to `windowManager` package | `lib/kernel/window_Bridge/window_manager_service.dart:28` | `WindowModeCoordinator`, `WindowResizeCoordinator`, `WindowPersistenceCoordinator`, `windowManager` |
| `WindowModeCoordinator` | Serializes mode transitions; generation guard; `fullscreenIntent` flag; `syncFullscreenState` | `lib/kernel/window_Bridge/window_mode_coordinator.dart:7` | `WindowServiceState`, `_maximize`/`_unmaximize` callbacks |
| `WindowServiceState` | Holds 5 `ValueNotifier`s (mode, windowSize, resizeSessionId, isResizing, isAlwaysOnTop) | `lib/kernel/window_Bridge/window_service_state.dart:13` | All coordinators read/write through it |
| `WindowResizeCoordinator` | Debounces resize→windowSize; **skips persist in fullscreen** (C2-derived) | `lib/kernel/window_Bridge/window_resize_coordinator.dart:11` | `WindowServiceState`, persistence callback |
| `WindowPersistenceCoordinator` | Serial save; **skips save in fullscreen** (C2-derived) | `lib/kernel/window_Bridge/window_persistence_coordinator.dart:9` | `WindowServiceState`, `WindowPersistence` |
| `CustomTitleBar` / `_TitleBarDragArea` | Self-drawn title bar; drag via `onPanStart → startDragging`; double-tap maximize | `lib/ui/window/custom_title_bar.dart:14` / `:122` | `WindowBridge` |
| `PlayerVideoControls._toggleFullscreen` | Splits fullscreen into mode-sync (setMode) + route toggle (video.toggleFullscreen) | `lib/ui/player/player_video_controls.dart:400` | `PlayerActions.onToggleFullscreen`, `VideoControlsPort.toggleFullscreen` |
| `PlayerScreen.onToggleFullscreen` | Wires setMode into PlayerActions | `lib/ui/player/player_screen.dart:154` | `WindowService.setMode` |
| media_kit `enterFullscreen` | Pushes `PageRouteBuilder(Duration.zero)`; calls `onEnterFullscreen` → native | `media_kit_video/.../methods/fullscreen.dart:19` | Navigator, `defaultEnterNativeFullscreen` |
| `Utils::EnterNativeFullscreen` | Saves rect, removes `WS_OVERLAPPEDWINDOW`, `SetWindowPos` to monitor | `media_kit_video/windows/utils.cc:16` | HWND, `WM_NCCALCSIZE` (→ C1 in flutter_window.cpp) |
| `Utils::ExitNativeFullscreen` | Restores `WS_OVERLAPPEDWINDOW`, restores saved rect or maximized | `media_kit_video/windows/utils.cc:53` | HWND |

## Current Fullscreen Transition Sequence (the chain to fix)

This is the exact call sequence today, traced from real source. Every fix must slot into one of these steps without reordering the C1/C2 invariants.

```text
User double-tap / F key / fullscreen button
  │
  v
PlayerVideoControls._toggleFullscreen()                    [player_video_controls.dart:400]
  ├─ 1. widget.actions.onToggleFullscreen?.call()          → PlayerScreen.onToggleFullscreen
  │      └─ windowService.setMode(fullscreen)              [player_screen.dart:157]
  │           └─ _modeCoordinator.setMode(fullscreen)
  │                └─ _setSerialized: target==fullscreen → syncFullscreenState(true)
  │                     └─ _commit(gen, WindowMode.fullscreen)
  │                          └─ _state.mode.value = fullscreen   ★ C2 commit (synchronous)
  │                               │
  │                               ├─ CustomTitleBar rebuilds: AnimatedOpacity → 0 (durationFullscreenAnim)
  │                               ├─ PlayerVideoControls._syncModeFullscreen: _isFullscreenNotifier=true
  │                               └─ WindowResizeCoordinator will skip persist on next resize
  │
  └─ 2. widget.video.toggleFullscreen()                    [media_kit fullscreen.dart:110]
           └─ enterFullscreen(context)
                ├─ Navigator.push(PageRouteBuilder(         transitionDuration: Duration.zero
                │     pageBuilder: Video(...controls: same builder...))
                │  )                                          ★ route pushed, fullscreen Video mounted
                │
                └─ await onEnterFullscreen(context)?.call()  → defaultEnterNativeFullscreen
                     └─ MethodChannel('com.alexmercerind/media_kit_video')
                          .invokeMethod('Utils.EnterNativeFullscreen')
                               │  (async channel round-trip — TIMING GAP HERE)
                               v
                     Utils::EnterNativeFullscreen(HWND)      [media_kit_video windows/utils.cc:16]
                      ├─ rect_before_fullscreen_ = placement.rcNormalPosition
                      ├─ SetWindowLongPtr(GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW)
                      └─ SetWindowPos(HWND_TOP, monitor.rcMonitor,
                                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED)
                                          │
                                          v
                     WM_NCCALCSIZE fires (wparam=TRUE)
                          │
                          v
                     FlutterWindow::MessageHandler           [flutter_window.cpp:63]  ★ C1
                      ├─ style = GetWindowLongPtr(GWL_STYLE)
                      ├─ (style & WS_OVERLAPPEDWINDOW) == 0  → return 0
                      └─ client area = whole window (no 8px inset)
```

**Three flicker sources identified in this sequence** (see Fix C analysis):

1. **Title bar fade vs native resize race** — step 1 sets mode (title bar starts fading over `durationFullscreenAnim`), but step 2's native resize is gated behind an async MethodChannel. For ~1 frame the title bar is mid-fade while the window is still windowed-sized.
2. **`SWP_FRAMECHANGED` frame recalc flash** — `SetWindowPos` with `SWP_FRAMECHANGED` triggers a full frame recalculation. `WM_ERASEBKGND return 1` (`win32_window.cpp:250`) already suppresses background flash, but the old frame border is erased before the new client area paints.
3. **`rect_before_fullscreen_` from `rcNormalPosition`** — if the window was maximized before fullscreen, `WINDOWPLACEMENT.rcNormalPosition` holds the *restored* (unmaximized) size, not the maximized size. On exit, `ExitNativeFullscreen` restores to this smaller rect, causing a size jump before `WindowModeCoordinator` re-maximizes.

---

## Fix-by-Fix Integration Analysis

### Fix A: Accent Border Removal (Win10 red border)

**Root cause:** Windows 10 DWM draws a 1px accent-color (user's theme color) border around every top-level window, *even frameless ones*. The project is already frameless (`WM_NCCALCSIZE` return 0 + `setAsFrameless`), but DWM's compositor border is independent of the non-client area calculation.

**Where the logic should live: runner C++ — specifically `flutter_window.cpp` / `win32_window.cpp`, alongside C1.**

Rationale:
- C1 (NCCALCSIZE) already lives here; border appearance is the same concern (non-client rendering).
- DWM attributes (`DwmSetWindowAttribute`) require the HWND and a C ABI call — most direct in C++.
- `window_manager` does not expose `DWMWA_BORDER_COLOR` or `DWMWA_NCRENDERING_POLICY`.
- Doing it in Dart via FFI would duplicate HWND acquisition and add a MethodChannel round-trip for no benefit.

**Integration points:**

| File | Function / Class | What changes |
|------|-----------------|--------------|
| `windows/runner/flutter_window.cpp` | `FlutterWindow::OnCreate` (`:12`) | NEW: call `DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, &DWMNCRP_DISABLED, ...)` to disable DWM non-client rendering — removes accent border on Win10. Apply once at creation. |
| `windows/runner/flutter_window.cpp` | `FlutterWindow::MessageHandler` (`:46`) | MODIFY: add `WM_NCACTIVATE` handler returning 0 (suppress active/inactive border redraw). Must NOT interfere with the existing `WM_NCCALCSIZE`抢跑 branch (`:63`). |
| `windows/runner/win32_window.cpp` | `Win32Window::MessageHandler` (`:198`) | MODIFY: add `WM_NCACTIVATE` return 0 in the base handler too (纵深防御, same pattern as NCCALCSIZE fallback at `:243`). |
| `windows/runner/win32_window.cpp` | (new helper) | NEW: `ApplyChromeAttributes(HWND)` — encapsulates DWM attribute calls (border color, dark mode, corner preference) so `OnCreate` stays small. |

**API specifics (verified against Microsoft Learn `dwmapi.h`):**
- `DWMWA_BORDER_COLOR = 34` (COLORREF, Win11 Build 22000+) — set to `DWMWA_COLOR_NONE = 0xFFFFFFFE` to suppress border. **Win11 only.**
- `DWMWA_NCRENDERING_POLICY` (DWMNCRP_DISABLED = 2) — works on Win10, disables DWM non-client rendering entirely. **This is the Win10 path.** Side effect: removes DWM drop shadow. Acceptable for this app (frameless, custom chrome).
- `DWMWA_USE_IMMERSIVE_DARK_MODE = 20` (Win11 22000+; value 19 backported to Win10 1809) — set TRUE so any residual frame matches the dark Midnight theme.

**Win10 vs Win11 strategy:** `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` is the universal fix that works on both Win10 and Win11 (removes both accent border and shadow). If Win11 shadow is later desired, switch to `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` on Win11 (keeps shadow, removes only border) via build-number detection (see Fix B). Recommendation: start with `DWMNCRP_DISABLED` (simplest, cross-version), revisit per-OS tuning only if shadow loss is noticed.

**C1/C2 impact:** None. `DWMWA_NCRENDERING_POLICY` controls DWM compositor border/shadow, independent of `WM_NCCALCSIZE` client-area calculation (C1) and `WindowMode` (C2).

### Fix B: Rounded Corners (cross-platform consistency)

**Where the layers own corner strategy:**

| OS | Layer | Mechanism |
|----|-------|-----------|
| Win11 22000+ | runner C++ | `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND=2)` — native DWM rounding |
| Win10 | runner C++ (detection) + Flutter UI (fallback) | No native support. Either accept square (recommended) or pseudo-round via transparent window + `ClipRRect` |
| Linux | Flutter UI (platform detection) | GTK/Wayland compositor-dependent; `ClipRRect` fallback if needed |

**Integration points:**

| File | Function / Class | What changes |
|------|-----------------|--------------|
| `windows/runner/flutter_window.cpp` | `FlutterWindow::OnCreate` (`:12`) | NEW: call `ApplyCornerPreference(hwnd)` — on Win11 build ≥22000, `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND`; on Win10, no-op (square). |
| `windows/runner/flutter_window.cpp` | (new helper, same as Fix A) | NEW: `GetWindowsBuildNumber()` via `RtlGetVersion` (same approach as `media_kit_video/windows/utils.cc:85` `Utils::GetWindowsVersion`). Reuse, don't reinvent. |
| `lib/ui/theme/tokens.dart` | `Tokens` | NEW: `windowCornerRadius` constant (e.g., 8.0) for pseudo-round fallback, if pursued. |
| `lib/ui/player/player_screen.dart` | root widget wrapper | MODIFY (only if Win10 pseudo-round is pursued): wrap root in `ClipRRect(borderRadius: BorderRadius.all(Radius.circular(Tokens.windowCornerRadius)))`. Requires transparent window background (already set: `WindowOptions(backgroundColor: Colors.transparent)` at `window_manager_service.dart:109`). |

**API specifics (verified):**
- `DWMWA_WINDOW_CORNER_PREFERENCE = 33` (Win11 Build 22000+) — `pvAttribute` points to `int` (DWM_WINDOW_CORNER_PREFERENCE enum): `DWMWCP_DEFAULT=0`, `DWMWCP_DONOTROUND=1`, `DWMWCP_ROUND=2`, `DWMWCP_ROUNDSMALL=3`.
- Build detection: `RtlGetVersion` (ntdll.dll) is more reliable than `GetVersionEx` (which is manifest-gated since Win8.1). `media_kit_video/windows/utils.cc:85-99` already implements this exact pattern — copy the approach, do not link against media_kit internals.

**Recommendation (opinionated):** Native DWM rounding on Win11 (`DWMWCP_ROUND`), square corners on Win10. Pseudo-rounding on Win10 (transparent window + `ClipRRect`) has known costs: edge anti-aliasing artifacts, lost native resize hit-test at corners, performance overhead of per-frame clip. The PROJECT.md defers this to research conclusion — this research concludes **don't pseudo-round on Win10**; the visual inconsistency is preferable to the technical debt. Unix principle #4 (portability over efficiency) means: let the OS do what it can (Win11 native), and accept what it can't (Win10 square).

**C1/C2 impact:** None. Corner preference is a DWM compositor attribute, orthogonal to `WM_NCCALCSIZE` (C1) and `WindowMode` (C2). `DWMWCP_ROUND` + `WM_NCCALCSIZE return 0` coexist cleanly (round corners on the DWM frame, zero inset on client area).

### Fix C: Flicker-Free Fullscreen Transition

This is the most architecturally constrained fix because it touches all three layers and both invariants. The PROJECT.md authorizes media_kit red-line lifting **only for fullscreen**.

**Three sub-symptoms, three integration points:**

#### C-1: Title bar fade vs native resize race

**Root cause:** Step 1 of the transition sequence sets `_state.mode = fullscreen` synchronously, which starts `CustomTitleBar`'s `AnimatedOpacity` fade (`durationFullscreenAnim`). But the native window resize (step 2, `EnterNativeFullscreen`) is async-gated behind a MethodChannel. For 1-2 frames the title bar is mid-fade in a still-windowed-sized window.

**Integration point — two options:**

| Option | File | Function | Change | Tradeoff |
|--------|------|----------|--------|----------|
| C-1a (recommended) | `lib/ui/window/custom_title_bar.dart:92` | `_TitleBarAnimatedShell.build` | Change `AnimatedOpacity` to `Opacity` (instant, no fade) when entering fullscreen; keep fade on exit only. Or: reduce `durationFullscreenAnim` to near-zero for enter. | Hard cut on enter; acceptable — the fullscreen route covers the title bar instantly anyway. |
| C-1b | `lib/ui/player/player_video_controls.dart:400` | `_toggleFullscreen` | Reorder: call `widget.video.toggleFullscreen()` (which triggers route push + native resize) and defer `onToggleFullscreen` (mode sync) until after the route is mounted. | Violates C2 — mode would lag the route. Not recommended. |

**Recommendation: C-1a.** The title bar should disappear *instantly* on enter (the fullscreen route covers it) and fade *on exit* (where the windowed content needs to re-show gracefully). This keeps C2 intact (mode still commits synchronously in step 1) and eliminates the fade-vs-resize race.

#### C-2: `SWP_FRAMECHANGED` frame recalc flash

**Root cause:** `Utils::EnterNativeFullscreen` calls `SetWindowPos(..., SWP_FRAMECHANGED)` after `SetWindowLongPtr(~WS_OVERLAPPEDWINDOW)`. `SWP_FRAMECHANGED` forces a full `WM_NCCALCSIZE` recalculation and frame redraw. The `WM_ERASEBKGND return 1` (`win32_window.cpp:250`) suppresses background flash but not the frame-border erase.

**Integration point — runner C++ (where else: this is a WM_ message concern):**

| File | Function | Change |
|------|----------|--------|
| `windows/runner/flutter_window.cpp:63` | `WM_NCCALCSIZE`抢跑 branch | MODIFY: also handle `WM_NCPAINT` during fullscreen transition — return 0 to suppress non-client paint while `WS_OVERLAPPEDWINDOW` is absent. Add a `WM_PAINT` guard if needed. |
| `windows/runner/win32_window.cpp:250` | `WM_ERASEBKGND` | Already returns 1. No change. |

**media_kit red-line consideration:** The `SWP_FRAMECHANGED` flag is in `media_kit_video/windows/utils.cc:49` — changing it requires lifting the red line for fullscreen (authorized). Alternative: add `SWP_NOCOPYBITS` (0x0080) to the `SetWindowPos` call to prevent client-area bit blit during reposition. This is a one-flag change in `utils.cc:45-49`. **Recommended: add `SWP_NOCOPYBITS` to both `EnterNativeFullscreen` and `ExitNativeFullscreen` `SetWindowPos` calls.**

#### C-3: `rect_before_fullscreen_` size jump on exit

**Root cause:** `Utils::EnterNativeFullscreen` saves `rect_before_fullscreen_` from `WINDOWPLACEMENT.rcNormalPosition` (`utils.cc:36-41`). If the window was maximized, `rcNormalPosition` is the *restored* size, not the maximized size. On exit, `ExitNativeFullscreen` restores to this smaller rect, then `WindowModeCoordinator` re-maximizes — causing a visible size jump.

**Integration point — two layers:**

| File | Function | Change |
|------|----------|--------|
| `media_kit_video/windows/utils.cc:36` | `EnterNativeFullscreen` (red-line lifted) | MODIFY: save `GetWindowRect(hwnd, &rect_before_fullscreen_)` instead of `placement.rcNormalPosition`, so the actual on-screen rect (including maximized) is restored. |
| `lib/kernel/window_Bridge/window_mode_coordinator.dart:70` | `syncFullscreenState` | MODIFY: on fullscreen exit, if `previous mode == maximized`, defer the mode commit until after native restore + re-maximize. Currently `_setSerialized(windowed)` runs `_unmaximize()` if previous was maximized — but the native exit already restored the rect. Need to coordinate: let native exit restore, then if was-maximized, call `_maximize()` instead of `_unmaximize()`. |

**C2 constraint:** The mode commit must still go through `_commit(gen, mode)`. The fix is in *which* mode is committed (maximized vs windowed) based on pre-fullscreen state, not in bypassing the commit. Add a `_preFullscreenMode` field to `WindowModeCoordinator` to remember the mode before fullscreen entry.

**Recommended approach for C-3:** Store `_preFullscreenMode` in `WindowModeCoordinator` when `syncFullscreenState(true)` is called (capture `_state.mode.value` before overwriting). On exit (`_setSerialized` with target != fullscreen), restore to `_preFullscreenMode` instead of always `windowed`. This is a Dart-side fix that doesn't require touching media_kit's `rect_before_fullscreen_` — lower risk. If the size jump persists, *then* also fix `utils.cc:36` to use `GetWindowRect`.

### Fix D: Title Bar Drag Reliability

**Current chain:** `_TitleBarDragArea` (`custom_title_bar.dart:122`) → `GestureDetector(behavior: opaque, onPanStart: (_) => windowService.startDragging())` → `windowManager.startDragging()` → MethodChannel → native `WM_NCLBUTTONDOWN(HTCAPTION)` → `DefWindowProc` SC_MOVE drag loop.

**Root cause of "occasional not following":** `onPanStart` fires only after the GestureDetector's pan-recognizer threshold (small movement). `startDragging()` is async (MethodChannel round-trip). Between the recognizer firing and the native SC_MOVE loop engaging, there is a ~1-frame gap where pointer-move events are consumed by Flutter's gesture arena but not yet forwarded to the native drag loop. If the user moves fast, the drag loop starts at a stale position.

**Two integration approaches:**

#### D-option-1 (recommended): Native HTCAPTION in WM_NCHITTEST

Move drag initiation to the C++ layer by returning `HTCAPTION` from `WM_NCHITTEST` for the title bar region. Windows then handles drag natively — no GestureDetector, no MethodChannel, no timing gap.

| File | Function | Change |
|------|----------|--------|
| `windows/runner/win32_window.cpp:256` | `WM_NCHITTEST` handler | MODIFY: after `HitTestWindowEdge` returns `HTCLIENT`, check if the point is in the title bar band (top `kTitleBarHeight` px, excluding right-side button region). If so, return `HTCAPTION`. |
| `windows/runner/win32_window.cpp` | constants | NEW: `constexpr int kTitleBarHeight = 32;` (matches `Tokens.titleBarHeight`). NEW: `constexpr int kTitleBarButtonWidth = 46*4;` (right-side button cluster, ~4 buttons). |
| `lib/ui/window/custom_title_bar.dart:122` | `_TitleBarDragArea` | MODIFY: remove `GestureDetector.onPanStart` (native drag now handles it). Keep `onDoubleTap` for maximize toggle (still a Flutter concern). Or keep `onPanStart` as a fallback for non-Windows platforms. |

**Shared state between C++ and Dart:** Only two compile-time constants (`kTitleBarHeight`, button cluster width). These are design tokens that don't change at runtime — duplicating them as C++ constants is acceptable (Unix #6: software leverage — but here the leverage is the native drag loop, which is worth the constant duplication).

**Platform concern:** `HTCAPTION` is Windows-only. On macOS/Linux, keep the `GestureDetector` + `startDragging` path. Gate via `Platform.isWindows` in `_TitleBarDragArea`, or (cleaner) make the C++ `HTCAPTION` return the default for the window class and the Dart side stays platform-agnostic — on Windows the native hit-test wins, on other platforms the GestureDetector wins.

**Hit-test conflict with buttons:** The right-side button cluster (minimize/maximize/close/pin) must return `HTCLIENT` so `InkWell.onTap` receives clicks. `WM_NCHITTEST` must exclude that region from `HTCAPTION`. This is a simple rect check: `pt.x > window_rect.right - kTitleBarButtonAreaWidth`.

**C1/C2 impact:** `HTCAPTION` is returned *only* for non-edge, non-button client area in the title bar band. `HitTestWindowEdge` (C1's 8px resize) runs first and returns `HT*` edge codes before the `HTCAPTION` check. `IsZoomed` guard at `win32_window.cpp:260` (skip resize when maximized) should also skip `HTCAPTION` when maximized (maximized windows shouldn't drag-move). No C2 impact — drag doesn't change `WindowMode`.

#### D-option-2 (lower risk, lower payoff): Keep GestureDetector, fix timing

| File | Function | Change |
|------|----------|--------|
| `lib/ui/window/custom_title_bar.dart:129` | `_TitleBarDragArea.build` | MODIFY: change `HitTestBehavior.opaque` to `HitTestBehavior.translucent` and use `onPanDown` instead of `onPanStart` (fires immediately on pointer-down, no threshold). |

This reduces but doesn't eliminate the async gap. **Not recommended as the final solution**, but acceptable as a Phase-1 quick win before the native `HTCAPTION` refactor.

---

## New vs Modified Components

### New Components

| Component | File | Purpose |
|-----------|------|---------|
| `ApplyChromeAttributes(HWND)` | `windows/runner/flutter_window.cpp` (or new `chrome_attributes.cpp`) | Encapsulates DWM attribute calls: border color/policy, dark mode, corner preference. Called from `OnCreate`. |
| `GetWindowsBuildNumber()` | `windows/runner/utils.cpp` / `utils.h` | `RtlGetVersion`-based build detection (copy `media_kit_video/windows/utils.cc:85` pattern). |
| `kTitleBarHeight`, `kTitleBarButtonAreaWidth` constants | `windows/runner/win32_window.cpp` | Title bar band dimensions for `HTCAPTION` hit-test (Fix D). |
| `_preFullscreenMode` field | `window_mode_coordinator.dart` | Remembers mode before fullscreen entry for correct exit restore (Fix C-3). |
| `Tokens.windowCornerRadius` | `lib/ui/theme/tokens.dart` | Corner radius constant (only if Win10 pseudo-round pursued — not recommended). |

### Modified Components

| Component | File | Change |
|-----------|------|--------|
| `FlutterWindow::OnCreate` | `flutter_window.cpp:12` | Call `ApplyChromeAttributes(hwnd)` after base `OnCreate`. |
| `FlutterWindow::MessageHandler` | `flutter_window.cpp:46` | Add `WM_NCACTIVATE` return 0; add `WM_NCPAINT` suppression during fullscreen (Fix C-2). |
| `Win32Window::MessageHandler` | `win32_window.cpp:198` | Add `WM_NCACTIVATE` return 0 (纵深防御); extend `WM_NCHITTEST` with `HTCAPTION` title bar band (Fix D). |
| `_TitleBarAnimatedShell` | `custom_title_bar.dart:74` | Instant opacity on fullscreen enter, fade on exit (Fix C-1a). |
| `_TitleBarDragArea` | `custom_title_bar.dart:122` | Remove/conditional `onPanStart` when native `HTCAPTION` active (Fix D-option-1). |
| `WindowModeCoordinator.syncFullscreenState` / `_setSerialized` | `window_mode_coordinator.dart:51,70` | Capture `_preFullscreenMode` on enter; restore to it on exit instead of always `windowed` (Fix C-3). |
| `Utils::EnterNativeFullscreen` | `media_kit_video/windows/utils.cc:16` (red-line lifted) | Add `SWP_NOCOPYBITS` to `SetWindowPos`; optionally save `GetWindowRect` instead of `rcNormalPosition` (Fix C-2, C-3). |
| `Utils::ExitNativeFullscreen` | `media_kit_video/windows/utils.cc:53` (red-line lifted) | Add `SWP_NOCOPYBITS` to `SetWindowPos` calls (Fix C-2). |

---

## Suggested Build Order (respects dependencies)

The four fixes have dependencies that dictate ordering. The build order below minimizes rework and ensures each phase can be verified independently.

### Phase 1: Accent border removal (Fix A) — no dependencies

**Why first:** Self-contained C++ change with zero Dart impact. Verifiable immediately by eye (red border gone). Establishes the `ApplyChromeAttributes` helper that Fix B reuses.

**Build:**
1. Add `ApplyChromeAttributes(HWND)` in `flutter_window.cpp` — calls `DwmSetWindowAttribute(DWMWA_NCRENDERING_POLICY, DWMNCRP_DISABLED)`.
2. Add `WM_NCACTIVATE` return 0 in both `FlutterWindow::MessageHandler` and `Win32Window::MessageHandler`.
3. Call `ApplyChromeAttributes` from `FlutterWindow::OnCreate`.
4. Verify: red border gone on Win10; no regression on Win11.

**Verifies C1/C2:** `WM_NCACTIVATE` handler must not interfere with existing `WM_NCCALCSIZE`抢跑 branch. Test: enter/exit fullscreen, confirm no seam regressed.

### Phase 2: Rounded corners (Fix B) — depends on Phase 1 (reuses `ApplyChromeAttributes` + build detection)

**Why second:** Reuses the `ApplyChromeAttributes` helper and `GetWindowsBuildNumber` from Phase 1. Pure additive (Win11 `DWMWCP_ROUND`; Win10 no-op). No Dart changes if pseudo-round is deferred (recommended).

**Build:**
1. Add `GetWindowsBuildNumber()` in `utils.cpp` (copy `RtlGetVersion` pattern).
2. Extend `ApplyChromeAttributes`: if build ≥ 22000, `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)`.
3. Verify: rounded corners on Win11; square on Win10 (acceptable per research conclusion).

### Phase 3: Title bar drag reliability (Fix D) — no dependency on A/B, but do before C

**Why before C:** Fix C (fullscreen flicker) involves the fullscreen transition. Fix D (drag) involves the windowed title bar. Doing D first means the `WM_NCHITTEST` handler is stable before C adds fullscreen-transition message handling. Also: D's `HTCAPTION` change touches the same `WM_NCHITTEST` code as C1's `HitTestWindowEdge` — get this right while C1 is the only other concern.

**Build:**
1. Add `kTitleBarHeight` / `kTitleBarButtonAreaWidth` constants in `win32_window.cpp`.
2. Extend `WM_NCHITTEST`: after `HitTestWindowEdge` returns `HTCLIENT`, check title bar band → return `HTCAPTION` (excluding button region and maximized state).
3. Conditionally disable `onPanStart` in `_TitleBarDragArea` on Windows (keep `onDoubleTap`).
4. Verify: drag is instant and reliable; buttons still clickable; resize edges still work.

**Critical C1 preservation:** `HitTestWindowEdge` (8px edges) MUST run before the `HTCAPTION` check. Order in `WM_NCHITTEST`: (1) `IsZoomed` guard → break; (2) `HitTestWindowEdge` → if non-HTCLIENT, return; (3) title bar band → `HTCAPTION`; (4) `break` (DefWindowProc).

### Phase 4: Flicker-free fullscreen (Fix C) — depends on all above; highest risk

**Why last:** Touches all three layers (runner C++, window_bridge Dart, media_kit C++). Requires the media_kit red-line lift. Each sub-fix (C-1, C-2, C-3) can be done independently and verified.

**Build sub-phase 4a (C-1a: title bar instant hide on enter):**
1. Modify `_TitleBarAnimatedShell` (`custom_title_bar.dart:92`): use `Opacity` (instant) when `isFullscreen && entering`; keep `AnimatedOpacity` for exit.
2. Need an "entering" signal — derive from mode transition: track previous mode in `_TitleBarAnimatedShell` or pass a `isEntering` flag from `CustomTitleBar`'s `AnimatedBuilder`.
3. Verify: no title bar flash on enter; graceful fade on exit.

**Build sub-phase 4b (C-2: SWP_NOCOPYBITS + NCPAINT suppression):**
1. Lift media_kit red-line for `utils.cc` (fullscreen only).
2. Add `SWP_NOCOPYBITS` to `SetWindowPos` in `EnterNativeFullscreen` and `ExitNativeFullscreen`.
3. Add `WM_NCPAINT` return 0 in `FlutterWindow::MessageHandler` when `WS_OVERLAPPEDWINDOW` is absent (fullscreen state).
4. Verify: no frame flash on enter/exit.

**Build sub-phase 4c (C-3: correct exit mode restore):**
1. Add `_preFullscreenMode` to `WindowModeCoordinator`; capture in `syncFullscreenState(true)`.
2. In `_setSerialized`, when exiting fullscreen, restore to `_preFullscreenMode` (maximized or windowed) instead of always `windowed`.
3. If was-maximized: call `_maximize()` instead of `_unmaximize()` after native exit.
4. Verify: enter fullscreen from maximized → exit → window returns to maximized (not windowed then jump).

**C2 preservation in 4c:** The mode commit still goes through `_commit(gen, mode)`. The only change is *which* `WindowMode` value is committed (maximized vs windowed). The `generation` guard still prevents stale callbacks.

---

## Patterns to Follow

### Pattern 1: DWM attribute application lives in runner C++, not Dart FFI
**What:** All `DwmSetWindowAttribute` calls are in `ApplyChromeAttributes(HWND)`, called from `FlutterWindow::OnCreate`.
**When:** Any time a DWM non-client rendering attribute needs setting.
**Why:** The HWND is native; C++ is the most direct path. `window_manager` doesn't expose these attributes. FFI from Dart would add a MethodChannel round-trip and duplicate the HWND lookup. Consistent with C1 (NCCALCSIZE also in C++).

### Pattern 2: WM_ message handlers use纵深防御 (defense-in-depth)
**What:** Both `FlutterWindow::MessageHandler` and `Win32Window::MessageHandler` handle the same message (e.g., `WM_NCCALCSIZE` return 0, `WM_NCACTIVATE` return 0). The derived class handles the specific case (media_kit fullscreen); the base class is the fallback.
**When:** Any new `WM_` message suppression.
**Why:** `window_manager`'s plugin delegate (`HandleTopLevelWindowProc`) runs before `FlutterWindow::MessageHandler` and may consume messages. Having both layers ensures the behavior holds even if the plugin changes.

### Pattern 3: WindowMode is the only fullscreen signal (C2)
**What:** Every component reads `isFullscreen` from `_state.mode.value`, never from `VideoState.isFullscreen` or a separate flag.
**When:** Any code that branches on fullscreen state.
**Why:** media_kit swaps `VideoState` context during fullscreen route, making `VideoState.isFullscreen` unreliable (the icon-stuck bug, already fixed). `WindowMode` is committed synchronously by `WindowModeCoordinator._commit` on every transition path.

### Pattern 4: Native hit-test for native drag (HTCAPTION), Flutter for Flutter clicks
**What:** `WM_NCHITTEST` returns `HTCAPTION` for the draggable title bar band; `HTCLIENT` for buttons. No `GestureDetector.onPanStart` on Windows.
**When:** Custom title bar drag.
**Why:** The native SC_MOVE drag loop is zero-latency. `GestureDetector` + `startDragging` has an inherent async gap (MethodChannel). Each layer does what it's best at.

## Anti-Patterns to Avoid

### Anti-Pattern 1: DWM attributes via Dart FFI
**What:** Calling `DwmSetWindowAttribute` from Dart via `dart:ffi` lookup.
**Why bad:** Duplicates HWND acquisition (window_manager already holds it); adds FFI binding maintenance; bypasses the runner C++ layer where C1 lives, splitting non-client rendering logic across two languages.
**Instead:** `ApplyChromeAttributes(HWND)` in runner C++.

### Anti-Pattern 2: Reading fullscreen state from VideoState
**What:** `if (widget.video.isFullscreen)` or `isFullscreen(context)` in UI code.
**Why bad:** media_kit swaps VideoState context during fullscreen route; the windowed-state instance reads `true` during fullscreen but never syncs back to `false` on exit (the icon-stuck root cause, documented at `player_video_controls.dart:644-650`).
**Instead:** Always read `widget.windowMode.value.isFullscreen` (C2).

### Anti-Pattern 3: Reordering the fullscreen transition sequence
**What:** Calling `video.toggleFullscreen()` (route + native resize) before `setMode(fullscreen)` (C2 commit).
**Why bad:** The title bar, auto-hide, cursor, resize coordinator, and persistence coordinator all react to `WindowMode`. If mode lags the route, they're in the wrong state for 1-2 frames.
**Instead:** Keep `setMode` first (synchronous C2 commit), then `toggleFullscreen` (route + native). Fix flicker at the C++/UI level (C-1a, C-2), not by reordering.

### Anti-Pattern 4: HTCAPTION without excluding resize edges
**What:** Returning `HTCAPTION` for the entire title bar band, including the top 8px.
**Why bad:** Breaks C1's 8px top resize edge (`HitTestWindowEdge` returns `HTTOP` for the top 8px; if `HTCAPTION` runs first, resize is lost).
**Instead:** `HitTestWindowEdge` (C1) runs first; `HTCAPTION` only for points that `HitTestWindowEdge` returned `HTCLIENT`.

## Scalability / Per-OS Considerations

| Concern | Windows 10 | Windows 11 | Linux | macOS |
|---------|-----------|-----------|-------|-------|
| Accent border | `DWMNCRP_DISABLED` removes it | `DWMWA_BORDER_COLOR=NONE` or same | N/A (no DWM) | N/A |
| Rounded corners | Square (no native support) | `DWMWCP_ROUND` native | Compositor-dependent (ClipRRect fallback) | Native (NSWindow) |
| Fullscreen | `Utils::EnterNativeFullscreen` (C++ path) | Same | GTK/Wayland path | NSWindow toggle |
| Title bar drag | `HTCAPTION` native (Fix D) | Same | `startDragging` (GestureDetector) | `startDragging` |
| Capability detection | `RtlGetVersion` build number | Same | `Platform.isLinux` | `Platform.isMacOS` |

## Sources

- Microsoft Learn, `DWMWINDOWATTRIBUTE` enumeration (dwmapi.h) — DWMWA_BORDER_COLOR=34, DWMWA_WINDOW_CORNER_PREFERENCE=33, DWMWA_COLOR_NONE=0xFFFFFFFE, all Win11 Build 22000+. Confidence: HIGH (official header docs, fetched 2026-09-01).
- Microsoft Learn, `DwmSetWindowAttribute` function (dwmapi.h) — signature `HRESULT DwmSetWindowAttribute(HWND, DWORD, LPCVOID, DWORD)`, returns S_OK. Confidence: HIGH.
- `media_kit_video-2.0.1/windows/utils.cc` — `EnterNativeFullscreen` / `ExitNativeFullscreen` source (read from pub cache). Confidence: HIGH (verbatim source).
- `media_kit_video-2.0.1/lib/.../methods/fullscreen.dart` — `enterFullscreen`/`exitFullscreen` route push logic (read from pub cache). Confidence: HIGH.
- Project source: `windows/runner/flutter_window.cpp`, `win32_window.cpp`, `window_manager_service.dart`, `window_mode_coordinator.dart`, `custom_title_bar.dart`, `player_video_controls.dart` — all read in full. Confidence: HIGH.
- window_manager README/docs via Context7 — `startDragging`, `WindowOptions`, `titleBarStyle: hidden`. Confidence: MEDIUM (docs don't expose native implementation depth).
