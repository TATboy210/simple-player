# Phase 30: panel-layout-redesign - Context

**Gathered:** 2026-07-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Re-containerize the settings overlay to **16:9 / ~50% screen area** with the **General tab at the middle position** of the 7-tab sequence and **multi-monitor drag clamping** via the existing `display_enumerator` work-area FFI.

**In scope (from ROADMAP L62-64 + LAYOUT-01..05):**
- Size formula: `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]`; height derived per D-04 below
- General tab moved to index 3 (4th position, 3+1+3 symmetric) of the 7-tab sequence
- Multi-monitor drag clamping via `display_enumerator` work-area FFI (NOT `MediaQuery`); panel never lands on a non-primary monitor's bezel gap
- Upper/middle/lower vertical structure color unification (LAYOUT-05, coordinated with VISUAL-01 in Phase 31 — boundary set in D-02)
- Size-assertion widget tests re-baselined to the 16:9 formula (SC#5); existing tab-strip tests stay green

**Out of scope (belong to other phases):**
- Phase 31 VISUAL-01: chrome alignment to `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` + edge-glow / three-state / density (D-02 defers these to Phase 31)
- Standalone-window mode for the panel (PROJECT Constraint: overlay mode only — centered Stack sibling, NOT a separate window)
- New dependencies (multi-monitor clamp MUST use existing FFI — Blocking Constraint)
- Hardcoded sizes (all visual values via `Tokens.*` — PROJECT Constraint)

**Depends on (COMPLETE):**
- Phase 28 (split shell — provides the sizing seam at `settings_overlay_shell.dart:172-179` + tab structure in `tab_strip.dart` / `tab_content.dart`)
- Phase 29 (always-pause — panel open implies pause + `_preOpenState` snapshot + 4 sub-race tests; Phase 30 can iterate safely without racing playback)

</domain>

<decisions>
## Implementation Decisions

### Carried Forward (pre-locked — DO NOT re-litigate)

These 8 decisions are already固化 in ROADMAP.md Success Criteria / REQUIREMENTS.md / PROJECT.md. Downstream agents treat them as constraints, not open questions.

- **CF-01 (size formula):** `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]` — 16:9 primary constraint, 50% area secondary (LAYOUT-02, PRODUCT-locked)
- **CF-02 (aspect ratio):** 16:9 primary + 50% area secondary (LAYOUT-01/02)
- **CF-03 (overlay mode):** Centered overlay Stack sibling, NOT standalone window (PROJECT Constraint; standalone-window mode explicitly out of scope)
- **CF-04 (multi-monitor clamp source):** `display_enumerator` work-area FFI, NOT `MediaQuery` (Blocking Constraint; no new deps; memory `project_multi_monitor_ffi` documents EnumDisplayMonitors callback + RECT→Rect + clamp algorithm)
- **CF-05 (General tab position):** General tab at index 3 (4th position, 3+1+3 symmetric) of the 7-tab sequence, NOT first/last (LAYOUT-03, ROADMAP SC#2)
- **CF-06 (tokens only):** All visual values via `Tokens.*`, no hardcoded sizes (PROJECT Constraint; LAYOUT-05 implied)
- **CF-07 (vertical structure color unify target):** Upper/middle/lower vertical structure unified to control-bar color (LAYOUT-05, coordinated with VISUAL-01 — but the Phase 30/31 boundary itself is gray area B, resolved in D-02)
- **CF-08 (always-pause live):** Phase 29 COMPLETE — panel open implies pause + `MediaState._preOpenState` snapshot + 4 sub-race tests. Phase 30 may iterate the panel without racing playback.

### A. Tab Sequence Reorder
- **D-01:** Final 7-tab sequence = `[EQ, Audio, Video, General, Shortcuts, About, Performance]` — General moved from position 1 to position 4 (index 3); the other 6 tabs keep their existing relative order. This is the minimal-change path that preserves user muscle memory. Planner updates the tab list in `tab_strip.dart` (currently `:36` comment "7 个 tab 图标 General/EQ/Audio/Video/Shortcuts/About/Performance") AND the `IndexedStack` child order in `tab_content.dart` to match.

### B. LAYOUT-05 vs VISUAL-01 Boundary
- **D-02:** Phase 30 does **placeholder unification** only — keep existing `bgGlass`, but unify "upper/middle/lower all use the SAME token" at the structural layer; Phase 31 (VISUAL-01) is where the actual switch to `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` happens. This enforces a strict phase boundary with no scope overlap. Phase 30 SC#4 ("unified control-bar color") is satisfied at the structural-unification level; the visual chrome alignment is Phase 31's deliverable.

### C. Multi-Monitor Clamp UX
- **D-03:** **Real-time clamping** during drag — the panel edge cannot exceed the current monitor's work-area at any frame (query work-area per drag frame). This matches the existing fullscreen snap behavior for consistency. Performance cost is negligible (work-area is cached; FFI query is lightweight). Planner implements this in the drag handler of `settings_overlay_shell.dart`, using the existing `display_enumerator` work-area FFI.

### D. Height Derivation + Responsive Breakpoint
- **D-04:** `height = width × 9/16` (strict 16:9, formula self-consistent). **Abandon the Phase 27 800px breakpoint** — `clamp[400, 960]` on width + the 16:9 height derivation is already adaptive across window sizes (verified: 4K 3840×2160 → 960×540; 1920×1080 → 960×540 hits 50% area; 800×600 → 400×225 small-window legal). SC#5 size-assertion tests re-baseline to this formula. — **Reversibility:** costly — undo requires re-baselining SC#5 size-assertion tests back to the Phase 27 `height=width×0.8` + 800px-breakpoint formula AND restoring the breakpoint branch logic; ROADMAP Risk Profile names test re-baseline as this phase's headline risk.

### Claude's Discretion
- **D-05 (C sub-decision — resize re-clamp):** When the window resizes and the panel's current position becomes illegal (outside the new work-area), re-clamp to the new work-area. This is the natural extension of D-03's "panel edge can never exceed work-area at any frame" philosophy — the real-time constraint applies whenever position is evaluated, not only during drag. If the user later disagrees, this is the item to revisit.
- **D-06 (D sub-decision — RepaintBoundary):** Keep the `RepaintBoundary` that Phase 27 added for the panel. It is a rendering-isolation optimization independent of the sizing formula; the 16:9 change does not affect its value. No action needed unless a Phase 31 rendering audit says otherwise.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning Artifacts
- `.planning/ROADMAP.md` — Phase 30 detail (L62-64 goal, L66-72 five Success Criteria, L73 Blocking Constraints honored, L157-171 Risk Profile + Research Flag)
- `.planning/REQUIREMENTS.md` — LAYOUT-01..05 atomic requirements + Traceability Phase 30 mapping
- `.planning/PROJECT.md` — v4.5 Key Decisions (横向 tab 中部布局 / 控制栏设计北极星 / overlay 模式 / 总是暂停)
- `.planning/STATE.md` — Phase 28/29 complete records; sizing seam position; always-pause verified live

### Sizing & Layout Code (the seams Phase 30 modifies)
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` §172-179 — sizing seam: current `width = windowWidth × 0.8, clamp [400,600]` / `height = width × 0.8, fullscreen 600×480, small 400×320`. THIS is the location to replace with the 16:9 formula (D-04). Also contains the upper/middle/lower vertical structure (D-02) and the drag/resize handler (D-03, D-05).
- `lib/ui/dialogs/settings/tab_strip.dart` §36 — tab order comment "7 个 tab 图标 (General/EQ/Audio/Video/Shortcuts/About/Performance)". General currently at position 1; D-01 moves it to position 4. The `IndexedStack` child order in `lib/ui/dialogs/settings/tab_content.dart` must be updated to match.

### Multi-Monitor FFI (existing — no new deps)
- `lib/kernel/bridge/display_enumerator.dart` — abstract work-area enumerator interface
- `lib/kernel/bridge/win32/win32_display_enumerator.dart` — Win32 EnumDisplayMonitors callback implementation
- `lib/kernel/bridge/screen_utils.dart` + `lib/kernel/bridge/window_service.dart` — work-area FFI consumers (clamp algorithm documented in memory `project_multi_monitor_ffi` + `project_v17_wave3_progress`)

### Design Tokens & Visual (LAYOUT-05 / VISUAL-01 coordination)
- `lib/ui/theme/tokens.dart` §12 `bgGlass` (0x8C0C0F18) / §31 `glowOuterRing` (0x0A5082FF) / §57 `controlBarBg` (0x990E111E) / §59 `controlBarBorderWhite` (0x0A6496FF) / §69 `controlBarBgIdle` (0x660E111E) / §87 `borderHighlight` (0x33FFFFFF) — LAYOUT-05/VISUAL-01 coordination needs all these; D-02 keeps `bgGlass` for Phase 30, defers the `controlBarBg` switch to Phase 31
- `lib/ui/player/control_bar.dart` — `ControlBar._decorationPlaying` 4-shadow decoration; Phase 31 VISUAL-01 reuses this as the chrome-alignment source (CONFIRM PATH EXISTS before Phase 31 planning)

### Tests (SC#5 re-baseline targets)
- `test/.../settings_tab_content_test.dart` — existing tab tests must stay green
- `test/.../settings_responsive_integration_test.dart` — SC#5 size-assertion re-baseline target

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **ValueNotifier + ValueListenableBuilder** — state management pattern unchanged; panel state still owned by `SettingsPanelController.state.selectedTab` (Phase 28 verified single owner)
- **GlassContainer** — glass-morphism wrapper pattern; Phase 30 keeps `bgGlass` per D-02
- **ControlBar._decorationPlaying 4-shadow decoration** (`lib/ui/player/control_bar.dart`) — Phase 31 VISUAL-01 reuses this for chrome alignment; Phase 30 does NOT touch it (D-02 boundary)
- **IndexedStack 7-child explicit structure** (`tab_content.dart`) — Phase 28 verified preserved; D-01 reorders children but keeps the IndexedStack pattern
- **FocusTraversalGroup ≥4** — Phase 28 verified unchanged; Phase 30 tab reorder must preserve focus-traversal ordering

### Established Patterns
- **`display_enumerator` work-area FFI** already exists — multi-monitor clamp uses it directly (CF-04), no new dependencies; memory `project_multi_monitor_ffi` documents the EnumDisplayMonitors callback + RECT→Rect conversion + clamp algorithm
- **`Tokens.*` for all visual values** — no hardcoded sizes (CF-06); the 16:9 formula's `[400, 960]` clamp bounds are the only magic numbers and should be promoted to named `Tokens.*` constants during planning
- **Fullscreen snap precedent** — existing fullscreen behavior uses work-area snap; D-03 real-time clamp mirrors this for consistency

### Integration Points
- **Sizing seam:** `settings_overlay_shell.dart:172-179` → replace `width×0.8` / `height×0.8` + 800px breakpoint with `width = min(0.5×screenW, screenH×16/9) clamp[400,960]` / `height = width×9/16` (D-04)
- **Tab order seam:** `tab_strip.dart:36` tab list + `tab_content.dart` IndexedStack child order → reorder to `[EQ, Audio, Video, General, Shortcuts, About, Performance]` (D-01)
- **Drag/resize handler:** `settings_overlay_shell.dart` drag callback → real-time work-area clamp per frame (D-03); resize listener → re-clamp on window resize (D-05)
- **Vertical structure decoration:** `settings_overlay_shell.dart` upper/middle/lower decoration code → unify to same token (bgGlass, structural layer only) (D-02)
- **Test re-baseline:** `settings_responsive_integration_test.dart` → SC#5 size-assertion tests re-baseline to 16:9 formula; `settings_tab_content_test.dart` → existing tab tests stay green (SC#5)

</code_context>

<specifics>
## Specific Ideas

- **Formula self-consistency check (recorded for the planner):** The 16:9 + clamp formula is self-consistent across window sizes — no conflict between the 16:9 primary and 50% area secondary constraints:
  - 4K 3840×2160 → `width = min(1920, 3840) = 1920 → clamp 960`, `height = 540` → panel 960×540 (~25% area, legal)
  - 1920×1080 → `width = min(960, 1920) = 960`, `height = 540` → panel 960×540 (hits 50% width + 50% height target)
  - 1366×768 → `width = min(683, 1365) = 683`, `height = 384` → panel 683×384 (~50% area)
  - Small 800×600 → `width = min(400, 1066) = 400`, `height = 225` → panel 400×225 (legal minimum, short but acceptable for an overlay)
- **Real-time clamp consistency with fullscreen snap** — D-03 was chosen specifically to match the existing fullscreen snap behavior; the planner should reuse the same work-area query/cache path for both, not introduce a parallel mechanism.
- **Phase 30/31 boundary discipline** — D-02's "placeholder unification" is the keystone: Phase 30 does structural color unification only (same token across upper/middle/lower), Phase 31 does the visual chrome alignment (switch to `controlBarBg`). The planner must NOT touch `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` in Phase 30 — that's Phase 31's scope.
- **`[400, 960]` clamp bounds** — these are the only magic numbers in the formula; promote to `Tokens.*` named constants (e.g., `Tokens.panelWidthMin = 400`, `Tokens.panelWidthMax = 960`) during planning per CF-06.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. No new capabilities or out-of-scope ideas surfaced during the A/B/C/D discussion.

</deferred>

---

*Phase: 30-panel-layout-redesign*
*Context gathered: 2026-07-26*
