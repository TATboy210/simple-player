---
phase: 30
slug: panel-layout-redesign
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-26
---

# Phase 30 — UI Design Contract

> Visual and interaction contract for the settings panel layout refactor (LAYOUT-01..05).
> This phase is a **layout refactor, not a visual redesign** — typography, color values,
> spacing scale, and all copy are inherited unchanged from the existing `Tokens.*` system.
> Only panel geometry, tab order, drag-clamp behavior, and structural color routing change.
> All 8 CF + 6 D decisions from `30-CONTEXT.md` are pre-locked constraints, not open questions.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (custom `Tokens.*` design system, `lib/ui/theme/tokens.dart`) |
| Preset | not applicable — Flutter desktop project; shadcn gate skipped (not React/Next/Vite) |
| Component library | Flutter Material + project glass widgets (`GlassContainer`, `GlassButton`, `SettingsNavItem`) |
| Icon library | Material Icons (`Icons.*`) |
| Font | `Tokens.fontFamily` = SF Pro Display (Windows fallback Segoe UI); mono `Tokens.fontFamilyMono` = SF Mono |

**Theme:** Midnight (single compile-time const theme). All visual values via `Tokens.*` — hardcoded literals are a contract violation (CF-06).

---

## Spacing Scale

Declared values (existing `Tokens.*`, all multiples of 4 — **no new spacing values this phase**):

| Token | Value | Usage |
|-------|-------|-------|
| `Tokens.spXs` | 4 | Icon gaps, inline padding |
| `Tokens.spSm` | 8 | Compact element spacing; nav item vertical padding |
| `Tokens.spMd` | 12 | Default element spacing; title bar horizontal padding |
| `Tokens.spLg` | 16 | Section padding; tab strip normal spacing (`tabBarSpacingNormal`) |
| `Tokens.spXl` | 24 | Layout gaps |
| `Tokens.tabBarSpacingCompact` | 8 | Tab strip compact spacing (below `breakpointResponsive`) |

Phase geometry tokens (the ONLY token edits this phase — `tokens.dart` 响应式设置面板 section, lines 230-240):

| Token | Current | Target | Action |
|-------|---------|--------|--------|
| `Tokens.panelMinWidth` | 400.0 | 400.0 | unchanged |
| `Tokens.panelMaxWidth` | 600.0 | **960.0** | edit value |
| `Tokens.panelWidthRatio` | 0.8 | **0.5** | repurpose value (grep-verified: only the shell consumes it) |
| `Tokens.panelHeightRatio` | 0.8 | — | **delete** (superseded by aspect derivation; single user) |
| `Tokens.panelAspectRatio` | — | **16.0 / 9.0** | NEW |
| `Tokens.panelSectionBg` | — | **= Tokens.bgGlass** | NEW alias (see Vertical Structure Color Contract) |

Naming rule (Assumption A4, locked): reuse existing `panelMinWidth`/`panelMaxWidth` names — edit values, do NOT add `panelWidthMin`/`panelWidthMax` duplicates.

Dead-code cleanup (locked): delete the unused alias `static const double panelWidthRatio = Tokens.panelWidthRatio;` at `settings_overlay_shell.dart:66-67` (grep-verified zero usages).

Exceptions: icon-only touch targets remain 48 (`Tokens.iconButtonSizeLarge`); title bar height 44; tab strip height 56 compact / 64 normal. All pre-existing, unchanged.

---

## Typography

Inherited from existing `Tokens.*` — **no typographic changes this phase**:

| Role | Size | Weight | Usage in this phase |
|------|------|--------|---------------------|
| Body | 14 (`Tokens.fontBody`) | Regular 400 (`weightRegular`) | Tab content body, audio/video tab rows |
| Label | 14 normal / 12 compact (`tabBarFontNormal` / `tabBarFontCompact`) | Regular 400 | Tab strip labels |
| Heading | 14 (`Tokens.fontBody`) | SemiBold 600 (`weightSemiBold`) | Panel title 「设置」 |
| Display | 18 (`Tokens.fontTitle`) | SemiBold 600 | Not used by this phase (dialogs elsewhere) |

Line heights: Flutter default (1.0 height multiplier, font metrics). No custom line-height tokens exist; none are introduced.

Weight exception (pre-existing, not new): `Tokens.weightMedium` (500) on the selected tab label (`_settings_nav_item.dart:94-96`) and `general_tab.dart:154` selected rows. Two primary weights (Regular 400 + SemiBold 600); Medium 500 is the selected-state emphasis already in the system.

---

## Color

Inherited from existing `Tokens.*` — **no color value changes this phase** (D-02 boundary):

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `Tokens.bgDeep` #060810 / `Tokens.bgBase` #0C0F18 | Player backdrop visible around the centered overlay; scrim `Colors.black54` behind panel (`settings_overlay_shell.dart:139`) |
| Secondary (30%) | `Tokens.bgGlass` 0x8C0C0F18 | **All four panel sections** (titleBar / tabStrip / content / buttonBar) via `Tokens.panelSectionBg` alias — see Vertical Structure Color Contract |
| Accent (10%) | `Tokens.accent` #2C58F4 | Selected tab left 2px indicator, selected tab icon + label color (only) |
| Destructive | `Tokens.danger` #FA3737 | Not used this phase — no destructive actions in the settings panel |

Accent reserved for: (1) selected-tab indicator bar, (2) selected-tab icon tint, (3) selected-tab label tint. Nothing else.

Hover surface: `Tokens.bgHover` #283045 (nav item hover/selected background — pre-existing, unchanged).

**Explicitly OUT of scope this phase (Phase 31 / VISUAL-01):** `controlBarBg`, `controlBarBorderWhite`, `glowOuterRing`, `controlBarBgIdle`, and `ControlBar._decorationPlaying` chrome alignment. The planner/executor must NOT touch these tokens or their consumers (D-02).

---

## Panel Geometry Contract (LAYOUT-01 / LAYOUT-02)

**Formula (CF-01 / D-04, locked):**

```
width  = min(screenW × Tokens.panelWidthRatio, screenH × Tokens.panelAspectRatio)
         .clamp(Tokens.panelMinWidth, Tokens.panelMaxWidth)
       = min(0.5 × screenW, screenH × 16/9)  clamp [400, 960]
height = width / Tokens.panelAspectRatio      // = width × 9/16 (strict 16:9)
```

**Seam:** `settings_overlay_shell.dart:172-180` — `_panelWidth` signature changes from `(double windowWidth)` to `(Size windowSize)`; `_panelHeight` divides by `panelAspectRatio`. Caller at :188-190 passes `MediaQuery.sizeOf(context)`.

**No breakpoint branch in sizing (D-04):** the formula is breakpoint-free. `Tokens.breakpointResponsive` (800) STAYS — it drives tab-strip compact switching only (font 14↔12, spacing 16↔8, strip height 64↔56), per Assumption A2. Deleting it would break 5 compact-mode tests.

**Re-baselined geometry (authoritative for SC#5 test assertions):**

| Window | Panel (new) | Panel (old, Phase 27) |
|--------|-------------|------------------------|
| 3840×2160 (4K) | 960×540 | 600×480 |
| 1920×1080 | 960×540 | 600×480 |
| 1366×768 | 683×384 | 600×480 |
| 800×600 | 400×225 | 600×480 |
| 500×400 | 400×225 | 400×320 |
| 625×500 | 400×225 | 500×400 |
| 600×400 | 400×225 | 480×384 |
| 1200×800 | 600×337.5 | 600×480 (drag maxY 160 → **231.25**) |

**Overlay mode (CF-03):** centered `Stack` sibling — NOT a standalone window, NOT `showDialog`. Position = screen center + `dragOffset`. `RepaintBoundary` from Phase 27 stays (D-06, no action).

---

## Tab Sequence Contract (LAYOUT-03)

**Final 7-tab order (D-01 / CF-05, locked):** `[EQ, Audio, Video, General, Shortcuts, About, Performance]` — General at **index 3** (3+1+3 symmetric). The other 6 tabs keep their existing relative order.

| Index | Tab | Icon | Label (existing copy, unchanged) |
|-------|-----|------|----------------------------------|
| 0 | EQ | `Icons.equalizer` | 均衡器 |
| 1 | Audio | `Icons.headphones` | 音频 |
| 2 | Video | `Icons.videocam` | 视频 |
| 3 | **General** | `Icons.tune` | 通用 |
| 4 | Shortcuts | `Icons.keyboard` | 快捷键 |
| 5 | About | `Icons.info_outline` | 关于 |
| 6 | Performance | `Icons.speed` | 性能 |

**Edit sites (all three must move together):**
1. `tab_strip.dart:36-56` — `_tabIcons` + `_tabLabels` lists reordered; order-comment updated to `EQ/Audio/Video/General/Shortcuts/About/Performance`.
2. `tab_content.dart:55-115` — `IndexedStack` children reordered to `[EqualizerTab, AudioTab, VideoTab, GeneralTab, ShortcutsTab, AboutTab, PerformanceTab]`; 7 hardcoded index literals (`end: N == selectedIndex`) and 7 order-comments updated. The 7-child explicit structure + `TweenAnimationBuilder` wrappers are preserved (test constraint at `tab_content.dart:8-11` — NO `List.generate` collapse).
3. `settings_panel_controller.dart:46-49` — `open()` reset index ripples (RESEARCH Pitfall 1): `state.selectedTab.value = 0` → reset to General's new index.

**Named-constant home (RESEARCH Open Question 1, locked):** promote `static const int defaultTabIndex = 3;` on `SettingsPanelController` — the index 3 appears exactly once in production code, referenced by `open()` and by tests. The positional lists in strip/content carry an order-comment referencing `SettingsPanelController.defaultTabIndex`. No separate `SettingsTabs` constants class (YAGNI — one reference site).

**Open-reset behavior (Assumption A1, locked):** panel opens on the **General tab (index 3)** — "opens on General" semantics preserved, NOT "opens on first tab". This preserves user muscle memory and the 6 General-default tests in `settings_tab_content_test.dart`.

**Order-agnostic (no change):** `nextTab`/`prevTab` modulo arithmetic (`tabCount = 7`); `panel_key_bindings.dart` pure index cycling; `FocusTraversalGroup` ≥4 ordering.

---

## Multi-Monitor Clamp Interaction Contract (LAYOUT-04)

**Primary behavior (CF-04 / D-03, locked):** real-time per-drag-frame clamping against the current monitor's **work area** via the existing `display_enumerator` FFI — the panel edge can never exceed the work area at any drag frame. Mirrors the existing fullscreen snap philosophy; no parallel clamp mechanism.

**Coordinate conversion (target pattern, ~15 lines, in `_onDragUpdate` at `settings_overlay_shell.dart:315-330`):**

```
panelCenterScreen = windowPos + windowSize/2 + dragOffset
constraint: workArea edges ∓ panel half-size
→ minDx = workArea.left   + panelW/2 − windowPos.dx − mediaSize.width/2
  maxDx = workArea.right  − panelW/2 − windowPos.dx − mediaSize.width/2
  minDy = workArea.top    + panelH/2 − windowPos.dy − mediaSize.height/2
  maxDy = workArea.bottom − panelH/2 − windowPos.dy − mediaSize.height/2
```

**Window-position source (Assumption A3, locked — Option A):** `await windowManager.getPosition()` at `onPanStart` (or panel open), cached for the drag session; `DisplayEnumerator.getCurrentDisplay()` queried synchronously per drag frame (cheap FFI). Option B (WindowService `onWindowMoved` notifier) is rejected — wider blast radius into kernel bridge for marginal freshness.

**Fallback path (locked — this is what keeps 10 existing test files constructible with zero ctor changes):** when the resolver returns null `DisplayInfo` (headless test env / FFI failure / `FindWindowW` finds no window), fall back to the **existing symmetric MediaQuery clamp** (`maxX = (mediaSize.width − panelW)/2` etc.). `user32.dll` loads fine on Windows headless — no new test-env hazard.

**Injectable seam (D-03, locked):** `SettingsOverlayShell` gains an optional ctor param `DisplayEnumerator? displayEnumerator` (default `null` → production constructs `Win32DisplayAdapter` internally). Tests inject a hand-written fake (project convention: fakes over mocks) returning a configurable `DisplayInfo`. Wiring point exists at `player_screen.dart:303-306` alongside the `isResizing` pass-through.

**Resize re-clamp (D-05, locked):** `didChangeDependencies` post-frame check — when `mediaSize` changes (window resize) and the current `dragOffset` is illegal against the new bounds, write back the clamped value. Self-contained in the shell. Real-time constraint applies whenever position is evaluated, not only during drag.

**Error handling convention:** FFI failures caught with `debugPrint` + graceful fallback to symmetric clamp — never silent `catch (_) {}`.

---

## Vertical Structure Color Contract (LAYOUT-05, D-02 boundary)

**Structural unification (locked):** all four panel sections read the SAME token. Value stays `bgGlass` — Phase 30 does placeholder unification only.

| Section | File:Line | Current | Target |
|---------|-----------|---------|--------|
| Upper (title bar) | `settings_overlay_shell.dart:286` | `Tokens.bgGlass` | `Tokens.panelSectionBg` |
| Tab strip | `tab_strip.dart:72` | `Tokens.bgGlass` | `Tokens.panelSectionBg` |
| Middle (content) | `tab_content.dart:52` | `Tokens.bgPanel` ← outlier | `Tokens.panelSectionBg` |
| Lower (button bar) | `settings_overlay_shell.dart:242` | `Tokens.bgGlass` | `Tokens.panelSectionBg` |

**Alias decision (RESEARCH Open Question 2, locked):** introduce `Tokens.panelSectionBg = Tokens.bgGlass` in the 响应式设置面板 token section and point all four sections at it. This creates the single swap-route Phase 31 (VISUAL-01/05) needs at zero extra cost now. A direct `bgPanel → bgGlass` swap without the alias is a contract deviation.

**Phase 31 scope (do NOT specify or touch here):** `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` switch, edge-glow, three-state, density. Phase 30 SC#4 is satisfied at the structural-unification level only.

---

## Copywriting Contract

**No copy changes this phase.** All strings are existing; the tab reorder moves labels with their tabs.

| Element | Copy |
|---------|------|
| Primary CTA | 「确定」 — apply pending settings and close (existing button bar: 取消 / 应用 / 确定, `settings_overlay_shell.dart:247-262`) |
| Panel title | 「设置」 (`settings_overlay_shell.dart:290`, fontBody SemiBold textPrimary) |
| Tab labels | 均衡器 / 音频 / 视频 / 通用 / 快捷键 / 关于 / 性能 (existing, reordered only) |
| Open-reset behavior | "Panel opens on General tab (index 3)" — preserves muscle memory (A1); 6 tests depend |
| Empty state | Not applicable — settings tabs are always populated; no empty-data state exists in the panel |
| Error state | FFI work-area query failure → silent-to-user fallback to symmetric clamp + `debugPrint` log (no user-facing error copy; panel remains fully usable) |
| Destructive confirmation | None — 取消 discards pending settings without confirmation (existing deferred-apply behavior, unchanged) |

---

## UI Considerations

> State coverage for this layout refactor. Probe (Step 9.5) may replace rows on re-run.

Applicable state considerations resolved: 5 covered, 2 backstop, 0 unresolved

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| empty | settings panel | ✅ covered | Panel closed = overlay subtree not built; tabs always populated — no empty-data state exists |
| drag-clamped | title bar drag (multi-monitor) | ✅ covered | Real-time workArea clamp per drag frame (D-03); conversion formula locked in Clamp Contract; fake-DisplayEnumerator widget test (Wave 0) |
| drag-fallback | headless / null DisplayInfo | ✅ covered | Null resolver → existing symmetric MediaQuery clamp; keeps 10 existing test files constructible with zero ctor changes |
| resize | window resize while panel open | ✅ covered | D-05 `didChangeDependencies` post-frame re-clamp of illegal `dragOffset`; Wave 0 test pumps size A → smaller size B and asserts re-clamp |
| tab-select on open | controller reset | ✅ covered | `open()` resets `selectedTab` to `SettingsPanelController.defaultTabIndex` (3 = General); re-baselined shell tests assert 3 |
| overflow | tab strip at `panelMinWidth` 400 | 🧪 backstop | 7 `Expanded` slots × inner 80px `SettingsNavItem` at 400px width — pre-existing since Phase 27 (min width unchanged); compact mode (font 12 / spacing 8) active below `breakpointResponsive`; visual check only, not regressed by this phase |
| long-text | tab labels (Chinese, 2-3 chars) | 🧪 backstop | 14px normal / 12px compact labels in ~57-80px slots; no truncation path; visual check only |

<!-- Status vocabulary (locked by probe-core projectTruths):
     ✅ covered   → a plain truth string lifted into must_haves.truths
     🧪 backstop  → a flat scalar { statement, verification: backstop }; at verify time, no explicit
                    evidence → insufficient_spec → human_needed (never a silent pass, #1154)
     ⚠ unresolved → an explicit planner assumption (surfaced, never silently dropped)
     Rows are REPLACED (not appended) on a probe re-run — idempotent. -->

---

## Registry Safety

Not applicable — Flutter desktop project; shadcn is not initialized and the shadcn gate does not apply (tech stack is not React/Next.js/Vite). No third-party component registries, no new packages, no new FFI (Blocking Constraint: multi-monitor clamp uses existing `display_enumerator` only).

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not required |
| (third-party) | none | not applicable |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
