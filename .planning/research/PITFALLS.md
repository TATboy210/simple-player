# Pitfalls Research

**Domain:** Frameless Flutter desktop window chrome + media_kit fullscreen transitions (Win10/Win11/Linux)
**Researched:** 2026-09-01
**Confidence:** HIGH (Win/NCCALCSIZE/DWM/window_manager), MEDIUM (Linux/gpu-texture — no real hardware)

This catalog targets mistakes that arise **when ADDING** accent-border removal, rounded corners, flicker-free fullscreen, and reliable drag to an **already-frameless** Flutter + media_kit player. It assumes the shipped foundations (white-border fix via `WM_NCCALCSIZE` return 0 + `setAsFrameless`; fullscreen gap fix via NCCALCSIZE 8px inset C1 + `WindowMode` single source C2; `SmartDragToResizeArea` for system resize) and treats regressing them as the #1 risk.

---

## Critical Pitfalls

### Pitfall 1: Re-touching `WM_NCCALCSIZE` and re-opening the solved fullscreen gap (C1 regression)

**What goes wrong:**
The v1.0 fullscreen gap fix (C1) works by returning a computed 8px-inset rect from `WM_NCCALCSIZE` instead of a bare `return 0`. Any new chrome work that edits the runner's `WM_NCCALCSIZE` handler — e.g. to strip the Win10 accent border, to add a transparent margin for fake rounded corners, or to "clean up" the frameless path — silently reverts C1. Symptom: fullscreen shows an 8px transparent/white gap at the edges again, the exact bug the team already fixed and promised not to reopen.

**Why it happens:**
`WM_NCCALCSIZE` is the single choke point for *all* frameless geometry: the white-border fix, the C1 gap fix, and any future rounded-corner/accent-border work all want to edit the same handler. A developer adding "just one more" adjustment overwrites the C1 inset branch with a plain `return 0` (Microsoft's documented "remove frame" recipe) and the gap returns. The Win32 docs actively encourage `return 0` for frameless chrome, so the regression looks like the "correct" textbook answer.

**How to avoid:**
- Treat the runner's `WM_NCCALCSIZE` handler as a **multi-branch state machine**, not a recipe. Branches: `isFullscreen` → C1 8px inset; `isMaximized` → overshoot handling (Pitfall 2); default frameless → `return 0`. Never collapse branches.
- Pin C1 with a regression test: a widget/integration assertion that, in fullscreen, the client rect equals the monitor rect minus the documented inset (or that no gap is visible). The project already has a `fullscreen-seam-icon-fix` memory recording C1 — link the test to that memory so deletion triggers a review.
- Add a `// DO NOT REMOVE — C1 fullscreen gap fix (see memory project_fullscreen_seam_icon_fix.md)` guard comment on the inset branch. Comments are load-bearing here.
- Any accent-border / rounded-corner work must edit a **different** Win32 surface (DWM attributes, `GWL_STYLE`, or a Flutter clip layer), NOT the `WM_NCCALCSIZE` inset branch.

**Warning signs:**
- Fullscreen shows a thin transparent/white seam at any edge on real hardware (headless tests will NOT catch this — geometry looks identical in a headless run; the gap is a DWM-composition visual).
- `git diff` on `windows/runner/win32_window.cpp` shows the `WM_NCCALCSIZE` inset math replaced by `return 0`.
- A "fullscreen looks cleaner now" comment in a PR touching the runner.

**Phase to address:**
Phase 1 (capability detection + C1 pinning). Before *any* chrome work, add the C1 regression test and the branch-guard comment. Every later phase that touches the runner must keep that test green.

---

### Pitfall 2: `WM_NCCALCSIZE` maximized overshoot + autohide taskbar — window covers the taskbar

**What goes wrong:**
On Windows, a maximized window deliberately overshoots the work area by ~`SM_CXSIZEFRAME + SM_CXPADDEDBORDER` (~8px) per side. This hides the resize border *and* keeps the autohide taskbar's trigger zone usable. A frameless `WM_NCCALCSIZE` handler that returns the work-area rect (or `return 0`) strips the overshoot, so a maximized window on a monitor with an autohide taskbar covers the taskbar's peek zone — the user can no longer summon the taskbar over the player. Worse: on Win10 vs Win11 the overshoot math differs slightly, so a fix that works on the dev's Win11 machine regresses on Win10.

**Why it happens:**
Developers copy the "frameless = return 0" recipe from Win32 docs without reading the `Remarks` noting that `return 0` makes the client area equal the *window* rect (which for a maximized window already includes the overshoot) — but only if the proposed rect was the maximized rect. Custom-chrome code that recomputes the rect from `GetMonitorInfo.rcWork` (work area) explicitly discards the overshoot, reintroducing the bug.

**How to avoid:**
- In the `isMaximized` branch, do **not** clamp to `rcWork`. Either call `DefWindowProc` first and let Windows compute the overshoot, or explicitly add `GetSystemMetrics(SM_CXSIZEFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER)` on each side when maximized.
- Detect autohide taskbars per-monitor via `ABM_GETSTATE` / `SHAppBarMessage` (a taskbar can be autohide on one monitor and not another). For autohide monitors, keep the overshoot on the taskbar edge.
- Test on **both** Win10 and Win11 with an autohide taskbar on a multi-monitor setup. This is a real-hardware-only check — headless cannot reveal a covered taskbar.

**Warning signs:**
- "The taskbar disappeared when I maximized the player" on a user machine with autohide taskbar.
- Maximized window has a 1-pixel line of the desktop visible on non-taskbar edges (undershoot — the inverse mistake).
- Works on Win11 dev box, fails on a Win10 user report.

**Phase to address:**
Phase 1 (capability detection — detect Win10 vs Win11, monitor layout, autohide state) and verify in the transition-sequence phase (Phase 4) that maximize→fullscreen and maximize+autohide stay correct.

---

### Pitfall 3: `DWMWA_BORDER_COLOR` / `DWMWA_WINDOW_CORNER_PREFERENCE` called on Windows 10 (silent no-op or `E_INVALIDARG`)

**What goes wrong:**
The Win10 accent-border (red theme-color border) removal is the milestone's headline feature. The obvious fix is `DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, DWMWA_COLOR_DEFAULT)`. But `DWMWA_BORDER_COLOR` (34) and `DWMWA_WINDOW_CORNER_PREFERENCE` (33) are **Windows 11 build 22000+ only** — they do not exist on Windows 10. On Win10 the call returns `E_INVALIDARG` (or, worse, if the constants are undefined in the targeted SDK, the build breaks). The developer who "fixed the red border" actually fixed nothing on the Win10 machine where the user reported it.

**Why it happens:**
MSDN lists these attributes in one enum page without a per-attribute "minimum build" column, so they look universally available. The constants are only compiled in when `NTDDI_VERSION >= NTDDI_WIN10_CO`; if the project targets an older SDK they don't even compile, and if it targets a new SDK they compile but fail at runtime on Win10. The Win10 red border is drawn by a *different* mechanism (the DWM/system accent frame) than the Win11 colored border — the Win11 attribute can't remove it because it's not the same border.

**How to avoid:**
- Runtime version-gate every `DwmSetWindowAttribute` call: use `IsWindows11OrGreater()` (via `RtlGetVersion` — not the deprecated `GetVersionEx`) **and** check the returned `HRESULT`, degrading silently on Win10. Never trust compile-time SDK presence.
- For Win10 accent-border removal specifically: `DWMWA_BORDER_COLOR` is the wrong tool. Win10's accent border is tied to the `WS_THICKFRAME` / DWM caption frame; the project's existing `WS_THICKFRAME | WS_MAXIMIZEBOX` (from window_manager PR #531) + `setAsFrameless` path is the lever, not a DWM color attribute. Verify the red border actually disappears on a real Win10 machine before claiming the feature done.
- Keep a single `DwmCapabilities` probe (Phase 1) that records, once at startup: `borderColor`, `cornerPreference`, `captionColor`, `textColor`, `systemBackdrop` booleans. Every later call reads these flags — never re-probe per frame.

**Warning signs:**
- "The red border is gone" on the dev's Win11 machine but user reports on Win10 persist.
- `DwmSetWindowAttribute` returns non-zero `HRESULT` in the debugger (log it; never ignore).
- Build breaks on a CI image with an older Windows SDK.

**Phase to address:**
Phase 1 (capability detection — the `DwmCapabilities` probe is the first thing built). Phase 2 (accent-border) then consumes the probe; the Win10 path is explicit and tested on real Win10 hardware.

---

### Pitfall 4: DWM attributes applied once and never re-applied (flicker after theme/DPI/mode change)

**What goes wrong:**
A DWM attribute (`DWMWA_BORDER_COLOR`, `DWMWA_CAPTION_COLOR`, `DWMWA_WINDOW_CORNER_PREFERENCE`) is set once at startup or on entering fullscreen. Then the user: switches dark/light theme (`WM_THEMECHANGED`), drags the window to a monitor with a different DPI scaling (`WM_DPICHANGED`), or enters/exits fullscreen. The DWM attribute is now stale — the border reappears, the caption color flips back, the corner preference reverts — and the transition itself flickers because DWM re-evaluates the frame mid-transition.

**Why it happens:**
DWM attributes are not sticky across these events. `WM_THEMECHANGED` and `WM_DPICHANGED` cause DWM to recompute the frame; if the app doesn't re-assert its preference, the system default wins. Fullscreen transitions change the window style and DWM re-derives the border. This is the **exact** trap that killed the reverted global-`DWMNCRP` (方案B / `DWMWA_NCRENDERING_POLICY`) approach: applying it globally once produced flicker on transitions and had to be re-applied on every change, which raced with the transition.

**How to avoid:**
- Re-apply DWM attributes from a single `applyChromeAttributes()` function called on: startup, `WM_THEMECHANGED`, `WM_DPICHANGED`, and at the **stable end-state** of every fullscreen enter/exit (not during the transition — see Pitfall 6).
- Never apply DWM attributes mid-transition. The transition-sequence phase must define a clear "settle" point (e.g. after `WM_SIZE` with the final geometry) where attributes are re-asserted. Applying during the size jump is what causes the flicker the reverted approaches hit.
- **Reverted-approach flag:** `DWMWA_NCRENDERING_POLICY` / `DWMNCRP_DISABLED` (方案B / global DWMNCRP) was reverted on real hardware (commits aad3ba36/36883b77) because of exactly this re-apply + transition-flicker problem. **Do not re-propose DWMNCRP as-is.** If a DWM-based border fix is reconsidered, it must use `DWMWA_BORDER_COLOR` (Win11 only) re-applied via the settle-point pattern, never `DWMWA_NCRENDERING_POLICY`.

**Warning signs:**
- Border/caption color is correct on startup but wrong after a theme toggle or monitor move.
- Single-frame flicker of the system frame during fullscreen enter/exit (visible only on real hardware — a captured frame in DevTools won't show it; use a high-speed screen capture or human eye).
- The same class of "transition flicker" the team already reverted once.

**Phase to address:**
Phase 1 (probe) → Phase 2 (accent-border, with re-apply hooks for `WM_THEMECHANGED`/`WM_DPICHANGED`) → Phase 4 (transition-sequence: wire the settle-point re-apply into fullscreen enter/exit). The settle-point contract is the milestone's central anti-flicker mechanism.

---

### Pitfall 5: Fake rounded corners via transparent (`WS_EX_LAYERED`) window + Flutter clip — video perf cost and black fringes

**What goes wrong:**
Win10 has no DWM rounded-corner API, so the "obvious" fake-round approach is: make the window transparent (`WS_EX_LAYERED` + per-pixel alpha) and clip the four corners with a Flutter widget. Three failures follow:
1. **Video perf cost:** `WS_EX_LAYERED` disables the DXGI flip model and hardware overlay planes — DWM composites the window via a readback path every frame. For a media_kit/libmpv video texture updating at 30/60fps, this measurably raises GPU/CPU usage and can drop frames on weak hardware.
2. **Video corners not clipped:** the media_kit `Video` texture is rectangular and renders *under* the Flutter clip layer. If the clip layer has rounded corners, the video shows through the corners as black triangles/fringes (the clip is transparent, but the texture behind it is opaque-black outside its own bounds — or the texture extends into the corner and the clip reveals a hard edge).
3. **GPU texture artifacts / per-pixel alpha seams:** on some GPUs, per-pixel-alpha windows show a 1px fringe at clip boundaries (premultiplied-alpha mismatch), and on Intel GPUs the corner anti-aliasing shimmers during playback due to the readback composite.

**Why it happens:**
The approach conflates "window transparency" (a DWM/window-style concern) with "corner clipping" (a Flutter widget concern). The video texture is a separate GPU surface that doesn't participate in Flutter's clip hierarchy the way regular widgets do. And `WS_EX_LAYERED`'s readback path is the documented cost of per-pixel alpha — but it's invisible until you play video through it.

**How to avoid:**
- **Prefer native corners where they exist:** Win11 → `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` (no layered window, no perf cost). Linux → GTK CSD / compositor SSD (Pitfall 9). Only fall back to fake-round on Win10.
- **Win10 fake-round that avoids `WS_EX_LAYERED`:** keep the window opaque and let the *corner mask* be a tiny Flutter widget (4 small black/transparent corner widgets on top of the video) rather than full-window transparency. This keeps flip model + overlays intact.
- **If full transparency is unavoidable:** document the measured perf cost on the target hardware before shipping. The project's `PerfMonitor`/`ResizeFrameMetrics` exist for exactly this — profile RSS/GPU before and after with a real video playing. **Do not ship transparent-window rounding on video without a perf gate** (raster max < 33ms with video playing).
- **Video corner clip:** if the video must reach the corners, clip the *texture widget itself* (`ClipRRect` on the `Video` widget) so the rounding applies to the texture, not a sibling layer. Test for black fringes on Intel/Nvidia/AMD.

**Warning signs:**
- CPU/GPU usage rises ~1.5–2x when switching from opaque to transparent window during playback.
- Black triangles visible at the four corners when a bright video plays.
- Corner AA shimmers during fast-motion video scenes (readback composite artifacts).
- `ResizeFrameMetrics` raster max spikes above 33ms with transparency on.

**Phase to address:**
Phase 1 (probe: `DWMWA_WINDOW_CORNER_PREFERENCE` available? → native; else Win10 fake-round path). Phase 3 (rounded corners) must ship the native Win11 path first, treat Win10 fake-round as a gated fallback, and run the perf gate before merging. No Linux real-hardware verification (mark `待实机验证`).

---

### Pitfall 6: Fullscreen enter/exit flicker — texture rebuild, resize ordering, animation-vs-transition fight, wrong restore geometry

**What goes wrong:**
The milestone targets three flicker symptoms: (1) title bar/border flash on enter, (2) size jump on enter, (3) exit flicker. Four independent root causes produce them:
1. **Texture/surface rebuild:** media_kit's `Video` texture is rebuilt when the window geometry changes sharply. During fullscreen enter, the Dart-side resize and the native `WM_SIZE` arrive in a racy order; if the texture is recreated mid-transition, a blank/black frame flashes. The project's own profile sessions found `textureIdChanges=0` across 13 sessions *after* the resize-three-sources fix — but a fullscreen toggle is a *different* resize path and can re-trigger it.
2. **Resize ordering:** Dart `WindowBridge.setFullscreen` calls `windowManager.setFullScreen`/size setters; native `WM_SIZE` fires back; the `ValueNotifier` chain updates; media_kit re-lays the `Video` widget. If Dart sets size before the native style change lands, the window briefly renders at the old style + new size = the size jump.
3. **Animation fighting transition:** an `AnimatedOpacity`/`AnimatedSlide` on the title bar or an OSD during enter/exit overlaps the mode transition; the animation's intermediate frames show a half-sized title bar or a border at the wrong position = the flash.
4. **Wrong restore geometry on exit:** exiting fullscreen restores the pre-fullscreen bounds. If bounds were saved *after* the enter-transition started (capturing a half-transitioned size), the window exits to the wrong size/position — the classic window_manager issue #181 ("right bound overlapped after leaving fullscreen") and #266 ("Fullscreen/Set as frameless bugs MediaQuery screen sizes").

**Why it happens:**
Fullscreen enter/exit is a multi-frame, multi-layer (native style → native size → Dart notifier → media_kit texture → Flutter widget) transition. Each layer has its own timing. A developer who "just calls `setFullScreen(true)`" leaves the ordering to luck; the visible artifacts are the layers disagreeing for a few frames.

**How to avoid:**
- **Snapshot restore geometry before the transition starts.** In `WindowBridge`, capture `{x, y, w, h, maximized}` into a `FullscreenSnapshot` at the *first* call to enter, before any native call. Restore from this snapshot on exit, never from a live `ValueNotifier` that the transition itself is mutating. This directly prevents #181-class regressions.
- **Sequence the enter in a defined order:** (a) hide custom title bar (instant, no animation), (b) snapshot geometry, (c) native style/size change to monitor rect, (d) wait for `WM_SIZE` with final geometry (the "settle point"), (e) re-apply DWM attributes, (f) reveal any in-player chrome. Exit is the reverse. Never interleave an animation with (c)–(d).
- **Suppress transition animations during mode switch.** Any `Animated*` on chrome that overlaps the transition must be gated off (set `isFullscreenTransition` flag → animations skip / use `Duration.zero`). The v1.0 `WindowMode` single-source (C2) fix already proved this pattern; extend it to the title bar.
- **Confirm texture not rebuilt.** Keep the `textureIdChanges=0` probe running during fullscreen toggle in the perf gate. If it rises above 0 on toggle, the texture is being recreated — investigate the `Video` widget's identity key and the `VideoController` lifecycle before shipping.
- **media_kit is in limited maintenance** (GitHub #1337, opened Nov 2025 — upstream will not fix fullscreen texture issues promptly). The project owns this fix; do not wait on an upstream patch.

**Warning signs:**
- A single black/blank frame during fullscreen enter or exit (texture rebuild).
- Title bar visibly slides/fades during the transition (animation fighting).
- After exit, window is 8px off, on the wrong monitor, or the wrong size (restore snapshot bug).
- `ResizeFrameMetrics` shows a raster spike exactly at toggle.

**Phase to address:**
Phase 4 (flicker-free fullscreen transitions) — the central phase. Depends on Phase 1 (probe) for monitor/DPI info, Phase 2 (DWM settle-point re-apply) for the attribute timing, and the C1 pin (Pitfall 1) so the gap doesn't return. Sequence + snapshot + animation-gate are the three deliverables.

---

### Pitfall 7: `window_manager` PR #531 fullscreen path + open regression #579 (title bar not reappearing on exit)

**What goes wrong:**
The project's frameless fullscreen currently goes through the media_kit chain (red line lifted for fullscreen). But the temptation is to delegate to `window_manager`'s newer frameless-fullscreen path (PR #531, merged May 2025), which switches the window style to `WS_THICKFRAME | WS_MAXIMIZEBOX` (dropping `WS_OVERLAPPEDWINDOW`) and calls `setAsFrameless` + separate position/size setting. **That path has an open, unresolved regression (issue #579, Dec 2025): on exit, the title bar does not reappear.** The reporter's workaround is "don't touch `titleBarStyle` on Windows." For a frameless app with a *custom* title bar (this project), the regression manifests as the custom title bar failing to re-bind to the restored window — the window is draggable/closable only via keyboard.

**Why it happens:**
PR #531 changed the style math to avoid the native title bar flashing on exit, but the exit-restore path doesn't fully re-assert the style that `TitleBarStyle.hidden` expects. The project's existing memory (`wm.setFullScreen has a known frameless defect`) already records that `window_manager.setFullScreen` is broken for frameless windows — PR #531 is the attempted fix, #579 is evidence it didn't fully land. There was no formal code review before merge.

**How to avoid:**
- **Do not switch the project's fullscreen path to `window_manager.setFullScreen` as-is.** The project already reverted 方案A/B for real-hardware reasons; #579 is a third reason to keep fullscreen under the project's own `WindowBridge`/media_kit chain.
- If borrowing the `WS_THICKFRAME | WS_MAXIMIZEBOX` style idea from #531, borrow the *style math only*, and own the exit-restore: explicitly re-apply the frameless style + re-bind the custom title bar on exit, with a regression test that the title bar is interactive after exit.
- **Avoid the companion older path (PR #367)** too: its 6-step approach (remove native title bar → hide custom bar → remove borders/corners → maximize → disable `startResizing` → disable `startDragging`) was itself followed by regression #389 ("frameless is broken after #367"). The history is: every window_manager fullscreen rewrite has been followed by a frameless-regression. Treat the whole `window_manager` fullscreen surface as load-bearing legacy, not a greenfield to migrate onto.
- Pin the current working path (media_kit chain) with a real-hardware UAT: title bar interactive after enter→exit→enter cycle.

**Warning signs:**
- After exiting fullscreen, the custom title bar no longer responds to drag/close (the #579 symptom, in custom-bar form).
- A "migrate to window_manager fullscreen" PR appears (this is the trap — reject or scope tightly).
- `TitleBarStyle` is being toggled on enter/exit (the exact pattern #579 says to avoid).

**Phase to address:**
Phase 4 (transitions). The decision "stay on the project's media_kit chain vs. migrate to window_manager #531" is a Phase-4 design gate — make it explicit and record the rationale in the phase's design doc so a future dev doesn't "modernize" onto a regressing path.

---

### Pitfall 8: Title bar drag — `startDragging` no-op, double-click-vs-drag, drag-during-maximized, Linux "cannot drag again"

**What goes wrong:**
The milestone targets "reliable title bar drag." Four concrete failure modes are reported in window_manager's tracker and match the user's "极小概率拖动无效" observation:
1. **`startDragging` no-op on frameless Windows (#399, closed but the pattern recurs):** calling `windowManager.startDragging()` from a `GestureDetector.onPanStart` is swallowed by Flutter's gesture arena before the native channel responds. The drag silently does nothing.
2. **Double-click vs drag (#511 open, #372 closed):** Windows doesn't fire maximize on `onDoubleTapDown` reliably; `DragToMoveArea` double-click-maximize collides with drag detection, so a slow double-click starts a drag instead, or a drag ends as a maximize.
3. **Drag during maximized state:** a maximized frameless window drag should restore windowed size and move — but if `startDragging` is called while the window is still maximized (style not yet flipped), the drag no-ops or jumps.
4. **Linux "cannot drag again after startDragging" (#203, merged but the class of bug):** after one successful drag, subsequent `startDragging` calls no-op until the window is reconfigured.

**Why it happens:**
`startDragging` is a thin FFI shim over `ReleaseCapture` + `SendMessage(WM_NCLBUTTONDOWN, HTCAPTION)`. It requires: (a) the pointer-down to still be the active capture, (b) the window style to permit move, (c) no competing gesture-arena member to have won. Flutter's gesture arena resolves *after* `onPointerDown` in many configurations, so calling from `onPanStart` is too late — the arena may have already assigned the gesture to a child. On Linux/X11, `move` via `_NET_WM_MOVERESIZE` has a single-shot semantics that some compositors honor once.

**How to avoid:**
- **Call `startDragging` from `Listener.onPointerDown` (lowest level, before the gesture arena), not from `GestureDetector.onPanStart`.** This is the documented window_manager recommendation and the project's `custom_title_bar.dart` should enforce it.
- **Separate double-click-maximize from drag** with an explicit delay/timeout gate: on pointer-up within `kDoubleTapTimeout` *and* with movement < `kTouchSlop`, treat as double-click → maximize; else the `onPointerDown`-initiated drag already won. Don't let both paths fire.
- **Flip maximized→windowed before `startDragging`:** if `WindowMode == maximized`, first restore windowed size (centered under the cursor, per Windows convention — restore width = saved restore width, x = cursor.x - width/2), then call `startDragging` on the next frame. Never drag while still maximized.
- **Linux:** after #203's fix, `startDragging` should re-arm, but verify on the target compositor (X11: `_NET_WM_MOVERESIZE`; Wayland: `xdg_toplevel.move`). For Wayland, drag is a compositor request — there is no "global coordinate" and the move is best-effort. Mark Linux drag as `待实机验证`.
- **Hit-test the title bar region natively** as a backup: on Windows, handling `WM_NCHITTEST` returning `HTCAPTION` for the title bar region gives a drag path that doesn't depend on `startDragging` at all — it's the OS handling the drag directly. This is the most reliable path and sidesteps the gesture arena entirely. (The project already has a SmartDragToResizeArea; extend the same native-hit-test approach to the title-bar move region.)

**Warning signs:**
- "Sometimes I drag the title bar and nothing happens" — the no-op, especially after a recent pointer interaction with a child widget.
- Slow double-click starts a drag (or a drag ends as a maximize).
- Drag from a maximized window leaves a ghost frame or jumps.
- On Linux, the first drag works, the second doesn't.

**Phase to address:**
Phase 5 (title bar drag reliability). Depends on Phase 4 (window-mode state machine is correct so "maximized→windowed before drag" works). The native `WM_NCHITTEST`/`HTCAPTION` path is the recommended primary mechanism; `startDragging` from `onPointerDown` is the fallback.

---

### Pitfall 9: Linux — Wayland no-global-coordinates, server-vs-client decorations, GTK CSD rounding, gamescope fullscreen-shell

**What goes wrong:**
The milestone marks Linux as "structural correctness, 待实机验证." Four structural traps:
1. **No global coordinates on Wayland:** any code that positions the window via absolute screen coords (the X11/Win32 pattern) fails silently — Wayland clients can't know their position. Fullscreen must use `xdg_toplevel.set_fullscreen(output)`, not `setPosition`.
2. **SSD vs CSD is the compositor's choice:** `xdg-decoration-unstable-v1` lets the client *request* server-side decorations, but Mutter (GNOME) forces CSD; wlroots (Sway/KDE) may honor SSD. A "rounded corner via SSD" approach works on one compositor and not another.
3. **GTK CSD rounded corners vs rectangular `wl_surface`:** GTK draws rounded corners, but the underlying `wl_surface` is still rectangular. Clicks at the corners hit-test the rectangle (not the visible round edge) — corner interactions land on whatever is beneath. The input region must be explicitly shaped to match the visible region.
4. **gamescope (SteamOS) is a fullscreen shell:** it ignores `xdg-decoration` entirely and runs the app as a borderless fullscreen surface. Corner rounding/SSD/CSD is moot inside gamescope — the app gets a virtual display. Code that branches on "is CSD available" may take the wrong path under gamescope.

**Why it happens:**
X11/Win32 devs assume they control window position, decoration, and shape. Wayland deliberately removes all three from client control. `window_manager` abstracts some of this, but its Linux fullscreen/drag paths have their own bugs (#203, #116). The project has no Linux real hardware, so these failures are invisible until a user reports them.

**How to avoid:**
- **Branch on compositor, not on "Linux":** detect Wayland vs X11 at runtime (`WAYLAND_DISPLAY` env or `gtk` init). On Wayland, never call `setPosition`/`setGeometry` for fullscreen — use the fullscreen hint. On X11, the existing path works.
- **Don't assume SSD or CSD — request CSD and draw your own round corners** in the Flutter layer (a `ClipRRect` on the root), and shape the input region to match. This is compositor-portable. SSD-native rounding is a bonus, not a reliance.
- **For gamescope:** detect (heuristic: `STEAM_RUNTIME`/`GAMESCOPE_WAYLAND_DISPLAY`) and skip all chrome work — gamescope fullscreen-shells the window; rounding/border/drag are no-ops. Document this path.
- **Drag on Wayland** uses `xdg_toplevel.move` (a compositor best-effort request, no coords). The `WM_NCHITTEST`/`HTCAPTION` fallback from Pitfall 8 is Windows-only — on Linux, `startDragging` is the only path, so the `onPointerDown`-call rule matters even more.
- Mark every Linux chrome deliverable `待实机验证` in the plan; do not claim "done on Linux" from headless tests.

**Warning signs:**
- On a Wayland user report: "window position is wrong / fullscreen targets the wrong monitor / drag doesn't work after the first try."
- Code calls `setPosition`/`setGeometry` inside a `Platform.isLinux && isWayland` block (always wrong on Wayland).
- Rounding looks right but corner clicks miss (input region = rectangle).
- "Works on my SteamOS box" but not on a GNOME user's box (gamescope vs Mutter divergence).

**Phase to address:**
Phase 1 (capability detection: detect Wayland/X11/gamescope; probe `xdg-decoration`; record compositor). Phase 6 (Linux structural implementation) consumes the probe and branches. No real-hardware verification phase — deliverables stay `待实机验证`.

---

### Pitfall 10: Re-proposing a reverted fullscreen approach (方案A FFI-bridge / 方案B DWM-disable / global DWMNCRP)

**What goes wrong:**
The milestone restarts fullscreen work after a revert. The three reverted approaches — 方案A (FFI-bridge fullscreen styling), 方案B (DWM-disable via `DWMWA_NCRENDERING_POLICY`/`DWMNCRP_DISABLED`), and global `DWMNCRP` — were each reverted on real hardware (commits aad3ba36, 36883b77) because they produced flicker, didn't fully remove the border, or raced with transitions. A new contributor (or an AI agent without the memory) re-proposes one of them verbatim as the "clean" fix, sending the milestone back into the same revert cycle. The `fullscreen-style-authority` memory records that these are technically-documented but practically-failed.

**Why it happens:**
The reverted approaches each have a coherent technical rationale (FFI bridge gives styling control; DWM-disable removes the system frame; DWMNCRP forces no native rendering). They look correct on paper and in a headless unit test. They fail only on real-hardware transitions, which the re-proposer hasn't run. Without the project memory, the approaches are indistinguishable from genuine new ideas.

**How to avoid:**
- **Treat the three reverted approaches as a denylist.** Add a "Reverted Approaches Registry" to the Phase 4 design doc listing: 方案A (FFI-bridge fullscreen styling), 方案B (DWM-disable / `DWMWA_NCRENDERING_POLICY`), global `DWMNCRP`. Each entry: what it was, why it failed on hardware, the revert commit. Any PR touching fullscreen styling must cite why it's NOT one of these.
- **`wm.setFullScreen` is also on the denylist** (known frameless defect, memory `project_fullscreen_style_authority`). Do not delegate fullscreen to `window_manager.setFullScreen` (see Pitfall 7 — #579 confirms the defect persists).
- **If re-considering one, the bar is:** a real-hardware pilot on the exact transition (enter + exit, on Win10 + Win11), with a perf/raster gate, AND a documented delta from the reverted approach that addresses the specific failure. "Same approach, same transition" = reject.
- The media_kit red line is lifted **for fullscreen only** — this permits modifying the media_kit fullscreen chain, not re-proposing a non-media_kit FFI bridge.

**Warning signs:**
- A design doc / PR description containing `DWMWA_NCRENDERING_POLICY`, `DWMNCRP_DISABLED`, "FFI bridge for fullscreen styling", or `windowManager.setFullScreen`.
- "This is the clean approach we tried before" without citing the revert.
- Headless tests pass but no real-hardware transition pilot.

**Phase to address:**
Phase 4 design gate (the denylist is a phase-4 entry artifact). Phase 1 (capability) establishes the probe that any new approach must use, so re-proposed approaches can be compared apples-to-apples.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|-----------------|
| Bare `return 0` in `WM_NCCALCSIZE` for all frameless cases | One-line frameless; matches Win32 docs | Reopens C1 gap (Pitfall 1), breaks maximized overshoot (Pitfall 2) | Never — use the branched state machine |
| Calling `windowManager.setFullScreen(true)` for fullscreen | Delegates to "maintained" plugin | Hits #579 regression + known frameless defect (Pitfall 7, 10) | Never on frameless — own the path in `WindowBridge`/media_kit |
| `WS_EX_LAYERED` full-window transparency for Win10 rounding | "It works" visually | Disables flip model + overlays → video perf cost (Pitfall 5) | Only with a passing perf gate on real video playback; prefer corner-mask |
| DWM attribute set-once at startup | Simple init | Stale after theme/DPI/mode change → flicker (Pitfall 4) | Never — re-apply at settle-points |
| `startDragging` from `onPanStart` | Uses familiar gesture API | Gesture arena swallows it → no-op drag (Pitfall 8) | Never — use `Listener.onPointerDown` or native `HTCAPTION` |
| Assuming "Linux" is one target | One code path | Wayland/X11/gamescope divergence silently fails (Pitfall 9) | Never — branch on compositor |
| Trusting `flutter test` for fullscreen visuals | Fast CI | Headless can't see gap/flicker/title-bar flash (Pitfalls 1, 4, 6) | CI is necessary but never sufficient — real-hardware UAT required |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|-------------------|
| `window_manager` (leanflutter) | Migrating fullscreen onto PR #531's `WS_THICKFRAME \| WS_MAXIMIZEBOX` path wholesale | Borrow style math only; own exit-restore + title-bar rebind; track #579 (Pitfall 7) |
| `window_manager` drag API | `startDragging()` from `GestureDetector.onPanStart` | `Listener.onPointerDown`, or native `WM_NCHITTEST`→`HTCAPTION` (Pitfall 8) |
| media_kit `Video` texture | Assuming texture survives fullscreen resize because it survives window resize | Probe `textureIdChanges=0` *during fullscreen toggle* specifically (Pitfall 6); media_kit is limited-maintenance (#1337), project owns the fix |
| DWM (`DwmSetWindowAttribute`) | Win11-only attrs called on Win10; attrs set once | Probe `DwmCapabilities` in Phase 1; re-apply at settle-points (Pitfalls 3, 4) |
| Win32 `WM_NCCALCSIZE` | One `return 0` for all cases | Branched handler: fullscreen→C1 inset, maximized→overshoot, default→`return 0` (Pitfalls 1, 2) |
| Wayland compositors | `setPosition` for fullscreen | `xdg_toplevel.set_fullscreen(output)`; branch on compositor (Pitfall 9) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `WS_EX_LAYERED` transparency on video window | CPU/GPU ~1.5–2x during playback; raster >33ms | Native corners (Win11) / corner-mask (Win10); perf gate before merge | Any video playing through a transparent window on Intel iGPU |
| Texture rebuild on fullscreen toggle | Single blank/black frame on enter/exit | Sequence resize; keep `Video` widget identity stable; probe `textureIdChanges` | Fullscreen toggle mid-playback (the project's own profile sessions showed `textureIdChanges=0` only *after* the resize-three-sources fix; fullscreen is a new path) |
| Animation overlapping fullscreen transition | Title-bar flash / size jump visible | `isFullscreenTransition` flag → `Duration.zero` animations | Any `Animated*` on chrome not gated off during transition |
| DWM attribute re-apply during (not after) transition | Single-frame flicker of system frame | Re-apply at settle-point (post-`WM_SIZE` final geometry) | Every theme/DPI/fullscreen change |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| FFI fullscreen bridge touching `user32`/`dwmapi` without null-checking function pointers | Crash on a Windows build missing the API (older Win10) | Probe `GetProcAddress`; fall back if null (Pitfall 3); never assume the export exists |
| Native `WM_NCHITTEST` returning `HTCAPTION` for too large a region | User can't click controls in the title bar area; drag steals input | Narrow `HTCAPTION` rect to the actual title-bar pixels; exclude button regions | 
| Storing fullscreen snapshot in a global mutable without locking | Concurrent toggle calls corrupt restore geometry | Snapshot is immutable `final`; single owner (`WindowBridge`); idempotent enter/exit (Pitfall 6) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Title bar flash on fullscreen enter | Feels janky, "am I in fullscreen?" confusion | Hide chrome *before* native style change; reveal at settle-point (Pitfall 6) |
| Wrong restore geometry on exit | Window lands off-screen or wrong size; user must resize | Snapshot *before* transition; restore from immutable snapshot (Pitfall 6, #181/#266) |
| Drag no-op on title bar | "The window is stuck" — core UX failure | Native `HTCAPTION` hit-test path (Pitfall 8); `onPointerDown` fallback |
| Red border persists on Win10 | "I thought you fixed this" — feature looks unfinished | Win10 path is NOT `DWMWA_BORDER_COLOR`; verify on real Win10 (Pitfall 3) |
| Rounded corners with black video fringes | Looks broken on bright videos | `ClipRRect` on the `Video` widget itself, not a sibling (Pitfall 5) |

## "Looks Done But Isn't" Checklist

- [ ] **Accent-border removal:** "Works on my Win11 dev box" — verify on real Win10 with a non-default accent color (Pitfall 3); `DWMWA_BORDER_COLOR` is Win11-only.
- [ ] **Rounded corners:** "Corners are round" — verify video corners aren't black-fringed (Pitfall 5) and `WS_EX_LAYERED` perf gate passes with video playing.
- [ ] **Fullscreen enter:** "No gap at edges" — verify on real hardware, not headless (Pitfall 1, C1 regression is invisible headless).
- [ ] **Fullscreen exit:** "Window comes back" — verify restore geometry on the *same* monitor and after a monitor-change DPI jump (Pitfall 6, #181/#266).
- [ ] **Title bar drag:** "Drag works" — verify after enter→exit→enter cycle (Pitfall 7, #579 regression) and after a maximize (Pitfall 8).
- [ ] **DWM attributes:** "Set at startup" — verify after a theme toggle and a DPI change (Pitfall 4).
- [ ] **Linux:** "Structurally correct" — verify Wayland compositor branch is taken and `setPosition` is NOT called for fullscreen (Pitfall 9); mark `待实机验证`.
- [ ] **Reverted approach:** "New clean fix" — check it isn't 方案A/B/DWMNCRP/`wm.setFullScreen` (Pitfall 10).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| C1 gap regression (Pitfall 1) | LOW | `git revert` the `WM_NCCALCSIZE` change; re-assert branched handler; C1 test should go red then green |
| Maximized overshoot / autohide (Pitfall 2) | MEDIUM | Re-add `DefWindowProc`-first or explicit overshoot math in `isMaximized` branch; test on Win10+Win11 multi-monitor autohide |
| DWM attr on Win10 (Pitfall 3) | LOW | Wrap call in `IsWindows11OrGreater()` + `HRESULT` check; log failures; route Win10 via `WS_THICKFRAME` path |
| DWM attr stale after change (Pitfall 4) | MEDIUM | Add `applyChromeAttributes()` to `WM_THEMECHANGED`/`WM_DPICHANGED`/settle-point; re-test transitions |
| Fake-round perf cost (Pitfall 5) | MEDIUM | Revert `WS_EX_LAYERED`; ship native Win11 + corner-mask Win10; re-run perf gate |
| Fullscreen flicker (Pitfall 6) | HIGH | Sequence + snapshot + animation-gate are interdependent; fix as a set, not piecemeal; re-run real-hardware UAT |
| #579 title-bar-no-return (Pitfall 7) | HIGH | If migrated to #531 path, revert to project's media_kit chain; re-assert frameless style + rebind title bar on exit |
| Drag no-op (Pitfall 8) | MEDIUM | Switch to `Listener.onPointerDown` or native `HTCAPTION`; re-test after maximize + enter/exit cycle |
| Linux Wayland failures (Pitfall 9) | HIGH (no hardware) | Can't recover without real hardware; mark `待实机验证`, document the compositor branches so a user can self-report |
| Reverted approach re-proposed (Pitfall 10) | LOW | Reject at PR review against the denylist; cite the revert commit and memory |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. C1 gap regression | Phase 1 (pin C1 + test + guard comment) | Real-hardware fullscreen: no edge seam (headless can't verify) |
| 2. Maximized overshoot / autohide | Phase 1 (probe) + Phase 4 (transition) | Win10+Win11 multi-monitor autohide: taskbar summonable over maximized player |
| 3. DWM attr Win10 no-op | Phase 1 (`DwmCapabilities` probe) + Phase 2 | Real Win10 with non-default accent color: no red border |
| 4. DWM attr stale after change | Phase 2 (re-apply hooks) + Phase 4 (settle-point) | Theme toggle + DPI change + fullscreen cycle: attrs stable, no mid-transition flicker |
| 5. Fake-round perf/fringes | Phase 1 (probe) + Phase 3 (native-first, fake-round fallback) | Perf gate raster <33ms with video; no black corners on bright video |
| 6. Fullscreen flicker (4 causes) | Phase 4 (sequence + snapshot + animation-gate + texture probe) | Real-hardware enter/exit: no blank frame, no title flash, correct restore geometry |
| 7. #531/#579 regression | Phase 4 (design gate: stay on media_kit chain) | Title bar interactive after enter→exit→enter on real hardware |
| 8. Drag no-op / double-click / maximized | Phase 5 (native `HTCAPTION` primary; `onPointerDown` fallback) | Drag works after maximize, after enter/exit, repeated 20× |
| 9. Linux Wayland/gamescope | Phase 1 (compositor probe) + Phase 6 (branch) | `待实机验证`; structural: no `setPosition` on Wayland; input region shaped |
| 10. Reverted approach re-proposal | Phase 4 (denylist in design doc) | PR review cites why approach ≠ 方案A/B/DWMNCRP/`wm.setFullScreen` |

## Sources

- [leanflutter/window_manager — startDragging issues search](https://github.com/leanflutter/window_manager/issues?q=startDragging) — #399 (no-op, closed), #203 (Linux cannot-drag-again, merged), #511 (no maximize in onDoubleTapDown, open), #372 (DragToMoveArea double-click, closed) [HIGH]
- [leanflutter/window_manager — fullscreen+frameless issues search](https://github.com/leanflutter/window_manager/issues?q=fullscreen+frameless) — PR #531 (frameless fullscreen, merged May 2025), #456 (frameless fullscreen request), #367 (better fullscreen, merged), #389 (frameless broken after #367), #181 (right bound overlapped after leaving fullscreen), #266 (Fullscreen/Set as frameless bugs MediaQuery), #579 (title bar not appearing after exit — OPEN regression, Dec 2025) [HIGH]
- [window_manager PR #531](https://github.com/leanflutter/window_manager/pull/531) — `WS_THICKFRAME | WS_MAXIMIZEBOX` approach, SetAsFrameless + separate position/size, removed force-refresh; follow-up regression #579 [HIGH]
- [window_manager PR #367](https://github.com/leanflutter/window_manager/pull/367) — 6-step fullscreen method; #389 regression cycle [HIGH]
- [window_manager issue #579](https://github.com/leanflutter/window_manager/issues/579) — OPEN regression: title bar not reappearing after fullscreen exit on Windows; workaround = don't touch `titleBarStyle` [HIGH]
- [Microsoft Learn — WM_NCCALCSIZE message](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-nccalcsize) — `return 0` when `wParam==TRUE` removes frame+caption; WVR_* return values; Vista+ DwmExtendFrameIntoClientArea caveat [HIGH]
- [Microsoft Learn — DwmSetWindowAttribute](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/nf-dwmapi-dwmsetwindowattribute) + [DWM_WINDOW_ATTRIBUTE enum](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwm_window_attribute) — `DWMWA_WINDOW_CORNER_PREFERENCE` (33) and `DWMWA_BORDER_COLOR` (34) are Windows 11 build 22000+ only; `E_INVALIDARG` on Win10 [HIGH]
- [Microsoft Learn — Layered Windows](https://learn.microsoft.com/en-us/windows/win32/winmsg/layered-windows), [DXGI Flip Model](https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/dxgi-flip-model), [DXGI Hardware Overlay Support](https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/dxgi-hardware-overlay-support) — `WS_EX_LAYERED` forces DWM readback, disables flip model + hardware overlays (Pitfall 5) [HIGH]
- [media-kit/media-kit — limited maintenance](https://github.com/media-kit/media-kit/issues/1337) — repo under limited maintenance since Nov 2025; project owns fullscreen/texture fixes [HIGH]
- [media-kit/media-kit — texture resize/rebuild issues](https://github.com/media-kit/media-kit/issues?q=texture+resize+rebuild) — only #1395 (mobile ANR); no desktop fullscreen texture-rebuild issue tracked upstream (project-owned) [MEDIUM]
- [flutter/flutter — desktop resize janky #44136](https://github.com/flutter/flutter/issues/44136) — engine-level desktop resize jank; texture/surface handling involved [MEDIUM]
- [flutter/flutter — texture flicker search](https://github.com/flutter/flutter/issues?q=texture+flicker+resize+desktop) — only macOS #135999 (video_player_avfoundation flickering, open); no Windows/Linux desktop texture-flicker issue upstream [MEDIUM]
- Project memory: `project_fullscreen_seam_icon_fix.md` (C1/C2 fixes, shipped), `project_fullscreen_style_authority.md` (方案A/B/DWMNCRP reverted, `wm.setFullScreen` defect), `bugfix_white_border_frameless.md` (frameless + SmartDragToResizeArea origin) [HIGH — project-specific]

---
*Pitfalls research for: frameless Flutter desktop window chrome + media_kit fullscreen transitions (Win10/Win11/Linux)*
*Researched: 2026-09-01*
