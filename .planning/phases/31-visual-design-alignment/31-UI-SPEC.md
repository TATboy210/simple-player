---
phase: 31
slug: visual-design-alignment
status: draft
shadcn_initialized: false
preset: none
created: 2026-07-27
---

# Phase 31 — UI Design Contract

> Visual and interaction contract for the settings panel chrome/option-row alignment to the
> control bar (VISUAL-01..05). This phase **extends Phase 30's structural params to chrome**:
> Phase 30 landed the container (16:9 / ~50% area, `panelSectionBg=bgGlass` placeholder
> unification); Phase 31 performs the actual switch to the `controlBar*` token family,
> extracts the shared decoration, establishes the option-row three-state, and tightens density.
> Design north star: 控制栏为视觉基准，面板是 adopter (control bar is the visual baseline,
> panel adopts its language).
> All CF + SC#1-5 + D-01..D-12 decisions from `31-CONTEXT.md` are pre-locked constraints,
> not open questions.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (custom `Tokens.*` design system, `lib/ui/theme/tokens.dart`) |
| Preset | not applicable — Flutter desktop project; shadcn gate skipped (not React/Next/Vite) |
| Component library | Flutter Material + project glass widgets (`GlassContainer`, `GlassButton`, `SettingRow`, `SettingsNavItem`) |
| Icon library | Material Icons (`Icons.*`) |
| Font | `Tokens.fontFamily` = SF Pro Display (Windows fallback Segoe UI); mono `Tokens.fontFamilyMono` = SF Mono |

**Theme:** Midnight (single compile-time const theme). All visual values via `Tokens.*` — hardcoded literals are a contract violation (CF-06).

---

## Spacing Scale

Declared values (existing `Tokens.*`, all multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| `Tokens.spXs` | 4 | **SettingRow horizontal padding (D-10, this phase)**; icon gaps, inline padding |
| `Tokens.spSm` | 8 | Compact element spacing; nav item vertical padding |
| `Tokens.spMd` | 12 | Default element spacing; title bar horizontal padding |
| `Tokens.spLg` | 16 | Section padding; tab strip normal spacing |
| `Tokens.spXl` | 24 | Layout gaps |

**Density edits this phase (D-09 / D-10, locked) — `lib/ui/shared/settings_card.dart` `SettingRow`:**

| Property | Current | Target | Source |
|----------|---------|--------|--------|
| Row height | 42 | **40** | D-09 — moderately compact; between 36px control bar button and 42px current |
| Horizontal padding | `spSm` (8) | **`spXs` (4)** | D-10 — halved, consistent with row height reduction |

Row height 40 is a multiple of 4 and matches the control bar density direction (control bar buttons are 36px; 40px balances density vs 14px body text comfort). Below the 44px a11y touch-target guideline — accepted for desktop per D-09 (control bar 36px precedent).

Exceptions: icon-only touch targets remain 48 (`Tokens.iconButtonSizeLarge`); title bar height 44; tab strip height 56 compact / 64 normal. All pre-existing, unchanged.

---

## Typography

Inherited from existing `Tokens.*` — **no typographic size/weight changes this phase**:

| Role | Size | Weight | Line Height | Usage in this phase |
|------|------|--------|-------------|---------------------|
| Body | 14 (`Tokens.fontBody`) | Regular 400 (`weightRegular`) | Flutter default (1.0) | SettingRow labels + values; option row text at new 40px height |
| Label | 14 normal / 12 compact (`tabBarFontNormal` / `tabBarFontCompact`) | Regular 400 | Flutter default | Tab strip labels (unchanged) |
| Heading | 14 (`Tokens.fontBody`) | SemiBold 600 (`weightSemiBold`) | Flutter default | Panel title 「设置」 (unchanged) |
| Display | 18 (`Tokens.fontTitle`) | SemiBold 600 | Flutter default | Not used by this phase |

**Active-value emphasis (D-07, locked):** the active value on a selected/focused option row switches its **text color** to `Tokens.accent` (#2C58F4) — color change only, same size/weight. Consistent with the tab selected-label tint precedent (30-UI-SPEC).

**A11y risk (recorded, plan-phase mitigation):** accent #2C58F4 on glass backgrounds may be insufficient contrast for color-weak users. Plan-phase may deepen the accent or apply `weightSemiBold` to the active value text after a contrast audit. Not a Phase 31 blocker (31-CONTEXT D-07).

Weight exception (pre-existing, not new): `Tokens.weightMedium` (500) on the selected tab label. Two primary weights (Regular 400 + SemiBold 600); Medium 500 is the selected-state emphasis already in the system.

---

## Color

The panel's color routing changes this phase. Values are all **existing tokens** — no new color values are introduced (SC#1: token names pre-locked exactly).

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `Tokens.bgDeep` #060810 / `Tokens.bgBase` #0C0F18 | Player backdrop visible around the centered overlay; scrim `Colors.black54` behind panel (unchanged) |
| Secondary (30%) — **chrome** | `Tokens.controlBarBg` 0x990E111E | **Panel chrome three sections** (title bar / tab strip / button bar) via `ControlBarDecoration.playing` (D-11) |
| Secondary (30%) — **content** | `Tokens.bgGlass` 0x8C0C0F18 (via `Tokens.panelSectionBg` alias) | **Content section only** — thin-glass see-through options (D-11, VISUAL-04) |
| Chrome border | `Tokens.controlBarBorderWhite` 0x0A6496FF | Panel chrome 1px border (playing decoration); **focused option-row glow border** (D-06) |
| Chrome outer ring | `Tokens.glowOuterRing` 0x0A5082FF | Panel chrome 4th shadow — blue outer ring (4-shadow decoration from `ControlBar._decorationPlaying`) |
| Accent (10%) | `Tokens.accent` #2C58F4 | Selected tab indicator bar, selected tab icon + label tint (existing); **active-value text on focused option rows (D-07, new)** |
| Destructive | `Tokens.danger` #FA3737 | Not used this phase — no destructive actions in the settings panel |

Accent reserved for: (1) selected-tab indicator bar, (2) selected-tab icon tint, (3) selected-tab label tint, (4) **active-value text color on focused option rows**. Nothing else.

Hover surface: `Tokens.bgHover` #283045 — option-row hover background (D-06) and nav item hover (pre-existing).

**Layered semantics (D-11, locked):** chrome = solid `controlBarBg` + 4-shadow decoration; content = thin `bgGlass`. This mirrors the control bar's own structure (control bar is pure chrome, no content area). Do NOT全切 `controlBarBg` onto the content section — that breaks VISUAL-04 see-through.

**Phase 30 boundary (CF / D-02):** Phase 30's `panelSectionBg = bgGlass` alias stays. Chrome sections stop reading `panelSectionBg` (they move to `ControlBarDecoration`); the content section keeps the `panelSectionBg` alias (recommended — preserves single-swap-route semantics for content; planner may alternatively point content directly at `bgGlass`, both satisfy CF-06).

---

## Shared Decoration Contract (VISUAL-01 / VISUAL-05 — D-01..D-04, locked)

**New file:** `lib/ui/shared/control_bar_decoration.dart` (D-01) — bidirectional reuse by `lib/ui/player/control_bar.dart` and `lib/ui/dialogs/settings/settings_overlay_shell.dart`. Shared generic layer depends on neither consumer.

**Class:** `ControlBarDecoration` (D-02 — directional naming; control bar = baseline, panel = adopter).

**API (D-03 / D-04, locked):**

| Member | Spec |
|--------|------|
| `playing({BorderRadius? borderRadius})` | Returns the 4-shadow `BoxDecoration` extracted verbatim from `ControlBar._decorationPlaying` (`control_bar.dart:21-49`): `color: controlBarBg`, `border: 1px controlBarBorderWhite`, shadows = [top inner highlight `controlBarBorderWhite` offset(0,-1), bottom inner shadow `controlBarShadowBlack` offset(0,1), outer drop `controlBarOuterShadow` blur 32 offset(0,8), blue outer ring `glowOuterRing` blur 1 spread 1]. Default radius = `Tokens.controlBarRadius` (22) — control bar calls no-arg. |
| `idle({BorderRadius? borderRadius})` | Returns the idle decoration extracted from `ControlBar._decorationIdle` (`control_bar.dart:52-73`): `controlBarBg` + 2% `controlBarBorderIdle` border + 4 padded shadows. Extracted for symmetry (D-03); used by `control_bar.dart` locally. |
| tween | **Stays local** in `control_bar.dart` (`_decorationTween`) — NOT extracted (D-03). Panel has no playing/idle animation. |

**Consumers:**

| Consumer | Call | Radius |
|----------|------|--------|
| `control_bar.dart` | `ControlBarDecoration.playing()` / `.idle()` | default `controlBarRadius` (22) |
| `settings_overlay_shell.dart` — chrome 3 sections (title bar / tab strip / button bar) | `ControlBarDecoration.playing(borderRadius: BorderRadius.circular(Tokens.radiusLg))` | `radiusLg` (22) override (D-04) |

**Panel chrome恒用 playing 装饰** — visual alignment, not state alignment (panel is not "playing"; the visual language is what transfers). Radius three-way inconsistency (`controlBarRadius` / `radiusLg` / `radiusLarge`) resolved by the `borderRadius` parameter (D-04); no token renames this phase.

---

## Option Row Three-State Contract (VISUAL-02 / VISUAL-03 — D-05..D-08, locked)

Target: control bar button three-state. `GlassButton` currently has only scale animation (no selected background) — three-state is **new**, established by this phase for both `SettingRow` and (as the target-state pattern) `GlassButton`.

**State semantics (D-05, locked):** `selected` = **focused row** (keyboard/gamepad navigation focus) — unified across all row types, paving Phase 32 NAV-06/07. NOT "row holding the active value".

| State | Background | Border | Text | Source |
|-------|-----------|--------|------|--------|
| Default | transparent (fused with panel section) | none | `textPrimary` label / `textSecondary` value (existing) | D-06 |
| Hover | `Tokens.bgHover` #283045 | none | unchanged | D-06 |
| Focused (selected) | transparent | **1px `Tokens.controlBarBorderWhite` blue glow border** | **active value text → `Tokens.accent` #2C58F4** | D-06 / D-07 |
| Pressed | InkWell built-in highlight + ripple | per focused/hover | unchanged | D-08 |

Notes:
- Flutter `BoxDecoration` border does not occupy layout (not CSS box-sizing) — the 1px focused border causes no row shift (D-06).
- Focused border + accent active-value text do not conflict — different visual dimensions (border vs text) (D-07).
- Pressed = InkWell built-in feedback, **no custom scale animation** — conforms to `feedback_button_no_animation` (D-08). Requires `SettingRow` refactor `GestureDetector` → `InkWell` (plan-phase implementation).
- Current 2-state (`AnimatedContainer` transparent→bgHover, height 42, padding spSm, `GestureDetector`) is replaced by: 3-state + height 40 + padding spXs + InkWell (`settings_card.dart`).

---

## See-Through Thin Glass Contract (VISUAL-04 — D-11 / D-12, locked)

**Pitfall-3 mitigation (SC#4, locked):** the panel's single `BackdropFilter` lives in `GlassContainer`. All section backgrounds use `Container(color:)` — **never a second `BackdropFilter`** (avoids GPU readback stacking). This applies to both chrome sections (which get `ControlBarDecoration` BoxDecoration, also no blur) and the content section.

| Section | Background | Blur |
|---------|-----------|------|
| Title bar (chrome) | `ControlBarDecoration.playing(radiusLg)` — `controlBarBg` solid | none (GlassContainer provides the one blur) |
| Tab strip (chrome) | same | none |
| Content | `Container(color: Tokens.panelSectionBg)` → `bgGlass` thin glass — see-through options | none |
| Button bar (chrome) | same as title bar | none |

**Phase 32 boundary (D-12, locked):** NAV-05 top/bottom thin-glass covers are **NOT pre-wired**. Phase 31 content = simple `Container(color: bgGlass)`; Phase 32 refactors to `Stack` + top/bottom covers. YAGNI — do not add the `Stack` wrapper this phase.

---

## Copywriting Contract

**No copy changes this phase.** All strings are existing (inherited from Phase 30 contract).

| Element | Copy |
|---------|------|
| Primary CTA | 「确定」 — apply pending settings and close (existing button bar: 取消 / 应用 / 确定) |
| Panel title | 「设置」 (fontBody SemiBold textPrimary) |
| Tab labels | 均衡器 / 音频 / 视频 / 通用 / 快捷键 / 关于 / 性能 (Phase 30 order, unchanged) |
| Empty state | Not applicable — settings tabs are always populated; no empty-data state exists in the panel |
| Error state | Not applicable — no new I/O this phase; visual token routing cannot fail at runtime |
| Destructive confirmation | None — 取消 discards pending settings without confirmation (existing deferred-apply behavior, unchanged) |

---

## UI Considerations

> State coverage for this visual-alignment phase. Resolved via `ui-consideration-probe.cjs` (Step 9.5) + researcher-authored interaction states. Idempotent — rows are REPLACED on a probe re-run.

Applicable state considerations resolved: **8 covered, 3 backstop, 0 unresolved, remainder dismissed (N/A)**.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| populated | panel chrome 3 sections (title/tab strip/button bar) | ✅ covered | Chrome renders `ControlBarDecoration.playing(radiusLg)` — `controlBarBg` + 1px `controlBarBorderWhite` border + 4 shadows incl. `glowOuterRing` outer ring; visually indistinguishable from control bar (VISUAL-01) |
| populated | content section | ✅ covered | Content renders `Container(color: panelSectionBg→bgGlass)` thin glass — options see-through; no second `BackdropFilter` (VISUAL-04, SC#4) |
| hover | option rows (`SettingRow`) | ✅ covered | Hover background = `Tokens.bgHover` #283045; borderless; default state fully transparent/fused (D-06) |
| focus | option rows (`SettingRow`) | ✅ covered | Focused row = 1px `controlBarBorderWhite` glow border + active value text `accent` #2C58F4; no layout shift (BoxDecoration border); unified focus semantics pave Phase 32 NAV-06/07 (D-05/D-06/D-07) |
| pressed | option rows (`SettingRow`) | ✅ covered | InkWell built-in highlight + ripple; no custom scale animation (`feedback_button_no_animation`); `GestureDetector`→`InkWell` refactor (D-08) |
| density | option rows (`SettingRow`) | ✅ covered | Row height 40px + horizontal padding `spXs` (4px) — control-bar-aligned density (D-09/D-10, VISUAL-03) |
| shared-token | `ControlBarDecoration` single-route | ✅ covered | New `lib/ui/shared/control_bar_decoration.dart`; playing+idle extracted, tween local; consumed by control bar (no-arg) + panel chrome (`radiusLg` override) (D-01..D-04, VISUAL-05) |
| test re-baseline | visual assertions | ✅ covered | SC#5 — Phase 30 size assertions unaffected (geometry unchanged); any decoration/color assertions on panel sections re-baselined to `controlBar*` routing |
| a11y contrast | accent #2C58F4 active-value text on glass | 🧪 backstop | Color-weak contrast risk recorded (D-07); plan-phase contrast audit may deepen accent or apply SemiBold — visual check, not a Phase 31 blocker |
| a11y touch target | 40px row height (< 44px guideline) | 🧪 backstop | Accepted desktop trade-off per D-09 (control bar 36px precedent); mouse/keyboard primary, not touch — visual check only |
| overflow | option-row value text at padding 4px | 🧪 backstop | Halved horizontal padding reduces text room; existing rows are short labels/values; content section scrollable — visual check only |
| empty / loading / error / partial / zero-one-many | settings tabs | ✗ dismissed | Static populated tabs, no async data, no variable count — same dismissal rationale as Phase 30 contract |
| long-text | tab labels / title / CTAs | ✗ dismissed | 2-3 char Chinese labels, fixed strings — no truncation path (Phase 30 precedent) |

<!-- Status vocabulary (locked by probe-core projectTruths):
     ✅ covered    → a plain truth string lifted into must_haves.truths
     🧪 backstop   → a flat scalar { statement, verification: backstop }; at verify time, no explicit
                     evidence → insufficient_spec → human_needed (never a silent pass, #1154)
     ✗ dismissed   → N/A for this surface (reason required, never silent); planner skips at verify
     ⚠ unresolved  → an explicit planner assumption (surfaced, never silently dropped)
     Rows are REPLACED (not appended) on a probe re-run — idempotent. -->

---

## Registry Safety

Not applicable — Flutter desktop project; shadcn is not initialized and the shadcn gate does not apply (tech stack is not React/Next.js/Vite). No third-party component registries, no new packages, no new FFI. All visual values route through existing `Tokens.*`.

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
