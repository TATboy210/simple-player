# Project Research Summary

**Project:** Simple Player v1.1 — Window Chrome & Fullscreen Experience
**Domain:** Flutter desktop media player window-chrome layer (Win10/Win11 primary, Linux structural-only)
**Researched:** 2026-09-01
**Confidence:** MEDIUM-HIGH (Win32 DWM APIs + media_kit internals verified against primary source; Win10 accent-border path and DWMWA_TRANSITIONS_FORCEDISABLED need real-hardware spike)

## Executive Summary

Simple Player is a Flutter desktop media player on media_kit/libmpv that is already frameless, already runs a working media_kit fullscreen chain, and already fixed its fullscreen edge-seam (C1 NCCALCSIZE 8px inset) and icon-stuck bug (C2 WindowMode single source of truth). The v1.1 milestone is not a rebuild — it is four surgical window-chrome fixes layered on top of those shipped invariants: (1) suppress the DWM accent-color border, (2) make corners match OS convention, (3) eliminate fullscreen enter/exit flicker, (4) make title-bar drag reliably follow the pointer. Experts build this the same way Windows Terminal, VLC, and VS Code do: let the OS do what it can (Win11 native DWM corner + border-color attributes), accept what it can't (Win10 square corners, no `DWMWA_BORDER_COLOR`), and drive the native modal drag loop (`HTCAPTION`) instead of reimplementing it in Dart.

The recommended approach is overwhelmingly a **runner-C++ + thin window_bridge** effort, not a new framework. The cleanest fix for Win11 is one `DwmSetWindowAttribute(DWMWA_BORDER_COLOR, DWMWA_COLOR_NONE)` call plus `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND`, set in a new `ApplyChromeAttributes(HWND)` helper at window creation and re-asserted at "settle points" (theme/DPI/mode changes). Flicker-free fullscreen comes from sequencing the existing media_kit chain: hide the title bar instantly on enter, add `SWP_NOCOPYBITS` to the `SetWindowPos` calls, snapshot restore geometry before the transition, and gate a `DWMWA_TRANSITIONS_FORCEDISABLED` spike as the highest-leverage remaining lever. Drag reliability comes from extending the runner's `WM_NCHITTEST` to return `HTCAPTION` for the title-bar band, eliminating the double-async `startDragging` race.

The key risks are all real-hardware-only: (a) the Win10 accent-border has **no clean API** and the four researchers disagree on the right path (see Open Decision below); (b) `DWMWA_TRANSITIONS_FORCEDISABLED` is adjacent to the user's withdrawn-DWMNCRP red line and must be spike-gated, not committed blind; (c) every fullscreen flicker regression and the C1/C2 invariants are invisible in headless tests — only a real-hardware UAT catches them. Mitigation: pin C1 with a regression test + guard comment before any chrome work, treat the three reverted fullscreen approaches (方案A FFI-bridge, 方案B DWM-disable, global DWMNCRP) and `window_manager.setFullScreen` as a hard denylist, and require a real-hardware perf/raster gate before shipping any transparent-window rounding.

### OPEN DECISION — Win10 accent-border fix (researcher disagreement)

The four research files DISAGREE on how to suppress the DWM accent-color border on Windows 10. This is surfaced for the user, not silently resolved.

| Source | Recommendation | Confidence | Caveat |
|--------|----------------|------------|--------|
| STACK.md | Accept the 1px Win10 border, OR strip `WS_THICKFRAME` from `GWL_STYLE` (cascades into media_kit fullscreen heuristic `(style & WS_OVERLAPPEDWINDOW) == 0`) | MEDIUM | `DWMWA_BORDER_COLOR` is Win11 22000+ only; Win10 has no clean DWM API |
| FEATURES.md | Win10 path = `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` + ensure `WS_THICKFRAME` stripped; warns red edge persists if `WS_THICKFRAME` residual remains in the `setAsFrameless` chain | HIGH on root cause | Recommends the withdrawn-family attribute as the Win10 lever |
| ARCHITECTURE.md | `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` + `WM_NCACTIVATE` return 0 as the universal Win10+Win11 fix (loses DWM shadow) | HIGH on integration | **This IS the withdrawn DWMNCRP family** — user red-line "勿重提" |
| PITFALLS.md | Win10 accent border is tied to `WS_THICKFRAME`/DWM caption frame, NOT a DWM color attribute; `DWMWA_BORDER_COLOR` is the wrong tool on Win10; verify on real Win10 before claiming done | HIGH | Does NOT endorse DWMNCRP; treats it as the reverted trap (Pitfall 10) |

**Reconciliation:** ARCHITECTURE.md's recommendation is the withdrawn global-DWMNCRP approach in everything but name. Per the user's hard constraint, any DWMNCRP-family recommendation can only appear as a **targeted variant requiring explicit user re-authorization** — never as the default. The synthesis default for Win10 is therefore STACK.md's pragmatic stance: **accept the 1px accent border on Win10** (the dev box is Win11 26200; Win10 is legacy fallback), with the `WS_THICKFRAME`-strip lever held in reserve as a MEDIUM-confidence option whose cascade into the media_kit fullscreen heuristic must be verified before adoption. The user must explicitly authorize any DWMNCRP variant before it is planned.

### Fullscreen path reconciliation (which chain is actually live)

- `window_manager.setFullScreen()` is a **no-op on frameless windows** — the `is_frameless_` guard at `window_manager.cpp:593` skips the style/resize block. STACK.md and PITFALLS.md confirm this; it is on the denylist (Pitfall 7, #579 regression).
- The **live fullscreen path in this project is the media_kit chain**: `PlayerVideoControls._toggleFullscreen` → `setMode(fullscreen)` (C2 commit, synchronous) → `video.toggleFullscreen()` → `enterFullscreen` pushes a `PageRouteBuilder(Duration.zero)` → `defaultEnterNativeFullscreen` → MethodChannel → `Utils::EnterNativeFullscreen` (`media_kit_video/windows/utils.cc:16`) strips `WS_OVERLAPPEDWINDOW` and `SetWindowPos` to monitor rect. All fullscreen-flicker fixes slot into this chain and the runner's `WM_NCCALCSIZE`/`WM_NCPAINT` handlers, NOT into `window_manager`.
- `DWMWA_TRANSITIONS_FORCEDISABLED` (Vista+, Win10-available) is endorsed by both FEATURES.md and STACK.md as the highest-leverage flicker fix, but flagged MEDIUM confidence pending a real-hardware spike (it is adjacent to the withdrawn DWMNCRP family but is a *different attribute* — it disables transition *animations*, not non-client *rendering*). It is a **spike-gated item**, not a committed plan.

## Key Findings

### Recommended Stack

No new pub dependencies. The "stack" is a set of Win32 DWM attribute APIs, Win32 hit-test techniques, GTK primitives (Linux), and surgical fixes to the existing `window_manager` 0.5.2 + `media_kit` 1.2.6 + runner C++ chain. The only build change is linking `dwmapi.lib` in `windows/CMakeLists.txt`. See STACK.md for full rationale.

**Core technologies:**
- `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` (Win11 22000+) — suppresses DWM accent border surgically, no style cascading — the clean Win11 fix
- `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` (Win11 22000+) — native anti-aliased free rounded corners — Win11 only
- `WM_NCHITTEST → HTCAPTION` in runner C++ — native modal `SC_MOVE` drag loop, zero channel latency — fully eliminates the `startDragging` race
- `SetWindowPos` + `SWP_NOCOPYBITS` + `WM_ERASEBKGND return 1` + `WM_NCPAINT` suppression — flicker-free fullscreen style/size transition in the media_kit chain
- `DWMWA_TRANSITIONS_FORCEDISABLED` (Vista+, spike-gated) — suppresses DWM's own transition animation; highest-leverage remaining flicker lever, MEDIUM confidence pending hardware spike
- `RtlGetVersion` build detection (copy `media_kit_video/windows/utils.cc:85` pattern) — single `DwmCapabilities` probe at startup gates all later attribute calls
- `gtk_window_begin_move_drag` / `xdg_toplevel.set_fullscreen` (Linux) — structural-only, `待实机验证`

**Critical version facts:**
- `window_manager` actual locked version is **0.5.2** (CLAUDE.md's "5.15.0" is a doc typo); `setFullScreen` is a no-op on frameless — do NOT use
- `DWMWA_BORDER_COLOR` (34) and `DWMWA_WINDOW_CORNER_PREFERENCE` (33) are **Win11 build 22000+ only** — `E_INVALIDARG` on Win10; runtime-gate with `RtlGetVersion`, never trust compile-time SDK presence
- `DWMWA_NCRENDERING_POLICY` (DWMNCRP) is **withdrawn by user** — denylist, do NOT re-propose as default

### Expected Features

See FEATURES.md for the full landscape analysis (mpv.net, IINA, VLC, Celluloid, Electron apps, Windows Terminal).

**Must have (table stakes — v1.1 MVP):**
- 去红边 — Win11 `DWMWA_BORDER_COLOR=NONE`; Win10 = OPEN DECISION (accept border vs. `WS_THICKFRAME` strip vs. user-authorized DWMNCRP variant)
- 圆角符合 OS 约定 — Win11 `DWMWCP_ROUND`; Win10 accept square (matches Windows Terminal/VLC/VS Code)
- 全屏进出无闪烁 — instant title-bar hide on enter + `SWP_NOCOPYBITS` + `WM_NCPAINT` suppression + (spike-gated) `DWMWA_TRANSITIONS_FORCEDISABLED`
- 标题栏拖拽必现跟手 + 双击最大化共存 — `HTCAPTION` native hit-test band, excluding resize edges and button cluster

**Should have (differentiators — v1.x):**
- Win11 dark title bar (`DWMWA_USE_IMMERSIVE_DARK_MODE`) — same batch as border, one version-gated call
- Explicit corner-preference setting (round/square) — Win11-only differentiator
- Linux real-hardware verification — structural correctness now, `待实机验证`

**Defer (v2+):**
- macOS window-chrome verification (structural support exists, not a release target)
- Multi-monitor fullscreen geometry restore (v1.0 has self-built FFI base; separate verification)
- Win10 pseudo-round corners via `WS_EX_LAYERED` + `ClipRRect` (anti-feature: video perf tax, black fringes — see Pitfall 5)

**Anti-features (do NOT build):**
- Win10 pseudo-round corners (all mature apps accept square on Win10)
- Global DWMNCRP scheme (withdrawn 2026-08-27)
- Self-drawn fullscreen enter/exit animation (VLC/mpv do instant; animation fights the transition)
- Self-drawn drag via mouse-move + `SetWindowPos` (loses Snap Layout, multi-monitor, DPI, Aero Peek)
- Transparent layered window for Windows rounding (per-pixel composite tax on video)

### Architecture Approach

All four fixes cross the same three layers — **runner C++** (`windows/runner/`), **window_bridge Dart** (`lib/kernel/window_Bridge/`), and **media_kit native fullscreen chain** (`media_kit_video/windows/utils.cc`). The guiding principle: native window appearance (border color, corner radius, frame style, hit-test) belongs in runner C++ alongside C1; window-mode semantics and transition timing belong in window_bridge Dart alongside C2; per-OS capability detection is a C++ responsibility. See ARCHITECTURE.md for the full component-boundary table and the traced fullscreen transition sequence.

**Major components (new + modified):**
1. `ApplyChromeAttributes(HWND)` (NEW, `flutter_window.cpp` or new `chrome_attributes.cpp`) — encapsulates all `DwmSetWindowAttribute` calls; called from `OnCreate` and re-applied at settle-points
2. `GetWindowsBuildNumber()` (NEW, `utils.cpp`) — `RtlGetVersion`-based probe feeding a one-shot `DwmCapabilities` struct
3. `WM_NCHITTEST` extension (`win32_window.cpp:256`) — `HTCAPTION` for title-bar band, after `HitTestWindowEdge` (C1 8px resize) and excluding button cluster; `IsZoomed` guard skips drag when maximized
4. `WindowModeCoordinator._preFullscreenMode` (NEW field) + `syncFullscreenState`/`_setSerialized` modifications — captures pre-fullscreen mode for correct exit restore (Fix C-3)
5. `_TitleBarAnimatedShell` (`custom_title_bar.dart:92`) — instant `Opacity` on fullscreen enter, `AnimatedOpacity` fade on exit only (Fix C-1a)
6. `Utils::EnterNativeFullscreen` / `ExitNativeFullscreen` (`media_kit_video/windows/utils.cc`, red-line lifted for fullscreen) — add `SWP_NOCOPYBITS`; optionally save `GetWindowRect` instead of `rcNormalPosition` (Fix C-2, C-3)

**Load-bearing invariants every fix must respect:**
- **C1** — `WM_NCCALCSIZE` 8px-inset branch in `FlutterWindow::MessageHandler` (`flutter_window.cpp:63-71`); treats the handler as a multi-branch state machine (fullscreen→inset, maximized→overshoot, default→return 0); never collapse to bare `return 0`
- **C2** — `WindowMode` is the only fullscreen signal; all components read `_state.mode.value.isFullscreen`, never `VideoState.isFullscreen`

### Critical Pitfalls

Top pitfalls from PITFALLS.md (see full catalog there):

1. **C1 gap regression** — any edit to `WM_NCCALCSIZE` that collapses the branched handler reopens the fullscreen edge seam. Avoid: pin C1 with a regression test + `// DO NOT REMOVE — C1` guard comment before any chrome work; route border/corner work through DWM attributes, NOT the NCCALCSIZE inset branch.
2. **DWM attributes on Win10 (silent no-op / `E_INVALIDARG`)** — `DWMWA_BORDER_COLOR` and `DWMWA_WINDOW_CORNER_PREFERENCE` are Win11 22000+ only. Avoid: runtime-gate every call with `RtlGetVersion` + check `HRESULT`; one `DwmCapabilities` probe at startup; Win10 border path is the OPEN DECISION above, not a DWM color attribute.
3. **DWM attributes stale after theme/DPI/mode change** — set-once at startup flickers on transitions (the exact trap that killed the reverted global-DWMNCRP). Avoid: re-apply from a single `applyChromeAttributes()` at startup, `WM_THEMECHANGED`, `WM_DPICHANGED`, and the fullscreen "settle point" (post-`WM_SIZE` final geometry), never mid-transition.
4. **Fullscreen flicker (4 independent root causes)** — texture rebuild, resize ordering, animation-vs-transition fight, wrong restore geometry. Avoid: snapshot geometry *before* transition; sequence enter as hide-chrome→snapshot→native resize→wait-settle→re-apply attrs→reveal-chrome; gate all `Animated*` on chrome with `isFullscreenTransition` flag; probe `textureIdChanges=0` during toggle.
5. **Re-proposing a reverted approach** — 方案A (FFI-bridge), 方案B (DWM-disable / `DWMWA_NCRENDERING_POLICY`), global DWMNCRP, and `window_manager.setFullScreen` are all on the denylist. Avoid: Phase 4 design doc opens with a "Reverted Approaches Registry"; any fullscreen PR must cite why it is NOT one of these; re-consideration requires a real-hardware pilot + documented delta addressing the specific failure.

## Implications for Roadmap

Based on the combined research, the four fixes have a strict dependency chain: capability detection + C1/C2 pinning must precede everything; border/corner share the same `ApplyChromeAttributes` helper; drag must land before fullscreen-transition work (both touch `WM_NCHITTEST`); fullscreen-flicker is the capstone because it touches all three layers and requires the media_kit red-line lift. Suggested six phases:

### Phase 1: Capability Detection + C1/C2 Pinning
**Rationale:** Every later phase consumes the `DwmCapabilities` probe and must not regress C1/C2. Pinning first means every subsequent phase has a guardrail. PITFALLS.md maps Pitfalls 1, 2, 3, 9 prevention here.
**Delivers:** `GetWindowsBuildNumber()` + `DwmCapabilities` probe (borderColor/cornerPreference/captionColor/textColor/systemBackdrop booleans, recorded once at startup); C1 regression test + `// DO NOT REMOVE` guard comment on the NCCALCSIZE inset branch; Linux compositor detection (Wayland/X11/gamescope).
**Addresses:** Features = none directly (enabler); Pitfalls = 1 (C1), 2 (maximized overshoot probe), 3 (Win10 no-op), 9 (Linux probe).
**Avoids:** C1 gap regression; Win11-only attributes called on Win10.

### Phase 2: Accent Border Removal (Win11 path) + Win10 OPEN DECISION
**Rationale:** Self-contained runner-C++ change; establishes `ApplyChromeAttributes` helper that Phase 3 reuses. Win11 path is HIGH confidence. Win10 path is the OPEN DECISION — plan it as a user-authorized fork: default = accept border; optional = `WS_THICKFRAME` strip with cascade verification; DWMNCRP variant only if user explicitly re-authorizes.
**Delivers:** `ApplyChromeAttributes(HWND)` calling `DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE` on Win11 22000+; `WM_NCACTIVATE return 0` in both handlers (纵深防御); re-apply hooks on `WM_THEMECHANGED` / `WM_DPICHANGED`.
**Addresses:** Features = 去红边 (Win11 HIGH, Win10 OPEN DECISION); Pitfalls = 3, 4.
**Avoids:** DWMNCRP denylist (Phase 5 gate enforces); set-once staleness.

### Phase 3: Rounded Corners (Win11 native, Win10 square)
**Rationale:** Reuses `ApplyChromeAttributes` + `GetWindowsBuildNumber` from Phase 2. Pure additive on Win11; Win10 no-op (accept square per research conclusion). No Dart changes if pseudo-round is deferred (recommended).
**Delivers:** `DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND` on Win11; Win10 square (documented divergence); Linux structural path (`ClipRRect` fallback if borderless, `待实机验证`).
**Addresses:** Features = 圆角符合 OS 约定; Pitfalls = 5 (no `WS_EX_LAYERED`).
**Avoids:** Transparent-window perf tax on video; black fringes.

### Phase 4: Title-Bar Drag Reliability
**Rationale:** Must land BEFORE fullscreen-flicker work — both touch `WM_NCHITTEST`, and drag's `HTCAPTION` band must be stable before Phase 5 adds `WM_NCPAINT` suppression. Drag does not depend on the media_kit red-line lift, so it can ship independently.
**Delivers:** `WM_NCHITTEST` returns `HTCAPTION` for title-bar band (after `HitTestWindowEdge`, excluding button cluster + `IsZoomed` guard); `kTitleBarHeight` / `kTitleBarButtonAreaWidth` constants; conditional disable of `onPanStart` on Windows (keep `onDoubleTap` for maximize); `Listener.onPointerDown` fallback for non-Windows.
**Addresses:** Features = 标题栏拖拽必现跟手 + 双击最大化共存; Pitfalls = 8.
**Avoids:** Anti-Pattern 4 (HTCAPTION without excluding resize edges); gesture-arena no-op.

### Phase 5: Flicker-Free Fullscreen Transition (capstone — highest risk)
**Rationale:** Touches all three layers (runner C++, window_bridge Dart, media_kit C++) and requires the media_kit red-line lift. Depends on Phase 1 (probe), Phase 2 (settle-point re-apply), Phase 4 (HTCAPTION stable). Each sub-fix (C-1, C-2, C-3) can be done and verified independently. Opens with the Reverted Approaches Registry denylist.
**Delivers:**
- C-1a: `_TitleBarAnimatedShell` instant `Opacity` on enter, fade on exit (`custom_title_bar.dart:92`)
- C-2: `SWP_NOCOPYBITS` added to `EnterNativeFullscreen`/`ExitNativeFullscreen` `SetWindowPos` (media_kit red-line lifted); `WM_NCPAINT return 0` in `FlutterWindow::MessageHandler` when `WS_OVERLAPPEDWINDOW` absent
- C-3: `_preFullscreenMode` field in `WindowModeCoordinator`; restore to pre-fullscreen mode (maximized vs windowed) on exit instead of always windowed
- Spike-gated: `DWMWA_TRANSITIONS_FORCEDISABLED` real-hardware pilot — adopt only if the spike passes the raster/visual gate
**Addresses:** Features = 全屏进出无闪烁; Pitfalls = 6, 7, 10.
**Avoids:** Anti-Pattern 3 (reordering transition sequence — keep `setMode` first); re-proposing 方案A/B/DWMNCRP/`wm.setFullScreen`.

### Phase 6: Linux Structural Implementation + Polish
**Rationale:** Linux is `待实机验证` only; structural correctness can be delivered without hardware. Bundles the Win11 dark-title-bar differentiator (`DWMWA_USE_IMMERSIVE_DARK_MODE`, same batch as Phase 2/3 attributes) and optional corner-preference setting.
**Delivers:** Linux compositor-branched paths (Wayland `xdg_toplevel.set_fullscreen`, no `setPosition`; X11 existing path; gamescope skip); Win11 dark title bar; optional corner-preference setting.
**Addresses:** Features = Linux structural, Win11 dark title bar, corner-preference differentiator; Pitfalls = 9.
**Avoids:** Wayland global-coordinate assumptions; SSD-vs-CSD compositor divergence.

### Phase Ordering Rationale

- **Probe before chrome** — `DwmCapabilities` + build detection is consumed by Phases 2, 3, 5; building it first prevents Win11-only attributes leaking onto Win10 (Pitfall 3).
- **Border before corners** — both call `ApplyChromeAttributes`; Phase 2 establishes the helper, Phase 3 extends it. `DWMWA_BORDER_COLOR=NONE` + `DWMWCP_ROUND` must be set together for a clean "borderless round" Win11 window.
- **Drag before fullscreen-flicker** — both edit `WM_NCHITTEST`; stabilizing the `HTCAPTION` band first means Phase 5 only adds `WM_NCPAINT` to a known-good handler.
- **Fullscreen-flicker last** — it is the only phase that lifts the media_kit red line, touches all three layers, and carries the reverted-approach denylist. Sequencing it last means every invariant it depends on (C1 pin, probe, settle-point re-apply, stable hit-test) is already in place.
- **Linux + polish after** — Linux is structural-only (`待实机验证`); the Win11 dark-title-bar differentiator is a one-line addition to the same `ApplyChromeAttributes` helper and bundles cleanly here.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Win10 OPEN DECISION):** the Win10 accent-border path is unresolved — `/gsd-plan-phase --research-phase 2` should center on (a) confirming whether `WS_THICKFRAME` residual exists in the `setAsFrameless` chain, (b) cascade effect of `WS_THICKFRAME` strip on the media_kit fullscreen heuristic, (c) user authorization gate for any DWMNCRP variant.
- **Phase 5 (Fullscreen flicker):** the `DWMWA_TRANSITIONS_FORCEDISABLED` spike is MEDIUM confidence and adjacent to the withdrawn family — `/gsd-plan-phase --research-phase 5` should include a real-hardware spike plan (enter/exit on Win10 + Win11, raster gate <33ms, visual gate no single-frame flicker) BEFORE committing the attribute to the plan.
- **Phase 6 (Linux):** Wayland compositor branching has no real hardware — `/gsd-plan-phase --research-phase 6` should validate the structural branches against `window_manager`'s Linux plugin source and document the `待实机验证` contract.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Probe + C1 pin):** well-documented `RtlGetVersion` pattern (copy `media_kit_video/windows/utils.cc:85`); C1 pin is a regression test on an existing invariant.
- **Phase 3 (Win11 corners):** single `DwmSetWindowAttribute` call, HIGH confidence, verified on Microsoft Learn.
- **Phase 4 (Drag):** `HTCAPTION` is a textbook Win32 pattern; the only novelty is the button-cluster exclusion rect, which is arithmetic.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Win32 DWM APIs + window_manager/media_kit internals verified against Microsoft Learn + pub-cache source. Win10 border path is the OPEN DECISION (MEDIUM). |
| Features | HIGH | Win11 path + table stakes verified against primary docs + competitor behavior (Windows Terminal/VLC/VS Code canonical). Win10 border feature is the disagreement. |
| Architecture | HIGH | Integration points verified by reading actual project source (`flutter_window.cpp`, `win32_window.cpp`, `window_mode_coordinator.dart`, `media_kit_video/utils.cc`). C1/C2 invariants load-bearing and documented. |
| Pitfalls | HIGH | Win32/window_manager pitfalls verified against issue tracker (#579, #531, #367, #181, #266, #399, #511, #203) + project memory. Linux/gpu-texture pitfalls MEDIUM (no hardware). |

**Overall confidence:** MEDIUM-HIGH — the Win11 path and architecture integration are HIGH confidence; the Win10 accent-border OPEN DECISION and the `DWMWA_TRANSITIONS_FORCEDISABLED` spike drag the overall to MEDIUM-HIGH.

### Gaps to Address

- **Win10 accent-border path (OPEN DECISION):** cannot be resolved in research — needs user authorization on which fork (accept border / `WS_THICKFRAME` strip / DWMNCRP variant) before Phase 2 planning can finalize.
- **`DWMWA_TRANSITIONS_FORCEDISABLED` real-hardware spike:** MEDIUM confidence, adjacent to the withdrawn DWMNCRP family — must be spike-gated in Phase 5 before commitment.
- **Linux real-hardware verification:** all Linux chrome deliverables are `待实机验证` — structural correctness only; Wayland compositor branching (Mutter/wlroots/gamescope) cannot be confirmed without hardware.
- **C1 regression visibility:** the fullscreen edge-seam is invisible in headless tests (DWM-composition visual) — Phase 1 must ship a real-hardware UAT contract, not just a widget assertion.
- **media_kit limited maintenance (GitHub #1337):** upstream will not fix fullscreen texture issues promptly; the project owns the fix. Phase 5 must document ownership and not wait on upstream.
- **`window_manager` version doc typo:** CLAUDE.md says 5.15.0; `pubspec.lock` says 0.5.2. Correct the doc (no runtime impact).

## Sources

### Primary (HIGH confidence)
- Microsoft Learn — `DWMWINDOWATTRIBUTE` enum (`dwmapi.h`): `DWMWA_BORDER_COLOR=34`, `DWMWA_COLOR_NONE=0xFFFFFFFE`, `DWMWA_WINDOW_CORNER_PREFERENCE=33`, `DWMWA_CAPTION_COLOR=35`, `DWMWA_TEXT_COLOR=36`, `DWMWA_USE_IMMERSIVE_DARK_MODE=20`, `DWMWA_TRANSITIONS_FORCEDISABLED`, all Win11 22000+ where applicable; `DWMWA_NCRENDERING_POLICY` Vista+ (withdrawn by user).
- Microsoft Learn — `DwmSetWindowAttribute` function, `DWM_WINDOW_CORNER_PREFERENCE` enum, `WM_NCCALCSIZE` message, Layered Windows / DXGI Flip Model / Hardware Overlay docs.
- `media_kit_video-2.0.1/windows/utils.cc` — `EnterNativeFullscreen` / `ExitNativeFullscreen` verbatim source (read from pub cache).
- `media_kit_video-2.0.1/lib/.../methods/fullscreen.dart` — `enterFullscreen`/`exitFullscreen` route-push logic.
- `window_manager` 0.5.2 source (pub-cache) — `StartDragging` native = `ReleaseCapture` + `SendMessage(WM_SYSCOMMAND, SC_MOVE|HTCAPTION)`; `SetFullScreen` `is_frameless_` guard (no-op on frameless); Linux `gtk_window_begin_move_drag`.
- Project source: `windows/runner/flutter_window.cpp`, `win32_window.cpp`, `window_manager_service.dart`, `window_mode_coordinator.dart`, `custom_title_bar.dart`, `player_video_controls.dart` — all read in full.
- Electron BrowserWindow docs — `setAccentColor` "active window border" relationship confirmed.

### Secondary (MEDIUM confidence)
- window_manager GitHub issue tracker — #579 (open regression: title bar not reappearing after fullscreen exit), #531 (frameless fullscreen PR), #367/#389 (earlier fullscreen rewrite + regression), #181/#266 (restore geometry bugs), #399/#511/#372/#203 (drag issues).
- media_kit GitHub #1337 — limited maintenance since Nov 2025; project owns fullscreen/texture fixes.
- flutter/flutter #44136 — engine-level desktop resize jank.
- Win32 drag-technique + Win10 rounded-corners community knowledge (Stack Overflow / Win32 community synthesis), cross-checked against MS Learn semantics.
- Context7 — window_manager `/leanflutter/window_manager`, media_kit `/media-kit/media-kit` (WindowOptions, titleBarStyle, FullscreenInheritedWidget, VideoState).
- Project memory: `project_fullscreen_seam_icon_fix.md` (C1/C2 shipped), `project_fullscreen_style_authority.md` (方案A/B/DWMNCRP reverted), `bugfix_white_border_frameless.md` (frameless + SmartDragToResizeArea origin).

### Tertiary (LOW confidence — needs validation)
- Linux Wayland/gamescope structural branches — no real hardware; `待实机验证`.
- `DWMWA_TRANSITIONS_FORCEDISABLED` real-hardware effect on fullscreen toggle — MEDIUM, spike-gated.
- mpv.net README fetch 404 — WPF+libmpv behavior described from established model, not direct read.

---
*Research completed: 2026-09-01*
*Ready for roadmap: yes — with Win10 accent-border OPEN DECISION flagged for user authorization before Phase 2 planning finalizes.*
