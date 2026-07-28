---
phase: 32
slug: navigation-interaction-polish
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-29
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **Source:** distilled from `32-RESEARCH.md` § Validation Architecture (L356-399, MEDIUM confidence).
> Plan-checker iter8 PASSED 2026-07-29 (0 blockers; 1 exempt `nyquist_compliance` warning resolved by THIS file's creation).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` from Flutter SDK 3.44.8 / Dart 3.12.2 |
| **Config file** | `pubspec.yaml` (no separate test config) |
| **Quick run command** | `flutter test test/kernel/services/input_mode_detector_test.dart test/ui/dialogs/settings/settings_tab_strip_test.dart test/ui/dialogs/settings/settings_overlay_shell_test.dart` |
| **Full suite command** | `flutter analyze && flutter test --coverage` |
| **Estimated runtime** | ~120 seconds full suite; ~15-30s targeted subset |

---

## Sampling Rate

- **After every task commit:** Run the targeted detector + settings-widget test files covering that task's NAV requirements.
- **After every plan wave:** Run `flutter analyze` + all Phase 32 test files.
- **Before `/gsd-verify-work`:** Full `flutter test --coverage` must be green — account for the documented pre-existing headless `mdk.dll` FFI baseline SEPARATELY (per Phase 31 `VERIFICATION.md` L28-34; not a Phase 32 regression).
- **Max feedback latency:** ~120 seconds (full suite).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-01-01 | 01 | 1 | NAV-02 | timer-after-dispose (DoS) | `InputModeDetector` ignores non-mouse pointer activity; idle heuristic (5s no-pointer-move + arrow-keys → gamepad); override toggle wins; timer cancelled + lifecycle guarded on dispose | unit (fake clock/timer via `@visibleForTesting forTest/resetInstance` + injectable `DateTime Function() clock`) | `flutter test test/kernel/services/input_mode_detector_test.dart` | ❌ W0 | ⬜ pending |
| 32-01-02 | 01 | 1 | NAV-04 | arrow-leak-to-seek (Tampering) | Zero `gameButtonLeft1`/`gameButtonRight1` production references; raw shoulder-button behavioral tests removed (source-grep gate is the authoritative proof) | source-grep gate + widget | `git grep -nE 'gameButtonLeft1|gameButtonRight1' -- ':(exclude)test/**' 'lib/**'` must exit 1; obsolete behavioral tests in `settings_overlay_shell_test.dart` L574-651 replaced | ✅ shell test exists (needs behavioral-test replacement + grep assertion) | ⬜ pending |
| 32-01-03 | 01 | 1 | NAV-07 | arrow-leak-to-seek (Tampering) | Single root `Focus(onKeyEvent: _handleKeyEvent)` returns `handled` for ALL recognized arrows; ←/→ cannot escape to outer `KeyboardHandler` seek ±5s | integration widget (outer `KeyboardHandler` spy callbacks) | `flutter test test/ui/dialogs/settings/settings_overlay_shell_test.dart` | ✅ exists (needs outer-handler leakage case) | ⬜ pending |
| 32-02-01 | 02 | 2 | NAV-01 | — | End-cap `TabArrowButton` widgets persistently visible + clickable; ←/→ switches tab by one index | widget | `flutter test test/ui/dialogs/settings/settings_tab_strip_test.dart test/ui/dialogs/settings/settings_overlay_shell_test.dart` | ❌ W0 (strip test); shell test exists | ⬜ pending |
| 32-02-02 | 02 | 2 | NAV-03 | — | Mode change replaces a `ValueKey`ed child via `AnimatedSwitcher`; gamepad RB/LB hints fade in / arrow-key hints fade out (keyboard reverse) | widget | `flutter test test/ui/dialogs/settings/input_mode_hint_test.dart` | ❌ W0 | ⬜ pending |
| 32-03-01 | 03 | 3 | NAV-05 | nested-blur (DoS) | Top/bottom option-list arrows use `Container(color: Tokens.bgGlass)` — ZERO new `BackdropFilter`/`GlassContainer` in overlay subtree; single-blur composition boundary honored | widget structural | `flutter test test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` | ❌ W0 | ⬜ pending |
| 32-03-02 | 03 | 3 | NAV-06 | timer-after-dispose (DoS) | ↑/↓ produces correct temporary `arrowGlow` notifier/view state; glow-reset timer cancelled on panel close (`onPanelClosed` hook); no timer-after-dispose | unit + widget | `flutter test test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kernel/services/input_mode_detector_test.dart` — deterministic idle, hover, override, and disposal coverage for NAV-02 (13 tests via `@visibleForTesting forTest/resetInstance` + injectable clock + Test 13 panel-close cancellation; production `instance` singleton never disposed)
- [ ] `test/ui/dialogs/settings/settings_tab_strip_test.dart` — end-cap geometry/click + compact-width coverage for NAV-01
- [ ] `test/ui/dialogs/settings/input_mode_hint_test.dart` — keyed `AnimatedSwitcher` replacement coverage for NAV-03
- [ ] `test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` — no-second-blur structure + ↑/↓ glow coverage for NAV-05/06
- [ ] Extend `settings_overlay_shell_test.dart` with outer `KeyboardHandler` spy callbacks to prove arrow containment for NAV-07 (replacing obsolete `gameButton` L574-651 tests; criterion 213 scoped to prohibit behavioral refs only, explicitly allowing the source-grep assertion)
- [ ] Repair `settings_focus_navigation_test.dart` L16-21 stale fake (`initiallyPlaying` → `initialState: MediaState.playing`) before relying on its `>=4` focus-traversal assertion

*Existing infrastructure covers the framework; Wave 0 only adds the 4 new test files + 1 extension + 1 fake repair.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Native keyboard ←/→ vs Steam Input LB/RB on Windows | NAV-02 / NAV-04 | Headless Flutter tests synthesize keys but cannot prove the Steam/Windows mapping's original platform event signature or duplicate delivery | Record key log fields, tab-index delta exactly one per press, correct hint mode/fallback toggle |
| GPU/perceptual thin-glass quality | NAV-05 | Structural tests assert no additional `BackdropFilter` but cannot prove visual match / readback cost on target hardware | Inspect top/bottom overlays on the open panel + profile for no new blur layer / jank |

*Plan 03 `autonomous=FALSE` with `checkpoint:human-verify` gates these two manual scenarios (Windows Steam Input dual-mode + profile raster A/B) per the plan's blocking checkpoint.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (4 new test files + 1 shell extension + 1 fake repair)
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-29 (plan-checker iter8 PASSED — 0 blockers; the prior `nyquist_compliance` warning is resolved by this artifact's creation per §12 of the checker prompt).
