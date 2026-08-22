---
phase: 30
slug: panel-layout-redesign
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-26
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> Phase 30 re-containers the settings overlay to 16:9 / ~50% screen area with
> the General tab in the middle of the 7-tab sequence and multi-monitor drag
> clamping. Validation focuses on: (1) size-assertion widget tests re-baselined
> to the 16:9 formula, (2) tab-strip middle-order assertion, (3) multi-monitor
> clamp behavior, (4) existing tab-strip tests stay green.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (widget tests double as integration tests per CLAUDE.md) |
| **Config file** | `pubspec.yaml` + `analysis_options.yaml` (strict-casts/strict-inference/strict-raw-types enabled) |
| **Quick run command** | `flutter test test/widgets/` (widget / size-assertion subset) |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30-60 seconds (headless) — note: ~57 pre-existing mdk.dll FFI load failures in headless env; stash/re-run to distinguish regressions (per memory `reference_mdk_dll_headless_test_failures`) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widgets/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

> Populated by the planner/executor once `30-0N-PLAN.md` tasks exist. Each row
> maps a Task ID → REQ-ID → automated verify command. Seed rows below cover the
> 5 LAYOUT requirements; expand during execution. Phase 30 is layout/sizing —
> no auth/data surface, so Secure Behavior = N/A and threat refs are empty
> (§5.55 rates this phase LOW risk).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | LAYOUT-01 | — | N/A | widget | `flutter test test/widgets/panel_size_test.dart` | ❌ W0 | ⬜ pending |
| 30-01-02 | 01 | 1 | LAYOUT-02 | — | N/A | widget | `flutter test test/widgets/panel_size_test.dart` | ❌ W0 | ⬜ pending |
| 30-01-03 | 01 | 1 | LAYOUT-04 | — | N/A | widget | `flutter test test/widgets/multi_monitor_clamp_test.dart` | ❌ W0 | ⬜ pending |
| 30-01-04 | 01 | 1 | LAYOUT-05 | — | N/A | widget | `flutter test test/widgets/panel_color_test.dart` | ❌ W0 | ⬜ pending |
| 30-01-05 | 01 | 1 | LAYOUT-03 | — | N/A | widget | `flutter test test/widgets/tab_strip_order_test.dart` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Re-baseline `test/widgets/panel_size_test.dart` assertions to `width = min(0.5 × screenW, screenH × 16/9)` clamped to `[400, 960]` (LAYOUT-01, LAYOUT-02)
- [ ] Add multi-monitor clamp widget test covering `display_enumerator` work-area clamp (LAYOUT-04)
- [ ] Existing tab-strip order tests stay green after General-tab middle reorder (LAYOUT-03)

*If none: "Existing infrastructure covers all phase requirements." — here, existing size/tab-strip tests need re-baselining, so Wave 0 listed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Multi-monitor drag never lands on non-primary bezel gap | LAYOUT-04 | Requires real multi-monitor hardware; FFI clamp logic is unit-tested, but visual bezel-gap confirmation needs a physical dual-display rig | Drag settings overlay across monitor boundary on dual-display setup; confirm panel clamps to primary work-area, never straddles the bezel |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
