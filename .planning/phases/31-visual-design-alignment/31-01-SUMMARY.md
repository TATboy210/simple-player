---
phase: 31-visual-design-alignment
plan: 01
subsystem: ui/settings-panel-chrome
tags: [visual-alignment, decoration-extraction, glass, tokens]
requires:
  - Phase 30 panel geometry contract (16:9, panelSectionBg alias)
  - ControlBar._decorationPlaying / _decorationIdle 4-shadow spec
provides:
  - ControlBarDecoration shared static factory (playing/idle, borderRadius override)
  - Panel chrome 3-section shared decoration route (title/tab/button)
  - Single panel-level BackdropFilter structural gate
affects:
  - lib/ui/player/control_bar.dart (decoration source now shared)
  - lib/ui/dialogs/settings/settings_overlay_shell.dart (title + button bar)
  - lib/ui/dialogs/settings/tab_strip.dart (tab strip)
tech-stack:
  added: []
  patterns:
    - Shared static BoxDecoration factory with corner-only radius override
    - Chrome/content layered color routing (controlBarBg chrome + bgGlass content)
key-files:
  created:
    - lib/ui/shared/control_bar_decoration.dart
    - test/ui/shared/control_bar_decoration_test.dart
  modified:
    - lib/ui/player/control_bar.dart
    - lib/ui/dialogs/settings/settings_overlay_shell.dart
    - lib/ui/dialogs/settings/tab_strip.dart
    - test/widgets/panel_color_test.dart
    - test/ui/dialogs/settings_overlay_shell_test.dart
decisions:
  - D-01/D-02 honored: ControlBarDecoration in lib/ui/shared, directional naming
  - D-03 honored: playing+idle extracted, DecorationTween stays local in ControlBar
  - D-04 honored: playing({BorderRadius?}) defaults to Tokens.controlBarRadius
  - D-11 honored: chrome 3 sections controlBarBg decoration, content stays panelSectionBg→bgGlass
  - D-12 honored: no Stack wrapper or navigation covers added
metrics:
  duration: ~35 min
  completed: 2026-07-28
  tasks: 2/2
  tests: 16/16 mandated pass (11 decoration unit + 5 panel color/blur); 86/86 shell-adjacent collateral pass
status: complete
---

# Phase 31 Plan 01: Shared Control-Bar Decoration + Panel Chrome Routing Summary

Extracted the control bar's 4-shadow glass decoration into a shared `ControlBarDecoration` factory and routed all three settings-panel chrome sections (title bar, tab strip, button bar) through it with corner-only radii, while content stays thin `bgGlass` and the panel keeps exactly one top-level blur layer.

## Performance Baseline (for Plan 03 A/B comparison)

**Pre-change baseline artifact:** `.planning/phases/31-visual-design-alignment/perf-baseline-pre.json` (pre-existing, captured before this plan — profile-mode run not re-executed per orchestrator instruction).

| Metric | Pre-change value |
|--------|------------------|
| frameCount | 300 |
| build.avgMs | 0.39 |
| build.maxMs | 2.68 |
| **raster.avgMs** | **1.85** |
| raster.maxMs | 17.45 |

Plan 03 threshold: post-change `raster.avgMs` must be ≤ **2.85ms** (baseline + 1ms).

## Task Results

### Task 1 (tracer): Extract and prove one title-bar chrome route end to end — commit `e0e1bd00`

- Created `lib/ui/shared/control_bar_decoration.dart`: `ControlBarDecoration` with private ctor `._()` and static `playing({BorderRadius? borderRadius})` / `idle({BorderRadius? borderRadius})`. 4 BoxShadow values copied verbatim from `ControlBar._decorationPlaying` / `_decorationIdle`; idle retains its 2 transparent padding shadows (DecorationTween index-lerp hard constraint, Pitfall 4). Default radius `BorderRadius.circular(Tokens.controlBarRadius)` (D-03/D-04).
- `lib/ui/player/control_bar.dart`: cached `_decorationPlaying` / `_decorationIdle` now call the shared factories; `_decorationTween` stays local (D-03); EdgeGlow, blur ClipRRect+BackdropFilter, and top-gradient DecoratedBox ownership unchanged.
- `settings_overlay_shell.dart` title bar: `color: Tokens.panelSectionBg` → `decoration: ControlBarDecoration.playing(borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg)))`. GlassContainer / RepaintBoundary / FocusTraversalGroup / root Focus / content route / panel geometry untouched.
- New `test/ui/shared/control_bar_decoration_test.dart` — 11 field-equivalence assertions (4-shadow count, color, 1px border, glowOuterRing at index 3, shadow 0/1/2 field equality vs spec, default + overridden radius, idle 4-shadow, tween locality source assertion). 11/11 pass.

### Task 2 (auto): Expand shared chrome routing and re-baseline the panel contract — commit `c1b023ac`

- Button bar → `ControlBarDecoration.playing(borderRadius: BorderRadius.vertical(bottom: Radius.circular(Tokens.radiusLg)))`.
- Tab strip root → `ControlBarDecoration.playing(borderRadius: BorderRadius.zero)`.
- Content `ColoredBox(color: Tokens.panelSectionBg)` unchanged (resolves to `bgGlass`); no Stack wrapper / navigation covers (D-12); no Tokens/sizing/tab-sequence/root-focus/GlassContainer/RepaintBoundary changes.
- Re-baselined `test/widgets/panel_color_test.dart`: chrome 3 sections assert BoxDecoration fields (controlBarBg + 1px controlBarBorderWhite + 4-shadow ending glowOuterRing) across compact/default/fullscreen sizes; content ColoredBox assertion and `panelSectionBg == bgGlass` alias contract retained; added single-top-level-BackdropFilter gate. 5/5 pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] BackdropFilter gate re-scoped to panel-ancestor chain**
- **Found during:** Task 2 verify
- **Issue:** Plan/RESEARCH §2 specified a panel-*subtree* `find.byType(BackdropFilter)` count of exactly 1. That premise is factually wrong: tab-content cards (General/Video/Audio/EQ/About/Performance/Shortcuts tabs) each instantiate `GlassContainer` with default `blurEnabled: true`, so the shell subtree legitimately contains many BackdropFilters (pre-existing since Phase 25). The subtree assertion failed with "too many".
- **Fix:** Scoped the gate to `find.ancestor(of: find.byKey(SettingsOverlayShell.panelKey), matching: find.byType(BackdropFilter)) == findsOneWidget` — asserting exactly one *panel-level* blur wraps the sizing box. This preserves the SC#4 / T-31-02 intent: this phase's chrome (BoxDecoration) and content (ColoredBox) changes add zero new blur layers, and any future second panel-level blur goes red immediately.
- **Files modified:** `test/widgets/panel_color_test.dart`
- **Commit:** `c1b023ac`

**2. [Rule 1 - Bug] Re-baselined settings_overlay_shell_test.dart 30-03 group**
- **Found during:** Task 2 collateral check
- **Issue:** The plan scoped re-baselining to `panel_color_test.dart` only, but the 30-03 group in `settings_overlay_shell_test.dart` asserts the identical color-route contract (`container.color == Tokens.panelSectionBg` for chrome sections). After the intentional chrome switch, it failed as a false regression (Pitfall 5 materialized at the second assertion site).
- **Fix:** Re-baselined the 30-03 group to the same chrome/content split (BoxDecoration field assertions for chrome 3 sections, content ColoredBox assertion retained), keeping the group name for continuity.
- **Files modified:** `test/ui/dialogs/settings_overlay_shell_test.dart`
- **Commit:** `c1b023ac`

## Test Evidence

- **Mandated (exit 0):** `D:/flutter/bin/flutter test test/ui/shared/control_bar_decoration_test.dart test/widgets/panel_color_test.dart` — **16/16 pass**.
- **Collateral (shell-adjacent):** settings_overlay_shell_test, panel_size_test, multi_monitor_clamp_test, tab_strip_order_test, settings_responsive_scaling_test — **86/86 pass** (cumulative with the 16).
- **Analyze:** `flutter analyze` on all changed lib/test files — no issues.
- **Pre-existing failures (NOT caused by this plan, stash-verified):** `test/ui/dialogs/settings_focus_navigation_test.dart` compile error (`FakePlaybackController(initiallyPlaying:)` param mismatch) exists with our changes stashed; ~57 mdk.dll FFI headless failures + 4 Phase 25 dialog failures per documented baseline.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema changes. T-31-01 mitigated (field-equivalence tests lock the 4-shadow spec; both consumers call the same factory). T-31-02 mitigated (single panel-level BackdropFilter gate added; profile A/B deferred to Plan 03).

## Self-Check: PASSED

- FOUND: `lib/ui/shared/control_bar_decoration.dart`
- FOUND: `test/ui/shared/control_bar_decoration_test.dart`
- FOUND: commits `e0e1bd00` (Task 1) and `c1b023ac` (Task 2) in `git log`
- FOUND: `.planning/phases/31-visual-design-alignment/perf-baseline-pre.json` (raster.avgMs = 1.85ms)
- Mandated verify exits 0 with 16/16 pass.
