# Project Research Summary

**Project:** simple_player_flutter — v4.5 设置面板横向重构 + 音频功能填充
**Domain:** Flutter desktop media player (fvp/MDK) — settings panel UX overhaul + audio feature backfill
**Researched:** 2026-07-25
**Confidence:** HIGH (grounded in live code; one kernel-audio gap flagged)

## Executive Summary

v4.5 is a **polish-and-fill milestone, not a rebuild**. The v4.0 settings framework at `lib/ui/dialogs/settings/` (Phase 23–27) already ships ~70% of the v4.5 target: a horizontal `_buildTabBar` strip (7 `SettingsNavItem`, 64/56px) already exists in `settings_overlay_shell.dart`, the overlay-shell-as-Stack-sibling pattern is in place, the deferred-apply `PendingSettingsState` is wired, and the `SettingsPanelPlayback` seam protects the kernel from UI races. The PROJECT.md "delete 200px sidebar" instruction is **stale** — the actual legacy sidebar in `lib/ui/dialogs/settings_panel.dart` is 88px, and the v4.0 framework path already moved past it. v4.5 finishes the remaining 30%: end-cap arrows, color unification to control-bar tokens, 5:4→16:9 ratio change, input-mode hints, always-pause, audio tab fill, control-bar audio button. **First job: delete the legacy `settings_panel.dart` and consolidate onto the `settings/` framework** — this removes ~750 lines of duplicate layout code and the "which panel?" ambiguity before any new feature lands.

The recommended approach is **zero new dependencies + zero kernel interface expansion**. All four audio features (EQ / balance / sync / normalization) flow through the existing `MediaEngine.setEqualizer(String afFilter)` entry — which the Stack researcher verified at `fvp_engine.dart` L908 is a generic MDK `af` passthrough, not just EQ despite its name. The four features map to FFmpeg `af` filter strings composed by a private `_buildAfString()` helper in AudioTab and submitted through `PendingSettingsState.commit()` → `engine.setEqualizer(...)`. The Architecture researcher's `AudioConfig` ISP proposal is a **clean optional enhancement, not a v4.5 requirement** — defer it; reuse the existing entry to avoid touching the v3.0 kernel baseline. The only genuinely new infrastructure in v4.5 is **input-mode detection** (keyboard vs gamepad hint substitution), because Steam Input API synthesizes keyboard events at the OS layer and Flutter's `HardwareKeyboard` cannot distinguish device source. The Stack researcher's recommendation: heuristic (`PointerMoveEvent` → keyboard; arrow keys with 5s no-mouse → gamepad) plus an explicit `auto/keyboard/gamepad` toggle fallback — Steamworks SDK FFI is explicitly out of scope (PROJECT.md excludes the gamepad adapter layer).

Key risks are concentrated in three places, all with concrete mitigations. (1) **Auto-pause "always"** is a one-line edit that races with `openGeneration`, end-of-media, and manual-pause states — mitigate by widening `bool _wasPlaying` to `MediaState _preOpenState` and only resuming if the pre-open state was `MediaState.playing` (the Pitfalls researcher's "Reading B", which the Architecture researcher agrees with). (2) **BackdropFilter stacking** — the design north star ("align to control bar glass") risks 3+ stacked GPU readback layers (panel + arrow thin-glass + hover highlight); mitigate by reusing control_bar's single-`BackdropFilter` + `opacity < 0.01` skip + `RepaintBoundary` pattern, faking thin-glass translucency with `Tokens.bgGlass` color rather than a second blur pass. (3) **`settings_overlay_shell.dart` is 517 lines, near the 500-line cap** — adding arrows + input-mode logic + glass overlays will push it past 800; the Pitfalls researcher's hard rule: **split first** (`tab_strip.dart`, `tab_content.dart`, `panel_key_bindings.dart`) before adding v4.5 features.

## Cross-Cutting Themes

1. **v4.0 framework is 70% built — v4.5 is polish, not rebuild.** All four researchers converge: the horizontal tab strip, overlay shell, deferred-apply, focus isolation, and kernel seams already exist. The PROJECT.md "delete 200px sidebar" framing is stale; the actual work is visual polish + audio fill. This is the dominant fact for phase ordering — no greenfield scaffolding needed.
2. **Audio features reuse `setEqualizer(afString)` — zero kernel change.** Stack read live code (`fvp_engine.dart` L908) confirming `setEqualizer` is a generic MDK `af` passthrough. EQ uses `bass`/`treble`/`equalizer`, balance uses `pan`, sync uses `adelay`, normalization uses `dynaudnorm`. All four are composed into a single `af` string and committed through `PendingSettingsState`. The Architecture researcher's `AudioConfig` ISP is an optional cohesion improvement — defer to v4.6+ to avoid kernel churn.
3. **Input-mode detection is the only new infrastructure.** Steam Input API synthesizes keyboard events at the OS layer; Flutter cannot distinguish device source. Solution across all three researchers who addressed it (Stack + Features + Pitfalls): heuristic (`PointerMoveEvent` → keyboard; arrow-keys-with-no-mouse-5s → gamepad) + explicit `auto/keyboard/gamepad` toggle fallback. Hints are **display-only** since Steam Input already maps gamepad→keyboard for navigation. **Critical: delete raw `gameButtonLeft1`/`gameButtonRight1` bindings** (Pitfall 6) to avoid LB/RB double-fire when Steam remaps to ←/→.
4. **`settings_overlay_shell.dart` near 500-line cap — split first.** The Pitfalls researcher flags this as the highest-priority cross-cutting risk: shell.dart is 517 lines and v4.5 adds ~300 lines of arrows + input-mode + glass overlays. Split `tab_strip.dart` / `tab_content.dart` / `panel_key_bindings.dart` BEFORE adding v4.5 features, not after. The Architecture researcher independently recommends extracting a shared `PanelDecoration`/`ControlBarDecoration` token for color unification — same split impulse.
5. **BackdropFilter stacking — reuse control_bar single-layer + opacity-skip pattern.** The design north star ("align to control bar glass") creates a temptation to stack `BackdropFilter` on every glass surface (panel + arrow thin-glass + hover rows). The Pitfalls researcher quantifies the cliff: each `BackdropFilter` is a D3D11 GPU readback on Windows; 3+ stacked = jank during drag/scroll, RSS spike, Steam Deck stutter. Mitigation: ONE `BackdropFilter` per panel (the existing `GlassContainer`), `RepaintBoundary` outside it, thin-glass translucency faked with `Container(color: Tokens.bgGlass)` (no second blur pass), `opacity < 0.01` skip during exit-anim tail (already in shell L49).
6. **Deferred-apply is non-negotiable for audio; live-preview is the trap.** The Architecture and Pitfalls researchers agree: Audio EQ/balance/sync changes MUST go through `PendingSettingsState.update()` → `commit()` on OK/Apply, never direct `engine.setEqualizer()` calls from slider `onChanged`. Direct calls break Cancel (no rollback) and cause audio glitches on each keystroke. The Stack researcher's "mixed mode" (slider previews live via engine, pending only persists preference) is a UX improvement **but requires snapshotting pre-open engine `af` state in the controller and restoring on Cancel** — `pending.cancel()` only rolls back the map, not the engine. Phase planning must pick one mode explicitly; recommended: pure deferred-apply for v4.5 (matches existing EQ tab's real-time-preview but with engine-state snapshot in controller for Cancel).

## Divergence Reconciliation

| # | Topic | Stack says | Architecture says | Pitfalls says | Resolution |
|---|-------|-----------|--------------------|---------------|------------|
| A | Audio EQ/balance/sync path | Reuse `setEqualizer(afString)`, zero kernel change (live code at fvp_engine.dart L908 is generic `af` passthrough) | New `AudioConfig` ISP (clean separation, mirrors `SubtitleConfig`) | (silent — agrees with reuse) | **Prefer Stack.** Live-code reading is authoritative; `setEqualizer` is genuinely generic. `AudioConfig` ISP is a **deferred enhancement** for v4.6+ cohesion, not a v4.5 blocker. Avoid kernel churn against v3.0 baseline. |
| B | Auto-pause strategy | "always pause on open, resume on close" (1-line: drop `if (_wasPlaying)` guard) | Reading B: drop guard on `open()`, keep `_wasPlaying` for `close()` resume decision (handles manual-pause-before-open) | Widen `bool _wasPlaying` → `MediaState _preOpenState`; only resume if `_preOpenState == MediaState.playing`; explicitly NO-RESUME for `loading`/`buffering`/`ended` | **Prefer Pitfalls** (most precise). Architecture's Reading B handles manual-pause but misses `loading`/`ended` edge cases. Pitfalls' `MediaState` snapshot covers all four sub-races (loading, EOF, manual-pause, openGeneration). Stack's "1-line" framing is too optimistic. |
| C | Horizontal tab implementation | Self-draw `GlassButton.iconOnly` sequence (avoids Material `TabBar` indicator = second visual system) | v4.0 `_buildTabBar` already horizontal 7-strip exists — only polish | (agrees with self-draw, warns about overflow at <640px) | **Reconcile: v4.0 strip is the base; v4.5 polishes to self-drawn GlassButton aligning control-bar language.** No structural rewrite — the 70%-built strip stays; v4.5 swaps the `SettingsNavItem` rendering to align with `GlassButton` three-state and adds end-cap arrows. Material `TabBar` with `isScrollable: true` is the **fallback for narrow widths** (Pitfall 4) — use it only when 7 labels truncate. |
| D | Input mode detection | Heuristic + explicit toggle; Steamworks SDK FFI = v4.6+ | New `InputModeDetector` `ValueNotifier<InputMode>` at panel root; debounce on modifier keys | Delete raw `gameButtonLeft1`/`gameButtonRight1` bindings (Pitfall 6); 500ms debounce; last-input-event heuristic | **Combine all three.** Heuristic + toggle fallback (Stack) + singleton `ValueNotifier<InputMode>` on controller (Architecture) + delete raw LB/RB bindings (Pitfalls) + 500ms debounce (Pitfalls). Hints are display-only since Steam Input maps gamepad→keyboard for navigation. |

## Key Findings

### Recommended Stack

**Zero new dependencies.** v4.5 is built entirely on the existing pubspec: `fvp ^0.37.2` (MDK/FFmpeg), `flutter_localizations`, `shared_preferences ^2.5.5`, `ffi ^2.1.0`, and the project's own v3.0 kernel + v4.0 settings framework. No new packages, no native bridges, no Steamworks SDK integration (deferred to v4.6+).

**Core technologies:**
- **fvp 0.37.2 (MDK/FFmpeg)** — playback engine + audio filter chain via `af` property. `setEqualizer(String)` is the single entry point for EQ/balance/sync/normalization.
- **Flutter Material (existing)** — `GlassButton`, `GlassContainer`, `FocusTraversalGroup`, `OverlayEntry`, `RepaintBoundary`, `AnimatedSwitcher`/`TweenAnimationBuilder`. No new widget library.
- **ValueNotifier + ValueListenableBuilder** — state management (project-locked since v2.1; PROJECT.md constraint).
- **`InputModeService` (NEW, kernel/services)** — `ValueNotifier<InputMode>{keyboard, gamepad, auto}` with heuristic detection + toggle fallback. The only new infrastructure.
- **`SettingsStore` (SharedPreferences, existing)** — persists audio tab preferences (default volume, EQ preset, balance, normalization toggle) on OK/Apply.

### Expected Features

**Must have (table stakes — from FEATURES.md):**
- Horizontal tab navigation (drop sidebar/tree pattern; top-tab strip is the player-panel norm — VLC/mpv.net/IINA all use it)
- EQ / equalizer presets (already wired in `EqualizerTab`; needs visual realignment only)
- Audio track switching from control bar (every surveyed player has track switching ≤2 clicks away)
- Auto-pause while settings open (jarring if audio plays under the panel)
- OK/Cancel/Apply deferred-apply (existing v4.0 framework; Audio tab must adopt it)
- Glass language consistent with control bar (immersion break otherwise)
- Keyboard navigation (existing v4.0 `FocusTraversalGroup` + `SpinControl`)

**Should have (differentiators):**
- Gamepad-aware hint substitution (RB/LB ↔ ←/→ fade) — no surveyed desktop player does this; aligns with Steam/SteamOS roadmap
- Top/bottom thin-glass arrows over option list ("透看选项") — unique visual
- Audio tab combining in-tab track list + deep EQ (no surveyed player does both in one tab)
- 16:9 / 50%-screen overlay (vs fixed dialog) — feels like part of the player
- Edge-glow + 3-state button feedback matching control bar

**Defer (v4.6+):**
- Video / subtitle / playback tab feature fill (PROJECT.md explicit; keep `SettingRow` placeholders)
- Audio device / output module picker
- Per-band graphical 10-band EQ (preset-list EQ is sufficient for v4.5)
- Default audio language preference wiring
- Pitch correction, `AudioConfig` ISP refactor, Steamworks SDK FFI for native gamepad polling

### Architecture Approach

v4.5 builds on the v4.0 `SettingsOverlayShell` mounted as a `PlayerScreen` Stack sibling (NOT `showDialog` — that rebuilds `MaterialApp` on locale/theme change, losing deferred-apply state). The controller depends only on the narrow `SettingsPanelPlayback` seam (`isPlaying`/`pause`/`play`), never on `MediaEngine` directly, avoiding races with `PlaybackController`'s `openGeneration` guard. `PendingSettingsState` is pure Dart (NOT `ChangeNotifier`) — tabs call `setState` locally after `update()` to avoid `IndexedStack`-level cascade rebuilds. Content is `IndexedStack` + `TweenAnimationBuilder` fade for tab persistence. Panel root is `RepaintBoundary`-wrapped with `BackdropFilter` skipped when `opacity < 0.01`.

**Major components:**
1. `SettingsPanelController` — open/close/toggle + nextTab/prevTab + holds `state` + `pending`; auto-pause snapshot widened to `MediaState _preOpenState`
2. `SettingsOverlayShell` (split into `tab_strip.dart` + `tab_content.dart` + `panel_key_bindings.dart` BEFORE adding features) — overlay render tree
3. `PendingSettingsState` — deferred-apply pure-data container; Audio tab registers `eq`/`balance`/`delay`/`normalize` keys
4. `InputModeDetector` (NEW) — singleton `ValueNotifier<InputMode>` at panel root; all hint widgets subscribe
5. `AudioTab` (filled) — EQ/balance/sync/normalization rows; writes to `pending`; `_buildAfString()` composes `af` chain
6. Control-bar audio track button (NEW in `right_button_group.dart`) — `GlassButton.iconOnly(Icons.headphones)` left of subtitle button; `OverlayEntry` popup with `ListView.builder` track list

### Critical Pitfalls

1. **Auto-pause races (Pitfall 2)** — loading/buffering/ended/manual-pause states all cause "close → unexpected play". Mitigation: widen `bool _wasPlaying` → `MediaState _preOpenState`; only resume if `_preOpenState == MediaState.playing`. Widget test: load media → wait for `loading` → open → close → assert `play()` NOT called.
2. **BackdropFilter stacking perf cliff (Pitfall 3)** — 3+ GPU readback layers = jank on drag/scroll, Steam Deck stutter. Mitigation: ONE `BackdropFilter` per panel; thin-glass translucency faked with `Container(color: Tokens.bgGlass)`; `opacity < 0.01` skip during exit anim; per-button `RepaintBoundary` for animated arrows.
3. **`settings_overlay_shell.dart` 517 lines → past 800 with v4.5 additions (Cross-Cutting Risk 2)** — Mitigation: split into `tab_strip.dart` / `tab_content.dart` / `panel_key_bindings.dart` BEFORE adding features.
4. **Steam Input LB/RB double-fire (Pitfall 6)** — Steam remaps LB→← and shell also binds `gameButtonLeft1` directly → tab switches twice. Mitigation: delete raw `gameButtonLeft1`/`gameButtonRight1` bindings from `_handleKeyEvent`; rely on Steam's keyboard remapping.
5. **Keyboard ←/→ escaping panel focus subtree (Pitfall 1)** — if v4.5 splits arrow-button Focus from the option-list Focus, unhandled arrows bubble to `KeyboardHandler` and seek the video ±5s. Mitigation: ONE `FocusTraversalGroup` wrapping the whole panel with a single root `Focus(onKeyEvent: _handleKeyEvent)` returning `handled` for ALL recognized keys.
6. **Deferred-apply: EQ live-preview can't undo (Pitfall 8)** — `pending.cancel()` only rolls back the map, not the engine. Mitigation: either pure deferred-apply (no live preview) OR snapshot pre-open engine `af` state in controller and restore on Cancel.
7. **Control-bar audio popup orphaned on window move (Pitfall 9)** — `OverlayEntry` doesn't follow button on resize. Mitigation: `CompositedTransformTarget` + `CompositedTransformFollower`; close on ESC/outside-tap/resize via `TapRegion` + `WidgetsBinding.window.onMetricsChanged`.
8. **16:9 vs 50%-area conflict on non-16:9 monitors (Pitfall 10)** — Mitigation: pick 16:9 as primary; `width = min(0.5 × screenW, screenH × 16/9)`; clamp `[400, 960]`; multi-monitor drag clamp via `display_enumerator` work-area (not `MediaQuery`).

## Implications for Roadmap

Based on combined research, the suggested phase structure. Features renumbered per PROJECT.md (1=Layout / 2=Visual / 3=Navigation / 4=Auto-Pause / 5=Audio Tab / 6=Control-Bar Audio).

### Phase 28: Settings Shell Split + Legacy Deletion
**Rationale:** Pitfalls Cross-Cutting Risk 2 + Architecture's two-panel finding. `settings_overlay_shell.dart` is 517 lines; v4.5 adds ~300. Split first or refactor becomes impossible mid-feature. Also delete the legacy `settings_panel.dart` (88px sidebar) to remove the "which panel?" ambiguity.
**Delivers:** `tab_strip.dart` + `tab_content.dart` + `panel_key_bindings.dart` extracted; legacy `settings_panel.dart` deleted; zero callers verified via `grep -r "SettingsPanel("`.
**Addresses:** No PROJECT.md feature directly — this is the prerequisite refactor that gates all v4.5 features.
**Avoids:** Shell-bloat anti-pattern (Pitfalls Cross-Cutting Risk 2); two-panel drift (Architecture Critical Finding).

### Phase 29: Auto-Pause Always (Feature 4)
**Rationale:** Features researcher's MVP order puts Feature 4 first (one-line policy change, unblocks safe iteration on all other features). Pitfalls widens the snapshot to `MediaState _preOpenState` — small but non-trivial. Low risk, fast, and means every subsequent phase can iterate without racing playback state.
**Delivers:** `SettingsPanelController.open()` always pauses; `_preOpenState` snapshot; `close()` resumes only if `_preOpenState == MediaState.playing`. Tests for loading/ended/manual-pause edge cases.
**Addresses:** PROJECT.md Feature 4 (Auto-Pause Always).
**Avoids:** Pitfall 2 (auto-pause races with openGeneration/EOF/manual-pause/loading).
**Uses:** Existing `SettingsPanelPlayback` seam (unchanged interface).

### Phase 30: Panel Layout Redesign (Feature 1)
**Rationale:** Features dependency graph — Features 2, 3, 5 all live INSIDE the Feature 1 container. Gating phase. Architecture confirms v4.0 horizontal strip already exists; this phase is ratio change (5:4 → 16:9 / 50% area) + General-tab-to-middle reorder + tokens (`panelAspectRatio`, `panelWidthRatio`, `panelMinWidth`, `panelMaxWidth`).
**Delivers:** 16:9 ratio with `width = min(0.5 × screenW, screenH × 16/9)` clamp `[400, 960]`; General tab moved to middle of sequence; multi-monitor drag clamp via `display_enumerator`.
**Addresses:** PROJECT.md Feature 1.
**Avoids:** Pitfall 10 (16:9 vs 50%-area conflict); Pitfall 4 (tab overflow at narrow widths — define `tabIconOnlyWidth`/`tabScrollWidth` tokens).
**Implements:** `SettingsOverlayShell` sizing + tab order; `Tokens.panel*` constants.

### Phase 31: Visual Design Alignment (Feature 2)
**Rationale:** Done immediately after the container exists (Phase 30) so every subsequent tab fills the right look. Color unification to control-bar tokens; `PanelDecoration`/`ControlBarDecoration` shared token extracted.
**Delivers:** Panel chrome swaps `Tokens.bgGlass` → `Tokens.controlBarBg` + `controlBarBorderWhite` + `glowOuterRing` (4-shadow decoration from `ControlBar._decorationPlaying`); option rows default borderless, highlight on hover/select only; tighter padding.
**Addresses:** PROJECT.md Feature 2.
**Avoids:** Pitfall 3 (BackdropFilter stacking — fake thin-glass with translucency, no second blur pass); Pitfall 12 (blur radius consistency — add `GlassTier.subtle` to tokens, never hardcode).
**Implements:** Shared `PanelDecoration` token; `GlassTier.subtle` addition; `SettingRow` three-state polish.

### Phase 32: Navigation & Interaction Polish (Feature 3)
**Rationale:** Depends on Phases 30+31 (horizontal strip to attach arrows to + visual alignment). Includes the only new v4.5 infrastructure: `InputModeDetector`. Highest-risk-of-the-standard phases due to new component + Steam Input edge cases.
**Delivers:** End-cap rounded L/R arrow buttons (`TabArrowButton` with own `RepaintBoundary`); `InputModeDetector` singleton `ValueNotifier<InputMode>` with heuristic + toggle fallback; `AnimatedSwitcher` hint substitution (RB/LB ↔ ←/→); top/bottom thin-glass arrows over option list; keyboard-up/down glow feedback; **deletion of raw `gameButtonLeft1`/`gameButtonRight1` bindings**.
**Addresses:** PROJECT.md Feature 3.
**Avoids:** Pitfall 1 (←/→ escaping focus subtree — single root `Focus.onKeyEvent`); Pitfall 5 (arrow-button repaint scope — per-button `RepaintBoundary` + `AnimatedBuilder`); Pitfall 6 (LB/RB double-fire — delete raw gamepad bindings); Pitfall 7 (input-mode detection reliability — 500ms debounce, last-input-event heuristic); Pitfall 11 (focus traversal order — explicit `OrderedTraversalPolicy`).
**Implements:** `InputModeService` (kernel/services); `TabArrowButton` widget; `InputModeHint` widget; `Tokens.tabArrowRadius`/`hintFadeDuration`.

### Phase 33: Audio Settings Tab (Feature 5)
**Rationale:** Heaviest single feature (kernel interface verification + UI + deferred-apply wiring + `af` string composition). Independent of Feature 6 (control-bar button) — can ship in parallel. Phase-specific research needed to verify MDK `af` filter support for `pan`/`adelay`/`dynaudnorm` inside the linked FFmpeg build.
**Delivers:** `AudioTab` filled with EQ presets (consolidate from `EqualizerTab`), balance slider (`pan` filter, UI abstracts -1.0..+1.0 → filter string), sync slider (`adelay`, aligns direction with subtitle delay), normalization toggle (`dynaudnorm`, default off). `_buildAfString(PendingSettingsState) → String` composer. Pure deferred-apply (no live preview) OR controller-snapshot-restore-on-Cancel mode.
**Addresses:** PROJECT.md Feature 5.
**Avoids:** Pitfall 8 (deferred-apply: EQ live-preview can't undo — pick pure-deferred OR snapshot engine `af` state in controller for Cancel restore).
**Uses:** Existing `SubtitleConfig.setEqualizer` (zero kernel change per Stack); `PendingSettingsState` extended with `eq`/`balance`/`delay`/`normalize` keys; `SettingsStore` for persistence.

### Phase 34: Control Bar Audio Track Switching (Feature 6)
**Rationale:** Independent of Feature 5 (control-bar = quick switch; Audio tab = deep EQ). Ships last or in parallel with Phase 33. Mechanical: `GlassButton.iconOnly(Icons.headphones)` inserted left of subtitle button in `right_button_group.dart`; `OverlayEntry` popup with `ListView.builder` track list.
**Delivers:** `PlayerActions.onOpenAudioTrack` callback; audio track button (visible only when `getAudioTracks().length > 1`); `TrackPopupMenu` shared widget extracted from subtitle button pattern; `CompositedTransformFollower` for resize-follow; `TapRegion` outside-tap dismiss; ESC close.
**Addresses:** PROJECT.md Feature 6.
**Avoids:** Pitfall 9 (popup orphaned on window move — `CompositedTransformFollower` + resize listener); symmetry-with-subtitle trap (if subtitle button is file-open only, audio button should match OR subtitle button should get its own dropdown — decide per PRODUCT, don't ship half-symmetric).
**Implements:** `TrackPopupMenu` shared widget (used by both audio and subtitle buttons); `PlayerActions.onOpenAudioTrack`; `right_button_group.dart` insertion.

### Phase Ordering Rationale

- **Split before features (Phase 28 first):** Pitfalls hard rule — shell.dart at 517 lines will hit 800+ mid-feature, making refactor impossible. Split + delete legacy first.
- **Auto-pause early (Phase 29):** Features MVP order + Pitfalls precision. One-line policy change (widened to `MediaState` snapshot) unblocks safe iteration on every subsequent phase — panel open no longer races playback state.
- **Layout before Visual before Navigation (Phases 30→31→32):** Features dependency graph — 2+3+5 live inside the 1 container; 3 depends on 1+2. Container → chrome → navigation polish is the only valid order.
- **Audio Tab and Control-Bar Button last (Phases 33→34, parallelizable):** Independent of layout/navigation work. Heaviest single feature (Audio Tab) and mechanical feature (Control-Bar Button) can ship in parallel. Both depend only on the Phase 30 container existing.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 32 (Navigation Polish):** `InputModeDetector` is the only new v4.5 infrastructure. Steam Input API gamepad→keyboard remapping preserves enough signal for the heuristic? Verify `HardwareKeyboard` event signatures for `gameButton*` vs synthesized arrow keys. Run `/gsd-plan-phase --research-phase 32`.
- **Phase 33 (Audio Tab):** MDK `af` filter support inside the linked FFmpeg build — verify `pan`, `adelay`, `dynaudnorm` are compiled in (not just FFmpeg upstream). Read `fvp_engine.dart` + MDK docs; cross-reference `reference_fvp_performance_bottlenecks` and `fvp_plugin.cpp` memory. Run `/gsd-plan-phase --research-phase 33`.
- **Phase 34 (Control-Bar Audio Button):** Confirm whether subtitle button currently opens a file picker or a track dropdown — the symmetry decision (file-open vs track-list) gates whether the audio button should be file-open or dropdown. Read `right_click_quick_menu` memory + subtitle button handler. Light research, probably skippable.

Phases with standard patterns (skip research-phase):
- **Phase 28 (Shell Split):** Pure refactor — extract files, delete legacy, verify callers. Well-documented Flutter patterns.
- **Phase 29 (Auto-Pause):** 1-line edit + `MediaState` snapshot + tests. Architecture and Pitfalls fully specify the change.
- **Phase 30 (Panel Layout):** Ratio/size token change + tab reorder. Existing `_buildTabBar` stays. Standard.
- **Phase 31 (Visual Alignment):** Token swap + `SettingRow` three-state polish. Reuses existing `control_bar.dart` decoration.

## Risk Profile

| Phase | Risk | Reason |
|-------|------|--------|
| 28 (Shell Split) | LOW | Pure refactor; no behavior change; grep-verified callers |
| 29 (Auto-Pause) | LOW | Small blast radius (`SettingsPanelController.open()` body only); `SettingsPanelPlayback` seam unchanged; well-specified by Architecture+Pitfalls |
| 30 (Panel Layout) | LOW-MEDIUM | Ratio math + multi-monitor clamp; existing strip stays; main risk is test re-baseline for size assertions |
| 31 (Visual Alignment) | MEDIUM | BackdropFilter stacking perf cliff (Pitfall 3); token-swap scope leakage risk (only `SettingsOverlayShell`, not global `Tokens`) |
| 32 (Navigation Polish) | MEDIUM-HIGH | Only new v4.5 infrastructure (`InputModeDetector`); Steam Input edge cases (double-fire, detection reliability); focus-tree splitting risk (Pitfall 1); per-button repaint scope (Pitfall 5) |
| 33 (Audio Tab) | MEDIUM | Kernel interface verification needed (MDK `af` filter support); deferred-apply live-preview decision; `af` string composition correctness |
| 34 (Control-Bar Audio) | LOW-MEDIUM | Mechanical (mirrors subtitle button); main risk is popup positioning + symmetry decision |

**Highest-risk phase: 32 (Navigation Polish)** — flagged for `/gsd-plan-phase --research-phase 32`. The `InputModeDetector` is genuinely new ground; all other phases reuse v4.0/v3.0 patterns.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new deps; live code read at `fvp_engine.dart` L908 confirms `setEqualizer` is generic `af` passthrough. Context7 fvp docs only MEDIUM on audio filter specifics — verify in Phase 33. |
| Features | MEDIUM | Player-comparison matrix synthesized from training knowledge + partial WebSearch fallbacks (VLC/mpv.net/IINA tab structures); no fresh web fetch available in this environment. Codebase-integration claims HIGH (verified from source). Verify exact tab counts before locking pixel specs. |
| Architecture | HIGH | All four researchers grounded in live code read end-to-end. Two-panel finding, horizontal-tab-already-shipped, `SettingsPanelPlayback` seam, `PendingSettingsState` pure-Dart — all verified. |
| Pitfalls | HIGH | All 14 pitfalls grounded in live code (`settings_overlay_shell.dart`, `settings_panel_controller.dart`, `control_bar.dart`, `keyboard_handler.dart`, `pending_settings.dart`, `right_button_group.dart`, `playback_controller.dart`). Cross-checked against Architecture researcher. |

**Overall confidence:** HIGH. The v4.0 framework already exists and is well-understood; the only genuinely uncertain area is MDK `af` filter support for `pan`/`adelay`/`dynaudnorm` (Phase 33 research flag) and Steam Input event signatures for the `InputModeDetector` heuristic (Phase 32 research flag).

### Gaps to Address

- **MDK `af` filter availability** — verify `pan`, `adelay`, `dynaudnorm` are compiled into MDK's linked FFmpeg build (not just FFmpeg upstream). Phase 33 research.
- **Steam Input event signature** — does Steam's synthesized keyboard event preserve any metadata the heuristic can use, or is it byte-identical to a real keypress? If byte-identical, the heuristic must rely on absence-of-mouse-move + arrow-key-presence. Phase 32 research.
- **Subtitle button popup primitive** — read `right_click_quick_menu` memory + subtitle button handler to confirm `showMenu` vs `OverlayEntry` pattern before extracting shared `TrackPopupMenu`. Phase 34 light research.
- **Legacy `settings_panel.dart` callers** — `grep -r "SettingsPanel(" lib/ test/` before deletion to confirm zero production callers (tests may need migration). Phase 28 pre-step.
- **Audio EQ live-preview vs pure-deferred decision** — PRODUCT decision: does the user hear EQ changes as they drag the slider, or only on OK/Apply? Pure-deferred is simpler; live-preview requires engine-state snapshot in controller for Cancel. Phase 33 planning.
- **16:9 vs 50%-area on non-16:9 monitors** — pick 16:9 as primary (research recommendation); confirm with PRODUCT that 50%-area is the secondary constraint, not the primary. Phase 30 planning.
- **Audio button vs subtitle button symmetry** — if subtitle button is file-open only, should audio button also be file-open (external audio) or a track-dropdown? Decide per PRODUCT. Phase 34 planning.
- **`AudioConfig` ISP refactor** — Architecture researcher recommends; Stack researcher says defer. Consensus: defer to v4.6+ to avoid kernel churn against v3.0 baseline. Not a v4.5 gap.

## Sources

### Primary (HIGH confidence — live code read)
- `lib/kernel/engine/media_engine.dart` — MediaEngine composite ISP interface
- `lib/kernel/engine/fvp_engine.dart` — `setEqualizer` L908 (generic `af` passthrough)
- `lib/kernel/engine/track_control.dart`, `volume_control.dart`, `subtitle_config.dart` — kernel interfaces for audio tab
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` — v4.0 horizontal tab strip (517 lines, near cap)
- `lib/ui/dialogs/settings/settings_panel_controller.dart` — open/close + `_wasPlaying` snapshot
- `lib/ui/dialogs/settings/pending_settings.dart` — deferred-apply pure-Dart container
- `lib/ui/dialogs/settings_panel.dart` — legacy 88px-sidebar panel (to delete)
- `lib/ui/player/control_bar.dart` — design north star, single-`BackdropFilter` + `RepaintBoundary` pattern
- `lib/ui/player/keyboard_handler.dart` — arrowLeft/right seek ±5s bindings (focus-capture requirement)
- `lib/ui/player/right_button_group.dart` — audio button insertion point
- `lib/kernel/services/playback_controller.dart` — `SettingsPanelPlayback` seam (L37) + `openGeneration` guard (L34, L200)
- `.planning/PROJECT.md` — v4.5 6 target features + constraints + key decisions

### Secondary (MEDIUM confidence)
- Context7 `/wang-bin/fvp` — fvp platform/render API capabilities (does not cover audio filter specifics)
- Assistant training knowledge — VLC/mpv.net/IINA/PotPlayer/MPC-HC/Kodi/Big Picture tab structures + control-bar patterns (no fresh web fetch available in this environment)

### Tertiary (LOW confidence — needs validation)
- WebSearch built-in fallback responses — VLC 4-tab / mpv.net audio tab / IINA 8-tab structures (training-data fallbacks, not fresh web; verify exact tab counts before locking pixel specs)
- FFmpeg `avfilter` docs — `bass`/`treble`/`equalizer`/`pan`/`adelay`/`dynaudnorm`/`loudnorm` syntax (HIGH for syntax, MEDIUM for MDK-linked-build availability — verify in Phase 33)
- Steamworks Controller Documentation / ISteamInput API — Steam Input auto-mapping mechanism (HIGH for mechanism, MEDIUM for event-signature distinguishability — verify in Phase 32)

---
*Research completed: 2026-07-25*
*Ready for roadmap: yes*
