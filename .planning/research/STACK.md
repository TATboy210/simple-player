# Stack Research

**Domain:** Flutter desktop (Windows primary, Linux secondary) window chrome + media_kit fullscreen
**Researched:** 2026-09-01
**Confidence:** HIGH (Win32 DWM APIs verified against Microsoft Learn; window_manager/media_kit internals verified against pub-cache source)

## Recommended Stack

This milestone adds four window-chrome fixes to an existing, validated Flutter desktop + media_kit player. The "stack" here is **not a new framework** — it is a set of **Win32 DWM attribute APIs**, **Win32 window-style / hit-test techniques**, **GTK window primitives** (Linux), and **surgical fixes to the existing window_manager 0.5.2 + media_kit 1.2.6 + runner C++ chain**. No new pub dependencies are required.

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `DwmSetWindowAttribute` + `DWMWA_BORDER_COLOR` | Win11 build 22000+ | Suppress the DWM-drawn accent-color border on the frameless window | The one targeted call `DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &DWMWA_COLOR_NONE, sizeof(COLORREF))` with `DWMWA_COLOR_NONE = 0xFFFFFFFE` **suppresses border drawing entirely** without touching non-client rendering policy. Verified on Microsoft Learn (`dwmapi.h`, enum `DWMWINDOWATTRIBUTE`). This is the clean fix the user needs on their Win11 26200 system. |
| `DwmSetWindowAttribute` + `DWMWA_WINDOW_CORNER_PREFERENCE` | Win11 build 22000+ | Native rounded corners on Win11 | `DWMWCP_ROUND = 2` gives the OS-native, anti-aliased, free rounded corners. Win11 already rounds by default, but setting it explicitly guarantees consistency regardless of user theme / snap state. Verified on Microsoft Learn (`DWM_WINDOW_CORNER_PREFERENCE` enum, min build 22000). |
| `SetWindowRgn` + `CreateRoundRectRgn` | Win10 fallback only | Fake rounded corners on Win10 (no native API) | Win10 has **no** DWM corner API. `SetWindowRgn` is the only zero-overhead option (1-bit mask, no per-pixel alpha tax). Aliased edges are the accepted trade-off — a video player's dynamic content rules out the layered-window alternative. Mark "accept aliasing or accept square corners" as a product decision. |
| `WM_NCHITTEST` → `HTCAPTION` in runner C++ | Win32, all Windows | Reliable title-bar drag without channel round-trip | Returning `HTCAPTION` from the existing `WM_NCHITTEST` handler lets `DefWindowProc` run the native modal drag loop (`WM_NCLBUTTONDOWN` → `HTCAPTION` → `SC_MOVE`) **synchronously** on pointer-down. Zero channel latency, zero race. The runner already handles `WM_NCHITTEST` for resize — extending it to `HTCAPTION` for the title bar region is a small, additive change. |
| `SetWindowPos` with `SWP_FRAMECHANGED` | Win32, all Windows | Flicker-free fullscreen style+size transition | The window_manager `SetFullScreen` reference (and media_kit's `utils.cc` which it copies) uses `SetWindowLongPtr(GWL_STYLE, …)` to strip `WS_THICKFRAME|WS_MAXIMIZEBOX` then `SetWindowPos(…, SWP_FRAMECHANGED)` to apply. Ordering: strip style → apply frame change → resize to monitor in one or two `SetWindowPos` calls. `WM_ERASEBKGND` returning 1 (already in runner) suppresses the background-erase flash. |
| `DWMWA_TRANSITIONS_FORCEDISABLED` (targeted) | Win Vista+ (attribute itself); relevant Win10/11 | Suppress DWM's own transition animation during fullscreen enter/exit | Set `TRUE` immediately before the fullscreen style change, `FALSE` immediately after. This is **a different attribute** from the withdrawn `DWMWA_NCRENDERING_POLICY` (DWMNCRP) — it disables transition *animations*, not non-client *rendering*. MEDIUM confidence: adjacent to the withdrawn family, verify on real hardware before committing. |
| `gtk_window_begin_move_drag` / `gdk_toplevel_begin_move` | GTK3 (Linux embedder) | Linux title-bar drag | The GTK equivalent of `SC_MOVE`. Already what `window_manager`'s Linux plugin calls. Same async-via-GDK-event-loop race as Windows; Linux fix is structural (CSD hit-test) not a quick patch. Mark "待实机验证". |

### Supporting Libraries / Primitives

| Library / Primitive | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `window_manager` | **0.5.2** (actual `pubspec.lock`; CLAUDE.md's "5.15.0" is a doc typo) | Existing window control: `setAsFrameless`, `titleBarStyle.hidden`, `startDragging`, `setPreventClose` | Keep as the Dart↔native bridge. **Do not call `setFullScreen()`** — it is a no-op on frameless windows (`is_frameless_` guard at `window_manager.cpp:593` skips the style change). Fullscreen must go through the media_kit chain. |
| `media_kit` / `media_kit_video` | 1.2.6 / 2.0.1 | Existing playback + fullscreen chain | Red line **lifted for fullscreen only** this milestone. `enterFullscreen()` pushes a Flutter route wrapped in `FullscreenInheritedWidget` + calls `enterNativeFullscreen()` (strips `WS_OVERLAPPEDWINDOW`, resizes to monitor). Flicker fixes go here. |
| `dart:ffi` → `DwmSetWindowAttribute` | Dart 3.13 FFI | Call DWM attribute APIs from Dart (optional) | If the runner-C++ path is undesirable, a thin FFI wrapper in `lib/kernel/window_bridge/` can call `DwmSetWindowAttribute` directly. **Prefer the runner C++ path** — DWM calls belong with the native window, and the runner already owns `WM_NCCALCSIZE`/`WM_NCHITTEST`. Reserve FFI only for attributes that must be set from Dart (e.g. a `setBorderColor` method on `WindowBridge`). |
| `windows/runner/win32_window.cpp` + `flutter_window.cpp` | Existing C++ | Native hit-test, NCCALCSIZE, fullscreen preemption | **Primary implementation surface** for (a) border, (b) corners via DWM, (d) `HTCAPTION` drag. Already handles `WM_NCCALCSIZE` (frameless + media_kit fullscreen preemption), `WM_NCHITTEST` (8px resize), `WM_ERASEBKGND` (return 1). |
| Flutter `ClipRRect` (Linux CSD only) | Flutter 3.47.0 | Draw rounded corners on a borderless Linux window | Only when the Linux window is undecorated (CSD/borderless) and the compositor doesn't round. On GNOME/Mutter Wayland, decorated windows get compositor-rounded corners for free; on X11 borderless, `ClipRRect` on the outermost widget + transparent window background gives soft corners. **Not for Windows** (use DWM `DWMWCP_ROUND` instead — `ClipRRect` on Windows would need a layered/transparent window = video perf tax). |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `dwmapi.lib` / `dwmapi.dll` | Link DWM attribute calls | Already available via Windows SDK; add `#pragma comment(lib, "dwmapi.lib")` or CMake `target_link_libraries(... dwmapi)` in `windows/CMakeLists.txt`. No new dependency. |
| `windowsx.h` macros (`GET_X_LPARAM`, `HTCAPTION`, etc.) | Win32 hit-test helpers | Already included in `win32_window.cpp`. |
| Microsoft Learn Win32 docs | Authoritative DWM API reference | `learn.microsoft.com/windows/win32/api/dwmapi/` — verified 2024-2026 content. |

## Installation

No new pub dependencies. The existing stack is sufficient. The only build change is linking `dwmapi.lib` if not already linked:

```bash
# CMake (windows/CMakeLists.txt) — add to target_link_libraries if dwmapi not already present
# target_link_libraries(${BINARY_NAME} PRIVATE ... dwmapi)

# Verify the existing dependency tree (no changes expected)
flutter pub get
flutter analyze
flutter test
```

The DWM calls are added to the **existing** `windows/runner/*.cpp` files and (optionally) a thin FFI file under `lib/kernel/window_bridge/` — no package additions.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Accent border (Win11) | `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` | `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` | **Withdrawn by user** (2026-08-27, real-hardware效果不理想). Do NOT re-propose. |
| Accent border (Win11) | `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` | Strip `WS_THICKFRAME` from `GWL_STYLE` | Works but cascades: breaks the media_kit fullscreen detection (`(style & WS_OVERLAPPEDWINDOW) == 0` heuristic in `flutter_window.cpp:67`) and loses native resize (already lost, but the heuristic break is the real cost). `DWMWA_BORDER_COLOR` is surgical — no style cascading. |
| Accent border (Win10) | Accept 1px accent border OR strip `WS_THICKFRAME` + update fullscreen heuristic | `DWMWA_NCRENDERING_POLICY` | Withdrawn (see above). `DWMWA_BORDER_COLOR` is 22000+ only — not available on Win10. |
| Rounded corners (Win11) | `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` | Flutter `ClipRRect` on transparent window | Would require `WS_EX_LAYERED` / transparent window background = per-pixel composite tax on every video frame. DWM native is free + anti-aliased. |
| Rounded corners (Win10) | `SetWindowRgn` + `CreateRoundRectRgn` (accept aliasing) OR accept square | Layered window (`WS_EX_LAYERED`) + `UpdateLayeredWindow` ARGB | Anti-aliased but **video performance tax** — the entire window is composited per-pixel on each frame. A media player's dynamic content rules this out. |
| Rounded corners (Win10) | Accept square corners | `SetWindowRgn` (aliased) | Product call. Unix principle: don't fake what the OS can't do natively. Win10 is legacy; the user is on Win11 26200. Square corners on Win10 is acceptable divergence. |
| Fullscreen transition | `SetWindowPos` ordering + `WM_ERASEBKGND` + targeted `DWMWA_TRANSITIONS_FORCEDISABLED` | `wm.setFullScreen()` (window_manager) | **No-op on frameless windows** (`is_frameless_` guard skips the style change). Known frameless defect per project memory. Use the media_kit chain instead. |
| Fullscreen transition | media_kit chain + `SetWindowPos` ordering | 方案A (FFI bridge) / 方案B (DWM 禁用) | **Reverted on real hardware** 2026-08-27. Do NOT re-propose. |
| Title-bar drag | Tier 1: bypass `await isFullScreen()` (sync check) + direct channel call. Tier 2: native `WM_NCHITTEST → HTCAPTION` | `PostMessage(WM_NCLBUTTONDOWN, HTCAPTION, …)` | Async post = unreliable (mouse state may change between post and dispatch). window_manager already uses `SendMessage(WM_SYSCOMMAND, SC_MOVE|HTCAPTION)` (synchronous) — the problem is the Dart double-async, not the native call. |
| Title-bar drag (Linux) | Keep `gtk_window_begin_move_drag` (accept same async race) | Native CSD hit-test override | Complex GTK CSD work; no real hardware to verify. Mark "待实机验证". |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `DWMWA_NCRENDERING_POLICY` (`DWMNCRP_DISABLED` / global DWMNCRP) | Withdrawn 2026-08-27 — real-hardware效果不理想. User explicitly said "勿重提". | `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` for border; `DWMWA_WINDOW_CORNER_PREFERENCE` for corners. |
| `wm.setFullScreen()` (window_manager `SetFullScreen`) | No-op on frameless windows — `is_frameless_` guard skips the entire style/resize block (`window_manager.cpp:593`). | media_kit fullscreen chain (`enterFullscreen`/`exitFullscreen` + `enterNativeFullscreen`/`exitNativeFullscreen`). |
| 方案A (FFI bridge for fullscreen) | Reverted on real hardware 2026-08-27. | media_kit native fullscreen + `SetWindowPos` ordering in runner. |
| 方案B (DWM disable for fullscreen) | Reverted on real hardware 2026-08-27. | `DWMWA_TRANSITIONS_FORCEDISABLED` targeted (different attribute) — but verify on hardware first. |
| Layered window (`WS_EX_LAYERED`) + `UpdateLayeredWindow` for rounded corners on Windows | Per-pixel composite tax on every frame — unacceptable for a texture-rendered video player. | Win11: `DWMWCP_ROUND`. Win10: `SetWindowRgn` (aliased) or accept square. |
| `PostMessage(WM_NCLBUTTONDOWN, HTCAPTION, …)` for drag | Async post — mouse capture/button state can change between post and dispatch, causing missed drags. | `SendMessage(WM_SYSCOMMAND, SC_MOVE|HTCAPTION)` (synchronous) — already what window_manager native uses. The fix is eliminating the Dart-side double-async, not changing the native call. |
| Flutter `ClipRRect` for rounded corners on Windows | Requires transparent window background → layered/alpha window → video perf tax. | DWM `DWMWA_WINDOW_CORNER_PREFERENCE` (Win11) or `SetWindowRgn` (Win10). |

## Stack Patterns by Variant

### Accent-color border suppression

**If Windows 11 (build ≥ 22000, user's system is 26200):**
- Call `DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &DWMWA_COLOR_NONE, sizeof(COLORREF))` once after window creation (`OnCreate` or after `waitUntilReadyToShow`).
- `DWMWA_COLOR_NONE = 0xFFFFFFFE` — **suppresses** border drawing entirely (enables "rounded window with no border" per Microsoft Learn).
- Confidence: **HIGH** — verified on Microsoft Learn `dwmapi.h` enum page.
- Optionally also set `DWMWA_CAPTION_COLOR` / `DWMWA_TEXT_COLOR` if a custom title-bar color is desired later (both 22000+).

**If Windows 10 (build < 22000):**
- `DWMWA_BORDER_COLOR` is **not available** (returns `E_INVALIDARG` / no-op on Win10).
- Option A (pragmatic, recommended): **accept the 1px accent border** on Win10. The user is on Win11; Win10 is a legacy fallback. Square/rounded corners already diverge on Win10, so a 1px border is consistent with "Win10 is best-effort".
- Option B (if border must be suppressed): strip `WS_THICKFRAME` from `GWL_STYLE` via `SetWindowLongPtr` + `SetWindowPos(SWP_FRAMECHANGED)`. **Cascading effect**: the media_kit fullscreen preemption in `flutter_window.cpp:67` checks `(style & WS_OVERLAPPEDWINDOW) == 0` — if `WS_THICKFRAME` is stripped but `WS_OVERLAPPEDWINDOW` flags remain, the heuristic still works; if the full `WS_OVERLAPPEDWINDOW` is stripped, the heuristic breaks. Careful: strip only `WS_THICKFRAME`/`WS_SIZEBOX`, keep `WS_OVERLAPPEDWINDOW` base for the heuristic. Confidence: **MEDIUM** — needs cascading-effect verification.
- Do NOT use `DWMWA_NCRENDERING_POLICY` (withdrawn).

### Rounded corners

**If Windows 11 (build ≥ 22000):**
- `DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &DWMWCP_ROUND, sizeof(int))` where `DWMWCP_ROUND = 2`.
- Native, anti-aliased, free. Set once at window creation.
- Confidence: **HIGH** — verified on Microsoft Learn `DWM_WINDOW_CORNER_PREFERENCE` enum page (min build 22000).

**If Windows 10 (build < 22000):**
- No native corner API.
- **Recommended: accept square corners.** Unix principle: don't fake what the OS can't do natively. Win10 is legacy; the primary target is Win11.
- If rounding is truly required: `SetWindowRgn(hwnd, CreateRoundRectRgn(0, 0, w, h, r, r), TRUE)` — aliased (jagged) edges, zero per-frame cost. Recompute on resize (`WM_SIZE` → re-`SetWindowRgn`). Accept the aliasing.
- Do NOT use layered window for a video player (perf tax).
- Confidence: **MEDIUM** (product decision).

**If Linux (GTK3, Wayland or X11):**
- **Decorated window (SSD/CSD default):** GNOME/Mutter (Wayland) draws compositor-rounded corners for free. KDE/KWin (X11) likewise. Keep the window decorated (`gtk_window_set_decorated(TRUE)`) and let the compositor handle corners.
- **Borderless/undecorated window:** the compositor won't round. Draw `ClipRRect` on the outermost Flutter widget with a transparent window background (`backgroundColor: Colors.transparent` in `WindowOptions`, already set). The compositor composites the transparent corners. Soft anti-aliased edges.
- **SteamOS/gamescope:** gamescope is a micro-compositor that runs apps fullscreen/borderless by design. Rounded corners are irrelevant in fullscreen mode. No action needed.
- Confidence: **MEDIUM** — no Linux real hardware; mark "待实机验证".

### Flicker-free fullscreen transition

**Enter fullscreen (media_kit chain):**
1. Make the title bar **synchronously** invisible before the route push — replace `AnimatedOpacity` with `Visibility(maintainState: true, visible: !isFullscreen)` or set opacity to 0 immediately (no animation) on the enter half. The animation causes the "title bar flash" during the route transition.
2. media_kit `enterNativeFullscreen()` strips `WS_OVERLAPPEDWINDOW` and resizes to monitor. Ensure the runner's `WM_NCCALCSIZE` preemption (already in `flutter_window.cpp:63-71`) returns 0 for the fullscreen style — this is already done and working.
3. `WM_ERASEBKGND` returning 1 (already in `win32_window.cpp:250-251`) suppresses the background-erase flash.
4. Optional: `DWMWA_TRANSITIONS_FORCEDISABLED` set `TRUE` before, `FALSE` after the `SetWindowPos` sequence — suppresses DWM's own transition animation. **MEDIUM confidence** — adjacent to the withdrawn DWMNCRP family; verify on real hardware.

**Exit fullscreen (media_kit chain):**
1. Restore window style (`WS_OVERLAPPEDWINDOW`) before restoring size — or combine in one `SetWindowPos(SWP_FRAMECHANGED)` call.
2. `WM_ERASEBKGND` return 1 suppresses flash.
3. Title bar `Visibility` flips back to visible **after** the route pop completes (not during).
4. Optional: `DWMWA_TRANSITIONS_FORCEDISABLED` targeted (same as enter).

**Do NOT use:**
- `wm.setFullScreen()` — no-op on frameless windows.
- 方案A (FFI bridge) / 方案B (DWM disable) — reverted on real hardware.
- `DWMWA_NCRENDERING_POLICY` — withdrawn.

Confidence: **MEDIUM** — the individual pieces (`WM_ERASEBKGND`, `SetWindowPos` ordering, route pre-hiding) are well-established; the `DWMWA_TRANSITIONS_FORCEDISABLED` targeted use is the novel part and needs real-hardware verification.

### Title-bar drag reliability

**Tier 1 (minimal, high-impact, recommended first):**
- The root cause: `window_manager`'s Dart `startDragging()` does `await isFullScreen()` (channel round-trip 1) THEN `await _channel.invokeMethod('startDragging')` (channel round-trip 2) before the native `ReleaseCapture()` + `SendMessage(WM_SYSCOMMAND, SC_MOVE|HTCAPTION)`. The double-async latency means the native drag loop starts ~2 channel round-trips after `onPanStart` — on quick clicks the mouse button may be released by then.
- Fix: bypass the `await isFullScreen()` check. The project already has a **synchronous** fullscreen state via `WindowBridge.mode.value.isFullscreen`. Call the channel directly (single round-trip) or add a project-level `startDragging` that checks fullscreen synchronously first.
- The native `SendMessage(SC_MOVE|HTCAPTION)` is already synchronous and reliable — Tier 1 keeps it, just removes the redundant async round-trip.
- Confidence: **HIGH** that this reduces the race frequency; **MEDIUM** that it fully eliminates it (one channel round-trip remains).

**Tier 2 (belt-and-suspenders, fully eliminates the race):**
- Extend the runner's `WM_NCHITTEST` handler (`win32_window.cpp:256-271`) to return `HTCAPTION` for the title-bar drag region (top `Tokens.titleBarHeight` = 32px, minus the 8px resize edges, minus the right-side button group width).
- `DefWindowProc` handles `WM_NCLBUTTONDOWN` with `HTCAPTION` → enters the native modal drag loop **synchronously** on pointer-down. Zero channel latency, zero race.
- The challenge: the button group width is responsive (`showPin` depends on `constraints.maxWidth >= 4 * buttonWidth`). Options:
  - (a) Use a fixed offset for the button area (e.g. rightmost 160px = 4 buttons × 40px). Fragile if button widths change.
  - (b) Communicate the button bounds from Flutter to the runner via a platform channel (`setDragRegion(rightEdgeOffset)`), and the runner returns `HTCAPTION` only left of that offset.
  - (c) Return `HTCAPTION` for the full title bar, and move the window buttons to a separate top-level `HWND` (overkill).
- Recommended: option (b) — a `setHitTestCaptionExcludeRight(int pixels)` channel call. The runner stores the offset and returns `HTCAPTION` for `pt.x < rect.right - offset` in the title-bar band, `HTCLIENT` otherwise (buttons receive clicks normally).
- Confidence: **HIGH** that this fully eliminates the race; **MEDIUM** on the button-bounds coordination (needs the channel call to stay in sync on resize).

**Linux equivalent:**
- `gtk_window_begin_move_drag()` (X11) / `gdk_toplevel_begin_move` (Wayland) — also async via the GDK event loop. Same race potential.
- Native CSD hit-test override on GTK is complex; no real hardware to verify.
- Recommended: keep the GTK call, accept the same async race on Linux, mark "待实机验证".
- Confidence: **MEDIUM**.

## Version Compatibility

| Package / API | Compatible With | Notes |
|-----------|-----------------|-------|
| `window_manager` 0.5.2 | Flutter 3.47.0, Dart 3.13 | Actual locked version. **CLAUDE.md's "5.15.0" is a documentation typo** — `pubspec.yaml` says `^0.5.2`, `pubspec.lock` confirms 0.5.2. No action needed beyond correcting the doc. |
| `DWMWA_BORDER_COLOR` (34) | Windows 11 build 22000+ | Returns `E_INVALIDARG` on Win10. Guard with `IsWindows10BuildOrGreater(22000)` or RtlGetVersion. |
| `DWMWA_WINDOW_CORNER_PREFERENCE` (33) | Windows 11 build 22000+ | Same guard. `DWMWCP_ROUND = 2`. |
| `DWMWA_CAPTION_COLOR` (35) / `DWMWA_TEXT_COLOR` (36) | Windows 11 build 22000+ | Same guard. |
| `DWMWA_TRANSITIONS_FORCEDISABLED` | Windows Vista+ | The attribute itself is Vista+, but the transition-suppression behavior is most relevant on Win10/11. |
| `DWMWA_NCRENDERING_POLICY` | Windows Vista+ | **Withdrawn — do NOT use** regardless of availability. |
| `DWMWA_SYSTEMBACKDROP_TYPE` (38) | Windows 11 build **22621** (22H2+) | Not needed this milestone; note the higher build floor if used later. |
| `SetWindowRgn` / `CreateRoundRectRgn` | All Windows versions | Win10 fallback for rounded corners. |
| media_kit 1.2.6 fullscreen | Flutter 3.47.0, libmpv (media_kit_libs_windows_video 1.0.11) | Red line lifted for fullscreen only this milestone. Route-push + `enterNativeFullscreen` chain. |
| `DwmSetWindowAttribute` (function) | Windows Vista+, `Dwmapi.lib` / `Dwmapi.dll` | The function itself is Vista+; individual attributes have their own build floors (see above). Link `dwmapi.lib` in CMake. |

## Sources

- **Microsoft Learn — `DWMWINDOWATTRIBUTE` enum** (`learn.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute`) — verified `DWMWA_BORDER_COLOR=34`, `DWMWA_COLOR_NONE=0xFFFFFFFE`, `DWMWA_WINDOW_CORNER_PREFERENCE=33`, `DWMWA_CAPTION_COLOR=35`, `DWMWA_TEXT_COLOR=36`, `DWMWA_TRANSITIONS_FORCEDISABLED`, `DWMWA_NCRENDERING_POLICY`, all with min build 22000 where applicable. **HIGH confidence.**
- **Microsoft Learn — `DwmSetWindowAttribute` function** (`learn.microsoft.com/windows/win32/api/dwmapi/nf-dwmapi-dwmsetwindowattribute`) — verified signature, min Windows Vista, `Dwmapi.lib`. **HIGH confidence.**
- **Microsoft Learn — `DWM_WINDOW_CORNER_PREFERENCE` enum** (`learn.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwm_window_corner_preference`) — verified `DWMWCP_DEFAULT=0, DWMWCP_DONOTROUND=1, DWMWCP_ROUND=2, DWMWCP_ROUNDSMALL=3`, min build 22000. **HIGH confidence.**
- **window_manager 0.5.2 source** (`pub-cache/.../window_manager-0.5.2/windows/window_manager.cpp`) — verified native `StartDragging()` = `ReleaseCapture()` + `SendMessage(WM_SYSCOMMAND, SC_MOVE|HTCAPTION)`, `SetFullScreen()` `is_frameless_` guard (no-op on frameless). **HIGH confidence.**
- **window_manager 0.5.2 Dart source** (`lib/src/window_manager.dart:719-722`) — verified double-async `startDragging()` (`await isFullScreen()` + `await invokeMethod`). **HIGH confidence.**
- **window_manager 0.5.2 Linux source** (`linux/window_manager_plugin.cc:611-627`) — verified `gtk_window_begin_move_drag` path. **HIGH confidence.**
- **Context7 — window_manager `/leanflutter/window_manager`** — `WindowOptions`, `titleBarStyle.hidden`, `WindowListener` events (`onWindowEnterFullScreen`/`onWindowLeaveFullScreen`). **HIGH confidence.**
- **Context7 — media_kit `/media-kit/media-kit`** — `toggleFullscreen`/`enterFullscreen`/`exitFullscreen` route-push + `FullscreenInheritedWidget`, `VideoState` fullscreen API, `enterNativeFullscreen`/`exitNativeFullscreen`. **HIGH confidence.**
- **Win32 drag-technique community knowledge** (WebSearch synthesis of Stack Overflow / Win32 community) — `SendMessage` vs `PostMessage` for `WM_NCLBUTTONDOWN`/`HTCAPTION`; `SC_MOVE` reliability ranking. **MEDIUM confidence** (training-knowledge synthesis, consistent with verified source code).
- **Win10 rounded-corners community knowledge** (WebSearch synthesis) — `SetWindowRgn` (aliased, fast) vs layered window (anti-aliased, perf tax) trade-off. **MEDIUM confidence** (consistent with Win32 API semantics).

---
*Stack research for: Flutter desktop window chrome + media_kit fullscreen (Windows primary, Linux secondary)*
*Researched: 2026-09-01*
