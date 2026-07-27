# Phase 31: visual-design-alignment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-27
**Phase:** 31-visual-design-alignment
**Areas discussed:** shared-decoration-token, option-row-three-state, density-pixels, see-through-thin-glass

---

## Area 1: shared-decoration-token

| Option | Description | Selected |
|--------|-------------|----------|
| shared/panel_decoration.dart 新文件 | (Q1 home — neutral location) | |
| lib/ui/shared/control_bar_decoration.dart | (Q1 home — bidirectional reuse, single-route) | ✓ |
| GlassChrome (neutral) | (Q2 name — recommended neutral semantics) | |
| ControlBarDecoration (directional) | (Q2 name — control bar as visual baseline) | ✓ |
| playing only (YAGNI) | (Q3 boundary — recommended, minimal extraction) | |
| playing + idle (complete migration) | (Q3 boundary — full state machine, control_bar no mix) | ✓ |
| caller passes borderRadius | (Q4 API — recommended, explicit) | |
| default + override | (Q4 API — control bar no-arg simplest) | ✓ |

**User's choices:** D-01 control_bar_decoration.dart, D-02 ControlBarDecoration, D-03 playing+idle, D-04 default+override
**Notes:** User chose directional naming (ControlBarDecoration) over neutral (GlassChrome) — control bar is visual baseline, panel is adopter; class name encodes design north star. User chose complete migration (playing+idle) over YAGNI (playing only) — within-phase symmetry preference (control_bar.dart should not mix shared+local). User chose default+override over caller-passes — control bar no-arg call is simplest; grep confirmed three-way radius inconsistency (controlBarRadius / radiusLg / radiusLarge).

---

## Area 2: option-row-three-state

| Option | Description | Selected |
|--------|-------------|----------|
| 活动值 (active value) | (Q1 selected semantics — recommended, direct meaning) | |
| 焦点行 (focus row) | (Q1 selected semantics — keyboard/gamepad focus, paves NAV-06/07) | ✓ |
| controlBarBorderWhite 边框 | (Q2 focused highlight — chrome alignment) | ✓ |
| accent 文字色 | (Q3 active value representation — tab selected precedent) | ✓ |
| InkWell 内置反馈 | (Q4 pressed — no custom animation, feedback_button_no_animation) | ✓ |

**User's choices:** D-05 focus row, D-06 controlBarBorderWhite border, D-07 accent text, D-08 InkWell
**Notes:** User chose focus row over active value — explicitly paves way for Phase 32 NAV-06/07 (keyboard arrow glow + single Focus root). GlassButton currently only scale animation (no selected background) — three-state is新建 (new), not aligning existing pattern. D-06 controlBarBorderWhite achieves chrome alignment (same border token as ControlBarDecoration). D-07 accent #2C58F4 consistent with 30-UI-SPEC tab selected label tint; a11y color-weak risk recorded, plan-phase mitigates. D-08 InkWell conforms to feedback_button_no_animation preference; requires SettingRow GestureDetector→InkWell refactor.

---

## Area 3: density-pixels

| Option | Description | Selected |
|--------|-------------|----------|
| 36px (full alignment) | (Q1 row height — recommended, matches button) | |
| 40px (moderate) | (Q1 row height — balance density vs text comfort) | ✓ |
| spXs 4px (halved) | (Q2 horizontal padding — from spSm 8, inline token) | ✓ |

**User's choices:** D-09 40px, D-10 spXs 4px
**Notes:** User chose 40px (moderate) over 36px (full alignment) — balancing density vs text comfort; 36px is button density, 40px is row density (rows have text, buttons have icons). a11y < 44px but acceptable for desktop (control bar 36px precedent). spXs 4px halved from spSm 8 — consistent with row height reduction; spXs is inline padding token (30-UI-SPEC L40), conforms CF-06 tokens only.

---

## Area 4: see-through-thin-glass

| Option | Description | Selected |
|--------|-------------|----------|
| content 留 bgGlass (分层) | (Q1 thin glass surface — chrome controlBarBg + content bgGlass, recommended) | ✓ |
| 四 section 全切 controlBarBg | (Q1 thin glass surface — LAYOUT-05 字面, single token) | |
| 反向分层 (不推荐) | (Q1 thin glass surface — content controlBarBg, chrome bgGlass, violates VISUAL-01) | |
| 不预埋, Phase 32 重构 | (Q2 NAV-05 prewire — YAGNI, recommended) | ✓ |
| 预埋 Stack + 占位 | (Q2 NAV-05 prewire — avoid Phase 32 refactor) | |
| 预埋结构, 色推迟 | (Q2 NAV-05 prewire — middle path) | |

**User's choices:** D-11 content 留 bgGlass (layered), D-12 不预埋 (YAGNI)
**Notes:** D-11 layered — chrome solid (controlBarBg 4-shadow) + content thin (bgGlass see-through options); consistent with control bar's own layering (control bar is pure chrome, no content area). VISUAL-01 chrome + VISUAL-04 content both satisfied. Pitfall 3 naturally satisfied — content Container(color: bgGlass) inside GlassContainer does not stack second BackdropFilter. D-12 YAGNI — user explicitly distinguished D-03 (within-phase state-machine symmetry, prefer complete) from D-12 (cross-phase pre-wire, follow YAGNI); mature engineering judgment. Phase 31 content = simple Container(color: bgGlass), Phase 32 NAV-05 refactors to Stack + top/bottom covers.

---

## Claude's Discretion

- **panelSectionBg alias fate** — keep alias for content (single-swap-route) vs direct bgGlass; plan-phase implementation detail, Claude recommends keeping alias.
- **Chrome decoration method** — `ControlBarDecoration.playing` for panel chrome (恒定 4-shadow, visual alignment not state alignment); planner confirms.
- **D-07 a11y mitigation** — deeper accent or SemiBold weight for active value text; plan-phase based on contrast audit.

## Deferred Ideas

- **NAV-05 top/bottom thin glass covers** — Phase 32 (D-12 not pre-wired)
- **NAV-06 keyboard arrow glow feedback** — Phase 32 (D-05 focus semantics paves way)
- **NAV-07 single Focus root capture** — Phase 32 (D-05 unified focus row paves way)
- **D-07 a11y mitigation** — plan-phase based on contrast audit
- **panelSectionBg alias final form** — plan-phase implementation detail
