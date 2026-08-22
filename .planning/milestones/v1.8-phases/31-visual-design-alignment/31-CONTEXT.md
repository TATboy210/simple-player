# Phase 31: visual-design-alignment - Context

**Gathered:** 2026-07-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the settings panel's chrome and option rows visually indistinguishable from the control bar — same glass material, 4-shadow + blue outer ring, edge glow, button three-state, tighter density. Phase 30 landed the container (16:9 / ~50% area, `panelSectionBg` placeholder unification); Phase 31 switches from `bgGlass` placeholder to `controlBar*` family + extracts shared decoration token.

**In scope (from ROADMAP §31 + VISUAL-01..05):**
- VISUAL-01: Panel chrome alignment to control bar — `bgGlass` → `controlBarBg` + `controlBarBorderWhite` + `glowOuterRing` (4-shadow decoration from `ControlBar._decorationPlaying`)
- VISUAL-02: Option row default borderless/no white-glow fused with panel, only selected state highlights (control bar button three-state: default/hover/selected)
- VISUAL-03: Option boundaries tighter (reduce padding/margin, align with control bar button density)
- VISUAL-04: Thin glass "see-through options" effect via `Tokens.bgGlass` color (NOT second `BackdropFilter`, avoid GPU readback stacking)
- VISUAL-05: Extract `PanelDecoration`/`ControlBarDecoration` shared token, color unified single-route

**Out of scope (belong to other phases):**
- Phase 32 NAV-05: top/bottom thin glass covers over option list ends (`Container(color: bgGlass)` non-second blur) — NOT pre-wired in Phase 31 (D-12)
- Phase 32 NAV-06/07: keyboard arrow glow feedback + single `Focus` root capture
- Container geometry (Phase 30 done — 16:9 / 50% area, `panelSectionBg` placeholder)
- New dependencies (all visual via existing `Tokens.*`)

**Depends on (COMPLETE):**
- Phase 28 (split shell — `tab_strip.dart` / `tab_content.dart` / `panel_key_bindings.dart`)
- Phase 29 (always-pause — panel open implies pause + `_preOpenState` snapshot)
- Phase 30 (panel layout — 16:9 formula + General tab index 3 + multi-monitor clamp + `panelSectionBg=bgGlass` alias placeholder unification, D-02 boundary)

</domain>

<decisions>
## Implementation Decisions

### Carried Forward (pre-locked — DO NOT re-litigate)

These decisions are already固化 in ROADMAP.md §31 SC#1-5 + Phase 30 CONTEXT.md CF-01..CF-08 + D-02 + PROJECT.md. Downstream agents treat them as constraints, not open questions.

- **CF-01..CF-08 + D-02** (Phase 30 keystone boundary): Phase 30 did placeholder structural color unification only (`panelSectionBg=bgGlass` alias across all four sections); Phase 31 is where the actual switch to `controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` + edge-glow + three-state + density happens. The planner/executor must NOT touch these in Phase 30 scope (already shipped); Phase 31 owns the switch.
- **SC#1**: `controlBarBg` / `controlBarBorderWhite` / `glowOuterRing` named exactly (token names pre-locked)
- **SC#2**: 4-shadow decoration source = `ControlBar._decorationPlaying` (Phase 31 extracts this into shared token)
- **SC#3**: Three-state semantics (default borderless / hover / selected) — control bar button three-state is the target state
- **SC#4**: BackdropFilter stacking mitigation (Pitfall 3) — thin glass via `Container(color:)` not second `BackdropFilter`
- **SC#5**: Test assertions re-baseline (Phase 30 SC#5 already done; Phase 31 may need visual assertion updates if chrome alignment changes geometry)
- **Design north star**: 面板对齐控制栏毛玻璃语言 (control bar is the visual baseline, panel is the adopter)
- **CF-06**: All visual values via `Tokens.*` (no hardcoded colors/fonts/spacing)

### A. Shared Decoration Token (Area 1)

- **D-01:** New file `lib/ui/shared/control_bar_decoration.dart` — bidirectional reuse (`control_bar.dart` + `settings_overlay_shell.dart`); single-route; no coupling direction issue (shared generic layer depends on neither consumer). — **Reversibility:** costly — undo requires re-inlining decoration back into `control_bar.dart` + `settings_overlay_shell.dart` (2 call sites) + re-duplicating 4-shadow logic.
- **D-02:** Class name `ControlBarDecoration` — control bar is the visual baseline, panel is the adopter, coherent with design north star (deviates from SC#3 neutral semantics; user chose directional naming).
- **D-03:** `playing` + `idle` extracted to shared, `tween` stays local in `control_bar.dart` — complete state machine migration; accept slight idle over-extraction in exchange for `control_bar.dart` not mixing shared+local (symmetry preference > strict YAGNI). — **Reversibility:** reversible — re-inlining `idle` to `control_bar.dart` is local.
- **D-04:** Method `playing({BorderRadius? borderRadius})` — default `controlBarRadius` (control bar no-arg call), panel overrides `radiusLg`; coherent with D-02 semantics. (grep confirmed three-way radius inconsistency: `controlBarRadius` / `radiusLg` / `radiusLarge`.)

### B. Option Row Three-State (Area 2)

- **D-05:** `selected` = focused row (keyboard/gamepad navigation focus) — unified across all row types, paving way for Phase 32 NAV (NAV-06/07); control bar button three-state is the target state (`GlassButton` currently only scale animation, no selected background); three-state is新建 (new) not aligning existing.
- **D-06:** Focused highlight = `controlBarBorderWhite` blue glow border — chrome alignment achieved (same token as `ControlBarDecoration` border); hover = `bgHover` background; default = transparent fusion; Flutter `BoxDecoration` border does not occupy layout (not CSS box-sizing).
- **D-07:** Active value representation = accent text color (`Tokens.accent` #2C58F4) — consistent with tab selected label tint (30-UI-SPEC precedent); focused border + active value text color do not conflict (border vs text, different visual dimensions); color-weak a11y risk recorded, plan-phase mitigates with deeper accent or SemiBold weight.
- **D-08:** Pressed state = InkWell built-in highlight + ripple, no custom scale animation — conforms to user `feedback_button_no_animation` preference; requires refactor `SettingRow` `GestureDetector`→`InkWell` (plan-phase implementation).

### C. Density Pixels (Area 3)

- **D-09:** Row height = 40px — moderately compact (between 36px button and 42px current), balancing density vs text comfort; a11y < 44px but acceptable for desktop (control bar 36px precedent).
- **D-10:** Horizontal padding = `spXs` (4px) — halved from `spSm` (8), consistent with row height reduction; `spXs` is inline padding token (30-UI-SPEC), conforms to CF-06 tokens only.

### D. See-Through Thin Glass (Area 4)

- **D-11:** Content section keeps `bgGlass`, chrome three sections switch to `controlBarBg` (layered) — VISUAL-01 chrome 4-shadow + VISUAL-04 content thin-glass see-through options both satisfied; NAV-05 Phase 32 adds top/bottom covers; layered semantics: chrome solid + content thin, consistent with control bar's own layering (control bar is pure chrome, no content area). — **Reversibility:** reversible — swapping content back to `controlBarBg` is a one-token alias change.
- **D-12:** NAV-05 top/bottom covers NOT pre-wired; Phase 31 content = simple `Container(color: bgGlass)`, Phase 32 NAV-05 refactors to `Stack` + top/bottom covers — YAGNI; differs from D-03 (D-03 is within-phase state-machine symmetry, D-12 is cross-phase pre-wire deferred to Phase 32). — **Reversibility:** reversible — Phase 32 adds `Stack` wrapper without touching Phase 31 content token.

### Claude's Discretion

- **panelSectionBg alias fate** (30-UI-SPEC L56 `panelSectionBg=bgGlass`): Under D-11 layered decision, chrome switches to `ControlBarDecoration` (does not use `panelSectionBg` alias); content may keep `panelSectionBg` alias (→bgGlass, content single-route) or switch to direct `bgGlass`. Recommendation: **keep `panelSectionBg` alias for content** — preserves 30-UI-SPEC's single-swap-route semantics for content; future content color change touches one alias site. Planner has flexibility to decide final form (alias vs direct) since both satisfy CF-06.
- **Chrome decoration method**: `ControlBarDecoration.playing` (4-shadow) for chrome three sections — panel chrome恒用 playing 装饰 (visual alignment, not state alignment; panel is not "playing" but visual language consistent). `idle` method exists for control_bar local use (D-03). Planner confirms.
- **a11y mitigation** (D-07, discretionary): If accent #2C58F4 insufficient contrast for color-weak users, plan-phase may deepen accent or apply SemiBold weight to active value text. Planner decides based on contrast audit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Planning Artifacts
- `.planning/ROADMAP.md` §31 — Phase 31 goal + SC#1-5 (controlBarBg/controlBarBorderWhite/glowOuterRing named, 4-shadow from ControlBar._decorationPlaying, three-state semantics, BackdropFilter Pitfall-3 mitigation)
- `.planning/REQUIREMENTS.md` VISUAL section (L31-37) — VISUAL-01..05 full requirement text + Traceability Phase 31 mapping
- `.planning/PROJECT.md` — v4.5 "设计北极星" constraint (control-bar alignment is the north star), Tokens.* design system, BackdropFilter stacking mitigation
- `.planning/STATE.md` — Phase 28/29/30 complete records; panelSectionBg alias placeholder live

### Prior Phase Context (Carried Forward)
- `.planning/phases/30-panel-layout-redesign/30-CONTEXT.md` — Phase 30 CF-01..CF-08 + D-02 (chrome-deferral boundary to Phase 31); the 8 pre-locked decisions flow directly into CONTEXT.md without re-asking
- `.planning/phases/30-panel-layout-redesign/30-UI-SPEC.md` — Phase 30's visual contract; Phase 31's alignment target inherits these params + extends to chrome alignment. KEY sections: L56 (`panelSectionBg=bgGlass` alias), L85 (no color change Phase 30 / D-02 boundary), L98 (`controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` explicitly Phase 31 scope), L188-201 (Vertical Structure Color Contract — four sections unified `panelSectionBg` placeholder)

### Code (the seams Phase 31 modifies)
- `lib/ui/player/control_bar.dart` — `ControlBar._decorationPlaying` 4-shadow decoration (L21-49); `_decorationIdle` (2-shadow); `_decorationTween`; `_borderRadius` (L18, `controlBarRadius`). Phase 31 extracts playing+idle into shared `ControlBarDecoration` (D-01, D-03); tween stays local.
- `lib/ui/shared/control_bar_decoration.dart` — NEW file (D-01 home); bidirectional reuse control_bar + settings_overlay_shell
- `lib/ui/shared/glass_container.dart` — `GlassContainer` (BackdropFilter at L158/167, 3-tier blur L35-43, D-13 opacity<0.01 skip L149, D-14 false skip L111, resize skip L118); `GlassButton` (icon-only no BackdropFilter L210/282, scale animation L181 — three-state is new, D-05/D-08). Phase 31 Pitfall 3 anchor: content `Container(color: bgGlass)` inside GlassContainer does not stack second BackdropFilter.
- `lib/ui/shared/settings_card.dart` — `SettingRow` (2-state transparent→bgHover #283045, height 42, padding spSm=8, AnimatedContainer + GestureDetector). Phase 31 refactor: 3-state (D-05/D-06/D-07), height 40 (D-09), padding spXs=4 (D-10), GestureDetector→InkWell (D-08).
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` — panel shell (GlassContainer L269, four sections, borderRadius radiusLg L271). Phase 31: chrome three sections → `ControlBarDecoration.playing` (D-11), content → bgGlass (D-11).

### Design Tokens
- `lib/ui/theme/tokens.dart` — `controlBarBg` (0x990E111E), `controlBarBorderWhite` (0x0A6496FF), `glowOuterRing` (0x0A5082FF), `controlBarBgIdle` (0x660E111E), `bgGlass` (0x8C0C0F18), `bgHover` (#283045), `accent` (#2C58F4), `borderHighlight` (0x33FFFFFF), `controlBarRadius` / `radiusLg` / `radiusLarge` (three-way inconsistency, D-04), `spXs` (4) / `spSm` (8)

### Tests
- `test/.../settings_tab_content_test.dart` — existing tab tests must stay green
- `test/.../settings_responsive_integration_test.dart` — Phase 30 SC#5 size-assertion (Phase 31 may need visual assertion updates if chrome alignment changes geometry)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **ValueNotifier + ValueListenableBuilder** — state management unchanged; panel state owned by `SettingsPanelController.state.selectedTab`
- **GlassContainer** — glass-morphism wrapper; Phase 31 keeps GlassContainer for panel blur, content uses `Container(color: bgGlass)` inside (no second BackdropFilter, Pitfall 3)
- **ControlBar._decorationPlaying 4-shadow decoration** (`lib/ui/player/control_bar.dart` L21-49) — Phase 31 VISUAL-01 extracts this into shared `ControlBarDecoration` (D-01); panel chrome adopts it for visual alignment
- **IndexedStack 7-child explicit structure** (`tab_content.dart`) — Phase 28 verified preserved; Phase 31 does not touch tab order
- **InkWell** — Flutter built-in highlight + ripple; Phase 31 adopts for SettingRow pressed state (D-08), conforming to `feedback_button_no_animation`

### Established Patterns
- **`Tokens.*` for all visual values** — no hardcoded sizes (CF-06); `controlBarBg`/`controlBarBorderWhite`/`glowOuterRing` are existing tokens, Phase 31 just routes panel to them
- **BackdropFilter stacking mitigation (Pitfall 3, SC#4)** — GlassContainer provides the single BackdropFilter layer; all section backgrounds use `Container(color:)` not additional `BackdropFilter`. Phase 31 content `Container(color: bgGlass)` follows this pattern; chrome `ControlBarDecoration` (BoxDecoration with color + shadow + border) also sits inside GlassContainer without stacking.
- **Three-state button pattern** — control bar `GlassButton` currently only scale animation (no selected background); Phase 31 establishes three-state (default/hover/selected) as new pattern (D-05), aligning panel option rows with the target control bar button state

### Integration Points
- **Shared decoration seam:** `lib/ui/shared/control_bar_decoration.dart` (NEW, D-01) → consumed by `control_bar.dart` (no-arg `playing()` default `controlBarRadius`) + `settings_overlay_shell.dart` (chrome three sections, `playing(borderRadius: radiusLg)`)
- **Content section background:** `settings_overlay_shell.dart` content section → `Container(color: bgGlass)` (D-11, keeps `panelSectionBg` alias per Claude's discretion)
- **SettingRow refactor:** `lib/ui/shared/settings_card.dart` → 3-state (D-05/D-06/D-07) + height 40 (D-09) + padding spXs (D-10) + InkWell (D-08)
- **GlassButton three-state:** `lib/ui/shared/glass_container.dart` GlassButton → add selected background (D-05 target state; currently only scale)

</code_context>

<specifics>
## Specific Ideas

- **D-02 directional naming rationale** — user chose `ControlBarDecoration` over neutral `GlassChrome` because "控制栏为视觉基准, 面板是 adopter" — the class name itself encodes the design north star (control bar is baseline). Planner should preserve this directional semantics in API design.
- **D-03 symmetry preference** — user accepted slight `idle` over-extraction to keep `control_bar.dart` from mixing shared+local decoration. This is a within-phase symmetry preference, distinct from D-12 cross-phase YAGNI. Planner should not "fix" the idle over-extraction by re-inlining.
- **D-05 selected = focus row** — user chose focus semantics (keyboard/gamepad navigation focus) over active-value semantics, explicitly to pave way for Phase 32 NAV-06/07 (keyboard arrow glow + single Focus root). All row types unified under focus semantics. Planner should ensure SettingRow + GlassButton both respond to Focus traversal.
- **D-07 a11y risk** — accent #2C58F4 for active value text may be insufficient for color-weak users. Recorded as risk; plan-phase mitigates (deeper accent or SemiBold). Not a Phase 31 blocker.
- **D-11 layered rationale** — "控制栏本身分层一致 (控制栏纯 chrome 无 content 区)" — panel chrome + content layering mirrors control bar's own structure (control bar is pure chrome). This is the deep rationale for not全切 controlBarBg.
- **D-12 YAGNI distinction** — user explicitly distinguished D-03 (within-phase symmetry) from D-12 (cross-phase pre-wire). Within-phase: prefer symmetry. Cross-phase: follow YAGNI. This is a mature engineering judgment pattern.

</specifics>

<deferred>
## Deferred Ideas

- **NAV-05 top/bottom thin glass covers** — Phase 32; Phase 31 content = simple `Container(color: bgGlass)`, Phase 32 refactors to `Stack` + top/bottom `Container(color: bgGlass)` covers (D-12)
- **NAV-06 keyboard arrow glow feedback** — Phase 32; Phase 31 D-05 focus semantics paves way
- **NAV-07 single Focus root capture** — Phase 32; Phase 31 D-05 unified focus row semantics paves way
- **D-07 a11y mitigation (deeper accent or SemiBold)** — plan-phase decision based on contrast audit; not Phase 31 blocker
- **panelSectionBg alias final form (alias vs direct bgGlass)** — plan-phase implementation detail (Claude's discretion recommends keeping alias for content single-route)

</deferred>

---

*Phase: 31-visual-design-alignment*
*Context gathered: 2026-07-27*
