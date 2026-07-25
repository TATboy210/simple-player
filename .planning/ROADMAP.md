# Roadmap: Simple Player — 设置面板横向重构 + 音频功能填充 (v4.5)

**Milestone:** v4.5 设置面板横向重构 + 音频功能填充
**Phases:** 7 (Phase 28–34, continuing from v4.0 Phase 27 — do NOT reset numbering)
**Granularity:** standard (config.json). 7 phases instead of the 4–6 standard band because each phase delivers exactly one PROJECT.md target feature (or the prerequisite refactor / safety fix); compressing would mix unrelated features across independent delivery boundaries. Same natural-boundary justification as v3.0's 8-phase (15–22) roadmap.
**Coverage:** 35/35 v1 requirements mapped ✓ — 0 orphaned, 0 duplicated
**Confidence:** HIGH (grounded in live code per `research/SUMMARY.md`; one kernel-audio filter gap flagged for Phase 33 research)

## Overview

**Milestone goal:** Take the v4.0 settings framework (~70% built) to product-grade by (a) splitting the near-cap shell first, (b) switching auto-pause to an always-on safety policy, (c) re-containerizing to 16:9 / 50%-area overlay with General tab in the middle, (d) unifying all panel chrome to control-bar glass language, (e) adding input-mode-aware navigation with end-cap arrows, (f) filling the audio tab with EQ / balance / sync / normalization via the existing `MediaEngine.setEqualizer(af)` entry, and (g) adding a control-bar audio-track button symmetric to the subtitle button. v4.5 ships only the audio tab — video / subtitle / playback tabs stay `SettingRow` placeholders (scope boundary).

**Build order rationale (summary):**
1. **Split before features (Phase 28 first)** — Pitfalls hard rule: `settings_overlay_shell.dart` is 517 lines (near the 500-line cap); v4.5 adds ~300 lines. Split + delete legacy panel BEFORE any feature lands or mid-feature refactor becomes impossible.
2. **Auto-pause early (Phase 29)** — Features MVP order + Pitfalls precision. One-line policy change (widened to `MediaState _preOpenState` snapshot) unblocks safe iteration on every subsequent phase — panel open no longer races playback state.
3. **Layout → Visual → Navigation (Phases 30 → 31 → 32)** — Features dependency graph: Features 2, 3, 5 all live INSIDE the Feature 1 container; Feature 3 depends on 1 + 2. Container → chrome → navigation polish is the only valid order.
4. **Audio last (Phases 33 → 34, parallelizable)** — Independent of layout / navigation work. Heaviest feature (Audio Tab) and mechanical feature (Control-Bar Button) can ship in parallel; both depend only on the Phase 30 container. `config.json parallelization: true` permits this.

**Risk profile (summary):** LOW (28, 29) → LOW-MEDIUM (30, 34) → MEDIUM (31, 33) → MEDIUM-HIGH (32, highest). All risks have concrete mitigations documented in `research/SUMMARY.md` Pitfalls 1–12.

## Phases

- [ ] **Phase 28: Settings Shell Split + Legacy Deletion** - Prerequisite refactor: split 517-line shell into 3 files + delete legacy 88px-sidebar panel
- [ ] **Phase 29: Auto-Pause Always** - Panel-open always pauses (wasPlaying guard dropped); MediaState snapshot for safe resume
- [ ] **Phase 30: Panel Layout Redesign** - 16:9 / 50%-area overlay + General tab middle + multi-monitor clamp
- [ ] **Phase 31: Visual Design Alignment** - Panel chrome + option rows aligned to control-bar glass / edge-glow / three-state
- [ ] **Phase 32: Navigation & Interaction Polish** - End-cap arrows + InputModeDetector + hint substitution + raw LB/RB binding deletion
- [ ] **Phase 33: Audio Settings Tab** - EQ / balance / sync / normalization via single af string, pure deferred-apply
- [ ] **Phase 34: Control Bar Audio Track Switching** - Headphones button + track popup menu symmetric to subtitle button

## Phase Details

### Phase 28: Settings Shell Split + Legacy Deletion
**Goal**: Consolidate the settings panel onto a single split, maintainable shell by extracting the 517-line shell into three focused files and deleting the legacy 88px-sidebar panel before any v4.5 feature lands.
**Depends on**: Nothing (first v4.5 phase; v4.0 Phase 27 complete)
**Requirements**: REFAC-01, REFAC-02
**Success Criteria** (what must be TRUE):
  1. `settings_overlay_shell.dart` split into `tab_strip.dart` + `tab_content.dart` + `panel_key_bindings.dart`, each under 300 lines, with zero behavior change (existing settings tests still green)
  2. Legacy `settings_panel.dart` deleted; `grep -r "SettingsPanel(" lib/ test/` returns zero production callers (legacy-only tests migrated to the `settings/` framework path)
  3. Full test suite green (`flutter test`); no new dependencies added to pubspec
**Blocking Constraints honored**: 设计北极星 (refactor preserves control-bar alignment target, no visual drift); file size cap (CLAUDE.md <500 lines convention, kernel <350); zero new dependencies; ValueNotifier unchanged
**Plans**: 1 plan
Plans:
- [ ] 28-01-PLAN.md — Extract the settings shell collaborators and remove the legacy sidebar panel with full regression coverage
**UI hint**: yes

### Phase 29: Auto-Pause Always
**Goal**: Make panel-open always pause playback (regardless of pre-open state) and resume only when the snapshot proves the media was actually playing — so every subsequent phase can iterate without racing playback state.
**Depends on**: Phase 28 (split shell gives a clean edit surface in `settings_panel_controller.dart`)
**Requirements**: PAUSE-01, PAUSE-02, PAUSE-03, PAUSE-04
**Success Criteria** (what must be TRUE):
  1. `SettingsPanelController.open()` unconditionally calls `pause()` — the `if (_wasPlaying)` guard is removed (PAUSE-01)
  2. `bool _wasPlaying` widened to `MediaState _preOpenState` snapshot taken at `open()`; `close()` resumes ONLY when `_preOpenState == MediaState.playing` (PAUSE-02, PAUSE-03)
  3. Four sub-race widget tests pass: loading→open→close→assert `play()` NOT called; EOF→open→close→assert NO-RESUME; manual-pause→open→close→assert NO-RESUME; playing→open→close→assert resume (PAUSE-04)
  4. `SettingsPanelPlayback` seam interface unchanged — zero kernel interface expansion, no new `MediaEngine` direct dependency
**Blocking Constraints honored**: zero kernel interface expansion (seam unchanged); deferred-apply seam preserved; Windows primary platform; ValueNotifier unchanged
**Plans**: TBD
**UI hint**: yes

### Phase 30: Panel Layout Redesign
**Goal**: Re-containerize the settings overlay to 16:9 / ~50% screen area with the General tab in the middle of the tab sequence and multi-monitor drag clamping.
**Depends on**: Phase 28 (split shell provides the sizing seam); Phase 29 (safe to iterate with always-pause active)
**Requirements**: LAYOUT-01, LAYOUT-02, LAYOUT-03, LAYOUT-04, LAYOUT-05
**Success Criteria** (what must be TRUE):
  1. Panel sized by `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]` — 16:9 as primary constraint, 50% area as secondary (PRODUCT decision固化 per LAYOUT-02)
  2. General (通用) tab rendered at the MIDDLE position of the 7-tab sequence (not first/last)
  3. Multi-monitor drag clamps to `display_enumerator` work-area (not `MediaQuery`); panel never lands on a non-primary monitor's bezel gap
  4. Panel upper/middle/lower vertical structure uses unified control-bar color (coordinated with VISUAL-01 in Phase 31)
  5. Size-assertion widget tests re-baselined to the 16:9 formula; existing tab-strip tests still green
**Blocking Constraints honored**: overlay mode (16:9 / 50% area, not standalone window); Windows primary; multi-monitor clamp via existing FFI (no new deps); Tokens.* (no hardcoded sizes)
**Plans**: TBD
**UI hint**: yes

### Phase 31: Visual Design Alignment
**Goal**: Make the panel chrome and option rows visually indistinguishable from the control bar — same glass, edge-glow, button three-states, and tighter density.
**Depends on**: Phase 30 (container exists at 16:9; tokens can be applied to sized chrome)
**Requirements**: VISUAL-01, VISUAL-02, VISUAL-03, VISUAL-04, VISUAL-05
**Success Criteria** (what must be TRUE):
  1. Panel chrome swaps `Tokens.bgGlass` → `controlBarBg` + `controlBarBorderWhite` + `glowOuterRing` (4-shadow decoration from `ControlBar._decorationPlaying`)
  2. Option rows render default borderless (no white glow); highlight ONLY on hover/select (control-bar button three-state: default / hover / selected)
  3. Single shared `PanelDecoration` / `ControlBarDecoration` token extracted — color unification is single-route, no duplicate decoration builders
  4. Thin-glass "透看选项" translucency faked with `Container(color: Tokens.bgGlass)` — ZERO additional `BackdropFilter` layers stacked on the panel (Pitfall 3 mitigation)
  5. BackdropFilter stacking perf: panel keeps ONE `BackdropFilter` + `RepaintBoundary`; no jank during drag/scroll (manual profile-mode check on Windows)
**Blocking Constraints honored**: 设计北极星 (control-bar alignment is the north star); Tokens.* design system (no hardcoded colors); BackdropFilter stacking mitigation (Pitfall 3); file size cap (shared token reduces decoration duplication)
**Plans**: TBD
**UI hint**: yes

### Phase 32: Navigation & Interaction Polish
**Goal**: Add end-cap rounded L/R tab arrows, input-mode-aware hint substitution (keyboard vs gamepad), and top/bottom thin-glass option-list arrows with keyboard glow feedback — the only new v4.5 infrastructure lives here.
**Depends on**: Phase 30 (horizontal strip to attach arrows); Phase 31 (visual alignment so arrows / glow match control bar)
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07
**Success Criteria** (what must be TRUE):
  1. End-cap rounded vertical L/R arrow buttons persistently visible + clickable + keyboard ←/→ switches tab
  2. `InputModeDetector` singleton `ValueNotifier<InputMode>{keyboard, gamepad, auto}` with heuristic (PointerMoveEvent → keyboard; arrow-keys-with-no-mouse-5s → gamepad) + toggle fallback — NO Steamworks SDK FFI
  3. Hint substitution via `AnimatedSwitcher`: gamepad mode RB/LB hints fade in / arrow-key hints fade out; keyboard mode reverse
  4. Raw `gameButtonLeft1` / `gameButtonRight1` bindings DELETED from `_handleKeyEvent` (`grep` confirms zero references) — Steam Input LB/RB→←/→ no longer double-fires
  5. Single root `Focus(onKeyEvent: _handleKeyEvent)` returns `handled` for ALL recognized arrows — ←/→ cannot escape to `KeyboardHandler` seek ±5s
  6. Top/bottom thin-glass arrows over option list use `Container(color: Tokens.bgGlass)` (no second blur); keyboard ↑/↓ triggers arrow glow feedback
**Blocking Constraints honored**: Steam Input API auto-maps (no Flutter adapter layer — heuristic + toggle only, not FFI); 设计北极星 (arrows match control-bar glass); Tokens.*; BackdropFilter stacking mitigation (Pitfalls 3 + 5); focus-tree single root (Pitfall 1)
**Plans**: TBD — needs `--research-phase 32` (InputModeDetector is the only new v4.5 infrastructure; verify Steam Input event signatures for heuristic distinguishability)
**UI hint**: yes

### Phase 33: Audio Settings Tab
**Goal**: Fill the audio tab with real EQ / balance / sync / normalization features composed into a single MDK `af` filter string and committed purely through deferred-apply — zero kernel change.
**Depends on**: Phase 30 (container); Phase 31 (visual alignment so audio rows match); INDEPENDENT of Phase 34 (parallelizable — deep EQ vs quick switch)
**Requirements**: AUDIO-01, AUDIO-02, AUDIO-03, AUDIO-04, AUDIO-05, AUDIO-06, AUDIO-07
**Success Criteria** (what must be TRUE):
  1. EQ presets (`bass` / `treble` / `equalizer` af), balance slider (`pan`, UI abstracts -1.0..+1.0 → filter string), sync slider (`adelay`, direction aligned with subtitle delay UX), normalization toggle (`dynaudnorm`, default off) — ALL flow through existing `MediaEngine.setEqualizer(String afFilter)`, zero kernel change
  2. Private `_buildAfString(PendingSettingsState) → String` composes EQ / balance / sync / normalization into one `af` chain
  3. Pure deferred-apply (PRODUCT decision固化): slider drag updates `PendingSettingsState` ONLY; `engine.setEqualizer()` called on OK/Apply; Cancel discards pending (no engine-state snapshot management)
  4. `SettingsStore` (SharedPreferences) persists EQ preset / balance / sync / normalization on OK/Apply commit
  5. Video / subtitle / playback tabs remain `SettingRow` placeholders (scope boundary honored — v4.5 audio tab only)
**Blocking Constraints honored**: zero kernel interface expansion (reuse `setEqualizer` af entry; `AudioConfig` ISP deferred to v4.6+); deferred-apply non-negotiable (AUDIO-06 pure, no live preview); scope boundary (audio tab only); ValueNotifier unchanged; zero new dependencies
**Plans**: TBD — needs `--research-phase 33` (verify MDK `af` filter support for `pan` / `adelay` / `dynaudnorm` in the linked FFmpeg build — not just FFmpeg upstream)
**UI hint**: yes

### Phase 34: Control Bar Audio Track Switching
**Goal**: Add a control-bar audio-track button (left of subtitle, right of open-file) that pops a track list menu — mechanically mirroring the subtitle button.
**Depends on**: Phase 30 (container for popup positioning); INDEPENDENT of Phase 33 (parallelizable — quick switch vs deep EQ)
**Requirements**: CTRLBAR-01, CTRLBAR-02, CTRLBAR-03, CTRLBAR-04, CTRLBAR-05
**Success Criteria** (what must be TRUE):
  1. `GlassButton.iconOnly(Icons.headphones)` inserted in the right-button group (subtitle button left / open-file right)
  2. Click pops `OverlayEntry` + `ListView.builder` track list (symmetric to subtitle button pattern)
  3. `CompositedTransformTarget` + `CompositedTransformFollower` keep popup attached to button on window move / resize; ESC / outside-tap / resize dismisses via `TapRegion` + metrics listener
  4. Button visible ONLY when `getAudioTracks().length > 1` (single track → hidden)
  5. `TrackPopupMenu` shared widget extracted — both audio AND subtitle buttons use it (DRY + symmetry)
**Blocking Constraints honored**: 设计北极星 (button matches control-bar three-state); zero new deps (`OverlayEntry` / `CompositedTransformFollower` existing); Windows primary; ValueNotifier unchanged; scope boundary (control-bar button, not kernel)
**Plans**: TBD — light research (probably skippable): confirm subtitle button primitive (`showMenu` vs `OverlayEntry`) for the symmetry decision before extracting shared `TrackPopupMenu`
**UI hint**: yes

## Phase Progress

| Phase | Name | Status | Plans | REQ count |
|-------|------|--------|-------|-----------|
| 28 | Settings Shell Split + Legacy Deletion | Not started | 0/TBD | 2 |
| 29 | Auto-Pause Always | Not started | 0/TBD | 4 |
| 30 | Panel Layout Redesign | Not started | 0/TBD | 5 |
| 31 | Visual Design Alignment | Not started | 0/TBD | 5 |
| 32 | Navigation & Interaction Polish | Not started | 0/TBD | 7 |
| 33 | Audio Settings Tab | Not started | 0/TBD | 7 |
| 34 | Control Bar Audio Track Switching | Not started | 0/TBD | 5 |

## Build Order Rationale

The 28 → 29 → 30 → 31 → 32 → 33 → 34 sequence is derived from `research/SUMMARY.md` Phase Ordering Rationale, grounded in the Features dependency graph and Pitfalls hard rules:

1. **Phase 28 first (split before features)** — Pitfalls Cross-Cutting Risk 2 hard rule: `settings_overlay_shell.dart` is at 517 lines (near the 500-line cap); v4.5 adds ~300 lines of arrows + input-mode + glass overlays. Split into `tab_strip.dart` + `tab_content.dart` + `panel_key_bindings.dart` + delete the legacy `settings_panel.dart` (88px sidebar, not the PROJECT.md-misremembered 200px) BEFORE adding any v4.5 feature, or mid-feature refactor becomes impossible. (SUMMARY: Cross-Cutting Theme 4 + Phase 28 rationale)

2. **Phase 29 second (auto-pause early)** — Features researcher's MVP order puts Feature 4 first: a one-line policy change (drop the `if (_wasPlaying)` guard) widened to a `MediaState _preOpenState` snapshot (Pitfalls precision, Architecture Reading B). Low risk, fast, and means every subsequent phase can iterate WITHOUT racing playback state — panel open no longer interferes with `openGeneration` / EOF / manual-pause / loading sub-races. (SUMMARY: Phase 29 rationale + Divergence Reconciliation B)

3. **Phases 30 → 31 → 32 (layout → visual → navigation)** — Features dependency graph: Features 2 (Visual), 3 (Navigation), and 5 (Audio) all live INSIDE the Feature 1 (Layout) container; Feature 3 depends on both 1 and 2. The only valid order is container (30) → chrome (31) → navigation polish (32). Reordering would mean re-touching the same surfaces. (SUMMARY: Phase Ordering Rationale + Features dependency graph)

4. **Phases 33 → 34 last (audio tab + control-bar button, parallelizable)** — Both are INDEPENDENT of layout / navigation work. Audio Tab (Phase 33) is the heaviest single feature (kernel interface verification + UI + deferred-apply wiring + `af` string composition). Control-Bar Button (Phase 34) is mechanical (mirrors the subtitle button). Both depend only on the Phase 30 container existing — they can ship in parallel. `config.json parallelization: true` permits this. (SUMMARY: Phase Ordering Rationale + Architecture researcher's two-entry-point division: control-bar = quick switch, audio tab = deep EQ)

## Research Flags

Phases flagged in `research/SUMMARY.md` for deeper research during planning:

- **Phase 32 — `--research-phase 32` REQUIRED**: `InputModeDetector` is the only new v4.5 infrastructure. Steam Input API synthesizes keyboard events at the OS layer; verify whether `HardwareKeyboard` event signatures for `gameButton*` differ at all from real arrow keys (if byte-identical, the heuristic must rely on absence-of-mouse-move + arrow-key-presence). Read `keyboard_handler.dart` + Steam Input docs; cross-reference `project_steam_steamos_plan` memory.

- **Phase 33 — `--research-phase 33` REQUIRED**: MDK `af` filter support inside the linked FFmpeg build — verify `pan`, `adelay`, `dynaudnorm` are compiled in (not just FFmpeg upstream). Read `fvp_engine.dart` L908 + MDK docs; cross-reference `reference_fvp_performance_bottlenecks` and `fvp_plugin.cpp` memory. Context7 `/wang-bin/fvp` is MEDIUM confidence on audio filter specifics.

- **Phase 34 — light research (probably skippable)**: Confirm whether the subtitle button currently opens a file picker or a track dropdown — the symmetry decision (file-open vs track-list) gates whether the audio button should be file-open or dropdown. Read `project_right_click_quick_menu` memory + subtitle button handler. Can be folded into the Phase 34 PLAN.md if research is trivial.

Phases with standard patterns (skip `--research-phase`):
- **Phase 28** — Pure refactor (extract files, delete legacy, grep-verify callers). Well-documented Flutter patterns.
- **Phase 29** — 1-line edit + `MediaState` snapshot + tests. Architecture + Pitfalls fully specify the change.
- **Phase 30** — Ratio / size token change + tab reorder. Existing `_buildTabBar` stays. Standard.
- **Phase 31** — Token swap + `SettingRow` three-state polish. Reuses existing `control_bar.dart` decoration.

## Risk Profile

Per-phase risk from `research/SUMMARY.md` (all risks have concrete mitigations in Pitfalls 1–12):

| Phase | Risk | Reason |
|-------|------|--------|
| 28 (Shell Split) | LOW | Pure refactor; no behavior change; grep-verified callers |
| 29 (Auto-Pause) | LOW | Small blast radius (`SettingsPanelController.open()` body only); `SettingsPanelPlayback` seam unchanged; well-specified by Architecture + Pitfalls |
| 30 (Panel Layout) | LOW-MEDIUM | Ratio math + multi-monitor clamp; existing strip stays; main risk is test re-baseline for size assertions |
| 31 (Visual Alignment) | MEDIUM | BackdropFilter stacking perf cliff (Pitfall 3); token-swap scope leakage risk (only `SettingsOverlayShell`, not global `Tokens`) |
| 32 (Navigation Polish) | MEDIUM-HIGH | Only new v4.5 infrastructure (`InputModeDetector`); Steam Input edge cases (double-fire, detection reliability); focus-tree splitting risk (Pitfall 1); per-button repaint scope (Pitfall 5) |
| 33 (Audio Tab) | MEDIUM | Kernel interface verification needed (MDK `af` filter support); deferred-apply live-preview decision; `af` string composition correctness |
| 34 (Control-Bar Audio) | LOW-MEDIUM | Mechanical (mirrors subtitle button); main risk is popup positioning + symmetry decision |

**Highest-risk phase: 32 (Navigation Polish)** — flagged for `--research-phase 32`. The `InputModeDetector` is genuinely new ground; all other phases reuse v4.0 / v3.0 patterns.

## Traceability Coverage

Every v1 requirement mapped to exactly one phase. No orphans, no duplicates.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REFAC-01 | Phase 28 | Pending |
| REFAC-02 | Phase 28 | Pending |
| PAUSE-01 | Phase 29 | Pending |
| PAUSE-02 | Phase 29 | Pending |
| PAUSE-03 | Phase 29 | Pending |
| PAUSE-04 | Phase 29 | Pending |
| LAYOUT-01 | Phase 30 | Pending |
| LAYOUT-02 | Phase 30 | Pending |
| LAYOUT-03 | Phase 30 | Pending |
| LAYOUT-04 | Phase 30 | Pending |
| LAYOUT-05 | Phase 30 | Pending |
| VISUAL-01 | Phase 31 | Pending |
| VISUAL-02 | Phase 31 | Pending |
| VISUAL-03 | Phase 31 | Pending |
| VISUAL-04 | Phase 31 | Pending |
| VISUAL-05 | Phase 31 | Pending |
| NAV-01 | Phase 32 | Pending |
| NAV-02 | Phase 32 | Pending |
| NAV-03 | Phase 32 | Pending |
| NAV-04 | Phase 32 | Pending |
| NAV-05 | Phase 32 | Pending |
| NAV-06 | Phase 32 | Pending |
| NAV-07 | Phase 32 | Pending |
| AUDIO-01 | Phase 33 | Pending |
| AUDIO-02 | Phase 33 | Pending |
| AUDIO-03 | Phase 33 | Pending |
| AUDIO-04 | Phase 33 | Pending |
| AUDIO-05 | Phase 33 | Pending |
| AUDIO-06 | Phase 33 | Pending |
| AUDIO-07 | Phase 33 | Pending |
| CTRLBAR-01 | Phase 34 | Pending |
| CTRLBAR-02 | Phase 34 | Pending |
| CTRLBAR-03 | Phase 34 | Pending |
| CTRLBAR-04 | Phase 34 | Pending |
| CTRLBAR-05 | Phase 34 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓
- Duplicated: 0 ✓

**Phase distribution:**
- Phase 28 (REFAC 重构前置): 2
- Phase 29 (PAUSE 自动暂停): 4
- Phase 30 (LAYOUT 面板布局): 5
- Phase 31 (VISUAL 视觉对齐): 5
- Phase 32 (NAV 导航打磨): 7
- Phase 33 (AUDIO 音频 tab): 7
- Phase 34 (CTRLBAR 控制栏音轨): 5

## Milestones

<details>
<summary>✅ v2.0 沉浸式全屏重构 (Phases 1-8) - SHIPPED 2026-07-13</summary>

Fullscreen cleanup, WindowService simplification, immersive UI, test updates. Phase numbering 1-8.

</details>

<details>
<summary>✅ v2.1 播放内核重构强化 expanded (Phases 9-14) - SHIPPED 2026-07-15</summary>

引擎接口 ISP 分解 + 独立状态机 + StateMonitor 拆分（PlaybackStateManager + AutoAdvancePolicy）+ openGeneration 守卫 + Widget↔Kernel 边界优化。Phase 9-14 全部完成并归档。

</details>

<details>
<summary>✅ v3.0 内核重写兼容式替换 (Phases 15-22) - SHIPPED 2026-07-17</summary>

兼容适配层 + 零依赖 KernelLogger + sealed 错误模型 + MemoryMonitor 一等化 + 状态机重写 + 测试验证 + 双语文档。Phase 15-22 全部完成。

</details>

<details>
<summary>✅ v4.0 设置面板框架 (Phases 23-27) - SHIPPED 2026-07-25</summary>

Overlay Shell & State Model (Phase 23) + Sidebar Navigation (Phase 24) + Tab Content Framework (Phase 25) + Gamepad & Keyboard Navigation (Phase 26) + Responsive Scaling (Phase 27)。v4.0 框架骨架完成，v4.5 重构对象。

</details>

<details>
<summary>🚧 v4.5 设置面板横向重构 + 音频功能填充 (Phases 28-34) - IN PROGRESS</summary>

7 phases: Shell Split (28) + Auto-Pause Always (29) + Panel Layout Redesign (30) + Visual Design Alignment (31) + Navigation & Interaction Polish (32) + Audio Settings Tab (33) + Control Bar Audio Track Switching (34)。本路线图。

</details>

---
*Roadmap created: 2026-07-25 — Milestone v4.5 started (设置面板横向重构 + 音频功能填充)*
*Ready for planning: `/gsd-plan-phase 28`*
