---
phase: 31
slug: visual-design-alignment
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-27
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `31-RESEARCH.md` `## Validation Architecture` (Nyquist Dimension 8).
> Per-task Task IDs (31-NN-MM) are filled by the planner; REQ→test mapping is pre-seeded below.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter 3.44.8 stable) |
| **Config file** | none — `flutter test` is zero-config |
| **Quick run command** | `D:/flutter/bin/flutter test test/widgets/panel_color_test.dart test/ui/shared/focusable_setting_row_test.dart test/ui/shared/control_bar_decoration_test.dart` |
| **Full suite command** | `D:/flutter/bin/flutter test` |
| **Estimated runtime** | ~30s quick / ~3-5min full suite (module-boundary discrimination) |

**Pre-existing failure baseline (NOT regression):** full suite has ~64 engine/kernel `mdk.dll` FFI failures (headless env, see memory `reference_mdk_dll_headless_test_failures`) + 4 pre-existing dialog failures (settings_nav_item 2 + settings_tab_content DropdownButton 2). Discrimination method: stash → HEAD baseline diff, OR by module boundary (Phase 31 only touches `lib/ui/` — engine/kernel failures are physically unreachable from this phase's changes).

---

## Sampling Rate

- **After every task commit:** Run quick run command (3-4 affected test files, <30s)
- **After every plan wave:** Run `D:/flutter/bin/flutter test` full suite (discriminate pre-existing failures by module boundary)
- **Before `/gsd-verify-work`:** Full suite green (zero new failures vs baseline) + §2 manual profile check passed
- **Max feedback latency:** 30 seconds (quick) / 5 minutes (full wave)

---

## Per-Task Verification Map

> Task IDs (31-NN-MM) are assigned by the planner in PLAN.md. REQ→behavior→test mapping pre-seeded from RESEARCH.md `### Phase Requirements → Test Map`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 31-NN-MM (TBD) | 01 | 1 | VISUAL-01 | — | N/A (pure UI visual, no input surface) | widget (re-baseline) | `flutter test test/widgets/panel_color_test.dart` | ✅ exists — re-baseline: chrome 3 sections assert `decoration` field (was `Container.color == panelSectionBg` L49-84); content keeps panelSectionBg | ⬜ pending |
| 31-NN-MM (TBD) | 02 | 1 | VISUAL-02 | — | N/A | widget | `flutter test test/ui/shared/focusable_setting_row_test.dart test/widget/settings/` | ⚠ partial — re-baseline 1px controlBarBorderWhite (was 2px borderHighlight); three-state + accent text assertions Wave 0 new | ⬜ pending |
| 31-NN-MM (TBD) | 03 | 1 | VISUAL-03 | — | N/A | widget | `flutter test test/ui/shared/settings_card_test.dart` (Wave 0 new) | ❌ Wave 0 — grep confirmed no existing height-42 assertion; net-new assertion | ⬜ pending |
| 31-NN-MM (TBD) | 04 | 1 | VISUAL-04 | — | N/A | widget | `flutter test test/widgets/panel_color_test.dart` (extended) | ⚠ partial — BackdropFilter count gate Wave 0 new | ⬜ pending |
| 31-NN-MM (TBD) | 05 | 1 | VISUAL-05 | — | N/A | unit | `flutter test test/ui/shared/control_bar_decoration_test.dart` (Wave 0 new) | ❌ Wave 0 new | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Additional Testable Properties (derived from RESEARCH areas 1-7)

| Property | Test Type | Method |
|----------|-----------|--------|
| BoxDecoration-no-layout-shift (§1) | widget | pump SettingRow → `focusNode.requestFocus()` → pump → assert render box height unchanged (40.0); reuse focusable_setting_row_test pattern |
| BackdropFilter-no-stacking perf (§2) | manual profile | §2 six-step protocol: profile mode + PerfMonitor per-frame sampling + drag/scroll + A/B exportStats baseline diff |
| focus-traversal-reachability (§4) | widget | `FocusTraversalGroup` inside shell + simulate Tab/arrow keys → assert each interactive SettingRow + GlassButton gets focus highlight in turn; assert InkWell produces no extra stop (exactly 1 per row) |
| decoration-extraction-API-stability (§5) | unit | `ControlBarDecoration.playing()` field-by-field vs transcribed spec (color/border/boxShadow.length==4/boxShadow[3].color==glowOuterRing/borderRadius==circular(22)); `playing(borderRadius: r)` override effective; `idle().boxShadow.length == 4` (tween compat hard constraint) |
| density-geometry (§7) | widget | SettingRow render box height == 40.0; **Phase 30 geometry assertions unchanged** (panel_size_test 16:9 formula unaffected — grep confirmed assertions only touch panel dimensions) |
| contrast-a11y (§6) | backstop | §6 theoretical calc on record (~3.4:1 vs 4.5 AA); if mitigation triggers, unit-test asserts active-value text color token == accentBlue |

---

## Wave 0 Requirements

- [ ] `test/ui/shared/control_bar_decoration_test.dart` — VISUAL-05 field-equivalence + API stability (new)
- [ ] `test/ui/shared/settings_card_test.dart` — VISUAL-02 three-state + VISUAL-03 density assertions (new or merged into existing settings test dir)
- [ ] `test/widgets/panel_color_test.dart` — re-baseline: chrome 3 sections decoration assertions + BackdropFilter count gate (modify existing)
- [ ] `test/ui/shared/focusable_setting_row_test.dart` — re-baseline: 1px controlBarBorderWhite border assertion (modify existing)
- [ ] Manual profile baseline: pre-refactor `flutter run --profile` + PerfMonitor `exportStats()` → save baseline JSON

*Wave 0 covers all MISSING references above (❌ Wave 0 rows).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| BackdropFilter no GPU readback stacking (perf) | VISUAL-04 (SC#4) | Requires profile-mode rendering + per-frame PerfMonitor sampling + visual drag/scroll interaction + A/B baseline diff — not assertable in headless widget test | §2 six-step protocol: (1) `flutter run --profile`; (2) PerfMonitor per-frame sampling on; (3) open settings panel; (4) drag/scroll option list; (5) `exportStats()` → JSON; (6) compare A (pre-refactor) vs B (post-refactor) frame times — no regression in jank metrics |
| chrome inter-section shadow seam (Pitfall 1) | VISUAL-01 | Visual aesthetic — 4-shadow decoration designed for floating single bar; stacked sections may show seam lines between title bar / tab strip / button bar | Open settings panel → screenshot → compare against control bar bottom edge; check for dark band/bright line between chrome sections. Mitigation if seen: D-04 `borderRadius` corner-only (title `vertical(top:)`, button `vertical(bottom:)`, tab strip `zero`) |
| accent #2C58F4 contrast on glass (a11y backstop) | VISUAL-02 (D-07) | Color-weak contrast is a perceptual judgment; theoretical calc ~3.4:1 < AA 4.5:1 — recorded risk, not a blocker | Visual check: view focused option row active-value text on glass background under various lighting; if unreadable, planner mitigation (deeper accent or SemiBold weight) — if triggered, unit-test asserts token == accentBlue |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (quick) / 5min (full)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (seeded by plan-phase 2026-07-27; validated by validate-phase §6)
