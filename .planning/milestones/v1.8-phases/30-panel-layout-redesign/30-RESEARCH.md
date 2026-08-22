# Phase 30: Panel Layout Redesign - Research

**Researched:** 2026-07-26
**Domain:** Flutter desktop UI — settings overlay sizing / tab reorder / multi-monitor drag clamp
**Confidence:** HIGH (all seams verified against live code; zero external library research needed)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Carried Forward (pre-locked — DO NOT re-litigate):**

- **CF-01 (size formula):** `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]` — 16:9 primary constraint, 50% area secondary (LAYOUT-02, PRODUCT-locked)
- **CF-02 (aspect ratio):** 16:9 primary + 50% area secondary (LAYOUT-01/02)
- **CF-03 (overlay mode):** Centered overlay Stack sibling, NOT standalone window (PROJECT Constraint; standalone-window mode explicitly out of scope)
- **CF-04 (multi-monitor clamp source):** `display_enumerator` work-area FFI, NOT `MediaQuery` (Blocking Constraint; no new deps; memory `project_multi_monitor_ffi` documents EnumDisplayMonitors callback + RECT→Rect + clamp algorithm)
- **CF-05 (General tab position):** General tab at index 3 (4th position, 3+1+3 symmetric) of the 7-tab sequence, NOT first/last (LAYOUT-03, ROADMAP SC#2)
- **CF-06 (tokens only):** All visual values via `Tokens.*`, no hardcoded sizes (PROJECT Constraint; LAYOUT-05 implied)
- **CF-07 (vertical structure color unify target):** Upper/middle/lower vertical structure unified to control-bar color (LAYOUT-05, coordinated with VISUAL-01 — but the Phase 30/31 boundary itself is gray area B, resolved in D-02)
- **CF-08 (always-pause live):** Phase 29 COMPLETE — panel open implies pause + `MediaState._preOpenState` snapshot + 4 sub-race tests. Phase 30 may iterate the panel without racing playback.

**Phase 30 discussion decisions:**

- **D-01 (tab reorder):** Final 7-tab sequence = `[EQ, Audio, Video, General, Shortcuts, About, Performance]` — General moved from position 1 to position 4 (index 3); the other 6 tabs keep their existing relative order. Planner updates the tab list in `tab_strip.dart` AND the `IndexedStack` child order in `tab_content.dart` to match.
- **D-02 (Phase 30/31 boundary):** Phase 30 does **placeholder unification** only — keep existing `bgGlass`, but unify "upper/middle/lower all use the SAME token" at the structural layer; Phase 31 (VISUAL-01) is where the actual switch to `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` happens. Phase 30 must NOT touch `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing`.
- **D-03 (multi-monitor clamp UX):** **Real-time clamping** during drag — the panel edge cannot exceed the current monitor's work-area at any frame (query work-area per drag frame). Matches existing fullscreen snap behavior. Implement in the drag handler of `settings_overlay_shell.dart`, using the existing `display_enumerator` work-area FFI.
- **D-04 (height derivation + breakpoint):** `height = width × 9/16` (strict 16:9, formula self-consistent). **Abandon the Phase 27 800px breakpoint** — `clamp[400, 960]` on width + the 16:9 height derivation is already adaptive across window sizes. SC#5 size-assertion tests re-baseline to this formula. **Reversibility: costly** — undo requires re-baselining SC#5 tests back to `height=width×0.8` + restoring the breakpoint branch logic.
- **D-05 (resize re-clamp, Claude's discretion):** When the window resizes and the panel's current position becomes illegal (outside the new work-area), re-clamp to the new work-area.
- **D-06 (RepaintBoundary, Claude's discretion):** Keep the `RepaintBoundary` that Phase 27 added for the panel. No action needed.

### Claude's Discretion
- D-05 (resize re-clamp) — user may revisit if they disagree.
- D-06 (keep RepaintBoundary) — no action unless Phase 31 rendering audit says otherwise.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAYOUT-01 | 面板比例从 5:4 (clamp 400-600) 改为 16:9 / 占屏约 50% 面积 | Seam 1 verified: `settings_overlay_shell.dart:172-180` replaces `_panelWidth`/`_panelHeight`; tokens at `tokens.dart:230-240` |
| LAYOUT-02 | `width = min(0.5 × screenW, screenH × 16/9)`, clamp `[400, 960]`; 16:9 主约束 | Formula verified self-consistent at 4 window sizes (see Seam 1 re-baseline table); `panelMaxWidth` 600→960 |
| LAYOUT-03 | 通用 tab 移到 tab 序列中间位置 | Seam 2 verified: `tab_strip.dart:36-56` (icons+labels lists) + `tab_content.dart:57-114` (IndexedStack children) + **ripple: `settings_panel_controller.dart:49` open-reset index** |
| LAYOUT-04 | 多显示器拖拽钳制 (`display_enumerator` work-area, 非 `MediaQuery`) | Seam 3 verified: `DisplayEnumerator` interface + `Win32DisplayAdapter` DI pattern exists; drag handler at `settings_overlay_shell.dart:315-330`; needs work-area resolver seam + window-position source |
| LAYOUT-05 | 上中下垂直结构颜色统一为控制栏色 (与 VISUAL-01 协同) | Seam 4 verified: titleBar/tabStrip/buttonBar = `bgGlass`, **content = `bgPanel`** (tab_content.dart:52) — D-02 unifies to `bgGlass` structural layer only |
</phase_requirements>

## Summary

Phase 30 is a **pure in-codebase seam edit** — no new packages, no new FFI, no kernel changes. All five requirements map to four verified code seams, all read line-by-line in this session. The sizing formula change (LAYOUT-01/02) touches 2 static methods and 4 token constants; the tab reorder (LAYOUT-03) touches 2 lists + 1 IndexedStack + **one non-obvious ripple** (`SettingsPanelController.open()` resets `selectedTab` to 0 with the comment "每次打开重置到 General tab" — after the reorder General is index 3, so the reset index must follow or six General-default tests break); the multi-monitor clamp (LAYOUT-04) is the only genuinely new mechanism — the existing `DisplayEnumerator`/`Win32DisplayAdapter` DI pattern is directly reusable, but the shell needs (a) an injectable work-area resolver and (b) a window-screen-position source, neither of which exists in the shell today; the color unification (LAYOUT-05) is a one-line token swap in `tab_content.dart` (`bgPanel` → `bgGlass`).

**Primary recommendation:** Implement as 4 ordered tasks — (1) tokens + sizing formula, (2) tab reorder + controller reset-index ripple, (3) work-area drag clamp with injectable resolver + MediaQuery fallback, (4) structural color unify — then re-baseline the 14 size/drag assertions across 3 test files and the ~8 index-sensitive tab assertions across 2 test files (full inventory below).

**CONTEXT.md drift note:** CONTEXT cites the sizing seam at `§172-179`; actual location is `settings_overlay_shell.dart:172-180` (`_panelWidth` 172-177, `_panelHeight` 179-180). CONTEXT also cites `lib/kernel/bridge/screen_utils.dart` — that file does NOT exist; the real file is `lib/kernel/utils/screen_utils.dart`. Both drifts are cosmetic; seams themselves are as described.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Panel size formula | UI widget (`SettingsOverlayShell`) | Tokens (constants) | Sizing derives from `MediaQuery.sizeOf` — pure view-layer math |
| Tab order | UI widget (`tab_strip` + `tab_content`) | Controller (reset index) | Order is presentation; reset-index is controller policy that must match |
| Work-area clamp | UI widget (drag handler) | Kernel bridge FFI (`DisplayEnumerator`) | FFI already exists in kernel; shell consumes via DI seam, no kernel modification |
| Window position source | `window_manager` package / `WindowService` | — | Screen-coordinate conversion needs window position; currently only async `getPosition()` exists |
| Vertical color unify | Tokens + 4 widget files | — | Single-token structural seam; Phase 31 swaps the token value |

## Standard Stack

**No new packages.** This phase uses only in-tree code + already-declared dependencies (`window_manager`, `ffi`, Flutter SDK). Package Legitimacy Audit: **N/A — zero external packages installed.**

| Existing Asset | Role in Phase 30 |
|----------------|------------------|
| `Tokens.*` (tokens.dart) | All sizing constants live here (CF-06) |
| `DisplayEnumerator` / `Win32DisplayAdapter` | Work-area FFI, already DI-ready (CF-04) |
| `ScreenUtils.clampToNearestMonitor` | Reference clamp algorithm (window-level; panel clamp mirrors its workArea philosophy) |
| `window_manager` (already in pubspec) | `getPosition()` for screen-coordinate conversion (async) |

## Architecture Patterns

### Seam 1: Sizing formula (LAYOUT-01/02) — VERIFIED CURRENT CODE

`lib/ui/dialogs/settings/settings_overlay_shell.dart:172-180`:

```dart
/// 面板宽度 — windowWidth × 0.8，clamp 到 [400, 600]（D-04/D-05）。
static double _panelWidth(double windowWidth) =>
    (windowWidth * Tokens.panelWidthRatio).clamp(
      Tokens.panelMinWidth,
      Tokens.panelMaxWidth,
    );

/// 面板高度 — 宽度 × 0.8 比例，全屏 600×480，小窗口 400×320（D-04 / SC-2/SC-3）。
static double _panelHeight(double width) => width * Tokens.panelHeightRatio;
```

Caller at line 188-190: `final mediaSize = MediaQuery.sizeOf(context); final width = _panelWidth(mediaSize.width); final height = _panelHeight(width);`

**Replacement (D-04):** `_panelWidth` needs the window **height** too — change signature to accept `Size` (or both dims):

```dart
// Target shape (planner writes final code):
static double _panelWidth(Size windowSize) =>
    math.min(
      windowSize.width * Tokens.panelWidthRatio,   // 0.5 — repurpose token value
      windowSize.height * Tokens.panelAspectRatio, // 16/9 — NEW token
    ).clamp(Tokens.panelMinWidth, Tokens.panelMaxWidth); // [400, 960]

static double _panelHeight(double width) => width / Tokens.panelAspectRatio; // = width × 9/16
```

**Formula self-consistency verification (matches CONTEXT `<specifics>` exactly):**

| Window | min(0.5W, H×16/9) | clamp [400,960] | height = W×9/16 |
|--------|-------------------|-----------------|------------------|
| 3840×2160 (4K) | min(1920, 3840)=1920 | 960 | 540 |
| 1920×1080 | min(960, 1920)=960 | 960 | 540 |
| 1366×768 | min(683, 1365.3)=683 | 683 | 384.2 |
| 800×600 | min(400, 1066.7)=400 | 400 | 225 |
| 500×400 | min(250, 711.1)=250 | 400 (min clamp) | 225 |

**Token edits (`lib/ui/theme/tokens.dart:230-240`, "响应式设置面板" section):**

| Token | Current | Target | Action |
|-------|---------|--------|--------|
| `panelMinWidth` | 400.0 | 400.0 | unchanged |
| `panelMaxWidth` | 600.0 | **960.0** | edit value |
| `panelWidthRatio` | 0.8 | **0.5** | repurpose (grep-verified: only shell uses it) |
| `panelHeightRatio` | 0.8 | — | **delete** (replaced by aspect derivation; grep-verified single user) |
| `panelAspectRatio` | — | **16.0/9.0** | NEW (per `.planning/research/04-pitfalls.md` Pitfall 10 prescription) |

Naming note: CONTEXT `<specifics>` suggested `Tokens.panelWidthMin`/`panelWidthMax`, but the **existing** convention is `panelMinWidth`/`panelMaxWidth` — reuse existing names (edit values), do NOT add duplicate-named constants.

**Dead code cleanup opportunity:** `settings_overlay_shell.dart:66-67` still defines `static const double panelWidthRatio = Tokens.panelWidthRatio;` — a leftover alias Phase 27's plan said to remove but never did. Grep-verified zero usages. Delete it in the sizing task.

### Seam 2: Tab reorder (LAYOUT-03) — VERIFIED CURRENT CODE

Current order = `[General(0), EQ(1), Audio(2), Video(3), Shortcuts(4), About(5), Performance(6)]`.

**`tab_strip.dart:36-56`** — two parallel lists drive the strip:

```dart
/// 7 个 tab 图标（对应 General/EQ/Audio/Video/Shortcuts/About/Performance）。
static const _tabIcons = [
  Icons.tune,           // General
  Icons.equalizer,      // EQ
  Icons.headphones,     // Audio
  Icons.videocam,       // Video
  Icons.keyboard,       // Shortcuts
  Icons.info_outline,   // About
  Icons.speed,          // Performance
];
static const _tabLabels = ['通用', '均衡器', '音频', '视频', '快捷键', '关于', '性能'];
```

**`tab_content.dart:55-115`** — `IndexedStack` with 7 explicit `TweenAnimationBuilder` children in the same order, each with a hardcoded index comparison (`end: N == selectedIndex ? 1.0 : 0.0`) and an order-comment (`// Tab N: 通用` etc.).

**D-01 edit:** move the General entries (icon `Icons.tune`, label `'通用'`, `GeneralTab` child) from position 0 to position 3 in all three places; update the 7 index literals and 7 order-comments in `tab_content.dart`; update the order-comment in `tab_strip.dart:36`. Keep the 7-child explicit `IndexedStack` structure and the `TweenAnimationBuilder` wrappers (test constraint documented at `tab_content.dart:8-11`).

**RIPPLE (planner MUST handle):** `settings_panel_controller.dart:46-49`:

```dart
void open() {
  if (state.isOpen.value) return;
  // D-03: 每次打开重置到 General tab（index 0）
  state.selectedTab.value = 0;
```

After reorder, index 0 = EQ. Existing behavior is "panel opens on General tab" — to preserve it, the reset must become index 3. **Recommendation:** promote a named constant (e.g. `static const int defaultTabIndex = 3;` on `SettingsPanelController` or a shared `SettingsTabs.general` index constant imported by strip/content/controller) so the index 3 appears exactly once and Phase 32+ refactors don't re-litigate. Six tests in `settings_tab_content_test.dart` depend on open-lands-on-General (see test inventory).

Order-agnostic (no change needed): `nextTab`/`prevTab` modulo arithmetic (`tabCount = 7`), `panel_key_bindings.dart` (pure index cycling).

### Seam 3: Multi-monitor drag clamp (LAYOUT-04) — VERIFIED + DESIGN GAP IDENTIFIED

**Current drag handler** (`settings_overlay_shell.dart:315-330`) — window-relative symmetric clamp via MediaQuery:

```dart
void _onDragUpdate(DragUpdateDetails details, Size mediaSize, Size panelSize) {
  final current = _controller.state.dragOffset.value;
  final next = current + details.delta;
  final maxX = ((mediaSize.width - panelSize.width) / 2).clamp(0.0, double.infinity);
  final maxY = ((mediaSize.height - panelSize.height) / 2).clamp(0.0, double.infinity);
  _controller.state.dragOffset.value = Offset(
    next.dx.clamp(-maxX, maxX),
    next.dy.clamp(-maxY, maxY),
  );
}
```

**Existing FFI (CF-04, verified):** `lib/kernel/bridge/display_enumerator.dart` —

```dart
abstract class DisplayEnumerator {
  List<DisplayInfo> enumerateDisplays();        // sync
  DisplayInfo? getDisplayForWindow(int hwnd);   // sync
  DisplayInfo? getCurrentDisplay();             // sync — FindWindowW(FLUTTER_RUNNER_WIN32_WINDOW) + MonitorFromWindow + GetMonitorInfoW
}
// DisplayInfo{ bounds, workArea, isPrimary } — all Flutter logical pixels (DPR-converted in _rectToFlutter)
```

`Win32DisplayAdapter` (win32_display_enumerator.dart:248-260) is the DI-ready instance wrapper — its own doc comment says "enables testability (mock DisplayEnumerator in tests)". **Headless-test behavior:** `getCurrentDisplay()` returns `null` when `FindWindowW` finds no Flutter window (test env) — natural fallback path. `user32.dll` loads fine on Windows headless (unlike mdk.dll), so no new test-env hazard.

**The gap — window screen position:** converting work-area (screen coords) into dragOffset bounds (window-center-relative) requires the window's screen position:

```
panelCenterScreen = windowPos + windowSize/2 + dragOffset
constraint: workArea.left + panelW/2 ≤ panelCenterScreen.dx ≤ workArea.right − panelW/2
→ dragOffset.dx ∈ [workArea.left + panelW/2 − windowPos.dx − windowW/2,
                   workArea.right − panelW/2 − windowPos.dx − windowW/2]
```

No synchronous window-position source exists today: `WindowBridge` has no position getter (grep-verified); `WindowService` uses `windowManager.getPosition()` (async) only in `_saveGeometry`; `WindowService` does NOT implement `onWindowMoved`. **Two viable sources (planner picks one):**

| Option | Mechanism | Tradeoff |
|--------|-----------|----------|
| A. Drag-session cache | `await windowManager.getPosition()` at `onPanStart` (or panel open), cache for the drag session; `getCurrentDisplay()` per drag frame (sync FFI, cheap) | Self-contained in shell; first drag frame may use fallback clamp (negligible); no kernel touch |
| B. Position cache on WindowService | Add `onWindowMoved` listener + `ValueNotifier<Offset> windowPosition` to WindowService, expose existing `_displayEnumerator` getter | Always-fresh position; touches kernel bridge (additive, not a new dep — allowed by Blocking Constraints which only forbid new deps, but widens blast radius) |

**Recommendation: Option A** — smallest blast radius, keeps shell testable, and per-frame work-area query (D-03) is satisfied via the sync `getCurrentDisplay()` FFI.

**Injectable seam for tests (required):** add optional ctor params to `SettingsOverlayShell`, e.g. `DisplayEnumerator? displayEnumerator` (default `null` → production path constructs `Win32DisplayAdapter` internally OR falls back). When resolver returns null (headless test / FFI failure), **fall back to the current symmetric MediaQuery clamp** — this keeps all 10 existing test files constructible with zero ctor changes and satisfies the project's "graceful fallback" convention. Wiring point already exists: `player_screen.dart:303-306` passes `widget.windowService.isResizing`; adding one more optional param is trivial.

**D-05 resize re-clamp:** shell rebuilds on `MediaQuery` change; add a `didChangeDependencies` (or post-frame) check — when `mediaSize` changes, re-evaluate `dragOffset` against the new clamp bounds and write back the clamped value if illegal. Self-contained in the shell.

### Seam 4: Vertical structure color unify (LAYOUT-05, D-02 boundary) — VERIFIED CURRENT STATE

| Section | File:Line | Current color token |
|---------|-----------|---------------------|
| Upper (title bar) | `settings_overlay_shell.dart:286` | `Tokens.bgGlass` |
| Tab strip | `tab_strip.dart:72` | `Tokens.bgGlass` |
| **Middle (content)** | **`tab_content.dart:52`** | **`Tokens.bgPanel`** ← the outlier |
| Lower (button bar) | `settings_overlay_shell.dart:242` | `Tokens.bgGlass` |

D-02 structural unification = make all four read the **same** token, keeping `bgGlass` as the value. Minimal edit: `tab_content.dart:52` `color: Tokens.bgPanel` → `Tokens.bgGlass`. **Recommended alternative (planner's choice):** introduce `Tokens.panelSectionBg = Tokens.bgGlass` in the 响应式设置面板 token section and point all four sections at it — creates the single swap-route Phase 31 (VISUAL-01/05) will need, at zero extra cost now. Do NOT touch `controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` (Phase 31 scope).

### Anti-Patterns to Avoid

- **Parallel clamp mechanism:** do NOT build a second work-area query path — D-03/CONTEXT `<specifics>` explicitly says reuse the same `display_enumerator` path as fullscreen snap, not a parallel mechanism.
- **Hardcoded 960/400/16-9 literals in shell:** CF-06 — all constants via `Tokens.*`.
- **`List.generate` collapse of the IndexedStack:** test constraint (`tab_content.dart:8-11`) requires 7 explicit children.
- **Silent FFI failure:** project convention — catch with `debugPrint` + graceful fallback, never `catch (_) {}` (note: existing `win32_display_enumerator.dart:222` has a `catch (_) { return 1.0; }` in `_getDevicePixelRatio` — pre-existing, out of scope, do not replicate the pattern in new code).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Monitor enumeration | New FFI / `win32` package | `Win32DisplayAdapter` (existing) | CF-04: EnumDisplayMonitors + DPR conversion + error logging already battle-tested (Phase 14/v1.7) |
| Work-area clamp math | Custom off-screen detection | Mirror `ScreenUtils._clampToArea` philosophy | Existing algorithm handles monitor-disconnect, nearest-display fallback |
| Tab state | Second notifier for order | Reorder the two const lists + IndexedStack children | `selectedTab` stays single-owner; order is pure presentation |

**Key insight:** every mechanism this phase needs already exists in-tree; the only genuinely new code is the dragOffset↔workArea coordinate conversion (~15 lines) and the resize re-clamp hook.

## Common Pitfalls

### Pitfall 1: open()-reset-index ripple (found this session — NOT in CONTEXT.md)
**What goes wrong:** Planner reorders tabs but leaves `state.selectedTab.value = 0` in `open()`. Panel now opens on EQ, and 6 General-default tests break (`settings_tab_content_test.dart` lines 50, 192, 205, 256, 271, 287).
**How to avoid:** Reset to the General index (3) via a named constant; update the `// D-03: 每次打开重置到 General tab（index 0）` comment.
**Warning signs:** `settings_overlay_shell_test.dart:354` ('default selected tab is index 0 （通用）') fails.

### Pitfall 2: 16:9 vs 50%-area constraint conflict (from research/04-pitfalls.md Pitfall 10)
**What goes wrong:** 50% screen AREA ≠ 50% width; on non-16:9 monitors the two constraints conflict.
**How to avoid:** Already resolved by PRODUCT lock CF-01/CF-02: 16:9 primary, 50% secondary. `width = min(0.5×screenW, screenH×16/9)` implements exactly this. Do not "fix" the math to chase 50% area.

### Pitfall 3: Test re-baseline misses a file (headline risk per ROADMAP Risk Profile)
**What goes wrong:** Size assertions live in **three** test files, not two (CONTEXT names only two). Full inventory in Validation Architecture below — 14 size/drag assertions + ~8 index-sensitive assertions.
**How to avoid:** Planner copies the inventory tables below into the plan's acceptance criteria verbatim.

### Pitfall 4: "Abandon the 800px breakpoint" misread as deleting tab-compact mode
**What goes wrong:** D-04 says "abandon the Phase 27 800px breakpoint". In live code the 800px breakpoint (`Tokens.breakpointResponsive`, shell line 191) drives **tab-strip compact/normal switching only** (font 12↔14, spacing 8↔16, height 56↔64) — there is **no 800px sizing branch** in `_panelWidth`/`_panelHeight` (Phase 27 landed pure ratio+clamp). Deleting `breakpointResponsive` would break 5 compact-mode tests that SC#5 requires to stay green.
**How to avoid:** Interpret D-04 as "the new sizing formula has no breakpoint branch" (trivially true — `min+clamp` replaces ratio+clamp) and **keep** `breakpointResponsive` untouched. Flagged as Assumption A2 for user confirmation.

### Pitfall 5: Headless FFI assumption for drag tests
**What goes wrong:** Planner wires `getCurrentDisplay()` directly with no fallback; in `flutter test` (no real Flutter window) `FindWindowW` returns 0 → null → crash or unclamped drag.
**How to avoid:** Null display info → fall back to existing symmetric MediaQuery clamp. This is also what keeps the existing 'Drag Bounds' tests meaningful.

## Code Examples

### Re-baselined size math (reference for test assertions)

```
1920×1080 → 960×540   (was 600×480)
800×600   → 400×225   (was 600×480 — old formula clamped width to 600!)
500×400   → 400×225   (was 400×320)
625×500   → 400×225   (was 500×400)
600×400   → 400×225   (was 480×384)
480×360   → 400×225   (was 400×320)
1200×800  → 600×337.5 (was 600×480) → drag maxY becomes (800−337.5)/2 = 231.25
```

### Work-area clamp conversion (target pattern, ~15 lines)

```dart
// In _onDragUpdate, when workArea + windowPos are available:
// dragOffset bounds derived from workArea (screen coords) minus window frame
final minDx = workArea.left + panelW / 2 - windowPos.dx - mediaSize.width / 2;
final maxDx = workArea.right - panelW / 2 - windowPos.dx - mediaSize.width / 2;
final minDy = workArea.top + panelH / 2 - windowPos.dy - mediaSize.height / 2;
final maxDy = workArea.bottom - panelH / 2 - windowPos.dy - mediaSize.height / 2;
// else: fall back to existing symmetric clamp
```

## State of the Art

| Old Approach (Phase 27) | Current Approach (Phase 30) | When Changed | Impact |
|------------------------|------------------------------|--------------|--------|
| `width×0.8` clamp [400,600], `height=width×0.8` (5:4) | `min(0.5W, H×16/9)` clamp [400,960], `height=width×9/16` | This phase | Panel gets ~60% wider at 1080p (600→960), shorter (480→540 vs 480... net area 288000→518400 px²) |
| General first in tab strip | General at index 3 (3+1+3 symmetric) | This phase | Muscle memory preserved for other 6 tabs (D-01) |
| MediaQuery symmetric drag clamp | workArea real-time clamp + MediaQuery fallback | This phase | Panel can't cross onto non-primary monitor bezel gap |

**Deprecated by this phase:** `Tokens.panelHeightRatio` (0.8) — superseded by `panelAspectRatio` derivation.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `open()` should keep "opens on General tab" semantics → reset index becomes 3 (not literal 0) | Seam 2 / Pitfall 1 | If user intended "opens on first tab (EQ)", 6 tests re-baseline differently; behavior change users will notice |
| A2 | D-04 "abandon 800px breakpoint" = no sizing breakpoint branch (trivially true); `breakpointResponsive` tab-compact switching STAYS | Pitfall 4 | If user intended deleting compact tab mode, 5 more tests re-baseline and small-window UX regresses |
| A3 | Option A (drag-session `windowManager.getPosition()` cache) is acceptable vs Option B (WindowService position notifier) | Seam 3 | If sub-frame position freshness matters (user drags panel while window itself moves), clamp lags one drag session |
| A4 | CONTEXT `<specifics>` token names `panelWidthMin/Max` yield to existing `panelMinWidth/MaxWidth` convention | Seam 1 | Cosmetic only |

## Open Questions

1. **Named constant home for tab indices** — `SettingsTabs.general = 3` style enum/constants class, or a `defaultTabIndex` const on the controller?
   - What we know: index 3 will be referenced by strip, content (7 literals), controller reset, and tests.
   - Recommendation: planner introduces ONE named constant and references it everywhere; document in plan.

2. **`Tokens.panelSectionBg` alias vs direct `bgGlass` swap for D-02** — alias creates Phase 31's swap route for free; direct swap is one less token.
   - Recommendation: alias (cheap, forward-compatible with VISUAL-05).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | build/test | ✓ | `D:/flutter/bin/flutter` (not on PATH — use full path, per STATE.md) | — |
| `flutter test` (headless) | SC#5 re-baseline | ✓ with caveat | ~57 pre-existing mdk.dll FFI failures in engine/kernel tests + 4 dialogs pre-existing failures —鉴别方法: stash + re-run baseline (memory: `reference_mdk_dll_headless_test_failures`) | module-boundary judgment (Phase 30 touches only `lib/ui/dialogs/settings/` + `tokens.dart`) |
| user32.dll FFI | work-area query | ✓ | Always present on Windows; headless returns null display → fallback path | MediaQuery symmetric clamp |
| Real multi-monitor Windows display | LAYOUT-04 manual verify | ⚠ user environment | Single-display 4K per user preferences memory | Automated tests use fake DisplayEnumerator; multi-monitor bezel-gap behavior needs manual or fake-injected verification |

**Missing dependencies with no fallback:** none for automated work. Multi-monitor physical verification is manual-only (user has single display).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK-bundled) |
| Config file | none (defaults) |
| Quick run command | `D:/flutter/bin/flutter test test/ui/dialogs/ --plain-name "settings"` |
| Full suite command | `D:/flutter/bin/flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAYOUT-01/02 | 16:9 formula + clamp at 4+ window sizes | widget | re-baseline SC-1/SC-2/SC-3 in `settings_responsive_integration_test.dart:357-424` + 5 tests in `settings_responsive_scaling_test.dart:44-139` + 4 tests in `settings_overlay_shell_test.dart:141-284` | ✅ re-baseline |
| LAYOUT-03 | General at index 3 | widget | new assertion (nav item 3 label == '通用', open lands on index 3); re-baseline index-sensitive tests (inventory below) | ❌ new + ✅ re-baseline |
| LAYOUT-04 | work-area clamp per drag frame | widget w/ fake DisplayEnumerator | inject fake resolver returning a workArea smaller than window; drag beyond → assert clamped to workArea bounds; null resolver → assert fallback symmetric clamp | ❌ Wave 0 (new tests) |
| LAYOUT-05 | all 4 sections same token | widget | assert `ColoredBox`/`Container` colors of title/tab/content/buttonBar all == `Tokens.bgGlass` (or `panelSectionBg`) | ❌ Wave 0 (new test) |
| SC#5 | tab-strip tests stay green | widget | `settings_tab_content_test.dart` + focus nav + key bindings suites | ✅ re-baseline indices |

### Re-baseline inventory — size/drag assertions (14 total, 3 files)

| File:Line | Test | Old assert | New assert |
|-----------|------|-----------|------------|
| settings_responsive_integration_test.dart:357 | SC-1 three sizes | 600/600/400 | 960/400/400 (1920×1080→960; 800×600→400; 500×400→400) |
| :389 | SC-2 fullscreen 600×480 | 600×480 | **960×540** |
| :408 | SC-3 small 400×320 | 400×320 | **400×225** |
| :214/:236 | Drag bounds 1200×800 | maxY=160 | maxY=231.25 (dy clamp assert 160→**200**) |
| settings_responsive_scaling_test.dart:45/:63/:82 | width clamps | 600/400/600 | 960/400/400 |
| :101 | height 600×480 | 600×480 | 960×540 |
| :121 | height 400×320 | 400×320 | 400×225 |
| settings_overlay_shell_test.dart:141 | drag 800×600 maxX=100/maxY=60 | 100/60 | panel 400×225 → maxX=**200**, maxY=**187.5** |
| :178 | drag 480×360 | maxX=40/maxY=20 | maxX=40, maxY=**67.5** |
| :249 | 625×500 → 500×400 | 500×400 | **400×225** |
| :269 | 600×400 → 480×384 | 480×384 | **400×225** |

### Re-baseline inventory — tab-index-sensitive assertions (~8, 2 files)

| File:Line | Test | Required change |
|-----------|------|-----------------|
| settings_tab_content_test.dart:50 | 'GeneralTab (index 0)' | rename; passes if A1 (reset→3) |
| :65, :218 | EQ at(1) | tap **at(0)** |
| :86, :236 | Audio at(2) | tap **at(1)** |
| :107, :333 | Video at(3) | tap **at(2)**; keep-alive assert index 3→**2** |
| settings_overlay_shell_test.dart:354 | 'default tab is index 0 （通用）' | assert selectedTab == **3** (per A1) |
| :388 | 'clicking tab index 3 （视频）' | now index 3 = 通用； retarget to at(2) for 视频 |
| :406 | 'resets selectedTab to 0' | assert reset to **3** |
| settings_responsive_scaling_test.dart:241 | 'all 7 tab labels visible' | label list order-independent — stays green ✓ |

Stays green (relative arithmetic only): arrow/LB/RB cycling tests, focus navigation tests, 'IndexedStack index matches selectedTab' (taps at(2), asserts 2 — but semantic changes from 音频→视频; assertion still passes, comment stale).

### Sampling Rate
- **Per task commit:** `D:/flutter/bin/flutter test test/ui/dialogs/` (dialogs subset, ~130 tests, <30s)
- **Per wave merge:** `D:/flutter/bin/flutter test` (full suite; expect 2361 pass + ~68 pre-existing failures per Phase 28 baseline — 鉴别: stash + re-run)
- **Phase gate:** dialogs subset green + full suite no NEW failures vs stashed baseline

### Wave 0 Gaps
- [ ] Fake `DisplayEnumerator` test double (hand-written fake per project convention "Fakes over mocks") returning configurable `DisplayInfo` — needed by LAYOUT-04 tests
- [ ] New test: work-area clamp active during drag (fake resolver)
- [ ] New test: fallback to symmetric clamp when resolver null
- [ ] New test: LAYOUT-05 four-section token unification assertion
- [ ] New test: D-05 resize re-clamp (pump at size A with dragOffset, re-pump at smaller size B, assert dragOffset re-clamped)

## Security Domain

No new ASVS surface: pure UI layout change. V5 Input Validation applies trivially — drag deltas come from Flutter gesture system (trusted); FFI workArea rects consumed from existing audited path. No auth/session/crypto/file-system changes. `security_enforcement` threat-model gate: LOW risk, no `<threat_model>` content beyond this note expected.

## Sources

### Primary (HIGH confidence) — all verified by direct file reads this session
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` (full read) — sizing seam 172-180, drag handler 315-330, decoration sites 242/286, dead alias 66-67
- `lib/ui/dialogs/settings/tab_strip.dart` (full read) — tab lists 36-56
- `lib/ui/dialogs/settings/tab_content.dart` (full read) — IndexedStack 55-115, `bgPanel` outlier :52
- `lib/ui/dialogs/settings/settings_panel_controller.dart` (full read) — open-reset :49, tabCount :38
- `lib/ui/theme/tokens.dart` (full read) — responsive section 230-248
- `lib/kernel/bridge/display_enumerator.dart` + `win32/win32_display_enumerator.dart` (full reads) — sync FFI interface, adapter DI pattern, headless-null behavior
- `lib/kernel/bridge/window_service.dart` (full read) — no position cache / no onWindowMoved
- `lib/kernel/utils/screen_utils.dart` (full read) — clamp algorithm reference (NOTE: CONTEXT.md cited wrong path `bridge/screen_utils.dart`)
- Test files: `settings_responsive_integration_test.dart`, `settings_responsive_scaling_test.dart`, `settings_tab_content_test.dart` (full reads); `settings_overlay_shell_test.dart`, `settings_focus_navigation_test.dart` (grep-targeted reads)
- `.planning/research/04-pitfalls.md` Pitfall 10 (lines 182-198) — pre-existing formula prescription matching CF-01
- `.planning/research/03-architecture.md` v4.5 Migration Map (lines 111-123)

### Secondary (MEDIUM confidence)
- Memory: `reference_mdk_dll_headless_test_failures` — pre-existing failure baseline + stash鉴别 method
- Memory: `project_multi_monitor_ffi` — EnumDisplayMonitors pattern documentation

### Tertiary (LOW confidence)
- None — no web sources used; all claims trace to in-repo code/docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new packages; all assets grep/read-verified
- Architecture: HIGH — all 4 seams read line-by-line; CONTEXT line-number drift corrected
- Pitfalls: HIGH — Pitfall 1 (open-reset ripple) and test inventory derived from live test files, not CONTEXT summaries
- Remaining uncertainty: A1/A2/A3 assumptions (user-confirmable, low blast radius)

**Research date:** 2026-07-26
**Valid until:** 2026-08-25 (stable — in-codebase seams only; invalidate on any Phase 31 early start or shell refactor)
