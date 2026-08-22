# Phase 31: visual-design-alignment - Pattern Map

**Mapped:** 2026-07-27
**Files analyzed:** 9 (1 new lib + 4 modified lib + 2 new test + 2 modified test)
**Analogs found:** 9 / 9 (this phase is extraction/refactor of existing seams — every file has a live analog or is its own source)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/ui/shared/control_bar_decoration.dart` (NEW) | utility (decoration token) | static spec | `lib/ui/player/control_bar.dart` L18-79 (extraction source) | exact (source-of-truth) |
| `lib/ui/player/control_bar.dart` (MODIFY) | component | request-response (state-driven decoration) | self — replace inline fields with shared calls | exact |
| `lib/ui/shared/settings_card.dart` (MODIFY) | component | event-driven (hover/focus/press) | `lib/ui/shared/focusable_setting_row.dart` (border toggle) + `lib/ui/shared/glass_container.dart` L282-313 (`GlassButton._buildIconOnly` InkWell+Material precedent) | exact |
| `lib/ui/dialogs/settings/settings_overlay_shell.dart` (MODIFY) | component (shell) | static layout | `lib/ui/player/control_bar.dart` `_decorationPlaying` (L21-49) | exact |
| `lib/ui/shared/glass_container.dart` (MODIFY, GlassButton selected bg) | component | event-driven | `lib/ui/shared/focusable_setting_row.dart` L94-104 (border-toggle pattern) | role-match |
| `lib/ui/dialogs/settings/tab_strip.dart` (MODIFY) | component | static layout | `settings_overlay_shell.dart` L304-311 (button bar `color:` → `decoration:` swap) | exact |
| `test/ui/shared/control_bar_decoration_test.dart` (NEW) | test (unit) | field-equality | `test/widgets/panel_color_test.dart` L130-137 (alias contract test style) | role-match |
| `test/ui/shared/settings_card_test.dart` (NEW) | test (widget) | three-state + geometry | `test/ui/shared/focusable_setting_row_test.dart` (pumpRow harness, AAA) | exact |
| `test/widgets/panel_color_test.dart` (MODIFY) | test (widget) | color-route contract | self — L49-84 four-section assertion to re-baseline | exact |
| `test/ui/shared/focusable_setting_row_test.dart` (MODIFY) | test (widget) | focus border | self — 2px borderHighlight assertions to re-baseline | exact |

## Pattern Assignments

### `lib/ui/shared/control_bar_decoration.dart` (NEW — utility, static decoration spec)

**Analog / extraction source:** `lib/ui/player/control_bar.dart` L18-79. Verbatim spec already transcribed in 31-RESEARCH.md §5 (planner can copy directly). Key invariants:

**Imports pattern** (control_bar.dart L1-2, 5):
```dart
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
```

**Core pattern — 4-shadow playing decoration** (control_bar.dart L21-49, extract verbatim into `static BoxDecoration playing({BorderRadius? borderRadius})`):
```dart
BoxDecoration(
  color: Tokens.controlBarBg,
  borderRadius: borderRadius ?? _defaultRadius, // default: circular(Tokens.controlBarRadius)
  border: Border.all(color: Tokens.controlBarBorderWhite, width: 1),
  boxShadow: const [
    BoxShadow(color: Tokens.controlBarBorderWhite, blurRadius: 0, spreadRadius: 0, offset: Offset(0, -1)), // 顶部内高光
    BoxShadow(color: Tokens.controlBarShadowBlack, blurRadius: 0, spreadRadius: 0, offset: Offset(0, 1)),  // 底部内阴影
    BoxShadow(color: Tokens.controlBarOuterShadow, blurRadius: 32, offset: Offset(0, 8)),                  // 外层投影
    BoxShadow(color: Tokens.glowOuterRing, blurRadius: 1, spreadRadius: 1),                                // 蓝色外环
  ],
)
```

**Hard constraint — idle MUST keep 4 shadows** (control_bar.dart L52-73, comment L69): `idle()` keeps the 2 transparent padding shadows so `DecorationTween` index-lerp does not break (Pitfall 4). Class shape per RESEARCH §5: private constructor `ControlBarDecoration._();` + two static methods. Full verbatim target code: **31-RESEARCH.md lines 153-199**.

**NOT extracted** (stays in control_bar.dart): `EdgeGlow` wrapper (L121-123), `_buildBlur` ClipRRect+BackdropFilter (L208-231), top gradient light `DecoratedBox` (L137-152), `_decorationTween` (L76-79, D-03).

---

### `lib/ui/player/control_bar.dart` (MODIFY — component)

**Analog:** self. Replace L18-73 field bodies with calls to shared class; keep `static final` caching precedent (L18/21 comment "D-01: static final 缓存"):

```dart
// After refactor (D-03: tween stays local, built from shared):
static final _borderRadius = BorderRadius.circular(Tokens.controlBarRadius);
static final _decorationPlaying = ControlBarDecoration.playing();
static final _decorationIdle = ControlBarDecoration.idle();
static final _decorationTween = DecorationTween(begin: _decorationIdle, end: _decorationPlaying);
```

Consumer at L116-119 (`_decorationTween.evaluate(decoration!)`) unchanged. Add import `../shared/control_bar_decoration.dart`.

---

### `lib/ui/shared/settings_card.dart` (MODIFY — component, three-state + density)

**Analog 1 — InkWell + Material transparency wrapper** (from `lib/ui/shared/glass_container.dart` L292-313, `GlassButton._buildIconOnly`; also `control_bar.dart` L124 `Material(color: Colors.transparent)`):
```dart
Material(
  color: Colors.transparent,
  borderRadius: GlassButton._radiusBtn,
  child: InkWell(
    onTap: widget.enabled ? widget.onPressed : null,
    hoverColor: widget.enabled ? Tokens.bgHover : Colors.transparent,
    highlightColor: Colors.transparent,
    borderRadius: GlassButton._radiusBtn,
    splashFactory: NoSplash.splashFactory,   // GlassButton precedent; RESEARCH §3 recommends
    child: Center(child: content),           // (b) splashColor: Tokens.accentLight for SettingRow
  ),
)
```

**Analog 2 — focus border toggle without layout shift** (from `lib/ui/shared/focusable_setting_row.dart` L94-104 — live zero-shift evidence per RESEARCH §1):
```dart
// D-13: 焦点边框即时切换，无动画 — 使用 Container 而非 AnimatedContainer
child: Container(
  decoration: BoxDecoration(
    color: showHoverBg ? Tokens.bgHover : Colors.transparent,
    border: Border.all(
      color: borderColor,   // _focused ? Tokens.borderHighlight : Colors.transparent
      width: 2,             // Phase 31: → width 1, color Tokens.controlBarBorderWhite (D-06)
    ),
    borderRadius: BorderRadius.circular(Tokens.radiusSm),
  ),
  child: widget.child,
)
```

**Refactor deltas in `_SettingRowState.build` (current L42-117):**
- DELETE: `GestureDetector` (L55-63), `AnimatedContainer` (L64-71), `Transform.scale` + `_pressed` state (L72-73, L39) — D-08 removes custom scale
- REPLACE with `Material(type: transparency)` + `InkWell(canRequestFocus: false, autofocus: false)` (Pitfalls 2/3)
- height `42` → `40` (L66, D-09); padding `Tokens.spSm` → `Tokens.spXs` (L67, D-10)
- Active-value accent text (D-07): wire via new optional `FocusableSettingRow.focusedBuilder(BuildContext, bool focused)` (RESEARCH §4 recommendation; keeps existing `child` API + all tests green)

**Wrapper rows unchanged:** `SettingSwitchRow` (L130-162) and `SettingSpinRow` (L179-226) patterns stay — they delegate to `SettingRow`.

---

### `lib/ui/dialogs/settings/settings_overlay_shell.dart` (MODIFY — chrome 2 of 3 sections)

**Analog:** swap `color:` for `decoration:` on existing Containers. Current seams:

**Button bar** (L304-311):
```dart
return Container(
  key: SettingsOverlayShell.buttonBarKey,
  padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd, vertical: Tokens.spSm),
  color: Tokens.panelSectionBg,   // → decoration: ControlBarDecoration.playing(borderRadius: BorderRadius.vertical(bottom: Radius.circular(Tokens.radiusLg)))
  ...
```

**Title bar** (L353-356):
```dart
child: Container(
  height: 44,
  padding: const EdgeInsets.symmetric(horizontal: Tokens.spMd),
  color: Tokens.panelSectionBg,   // → decoration: ControlBarDecoration.playing(borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg)))
```

**Corner-only radii per RESEARCH §5 / Pitfall 1** (segment shadow-seam mitigation): title bar `vertical(top:)`, button bar `vertical(bottom:)`, tab strip `BorderRadius.zero`.

**DO NOT TOUCH:** `FocusTraversalGroup` + `Focus(autofocus: true, onKeyEvent: keyBindings.handle)` (L265-268 — NAV-07 root, Phase 31 must not add competing focus roots); `RepaintBoundary` (L264); `GlassContainer(radiusLg)` (L269-272); content section (`SettingsTabContent`, keeps `panelSectionBg` per D-11).

---

### `lib/ui/dialogs/settings/tab_strip.dart` (MODIFY — chrome section 3)

**Analog:** same swap as shell. Current L71-73:
```dart
return Container(
  height: isCompact ? 56 : 64,
  color: Tokens.panelSectionBg,   // → decoration: ControlBarDecoration.playing(borderRadius: BorderRadius.zero)
```

---

### `lib/ui/shared/glass_container.dart` (MODIFY — GlassButton selected bg, planner-scoped per RESEARCH A5)

**Analog:** `FocusableSettingRow` border-toggle (L94-104 above). `GlassButton` current state: scale animation only (L230-272), InkWell with `NoSplash` + `hoverColor: Tokens.bgHover` (L298-309). Selected background is NEW (D-05 target state) — add a `selected` field and a background color branch on the `Material`/InkWell path, following the same instant-toggle (no animation) precedent. Conservative recommendation (RESEARCH Open Q3): this phase may defer GlassButton selected bg to Phase 32 NAV-06 batch; only SettingRow three-state is a hard SC requirement.

---

### Tests (Wave 0)

**`test/ui/shared/control_bar_decoration_test.dart` (NEW, unit).** Analog: alias-contract test style in `test/widgets/panel_color_test.dart` L130-137 (pure `expect` on Tokens, no pump). Assertions per RESEARCH Validation §: `playing()` field-equality vs transcribed spec (color == `Tokens.controlBarBg`, border width 1 / color `controlBarBorderWhite`, `boxShadow.length == 4`, `boxShadow[3].color == Tokens.glowOuterRing`, `borderRadius == BorderRadius.circular(Tokens.controlBarRadius)`); `playing(borderRadius: r)` override effective; `idle().boxShadow.length == 4` (tween-compat hard constraint).

**`test/ui/shared/settings_card_test.dart` (NEW, widget).** Analog — pump harness + AAA from `test/ui/shared/focusable_setting_row_test.dart` L11-32:
```dart
Future<void> pumpRow(WidgetTester tester, {required Widget child, ...}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FocusableSettingRow(enabled: enabled, ..., child: child),
      ),
    ),
  );
}
```
Assertions: render box height == 40.0 (VISUAL-03); default transparent / hover `bgHover` / focused 1px `controlBarBorderWhite` + accent text (VISUAL-02); `find.byType(InkWell)` present, no `GestureDetector` in SettingRow subtree; no height shift on focus (pump → `focusNode.requestFocus()` → pump → height equal, pattern per focusable_setting_row_test L46-70).

**`test/widgets/panel_color_test.dart` (MODIFY).** Re-baseline `expectFourSectionsRouteToPanelSectionBg` (L51-85): chrome 3 sections switch from `container.color == Tokens.panelSectionBg` to `container.decoration` field assertions (cast to `BoxDecoration`, assert `.color == Tokens.controlBarBg`); content ColoredBox assertion (L78-84) UNCHANGED. Alias contract test (L130-137) unchanged. Add BackdropFilter count gate: `expect(find.byType(BackdropFilter), findsOneWidget)` in panel subtree (VISUAL-04, RESEARCH §2).

**`test/ui/shared/focusable_setting_row_test.dart` (MODIFY).** Re-baseline border assertions: width 2 → 1, color `Tokens.borderHighlight` → `Tokens.controlBarBorderWhite`. Harness (L11-32) and D-15 disabled tests (L72-119) unchanged.

## Shared Patterns

### Tokens-only visual values (CF-06)
**Source:** `lib/ui/theme/tokens.dart` — all 16 tokens verified live (RESEARCH §7 table with line numbers). **Apply to:** every file in this phase. No hardcoded colors/spacing; no new token values needed.

### Material(type: transparency) + InkWell on glass
**Source:** `lib/ui/shared/glass_container.dart` L292-313; `lib/ui/player/control_bar.dart` L124-125.
**Apply to:** `settings_card.dart` SettingRow refactor (D-08).
```dart
Material(
  color: Colors.transparent,
  child: InkWell(
    canRequestFocus: false,   // Pitfall 3 — FocusableSettingRow is sole focus owner
    autofocus: false,
    hoverColor: Tokens.bgHover,
    ...
  ),
)
```

### Single-focus-owner invariant (D-05 → Phase 32 paving)
**Source:** `lib/ui/shared/focusable_setting_row.dart` L79-92 (`FocusableActionDetector` + `onFocusChange`) + `settings_overlay_shell.dart` L265-268 (single root `Focus`).
**Apply to:** all row widgets. Invariants (RESEARCH §4): (1) exactly one focus node per row; (2) focus signal via `onFocusChange` single route; (3) no new competing Focus roots in shell.

### BackdropFilter non-stacking (SC#4)
**Source:** `lib/ui/shared/glass_container.dart` L158/167 is the panel subtree's ONLY blur.
**Apply to:** `settings_overlay_shell.dart`, `tab_strip.dart` — chrome/content changes use `Container(color:)` / `BoxDecoration` only (paint-path children of the single GlassContainer blur). Never add a second `BackdropFilter`.

### Instant border toggle, no AnimatedContainer (D-13 precedent)
**Source:** `lib/ui/shared/focusable_setting_row.dart` L93-104.
**Apply to:** `settings_card.dart`, `glass_container.dart` — focus/selected visual changes switch instantly to avoid sub-pixel jitter during interpolation.

## No Analog Found

None — every file maps to a live seam (this phase is extraction + token re-routing of existing code).

## Metadata

**Analog search scope:** `lib/ui/player/`, `lib/ui/shared/`, `lib/ui/dialogs/settings/`, `lib/ui/theme/`, `test/ui/shared/`, `test/widgets/`
**Files scanned:** 8 (control_bar, settings_card, focusable_setting_row, settings_overlay_shell, glass_container, tab_strip, panel_color_test, focusable_setting_row_test) + 31-RESEARCH.md verbatim spec (§5) as extraction source
**Pattern extraction date:** 2026-07-27
